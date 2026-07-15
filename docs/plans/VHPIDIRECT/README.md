# VHPIDIRECT Merge Readiness

## Goal

Make pull request 1450 ready to merge by completing the GHDL VHPIDIRECT
backend for `RogueTcpStream`, `RogueTcpMemory`, and `RogueSideBand` without
regressing the existing VCS/VHPI backend.

The completed backend must support multiple elaborated instances and must own
and release each instance's native state explicitly. Pull request 1450 will
preserve the long-standing synchronous ZeroMQ transport behavior used by the
VCS/VHPI implementation.

## Scope

This plan covers:

- Per-instance C state for all three GHDL VHPIDIRECT models.
- An explicit VHPIDIRECT instance-handle API.
- Model creation, lookup, shutdown, and resource cleanup.
- Multi-instance, mixed-model, and lifecycle tests.
- Validation of the shared-core changes against both GHDL and the existing
  VCS/VHPI source path.

This plan does not cover:

- Vivado xsim/DPI support from pull request 1452. That branch must rebase onto
  the completed shared-core design later.
- Changing synchronous ZeroMQ sends, send timeouts, high-water-mark behavior,
  linger behavior, or the handling of absent and stalled peers. Transport
  hardening will be handled in a later pull request across VCS/VHPI,
  GHDL/VHPIDIRECT, and xsim/DPI.
- Replacing the simulator-thread transport with a dedicated worker thread or
  adding native retry queues and HDL backpressure.
- Changing the existing Rogue TCP ZeroMQ wire formats.
- Removing the existing maximum frame and transaction sizes.
- Broad cleanup outside `axi/simlink` and its focused tests.

## Current Status

- Active worktree: `/private/tmp/surf-pr-1450`.
- Active pull request: 1450.
- Baseline head when this plan was created: `c93078330`.
- The worktree was clean before this plan file was added.
- Existing GitHub review threads are resolved.
- Existing bounds checks, GHDL dependency tracking, conda dependencies, and
  platform-gated Valgrind coverage are already present.
- The inherited blocking-send behavior is accepted for pull request 1450 and
  recorded below as cross-backend follow-up work.
- The integer-handle ABI is validated with GHDL 6.0.0 using both scalar and
  vector-return foreign functions.
- Per-instance state, normal-process cleanup, explicit destroy, and port reuse
  are implemented for Stream, Memory, and SideBand.
- A mixed VHPIDIRECT regression now elaborates four Stream, two Memory, and two
  SideBand instances concurrently on distinct endpoint pairs.
- Remaining work is focused on reset/error-path coverage, full serial/xdist
  validation, and final review rather than the original singleton architecture.

## Implementation Progress

Completed locally:

- Added `axi/simlink/ghdl/RogueVhpiDirectRegistry.h`, which provides a
  per-library positive integer handle registry, zero-initialized state
  allocation, stable lookup, duplicate-port detection, explicit destroy, and
  process-exit cleanup.
- Converted every VHPIDIRECT update and getter in `RogueTcpStream`,
  `RogueTcpMemory`, and `RogueSideBand` to take an instance handle.
- Kept reset behavior compatible: a handle survives HDL reset, and port
  validation/reservation occurs only after reset is deasserted.
- Added a native lifecycle regression that creates, binds, destroys, and
  recreates every model on the same endpoint pair.
- Added a mixed-model GHDL regression with four Stream, two Memory, and two
  SideBand instances in the same simulation.
- Installed the already-declared `pyzmq` dependency in the local cocotb
  virtual environment and generated this worktree's imported HDL source graph.

Validation completed locally:

- GHDL shared-library build passes with `-Wall` for all three models.
- Existing raw VHPIDIRECT smoke tests pass for all three models.
- Existing end-to-end wrapper regressions pass: 5 passed, 1 skipped.
- Mixed multi-instance and destroy/rebind lifecycle regressions pass.
- The three production VHPIDIRECT VHDL files pass VSG with zero violations.
- The new mixed-model VHDL harness passes VSG with zero violations.
- Full imported-source `make analysis` passes with the local virtual
  environment's `vhdeps` on `PATH`.
- The complete simlink suite passes serially and with CI work-stealing xdist:
  the final macOS-safe runs report 10 passed, 3 skipped in both modes. Linux CI
  retains the two intentional-abort checks (expected 12 passed, 1 skipped),
  while macOS skips them to avoid system crash-reporter dialogs.

Still required:

- Confirm the Linux-only duplicate-port/invalid-handle abort checks in CI.
- Review or compile the VCS/VHPI consumers to ensure no shared behavior
  regressed; no shared transport-core behavior has changed so far.
- Run GitHub CI and perform the final PR diff/review-thread audit.

## Existing Architecture

The three simulator paths share the protocol and ZeroMQ state machines in:

- `axi/simlink/shared/RogueTcpStreamCore.h`
- `axi/simlink/shared/RogueTcpMemoryCore.h`
- `axi/simlink/shared/RogueSideBandCore.h`

The VCS/VHPI backend allocates one model state object for every elaborated
component and carries that pointer through VHPI callback user data. The GHDL
VHPIDIRECT backend instead uses one file-scope static object per model type and
zero-argument output getters. That makes multiple instances share state and
bind only the first port.

All backends currently execute the shared step function synchronously on the
simulator thread. Receive operations are nonblocking, but send operations can
wait indefinitely for a usable peer or queue capacity. This behavior predates
pull request 1450 and is preserved in this pull request so the new backend
matches the established VCS/VHPI behavior.

## Design Decisions

### Instance identity

Use a positive 32-bit integer handle at the VHDL/C boundary. Do not pass raw C
pointers through VHDL.

Each GHDL model architecture will:

1. Hold a process-local handle variable initialized to zero.
2. Call the model's foreign `create` function on its first rising clock edge.
3. Pass the returned handle to every update and getter call.
4. Treat handle zero as invalid and fail through a VHDL assertion if creation
   fails.

The C side maps handles to dynamically allocated state objects. Handles
must remain stable for the life of the elaborated VHDL instance. Creating a
second live instance for the same model type and TCP port is an error because
the sockets cannot bind the same port pair.

The focused Stream prototype confirmed the exact GHDL ABI for an integer
function return, integer input arguments, scalar returns, and composite vector
returns before the API was applied to Memory and SideBand.

### State ownership

Provide model-specific operations with equivalent behavior:

```text
create() -> handle
lookup(handle) -> state
step(handle, inputs) -> outputs/status
destroy(handle)
destroy_all()
```

Use `calloc` so a new instance has the same zero-initialized state as the
existing static objects. Keep the current reset semantics: HDL reset clears
protocol state but does not destroy/rebind the native instance.

Where practical, move duplicated state definitions used by GHDL and VCS into
shared type headers. Shared lifecycle fields must not drift between
backend-specific copies of the structures.

### Lifecycle

Register one process-exit cleanup handler per loaded GHDL model library. Normal
shutdown must:

1. Close every PULL and PUSH socket using the existing transport semantics.
2. Terminate each instance's ZeroMQ context.
3. Release dynamically allocated instance state.
4. Clear the registry so a native lifecycle harness can create the same port
   again.

Expose `destroy(handle)` for focused C tests even though a static VHDL
elaboration normally lives until simulator exit.

The VCS path should use the same model cleanup functions. Add an
end-of-simulation VHPI cleanup callback if it can be done without changing the
public VHDL entity or callback timing. If simulator-version compatibility makes
that unsafe, preserve VCS behavior and record it as a follow-up; GHDL cleanup
remains required for this pull request.

### Transport compatibility for pull request 1450

Do not change the shared send/receive policy in this pull request. In
particular:

- Keep receive calls nonblocking as they are today.
- Keep synchronous send calls and the existing ZeroMQ socket defaults.
- Do not add Stream backpressure, Memory response retry state, SideBand event
  queues, `ZMQ_IMMEDIATE`, or new send/linger settings.
- Keep the Rogue TCP multipart wire formats unchanged.

The expected operating contract remains that the Rogue peer is connected and
draining traffic before the HDL model produces outbound messages. This is the
same contract under which the VCS/VHPI implementation has historically been
used.

### Future cross-backend transport hardening

Create a later pull request after pull requests 1450 and 1452 have converged on
the shared model cores. It must address VCS/VHPI, GHDL/VHPIDIRECT, and xsim/DPI
together so the simulator backends do not acquire different transport
semantics.

Start that work with characterization tests against the unmodified legacy
behavior:

- No PUSH peer connected when an outbound message is produced.
- A peer that connects and then stops reading.
- A deliberately small send high-water mark that reaches saturation quickly.
- Peer disconnect during Stream, Memory, and SideBand traffic.
- Shutdown or restart while unsent messages remain queued.
- Proof that simulation time either advances or fails within a fixed deadline.

The lowest-risk hardening option is fail-fast rather than transparent retry:

1. Add `ZMQ_DONTWAIT` to every send while preserving `ZMQ_SNDMORE` framing.
2. Set `ZMQ_SNDTIMEO` to zero as defensive configuration.
3. Set `ZMQ_LINGER` to zero so close/context termination cannot wait for an
   absent peer.
4. Treat `EAGAIN` as a clear model/port-specific simulation failure.
5. Verify that normal connected-peer behavior and wire data are unchanged.

If later requirements call for surviving peer stalls instead of failing, make
that a separately reviewed semantic change. Stream would need retained frames
and AXI backpressure, Memory would need retained response state, and SideBand
would need an explicit bounded-event policy because it has no ready signal.
Multipart retry would also need to preserve partial-send progress correctly.

A shared ZeroMQ context or dedicated transport worker can be evaluated in that
future work, but should not be assumed necessary before the fail-fast approach
has been characterized.

## Implementation Milestones

### 1. Prove the VHPIDIRECT handle ABI

- Add a minimal Stream `create` function returning an integer handle.
- Store the handle in the VHDL process and pass it back to update/getters.
- Elaborate and run a single-instance Stream smoke test.
- Add a second Stream instance and prove the calls resolve different state.

Exit criteria:

- Both instances advance independently and bind distinct port pairs.
- No static `RogueTcpStreamData` singleton remains in the GHDL adapter.
- The smoke test works with the same GHDL backend and flags used in CI.

### 2. Complete per-instance state

- Generalize the registry/handle pattern for Stream, Memory, and SideBand.
- Pass handles to every VHPIDIRECT update and getter.
- Reject invalid handles, duplicate live ports, and allocation failures.
- Remove the current single-instance guards and singleton diagnostics.

Exit criteria:

- At least four Stream instances, two Memory instances, and two SideBand
  instances can coexist without state or port crossover.
- The existing single-instance tests remain unchanged in observable behavior.

### 3. Complete lifecycle handling

- Add close/destroy functions to each shared model core.
- Register normal-process cleanup for GHDL.
- Add a native harness that creates, destroys, and recreates each model on the
  same port.
- Run the lifecycle harness under Valgrind on supported Linux systems.

Exit criteria:

- Port reuse succeeds after destroy.
- No model-owned allocations or ZeroMQ sockets remain reachable after normal
  harness shutdown when the peer follows the existing connected/draining
  contract.
- The harness does not alter the shared transport policy solely to exercise
  cleanup; shutdown-with-pending-data belongs to the future transport work.

### 4. Add integration regressions

Add focused wrappers/tests for:

- Four simultaneous Stream port pairs with independent bidirectional traffic.
- Multiple Memory instances issuing independent reads and writes.
- Multiple SideBand instances exchanging independent events.
- Stream, Memory, and SideBand active in the same GHDL simulation.
- Repeated HDL reset after sockets have been initialized.
- Native destroy/recreate and port reuse.

Every wait on a peer or transaction must have a simulation-cycle or wall-clock
timeout so a regression reports failure instead of hanging CI.

Exit criteria:

- Tests fail against the singleton baseline and pass with the new
  implementation.
- The multi-instance test exercises the actual VHPIDIRECT boundary, not only a
  C registry unit test.
- The suite passes both serially and with the repository's xdist settings.

### 5. Final validation and review

Run, at minimum:

```text
make -C axi/simlink/ghdl clean all
./.venv/bin/python -m pytest -q -n 0 tests/axi/simlink
./.venv/bin/python -m pytest -q -n auto --dist=worksteal tests/axi/simlink
make MODULES="$PWD" import
```

Also run:

- VSG on every edited VHDL file.
- C/C++ lint on edited C and header files.
- Native lifecycle/bounds harnesses, with Valgrind when available.
- GHDL analysis of the imported SURF source graph.
- `git diff --check`.
- The full GitHub CI workflow.
- A final review-thread and PR-diff audit.

The VCS/VHPI libraries cannot necessarily be executed locally without VCS, so
at least compile/lint their shared-header consumers where possible and review
all shared-core changes for callback and port behavior compatibility.

## Expected Files

The implementation is expected to touch:

- `axi/simlink/ghdl/RogueTcpStream.{c,h,vhd}`
- `axi/simlink/ghdl/RogueTcpMemory.{c,h,vhd}`
- `axi/simlink/ghdl/RogueSideBand.{c,h,vhd}`
- `axi/simlink/ghdl/RogueVhpiDirect.h`
- `axi/simlink/shared/RogueTcpStreamCore.h`
- `axi/simlink/shared/RogueTcpMemoryCore.h`
- `axi/simlink/shared/RogueSideBandCore.h`
- Corresponding VCS headers/adapters if state types or cleanup hooks are shared.
- `axi/simlink/wrappers/` for multi-instance cocotb-facing wrappers.
- `tests/axi/simlink/` for native and cocotb regressions.

Update `axi/simlink/ghdl/Makefile` if new shared headers or harness sources need
dependency or build rules.

## Risks and Mitigations

- GHDL ABI differences: prove the handle signature first and retain a
  port-keyed registry fallback.
- Inherited blocking sends: retain the established requirement that the Rogue
  peer be connected and draining. Track no-peer, saturation, disconnect, and
  linger behavior in the cross-backend transport follow-up described above.
- Larger per-instance memory usage: keep the existing validated bounds; dynamic
  payload allocation is a possible follow-up unless realistic multi-instance
  tests show the fixed buffers are prohibitive.
- VCS regression risk: keep public entities unchanged, centralize shared state
  fields, and avoid VHPI callback timing changes except for optional shutdown
  cleanup.
- CI hangs: every new peer process and cocotb wait must have cleanup in a
  `finally` block and a finite timeout.

## Progress Log

### Plan creation

- Confirmed pull request 1450 is the active scope.
- Confirmed the existing review threads are resolved.
- Recorded explicit instance handles, lifecycle cleanup, and multi-instance
  regressions as merge requirements.
- Deferred nonblocking/fail-fast transport changes to a later pull request
  spanning VCS/VHPI, GHDL/VHPIDIRECT, and xsim/DPI.
- No implementation or validation has been performed under this plan yet.

## Next Step

Implement milestone 1 as a narrow Stream-only ABI prototype. Do not refactor
Memory or SideBand until the integer-handle round trip works in a real GHDL
VHPIDIRECT simulation with two Stream instances.
