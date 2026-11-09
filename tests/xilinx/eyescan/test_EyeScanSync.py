##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

# Test methodology:
# - Sweep: the activation check that the eye-scan sampler is in step with the
#   data sampler before anything is scanned, on emulated GTHE3, GTHE4,
#   GTYE3 and GTYE4 lanes: a probe at the eye centre whose error counter fills is followed by
#   another RX reset, a bounded number of times.
# - Stimulus: real Rogue transactions against Gthe3EyeModel and Gtye4EyeModel
#   with the seeded dual-Dirac BER model of the bathtub tests and a callable
#   RX reset hook. desyncResets leaves the model out of step after chosen
#   resets (error ratio 0.25 at every offset), as about every second RX reset
#   does on the C1100 GTYE4 lanes 4 and 6 at 15.46875 Gb/s; consecutive members
#   are resets that keep the out-of-step state, as one of 33 resets did there.
#   resetMode 'keep' with enableDraws is C1100 lanes 5 and 7, where a reset
#   never changes the alignment and setting the enables again draws it afresh;
#   resetMode 'flip' is lanes 4 and 6 with the enable draw made explicit.
# - Checks: an out-of-step activation is reset again and its bathtub is open,
#   where before the check it came back CLOSED with a full error counter at
#   every point; alternating resets cost one extra reset per bad activation;
#   the C1100 lane 4 sequence with one kept state ends in step every time; the
#   reset budget absorbs up to three kept states in one activation; a lane
#   whose resets keep the alignment is brought in step by clearing and setting
#   the enables before the second and later retries, stays in step through
#   later activations; a lane whose reset flips the alignment needs no re-arm.
#   A sampler that stays out of step, every re-arm the budget allows drawing
#   out of step, a dead link (centre counter full after every reset, lane
#   ready) and a full counter under ResetPolicy Never all scan to CLOSED with
#   a warning that names both causes (sampler out of step, link closed or
#   unlocked) in the message, the meta warnings and
#   ActivationResult.syncWarning, with every swept position measured and the
#   registers restored apart from the enables; the probe of such a lane is
#   CLOSED with the warning, eye, margin and point carry it, and an in-step
#   activation carries none. The criterion is a full error counter at the
#   centre (65534 errors in 65535 samples is in step, 65535 is not); a closed
#   eye whose samples still follow the data keeps its CLOSED result and one
#   reset. A re-arm that is aborted during the wait, or hits a failing DRP
#   write, leaves ES_EYE_SCAN_EN and ES_ERRDET_EN set.
# - Timing: countReads=1 and a zero settle keep the emulated runs short; the
#   model steps on status reads, so no test waits on real hardware time.

from types import SimpleNamespace

import pytest

pr = pytest.importorskip('pyrogue', reason='Eye-scan tests require Rogue/PyRogue')
rogue = pytest.importorskip('rogue', reason='Eye-scan tests require Rogue/PyRogue')

from surf.xilinx.eyescan import ResetPolicy, ScanControl, ScanStatus, loadResult  # noqa: E402
from surf.xilinx.eyescan._EyeScanPort import EyeScanPort  # noqa: E402
from surf.xilinx.eyescan._EyeScanEngine import SYNC_RESETS  # noqa: E402

from tests.xilinx.eyescan.gthe3_eye_model import ERROR_MAX, SAMPLE_MAX, makeGtRoot  # noqa: E402
from tests.xilinx.eyescan.gt_new_eye_model import makeGthe4Root, makeGtye3Root  # noqa: E402
from tests.xilinx.eyescan.gtye4_eye_model import makeGtyRoot  # noqa: E402
from tests.xilinx.eyescan.test_EyeScanBathtub import Hook, closed, gauss, seedWords  # noqa: E402

FLOOR = 1e-9
WINDOW = 0.3

# The two causes a full error counter at the eye centre can have
OUT_OF_STEP = 'out of step with the data sampler'
LINK_DOWN = 'link is closed or unlocked'

FAMS = {'GTHE3': makeGtRoot, 'GTYE4': makeGtyRoot, 'GTYE3': makeGtye3Root, 'GTHE4': makeGthe4Root}


@pytest.fixture(params=sorted(FAMS))
def rig(request):
    roots = []

    def make(**kw):
        kw.setdefault('requireReset', True)
        kw.setdefault('berFn', gauss)
        kw.setdefault('countReads', 1)
        root, gt, model = FAMS[request.param](**kw)
        roots.append(root)
        hook = Hook(model)
        gt.EyeScan.setRxReset(hook.pulse, hook.ready, settle=0.0, fallWait=0.05, timeout=0.5)
        return gt, model, hook

    yield make
    for root in roots:
        root.stop()


def test_an_out_of_step_activation_is_reset_again_and_the_bathtub_is_open(rig):
    gt, model, hook = rig(desyncResets={1})

    res = gt.EyeScan.runBathtub(step=8, floor=FLOOR, probeWindow=WINDOW)

    assert res.status is ScanStatus.OK, res.message
    assert res.openingAtFloorUI is not None and res.openingAtFloorUI > 0
    assert hook.pulses == 2 and model.resets == 2
    assert res.activation.resetCalled and res.activation.resets == 2
    assert 'after 2 RX resets' in res.activation.message
    centre = list(res.horzCounts).index(0)
    assert res.errors[:, centre].sum() < ERROR_MAX
    assert res.activation.sampleCount == SAMPLE_MAX


def test_alternating_resets_cost_one_extra_reset_per_bad_activation(rig):
    # Reset 1 in step, then every even reset out of step, as on the C1100 lanes
    gt, model, hook = rig(desyncResets={2, 4})

    seen = []
    for _ in range(3):
        res = gt.EyeScan.probe(resetPolicy=ResetPolicy.Always, probeWindow=WINDOW)
        assert res.status is ScanStatus.OK, res.message
        assert res.sampleCount == SAMPLE_MAX
        seen.append((res.resets, hook.pulses))

    assert seen == [(1, 1), (2, 3), (2, 5)]
    assert not model.desynced


def flipping(count, kept=(), desynced=False):
    """desyncResets of a sampler whose alignment every reset flips, except the resets in kept."""
    out = set()
    for n in range(1, count + 1):
        desynced ^= n not in kept
        if desynced:
            out.add(n)
    return out


def test_a_reset_that_keeps_the_alignment_still_ends_in_step(rig):
    # Ten activations on C1100 lane 4 after an out-of-step reset: every reset flipped the
    # alignment except the third, which kept the sampler out of step
    gt, model, hook = rig(desyncResets=flipping(20, kept={3}, desynced=True))

    seen = []
    for _ in range(10):
        res = gt.EyeScan.probe(resetPolicy=ResetPolicy.Auto, probeWindow=WINDOW)
        assert res.status is ScanStatus.OK, res.message
        assert res.sampleCount == SAMPLE_MAX and not model.desynced
        seen.append(res.resets)

    assert seen == [1, 3, 2, 2, 2, 2, 2, 2, 2, 2]
    assert hook.pulses == model.resets == 20


@pytest.mark.parametrize('keeps', [0, 1, 2, 3])
def test_the_budget_absorbs_up_to_three_resets_that_keep_the_alignment(rig, keeps):
    # From in step the first reset puts the sampler out of step and the next `keeps` resets keep it there
    gt, model, hook = rig(desyncResets=flipping(keeps + 2, kept=range(2, keeps + 2)))

    res = gt.EyeScan.probe(resetPolicy=ResetPolicy.Auto, probeWindow=WINDOW)

    assert res.status is ScanStatus.OK, res.message
    assert res.resets == hook.pulses == keeps + 2
    assert f'after {keeps + 2} RX resets' in res.message
    assert res.sampleCount == SAMPLE_MAX and not model.desynced


def test_resets_that_keep_the_alignment_past_the_budget_scans_to_closed_with_the_warning(rig):
    # Every reset of the budget leaves the sampler out of step; the next one would bring it back
    keeps = SYNC_RESETS - 1
    gt, model, hook = rig(desyncResets=flipping(keeps + 2, kept=range(2, keeps + 2)))
    assert SYNC_RESETS + 1 not in model.desyncResets
    before = seedWords(model, gt)

    res = gt.EyeScan.runBathtub(step=8, floor=FLOOR, probeWindow=WINDOW)

    assert res.status is ScanStatus.CLOSED, res.message
    assert 'out of step' in res.message and f'after each of {SYNC_RESETS} RX resets' in res.message
    assert OUT_OF_STEP in res.activation.syncWarning and LINK_DOWN in res.activation.syncWarning
    assert hook.pulses == model.resets == res.activation.resets == SYNC_RESETS
    assert len(res.horzCounts) > 0 and res.bits.sum() > 0
    assert res.activation.syncWarning in res.meta['warnings']
    assert model.getField(gt.ES_CONTROL) == 0
    assert seedWords(model, gt) == before


def test_a_lane_whose_resets_keep_the_alignment_is_rearmed_and_the_bathtub_is_open(rig):
    # C1100 lane 5: out of step at the enable, every reset keeps it, setting the enables again draws in step
    gt, model, hook = rig(resetMode='keep', enableDraws=[True, False])

    res = gt.EyeScan.runBathtub(step=8, floor=FLOOR, probeWindow=WINDOW)

    assert res.status is ScanStatus.OK, res.message
    assert res.openingAtFloorUI is not None and res.openingAtFloorUI > 0
    # The activation reset and the plain retry stay out of step; the re-armed retry is in step
    assert res.activation.resets == hook.pulses == model.resets == 3
    assert res.activation.rearms == 1 and model.enableSets == 2
    assert 'after 3 RX resets' in res.activation.message
    assert res.activation.sampleCount == SAMPLE_MAX and not model.desynced
    centre = list(res.horzCounts).index(0)
    assert res.errors[:, centre].sum() < ERROR_MAX


def test_a_stuck_lane_stays_in_step_through_later_activations(rig):
    # C1100 lane 5 after the fix: two re-arms draw out of step, the third in step; the enables then stay set
    gt, model, hook = rig(resetMode='keep', enableDraws=[True, True, False])

    seen = []
    for _ in range(3):
        res = gt.EyeScan.probe(resetPolicy=ResetPolicy.Auto, probeWindow=WINDOW)
        assert res.status is ScanStatus.OK, res.message
        assert res.sampleCount == SAMPLE_MAX and not model.desynced
        seen.append((res.resets, res.rearms))

    assert seen == [(4, 2), (1, 0), (1, 0)]
    assert model.enableSets == 3


@pytest.mark.parametrize('rearms', [1, 2, 10])
def test_the_budget_allows_every_rearm_but_the_first_retry(rig, rearms):
    # Out of step at the enable and at the first rearms - 1 re-arms; the last re-arm draws in step.
    # Ten re-arms keep the CLOSED with the warning of a lane whose resets keep the state near 2**-10 per activation
    gt, model, hook = rig(resetMode='keep', enableDraws=[True] * rearms + [False])

    res = gt.EyeScan.probe(resetPolicy=ResetPolicy.Auto, probeWindow=WINDOW)

    assert res.status is ScanStatus.OK, res.message
    assert (res.resets, res.rearms) == (rearms + 2, rearms)
    assert hook.pulses == model.resets == rearms + 2 and model.enableSets == rearms + 1
    assert res.sampleCount == SAMPLE_MAX and not model.desynced


def test_rearms_that_draw_out_of_step_past_the_budget_scans_to_closed_with_the_warning(rig):
    # Every re-arm the budget allows draws out of step; the next one would draw in step
    rearms = SYNC_RESETS - 2
    gt, model, hook = rig(resetMode='keep', enableDraws=[True] * (rearms + 1) + [False])
    before = seedWords(model, gt)

    res = gt.EyeScan.runBathtub(step=8, floor=FLOOR, probeWindow=WINDOW)

    assert res.status is ScanStatus.CLOSED, res.message
    assert 'out of step' in res.message and f'after each of {SYNC_RESETS} RX resets' in res.message
    assert f'cleared and set again before {rearms} of them' in res.message
    assert hook.pulses == model.resets == res.activation.resets == SYNC_RESETS
    assert res.activation.rearms == rearms and model.enableSets >= rearms + 1
    assert model.enableDraws == [False]
    assert len(res.horzCounts) > 0 and res.bits.sum() > 0
    assert res.activation.syncWarning in res.meta['warnings']
    assert model.getField(gt.ES_CONTROL) == 0
    assert seedWords(model, gt) == before


def test_a_lane_whose_reset_flips_the_alignment_needs_no_rearm(rig):
    # C1100 lanes 4 and 6: in step at the enable, the activation reset flips it out, the plain retry back in
    gt, model, hook = rig(resetMode='flip', enableDraws=[False, True, True])

    res = gt.EyeScan.probe(resetPolicy=ResetPolicy.Auto, probeWindow=WINDOW)

    assert res.status is ScanStatus.OK, res.message
    assert (res.resets, res.rearms) == (2, 0)
    assert hook.pulses == 2 and model.enableSets == 1
    assert 'after 2 RX resets' in res.message and 'enables' not in res.message


def test_a_sampler_that_stays_out_of_step_scans_to_closed_with_the_warning(rig):
    gt, model, hook = rig(desyncResets=range(1, 100))
    before = seedWords(model, gt)

    res = gt.EyeScan.runBathtub(step=8, floor=FLOOR, probeWindow=WINDOW)

    assert res.status is ScanStatus.CLOSED, res.message
    assert 'out of step' in res.message and f'{ERROR_MAX} errors' in res.message
    assert hook.pulses == SYNC_RESETS
    assert res.activation.resets == SYNC_RESETS
    # One probe per reset, then the scan points
    assert model.runs > SYNC_RESETS
    assert len(res.horzCounts) > 0
    assert res.activation.syncWarning in res.meta['warnings']
    assert model.getField(gt.ES_CONTROL) == 0
    assert seedWords(model, gt) == before


def test_never_does_not_reset_an_out_of_step_sampler_and_the_probe_is_closed_with_the_warning(rig):
    gt, model, hook = rig()
    model.setField(gt.ES_ERRDET_EN, 1)
    model.setField(gt.ES_EYE_SCAN_EN, 1)
    model.activate()
    model.desynced = True

    res = gt.EyeScan.probe(resetPolicy=ResetPolicy.Never, probeWindow=WINDOW)

    assert res.status is ScanStatus.CLOSED, res.message
    assert OUT_OF_STEP in res.message and LINK_DOWN in res.message and 'Never' in res.message
    assert hook.pulses == 0 and not res.resetCalled and res.resets == 0
    assert model.runs == 1
    assert model.getField(gt.ES_CONTROL) == 0


@pytest.mark.parametrize('errors, policy, status, pulses', [
    (ERROR_MAX - 1, ResetPolicy.Auto, ScanStatus.OK, 1),
    (ERROR_MAX, ResetPolicy.Auto, ScanStatus.CLOSED, SYNC_RESETS),
    (ERROR_MAX - 1, ResetPolicy.Never, ScanStatus.OK, 0),
    (ERROR_MAX, ResetPolicy.Never, ScanStatus.CLOSED, 0),
])
def test_the_criterion_is_a_full_error_counter_at_the_eye_centre(rig, errors, policy, status, pulses):
    gt, model, hook = rig(berFn=lambda horz, ut: 1e-3)
    if policy is ResetPolicy.Never:
        model.setField(gt.ES_ERRDET_EN, 1)
        model.setField(gt.ES_EYE_SCAN_EN, 1)
        model.activate()
    # Every run counts exactly `errors` in a full sample counter
    model.rng = SimpleNamespace(poisson=lambda lam: errors)

    res = gt.EyeScan.probe(resetPolicy=policy, probeWindow=WINDOW)

    assert res.status is status, res.message
    assert hook.pulses == pulses
    assert res.sampleCount == SAMPLE_MAX


def test_a_closed_eye_that_follows_the_data_keeps_its_closed_result(rig):
    gt, model, hook = rig(berFn=closed)

    res = gt.EyeScan.runBathtub(step=16, floor=FLOOR, probeWindow=WINDOW)

    assert res.status is ScanStatus.CLOSED
    assert hook.pulses == 1 and res.activation.resets == 1


def test_a_dead_link_scans_to_closed_with_the_warning_and_its_data(rig, tmp_path):
    # The centre counter fills after every reset and the lane stays ready: a closed or unlocked link
    gt, model, hook = rig(berFn=lambda horz, ut: 0.5)
    before = seedWords(model, gt)

    res = gt.EyeScan.runBathtub(step=16, floor=FLOOR, probeWindow=WINDOW)

    assert res.status is ScanStatus.CLOSED, res.message
    assert len(res.horzCounts) > 0 and res.bits.sum() > 0
    assert hook.pulses == res.activation.resets == SYNC_RESETS
    warning = res.activation.syncWarning
    assert OUT_OF_STEP in warning and LINK_DOWN in warning
    assert warning in res.message
    assert warning in res.meta['warnings']
    assert model.getField(gt.ES_CONTROL) == 0
    assert seedWords(model, gt) == before

    outcome = gt.EyeScan.save(res, str(tmp_path), png=False)
    assert outcome.errors == []
    _, meta = loadResult(outcome.npzPath)
    assert warning in meta['message']
    assert warning in meta['engine']['warnings']


def test_the_probe_of_an_exhausted_budget_is_closed_with_the_warning(rig):
    gt, model, hook = rig(berFn=lambda horz, ut: 0.5)

    res = gt.EyeScan.probe(resetPolicy=ResetPolicy.Auto, probeWindow=WINDOW)

    assert res.status is ScanStatus.CLOSED, res.message
    assert hook.pulses == SYNC_RESETS
    assert OUT_OF_STEP in res.message and LINK_DOWN in res.message
    assert model.getField(gt.ES_CONTROL) == 0


def test_an_in_step_activation_carries_no_sync_warning(rig):
    gt, model, hook = rig()

    res = gt.EyeScan.runBathtub(step=16, floor=FLOOR, probeWindow=WINDOW)

    assert res.status is ScanStatus.OK, res.message
    assert res.activation.syncWarning == ''
    assert not any(OUT_OF_STEP in w for w in res.meta['warnings'])
    assert OUT_OF_STEP not in res.message


def test_a_dead_link_eye_and_margin_are_closed_with_the_warning(rig):
    gt, model, hook = rig(berFn=lambda horz, ut: 0.5)

    eye = gt.EyeScan.runEye(horzStep=16, vertStep=32, probeWindow=WINDOW)

    assert eye.status is ScanStatus.CLOSED, eye.message
    assert eye.activation.syncWarning in eye.message
    assert eye.activation.syncWarning in eye.meta['warnings']
    assert OUT_OF_STEP in eye.message and LINK_DOWN in eye.message
    assert eye.bits.sum() > 0

    margin = gt.EyeScan.runMargin(horzStep=16, vertStep=16, horzRange=32, vertRange=48, probeWindow=WINDOW)

    assert margin.status is ScanStatus.CLOSED, margin.message
    assert margin.activation.syncWarning in margin.message
    assert margin.activation.syncWarning in margin.meta['warnings']
    assert margin.eye.bits.sum() > 0
    assert model.getField(gt.ES_CONTROL) == 0


def test_a_dead_link_point_carries_the_warning(rig):
    gt, model, hook = rig(berFn=lambda horz, ut: 0.5)

    res = gt.EyeScan._engine().point(0, probeWindow=WINDOW)

    assert OUT_OF_STEP in res.message and LINK_DOWN in res.message


def test_an_abort_during_the_rearm_wait_leaves_both_enables_set(rig):
    # Out of step at the enable and after the plain retry: the third reset is preceded by a re-arm
    gt, model, hook = rig(resetMode='keep', enableDraws=[True, True, True])
    # True once the re-arm has cleared the enables, which is while it waits
    control = ScanControl(isAborted=lambda: model.enableSets >= 1 and model.getField(gt.ES_EYE_SCAN_EN) == 0)

    res = gt.EyeScan.probe(resetPolicy=ResetPolicy.Auto, probeWindow=WINDOW, control=control)

    assert res.status is ScanStatus.ABORTED, res.message
    assert res.rearms == 1
    assert model.getField(gt.ES_EYE_SCAN_EN) == 1 and model.getField(gt.ES_ERRDET_EN) == 1


def test_a_failing_write_inside_the_rearm_leaves_both_enables_set(rig, monkeypatch):
    gt, model, hook = rig(resetMode='keep', enableDraws=[True, True, True])
    write = EyeScanPort.write

    def failing(self, role, value, verify=True):
        if role == 'errDetEn' and value == 0:
            raise RuntimeError('injected DRP failure')
        write(self, role, value, verify)

    monkeypatch.setattr(EyeScanPort, 'write', failing)

    res = gt.EyeScan.probe(resetPolicy=ResetPolicy.Auto, probeWindow=WINDOW)

    assert res.status is ScanStatus.ERROR, res.message
    assert 'RuntimeError' in res.message and 'injected DRP failure' in res.message
    assert res.rearms == 1
    assert model.getField(gt.ES_EYE_SCAN_EN) == 1 and model.getField(gt.ES_ERRDET_EN) == 1
