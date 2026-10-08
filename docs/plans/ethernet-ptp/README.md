# Ethernet PTP workstream

Reusable fixed-source, one-/two-step Layer-2 E2E TimeReceiver with autonomous
numerical PHC/servo control. Software configures and observes it; software is not
in the timing loop. The source is implemented; current behavioral and hardware
acceptance remain open.

## Document map

| Question | Maintained source |
| --- | --- |
| What is implemented, and what are its limits? | [Endpoint contract](autonomous-endpoint.md), [source/integration guide](../../../ethernet/PtpCore/README.md) |
| What does software configure/read? | [Register map and ownership](register-map.md) |
| Who owns each interface and clock edge? | [PTP timing and record contracts](rtl-readability.md), [SURF VHDL conventions](../../vhdl-conventions.md) |
| What was checked, and what remains to approve? | [Review and acceptance record](rtl-review.md), [test procedures/fixtures](../../../tests/ethernet/PtpCore/README.md) |
| How can numerical time drive a physical clock? | [Physical-clock requirements](physical-clock-integration.md) |
| Why were earlier designs rejected, and what did older tests establish? | [Historical experiments and milestones](history/verification.md), [September 8 design review](history/review-2026-09-08.md) |
| What unimplemented options were studied? | [Application timing, co-simulation and clock/PHY studies](history/design-studies.md) |

## Current validation

**Simulation and pytest, including collection and pure models, remain paused
until explicit maintainer VHDL approval.** Lint and compile/link smoke checks
are allowed. Historical simulation passes predate the register, interface,
control-flow and one-step receive changes and do not validate the current tree.

The [review record](rtl-review.md) owns recorded static checks and their limits,
including blocked full imports, declaration-only dependencies and unavailable
tools. None establishes behavioral equivalence, real checkpoint binding, timing
closure, physical CDC, external-master interoperability or hardware accuracy.
After approval, follow its [ordered acceptance checklist](rtl-review.md#outstanding-acceptance),
including [one-step coverage](rtl-review.md#one-step-receive-acceptance).

## Current implementation

- `PtpEndpointControl` owns global coordination, registered restart/RX flush and
  IRQ events; `PtpEndpoint` is structural. Functional cores retain local banks.
- `PtpProtocolEngine` replaces the RTL name `PtpPort`. Python exposes
  `PtpEndpoint.ProtocolEngine` in place of `PtpEndpoint.Port`; offsets/fields,
  `PtpPort*Type` records and the `PtpPortWrapper` fixture name are unchanged.
  See [software naming](register-map.md#software-naming).
- One-step receive selects origin/correction per Sync without a mode register.
  Its association rules are part of the [endpoint contract](autonomous-endpoint.md#port-policy-and-numerical-envelope),
  with prepared fixtures awaiting behavioral approval.

## PHY composition implementation

UltraScale GTH, UltraScale+ GTY and gigabit-only UltraScale LVDS/Marvell copper
source compositions share `GigEthPtp` and the same autonomous endpoint. Legacy
Ethernet and PTP lanes share PHY adapters. Public interfaces, bank apertures,
reference selection, exact hierarchy and reset contracts belong in the
[composition guide](../../../ethernet/PtpCore/README.md#1g-phy-compositions).

The consuming KCU105 target has independent SFP/copper PHCs and uses
`USE_GTREFCLK_G=true` for SFP. Its compatible dedicated-reference GTH checkpoint
is still missing: develop and qualify it in `surf-dcp-targets`, then load it
through the normal SURF manifest. The legacy checkpoint cannot satisfy that
binding. RFMC uses the selected 1 GbE RTM integration path, with board HDL still
a scaffold. Neither is a hardware-qualified PTP release.

Board pin/clock assumptions, XM107 programming, measurement-output decisions
and target evidence belong in the consuming project's target guides. In
particular, copper PCS reset clears its PHC/configuration, unlike the externally
clocked GTH/GTY paths. Stopped-clock recovery requires invalidation/reacquisition;
retained registers alone do not establish holdover. Reusable PHY acceptance is
tracked in the [review record](rtl-review.md#phy-and-hardware-acceptance).

## Open decisions and next work

1. Review the current RTL and record approval before restarting behavioral
   checks. Justify the existing 2048-cycle association floor and 200,000-ppb
   actuator cap; their rationale is still unresolved.
2. Supply/qualify the dedicated GTH reference IP, then qualify reset/clock
   continuity, constraints, CDC, timing/resources and latency separately for
   each supported PHY/board. Do not infer family-wide support from one target.
3. Select the external-master configuration and independent instrument fixture;
   define settling, steady/peak error, temperature, reset-repeatability and
   holdover limits at a named reference plane. Earlier accuracy figures are
   engineering objectives, not requirements or measured results.
4. Select physical reference/cleanup and application epoch-transfer requirements
   through [physical-clock integration](physical-clock-integration.md). Numerical
   time, physical frequency/phase and application events remain distinct.
5. Revisit the [deferred RX FIFO option](autonomous-endpoint.md#deferred-rx-fifo-optimization)
   only with a concrete resource/timing need. Additional PHYs, a timed-event
   scheduler, shared simulator timing, one-step transmit, VLAN/UDP, BMCA and
   White Rabbit remain optional future scope, not first-endpoint dependencies.

## Maintaining this workstream

Keep this index concise: current state, decisions, risks and next steps. Put
enduring behavior in the owning contract and pending acceptance in `rtl-review.md`.
When a task finishes, fold its useful content into those documents and remove
its execution checklist; do not add another permanent per-task handoff. Keep
unique dated experiments or unimplemented design studies under `history/`, with
source provenance and explicit limits. Use the source/test guides for inventories
and procedures, and application repositories for board details. Historical
results never close acceptance of later changes.
