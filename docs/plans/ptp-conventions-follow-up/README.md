# PtpCore conventions follow-up

## Goal and scope

Survey all 15 RTL/package files and seven wrappers in `ethernet/PtpCore`
against [SURF VHDL conventions](../../vhdl-conventions.md), then make the
compliance edits authorized during review. Starting revision:
`a48b07ef1b96dee81b66a2a64c463e752173911f` (2026-09-18).

## Status and decisions

The survey, compliance edits and permitted build checks are complete. All 22
files have been read. The review covered process/state ownership, publication
and reset order, retained
versus temporary values, registered boundaries, cancellation/backpressure,
clock domains, parameter/arithmetic conventions, local AXI banks, package
contracts, headers, wrapper structure and ruckus membership. Public entity
declarations, register ABI and documented interface timing are preserved.
The previous reviews remain historical design records.

## Findings and changes

1. **Reset before publication:** `PtpEndpoint`, `PtpPhc`, `PtpPort`, `PtpReg`,
   `PtpRxFrontend`, `PtpServo`, `PtpTxLedger` and `PtpRegWrapper` published
   outputs before the final synchronous reset override. Moved the existing
   override and `rin <= v` ahead of those publications, following
   [reset ordering](../../vhdl-conventions.md#apply-reset-before-publishing-outputs).
   Registered outputs still use `r`; wiring and reset-distribution scratch
   remain independent of `v`. The port already suppresses all three ready
   outputs through its reset-qualified abort path; the servo already clears
   measurement ready explicitly during reset. Their ready values therefore
   remain low before and after this reordering, for both supported reset modes.
2. **Timing documentation:** Removed comments instructing publication before
   reset. Corrected the RX overflow comment: a detection-edge head transfer
   can precede the registered abort. Corrected the port header to distinguish
   registered forward measurements from reverse ready. Added local capacity
   explanations for math/E2E/guard combinational ready and the TX observer's
   PHY-loss polarity conversion. Added clock/interface separators and the
   always-accepting default contract where the main interfaces needed them.
3. **Layout:** Expanded helper parameter declarations and the ledger's nested
   initializer to one association/declaration per line. Repaired inconsistent
   declaration, assignment and port-direction alignment within PtpCore. Kept
   already aligned groups and the public generic/port order.
4. **Constants and arithmetic:** Renamed seven architecture-local constants
   in `PtpRegWrapper` from `_G` to `_C`, retaining child generic names and
   values; used its timing/frequency constants at the remaining literal sites.
   Replaced the ledger fixture's literal Delay_Req encoding with
   `PTP_MSG_DELAY_REQ_C`. Expressed the port's half-interval jitter as unsigned
   division by two, preserving floor rounding, result width and addition order.

These address the guide's written requirements even though the initial VSG
run already passed. No new pipeline stages, state fields, register addresses,
reset modes or protocol policy were introduced.

## Intentional exceptions retained

- Combinational reverse-ready paths express current admission/cancellation or
  simultaneous consume/refill. They remain resolved through `v` and published
  unconditionally; registering them needs a separate buffering design.
- `PtpPhcRead` retains one process pair per domain and asynchronous session
  reset for stopped clocks, using existing SURF FIFOs and reset synchronizers.
- Reset distribution, fixed polarity conversion, structural forwarding,
  slices/casts and fixture packing retain their documented roles.
- Endpoint public generic order remains compatible with positional users.
  The register fixture intentionally composes several production banks, so
  its descriptive instance names remain appropriate.

The [boundary survey](../ethernet-ptp/output-register-survey.md) and
[timing contract](../ethernet-ptp/rtl-readability.md) still describe these
interfaces. No changes to their cycle semantics are intended by this follow-up.

## Validation and next steps

- Initial and final VSG pass all 22 files with `vsg-linter.yml`. Final temporary
  log: `/private/tmp/ptp-conventions-follow-up-vsg.log`.
- A source comparison confirms that all 21 entity declarations are unchanged
  after ignoring comments/whitespace. Across all 22 files, the only other
  non-comment token changes are the eight reset/publication relocations,
  constant substitutions/renames and the two equivalent half-interval
  expressions listed above. This is a scope check, not behavioral simulation.
- `git diff --check` passes. No manifests or source membership changed.
- All 21 entities/wrappers compile and link with GHDL 6.0.0 using
  `--std=08 --ieee=synopsys -frelaxed-rules -fexplicit`. Only `ghdl -i` and
  `ghdl -m` were used; no executable was run. Warnings concern existing
  dependency shared variables/elaboration/name hiding, the servo's unchanged
  `maximum` parameter name, and its fixture's unchanged partial `open`
  association. Temporary log:
  `/private/tmp/ptp-conventions-follow-up-85msl3ik/compile.log`.

A fresh `make MODULES="$PWD" ... import` was attempted but Tcl could not create
its subprocess error file inside the sandbox. The makefile also attempted an
index refresh, which the sandbox denied. Direct GHDL import instead uses the
existing ruckus inventory under
`/private/tmp/ptp-conventions-build-7cubpyge/SRC_VHDL`, reading current source
contents into a fresh work library. As in the previous handoff, MAC RTL and
`DspXor.vhd` supplement the non-Vivado source inventory. No old compiled objects
are reused. Import-attempt log:
`/private/tmp/ptp-conventions-follow-up-import.log`.

Simulation and pytest remain paused under the
[maintainer gate](../ethernet-ptp/README.md#current-validation). After approval,
run the already prepared focused PTP regressions, including reset/ready checks
for the port and servo and deterministic Delay_Req scheduling. No staging or
commits. Behavioral correctness, FPGA timing/resources and physical CDC
qualification remain outside the evidence provided by this survey and build.
