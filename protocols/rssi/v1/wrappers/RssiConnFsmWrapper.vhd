-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for RSSI connection FSM tests
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

entity RssiConnFsmWrapper is
   generic (
      TPD_G               : time     := 1 ns;
      SERVER_G            : boolean  := true;
      TIMEOUT_UNIT_G      : real     := 1.0;
      CLK_FREQUENCY_G     : real     := 1.0;
      RETRANS_TOUT_G      : positive := 4;
      MAX_RETRANS_CNT_G   : positive := 1;
      WINDOW_ADDR_SIZE_G  : positive := 3;
      SEGMENT_ADDR_SIZE_G : positive := 7
   );
   port (
      axisClk : in sl;
      axisRst : in sl;

      connRq_i  : in sl;
      closeRq_i : in sl;

      rxParamVersion_i      : in slv(3 downto 0);
      rxParamChksumEn_i     : in slv(0 downto 0);
      rxParamTimeoutUnit_i  : in slv(7 downto 0);
      rxParamMaxOutsSeg_i   : in slv(7 downto 0);
      rxParamMaxSegSize_i   : in slv(15 downto 0);
      rxParamRetransTout_i  : in slv(15 downto 0);
      rxParamCumulAckTout_i : in slv(15 downto 0);
      rxParamNullSegTout_i  : in slv(15 downto 0);
      rxParamMaxRetrans_i   : in slv(7 downto 0);
      rxParamMaxCumAck_i    : in slv(7 downto 0);
      rxParamMaxOutofseq_i  : in slv(7 downto 0);
      rxParamConnectionId_i : in slv(31 downto 0);

      appParamVersion_i      : in slv(3 downto 0);
      appParamChksumEn_i     : in slv(0 downto 0);
      appParamTimeoutUnit_i  : in slv(7 downto 0);
      appParamMaxOutsSeg_i   : in slv(7 downto 0);
      appParamMaxSegSize_i   : in slv(15 downto 0);
      appParamRetransTout_i  : in slv(15 downto 0);
      appParamCumulAckTout_i : in slv(15 downto 0);
      appParamNullSegTout_i  : in slv(15 downto 0);
      appParamMaxRetrans_i   : in slv(7 downto 0);
      appParamMaxCumAck_i    : in slv(7 downto 0);
      appParamMaxOutofseq_i  : in slv(7 downto 0);
      appParamConnectionId_i : in slv(31 downto 0);

      paramVersion_o      : out slv(3 downto 0);
      paramChksumEn_o     : out slv(0 downto 0);
      paramTimeoutUnit_o  : out slv(7 downto 0);
      paramMaxOutsSeg_o   : out slv(7 downto 0);
      paramMaxSegSize_o   : out slv(15 downto 0);
      paramRetransTout_o  : out slv(15 downto 0);
      paramCumulAckTout_o : out slv(15 downto 0);
      paramNullSegTout_o  : out slv(15 downto 0);
      paramMaxRetrans_o   : out slv(7 downto 0);
      paramMaxCumAck_o    : out slv(7 downto 0);
      paramMaxOutofseq_o  : out slv(7 downto 0);
      paramConnectionId_o : out slv(31 downto 0);

      rxFlagsSyn_i  : in sl;
      rxFlagsAck_i  : in sl;
      rxFlagsEack_i : in sl;
      rxFlagsRst_i  : in sl;
      rxFlagsNul_i  : in sl;
      rxFlagsData_i : in sl;
      rxFlagsBusy_i : in sl;
      rxFlagsEofe_i : in sl;

      rxValid_i   : in sl;
      synHeadSt_i : in sl;
      ackHeadSt_i : in sl;
      rstHeadSt_i : in sl;

      connActive_o : out sl;
      closed_o     : out sl;
      sndSyn_o     : out sl;
      sndAck_o     : out sl;
      sndRst_o     : out sl;
      txAckF_o     : out sl;

      rxBufferSize_o : out integer range 1 to 2 ** (SEGMENT_ADDR_SIZE_G);
      rxWindowSize_o : out integer range 1 to 2 ** (WINDOW_ADDR_SIZE_G);
      txBufferSize_o : out integer range 1 to 2 ** (SEGMENT_ADDR_SIZE_G);
      txWindowSize_o : out integer range 1 to 2 ** (WINDOW_ADDR_SIZE_G);

      connState_o   : out slv(3 downto 0);
      peerTout_o    : out sl;
      paramReject_o : out sl
   );
end entity RssiConnFsmWrapper;

architecture mapping of RssiConnFsmWrapper is

   signal rxRssiParam  : RssiParamType := RSSI_PARAM_INIT_C;
   signal appRssiParam : RssiParamType := RSSI_PARAM_INIT_C;
   signal rssiParam    : RssiParamType;
   signal rxFlags      : FlagsType;

begin

   rxRssiParam.version      <= rxParamVersion_i;
   rxRssiParam.chksumEn     <= rxParamChksumEn_i;
   rxRssiParam.timeoutUnit  <= rxParamTimeoutUnit_i;
   rxRssiParam.maxOutsSeg   <= rxParamMaxOutsSeg_i;
   rxRssiParam.maxSegSize   <= rxParamMaxSegSize_i;
   rxRssiParam.retransTout  <= rxParamRetransTout_i;
   rxRssiParam.cumulAckTout <= rxParamCumulAckTout_i;
   rxRssiParam.nullSegTout  <= rxParamNullSegTout_i;
   rxRssiParam.maxRetrans   <= rxParamMaxRetrans_i;
   rxRssiParam.maxCumAck    <= rxParamMaxCumAck_i;
   rxRssiParam.maxOutofseq  <= rxParamMaxOutofseq_i;
   rxRssiParam.connectionId <= rxParamConnectionId_i;

   appRssiParam.version      <= appParamVersion_i;
   appRssiParam.chksumEn     <= appParamChksumEn_i;
   appRssiParam.timeoutUnit  <= appParamTimeoutUnit_i;
   appRssiParam.maxOutsSeg   <= appParamMaxOutsSeg_i;
   appRssiParam.maxSegSize   <= appParamMaxSegSize_i;
   appRssiParam.retransTout  <= appParamRetransTout_i;
   appRssiParam.cumulAckTout <= appParamCumulAckTout_i;
   appRssiParam.nullSegTout  <= appParamNullSegTout_i;
   appRssiParam.maxRetrans   <= appParamMaxRetrans_i;
   appRssiParam.maxCumAck    <= appParamMaxCumAck_i;
   appRssiParam.maxOutofseq  <= appParamMaxOutofseq_i;
   appRssiParam.connectionId <= appParamConnectionId_i;

   paramVersion_o      <= rssiParam.version;
   paramChksumEn_o     <= rssiParam.chksumEn;
   paramTimeoutUnit_o  <= rssiParam.timeoutUnit;
   paramMaxOutsSeg_o   <= rssiParam.maxOutsSeg;
   paramMaxSegSize_o   <= rssiParam.maxSegSize;
   paramRetransTout_o  <= rssiParam.retransTout;
   paramCumulAckTout_o <= rssiParam.cumulAckTout;
   paramNullSegTout_o  <= rssiParam.nullSegTout;
   paramMaxRetrans_o   <= rssiParam.maxRetrans;
   paramMaxCumAck_o    <= rssiParam.maxCumAck;
   paramMaxOutofseq_o  <= rssiParam.maxOutofseq;
   paramConnectionId_o <= rssiParam.connectionId;

   rxFlags.syn  <= rxFlagsSyn_i;
   rxFlags.ack  <= rxFlagsAck_i;
   rxFlags.eack <= rxFlagsEack_i;
   rxFlags.rst  <= rxFlagsRst_i;
   rxFlags.nul  <= rxFlagsNul_i;
   rxFlags.data <= rxFlagsData_i;
   rxFlags.busy <= rxFlagsBusy_i;
   rxFlags.eofe <= rxFlagsEofe_i;

   U_DUT : entity surf.RssiConnFsm
      generic map (
         TPD_G               => TPD_G,
         SERVER_G            => SERVER_G,
         TIMEOUT_UNIT_G      => TIMEOUT_UNIT_G,
         CLK_FREQUENCY_G     => CLK_FREQUENCY_G,
         RETRANS_TOUT_G      => RETRANS_TOUT_G,
         MAX_RETRANS_CNT_G   => MAX_RETRANS_CNT_G,
         WINDOW_ADDR_SIZE_G  => WINDOW_ADDR_SIZE_G,
         SEGMENT_ADDR_SIZE_G => SEGMENT_ADDR_SIZE_G)
      port map (
         clk_i          => axisClk,        -- [in]
         rst_i          => axisRst,        -- [in]
         connRq_i       => connRq_i,       -- [in]
         closeRq_i      => closeRq_i,      -- [in]
         rxRssiParam_i  => rxRssiParam,    -- [in]
         appRssiParam_i => appRssiParam,   -- [in]
         rssiParam_o    => rssiParam,      -- [out]
         rxFlags_i      => rxFlags,        -- [in]
         rxValid_i      => rxValid_i,      -- [in]
         synHeadSt_i    => synHeadSt_i,    -- [in]
         ackHeadSt_i    => ackHeadSt_i,    -- [in]
         rstHeadSt_i    => rstHeadSt_i,    -- [in]
         connActive_o   => connActive_o,   -- [out]
         closed_o       => closed_o,       -- [out]
         sndSyn_o       => sndSyn_o,       -- [out]
         sndAck_o       => sndAck_o,       -- [out]
         sndRst_o       => sndRst_o,       -- [out]
         txAckF_o       => txAckF_o,       -- [out]
         rxBufferSize_o => rxBufferSize_o, -- [out]
         rxWindowSize_o => rxWindowSize_o, -- [out]
         txBufferSize_o => txBufferSize_o, -- [out]
         txWindowSize_o => txWindowSize_o, -- [out]
         connState_o    => connState_o,    -- [out]
         peerTout_o     => peerTout_o,     -- [out]
         paramReject_o  => paramReject_o); -- [out]

end architecture mapping;
