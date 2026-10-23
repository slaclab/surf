# SimLink Alignment and Hardening

## Goal and status

Align the GHDL/VHPIDIRECT, VCS/VHPI, and Vivado xsim/DPI SimLink backends
around shared transport, lifecycle, and protocol-core code while preserving
the public `Rogue*Wrap` interfaces and established Rogue wire protocols.

Status: implementation and review are complete on `simlink-alignment`. SimLink
is now a top-level SURF subsystem under `simlink/`, with executable tests under
`tests/simlink/`. User and maintainer documentation starts at
[`simlink/README.md`](../../../simlink/README.md); test architecture and commands
are in [`tests/simlink/README.md`](../../../tests/simlink/README.md).

## Delivered architecture

- `simlink/shared/` owns the common ZeroMQ transport, complete adjacent-port
  reservation, instance lifecycle, multipart codecs, and deterministic Stream,
  Memory, and SideBand model behavior.
- `simlink/ghdl/`, `simlink/vcs/`, and `simlink/xsim/` contain thin
  simulator-specific adapters using VHPIDIRECT, VHPI, and DPI-C respectively.
- Each backend builds one descriptively named combined shared library and uses
  one process-wide instance registry across all three model types.
- `simlink/sim/` contains the stable record-based SURF wrappers and the
  deterministic aggregate Stream payload pacer.
- `simlink/test/` contains test-only HDL/SystemVerilog harnesses; Python
  orchestration and protocol peers live under `tests/simlink/`.
- GHDL and VCS reuse the same active eight-instance VHDL topology and cocotb
  traffic scenario. xsim uses the same peer allocation and result contract
  through a self-driving mixed-language top.
- Stream supports payload widths from 1 through 128 bytes per beat. The public
  wrappers retain existing interface names and wire semantics.

## Compatibility and design decisions

- The public compatibility surface is `RogueTcpStreamWrap`,
  `RogueTcpMemoryWrap`, and `RogueSideBandWrap`; backend leaves are integration
  details.
- Existing multipart order, field sizes, host byte order, socket directions,
  transaction identifiers, and SSI/AXI sideband behavior remain unchanged.
- Memory ordinary responses remain four-byte numeric AXI responses. Only the
  `TcpBridgeProbe` readiness response uses ASCII `OK`, as required by
  `TcpClient.waitReady()`.
- One worker exclusively owns each model's ZeroMQ context and sockets. Complete
  inbound messages cross a bounded 16-entry FIFO; the worker stops draining
  rather than dropping or overwriting an entry.
- Each instance reserves its complete adjacent TCP port pair before either bind
  and releases it only after both sockets close.
- Transport waits and shutdown are bounded. The positive-decimal
  `SURF_SIMLINK_TRANSPORT_TIMEOUT_MS` override controls model deadlines.
- Stream pacing is based on simulated payload-byte credit and completed AXI
  Stream handshakes. It is independent of host scheduling and transport queue
  depth and intentionally does not model encoding or frame overhead.
- VCS teardown remains passive at `$finish`: registering a VHPI end-of-
  simulation callback conflicts with cocotb's VPI shutdown in VCS. Process exit
  and `atexit(rogueSimLinkDestroyAll)` own cleanup; direct cleanup remains
  available to the native lifecycle harness.

## Review closeout

The final review and hardening passes resolved the following material defects:

- Bounded `RogueTcpStreamWrap` channel mapping for non-power-of-two channel
  counts and rejected `CHAN_COUNT_G = 0` at elaboration.
- Corrected VCS VHPI port-direction validation where standard `vhpiIn` is zero.
- Removed the VCS mixed-VHPI/VPI end-of-simulation callback that caused
  teardown segfaults, and updated the native lifecycle harness accordingly.
- Added NULL guards and removed signed-shift undefined behavior in the VCS
  adapter.
- Centralized fixed test-port allocation and added overlap checks for xdist.
- Replaced timing-sensitive peer startup assumptions with explicit readiness
  and bounded wall-clock completion.
- Closed the ZeroMQ PUSH slow-joiner window by waiting for
  `ZMQ_EVENT_HANDSHAKE_SUCCEEDED` before first send and using bounded linger so
  queued fire-and-forget frames are flushed during peer teardown.
- Made shared-library staging atomic so parallel tests never rewrite a mapped
  library in place.
- Kept simulator relaunch peers alive for the full compile/elaboration/run
  budget and kept clocking until every expected inbound observation arrives.
- Consolidated socket helpers, malformed-input coverage, lifecycle checks, and
  native transport bounds/overload tests.

No unresolved product-code defect remains in the completed alignment scope.

## Verification

Verification on the final synchronized PR head included:

- GitHub CI: lint, regression, documentation, and the required production
  Rogue Memory contract all passed.
- Local open-source suite on macOS: 94 passed and 13 expected skips. The skips
  were five Linux-only abort/Valgrind cases, three separately provisioned Rogue
  contracts, two licensed VCS cases, and three Vivado xsim cases.
- Flake8 passed for the changed Python test code.
- VSG reported zero violations across all 22 SimLink VHDL files.
- `make MODULES="$PWD" import` completed and loaded the top-level `simlink`
  ruckus manifest.
- All SimLink runner scripts passed `bash -n`.
- Licensed VCS X-2025.06 evidence covers both the active multi-instance test and
  the two-`simv` persistent-peer relaunch test.
- Licensed Vivado 2025.2 evidence covers mixed-language elaboration,
  multi-instance isolation, duplicate-port rejection, and repeated active
  traffic after the slow-joiner fix.

Generated simulator output remains under `tests/sim_build/simlink/` and is not
part of this handoff.

## Remaining risks and follow-ups

These are deliberate follow-ups, not merge blockers:

- Hosted CI does not provide licensed VCS or Vivado tools. Add a self-hosted
  licensed job for `run-vcs.sh` and `run-xsim.sh` when suitable infrastructure
  is available.
- The required real-Rogue CI job currently exercises Memory. Promote the
  checked-in Stream and SideBand Rogue contracts into that required job.
- VCS proves shared active traffic and relaunch but does not yet mirror every
  GHDL wrapper boundary/error case. Extend the existing VPI bridge pattern for
  deeper wrapper coverage.
- Exact in-place VCS GUI/UCLI re-exec and xsim `restart`/`relaunch_sim`
  lifecycle commands remain distinct from the covered process-relaunch
  contract and need tool-specific tests.
- Stream and SideBand have no production readiness transaction equivalent to
  Memory's `TcpBridgeProbe`; callers must account for asynchronous connection
  establishment.
- Stream currently allocates fixed 20,000,000-byte inbound and outbound
  buffers per instance. A future allocation redesign could reduce idle memory
  without changing the wire protocol.
- The identical non-power-of-two channel-map defect on the legacy `master`
  branch is outside this PR and remains a maintainer decision.
