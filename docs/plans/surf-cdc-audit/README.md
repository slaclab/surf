# SURF Static CDC Audit

## Goal

Find source-level CDC structures across SURF, then confirm and prioritize the
candidates with Vivado `report_cdc`.  The first pass covered CDC-10 and CDC-12;
the second pass covered CDC-2, CDC-5, CDC-6, and CDC-8.

[AMD UG906](https://docs.amd.com/r/en-US/ug906-vivado-design-analysis/Understanding-the-Clock-Domain-Crossings-Report-Rules)
classifies CDC-10 (combinational logic in synchronizer fan-in) and CDC-12
(multi-clock fan-in) as critical, unsafe structures. Static source inspection
can identify strong candidates, but only an elaborated design with complete
clock constraints can produce an authoritative result.

## Scope And Method

Initial static scan performed on 2026-08-21:

- 1,200 VHDL files under `axi`, `base`, `devices`, `dsp`, `ethernet`,
  `protocols`, `xilinx`, and `simlink`.
- 208 VHDL files instantiate a SURF reset or CDC primitive.
- 124 explicit `RstSync.asyncRst` associations.
- 446 `Synchronizer`, `SynchronizerVector`, `SynchronizerOneShot`, or
  `SynchronizerEdge` instances across 135 files.
- 92 `FifoAsync` or `SynchronizerFifo` instances across 47 files.
- 26 Verilog/SystemVerilog files. Most are generated BlueSpec or vendor RTL;
  the maintained `i2cSlave.sv` synchronizes its raw inputs directly and did not
  expose the reset-aggregation pattern targeted here.

The scan traced concurrent assignments into `RstSync`, `PwrUpRst`,
`Synchronizer`, `SynchronizerOneShot`, `FifoAsync`, `SynchronizerFifo`, and
known FIFO wrappers. It then checked whether the fan-in was combinational and
whether its operands belong to named, distinct interface clock domains.

Testbench, simulation-only, generated, and mutually exclusive simulation
drivers were excluded from the findings below.

## CDC-2, CDC-5, CDC-6, And CDC-8 Pass

Focused static scan performed on 2026-08-21 at commit `20116083fedc`:

- `Synchronizer` and `SynchronizerVector` are the only maintained HDL entities
  that declare `ASYNC_REG`.  `RstSync` obtains the attribute by instantiating
  `Synchronizer` for its reset-release stages.
- 103 production `SynchronizerVector` instances were found in 44 files.  Only
  three explicitly have width one; the other 100 are source-level CDC-6
  candidates before considering their protocols.
- 48 `RstPipeline` or `RstPipelineVector` instantiations were found in 16
  files, including the internal scalar instance in `RstPipelineVector`.
  `RstPipeline` is a same-domain fanout/delay pipeline and does not carry
  `ASYNC_REG`; it must not be treated as a reset synchronizer.
- Custom record-based synchronizers, `_meta`/`_sync` chains, vector shift
  chains, and input-filter pipelines were searched in maintained VHDL and
  Verilog/SystemVerilog.  Imported I2C and Xilinx-generated sources were
  recorded separately rather than treated as maintained SURF RTL.

### Missing `ASYNC_REG` Findings

| ID | Source | Expected rule | Finding |
| --- | --- | --- | --- |
| CDC-B01 | `protocols/saci/saci1/rtl/SaciMaster.vhd:46-95,171-172` | CDC-2 | A local `SynchronizerType` and `synchronize` procedures implement three-stage synchronizers for `req` and `reset` inside the main state record.  The stages have no `ASYNC_REG` attribute and bypass the SURF primitives. |
| CDC-B02 | `protocols/saci/saci1/rtl/SaciMasterSync.vhd:48-65,167-168` | CDC-2 | Duplicates the hand-written three-stage `req` and `reset` synchronizers without `ASYNC_REG`. |
| CDC-B03 | `xilinx/7Series/{gtx7,gtp7,gth7}/rtl/*RecClkMonitor.vhd:161-182,229-292,407-416` | CDC-2 | Each Xilinx-generated monitor contains six explicit metastability chains using legacy `syn_keep` attributes but no Vivado `ASYNC_REG`: reset into recovered/reference clocks, reset and PLL lock into `SYSTEM_CLK`, and recovered/reference counter MSBs into `SYSTEM_CLK`. |

No high-confidence maintained CDC-5 or CDC-8 instance was found.  In
particular, maintained reset-release logic routes through `RstSync`, whose
internal synchronization stages are annotated.  The `RstPipeline` uses were
either same-clock fanout/delay stages, post-synchronizer JESD timing pipelines,
or interface-reset uses whose source-clock contract can only be established at
integration.  Feeding an asynchronous interface reset into one of those
`RstPipeline` instances would still produce a CDC finding.

The imported I2C implementations also contain unannotated raw SCL/SDA input
pipelines:

- `protocols/i2c/rtl/i2c_master_bit_ctrl.vhd:268-288,372-425`
- `protocols/i2c/rtl/I2cSlave.vhd:146-165,208-221`
- `protocols/i2c/rtl/i2cSlave.sv:97-101,144-153`
- `protocols/i2c/rtl/orig/i2cslv.vhd:196-254`
- `protocols/i2c/rtl/orig/i2c2ahbx.vhd:159-204`

These should be handled as imported-code exceptions or through maintained
wrappers/constraints unless there is a deliberate decision to update the
third-party source.

### CDC-6 Priority Findings

`SynchronizerVector` deliberately synchronizes every bit independently.  It is
appropriate for unrelated status bits and Gray-coded values, but it does not
make a changing binary word or correlated record coherent.  The following
uses have the strongest functional reason to require an atomic snapshot,
handshake, or FIFO-style transfer.

| ID | Source | Data | Risk |
| --- | --- | --- | --- |
| CDC-C01 | `axi/axi-stream/rtl/AxiStreamFrameBuffer.vhd:460-474,552-565` | Final RAM address plus `rdSetupDone` | The source updates the address and flag together, both pass through equal-depth independent bit synchronizers, and the destination captures the address as soon as the flag is seen.  Metastability can delay any address bit beyond the flag. |
| CDC-C02 | `axi/axi4/rtl/AxiMemTester.vhd:383-446` | Live read data, expected pattern, and completion/error status | `rData` and `rPattern` update on each read beat.  Error/status bits cross independently, so observing an error does not guarantee a coherent associated data/pattern word. |
| CDC-C03 | `protocols/htsp/core/rtl/HtspAxiL.vhd:496-503,589-596` | Two 128-bit link-data words | `remLinkData` updates from received headers and `locData` is an unconstrained interface input.  AXI-Lite can observe torn telemetry words. |
| CDC-C04 | Four ADC readout files under `devices/AnalogDevices/{ad9249,ad9681}` | 8- or 14-bit ADC frame samples | Live sampled data is independently synchronized for AXI-Lite debug/readback, so a read can contain bits from different samples. |
| CDC-C05 | `protocols/jesd204b/rtl/{JesdRxReg,JesdTxReg}.vhd` status-vector instances | Per-lane dynamic status words | Correlated status fields can be observed in combinations that never existed in the source domain. |
| CDC-C06 | `protocols/clink/rtl/ClinkData.vhd:292-310` | Delay and shift-count status | Multi-bit calibration values can tear while the calibration state changes. |

CDC-C02 through CDC-C06 are primarily diagnostic/readback coherency concerns;
CDC-C01 participates directly in a control protocol and is therefore the
highest-priority CDC-6 fix.

### CDC-6 Intent-Dependent Groups

The remaining vector synchronizers are dominated by slowly changing AXI-Lite
configuration words.  They converge after the source stops changing, but can
take on a mixed value during an update.  Whether that transient is acceptable
is an interface-contract question.  The main families are:

- MAC addresses and Ethernet configuration in GigE, TenGigE, Xaui, and HTSP.
- RSSI negotiated parameters and control registers.
- JESD204B delay, amplitude, selection, threshold, and per-lane controls.
- CoaXPress timing/lane configuration, SALT receiver configuration, ADC delay
  configuration, and the AXI Stream frame-rate limit.
- PGP skip interval, ICAP boot address, and other infrequently written setup
  values.

These should either document a software rule that writes only while the
consumer is disabled/reset, or use an explicit atomic-update protocol.  Slow
update frequency by itself does not provide CDC coherency.

### Reviewed CDC-6 Exceptions

- `base/fifo/rtl/inferred/FifoAsync.vhd`: the two synchronized index buses are
  Gray coded.  Independent synchronization is the intended async-FIFO
  topology, subject to the normal Gray-code and bus-skew constraints.
- `axi/dma/rtl/v1/AxiStreamDmaRingRead.vhd`: request and acknowledgment payloads
  use two synchronization stages while their request/done controls use four.
  The source holds each payload throughout the handshake, providing deliberate
  bundled-data settling margin.
- `SyncStatusVector` and packed pause/link/status vectors represent independent
  Boolean indications where no atomic vector meaning is consumed.  They remain
  structural CDC-6 results but are not automatically functional defects.
- Device DNA values are static after acquisition.
- The three explicit width-one `SynchronizerVector` instances are not CDC-6
  structures and could use scalar `Synchronizer` for clarity.

## High-Confidence Candidates

These are structurally unsafe or sufficiently close to a CDC-10/CDC-12 pattern
that they should be the first Vivado targets.

| ID | Source pattern | Expected rule | Reason |
| --- | --- | --- | --- |
| CDC-A01 | `base/general/rtl/AsyncGearbox.vhd:85,118,187` | CDC-10, CDC-12 | `slaveRst or masterRst` directly resets `FifoAsync`; the operands belong to explicitly different interfaces. |
| CDC-A02 | `axi/axi-stream/rtl/AxiStreamRingBuffer.vhd:351,368` | CDC-10, CDC-12 | `dataRst or axilRst` directly resets `SynchronizerFifo` spanning `dataClk` and `axilClk`. |
| CDC-A03 | `axi/axi-stream/rtl/AxiStreamMonAxiL.vhd:108-120` | CDC-10, CDC-12 | An AXI-Lite combinational decode is combined with `axisRst` before an `axisClk` `RstSync`; default `COMMON_CLK_G` is false. |
| CDC-A04 | `base/sync/rtl/SyncTrigRate.vhd:161-178` through `SyncMinMax.vhd:78-85` | CDC-10, CDC-12 | `refRst or locRst` feeds a one-shot synchronizer; the resets correspond to independently configurable reference and local clocks. |
| CDC-A05 | Six `ethernet/GigEthCore/*/rtl/GigEth*.vhd` implementations | CDC-10, CDC-12 | `extRst or config.softRst or sysRst125` feeds `PwrUpRst`, whose first stage is `RstSync`. `config.softRst` is registered in `axiLiteClk`. |
| CDC-A06 | `ethernet/XauiCore/{gtx7,gth7}/rtl/Xaui*.vhd:166-177` | CDC-10, CDC-12 | AXI-domain `config.softRst` is ORed with `extRst` before a `gtRefClk` `RstSync`. |
| CDC-A07 | Three UltraScale Xaui wrappers (`gthUltraScale`, `gthUltraScale+`, `gtyUltraScale+`) | CDC-10, possible CDC-12 | `wdtRst or extRst` feeds `PwrUpRst`. Source-clock provenance must be confirmed after elaboration. |
| CDC-A08 | `protocols/clink/{7Series,UltraScale}/ClinkDataClk.vhd` | CDC-10 | `lockedLoc and not rstIn` drives the asynchronous input of `RstSync`. |
| CDC-A09 | `xilinx/7Series/{gtx7,gtp7,gth7}/rtl/*Core.vhd` | CDC-10, likely CDC-12 | `rxResetDone and rxFsmResetDone` drives an `rxUsrClk` reset synchronizer; the GT status and reset-FSM completion do not clearly share a launch clock. |
| CDC-A10 | `xilinx/general/rtl/GtRxAlignCheck.vhd:184-193` | CDC-10 | `resetDone and resetErr` feeds `SynchronizerOneShot`, whose input is the asynchronous assertion input of an internal `RstSync`. |
| CDC-A11 | `protocols/pgp/shared/PgpTxVcFifo.vhd:70-81` and `protocols/htsp/core/rtl/HtspTxFifo.vhd:82-93` | CDC-10 | Two link-ready indications are ANDed before a single-bit synchronizer. |
| CDC-A12 | `protocols/jesd204b/rtl/Jesd204bTx.vhd:293-305` | CDC-10 | Polarity selection between `nSync_i` and a control signal occurs before `SynchronizerVector`. |
| CDC-A13 | `protocols/srp/rtl/SrpV3AxiLite.vhd:285-302` | CDC-10 | A synchronized AXI-domain reset is ORed with `sAxisRst` before a second `sAxisClk` `RstSync`. |
| CDC-A14 | `protocols/ssi/rtl/SsiFifo.vhd:259-265` | CDC-10 when asynchronous | A registered lockup-reset request and `sAxisRst` are combined before the reset reaches the asynchronous FIFO path. |

The Gigabit Ethernet family in CDC-A05 comprises the `gtx7`, `gtp7`, `gth7`,
`gthUltraScale`, `gthUltraScale+`, and `gtyUltraScale+` implementations.

## Candidates Requiring Elaboration

| Source pattern | Concern | Why static inspection is insufficient |
| --- | --- | --- |
| `ethernet/TenGigEthCore/{gthUltraScale+,gtyUltraScale+}/rtl/*Rst.vhd:59-67` | `txRstdone and rxRstdone` before `Synchronizer` | Need the generated GT IP clock provenance for both status outputs. |
| Three `protocols/coaxpress/{gthUs,gthUs+,gtyUs+}/rtl/*IpWrapper.vhd` variants | `phyRst312 or not reset-done/ready` before `RstSync` | Generated-IP outputs may already be synchronous to `phyClk312`; the LUT remains a possible CDC-10 endpoint. |
| `protocols/pgp/pgp4/core/rtl/Pgp4AxiL.vhd:362-364` | Generic polarity conversion before FIFO reset synchronization | Active-high elaboration can collapse to a wire; active-low can retain an inverter. |
| `protocols/glink/{gtx7,gtp7}/rtl/GLink*FixedLat.vhd` | Inverted reset-done plus reset request feeds `SynchronizerFifo.rst` | Generate constants may simplify part of the expression; check post-synthesis topology. |
| `base/fifo/rtl/xilinx/FifoXpm.vhd:254` | Generic reset-polarity conversion ahead of XPM FIFO reset | Whether Vivado folds the inversion into the recognized XPM reset topology depends on elaborated generics and primitive mapping. |

## Reviewed False Positives

- `ethernet/RoCEv2/rtl/RoCEv2AxiStreamRdmaCore.vhd`: the derived FIFO reset
  is used with `GEN_SYNC_FIFO_G = true` and both interfaces on `roceClk`.
- `protocols/rssi/v1/rtl/RssiCore.vhd`: the connection-state FIFO reset is
  generated and consumed in `clk_i`; no multi-clock reset crossing was found in
  the inspected configuration.
- `xilinx/UltraScale/general/rtl/SelectioDeserUltraScale.vhd`: the apparent
  inversion driving `locked` is in the simulation-only generate branch. The
  synthesized branch receives `locked` directly from the PLL primitive.
- `protocols/pgp/pgp2fc/core/rtl/Pgp2fcAlignmentController.vhd`: `intSlideR`
  is produced by a clocked assignment, despite looking like a concurrent data
  expression to a simple source scanner.
- Constants on synchronizer inputs and `RstSync` internal constant polarity
  expressions do not represent launch-clock combinational fan-in.

## Vivado Verification Plan

Static source scanning is deliberately conservative. `report_cdc` only reports
paths for which both source and destination clocks are defined, so a clean
report from an incompletely constrained test top is not evidence of safety.

For each family below:

1. Elaborate a representative maintained top with its normal ruckus source set.
2. Define every generated, primary, AXI, stream, reference, recovered, and user
   clock; run `check_timing` first and reject unconstrained clock endpoints.
3. Run synthesis and then:

   ```tcl
   report_cdc -details -all_checks_per_endpoint -file cdc_all.rpt
   report_cdc -details -severity Critical -file cdc_critical.rpt
   ```

4. Record source/destination clocks and full cell paths for every CDC-10 and
   CDC-12. Do not waive a result until the source clock and intended protocol
   are documented.
5. Rerun after each fix because rule precedence can expose a lower-priority CDC
   finding at the same endpoint.

Suggested elaboration matrix:

- Generic base/AXI: `AsyncGearbox`, `AxiStreamRingBuffer`,
  `AxiStreamMonAxiL`, `SyncTrigRate`, `SrpV3AxiLite`, and `SsiFifo` wrappers.
- 7 Series: one design covering GigE, Xaui, GTP/GTX/GTH reset cores, GLink,
  and Clink.
- UltraScale and UltraScale+: GigE, Xaui, TenGigE, CoaXPress, and Clink.
- Protocol-specific: JESD204B and PGP/HTSP FIFO wrappers.

## Recommended Cleanup Order

1. Fix CDC-C01 first because its multi-bit address is consumed directly when
   an independently synchronized completion flag arrives. Completed on
   2026-08-24 as described below.
2. Replace the custom Saci synchronizers in CDC-B01 and CDC-B02 with SURF
   primitives.  Decide separately whether the generated Xilinx monitors are
   wrapped, locally patched, or accepted with explicit constraints.
3. Fix CDC-A01 through CDC-A04. They are generic shared infrastructure
   and contain explicit multi-domain reset aggregation.
4. Fix the repeated GigE/Xaui family patterns through shared helpers where
   practical, preserving family-specific generated/vendor code.
5. Fix same-source-domain combinational fan-in (CDC-A08 through CDC-A14) by
   registering in the source/control domain or moving polarity/qualification
   after synchronization.
6. Define which slow configuration and telemetry buses require atomic
   semantics, then address CDC-C02 through CDC-C06 and the intent-dependent
   groups accordingly.
7. Run the elaboration matrix and promote or dismiss the conditional candidates.
8. Add CI/report automation that fails on unreviewed critical CDC entries and
   records reviewed informational/warning structures; this repository
   currently has no `report_cdc` automation or waivers.

## Implementation Progress

### XPM CDC Backend Exploration

Reviewed on 2026-08-24 against the existing RAM/FIFO backend-selection
pattern and the AMD XPM CDC interfaces.  The proposed public selector is:

```vhdl
SYNTH_MODE_G : string := "inferred";
```

The default must remain `"inferred"` so existing designs, non-Xilinx builds,
and current simulation behavior do not change.  XPM implementations should
live in a backend-specific wrapper directory, with unsupported dummy entities
loaded by ruckus for non-Vivado and older-Vivado analysis.  Vivado projects
that load the XPM wrappers also need the `XPM_CDC` library enabled, following
the existing `XPM_MEMORY` handling in `base/ram` and `base/fifo`.

The mapping is not uniformly drop-in:

| SURF entity | XPM backend | Recommendation | Compatibility notes |
| --- | --- | --- | --- |
| `Synchronizer` | `xpm_cdc_single` | Add after reset semantics are explicit | XPM has no reset port, supports 2-10 destination stages, and cannot reproduce arbitrary per-stage `INIT_G`.  XPM mode must reject an asserted `rst` and unsupported initialization rather than silently changing behavior. |
| `SynchronizerVector` | `xpm_cdc_array_single` | Add with the same restrictions as scalar | This remains an array of unrelated single-bit crossings; it does not make a correlated vector coherent.  XPM limits width to 1-1024 and stages to 2-10. |
| `RstSync` | `xpm_cdc_async_rst` | Good first backend candidate | The default asynchronous-assert/synchronous-release behavior maps directly when `OUT_REG_RST_G = true` and `BYPASS_SYNC_G = false`.  XPM limits the release chain to 2-10 stages; other modes should remain inferred. |
| `SynchronizerEdge` | composed from `Synchronizer` plus edge logic | Keep composed | It can eventually propagate backend selection to its level synchronizer, but reset/restart behavior must remain identical. |
| `SynchronizerOneShot` and vector | no exact mapping with the current interface | Keep inferred/composed | `xpm_cdc_pulse` requires source and destination clocks and optionally both resets.  The SURF one-shot accepts an asynchronous trigger and only a destination clock, so substituting XPM would change its contract.  A separate two-clock pulse-transfer entity would be appropriate if needed. |
| `SynchronizerFifo` | existing `FifoXpm`/XPM FIFO path | Add `SYNTH_MODE_G` and delegate | This follows the existing FIFO selector most closely.  XPM FIFO depth restrictions mean current `ADDR_WIDTH_G = 2` uses must remain inferred; the default width of four is suitable. |
| proposed `SynchronizerHandshake` | historically `xpm_cdc_handshake` | Verify current tool support before promising an XPM backend | The AMD-style full handshake interface is a close match, but the macro has no reset ports.  The public contract must either be resetless or make XPM mode reject reset use.  The inferred backend needs a documented reset/abort contract and scoped bundled-data timing constraints; XPM reports its data path as CDC-15 by design.  AMD's 2026.1 architecture-library macro lists omit `xpm_cdc_handshake` even though current `xpm_cdc_array_single` text still recommends it, so availability must be checked in every supported Vivado release. |
| proposed Gray synchronizer | `xpm_cdc_gray` | Do not add without a concrete use case | The macro only applies when a binary source increments or decrements by one.  SURF's asynchronous FIFOs already encode, synchronize, and consume Gray pointers as part of their full/empty protocol, so replacing that logic with a general-purpose synchronizer would not simplify the FIFO.  Most other correlated-vector use cases need a handshake because their values can jump arbitrarily. |

Backend wrappers should set XPM simulation misuse checking on by default unless
Vivado regression shows an incompatibility.  Vendor-specific knobs should not
all become public SURF generics; expose only parameters needed to preserve the
SURF contract, such as source/destination synchronization depth and external
versus internal destination acknowledgment for the handshake.

Recommended implementation order:

1. Define and test the portable `SynchronizerHandshake` contract and inferred
   backend, verify `xpm_cdc_handshake` availability in the supported Vivado
   matrix, add an XPM backend only where available, then migrate CDC-C01 from
   its provisional FIFO.
2. Add `SYNTH_MODE_G` to `SynchronizerFifo` and route XPM-compatible depths
   through the existing FIFO backend.
3. Add the direct `RstSync` XPM backend.
4. Add restricted scalar/vector XPM backends only after codifying how callers
   declare that reset and nonzero initialization are unused.
5. Keep `SynchronizerEdge` and the one-shot/count/status hierarchy composed;
   propagate the selector only where it preserves behavior and provides a
   concrete synthesis benefit.

### Planned CDC Primitive Work

#### 1. Create `SynchronizerHandshake`

- [ ] Add a coherent vector-transfer primitive for applications that need one
  in-flight value but do not need FIFO buffering.
- [ ] Use an AMD-style full handshake: source data/send/receive and destination
  data/request/acknowledge.  Support both immediate internal destination
  acknowledgment and an external destination acknowledgment where practical.
- [ ] Hold the source payload stable for the entire transfer and capture it in
  the destination domain only when the synchronized request qualifies it.
- [ ] Define startup, reset, mid-transfer reset, and abort behavior before
  finalizing the ports.  Do not claim identical inferred/XPM behavior if the
  selected XPM macro cannot implement the reset contract.
- [ ] Include source and destination synchronization-depth generics, a
  `COMMON_CLK_G` bypass option, and
  `SYNTH_MODE_G : string := "inferred"`.
- [ ] Implement the portable inferred backend first, including `ASYNC_REG`
  attributes and the scoped bundled-data timing constraints required for the
  held vector path.
- [ ] Verify which supported Vivado versions and FPGA families actually provide
  `xpm_cdc_handshake`; add the XPM backend and unsupported dummy wrapper only
  for the verified matrix.
- [ ] Replace the provisional `SynchronizerFifo` transfer in
  `AxiStreamFrameBuffer` with `SynchronizerHandshake` after the primitive and
  its tests are complete.

#### 2. Add XPM Backend Selection To Existing Synchronizers

- [ ] Add `SYNTH_MODE_G : string := "inferred"` without changing the default
  implementation or existing public behavior.
- [ ] Add backend-specific XPM wrappers and non-XPM dummy entities following
  the `base/ram` and `base/fifo` ruckus pattern.  Enable `XPM_CDC` in Vivado
  projects that load these wrappers.
- [ ] Route `SynchronizerFifo` through the existing FIFO selector for supported
  XPM depths; retain the inferred implementation when `ADDR_WIDTH_G < 4`,
  which is used by existing shallow synchronization FIFOs but is below the
  XPM FIFO minimum depth.
- [ ] Add the direct `xpm_cdc_async_rst` backend for compatible `RstSync`
  configurations.
- [ ] Add restricted `xpm_cdc_single` and `xpm_cdc_array_single` backends for
  `Synchronizer` and `SynchronizerVector`.  Reject unsupported reset,
  initialization, stage-count, and width configurations explicitly rather
  than silently changing their behavior.  The XPM vector backend must remain
  documented as independent single-bit crossings, not an atomic bus transfer.
- [ ] Keep `SynchronizerEdge`, `SynchronizerOneShot`, the vector wrappers, and
  the counter/status hierarchy composed from lower-level SURF primitives.
  Propagate `SYNTH_MODE_G` only where the selected backend preserves latency,
  reset, and pulse semantics.
- [ ] Keep `SynchronizerOneShot` off `xpm_cdc_pulse` because the interfaces are
  not equivalent.  Add a separate source-clock-aware pulse-transfer primitive
  only if a real application requires one.

#### 3. Regression And Manual Vivado Validation

- [ ] Add focused GHDL/cocotb regressions for every changed public primitive.
  Existing inferred-mode tests must continue to cover default generics so the
  backend refactor cannot change current users accidentally.
- [ ] Cover scalar and vector level transfer, active-high and active-low reset,
  synchronous and asynchronous reset, initialization, bypass/common-clock
  operation, multiple synchronization depths, and edge/pulse behavior where
  applicable.
- [ ] For `SynchronizerHandshake`, cover unrelated clock ratios and phases,
  backpressure through external destination acknowledgment, back-to-back
  transfers, source-send protocol violations, reset/startup behavior, and data
  stability for the complete handshake.
- [ ] Add a manual Vivado regression configuration that runs the same stimulus
  against `SYNTH_MODE_G = "inferred"` and `SYNTH_MODE_G = "xpm"`, compares the
  externally visible transaction sequence and data, and allows only documented
  latency differences.
- [ ] Keep the Vivado/XPM comparison out of normal CI because the CI environment
  does not provide Vivado.  Document the exact manual command and supported
  Vivado version/family matrix so it can be rerun before release.
- [ ] For each XPM-capable primitive, run elaboration/synthesis and
  `report_cdc`; confirm that the XPM hierarchy is recognized and that no new
  critical CDC findings are hidden by the backend wrapper.

#### 4. Document The Synchronizer Library

- [ ] Create `base/sync/README.md` and link it from `base/README.md`.
- [ ] Describe every public synchronizer/reset/status primitive, its intended
  source signal type, whether it preserves vector coherency, whether events can
  be lost, whether it buffers transfers, reset assumptions, latency, and the
  supported inferred/XPM modes.
- [ ] Include a short selection guide covering unrelated status bits, coherent
  vectors, pulses/events, resets, counters/rates, continuous streams, and
  common-clock bypasses.
- [ ] Call out unsafe or easily misunderstood uses explicitly, especially
  changing binary words through `SynchronizerVector`, narrow pulses through a
  level synchronizer, and unbounded event rates through a one-shot.

#### Gray CDC Scope Decision

No standalone Gray synchronizer is planned in this work.  `xpm_cdc_gray` is
limited to binary values that move by exactly one count between source samples.
The primary SURF use case is asynchronous FIFO pointer transfer, and
`base/fifo/rtl/inferred/FifoAsync.vhd` already performs the Gray conversion,
crossing, and pointer comparison as one protocol.  Reconsider a public Gray
primitive only if a non-FIFO monotonic counter/address use case is identified;
arbitrary addresses and configuration vectors belong on the handshake path.

### CDC-C01: AxiStreamFrameBuffer Atomic Address Transfer

Completed on 2026-08-24 in
`axi/axi-stream/rtl/AxiStreamFrameBuffer.vhd`:

- Replaced the independently synchronized final-address/setup-done vector with
  a one-shot `SynchronizerFifo` transfer of the final address.
- Kept `rdSetupDone` as a separately synchronized scalar level for the return
  handshake only.  FIFO `valid` now exclusively qualifies the atomic address
  payload, while the existing `rdMoveDone` handshake holds the source state
  until readout completes.
- Preserved the `COMMON_CLK_G` bypass path and the existing public interface.

Validation:

- `vsg` reported zero violations for `AxiStreamFrameBuffer.vhd`.
- `tests/axi/axi_stream/test_AxiStreamFrameBuffer.py` passed all four
  asynchronous/synchronous and safe/unsafe buffer configurations (4 passed).
- Vivado `report_cdc` confirmation remains outstanding.

## Current Status

Static CDC-2/5/6/8/10/12 source audits and the initial SURF/XPM backend mapping
are complete. CDC-C01 has a validated provisional FIFO fix pending the new
handshake primitive; CDC-B01 and CDC-B02 remain the next maintained-source
cleanup after the primitive direction is settled. Authoritative Vivado reports
and the supported-version check for `xpm_cdc_handshake` remain outstanding
because Vivado is not available in the current environment. The next planned
implementation step is to finalize the `SynchronizerHandshake` interface and
reset contract, then build its inferred regression before adding XPM backend
selection to the existing primitives.
