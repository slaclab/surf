# RX RTL proof

Status: RX slice implemented; reference comparison, physical simulation,
real-MAC loss experiments, and generic GHDL synthesis pass. Device timing and
full endpoint integration remain open. This record follows the
[selected RX boundary](rx-frontend-design.md); it does not close R4–R6 or claim
a complete endpoint.

## Implemented boundary

The new [PtpCore source area](../../../ethernet/PtpCore/README.md) contains
`PtpPkg`, `PtpRxTimestampAdapter`, `PtpRxFrontend`, and a thin simulation wrapper.
The shared adapter selects GMII/XGMII at elaboration and owns only RX; TX
completion remains future work. The planned combined RX/TX TimestampTap names
have not been implemented as empty wrappers around this proof.

The adapter validates preamble/control framing and samples the PHC at the
first destination-MAC byte, avoiding extrapolation across a PHC command edge.
It records unsteered whole ticks and eighth-cycle phase at that same point,
scales XGMII sub-cycle time with the supplied active Q32 PHC increment, and
subtracts signed Q16 ingress calibration exactly once. It normalizes seconds
carry/borrow and marks epoch underflow/overflow as invalid capture. Calibration
is currently an elaboration-time generic; division of that constant into
seconds/remainder occurs outside the runtime datapath. PHC inputs must be
canonical, with the small positive increment appropriate to 125/156.25 MHz.

One normalized AXI/SSI register carries both SOF data and capture. The
frontend consumes at most eight bytes per clock without ready. It uses SURF's
parallel CRC functions, a bounded prefix/header decoder, streaming TLV length
state, and a small register queue. Unlike the Python oracle, it need not hold
back four FCS bytes: a complete record is admitted only when declared PTP
length fits entirely before FCS. Prefix data outside the fixed body is never
published. CRC conventions are independently tested against zlib wire FCS.

RX overflow, logical flush, and generation change suppress transfer on the
same edge and clear pending records; logical flush also discards partial
decode. The queue exports a 32-bit epoch and saturating accepted, rejected,
and overflow counters. System reset clears counters and epoch. A future
consumer must share the reset/abort contract; a local reset alone cannot
invalidate already transferred records elsewhere.

`EthMacPtpExperimentWrapper` gains an opt-in simulation-only RX proof instance
and flat ports. Its default remains disabled. The production `EthMacTop`,
importers, filters, FIFOs, and primary interface are unchanged. `ethernet/ruckus.tcl`
loads PtpCore for Vivado and GHDL; the nearest manifest marks wrappers simulation-only.

## Validation

The final physical regression passed three configurations: direct/depth-one,
XGMII/depth-four with +7.25 ns ingress calibration, and GMII/depth-four with
−3.5 ns calibration and active-low asynchronous reset. Each compares queue
head, complete record fields, generation/epoch, transfer/abort, and admission/
overflow counters against the independent bounded model on every edge.

The real-MAC proof passed: all 240 valid frontend records retained their own
wire timestamps while a stalled 512-word MAC RX FIFO dropped copies. A bad-FCS
duplicate emitted no record. Restarting the frontend while old MAC data stayed
buffered did not publish that old data when the MAC later drained. Independent
frontend overflow flushed its queue and recovered on a fresh frame.

The final model/RTL run passed 63 pytest cases: 60 Python reference cases and
three cocotb configurations. Coverage includes both minor versions, rejected
EtherType/version/type/length, every final-byte alignment, empty termination,
maximum-length TLVs, unterminated oversize, exact twelve-slot XGMII gaps,
non-nominal PHC increments, second carry/borrow, epoch-underflow rejection,
stalls, full-before-edge overflow with ready high, and flush/generation/reset
at physical or completed-frame boundaries. Clocks are 125 MHz for GMII and
156.25 MHz for XGMII. `TPD_G` is the default 1 ns in these runs.

The three legacy MAC counterexample scenarios also passed. The final RX/MAC
scenario passed in a separate rerun after correcting a wrapper-formatting
compile error in the combined invocation; the error did not alter production
RTL. In total, 60 reference cases and seven cocotb scenarios passed. The last
wrapper formatting pass was checked to preserve all non-comment VHDL tokens.
All five edited VHDL files passed VSG, Python passed flake8, the final ruckus
import passed, and local documentation links/SVG XML and whitespace were checked.

GHDL synthesis succeeded for the validator and both physical adapter choices.
Inspection prompted moving capture arithmetic out of the eight-lane decoding
loop so it is computed once per accepted SOF. Synthesis passed again after
that change. This source restructuring is not a measured device-area saving.
Generated netlists and logs stay in temporary storage. They are
generic synthesis evidence, not a device utilization or timing report. Vivado
and Yosys are unavailable on this host; routed 125/156.25 MHz timing and FPGA
LUT/FF/BRAM counts remain unverified.

Reproduce functional checks from the repository root:

```sh
make MODULES="$PWD" import
./.venv/bin/python -m pytest -n 0 -q tests/ethernet/PtpCore
./.venv/bin/flake8 tests/ethernet/PtpCore
./.venv/bin/vsg -c vsg-linter.yml -f ethernet/PtpCore/rtl/*.vhd ethernet/PtpCore/wrappers/*.vhd ethernet/EthMacCore/wrappers/EthMacPtpExperimentWrapper.vhd
git diff --check
```

GHDL synthesis used a temporary `surf` library analyzing `StdRtlPkg`, `AxiPkg`,
`AxiStreamPkg`, `SsiPkg`, `CrcPkg`, and the three PTP RTL files, with
`--std=08 --ieee=synopsys -frelaxed-rules`. `ghdl --synth` then targeted
`PtpRxFrontend` and `PtpRxTimestampAdapter` with default XGMII and with
`-gPHY_TYPE_G=GMII`. Calibration was zero for these generic synthesis runs;
the nonzero signed calibration cases were simulated. Device qualification must
check the unrolled decode/length paths and wide capture normalizer, adding
pipelines if needed while preserving capture, completion, and abort together.

## Remaining gates and handoff

- R3: device timing/resource qualification remains.
  This slice verifies the producer and boundary transfer, but `PtpPort` does
  not yet exist; abort must also win over its future measurement commit and
  invalidate any downstream pending work.
- R4: integrate finite generations, consumer reset/flush acknowledgement, PHC
  discontinuity, and command/capture ordering. No CDC or production PHC is
  present in these benches; their PHC inputs come from independent Python time.
- R5: include byte phase in the fixed-point elapsed-time path and qualify the
  estimator under packet-delay variation. Raw unsteered coordinates describe
  the MAC/PCS point, while protocol timestamps have latency correction. The
  elapsed-master-time reconstruction must account for that reference-plane
  displacement as well; substituting raw tick differences silently loses
  ingress/egress calibration. Freeze the calibration units/conversion with
  the rate estimator before integrating E2E arithmetic.
- R6: implement exclusive TX identity, admission/retirement, wire completion,
  and quarantine/drain/reset rules. The RX proof does not release these gates.

Next work is the integrated PHC/generation contract and rate-estimator model,
while device synthesis can qualify this RX slice. Keep endpoint assembly gated
on those contracts; structural RX validation does not enforce the port profile.
