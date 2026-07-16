# Xsim Co-Simulation Review Remediation

## Goal

Make pull request 1452 ready for re-review by:

- Giving every elaborated xsim/DPI Stream, Memory, and SideBand model
  independent native state and ZeroMQ ownership.
- Supporting established multi-instance users, including
  `RogueTcpStreamWrap(CHAN_COUNT_G > 1)` and the four-link PGP/HTSP simulation
  configurations identified in review.
- Replacing the README's nonexistent demo tops and peer scripts with runnable,
  in-repository usage and explicit external-target requirements.
- Documenting why synchronous ZeroMQ sends remain unchanged in this pull
  request and carrying transport hardening into a later cross-backend change.

Preserve the existing public VHDL entities, Rogue TCP wire formats, and
established transport behavior.

## Baseline and Dependency

- Active worktree: `/private/tmp/surf-pr-1452`.
- Active pull request: 1452.
- Active branch: `cosim-xsim`.
- Planning baseline: `f4a4927a0234aa0a558f368c4f9cf910d6dd6811`.
- Pull request 1452 targets
  `ci-RogueTcpMemoryWrap-RogueTcpStreamWrap`, the pull request 1450 branch.
- Pull request 1450 completed per-instance VHPIDIRECT state and lifecycle at
  `989731d754e729d3866308e7529c0c2842a73695`; its current documentation head
  is `8d845e696`.

Before implementation, rebase `cosim-xsim` onto the latest accepted pull
request 1450 head or the descendant where pull request 1450 is merged. Retain
the xsim backend-selection work while accepting the completed shared-core
bounds fixes, tagged peer vectors, per-instance ownership precedent, and
VHPIDIRECT lifecycle tests.

The current local environment does not expose `xsc`, `xvlog`, or `xsim`.
The DPI ABI and end-to-end xsim milestones therefore require a Vivado-enabled
environment. GHDL regressions and source/lint checks can run locally after the
rebase.

## Review Findings and Disposition

Pull request 1452 currently has three unresolved review threads.

### 1. Global DPI state breaks multiple instances

The xsim adapters in:

- `axi/simlink/xsim/RogueTcpStream.c`
- `axi/simlink/xsim/RogueTcpMemory.c`
- `axi/simlink/xsim/RogueSideBand.c`

each contain one file-scope state object. Every elaborated SystemVerilog DPI
leaf calls the same exported function, so instances share protocol state,
frame buffers, sockets, and the first bound port. The current different-port
guards only turn that corruption into an intentional abort.

Disposition: implement an explicit per-instance API for all three models and
add active mixed-model xsim coverage. Although the first planning pass focused
on Stream, resolving the posted review finding requires Memory and SideBand as
well.

### 2. Documented demos do not exist

`axi/simlink/README.md` names three `*XsimDemoTb` tops and three peer scripts
that are not present in this pull request, its base, or the SURF repository.
The documented `set_property top` procedure is therefore not runnable.

Disposition: remove the nonexistent names and use the checked-in xsim
regression harness as the runnable example. Document exactly what SURF
provides and what an external target must provide.

### 3. Synchronous sends can freeze simulation

The review correctly observes that all three shared cores perform ZeroMQ sends
synchronously on the simulator thread. This behavior is not introduced by the
xsim adapter: the same shared send functions are used by VCS/VHPI and
GHDL/VHPIDIRECT.

Pull request 1450 explicitly records the accepted operating contract:

- Receive remains nonblocking.
- Send remains synchronous with existing ZeroMQ socket defaults.
- The Rogue peer must be connected and draining before HDL produces outbound
  messages.
- No retry queues, AXI Stream backpressure, Memory response retention,
  SideBand event queues, `ZMQ_IMMEDIATE`, or new linger/send-timeout settings
  are added while the simulator backends are being brought to parity.

That plan also requires transport hardening to occur later across VCS, GHDL,
and xsim together. Changing only pull request 1452 would make the xsim backend
semantically different from the established VCS path and the completed
VHPIDIRECT implementation. Surviving `EAGAIN` would additionally require
model-specific retained state and externally visible policy changes:

- Stream needs retained frames and AXI backpressure.
- Memory needs retained responses and transaction gating.
- SideBand needs an explicit bounded-event or overflow policy because it has
  no ready signal.
- Multipart retry must preserve partial-send progress.

Disposition: do not implement transport hardening in pull request 1452. Add a
clear README warning describing the connected-and-draining peer contract, and
prepare a review response explaining that the hazard is acknowledged,
inherited, and deliberately deferred to the cross-backend follow-up already
recorded by pull request 1450.

The later transport change should begin with no-peer, stalled-peer, saturation,
disconnect, and teardown characterization. Pull request 1450 recommends
evaluating fail-fast nonblocking sends before retained retry queues:
`ZMQ_DONTWAIT`, zero send timeout, zero linger, and a model/port-specific
failure on `EAGAIN`.

## Scope

This plan covers:

- Per-instance xsim/DPI state for Stream, Memory, and SideBand.
- A DPI `chandle` per SystemVerilog leaf and explicit
  create/update/destroy APIs.
- A small C live-instance manager for cleanup and port-pair reservation, not
  for per-edge integer-handle dispatch.
- Port reservation, invalid-context checks, normal shutdown, and process-exit
  cleanup.
- Active mixed-model xsim coverage with at least four Stream instances and
  two each of Memory and SideBand.
- Repeated reset, duplicate-port, wrong-model-context, and lifecycle tests.
- Runnable xsim documentation based only on files checked into SURF.
- Documentation of the existing connected-and-draining peer requirement.
- A concise proposed response for each unresolved review thread.
- Regression checks for the completed GHDL/VHPIDIRECT work and shared VCS
  consumers.

This plan does not cover:

- Changing synchronous send behavior, send timeouts, high-water marks, linger,
  absent/stalled-peer behavior, or teardown transport policy.
- Adding retry queues, a transport worker, or new HDL backpressure.
- Changing the Rogue TCP multipart wire formats.
- Removing the existing maximum frame or transaction sizes.
- Broad cleanup outside `axi/simlink` and focused tests.

## Existing Architecture

Each xsim VHDL model instantiates one matching SystemVerilog DPI leaf:

```text
VHDL model instance
  -> SystemVerilog Rogue*Dpi module instance
     -> exported C rogue*Update()
        -> shared Rogue*Step()
           -> ZeroMQ transport
```

The SystemVerilog leaf is already elaborated per VHDL instance, making it the
natural owner of an opaque instance handle. The current C adapter discards
that identity by routing every call to a file-scope singleton.

The shared Stream, Memory, and SideBand cores are included by VCS/VHPI,
GHDL/VHPIDIRECT, and xsim/DPI adapters. This pull request will use them without
changing transport semantics.

## Design Decisions

### Instance identity

Use SystemVerilog DPI's native `chandle` type for xsim instance identity. AMD
documents `chandle` as a supported Vivado simulator DPI boundary type mapped
directly to C `void *`. GHDL needs a positive integer because its VHPIDIRECT
boundary does not provide an equivalent portable pointer type; xsim should not
inherit that workaround when DPI already supplies the intended opaque-state
API.

Each `chandle` points to a C-owned `RogueDpiInstance` object containing:

- A model tag and validation magic.
- The reserved two-port endpoint pair, once established.
- A zero-initialized model-specific state allocation.
- A model-specific cleanup callback.
- Links used only by the live-instance/normal-exit cleanup list.

The per-edge fast path casts the `chandle`, validates its magic and model tag,
and accesses the state directly. It must not perform a process-global linear
integer-handle lookup on every clock edge. The live-instance list is scanned
only for infrequent operations such as port reservation and cleanup.

Each elaborated `RogueTcpStreamDpi`, `RogueTcpMemoryDpi`, and
`RogueSideBandDpi` module will:

1. Hold a module-local `chandle`, initially `null`.
2. Lazily call its model-specific create function on the first rising edge.
3. Call SystemVerilog `$fatal` if creation returns `null`.
4. Pass the retained `chandle` to every update call.
5. Call SystemVerilog `$fatal` if an update reports an ownership or port
   validation failure.
6. Call its model-specific destroy function from a SystemVerilog `final`
   block on normal shutdown.

Use a plain simulation-only `always @(posedge clock)` block rather than
`always_ff`: the block performs foreign side effects, lazily assigns a
`chandle`, and drives outputs through DPI output arguments. Lazy first-edge
creation avoids a time-zero ordering race between an `initial` constructor and
the first clock event, and matches the GHDL create-on-first-edge lifecycle.

Declare create/update/destroy as ordinary impure DPI imports. Do not mark them
`pure`; they allocate, mutate, bind sockets, and free resources. Do not mark
them `context` because they do not call exported SystemVerilog routines or use
scope-sensitive DPI services.

The leaf pattern is:

```systemverilog
import "DPI-C" function chandle rogueModelCreate();
import "DPI-C" function int rogueModelUpdate(input chandle context, ...);
import "DPI-C" function void rogueModelDestroy(input chandle context);

chandle context = null;

always @(posedge clock) begin
   if (context == null) begin
      context = rogueModelCreate();
      if (context == null) $fatal(1, "Rogue model creation failed");
   end
   if (!rogueModelUpdate(context, ...))
      $fatal(1, "Rogue model update failed");
end

final begin
   if (context != null) rogueModelDestroy(context);
end
```

The actual imports remain model-specific and retain the existing typed data
arguments. The update status is for ownership/port validation at the adapter
boundary; normal model outputs remain DPI output arguments.

The first implementation milestone must prove `chandle` return/input
marshalling, per-module variable retention, and DPI calls from `final` with the
supported Vivado versions. If `final` is unreliable in a supported version,
`atexit()` cleanup remains mandatory and the limitation must be documented.

### Live-instance manager

Add one compiled instance manager to the combined `RogueTcpDpi.so` rather than
three unrelated header-local registries. It will provide:

```text
create(model, data_size, cleanup) -> chandle
get_data(chandle, expected_model) -> state
reserve_port(chandle, base_port)
destroy(chandle)
destroy_all()
```

Use `calloc` for model state so new instances retain the current
zero-initialized behavior. The combined manager tracks all live contexts and
can reject overlapping live port pairs across model types before ZeroMQ bind.

Reject:

- `null`, bad-magic, and wrong-model contexts.
- Zero base ports and base ports whose `port + 1` is invalid.
- Two live contexts reserving overlapping port pairs.
- A live context whose requested port changes after reservation.
- Allocation and cleanup-registration failures.

Reserve ports only after HDL reset is deasserted. Contexts survive HDL reset;
reset clears protocol state but does not destroy sockets, recreate state, or
change the reserved port.

### Lifecycle

Each managed instance owns one model state allocation and a model-specific
cleanup callback. Cleanup must:

1. Close the model's PUSH and PULL sockets using the inherited transport
   semantics.
2. Terminate the instance's ZeroMQ context.
3. Free model state and remove the live-list entry.

Register one process-exit cleanup handler for the combined xsim manager.
Explicit `final` destruction removes entries first, so later process-exit
cleanup is a no-op for those instances. Native lifecycle coverage must prove
create/bind/destroy/recreate on the same port for all three models.

Keep ownership failures at the DPI boundary recoverable long enough for the
SystemVerilog leaf to issue `$fatal`; do not call C `abort()` for expected
constructor, context-validation, or port-reservation errors. This preserves
xsim diagnostics and gives normal `final`/cleanup handling a chance to run.
The inherited shared-core assertion mechanism remains unchanged in this pull
request.

### DPI type and prototype discipline

Use the types from `svdpi.h` in C signatures: `svBit` for SystemVerilog `bit`,
`svBitVecVal` for packed bit vectors, and `void *` for `chandle`. Do not rely on
locally assumed `unsigned char` aliases even if they happen to match the
current xsim typedefs.

Add an xsim ABI validation target that runs `xelab -dpiheader` and compiles the
C adapters against the generated declarations. AMD documents this flow as the
way to obtain the simulator's exact C prototypes. The generated header is a
build artifact, not a checked-in source file. This target must catch any
signature drift in return type, argument order, direction, width, or
`const`/pointer mapping.

Vivado xsim also provides `svGetScope`, `svPutUserData`, and `svGetUserData`.
Do not use scope user data for primary ownership here: it would require
scope-aware/context imports, couple state to elaborated hierarchy, and add
lookup machinery despite each SystemVerilog leaf already having a natural
module-local `chandle`. Scope APIs remain a fallback only if a supported xsim
version fails the explicit `chandle` prototype.

### Runnable documentation

Remove references to nonexistent `RogueTcpStreamXsimDemoTb`,
`RogueTcpMemoryXsimDemoTb`, `RogueSideBandXsimDemoTb`,
`prbsLoopbackDemo.py`, `axiVersionMemoryDemo.py`, and
`sideBandDemo.py` unless those exact files are added.

Use the checked-in xsim regression harness as the runnable example. Document:

- The exact command that builds `RogueTcpDpi.so`.
- The exact command that elaborates and runs the checked-in xsim example.
- Required tools and environment variables.
- How ruckus selects the xsim backend and binds `-sv_lib RogueTcpDpi`.
- What an external target must provide: clock/reset, model or wrapper
  instances, unique base ports, a simulation top, and a compatible
  Rogue/ZeroMQ peer.
- The requirement that peers connect and drain before outbound HDL traffic.
- Which files are SURF examples versus external application code.

## Implementation Milestones

### 1. Rebase and establish a green baseline

- Rebase onto the completed pull request 1450 head or merged descendant.
- Resolve `axi/simlink/ruckus.tcl` by retaining all three backend choices and
  xsim stale-source cleanup.
- Retain the xsim combined-library build and accept pull request 1450's
  shared-core and test changes.
- Run the complete GHDL simlink suite before new ownership work.

Exit criteria:

- The branch contains both completed VHPIDIRECT support and the xsim backend.
- Existing single-, multi-instance, bounds, and lifecycle GHDL tests pass.
- Shared transport semantics remain unchanged.

### 2. Prove the xsim DPI `chandle` ABI

- Prototype create/update/destroy on two instances of each DPI leaf.
- Confirm non-null contexts are distinct and retained independently.
- Confirm normal finish invokes explicit destroy without double cleanup.
- Generate the DPI C header with `xelab -dpiheader` and compile the prototype
  against it.
- Record the Vivado version and exact compile/elaboration commands.

Exit criteria:

- `chandle` return/input marshalling is proven in xsim.
- `final` behavior is proven or a documented `atexit()` fallback is selected.
- No model requires a file-scope singleton.

### 3. Implement per-instance xsim state for all models

- Add the compiled xsim instance manager.
- Add model-specific create and destroy entry points.
- Add a `chandle` context argument to all three DPI update signatures.
- Replace each singleton with direct model state obtained from its context.
- Reserve and validate ports after reset deassertion.
- Add model-specific cleanup callbacks and combined process-exit cleanup.
- Update xsim Makefile source/header dependencies and add DPI-header ABI
  validation.

Exit criteria:

- Four Stream, two Memory, and two SideBand instances coexist on distinct port
  pairs.
- State, buffers, FSMs, sockets, and contexts do not cross between instances.
- Null contexts, wrong-model contexts, duplicate/overlapping ports, and
  changed ports fail clearly.
- Existing one-instance xsim behavior remains compatible.

### 4. Add mixed-model xsim regressions

Port the active VHPIDIRECT mixed-model strategy to xsim:

- Four Stream instances exchange uniquely tagged frames in both directions.
- Two Memory instances perform independent tagged write/read transactions.
- Two SideBand instances exchange independent tagged events.
- All eight instances run concurrently in one xsim process.
- Repeated reset after socket initialization preserves contexts and port
  ownership.
- `RogueTcpStreamWrap(CHAN_COUNT_G => 4)` elaborates and advances.
- Native create/destroy/recreate proves same-port reuse.
- Negative tests cover null/wrong-model contexts and overlapping live port
  pairs.

Peers must be connected and draining before outbound HDL traffic, matching the
accepted transport contract. Use bounded waits, peer timeouts, and
unconditional child-process cleanup. Tests requiring Vivado must skip
explicitly when tools are absent; they must not substitute GHDL while claiming
xsim coverage.

Exit criteria:

- The active test fails against the singleton baseline and passes with the
  per-instance context design.
- Every peer receives only its own tagged traffic.
- Repeated and serial runs release ports and leave no simulator or peer
  processes behind.

### 5. Replace nonexistent demos with runnable documentation

- Remove fictional top/script names.
- Check in the thin xsim harness and runner used by regression.
- Add exact build/run commands and expected success output.
- Document external-target integration, unique port allocation, and the
  connected-and-draining peer contract.
- Ensure the nearest ruckus manifest loads required HDL/SV sources.

Exit criteria:

- Every documented command and referenced file exists.
- A user in a Vivado-enabled shell can run the example without inventing a
  testbench or peer script.
- Documentation distinguishes checked-in examples from external project
  responsibilities.

### 6. Final validation and review-response audit

Run, at minimum, in a Vivado-enabled environment:

```text
make -C axi/simlink/xsim clean all
<checked-in xsim mixed-model regression command>
<checked-in xsim lifecycle and negative-path command>
```

Also run:

```text
./.venv/bin/python -m pytest -q -n 0 tests/axi/simlink
./.venv/bin/python -m pytest -q -n auto --dist=worksteal tests/axi/simlink
make MODULES="$PWD" import
git diff --check
```

Run VSG on edited VHDL, lint/compile edited SystemVerilog, and warning-enabled C
compilation. Compile or analyze VCS shared-core consumers even if licensed VCS
execution is unavailable. Record the Vivado version used for DPI and
end-to-end validation.

Prepare responses for the unresolved threads:

1. Link the per-instance context manager, mixed-model test, and wrapper elaboration
   evidence.
2. Link the corrected README and checked-in runnable harness.
3. Acknowledge the blocking-send hazard, cite the established VCS/GHDL
   connected-and-draining contract, explain why xsim-only hardening would
   break backend parity, and point to the planned cross-backend follow-up.

Exit criteria:

- Focused xsim ownership, active traffic, reset, and lifecycle tests pass.
- The complete GHDL simlink suite passes serially and with CI xdist settings.
- Every unresolved review finding has code/documentation evidence or a
  technically supported scope response ready for re-review.
- No GitHub reply or thread resolution occurs until explicitly requested.

## Expected Files

The implementation is expected to touch:

- `axi/simlink/xsim/RogueDpiInstance.{c,h}`
- `axi/simlink/xsim/RogueTcpStream.{c,h}`
- `axi/simlink/xsim/RogueTcpMemory.{c,h}`
- `axi/simlink/xsim/RogueSideBand.{c,h}`
- `axi/simlink/xsim/RogueTcpStreamDpi.sv`
- `axi/simlink/xsim/RogueTcpMemoryDpi.sv`
- `axi/simlink/xsim/RogueSideBandDpi.sv`
- `axi/simlink/xsim/Makefile`
- `axi/simlink/README.md`
- The nearest `ruckus.tcl` if the runnable harness needs manifest integration
- Thin xsim harnesses and focused tests under `axi/simlink/wrappers/` and
  `tests/axi/simlink/`

The shared `Rogue*Core.h` transport implementation and public VHDL entity
interfaces should remain unchanged in this pull request.

## Risks and Mitigations

- **Vivado DPI differences:** Prove `chandle` returns, per-module storage,
  generated-header conformance, and `final` behavior before generalizing.
- **Stacked-branch conflicts:** Rebase first and do not duplicate or revert
  pull request 1450's completed fixes.
- **Large Stream allocations:** Four Stream states consume substantial memory
  because each has two fixed `MAX_FRAME` buffers. Record xsim memory use;
  dynamic payload allocation is separate work unless testing shows the current
  model is impractical.
- **Port collisions:** Reserve the complete two-port endpoint pair before
  binding and report both conflicting contexts/models.
- **Cleanup can inherit blocking linger behavior:** Run lifecycle tests only
  under the accepted connected-and-draining contract. Teardown hardening stays
  with the later cross-backend transport work.
- **Reviewer may require transport work in this PR:** Present the documented
  pull request 1450 decision and backend-parity rationale. If maintainers
  explicitly reject that scope, stop and re-plan a separate cross-backend
  change rather than adding xsim-only semantics.
- **No Vivado in default CI/local environment:** Provide deterministic
  commands, explicit skips, and a recorded Vivado-enabled validation run before
  merge.

## Proposed Blocking-Send Review Response

The underlying concern is valid, but the blocking send behavior predates this
xsim adapter and is shared by the VCS/VHPI and GHDL/VHPIDIRECT paths through
the same `Rogue*Core.h` functions. Pull request 1450 deliberately preserved
that behavior while establishing per-instance state, with the operating
contract that the Rogue peer is connected and draining before HDL produces
outbound traffic.

Changing only pull request 1452 would make xsim behavior differ from the other
simulator backends. Retrying `EAGAIN` is also not a local flag change: Stream
needs retained frames and backpressure, Memory needs retained responses, and
SideBand needs a bounded-event policy. Pull request 1450 records this as a
separate cross-backend hardening effort after pull requests 1450 and 1452
converge, beginning with no-peer/saturation characterization and a fail-fast
nonblocking option.

For pull request 1452, preserve backend parity, document the
connected-and-draining peer requirement in the public README, and limit the
implementation to per-instance xsim ownership, lifecycle, runnable examples,
and active connected-peer regressions.

## Acceptance Criteria

The work is complete when:

1. Four xsim Stream, two Memory, and two SideBand instances exchange active,
   isolated traffic in one simulation.
2. `RogueTcpStreamWrap(CHAN_COUNT_G => 4)` elaborates and advances under
   xsim.
3. Contexts and reserved ports survive HDL reset; destroy permits same-port
   reuse.
4. Null/wrong-model contexts and overlapping live port pairs fail clearly.
5. Every README command and referenced example file exists and runs in the
   documented environment.
6. The README states the connected-and-draining peer contract and identifies
   transport hardening as cross-backend follow-up work.
7. Existing one-instance behavior, wire formats, shared transport semantics,
   public VHDL interfaces, and the complete GHDL simlink regression remain
   compatible.
8. All three unresolved PR 1452 review threads have corresponding
   implementation evidence or a documented scope response ready for re-review.
