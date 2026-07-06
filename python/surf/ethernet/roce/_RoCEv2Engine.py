#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import random
import time

import rogue

import pyrogue as pr

import surf.ethernet.roce as roce

class RoCEv2Engine(pr.Device):
    def __init__( self, **kwargs):
        super().__init__(**kwargs)

        # FPGA QP shadow state — plain private attrs, NOT pyrogue tree
        # variables (no GUI noise). Set in setupConnection() once the FPGA
        # resources go live, consumed/reset by teardownConnection().
        self._fpgaQpn   = 0
        self._pdHandler = 0
        self._lkey      = 0
        self._rkey      = 0

        self.add(pr.RemoteVariable(
            name        = 'SendMetaData',
            description = 'Trigger sending RoCE metadata to the remote peer',
            offset      = 0xF00,
            bitSize     = 1,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MetaDataTx',
            description = 'RoCE transmit metadata payload for queue pair setup',
            offset      = 0xF04,
            bitSize     = 303,
            mode        = 'RW',
        ))


        self.add(pr.RemoteVariable(
            name        = 'RecvMetaData',
            description = 'Indicates received RoCE metadata is available',
            offset      = 0xF00,
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MetaDataRx',
            description = 'RoCE received metadata payload from remote peer',
            offset      = 0xF2C,
            bitSize     = 276,
            mode        = 'RO',
        ))

        self.add(pr.RemoteCommand(
            name        = 'SoftReset',
            description = 'Soft-reset the RoCE transport core to clear stale QP/PSN '
                          'state from a prior session (without disturbing the '
                          'RUDP/UDP link). Pulse before re-establishing a QP.',
            offset      = 0xF50,
            bitSize     = 1,
            bitOffset   = 0,
            function    = pr.RemoteCommand.toggle,
        ))

    def setupConnection(self, *, hostQpn, hostRqPsn, hostSqPsn, mrAddr, mrLen,
                        pmtu, minRnrTimer=1, rnrRetry=7, retryCount=3):
        """Drive the FPGA RoCEv2 engine through PD alloc → MR alloc → QP create
        → INIT → RTR → RTS via the metadata bus.

        Pulses SoftReset first to clear stale QP/PSN state left by a prior
        session. Any failure in stages 2-6 triggers a reverse-order rollback of
        every resource allocated so far (so the FPGA is never left with a
        stranded PD / MR / QP), then re-raises. On success, stores the live
        FPGA params as shadow state and returns a roce.RoCEv2FpgaParams.
        """
        log = self._log

        # Up-front input validation (before SoftReset / any bus traffic) so an
        # invalid call fails cleanly with nothing allocated. _mkBus silently
        # masks every field with & ((1<<width)-1), so out-of-range values would
        # otherwise be truncated onto the FROZEN metadata bus — e.g. a too-large
        # mrLen programs a smaller MR into the FPGA than the host believes it
        # registered, letting the FPGA bounds check pass for offsets the host MR
        # cannot cover (RDMA-WRITE out-of-bounds / data corruption).
        if not (0 <= mrLen < (1 << roce.RoCEv2FieldW.MR_LEN)):
            raise rogue.GeneralError(
                "setupConnection",
                f"mrLen {mrLen} exceeds the {roce.RoCEv2FieldW.MR_LEN}-bit MR_LEN "
                f"metadata-bus field")
        for name, val, width in (("hostQpn",   hostQpn,   roce.RoCEv2FieldW.QPA_DQPN),
                                 ("hostRqPsn", hostRqPsn, roce.RoCEv2FieldW.QPA_RQPSN),
                                 ("hostSqPsn", hostSqPsn, roce.RoCEv2FieldW.QPA_SQPSN)):
            if not (0 <= val < (1 << width)):
                raise rogue.GeneralError(
                    "setupConnection",
                    f"{name}={val} does not fit in its {width}-bit bus field")
        # pmtu is masked to 3 bits on the bus, but the success-summary log below
        # does roce._RoCEv2Protocol._PMTU_BYTES[pmtu] — a dict lookup with no fallback. Reject
        # an invalid pmtu here rather than letting it KeyError AFTER the QP is
        # live and shadow state is written (stranded QP, no clean error path).
        if pmtu not in roce._RoCEv2Protocol._PMTU_BYTES:
            raise rogue.GeneralError(
                "setupConnection",
                f"pmtu must be a valid RoCEv2Mtu code (one of "
                f"{sorted(int(k) for k in roce._RoCEv2Protocol._PMTU_BYTES)}); got {pmtu}")

        def _rollbackStep(busValue, waitTimeout):
            # Best-effort teardown step: swallow any response failure so a
            # rollback error never masks the original exception.
            try:
                roce._RoCEv2Protocol._sendMeta(self, busValue)
            except Exception as e:
                log.warning(f"RoCEv2Engine: rollback _sendMeta failed: {e}")
                return
            try:
                roce._RoCEv2Protocol._waitResp(self, timeout_s=waitTimeout)
            except Exception:
                pass

        # Clear any stale RoCE transport state (QP / PSN tables) left behind by
        # a prior session. Without this, a software reconnect reuses a stale
        # FPGA transmit PSN and the host NIC silently drops every RDMA WRITE as
        # out-of-sequence. Best-effort: older firmware lacks the register.
        try:
            self.SoftReset()
            time.sleep(0.05)
        except AttributeError:
            log.warning("RoCEv2Engine has no SoftReset register — a software "
                        "reconnect may require an FPGA reload to clear stale "
                        "QP/PSN state")

        # Ensure SendMetaData starts at 0 for a clean first rising edge.
        self.SendMetaData.set(0)
        time.sleep(0.1)

        # 1. Alloc PD — nothing to roll back if this stage itself fails.
        roce._RoCEv2Protocol._sendMeta(self, roce._RoCEv2Protocol._encodeAllocPd(random.getrandbits(roce.RoCEv2FieldW.PD_KEY)))
        rx = roce._RoCEv2Protocol._waitResp(self)
        actualType = roce._RoCEv2Protocol._decodeRespType(rx)
        if actualType != roce.RoCEv2BusType.PD:
            raise rogue.GeneralError(
                "setupConnection",
                f"Expected PD response (type=0), got type={actualType}")
        ok, pdHandler = roce._RoCEv2Protocol._decodePdResp(rx)
        if not ok:
            raise roce._RoCEv2Protocol._staleResourceErr("PD allocation")
        log.info(f"RoCEv2Engine: PD allocated handler=0x{pdHandler:08x}")

        # Past stage 1, every subsequent failure must release the PD (and any
        # MR / QP allocated since) before re-raising.
        lkey = 0
        rkey = 0
        fpgaQpn = 0
        mrAllocated = False
        qpCreated = False

        try:
            # 2. Alloc MR
            roce._RoCEv2Protocol._sendMeta(self, roce._RoCEv2Protocol._encodeAllocMr(
                pdHandler = pdHandler,
                laddr     = mrAddr,
                length    = mrLen,
                lkeyPart  = random.getrandbits(roce.RoCEv2FieldW.MR_LKEYPART),
                rkeyPart  = random.getrandbits(roce.RoCEv2FieldW.MR_RKEYPART),
            ))
            rx = roce._RoCEv2Protocol._waitResp(self)
            actualType = roce._RoCEv2Protocol._decodeRespType(rx)
            if actualType != roce.RoCEv2BusType.MR:
                raise rogue.GeneralError(
                    "setupConnection",
                    f"Expected MR response (type=1), got type={actualType}")
            ok, lkey, rkey = roce._RoCEv2Protocol._decodeMrResp(rx)
            if not ok:
                raise roce._RoCEv2Protocol._staleResourceErr("MR allocation")
            mrAllocated = True
            log.info(f"RoCEv2Engine: MR allocated lkey=0x{lkey:08x} rkey=0x{rkey:08x}")

            # 3. Create QP (RC)
            roce._RoCEv2Protocol._sendMeta(self, roce._RoCEv2Protocol._encodeCreateQp(pdHandler))
            rx = roce._RoCEv2Protocol._waitResp(self)
            actualType = roce._RoCEv2Protocol._decodeRespType(rx)
            if actualType != roce.RoCEv2BusType.QP:
                raise rogue.GeneralError(
                    "setupConnection",
                    f"Expected QP response (type=2), got type={actualType}")
            ok, fpgaQpn, _ = roce._RoCEv2Protocol._decodeQpResp(rx)
            if not ok:
                raise roce._RoCEv2Protocol._staleResourceErr("QP creation")
            qpCreated = True
            log.info(f"RoCEv2Engine: QP created fpgaQpn=0x{fpgaQpn:06x}")

            # 4. QP → INIT
            initMask = roce.RoCEv2QpAttrMask.STATE | roce.RoCEv2QpAttrMask.PKEY_INDEX | roce.RoCEv2QpAttrMask.ACCESS_FLAGS
            roce._RoCEv2Protocol._sendMeta(self, roce._RoCEv2Protocol._encodeModifyQp(fpgaQpn, initMask, roce.RoCEv2QpState.INIT, pmtu))
            rx = roce._RoCEv2Protocol._waitResp(self)
            ok, _, state = roce._RoCEv2Protocol._decodeQpResp(rx)
            if not (ok and state == roce.RoCEv2QpState.INIT):
                raise rogue.GeneralError(
                    "setupConnection",
                    f"FPGA QP→INIT failed (ok={ok} state={state})")
            log.info("RoCEv2Engine: QP → INIT")

            # 5. QP → RTR
            rtrMask = (roce.RoCEv2QpAttrMask.STATE | roce.RoCEv2QpAttrMask.PATH_MTU | roce.RoCEv2QpAttrMask.DEST_QPN |
                       roce.RoCEv2QpAttrMask.RQ_PSN | roce.RoCEv2QpAttrMask.MAX_DEST_RD_ATOMIC | roce.RoCEv2QpAttrMask.MIN_RNR_TIMER)
            roce._RoCEv2Protocol._sendMeta(self, roce._RoCEv2Protocol._encodeModifyQp(
                fpgaQpn, rtrMask, roce.RoCEv2QpState.RTR, pmtu,
                dqpn=hostQpn, rqPsn=hostRqPsn,
                minRnrTimer=minRnrTimer))
            rx = roce._RoCEv2Protocol._waitResp(self)
            ok, _, state = roce._RoCEv2Protocol._decodeQpResp(rx)
            if not (ok and state == roce.RoCEv2QpState.RTR):
                raise rogue.GeneralError(
                    "setupConnection",
                    f"FPGA QP→RTR failed (ok={ok} state={state})")
            log.info(f"RoCEv2Engine: QP → RTR targeting host qpn=0x{hostQpn:06x}")

            # 6. QP → RTS
            rtsMask = (roce.RoCEv2QpAttrMask.STATE | roce.RoCEv2QpAttrMask.SQ_PSN | roce.RoCEv2QpAttrMask.TIMEOUT |
                       roce.RoCEv2QpAttrMask.RETRY_CNT | roce.RoCEv2QpAttrMask.RNR_RETRY | roce.RoCEv2QpAttrMask.MAX_QP_RD_ATOMIC)
            roce._RoCEv2Protocol._sendMeta(self, roce._RoCEv2Protocol._encodeModifyQp(
                fpgaQpn, rtsMask, roce.RoCEv2QpState.RTS, pmtu,
                sqPsn=hostSqPsn, minRnrTimer=minRnrTimer,
                rnrRetry=rnrRetry, retryCount=retryCount))
            rx = roce._RoCEv2Protocol._waitResp(self)
            ok, _, state = roce._RoCEv2Protocol._decodeQpResp(rx)
            if not (ok and state == roce.RoCEv2QpState.RTS):
                raise rogue.GeneralError(
                    "setupConnection",
                    f"FPGA QP→RTS failed (ok={ok} state={state})")
            log.info("RoCEv2Engine: QP → RTS — FPGA ready to send RDMA WRITEs")

        except Exception:
            # Reverse-order rollback of everything allocated so far, skipping
            # stages whose resources were never allocated so the rollback's
            # TX-write count matches the allocation count exactly.
            log.warning("RoCEv2Engine: rolling back partial setup")
            if qpCreated:
                _rollbackStep(roce._RoCEv2Protocol._encodeErrQp(fpgaQpn),     3.0)
                _rollbackStep(roce._RoCEv2Protocol._encodeDestroyQp(fpgaQpn), 5.0)
            if mrAllocated:
                _rollbackStep(roce._RoCEv2Protocol._encodeDeallocMr(pdHandler, lkey, rkey), 3.0)
            _rollbackStep(roce._RoCEv2Protocol._encodeDeallocPd(pdHandler), 3.0)
            raise

        # Resources are live — capture shadow state before returning so
        # teardownConnection() can reach them even if a later caller raises.
        self._fpgaQpn   = fpgaQpn
        self._pdHandler = pdHandler
        self._lkey      = lkey
        self._rkey      = rkey

        log.info("=" * 60)
        log.info("RoCEv2 FPGA connection summary")
        log.info(f"  FPGA QPN    : 0x{fpgaQpn:06x}")
        log.info(f"  FPGA lkey   : 0x{lkey:08x}")
        log.info("  FPGA state  : RTS (ready to send RDMA WRITEs)")
        log.info(f"  Host QPN    : 0x{hostQpn:06x}")
        log.info(f"  Host RQ PSN : 0x{hostRqPsn:06x}")
        log.info(f"  Host SQ PSN : 0x{hostSqPsn:06x}")
        log.info(f"  MR addr     : 0x{mrAddr:016x}")
        log.info(f"  MR length   : {mrLen} bytes")
        log.info(f"  Path MTU    : {pmtu} ({roce._RoCEv2Protocol._PMTU_BYTES[pmtu]} bytes)")
        log.info("=" * 60)

        return roce.RoCEv2FpgaParams(fpgaQpn=fpgaQpn, lkey=lkey, pdHandler=pdHandler, rkey=rkey)

    def teardownConnection(self):
        """Tear down the FPGA QP from stored shadow state: QP ERR → DESTROY →
        MR dealloc → PD dealloc. Safe no-op when no QP is live.

        Sends each request unconditionally — the firmware rejects them with
        successOrNot=False if resources are already freed, which is ignored.
        All per-step errors are caught and logged as warnings (best-effort).
        """
        log = self._log
        fpgaQpn = self._fpgaQpn
        if fpgaQpn == 0:
            return   # safe no-op when no QP is live

        pdHandler = self._pdHandler
        lkey = self._lkey
        rkey = self._rkey

        try:
            log.info(f"RoCEv2Engine: tearing down FPGA QP 0x{fpgaQpn:06x}")
            self.SendMetaData.set(0)
            time.sleep(0.1)

            # Step 1: QP → ERR
            log.info(f"RoCEv2Engine: teardown — sending ERR for QP 0x{fpgaQpn:06x}")
            roce._RoCEv2Protocol._sendMeta(self, roce._RoCEv2Protocol._encodeErrQp(fpgaQpn))
            try:
                rx = roce._RoCEv2Protocol._waitResp(self, timeout_s=3.0)
                ok, _, state = roce._RoCEv2Protocol._decodeQpResp(rx)
                log.info(f"RoCEv2Engine: ERR response ok={ok} state={state}")
            except Exception:
                log.warning("RoCEv2Engine: ERR timed out — proceeding anyway")

            # Step 2: QP DESTROY
            log.info(f"RoCEv2Engine: teardown — sending DESTROY for QP 0x{fpgaQpn:06x}")
            roce._RoCEv2Protocol._sendMeta(self, roce._RoCEv2Protocol._encodeDestroyQp(fpgaQpn))
            try:
                rx = roce._RoCEv2Protocol._waitResp(self, timeout_s=5.0)
                ok, _, _ = roce._RoCEv2Protocol._decodeQpResp(rx)
                log.info(f"RoCEv2Engine: DESTROY response ok={ok}")
            except Exception:
                log.warning("RoCEv2Engine: DESTROY timed out — proceeding anyway")

            # Step 3 + 4: MR dealloc then PD dealloc (only if we have the keys).
            if pdHandler != 0:
                log.info(f"RoCEv2Engine: teardown — dealloc MR lkey=0x{lkey:08x}")
                roce._RoCEv2Protocol._sendMeta(self, roce._RoCEv2Protocol._encodeDeallocMr(pdHandler, lkey, rkey))
                try:
                    rx = roce._RoCEv2Protocol._waitResp(self, timeout_s=3.0)
                    ok, _, _ = roce._RoCEv2Protocol._decodeMrResp(rx)
                    log.info(f"RoCEv2Engine: MR dealloc response ok={ok}")
                except Exception:
                    log.warning("RoCEv2Engine: MR dealloc timed out — proceeding anyway")

                log.info(f"RoCEv2Engine: teardown — dealloc PD handler=0x{pdHandler:08x}")
                roce._RoCEv2Protocol._sendMeta(self, roce._RoCEv2Protocol._encodeDeallocPd(pdHandler))
                try:
                    rx = roce._RoCEv2Protocol._waitResp(self, timeout_s=3.0)
                    ok, _ = roce._RoCEv2Protocol._decodePdResp(rx)
                    log.info(f"RoCEv2Engine: PD dealloc response ok={ok}")
                except Exception:
                    log.warning("RoCEv2Engine: PD dealloc timed out — proceeding anyway")

            time.sleep(0.1)

            self._fpgaQpn   = 0
            self._pdHandler = 0
            self._lkey      = 0
            self._rkey      = 0
        except Exception as e:
            log.warning(f"RoCEv2 teardown failed: {e}")
