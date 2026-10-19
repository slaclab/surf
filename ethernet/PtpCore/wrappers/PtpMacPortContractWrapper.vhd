-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Flat timing-port record and lifecycle verification boundary
-------------------------------------------------------------------------------
-- The test drives complete record fields and independent packed values. This
-- wrapper only maps records and calls the production packing functions. The
-- lifecycle DUT is PtpMacPort with idle MAC inputs and explicit abort ack;
-- cocotb owns the controller sequence, generation oracle and all assertions.
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SLAC Firmware Standard Library', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;
use surf.EthMacPkg.all;
use surf.PtpPkg.all;

entity PtpMacPortContractWrapper is
   port (
      timestamp           : in slv(95 downto 0);
      ticks               : in slv(63 downto 0);
      tickPhase           : in slv(2 downto 0);
      generation          : in slv(31 downto 0);
      increment           : in slv(63 downto 0);
      timeValid           : in sl;
      error               : in sl;
      frameLength         : in slv(15 downto 0);
      transportGeneration : in slv(15 downto 0);
      cookie              : in slv(31 downto 0);
      outcome             : in slv(1 downto 0);
      captureValid        : in sl;
      captureBits         : in slv(260 downto 0);
      capturePacked       : out slv(260 downto 0);
      captureDecoded      : out slv(260 downto 0);
      captureInit         : out slv(260 downto 0);
      metaBits            : in slv(292 downto 0);
      metaPacked          : out slv(292 downto 0);
      metaDecoded         : out slv(292 downto 0);
      metaInit            : out slv(292 downto 0);
      completionBits      : in slv(311 downto 0);
      completionPacked    : out slv(311 downto 0);
      completionDecoded   : out slv(311 downto 0);
      completionInit      : out slv(311 downto 0);
      clk                 : in sl;
      rst                 : in sl;
      openAdmission       : in sl;
      drainRequest        : in sl;
      abortRequest        : in sl;
      cancelAck           : in sl;
      macAck              : in sl;
      ethClkEn            : in sl;
      txValid             : in sl;
      txGeneration        : in slv(15 downto 0);
      lifecycleGeneration : out slv(15 downto 0);
      faults              : out slv(2 downto 0);
      nextToken           : out slv(7 downto 0);
      normalStreamBits    : out slv(15 downto 0);
      timingStreamBits    : out slv(15 downto 0);
      admissionOpen       : out sl;
      drainIdle           : out sl;
      cancelRequest       : out sl;
      abortDone           : out sl;
      macRequest          : out sl;
      txReady             : out sl);
end entity PtpMacPortContractWrapper;

architecture mapping of PtpMacPortContractWrapper is

   signal captureIn     : PtpRxCaptureType;
   signal captureOut    : PtpRxCaptureType;
   signal metaIn        : PtpMacPortRxMetaType;
   signal metaOut       : PtpMacPortRxMetaType;
   signal completionIn  : PtpMacPortTxCompletionType;
   signal completionOut : PtpMacPortTxCompletionType;
   signal control       : PtpMacPortControlType;
   signal status        : PtpMacPortStatusType;
   signal abortReq      : EthMacAbortRequestType;
   signal abortAck      : EthMacAbortAckType;
   signal txMaster      : PtpMacPortTxMasterType := PTP_MAC_PORT_TX_MASTER_INIT_C;
   signal txSlave       : AxiStreamSlaveType;

begin

   captureIn.timestamp <= timestamp;
   captureIn.ticks <= ticks;
   captureIn.tickPhase <= tickPhase;
   captureIn.generation <= generation;
   captureIn.increment <= increment;
   captureIn.timeValid <= timeValid;
   captureIn.error <= error;
   metaIn.capture <= captureIn;
   metaIn.frameLength <= frameLength;
   metaIn.transportGeneration <= transportGeneration;
   completionIn.capture <= captureIn;
   completionIn.cookie <= cookie;
   completionIn.outcome <= outcome;
   completionIn.captureValid <= captureValid;
   completionIn.transportGeneration <= transportGeneration;

   capturePacked <= toSlv(captureIn);
   metaPacked <= toSlv(metaIn);
   completionPacked <= toSlv(completionIn);
   captureOut <= toPtpRxCapture(captureBits);
   metaOut <= toPtpMacPortRxMeta(metaBits);
   completionOut <= toPtpMacPortTxCompletion(completionBits);
   captureDecoded <= captureOut.timestamp &
      captureOut.ticks &
      captureOut.tickPhase &
      captureOut.generation &
      captureOut.increment &
      captureOut.timeValid &
      captureOut.error;
   metaDecoded <= metaOut.capture.timestamp &
      metaOut.capture.ticks &
      metaOut.capture.tickPhase &
      metaOut.capture.generation &
      metaOut.capture.increment &
      metaOut.capture.timeValid &
      metaOut.capture.error &
      metaOut.frameLength & metaOut.transportGeneration;
   completionDecoded <= completionOut.cookie & completionOut.outcome & completionOut.captureValid &
      completionOut.capture.timestamp &
      completionOut.capture.ticks &
      completionOut.capture.tickPhase &
      completionOut.capture.generation &
      completionOut.capture.increment &
      completionOut.capture.timeValid &
      completionOut.capture.error & completionOut.transportGeneration;
   captureInit <= toSlv(PTP_RX_CAPTURE_INIT_C);
   metaInit <= toSlv(PTP_MAC_PORT_RX_META_INIT_C);
   completionInit <= toSlv(PTP_MAC_PORT_TX_COMPLETION_INIT_C);
   normalStreamBits <= toSlv(getSlvSize(INT_EMAC_AXIS_CONFIG_C), 16);
   timingStreamBits <= toSlv(getSlvSize(EMAC_TIMING_AXIS_CONFIG_C), 16);

   control.openAdmission <= openAdmission;
   control.drainRequest <= drainRequest;
   control.abortRequest <= abortRequest;
   control.cancelAck <= cancelAck;
   abortAck.acknowledge <= macAck;
   macRequest <= abortReq.request;
   lifecycleGeneration <= status.transportGeneration;
   admissionOpen <= status.admissionOpen;
   drainIdle <= status.drainIdle;
   cancelRequest <= status.cancelRequest;
   abortDone <= status.abortDone;
   faults <= status.faultTokenProtocol & status.faultClockEnable & status.faultGeneration;
   txReady <= txSlave.tReady;
   txMaster.frame.tValid <= txValid;
   txMaster.frame.tKeep(15 downto 0) <= (others => '1');
   txMaster.frame.tLast <= '1';
   txMaster.frame.tUser(SSI_SOF_C) <= '1';
   txMaster.request.frameLength <= x"0010";
   txMaster.request.transportGeneration <= txGeneration;

   U_Port : entity surf.PtpMacPort
      generic map (
         -- This idle-MAC contract bench checks clocked lifecycle behavior.
         -- Avoid scheduling wide inactive AXI records after every clock edge.
         TPD_G            => 0 ns,
         TX_TABLE_DEPTH_G => 1,
         RX_TABLE_DEPTH_G => 1)
      port map (
         clk              => clk,
         rst              => rst,
         ethClkEn         => ethClkEn,
         phcTime          => PTP_TIME_INIT_C,
         phcStatus        => PTP_PHC_STATUS_INIT_C,
         control          => control,
         status           => status,
         counters         => open,
         txMaster         => txMaster,
         txSlave          => txSlave,
         completionMaster => open,
         completionReady  => '1',
         rxMaster         => open,
         rxReady          => '1',
         macTxMaster      => open,
         macTxSlave       => AXI_STREAM_SLAVE_FORCE_C,
         macRxMaster      => AXI_STREAM_MASTER_INIT_C,
         macRxSlave       => open,
         rxNextToken      => nextToken,
         rxFrameEvent     => ETH_MAC_FRAME_EVENT_INIT_C,
         rxRetire         => (others => ETH_MAC_TOKEN_RETIRE_INIT_C),
         txFrameEvent     => ETH_MAC_FRAME_EVENT_INIT_C,
         txRetire         => (others => ETH_MAC_TOKEN_RETIRE_INIT_C),
         macAbortReq      => abortReq,
         macAbortAck      => abortAck);

end architecture mapping;
