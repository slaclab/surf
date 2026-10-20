#-----------------------------------------------------------------------------
# Title      : PTP telemetry records
#-----------------------------------------------------------------------------
# Description:
# Decoder, encoder and Rogue receiver for PtpTelemetry records
# (ethernet/PtpCore/telemetry.md).
#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import numpy as np
import pyrogue as pr

TELEMETRY_VERSION = 1
PHC_RECORD = 1
MEASUREMENT_RECORD = 2
SERVO_RECORD = 3
RECORD_WORDS = {PHC_RECORD: 8, MEASUREMENT_RECORD: 27, SERVO_RECORD: 19}
SERVO_STATES = {0: 'Disabled', 1: 'Acquiring', 2: 'Tracking', 3: 'Locked', 4: 'Holdover', 5: 'Fault'}

_M64 = (1 << 64) - 1


def _bits(value, low, width):
    return (value >> low) & ((1 << width) - 1)


def _signed(value, width):
    return value - (1 << width) if value >> (width - 1) else value


def _wide(words, index, width):
    """Little-endian multi-word field: least significant 64 bits first."""
    value = 0
    for i in range((width + 63) // 64):
        value |= words[index + i] << (64 * i)
    return value & ((1 << width) - 1)


def localTimeQ16(timestamp):
    """96-bit local capture (s48, ns32, fraction16) to Q16 nanoseconds."""
    return ((timestamp >> 48) * 1_000_000_000 + _bits(timestamp, 16, 32)) * 65536 + _bits(timestamp, 0, 16)


def wireTimeQ16(timestamp):
    """80-bit wire timestamp (s48, ns32) to Q16 nanoseconds."""
    return localTimeQ16(timestamp << 16)


def decodeTelemetry(words):
    """Decode one record (a sequence of 64-bit words) into a dict.

    Raises ValueError for an unknown version or type or a wrong length.
    Signed Q16 quantities are returned both raw (``*Q16``) and in float
    nanoseconds or ppb.
    """
    words = [int(w) & _M64 for w in words]
    if not words:
        raise ValueError('empty telemetry record')
    w0, w1 = words[0], words[1] if len(words) > 1 else 0
    version, kind = _bits(w0, 0, 8), _bits(w0, 8, 8)
    if version != TELEMETRY_VERSION:
        raise ValueError(f'unsupported telemetry version {version}')
    if kind not in RECORD_WORDS:
        raise ValueError(f'unknown telemetry record type {kind}')
    if len(words) != RECORD_WORDS[kind]:
        raise ValueError(f'record type {kind} has {len(words)} words, expected {RECORD_WORDS[kind]}')

    rec = {
        'version': version,
        'type': kind,
        'endpoint': _bits(w0, 16, 8),
        'cause': _bits(w0, 24, 8),
        'sequence': _bits(w0, 32, 32),
        'dropped': _bits(w1, 0, 32),
        'servoState': _bits(w1, 32, 3),
        'timeValid': _bits(w1, 35, 1),
        'portActive': _bits(w1, 36, 1),
        'linkReady': _bits(w1, 37, 1),
        'fault': _bits(w1, 38, 1),
        'phcSeconds': _bits(words[2], 0, 48),
        'phcNanoseconds': _bits(words[3], 0, 32),
        'phcFraction': _bits(words[3], 32, 32),
        'phcTicks': words[4],
        'phcRate': _signed(words[5], 64),
        'phcGeneration': _bits(words[6], 0, 32),
    }
    rec['phcTime'] = rec['phcSeconds'] + (rec['phcNanoseconds'] + rec['phcFraction'] / 2**32) * 1e-9

    if kind == PHC_RECORD:
        rec['phcIncrement'] = words[7]
    elif kind == MEASUREMENT_RECORD:
        w7 = words[7]
        rec.update({
            'isDelay': _bits(w7, 0, 1),
            'ratioValid': _bits(w7, 1, 1),
            'syncSequence': _bits(w7, 16, 16),
            'delaySequence': _bits(w7, 32, 16),
            'generation': _bits(words[8], 0, 32),
            'ticks': words[9],
            'forwardQ16': _signed(_wide(words, 10, 128), 128),
            'delayQ16': _signed(_wide(words, 12, 128), 128),
            'ratio': words[14],
            't1': _wide(words, 15, 80),
            't2': _wide(words, 17, 96),
            't3': _wide(words, 19, 96),
            't4': _wide(words, 21, 80),
            'syncCorrectionQ16': _signed(_wide(words, 23, 128), 128),
            'delayCorrectionQ16': _signed(words[25], 64),
            'exchangeSyncSequence': _bits(words[26], 0, 16),
            'exchangeDelaySequence': _bits(words[26], 16, 16),
            'exchangeGeneration': _bits(words[26], 32, 32),
        })
        rec['forwardNs'] = rec['forwardQ16'] / 65536
        rec['delayNs'] = rec['delayQ16'] / 65536
    else:
        w7 = words[7]
        rec.update({
            'commandKind': _bits(w7, 0, 3),
            'commandValue': _bits(w7, 3, 1),
            'commandGeneration': _bits(w7, 32, 32),
            'commandRate': _signed(words[8], 64),
            'commandPhaseSeconds': _signed(words[9], 64),
            'commandPhaseFraction': _signed(words[10], 64),
            'commandSetSeconds': _bits(words[11], 0, 48),
            'commandSetNanoseconds': _bits(words[12], 0, 32),
            'commandSetFraction': _bits(words[12], 32, 32),
            'offsetQ16': _signed(_wide(words, 13, 128), 128),
            'filteredDelayQ16': _signed(_wide(words, 15, 128), 128),
            'ratePpbQ16': _signed(words[17], 64),
            'state': _bits(words[18], 0, 3),
            'filterCount': _bits(words[18], 4, 3),
            'rejectedCount': _bits(words[18], 32, 32),
        })
        rec['offsetNs'] = rec['offsetQ16'] / 65536
        rec['filteredDelayNs'] = rec['filteredDelayQ16'] / 65536
        rec['ratePpb'] = rec['ratePpbQ16'] / 65536
    return rec


def encodeTelemetry(rec):
    """Inverse of decodeTelemetry for raw fields; for tests and synthetic data."""
    def get(name):
        return int(rec.get(name, 0))

    def split(value, width):
        value &= (1 << width) - 1
        return [(value >> (64 * i)) & _M64 for i in range((width + 63) // 64)]

    kind = get('type')
    words = [
        TELEMETRY_VERSION | kind << 8 | get('endpoint') << 16 | get('cause') << 24 | get('sequence') << 32,
        get('dropped') | get('servoState') << 32 | get('timeValid') << 35 | get('portActive') << 36 |
        get('linkReady') << 37 | get('fault') << 38,
        get('phcSeconds'),
        get('phcNanoseconds') | get('phcFraction') << 32,
        get('phcTicks'),
        get('phcRate') & _M64,
        get('phcGeneration'),
    ]
    if kind == PHC_RECORD:
        words += [get('phcIncrement')]
    elif kind == MEASUREMENT_RECORD:
        words += [get('isDelay') | get('ratioValid') << 1 | get('syncSequence') << 16 | get('delaySequence') << 32,
                  get('generation'), get('ticks')]
        words += split(get('forwardQ16'), 128) + split(get('delayQ16'), 128) + [get('ratio')]
        words += split(get('t1'), 128)[:1] + [get('t1') >> 64]
        words += split(get('t2'), 128)[:1] + [get('t2') >> 64]
        words += split(get('t3'), 128)[:1] + [get('t3') >> 64]
        words += split(get('t4'), 128)[:1] + [get('t4') >> 64]
        words += split(get('syncCorrectionQ16'), 128) + [get('delayCorrectionQ16') & _M64]
        words += [get('exchangeSyncSequence') | get('exchangeDelaySequence') << 16 | get('exchangeGeneration') << 32]
    elif kind == SERVO_RECORD:
        words += [get('commandKind') | get('commandValue') << 3 | get('commandGeneration') << 32,
                  get('commandRate') & _M64, get('commandPhaseSeconds') & _M64, get('commandPhaseFraction') & _M64,
                  get('commandSetSeconds'), get('commandSetNanoseconds') | get('commandSetFraction') << 32]
        words += split(get('offsetQ16'), 128) + split(get('filteredDelayQ16'), 128) + [get('ratePpbQ16') & _M64]
        words += [get('state') | get('filterCount') << 4 | get('rejectedCount') << 32]
    else:
        raise ValueError(f'unknown telemetry record type {kind}')
    return [w & _M64 for w in words]


def forwardCheckQ16(rec):
    """Recomputed t2 - (t1 + cSync) for a measurement whose Sync matches its exchange, else None."""
    if rec['type'] != MEASUREMENT_RECORD or rec['exchangeSyncSequence'] != rec['syncSequence']:
        return None
    return localTimeQ16(rec['t2']) - wireTimeQ16(rec['t1']) - rec['syncCorrectionQ16']


def classicDelayQ16(rec):
    """Unratioed E2E delay ((t2 - t1 - cSync) + (t4 - t3 - cDelay)) / 2 of the record's exchange."""
    t1, t4 = wireTimeQ16(rec['t1']), wireTimeQ16(rec['t4'])
    t2, t3 = localTimeQ16(rec['t2']), localTimeQ16(rec['t3'])
    return ((t2 - t1 - rec['syncCorrectionQ16']) + (t4 - t3 - rec['delayCorrectionQ16'])) // 2


class PtpTelemetryReceiver(pr.DataReceiver):
    """Decode one endpoint's telemetry records into Variables.

    Connect the telemetry stream to this receiver; records from other
    endpoint IDs are ignored, so several receivers may share one stream.
    SequenceGaps counts sequence numbers not yet received: a record that
    arrives after a later one (send priority) clears its own gap.
    Latest values, protocol cross-checks and fixed-length histories are
    published for display. History arrays hold the last historyDepth points
    in time order with a matching time axis: seconds of unsteered local clock
    (raw ticks times the nominal period) since the first record, unaffected
    by PHC steps. The nominal period follows each PHC record (increment minus
    rate) and starts from clockFrequency.

    ForwardCheck is the firmware forward value minus t2 - (t1 + cSync)
    recomputed from the record's exchange when its Sync matches; it should be
    zero. DelayCheck is the firmware path delay minus the unratioed E2E delay of
    the same exchange; it is small but not zero, since the firmware converts
    the local t2..t3 interval with the measured rate ratio and adds the
    configured calibration.
    """

    def __init__(self, *, endpointId=0, historyDepth=1024, clockFrequency=125.0e6, **kwargs):
        super().__init__(hideData=True, enableOnStart=True, **kwargs)
        self._endpointId = endpointId
        self._depth = historyDepth
        self._nominalNs = 1e9 / clockFrequency
        self._firstTicks = None
        self._lastSequence = None
        self._missing = set()
        self._lostGaps = 0
        self._lastPhc = None
        self._hist = {}

        def var(name, value, description, disp='{}', units=None, enum=None):
            self.add(pr.LocalVariable(
                name        = name,
                value       = value,
                mode        = 'RO',
                disp        = disp,
                units       = units,
                enum        = enum,
                description = description,
            ))

        var('Records',            0, 'Records decoded for this endpoint.')
        var('PhcRecords',         0, 'PHC records decoded.')
        var('MeasurementRecords', 0, 'Measurement records decoded.')
        var('ServoRecords',       0, 'Servo records decoded.')
        var('FormatErrors',       0, 'Frames that failed to decode (version, type or length).')
        var('Dropped',            0, 'Firmware dropped-record count in the latest header.')
        var('SequenceGaps',       0, 'Record sequence numbers not received; a late record removes its gap.')
        var('LastSequence',       0, 'Record sequence number of the latest record.')

        var('PhcTime',       0.0, 'PHC time of the latest record, seconds.', '{:.9f}', 's')
        var('PhcGeneration', 0,   'PHC generation of the latest record.')
        var('TimeValid',     False, 'PHC timeValid in the latest record.')
        var('PortActive',    False, 'Port active in the latest record.')
        var('LinkReady',     False, 'Link ready in the latest record.')
        var('ServoState',    0, 'Servo state in the latest record.', enum=SERVO_STATES)
        var('RateCommandPpb', 0.0, 'PHC rate addend relative to the nominal increment.', '{:.3f}', 'ppb')
        var('AppliedRatePpb', 0.0, 'PHC frequency offset measured between PHC records.', '{:.3f}', 'ppb')

        var('OffsetNs',        0.0, 'Servo offset from the latest servo record.', '{:.3f}', 'ns')
        var('FilteredDelayNs', 0.0, 'Servo filtered path delay.', '{:.3f}', 'ns')
        var('ServoRatePpb',    0.0, 'Servo rate command.', '{:.3f}', 'ppb')
        var('FilterCount',     0, 'Populated servo delay-filter samples.')
        var('RejectedCount',   0, 'Servo rejected-sample count.')

        var('ForwardNs',      0.0, 'Latest forward (Sync) measurement.', '{:.3f}', 'ns')
        var('PathDelayNs',    0.0, 'Latest path-delay measurement.', '{:.3f}', 'ns')
        var('SyncSequence',   0, 'Sync sequence of the latest measurement.')
        var('DelaySequence',  0, 'Delay_Req sequence of the latest measurement.')
        var('ForwardCheckNs', 0.0, 'Firmware forward minus the value recomputed from t1, t2 and cSync.', '{:.6f}', 'ns')
        var('DelayCheckNs',   0.0, 'Firmware path delay minus the unratioed E2E delay of the same exchange.', '{:.6f}', 'ns')
        var('ForwardMismatches', 0, 'Matched forward values that differ from the recomputation.')

        for name, units in (('Offset', 'ns'), ('PathDelay', 'ns'), ('ServoRate', 'ppb'),
                            ('AppliedRate', 'ppb'), ('Forward', 'ns')):
            self._hist[name] = ([], [])
            var(f'{name}History', np.zeros(0), f'Last {historyDepth} values.', units=units)
            var(f'{name}Times', np.zeros(0), f'Local-clock seconds of {name}History.', units='s')

    def _localSeconds(self, ticks):
        if self._firstTicks is None:
            self._firstTicks = ticks
        return ((ticks - self._firstTicks) & _M64) * self._nominalNs * 1e-9

    def _push(self, name, t, value):
        times, values = self._hist[name]
        times.append(t)
        values.append(value)
        if len(times) > self._depth:
            del times[0]
            del values[0]
        self.node(f'{name}History').set(np.array(values, dtype=np.float64))
        self.node(f'{name}Times').set(np.array(times, dtype=np.float64))

    def _bump(self, name):
        var = self.node(name)
        var.set(var.value() + 1)

    def process(self, frame):
        size = frame.getPayload()
        if size == 0 or size % 8:
            self._bump('FormatErrors')
            return
        words = frame.getNumpy(0, size).view(np.uint64)
        try:
            rec = decodeTelemetry(words)
        except ValueError:
            self._bump('FormatErrors')
            return
        if rec['endpoint'] == self._endpointId:
            self.handle(rec)

    def handle(self, rec):
        """Apply one decoded record; also usable directly for offline replay."""
        self._bump('Records')
        # Records may arrive slightly out of sequence order (priority and a
        # servo record's status capture); a late one fills its gap.
        seq = rec['sequence']
        if self._lastSequence is None:
            self._lastSequence = seq
        else:
            ahead = (seq - self._lastSequence) & 0xFFFFFFFF
            if 0 < ahead < 0x80000000:
                for missing in range(1, ahead):
                    self._missing.add((self._lastSequence + missing) & 0xFFFFFFFF)
                self._lastSequence = seq
            else:
                self._missing.discard(seq)
            while len(self._missing) > 4096:
                self._missing.remove(min(self._missing))
                self._lostGaps += 1
        self.SequenceGaps.set(self._lostGaps + len(self._missing))
        self.LastSequence.set(self._lastSequence)
        self.Dropped.set(rec['dropped'])
        self.PhcTime.set(rec['phcTime'])
        self.PhcGeneration.set(rec['phcGeneration'])
        self.TimeValid.set(bool(rec['timeValid']))
        self.PortActive.set(bool(rec['portActive']))
        self.LinkReady.set(bool(rec['linkReady']))
        self.ServoState.set(rec['servoState'])
        self.RateCommandPpb.set(rec['phcRate'] / 2**32 / self._nominalNs * 1e9)
        t = self._localSeconds(rec['phcTicks'])

        if rec['type'] == PHC_RECORD:
            self._bump('PhcRecords')
            nominal = (rec['phcIncrement'] - rec['phcRate']) / 2**32
            if nominal > 0:
                self._nominalNs = nominal
            # Exact integer Q32 nanoseconds: a float cannot resolve them.
            phcQ32 = (rec['phcSeconds'] * 1_000_000_000 + rec['phcNanoseconds']) << 32 | rec['phcFraction']
            if self._lastPhc is not None and rec['phcGeneration'] == self._lastPhc[2]:
                dTicks = (rec['phcTicks'] - self._lastPhc[0]) & _M64
                if dTicks:
                    elapsed = (phcQ32 - self._lastPhc[1]) / 2**32
                    applied = (elapsed / (dTicks * self._nominalNs) - 1.0) * 1e9
                    self.AppliedRatePpb.set(applied)
                    self._push('AppliedRate', t, applied)
            self._lastPhc = (rec['phcTicks'], phcQ32, rec['phcGeneration'])

        elif rec['type'] == MEASUREMENT_RECORD:
            self._bump('MeasurementRecords')
            self.SyncSequence.set(rec['syncSequence'])
            self.DelaySequence.set(rec['delaySequence'])
            if rec['isDelay']:
                self.PathDelayNs.set(rec['delayNs'])
                self._push('PathDelay', t, rec['delayNs'])
                if rec['exchangeDelaySequence'] == rec['delaySequence']:
                    self.DelayCheckNs.set((rec['delayQ16'] - classicDelayQ16(rec)) / 65536)
            else:
                self.ForwardNs.set(rec['forwardNs'])
                self._push('Forward', t, rec['forwardNs'])
                check = forwardCheckQ16(rec)
                if check is not None:
                    diff = rec['forwardQ16'] - check
                    self.ForwardCheckNs.set(diff / 65536)
                    if diff:
                        self._bump('ForwardMismatches')

        else:
            self._bump('ServoRecords')
            self.OffsetNs.set(rec['offsetNs'])
            self.FilteredDelayNs.set(rec['filteredDelayNs'])
            self.ServoRatePpb.set(rec['ratePpb'])
            self.FilterCount.set(rec['filterCount'])
            self.RejectedCount.set(rec['rejectedCount'])
            if rec['cause'] & 1:
                self._push('Offset', t, rec['offsetNs'])
                self._push('ServoRate', t, rec['ratePpb'])
