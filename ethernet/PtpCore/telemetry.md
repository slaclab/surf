# PTP telemetry stream

`PtpTelemetry` turns endpoint activity into a stream of fixed-format records:
the PHC trajectory, every accepted measurement with its exchange timestamps,
and every servo update. It observes signals only. It drives no ready and no
command, so a stalled or absent consumer can drop records but cannot delay a
measurement, a servo update or the PHC. Records are 64-bit words in one SSI
frame each, in the RSSI application stream format
(`PTP_TELEMETRY_AXIS_CONFIG_C`: eight bytes, all `tKeep`, SOF in `tUser`).

`PtpEndpoint` instantiates it when `TELEMETRY_EN_G` is true; the stream is in
the endpoint clock. `GigEthPtp` crosses it to `axilClk`. A board may merge
several endpoints' streams; the endpoint ID in each header separates them.

## Capture and loss

Each record type has one capture buffer. A trigger captures the record's
fields, including a coherent PHC sample, on its own edge. A trigger finding
its type's buffer still occupied (waiting or being sent) is a dropped record:
the dropped count increases and no partial record is ever emitted. Every
trigger, sent or dropped, takes the next record sequence number, so a gap in
the sequence shows exactly where records were lost. Buffers are sent in the
order PHC, measurement, servo when several wait.

## Common header (words 0-6)

| Word | Bits | Field |
| --- | --- | --- |
| 0 | 7:0 | Format version, `PTP_TELEMETRY_VERSION_C` (1) |
| 0 | 15:8 | Record type: 1 PHC, 2 measurement, 3 servo |
| 0 | 23:16 | Endpoint ID (`TELEMETRY_ID_G`) |
| 0 | 31:24 | Cause bits, by record type (below) |
| 0 | 63:32 | Record sequence: one per trigger, modulo 2^32 |
| 1 | 31:0 | Dropped records since reset, saturating |
| 1 | 34:32 | Servo state (`PTP_SERVO_*_C`) |
| 1 | 35 | PHC timeValid |
| 1 | 36 | Port active |
| 1 | 37 | Link ready |
| 1 | 38 | PHC fault |
| 2 | 47:0 | PHC seconds |
| 3 | 31:0 | PHC nanoseconds |
| 3 | 63:32 | PHC fraction (2^-32 ns) |
| 4 | 63:0 | PHC raw ticks: the unsteered cycle count |
| 5 | 63:0 | PHC applied rate (`phcStatus.rate`) |
| 6 | 31:0 | PHC generation |

The PHC fields and the header flags are sampled on the trigger's edge. Over
any two records, the change in PHC time against the change in raw ticks is
the frequency actually applied between them.

## PHC record (type 1, 8 words)

Emitted when the PHC seconds change and on PHC events. Cause bits: 0 second
rollover or step in seconds, 1 discontinuity, 2 generation change, 3 timeValid
change, 4 port-active or link-ready change, 5 fault.

| Word | Bits | Field |
| --- | --- | --- |
| 7 | 63:0 | PHC increment (`phcStatus.increment`) |

## Measurement record (type 2, 27 words)

Emitted for each `PtpMeasurementType` the servo accepts. Cause bit 0 is set
for a path-delay update (`isDelay`), clear for a forward (Sync) update. The
exchange fields are the port's last completed delay exchange at that edge;
its sequence numbers tell software whether it belongs to this measurement.

| Word | Bits | Field |
| --- | --- | --- |
| 7 | 0 | isDelay |
| 7 | 1 | ratioValid |
| 7 | 31:16 | Measurement syncSequence |
| 7 | 47:32 | Measurement delaySequence |
| 8 | 31:0 | Measurement generation |
| 9 | 63:0 | Measurement raw ticks |
| 10-11 | 127:0 | Forward value, signed Q16 ns (word 10 low) |
| 12-13 | 127:0 | Path delay value, signed Q16 ns |
| 14 | 63:0 | Ratio, Q16.48 master ns per raw cycle |
| 15-16 | 79:0 | Exchange T1, wire timestamp (48-bit s, 32-bit ns) |
| 17-18 | 95:0 | Exchange T2, local capture (48-bit s, 32-bit ns, 16-bit fraction) |
| 19-20 | 95:0 | Exchange T3, local capture |
| 21-22 | 79:0 | Exchange T4, wire timestamp |
| 23-24 | 127:0 | Exchange Sync correction, signed Q16 ns |
| 25 | 63:0 | Exchange Delay_Resp correction, signed Q16 ns |
| 26 | 15:0 | Exchange syncSequence |
| 26 | 31:16 | Exchange delaySequence |
| 26 | 63:32 | Exchange generation |

Multi-word fields put the least significant 64 bits first; unused high bits
are zero.

## Servo record (type 3, 19 words)

Emitted when the PHC accepts a servo command (cause bit 0) and when the servo
state changes (cause bit 1). For a command, the command fields are captured
on its acceptance edge and the servo status and header two edges later, after
the servo's status update; otherwise the command fields are zero.

| Word | Bits | Field |
| --- | --- | --- |
| 7 | 2:0 | Command kind (`PTP_CMD_*_C`) |
| 7 | 3 | Command value (validity/PPS commands) |
| 7 | 63:32 | Command generation |
| 8 | 63:0 | Command rate |
| 9 | 63:0 | Command phase seconds |
| 10 | 63:0 | Command phase fraction |
| 11 | 47:0 | Command set seconds |
| 12 | 31:0 | Command set nanoseconds |
| 12 | 63:32 | Command set fraction |
| 13-14 | 127:0 | Servo offset, signed Q16 ns |
| 15-16 | 127:0 | Servo filtered delay, signed Q16 ns |
| 17 | 63:0 | Servo rate, signed Q16 ppb |
| 18 | 2:0 | Servo state |
| 18 | 6:4 | Servo filter count |
| 18 | 63:32 | Servo rejected count |

## Limits

There is no runtime enable or rate control; the stream is compiled in or
out. Cross-endpoint PHC comparison and PPS-edge records are planned record
types, not part of version 1.
