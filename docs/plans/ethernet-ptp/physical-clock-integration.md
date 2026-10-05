# PTP physical-clock integration

## Scope and status

This note records reusable physical-clock integration requirements alongside the
[Ethernet PTP plan](README.md). Physical reference generators, external oscillator
control and precise destination-domain time transfer remain future work. These
requirements do not change the implemented endpoint interface or make physical
clock discipline a prerequisite for the initial plain-PTP endpoint.

The source is the `spt3g-ptp` discussion at SURF commit
`11cd0250bf4512759868b360292d9eb8d7f7a2e8`, principally
`docs/plans/spt-ptp-bridge/lmk-ptp-clock-conditioning.md` and
`ptp-clock-interface.md`. Extracted on October 5, 2026. Board pin mappings,
component settings and application message formats remain in the application
project's historical notes. The source calculations are not hardware results.

## Use applied time and rate

[EthMacPtpEndpoint](../../../ethernet/PtpCore/rtl/EthMacPtpEndpoint.vhd) exports
`phcTime`, `phcStatus`, `pps` and `servoState`. Their records are defined in
[PtpPkg](../../../ethernet/PtpCore/rtl/PtpPkg.vhd). For a generator driven from
the same clock domain as the PHC:

| Value | Interpretation |
| --- | --- |
| `phcTime` | Seconds, nanoseconds and fractional nanoseconds; the running time coordinate in the endpoint domain. |
| `phcStatus.increment` | Applied unsigned Q32 nanoseconds per endpoint cycle, including the nominal increment and committed rate correction. |
| `phcStatus.rate` | Applied signed Q32 correction to the nominal increment, in nanoseconds per endpoint cycle. |
| `generation`, `discontinuity`, `timeValid`, `fault` | PHC lifecycle and validity information that the generator must interpret under an explicit recovery policy. |
| `pps` | Enabled, valid second-rollover marker on the endpoint clock grid. |
| `servoState` | Synchronization-state summary; qualify separately from downstream clock health. |

Use the applied increment when deriving waveform frequency. The internal
`PtpServo.status.ratePpb` is a signed Q16 ppb diagnostic that includes frequency
and phase-slew terms; it can change before the corresponding PHC command commits.
The combined endpoint does not export that full diagnostic record. Treating it
as an already-applied physical actuator command would lose the command timing
and unit distinctions. Raw PHC ticks count unsteered endpoint cycles.

A waveform generator in another clock domain needs coherent transfer and an
explicit conversion between cycle rates. Nanoseconds per Ethernet cycle cannot
be reused unchanged as nanoseconds per destination cycle. An independently
clocked oscillator also needs a measured or specified frequency relationship;
copying the PHC correction to its DAC code does not close that oscillator's loop.

## Reference generation and external cleanup

Evaluate an FPGA-derived periodic reference feeding an external PLL/VCXO, with
the PLL providing physical clock cleanup. Keep numerical time, waveform
production, oscillator control and application epoch transfer as separate
responsibilities. Device configuration over SPI and the continuous fine-frequency
actuator may be different interfaces.

A fabric phase accumulator is a candidate alongside the
[MMCM phase-stepping approach](README.md#experimental-fpga-generated-frequency-output).
In the PHC domain, its phase advance is:

```text
reference cycles per endpoint cycle
    = desired reference frequency [Hz]
    * applied PHC increment [ns per endpoint cycle]
    * 1e-9 [seconds per ns]
```

Decode the Q32 increment or include its scale in the fixed-point arithmetic.
Fine accumulator resolution improves average frequency; physical edges remain
quantized to the generating clock's edge grid. An external PLL may attenuate
this modulation, but deterministic patterns, detuning and slow spurs still
require analysis and measurement. Choose reference frequency, duty cycle,
minimum pulse width and output buffering to meet the receiving device's limits.

Preserve waveform continuity through rate changes. A PHC time step must invoke
a defined reacquisition policy; immediately reloading waveform phase can produce
short or extra pulses. Do not asynchronously gate a live clock. MMCM variants
must additionally obey their request/completion handshake and expose saturation,
lock and fault state. A generic rate/phase actuator interface is still a proposal,
not a record already implemented by the endpoint.

Derive same-oscillator MMCM steering from the applied PHC rate with explicit
units. For direct control of an independent VCXO, provide a separate measurement
and control loop with defined gain, polarity, update rate, limits and holdover.
Give each tuning node one owner. If the PHC itself moves onto a controlled clock,
review estimator/actuator ownership to avoid correcting the same error twice.
Preserve the endpoint's required clock continuity and PHY frequency contract.

External loop design must pass the intended slow steering while filtering faster
reference modulation. Reference frequency and divider changes can alter stability
and acquisition behavior; a convenient ratio is not sufficient evidence. Verify
oscillator pull range, loop gain and actuator resolution for the actual hardware.
A recovered Ethernet clock requires an independently established traceability
contract; PTP-aware switching alone does not establish SyncE capability.

## Clock health, epoch and recovery

Qualify these conditions separately: PTP synchronization, PHC time validity,
reference-generator health, external PLL lock, and usable application timing.
For example, loss of PTP packets can leave the reference waveform running and
the external PLL locked while time quality expires.

The integration must define:

- Startup order, accepted time quality and when application timing becomes valid.
- Holdover rate, quality expiry and the policy for continued waveform generation.
- Response to reference loss, stopped clocks, actuator saturation and PLL unlock.
- Recovery after source changes, PHC generation changes, time steps and resets.
- Ownership of shared PLL configuration, alignment controls and resets.

[PtpPhcRead](../../../ethernet/PtpCore/rtl/PtpPhcRead.vhd) supplies coherent
snapshots. A snapshot does not provide continuously advancing or
latency-compensated time in the receiving clock domain. The
[existing CDC and application plan](README.md#clock-domain-crossing-and-application-use)
already distinguishes these uses. A precise consumer must define its reference
edge, time-transfer latency, epoch/timescale conversion, divider alignment and
common event/counter origin. Frequency lock alone cannot establish those values.

Verify the physical route all the way through the consumer, including dedicated
transceiver reference inputs where needed. A cleaned fabric clock does not prove
that an outgoing serial timing link follows it. Avoid feedback that locks a
source to a recovered copy of its own transmitted timing.

## Qualification and next steps

Define numerical acceptance limits before choosing the actuator and cleanup loop.
Separate absolute timestamp error, inter-device event alignment, frequency
agreement, local jitter and sample-clock phase repeatability. Independent
endpoints can have different network/calibration errors despite low local jitter.

Compare accumulator and MMCM candidates using the actual external loop and
oscillator. The hardware qualification plan must cover:

1. Average frequency, phase noise, deterministic spurs and time error across the
   complete correction/slew range and temperature range.
2. Reset, time-step, source/link loss, holdover, quality expiry and reacquisition;
   check waveform integrity as well as convergence and phase repeatability.
3. Direct and switched network paths under traffic, including independent
   endpoint resets and rejoin.
4. Both the local cleaned output and the remote recovered clock or application
   event. Account for connector/PHY calibration and distribution skew.

Use independent measurements: endpoint self-reported offset and PLL lock alone
cannot establish timing accuracy. Current validation is limited to documentation
links, heading anchors and whitespace. No RTL changed and no simulation or
hardware measurements were run; the existing RTL-review simulation pause remains
in force. Next work is requirements selection, actuator/loop design and the
corresponding implementation and qualification, subject to that review gate.
