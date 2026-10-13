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
| How do we implement the full compute/storage redesign? | [Implementation brief for the executing agent](lut-implementation.md) |
| Why this area architecture, and what savings are already measured? | [Architecture, planning allocations and earlier evidence](lut-optimization.md#proposed-architecture-for-substantial-lut-reduction) |
| Why were earlier designs rejected, and what did older tests establish? | [Historical experiments and milestones](history/verification.md), [September 8 design review](history/review-2026-09-08.md) |
| What unimplemented options were studied? | [Application timing, co-simulation and clock/PHY studies](history/design-studies.md) |

## Current validation

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
- The [fixed-point width audit](autonomous-endpoint.md#fixed-point-width-audit)
  narrows bounded servo state and the math engine's internal product storage.
  Precision and public arithmetic ranges are retained; current and pre-width-change
  RTL pass the prepared boundary fixtures. Additional
  [width acceptance](rtl-review.md#fixed-point-width-acceptance) remains open.
- [LUT optimization](lut-optimization.md) replaces the servo bubble sort with
  a fixed nine-comparison network and restructures RX prefix/header parsing.
  The [RX queue](autonomous-endpoint.md#rx-queue-storage) uses a synchronous FWFT
  FIFO with lossless capture packing and exact logical capacity. Delivery now
  takes three clocks after completion; write/read pipeline occupancy counts
  toward that capacity. See the [focused verification record](rtl-review.md#october-9-lut-optimization-checks)
  for the original optimization checks and subsequent FIFO validation.
  Vivado resource and timing improvement remains unmeasured.

- The October 11 [ledger optimization](lut-optimization.md#october-11-ledger-storage-and-counter-pass)
  stores complete entries in synchronous RAM and shares row processing across
  a ten-clock scan at depth four. Completion/response paths honor backpressure;
  the software ABI is unchanged. The later
  [synthesis report review](lut-optimization.md#october-12-synthesis-report-review)
  confirms 364 LUTRAMs and about 1,800 total LUTs per ledger, down from about
  6,950 in the earlier placed hierarchy. A controlled comparison at the same
  stage and timing acceptance remain open. See the
  [focused acceptance record](rtl-review.md#october-11-ledger-optimization-checks).

- The October 12 [protocol table conversion](lut-optimization.md#october-12-protocol-table-conversion)
  replaces Sync history and Sync/Follow_Up payload arrays with synchronous RAM
  and shared scans. The [storage contract](autonomous-endpoint.md#protocol-association-storage)
  defines the added latency and scan-time expiry boundary. A subsequent
  [post-synthesis screenshot](lut-optimization.md#october-12-protocol-table-synthesis-screenshot)
  shows the copper protocol engine at 16,792 LUTs, down 28.64% from the prior
  synthesis; its own logic including the new RAMs falls 43.08%. The full new
  reports, SFP breakdown and timing acceptance remain outstanding.

- The subsequent [E2E, servo and PHC arithmetic audit](lut-optimization.md#october-12-e2e-servo-and-phc-arithmetic-audit)
  led to the [servo sharing implementation](lut-optimization.md#october-12-servo-arithmetic-and-median-implementation):
  a shared clamp/rounding path and one median comparator over nine clocks.
  The [sequencing contract](autonomous-endpoint.md#servo-arithmetic-and-filter-sequencing)
  defines added latency and backpressure. The subsequent
  [E2E/PHC/math implementation](lut-optimization.md#october-12-e2e-phc-and-math-implementation)
  shares timestamp conversion and accumulation, skips zero calibration work,
  ticks from the committed PHC increment and bounds its phase-divider remainder.
  [E2E sequencing](autonomous-endpoint.md#e2e-arithmetic-sequencing) and
  [PHC/math contracts](autonomous-endpoint.md#phc-increment-and-phase-normalization)
  preserve numeric widths and ownership. The
  [October 12 full-report comparison](lut-optimization.md#october-12-arithmetic-synthesis-comparison)
  shows each E2E dropping 12 DSPs, Servo own logic falling about 1,730 LUTs,
  and phase math falling 234 LUTs against the October 11 baseline. Rate and
  Servo math children each save 64 LUTs. Complete endpoints fall 26.03%/26.99%,
  including the intervening protocol-table work. This differs from the later
  [screenshot-to-screenshot comparison](lut-optimization.md#october-12-arithmetic-synthesis-screenshot),
  which shows an 11.27% copper endpoint reduction for the arithmetic pass.
  Vivado versions differ between the retained reports, so exact causal savings,
  placement and timing remain outstanding.

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
   Justify the existing 2048-cycle association floor and 200,000-ppb
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
5. Execute the [compute and word-storage implementation brief](lut-implementation.md):
   a shared measurement processor, RAM working/configuration/snapshot state and
   specialized timestamp paths, retaining the shared Ethernet MAC, independent
   PHCs and autonomous control. The maintainer clarified that halving LUT usage
   is motivation, not an acceptance requirement; report the measured result of
   the completed design. Shared protocol timestamp conversion
   is committed at `3f0daa750`; checksum changes were deferred/reverted. See the
   [first increment](lut-optimization.md#first-implementation-increment-october-12).
   The standalone [word processor prototype](lut-optimization.md#shared-word-processor-prototype-october-12)
   now shares arithmetic and 32-bit RAM across four contexts; both memory modes
   pass focused checks. It is not integrated into the endpoint. Rate/E2E migration,
   engine-plus-adapter area and actual configuration/snapshot/median/ledger word
   storage remain next work, followed by servo/PHC preparation migration.
   The working Sync ceiling is 10 Hz, initially configured at 8 Hz. Obtain a
   matched synthesis comparison and qualify complete compute-service latency.
   These are evidence requirements, not per-module approval or area thresholds.
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
