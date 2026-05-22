-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for RSSI monitor tests
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
use surf.RssiPkg.all;

entity RssiMonitorWrapper is
   generic (
      TPD_G               : time     := 1 ns;
      TIMEOUT_UNIT_G      : real     := 1.0;
      CLK_FREQUENCY_G     : real     := 1.0;
      SERVER_G            : boolean  := true;
      WINDOW_ADDR_SIZE_G  : positive := 3;
      STATUS_WIDTH_G      : positive := 8;
      CNT_WIDTH_G         : positive := 16;
      RETRANSMIT_ENABLE_G : boolean  := true
   );
   port (
      axisClk : in sl;
      axisRst : in sl;

      connActive_i : in sl;
      localBusy_i  : in sl;

      paramVersion_i      : in slv(3 downto 0);
      paramChksumEn_i     : in slv(0 downto 0);
      paramTimeoutUnit_i  : in slv(7 downto 0);
      paramMaxOutsSeg_i   : in slv(7 downto 0);
      paramMaxSegSize_i   : in slv(15 downto 0);
      paramRetransTout_i  : in slv(15 downto 0);
      paramCumulAckTout_i : in slv(15 downto 0);
      paramNullSegTout_i  : in slv(15 downto 0);
      paramMaxRetrans_i   : in slv(7 downto 0);
      paramMaxCumAck_i    : in slv(7 downto 0);
      paramMaxOutofseq_i  : in slv(7 downto 0);
      paramConnectionId_i : in slv(31 downto 0);

      rxFlagsSyn_i  : in sl;
      rxFlagsAck_i  : in sl;
      rxFlagsEack_i : in sl;
      rxFlagsRst_i  : in sl;
      rxFlagsNul_i  : in sl;
      rxFlagsData_i : in sl;
      rxFlagsBusy_i : in sl;
      rxFlagsEofe_i : in sl;

      rxLastSeqN_i    : in slv(7 downto 0);
      rxWindowSize_i  : in integer range 1 to 2 ** (WINDOW_ADDR_SIZE_G);
      txBufferEmpty_i : in sl;
      rxValid_i       : in sl;
      rxDrop_i        : in sl;

      ackHeadSt_i  : in sl;
      rstHeadSt_i  : in sl;
      dataHeadSt_i : in sl;
      nullHeadSt_i : in sl;

      lenErr_i       : in sl;
      ackErr_i       : in sl;
      peerConnTout_i : in sl;
      paramReject_i  : in sl;

      sndResend_o : out sl;
      sndNull_o   : out sl;
      sndAck_o    : out sl;
      closeRq_o   : out sl;

      statusReg_o : out slv(STATUS_WIDTH_G downto 0);
      dropCnt_o   : out slv(CNT_WIDTH_G-1 downto 0);
      validCnt_o  : out slv(CNT_WIDTH_G-1 downto 0);
      resendCnt_o : out slv(CNT_WIDTH_G-1 downto 0);
      reconCnt_o  : out slv(CNT_WIDTH_G-1 downto 0)
   );
end entity RssiMonitorWrapper;

architecture mapping of RssiMonitorWrapper is

   signal rssiParam : RssiParamType := RSSI_PARAM_INIT_C;
   signal rxFlags   : FlagsType;

begin

   -- Flattened RSSI parameter record.
   rssiParam.version      <= paramVersion_i;
   rssiParam.chksumEn     <= paramChksumEn_i;
   rssiParam.timeoutUnit  <= paramTimeoutUnit_i;
   rssiParam.maxOutsSeg   <= paramMaxOutsSeg_i;
   rssiParam.maxSegSize   <= paramMaxSegSize_i;
   rssiParam.retransTout  <= paramRetransTout_i;
   rssiParam.cumulAckTout <= paramCumulAckTout_i;
   rssiParam.nullSegTout  <= paramNullSegTout_i;
   rssiParam.maxRetrans   <= paramMaxRetrans_i;
   rssiParam.maxCumAck    <= paramMaxCumAck_i;
   rssiParam.maxOutofseq  <= paramMaxOutofseq_i;
   rssiParam.connectionId <= paramConnectionId_i;

   -- Flattened received-header flags.
   rxFlags.syn  <= rxFlagsSyn_i;
   rxFlags.ack  <= rxFlagsAck_i;
   rxFlags.eack <= rxFlagsEack_i;
   rxFlags.rst  <= rxFlagsRst_i;
   rxFlags.nul  <= rxFlagsNul_i;
   rxFlags.data <= rxFlagsData_i;
   rxFlags.busy <= rxFlagsBusy_i;
   rxFlags.eofe <= rxFlagsEofe_i;

   U_DUT : entity surf.RssiMonitor
      generic map (
         TPD_G               => TPD_G,
         TIMEOUT_UNIT_G      => TIMEOUT_UNIT_G,
         CLK_FREQUENCY_G     => CLK_FREQUENCY_G,
         SERVER_G            => SERVER_G,
         WINDOW_ADDR_SIZE_G  => WINDOW_ADDR_SIZE_G,
         STATUS_WIDTH_G      => STATUS_WIDTH_G,
         CNT_WIDTH_G         => CNT_WIDTH_G,
         RETRANSMIT_ENABLE_G => RETRANSMIT_ENABLE_G)
      port map (
         clk_i          => axisClk,        -- [in]
         rst_i          => axisRst,        -- [in]
         connActive_i   => connActive_i,   -- [in]
         localBusy_i    => localBusy_i,    -- [in]
         rssiParam_i    => rssiParam,      -- [in]
         rxFlags_i      => rxFlags,        -- [in]
         rxLastSeqN_i   => rxLastSeqN_i,   -- [in]
         rxWindowSize_i => rxWindowSize_i, -- [in]
         txBufferEmpty_i => txBufferEmpty_i, -- [in]
         rxValid_i      => rxValid_i,      -- [in]
         rxDrop_i       => rxDrop_i,       -- [in]
         ackHeadSt_i    => ackHeadSt_i,    -- [in]
         rstHeadSt_i    => rstHeadSt_i,    -- [in]
         dataHeadSt_i   => dataHeadSt_i,   -- [in]
         nullHeadSt_i   => nullHeadSt_i,   -- [in]
         lenErr_i       => lenErr_i,       -- [in]
         ackErr_i       => ackErr_i,       -- [in]
         peerConnTout_i => peerConnTout_i, -- [in]
         paramReject_i  => paramReject_i,  -- [in]
         sndResend_o    => sndResend_o,    -- [out]
         sndNull_o      => sndNull_o,      -- [out]
         sndAck_o       => sndAck_o,       -- [out]
         closeRq_o      => closeRq_o,      -- [out]
         statusReg_o    => statusReg_o,    -- [out]
         dropCnt_o      => dropCnt_o,      -- [out]
         validCnt_o     => validCnt_o,     -- [out]
         resendCnt_o    => resendCnt_o,    -- [out]
         reconCnt_o     => reconCnt_o);    -- [out]

end architecture mapping;
