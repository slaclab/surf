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
| How do tests relate to IEEE 1588? | [Specification coverage and gaps](../../../tests/ethernet/PtpCore/specification-coverage.md) |
| How can numerical time drive a physical clock? | [Physical-clock requirements](physical-clock-integration.md) |
| What did the compute/storage redesign implement? | [Implementation record and storage inventory](lut-implementation.md) |
| Why this area architecture, and what savings are already measured? | [Architecture, planning allocations and earlier evidence](lut-optimization.md#proposed-architecture-for-substantial-lut-reduction) |
| Which LUT optimizations should be explored next? | [Prioritized candidates and probe findings](lut-optimization.md#next-optimization-candidates) |
| Why were earlier designs rejected, and what did older tests establish? | [Historical experiments and milestones](history/verification.md), [September 8 design review](history/review-2026-09-08.md) |
| What unimplemented options were studied? | [Application timing, co-simulation and clock/PHY studies](history/design-studies.md) |

## Current validation

The [October 13 arbiter, capacity and TLV pass](lut-optimization.md#october-13-compute-arbiter-frame-capacity-and-optional-tlvs)
restructures `PtpCompute`'s memory arbitration to index owners at constant
indices, makes the previously unreachable `MAX_FRAME_G` settable through the
endpoint chain, and adds `TLV_EN_G` for deployments that carry no TLVs. Matched
synthesis measures -803 LUTs for the arbiter change and -1,176 for a 128-byte
capacity; disabling TLVs measures a further -2,754 but rejects TLV-bearing
messages and is not selected. 48 focused configurations pass. These are
synthesis-stage figures with the PHY black boxes unbound; a routed build of the
combined source is outstanding.

The [LUT candidates 5-7 follow-up](rtl-review.md#october-13-lut-candidates-5-7)
selects a 70-byte lane-aligned RX store and specialized TX observer, retaining
the existing chunked TLV helper. Matched synthesis saves 770 LUTs (1.50%) with
unchanged RAM/DSP use; the selected SFP-only routed build has WNS +0.247 ns and
zero setup/hold/pulse-width failures. Seven RX configurations, the unchanged
TX storage source and final real-MAC RX pass focused checks. Final endpoint
integration and hardware acceptance remain open; see the linked provenance.

The [arithmetic-guided timing follow-up](rtl-review.md#october-13-arithmetic-guided-timing-follow-up)
uses native arithmetic, parallel TLV validation and shorter protocol admission
logic. The isolated KCU105 SFP-only R4 build meets its existing setup, hold and
pulse-width constraints: WNS +0.182 ns and zero failing endpoints. Fifteen
initial focused configurations, four final admission configurations and an extra
TLV stress scenario pass; final endpoint/MAC integration and hardware acceptance
remain unrun. See the linked record for source provenance and constraint/CDC limits.

The October 13 [critical-path implementation](rtl-review.md#october-13-critical-path-implementation)
addresses the routed KCU105 setup failures in both wire validators, protocol
rejection diagnostics, PHC normalization and servo age checks. Focused behavioral
verification passes in 18 selected final-pass configurations. The isolated
SFP-only routed comparison improves WNS from -8.039 to -2.829 ns but still fails
setup timing; final-pass endpoint/MAC integration remains unrun.

The October 13 connected compute/storage redesign has passed all 171
regression configurations across focused batches, including both PHYs and both
receive modes in the endpoint and real-MAC lifecycle fixtures, and raw/normalized
E2E calibration cases. See the
[current implementation review](rtl-review.md#october-13-connected-compute-and-word-storage)
for tool settings, reruns and evidence. The first
[Vivado 2025.2 screenshot](lut-optimization.md#october-13-connected-implementation-synthesis)
for SURF `52dfa266f` shows 18,483 LUTs and 13,618 registers in the copper endpoint.
Full reports, matched resource attribution and timing remain outstanding;
hardware and standards acceptance remains separate.

The subsequent [candidates 1–4 pass](rtl-review.md#october-13-optimization-candidates-1-4)
consolidates rejection counting, selects six deeper block-RAM stores, shares
ledger age arithmetic and replaces runtime interval shifts with constants.
That pass is committed as `0d27ddbba`; all 20 focused final configurations pass.
The subsequent [protocol scan follow-up](rtl-review.md#october-13-protocol-scan-word-arithmetic)
shares a word ALU across pair/history checks with bounded arbitration and
cancellation; all nine selected configurations pass. These changes are separate from the screenshot above; focused
results and remaining build-host measurement are tracked in the review records.

**The maintainer authorized resuming behavioral verification on October 9,
2026.** The prior simulation/pytest pause is lifted. The resumed run and its
source revision are recorded in the [acceptance record](rtl-review.md#october-9-behavioral-verification).
The resumed baseline suite passed all **121 distinct cases** after a GMII fixture timeout
correction: 24 cocotb/GHDL configurations and 97 Python/static cases, with no
remaining failures or skips. That baseline run did not change production RTL.
Additional boundary and standards/profile acceptance remains open.
The subsequent [specification audit and fixes](rtl-review.md#october-9-directed-specification-checks)
use the maintainer-supplied 2019 text. Minor-version, reserved/control-field,
TLV and transmitted-control fixes have **11 focused RTL configurations and
27 RX model cases passing**; the selected RTL runs took about 66 seconds total.
The full suite was not rerun. The subsequent
[master/exchange checks](rtl-review.md#october-9-master-and-exchange-checks)
add ordinary multicast master traffic, correction-overflow retirement and
response-association rejection/recovery: **10 focused configurations passed in
196.17 seconds with four workers**, including the direct protocol and ledger
regressions. The default multicast scheduler,
domain limits and profile requirements remain open.

Routine changes use the [focused test-selection guide](../../../tests/ethernet/PtpCore/README.md#selecting-tests).
The full suite is reserved for substantial integration/release validation or an
explicit request. Parallelize the selected cases; the acceptance backlog does
not require replaying all regressions after each edit.

The [review record](rtl-review.md) owns recorded static checks and their limits,
including blocked full imports, declaration-only dependencies and unavailable
tools. None establishes behavioral equivalence, real checkpoint binding, timing
closure, physical CDC, external-master interoperability or hardware accuracy.
Follow its [ordered acceptance checklist](rtl-review.md#outstanding-acceptance),
including [one-step coverage](rtl-review.md#one-step-receive-acceptance).

## Current implementation

- `PtpEndpointControl` owns global coordination, registered restart/RX flush and
  IRQ events; `PtpEndpoint` is structural. Functional cores retain local banks.
- `PtpProtocolEngine` replaces the RTL name `PtpPort`. Python exposes
  `PtpEndpoint.ProtocolEngine` in place of `PtpEndpoint.Port`; offsets/fields
  and `PtpPort*Type` records are unchanged. The direct fixture is
  `PtpProtocolEngineWrapper`, matching the production entity name.
  See [software naming](register-map.md#software-naming).
- One-step receive selects origin/correction per Sync without a mode register.
  Its association rules are part of the [endpoint contract](autonomous-endpoint.md#port-policy-and-numerical-envelope),
  with both receive modes passing the baseline direct, physical and endpoint
  fixtures; later header fixes have the focused verification recorded above.
- The earlier [fixed-point width audit](autonomous-endpoint.md#fixed-point-width-audit)
  records range proofs and the preceding private-engine implementation. The
  connected processor preserves full signed128 arithmetic and public precision.
  Historical comparison results and remaining
  [width acceptance](rtl-review.md#fixed-point-width-acceptance) are recorded separately.
- The connected [shared-compute implementation](lut-implementation.md) now uses
  one production word processor per endpoint, addressed working storage, compact
  packet stores, sequential configuration banks and versioned snapshots. Its
  endpoint and real-MAC integration configurations have passed. The
  [service bound](rtl-readability.md#shared-service-bound) replaces the earlier
  unexplained 2,048-tick association floor with a derived 70,347,776-tick minimum.
- Earlier [LUT optimization evidence](lut-optimization.md), including the
  [ledger report](lut-optimization.md#october-11-ledger-storage-and-counter-pass),
  [protocol table report](lut-optimization.md#october-12-protocol-table-conversion)
  and [arithmetic report comparison](lut-optimization.md#october-12-arithmetic-synthesis-comparison),
  describes the prior architecture. Those figures are not measurements of the
  connected word-storage implementation. Its first
  [October 13 synthesis result](lut-optimization.md#october-13-connected-implementation-synthesis)
  is now recorded separately; matched attribution and timing qualification remain
  outstanding.

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

1. Complete the remaining boundary acceptance and the IEEE 1588-2019/2008
   [specification coverage review](../../../tests/ethernet/PtpCore/specification-coverage.md).
   Qualify the shared-service envelope and justify the 200,000-ppb actuator cap;
   its physical/control rationale remains unresolved.
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
5. Obtain the matched Vivado resource/timing comparison for the completed
   [compute and word-storage implementation](lut-implementation.md), then qualify
   hardware timing. Halving LUT usage is motivation, not an acceptance threshold;
   report the measured result with complete lane accounting. The working Sync
   envelope is 10 Hz, initially encoded at 8 Hz. Shared Ethernet MAC/checksum
   changes remain deferred.
   The [feedback rate-estimator study](lut-optimization.md#feedback-rate-estimator-study-october-13)
   is also deferred: LUT savings are unproven, while convergence, filtering and
   rate qualification would change. Retain the current quotient-based estimator.
   Consider a future compile-time "no TLVs accepted" generic, disabled by
   default, to remove the RX TLV walker for controlled deployments. This is
   unimplemented and not a commitment: the current structural validation and
   skipping of TLV contents remains the default. The restricted mode would
   require each supported message's exact fixed-body `messageLength`, while
   still allowing Ethernet padding outside that length. Before enabling it,
   verify that the selected profile and grandmaster configuration need/send no
   TLVs; test rejection of extended messages and acceptance of legal padding,
   and measure matched synthesis/timing results. LUT and timing savings are
   unproven.
   Additional PHYs, a timed-event
   scheduler, shared simulator timing, one-step transmit, VLAN/UDP, BMCA and
   White Rabbit remain optional future scope, not first-endpoint dependencies.
   A [floating-point servo](autonomous-endpoint.md#deferred-floating-point-servo-option)
   is also a deferred investigation; integer/fixed point remains preferred for
   the rest of the timing chain.

## Maintaining this workstream

Keep this index concise: current state, decisions, risks and next steps. Put
enduring behavior in the owning contract and pending acceptance in `rtl-review.md`.
When a task finishes, fold its useful content into those documents and remove
its execution checklist; do not add another permanent per-task handoff. Keep
unique dated experiments or unimplemented design studies under `history/`, with
source provenance and explicit limits. Use the source/test guides for inventories
and procedures, and application repositories for board details. Historical
results never close acceptance of later changes.
