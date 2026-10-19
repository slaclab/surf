# PHC subsystem contract

`PtpPhcCore` is the one PTP hardware clock (PHC) subsystem used by both
compositions: standalone, where a software controller or an external command
client steers it, and inside the autonomous `PtpEndpoint`, where `PtpServo` is
the external client. The core contains `PtpPhcControl`, `PtpPhc` and, when
manual steering is compiled in, a private one-client `PtpSecondService`; it has
no protocol engine, servo or variable divider. `CONTROL_MODE_G` selects which
command sources exist (§3.1). This guide owns the core's source interface, ownership and admission
rules, coordination handshakes, reset lifetimes and register map. The
[timing-port contract](timing-port.md) owns packet transport;
[interfaces.md](interfaces.md) owns the command record timing it reuses.

The PTP implementation is unreleased. This contract replaces the former
endpoint-owned PHC wiring and four-bank map; no compatibility wrapper exists.

## 1. Composition

| Block | Responsibility |
| --- | --- |
| `PtpPhc` | Running time, applied increment, raw ticks, generation, PPS, manual operands/normalization, snapshots, and final command admission, commit and acknowledgement. The numerical algorithm is unchanged from the former endpoint PHC. |
| `PtpPhcControl` | Identity/capabilities, committed owner selection, configuration and snapshot coordination (local, or as a participant of an enclosing coordinator), PHC event IRQ. |
| `PtpPhcCore` | Upstream AXI-Lite interface, optional management-clock crossing, local two-slot crossbar, the blocks above and, unless `CONTROL_MODE_G = "EXTERNAL"`, a private `PtpSecondService` with `NUM_CLIENTS_G = 1`, `WIDTH_G = 128`. |

| Generic | Default | Meaning |
| --- | --- | --- |
| `AXIL_BASE_ADDR_G` | `0` | 8 KiB-aligned base of the local aperture. |
| `CLK_FREQ_G` | 156250000 | PHC clock frequency; sets the nominal Q32 increment. |
| `COMMON_CLK_G` | `true` | `false` inserts `AxiLiteAsync` from `axilClk` to `clk`. |
| `CONTROL_MODE_G` | `"SELECTABLE"` | `"AXI"`, `"EXTERNAL"` or `"SELECTABLE"` (§3.1). Other values fail elaboration. |
| `EXT_COORDINATION_G` | `false` | `true` makes the core a participant of an enclosing coordinator (§4.2); local CommitConfig/Snapshot return SLVERR. |

All PHC outputs, commands and coordination records are in `clk`. Only AXI-Lite
transactions cross clock domains. The live `phcTime`/`phcStatus`/`captureAbort`
tuple is consumed in `clk` by timestamp adapters and `PtpMacPortEthMac`;
`PtpPhcRead` remains the coherent snapshot service for another clock domain.

| Port | Direction | Meaning |
| --- | --- | --- |
| `clk`, `rst` | in | PHC clock and system reset (§6). |
| `axilClk`, `axilRst` | in | Management clock/reset; ignored when `COMMON_CLK_G = true`. |
| `regRst` | in | AXI-only reset in `clk` (§6). |
| `axil*Master/Slave` | in/out | Local aperture. |
| `restart` | in | Controller restart: vetoes accepted external work inside the pre-commit window. |
| `commandAbort` | in | Held controller abort; cancels external work once per assertion. |
| `commandMaster`/`commandSlave` | in/out | External command client, [registered command interface](interfaces.md#registered-command-and-expiry-interface). |
| `clearValid` | in | External controller's registered qualification revocation; effective only while it is the active owner. |
| `configControl`, `snapshotControl` | in | Enclosing coordinator strobes; used only when `EXT_COORDINATION_G = true`. |
| `configPrepared`, `configValid`, `snapshotPrepared`, `manualBusy` | out | Participant handshake to the enclosing coordinator. |
| `phcTime`, `phcStatus`, `captureAbort`, `pps` | out | Registered live clock tuple and PPS. |
| `externalOwner` | out | Registered: the committed owner is the external command client. |
| `irq` | out | Masked sticky PHC events. |

## 2. Commands, units and normalization

Commands reuse `PtpPhcCommandType` and its master/slave records. SET names the
commit-edge time (seconds48, nanoseconds below 10^9, Q32 fraction). PHASE adds
whole seconds plus a signed Q32 remainder strictly inside one second to the
normally advanced time. RATE sets a signed Q32 ns/cycle addend; the increment
`nominal + addend` must lie in (0, 1 s). VALID sets qualification; PPS sets the
output enable. A command accepted on edge N commits on N+1 and acknowledges on
N+1; `error` accompanies `ack`.

Manual PHASE takes a signed Q16-nanosecond 128-bit submission. The upper 32
bits must sign-extend the lower 96, otherwise the command completes with
CommandError and no clock effect. The private SECOND service truncates toward
zero; the quotient must fit signed64 and the remainder signed48, otherwise
CommandError. Normalization runs in the clock domain and survives AXI reset.

## 3. Ownership and admission

The committed owner is either **AXI** (`Owner = 0`, reset value) or the
**external** client (`Owner = 1`). Exactly one may steer. The selector
distinguishes AXI from the external port only; it cannot distinguish two
software agents writing the same AXI bank (§7).

| Request | Admitted when | Otherwise |
| --- | --- | --- |
| AXI SET/PHASE/RATE/VALID | Owner AXI, no configuration transaction, no manual command in progress, kind ≤ PPS. | SLVERR on the `PhcCommand` write; no operand freeze, normalization, slot use or capture inhibition. |
| AXI PPS | Any owner, same transaction/manual-busy rules. | SLVERR. |
| External command | `commandSlave.ready` registered high and `valid`, with `cancel`/`stale` low. Ready is high only when owner is external, no configuration transaction is in progress, the slot is free, no manual request is waiting and the PHC has not faulted. | Not admitted. No ack is ever reported for an unaccepted request; the client holds or withdraws its offer. |

Ready is registered. A ready published on the edge a transaction begins can
still admit once; §4.1 drains that command before any owner change. AXI PPS is
the only cross-owner command. It uses the shared slot and its completion
returns only to the AXI bank (`CommandAck`/`CommandError`), never to
`commandSlave`. A non-owner can therefore neither occupy the slot, inhibit
captures nor alter clock state.

Accepted ownership is retained through acknowledgement. Accepted external work
is still vetoed before commit by `cancel`, `stale`, `restart`, a new
`commandAbort` assertion or loss of external ownership. That last veto cannot
fire in normal operation, because owner changes wait for an idle slot.

### 3.1 Build-time control modes

| `CONTROL_MODE_G` | Compiled command paths | Owner |
| --- | --- | --- |
| `"AXI"` | Manual SET/PHASE/RATE/VALID/PPS with operands and PHASE normalization. No external admission (`commandSlave` idle) and no `clearValid` revocation. | Fixed AXI (`Owner = 0`, read-only). |
| `"EXTERNAL"` | External client only. Manual SET/PHASE/RATE/VALID submission, the operand words (`0x1028`–`0x104F`, DECERR) and the private SECOND converter are omitted; AXI PPS remains. | Fixed external (`Owner = 1`, read-only). |
| `"SELECTABLE"` | Both paths. | Committed runtime selection, reset to AXI (§4.1). |

In a fixed mode a write to `Owner` returns DECERR. Configuration and snapshot
coordination, monotonic and PPS policy, time/rate/tick snapshots, IRQs and
command bookkeeping are present in every mode, and every configuration
transaction still drains accepted commands before applying policy. A
non-present path is excluded exactly like a non-owner (§3). The capability
word reports `CommandMask` (AXI-submittable kinds: `0x1F`, or `0x10` without
manual steering), `ExternalCommand`, `ManualCommand` and `OwnerSelectable`.

Use `"SELECTABLE"` for development images that need manual override,
`"AXI"` for software control and `"EXTERNAL"` for an autonomous deployment
without override. Inside `PtpEndpoint` the servo is the external client; the
endpoint's separate `ServoEnable` runs or stops it, and stopping it never grants
AXI steering. Returning a selectable owner to the servo restarts acquisition.
The area saved by `"EXTERNAL"` has not been measured; compare matched
`"SELECTABLE"` and `"EXTERNAL"` builds before claiming it.

## 4. Configuration and snapshots

### 4.1 Transaction phases

`PtpPhcControl` owns `Owner` shadow, candidate and active state; `PtpPhc` owns
the `Monotonic` policy. Both participate in the same `PtpConfigControlType`
transaction:

| Edge (coordinator registers) | Participant behavior |
| --- | --- |
| PREPARE (`prepare`, `busy` high) | Candidate ← shadow. `busy` closes manual submission (SLVERR) and external ready. `configPrepared` falls on the next edge. |
| Drain | From the second edge after PREPARE, `configPrepared` rises once the PHC reports no manual work and no slot owner. This covers a command admitted on the PREPARE edge by an already published ready. |
| VALIDATE | Coordinator waits for every `configPrepared`, then checks votes. The core votes invalid while a manual command is still busy; both owners exist whenever the owner is selectable. |
| APPLY (`apply`) | Active owner and monotonic policy change on this edge. `busy` falls with the coordinator's return to idle; admission reopens for the new owner only. |
| Rejected | No active state changes; ConfigError and ConfigSequence report it. |

A transaction always drains, even when the owner is unchanged; this keeps the
monotonic-policy apply edge free of a pending command. Commit submission while
a manual command is in progress returns SLVERR; manual submission while a
transaction is in progress returns SLVERR. Both arrive through one AXI path, so
there is no same-edge race. An external offer held across a transaction is
admitted afterwards only if the external client is still owner; `PtpServo`
withdraws its offer when `externalOwner` falls.

### 4.2 Local and enclosing coordination

With `EXT_COORDINATION_G = false`, `PtpPhcControl` is the coordinator. Its
CommitConfig/Snapshot registers drive both participants. With
`EXT_COORDINATION_G = true`, the enclosing coordinator's records reach
`PtpPhcControl` and `PtpPhc` unchanged on the same edges as every other bank.
The core returns `configPrepared`, `configValid`, `snapshotPrepared` and
`manualBusy`. Local CommitConfig/Snapshot writes return SLVERR, so only one
coordinator drives the PHC strobes. The mode is reported in Capabilities.

Snapshots defer while a transaction is busy or `captureAbort` is high. Capture
pins pre-edge PHC state; publication follows `snapshotPrepared` and advances
the PHC bank's `SnapshotSequence` (`0x13FC`) with the coordinator's sequence.
Under enclosing coordination, the endpoint's sequence is authoritative; local
ConfigSequence/ConfigError remain zero.

## 5. Qualification, captures and PPS

`timeValid` is clock qualification, not capture usability. A capture is
unusable only when `captureAbort` is high on its sample edge. That happens on a
fault, on a discontinuity, and from SET/PHASE admission through commit
(including a SET/PHASE later rejected at commit). Captures taken with
`timeValid = 0` are usable during acquisition.

Qualification is set only by an admitted VALID(1) command. It is revoked by
VALID(0), by any SET/PHASE discontinuity, by a fault, by system reset, and by
`clearValid` **only while the external client is the active owner**. An
inactive controller, such as a faulted servo while AXI owns the clock, cannot
revoke it. Revocation does not stop time or erase rate.

PPS is one `clk` cycle on the edge where time crosses a second. It requires
PPS enable and qualification both before the edge and after that edge's
command/revocation. A VALID(0), `clearValid` or PPS-disable that takes effect
on the rollover edge suppresses that pulse; a VALID(1) or PPS-enable on that
edge first affects the next second. Physical lock, calibration validity and application
epoch validity are not represented by `timeValid`.

## 6. Reset lifetimes

| Event | Effect |
| --- | --- |
| `rst` (system) | Clears time, rate, generation, owner (AXI), policy, transactions, normalization and IRQ state. Every capture/transport consumer of the tuple must also reset. |
| `regRst`, `axilRst` | Cancel bus responses and crossbar/crossing state only. Time, active owner/configuration, shadows, accepted manual work, normalization, transactions and snapshot sessions continue. Software recovers completion through status. With a management crossing, `axilRst` is synchronized into `clk` (asynchronous assertion, `clk` release) and resets the crossbar and bank responses as `regRst` does, so a transaction the crossing abandons cannot leave downstream state waiting. `AxiLiteAsync` answers SLVERR locally until the reset has resynchronized in both domains. |
| `restart` | Vetoes accepted external work inside its pre-commit window; preserves manual work, time, rate and qualification. |
| `commandAbort` held | Vetoes once per assertion, so later holdover commands proceed. |
| PHC step | Advances generation and inhibits captures on the affected edges. It does not release TX ownership in a timing port; an outstanding request still completes through its terminal disposition with `captureValid = 0`. |

Link loss and controller restart do not reset the PHC. Holdover requires the
PHC clock to keep running; recovery from a stopped clock is a PHY-composition
decision.

## 7. Software-writer boundary

The AXI owner is the composition's single software writer. Writes from any
other software agent, including Rogue diagnostics on a Linux-owned clock, must
be blocked by the integrating access path (for example a read-only crossbar
port). That covers operand and policy writes as well as `PhcCommand`. Phase 2
provides the hardware AXI/external selector only. Linux-versus-Rogue isolation
is implemented with the Phase 5 driver, and is not claimed by this core.

## 8. Register map

The core occupies 8 KiB: `PtpPhcControl` at `0x0000` and the `PtpPhc` bank at
`0x1000`, from an 8 KiB-aligned `AXIL_BASE_ADDR_G`. The field tables are in
[register-map.md](register-map.md#ptpphccore-fields) at the endpoint's
offsets (`0x4000`/`0x5000`); subtract `0x4000` for a standalone core. Helper
conventions, strobes and DECERR follow the
[endpoint register guide](register-map.md#transactions-and-reset).

| Local offset | Contents |
| --- | --- |
| `0x000`–`0x008` | `Version` (`PTP_PHC_CORE_VERSION_C`), `Owner` (shadow when selectable, read-only when fixed), capability word. |
| `0x03C`–`0x048` | Local CommitConfig, ConfigError/ConfigBusy, ActiveOwner/CommandIdle, ConfigSequence. |
| `0x04C`–`0x054` | PHC event IRQ status, mask and write-one-to-clear. |
| `0x100`–`0x108` | Local Snapshot, SnapshotSequence, SnapshotBusy. |
| `0x1000`–`0x13FC` | [PtpPhc fields](register-map.md#ptpphc-fields). |

Command errors set `IrqStatus` bit 2 for both owners. The enclosing endpoint
keeps its own aggregate IRQ; the core's `irq` output is unused there.

## 9. Verification selection

| Fixture | Covers |
| --- | --- |
| `test_ptp_phc.py` (`PtpPhcWrapper`) | Cycle-exact numerical model, command edges, cancellation, normalization limits, snapshot reader. |
| `test_ptp_phc_core.py` (`PtpPhcCoreWrapper`) | The real core through AXI in all three modes: owner admission and transitions, no-side-effect rejection, fixed-owner write rejection, absent manual path and operands, AXI reset during normalization/transition, management reset mid-read, controller restart, snapshot/config collisions, VALID/clearValid/PPS at rollover, both frequencies, nonzero base, independent management clock. Inapplicable scenarios are skipped explicitly per mode. |
| `test_ptp_phc_mac_port.py` (`PtpPhcMacPortWrapper`) | The real core with `PtpMacPortEthMac`, GMII/125 MHz and XGMII/156.25 MHz: capture alignment at RATE/SET/PHASE, usable unqualified capture, PHC step during outstanding TX. |
| `test_ptp_reg.py`, `test_ptp_register_map.py`, endpoint/servo cases | Enclosing coordination and the endpoint map, including a fixed `"EXTERNAL"` endpoint with servo run/stop. |
