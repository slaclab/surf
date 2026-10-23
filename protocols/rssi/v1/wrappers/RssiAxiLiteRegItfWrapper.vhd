-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for RSSI AXI-Lite register tests
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
use surf.AxiLitePkg.all;
use surf.RssiPkg.all;

entity RssiAxiLiteRegItfWrapper is
   generic (
      TPD_G                 : time     := 1 ns;
      SEGMENT_ADDR_SIZE_G   : positive := 7;
      TIMEOUT_UNIT_G        : real     := 1.0E-6;
      INIT_SEQ_N_G          : natural  := 16#80#;
      CONN_ID_G             : positive := 16#12345678#;
      VERSION_G             : positive := 1;
      HEADER_CHKSUM_EN_G    : boolean  := true;
      MAX_NUM_OUTS_SEG_G    : positive := 8;
      MAX_SEG_SIZE_G        : positive := 1024;
      RETRANS_TOUT_G        : positive := 50;
      ACK_TOUT_G            : positive := 25;
      NULL_TOUT_G           : positive := 200;
      MAX_RETRANS_CNT_G     : positive := 2;
      MAX_CUM_ACK_CNT_G     : positive := 3;
      MAX_OUT_OF_SEQUENCE_G : natural  := 3
   );
   port (
      axilClk : in sl;
      axilRst : in sl;

      S_AXI_AWADDR  : in  slv(9 downto 0);
      S_AXI_AWPROT  : in  slv(2 downto 0);
      S_AXI_AWVALID : in  sl;
      S_AXI_AWREADY : out sl;
      S_AXI_WDATA   : in  slv(31 downto 0);
      S_AXI_WSTRB   : in  slv(3 downto 0);
      S_AXI_WVALID  : in  sl;
      S_AXI_WREADY  : out sl;
      S_AXI_BRESP   : out slv(1 downto 0);
      S_AXI_BVALID  : out sl;
      S_AXI_BREADY  : in  sl;
      S_AXI_ARADDR  : in  slv(9 downto 0);
      S_AXI_ARPROT  : in  slv(2 downto 0);
      S_AXI_ARVALID : in  sl;
      S_AXI_ARREADY : out sl;
      S_AXI_RDATA   : out slv(31 downto 0);
      S_AXI_RRESP   : out slv(1 downto 0);
      S_AXI_RVALID  : out sl;
      S_AXI_RREADY  : in  sl;

      openRq_o      : out sl;
      closeRq_o     : out sl;
      mode_o        : out sl;
      injectFault_o : out sl;
      initSeqN_o    : out slv(7 downto 0);

      appParamVersion_o      : out slv(3 downto 0);
      appParamChksumEn_o     : out slv(0 downto 0);
      appParamTimeoutUnit_o  : out slv(7 downto 0);
      appParamMaxOutsSeg_o   : out slv(7 downto 0);
      appParamMaxSegSize_o   : out slv(15 downto 0);
      appParamRetransTout_o  : out slv(15 downto 0);
      appParamCumulAckTout_o : out slv(15 downto 0);
      appParamNullSegTout_o  : out slv(15 downto 0);
      appParamMaxRetrans_o   : out slv(7 downto 0);
      appParamMaxCumAck_o    : out slv(7 downto 0);
      appParamMaxOutofseq_o  : out slv(7 downto 0);
      appParamConnectionId_o : out slv(31 downto 0);

      negParamVersion_i      : in slv(3 downto 0);
      negParamChksumEn_i     : in slv(0 downto 0);
      negParamTimeoutUnit_i  : in slv(7 downto 0);
      negParamMaxOutsSeg_i   : in slv(7 downto 0);
      negParamMaxSegSize_i   : in slv(15 downto 0);
      negParamRetransTout_i  : in slv(15 downto 0);
      negParamCumulAckTout_i : in slv(15 downto 0);
      negParamNullSegTout_i  : in slv(15 downto 0);
      negParamMaxRetrans_i   : in slv(7 downto 0);
      negParamMaxCumAck_i    : in slv(7 downto 0);
      negParamMaxOutofseq_i  : in slv(7 downto 0);
      negParamConnectionId_i : in slv(31 downto 0);

      txLastAckN_i : in slv(7 downto 0);
      rxSeqN_i     : in slv(7 downto 0);
      rxAckN_i     : in slv(7 downto 0);
      rxLastSeqN_i : in slv(7 downto 0);
      txTspState_i : in slv(7 downto 0);
      txAppState_i : in slv(3 downto 0);
      txAckState_i : in slv(3 downto 0);
      rxTspState_i : in slv(3 downto 0);
      rxAppState_i : in slv(3 downto 0);
      connState_i  : in slv(3 downto 0);
      frameRate0_i : in slv(31 downto 0);
      frameRate1_i : in slv(31 downto 0);
      bandwidth0_i : in slv(63 downto 0);
      bandwidth1_i : in slv(63 downto 0);
      status_i     : in slv(8 downto 0);
      dropCnt_i    : in slv(31 downto 0);
      validCnt_i   : in slv(31 downto 0);
      resendCnt_i  : in slv(31 downto 0);
      reconCnt_i   : in slv(31 downto 0)
   );
end entity RssiAxiLiteRegItfWrapper;

architecture mapping of RssiAxiLiteRegItfWrapper is

   signal axilRstN        : sl;
   signal axilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal axilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;
   signal appRssiParam    : RssiParamType          := RSSI_PARAM_INIT_C;
   signal negRssiParam    : RssiParamType          := RSSI_PARAM_INIT_C;
   signal frameRate       : Slv32Array(1 downto 0);
   signal bandwidth       : Slv64Array(1 downto 0);

begin

   axilRstN <= not axilRst;

   -----------------------
   -- AXI-Lite bus shim --
   -----------------------
   U_AXIL : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         HAS_PROT      => 1,
         HAS_WSTRB     => 1,
         ADDR_WIDTH    => 10)
      port map (
         S_AXI_ACLK      => axilClk,          -- [in]
         S_AXI_ARESETN   => axilRstN,         -- [in]
         S_AXI_AWADDR    => S_AXI_AWADDR,     -- [in]
         S_AXI_AWPROT    => S_AXI_AWPROT,     -- [in]
         S_AXI_AWVALID   => S_AXI_AWVALID,    -- [in]
         S_AXI_AWREADY   => S_AXI_AWREADY,    -- [out]
         S_AXI_WDATA     => S_AXI_WDATA,      -- [in]
         S_AXI_WSTRB     => S_AXI_WSTRB,      -- [in]
         S_AXI_WVALID    => S_AXI_WVALID,     -- [in]
         S_AXI_WREADY    => S_AXI_WREADY,     -- [out]
         S_AXI_BRESP     => S_AXI_BRESP,      -- [out]
         S_AXI_BVALID    => S_AXI_BVALID,     -- [out]
         S_AXI_BREADY    => S_AXI_BREADY,     -- [in]
         S_AXI_ARADDR    => S_AXI_ARADDR,     -- [in]
         S_AXI_ARPROT    => S_AXI_ARPROT,     -- [in]
         S_AXI_ARVALID   => S_AXI_ARVALID,    -- [in]
         S_AXI_ARREADY   => S_AXI_ARREADY,    -- [out]
         S_AXI_RDATA     => S_AXI_RDATA,      -- [out]
         S_AXI_RRESP     => S_AXI_RRESP,      -- [out]
         S_AXI_RVALID    => S_AXI_RVALID,     -- [out]
         S_AXI_RREADY    => S_AXI_RREADY,     -- [in]
         axilClk         => open,             -- [out]
         axilRst         => open,             -- [out]
         axilReadMaster  => axilReadMaster,   -- [out]
         axilReadSlave   => axilReadSlave,    -- [in]
         axilWriteMaster => axilWriteMaster,  -- [out]
         axilWriteSlave  => axilWriteSlave);  -- [in]

   ----------------------
   -- Flattened records --
   ----------------------
   negRssiParam.version      <= negParamVersion_i;
   negRssiParam.chksumEn     <= negParamChksumEn_i;
   negRssiParam.timeoutUnit  <= negParamTimeoutUnit_i;
   negRssiParam.maxOutsSeg   <= negParamMaxOutsSeg_i;
   negRssiParam.maxSegSize   <= negParamMaxSegSize_i;
   negRssiParam.retransTout  <= negParamRetransTout_i;
   negRssiParam.cumulAckTout <= negParamCumulAckTout_i;
   negRssiParam.nullSegTout  <= negParamNullSegTout_i;
   negRssiParam.maxRetrans   <= negParamMaxRetrans_i;
   negRssiParam.maxCumAck    <= negParamMaxCumAck_i;
   negRssiParam.maxOutofseq  <= negParamMaxOutofseq_i;
   negRssiParam.connectionId <= negParamConnectionId_i;

   appParamVersion_o      <= appRssiParam.version;
   appParamChksumEn_o     <= appRssiParam.chksumEn;
   appParamTimeoutUnit_o  <= appRssiParam.timeoutUnit;
   appParamMaxOutsSeg_o   <= appRssiParam.maxOutsSeg;
   appParamMaxSegSize_o   <= appRssiParam.maxSegSize;
   appParamRetransTout_o  <= appRssiParam.retransTout;
   appParamCumulAckTout_o <= appRssiParam.cumulAckTout;
   appParamNullSegTout_o  <= appRssiParam.nullSegTout;
   appParamMaxRetrans_o   <= appRssiParam.maxRetrans;
   appParamMaxCumAck_o    <= appRssiParam.maxCumAck;
   appParamMaxOutofseq_o  <= appRssiParam.maxOutofseq;
   appParamConnectionId_o <= appRssiParam.connectionId;

   frameRate(0) <= frameRate0_i;
   frameRate(1) <= frameRate1_i;
   bandwidth(0) <= bandwidth0_i;
   bandwidth(1) <= bandwidth1_i;

   -------------------
   -- DUT instancing --
   -------------------
   U_DUT : entity surf.RssiAxiLiteRegItf
      generic map (
         TPD_G                 => TPD_G,
         COMMON_CLK_G          => true,
         SEGMENT_ADDR_SIZE_G   => SEGMENT_ADDR_SIZE_G,
         TIMEOUT_UNIT_G        => TIMEOUT_UNIT_G,
         INIT_SEQ_N_G          => INIT_SEQ_N_G,
         CONN_ID_G             => CONN_ID_G,
         VERSION_G             => VERSION_G,
         HEADER_CHKSUM_EN_G    => HEADER_CHKSUM_EN_G,
         MAX_NUM_OUTS_SEG_G    => MAX_NUM_OUTS_SEG_G,
         MAX_SEG_SIZE_G        => MAX_SEG_SIZE_G,
         RETRANS_TOUT_G        => RETRANS_TOUT_G,
         ACK_TOUT_G            => ACK_TOUT_G,
         NULL_TOUT_G           => NULL_TOUT_G,
         MAX_RETRANS_CNT_G     => MAX_RETRANS_CNT_G,
         MAX_CUM_ACK_CNT_G     => MAX_CUM_ACK_CNT_G,
         MAX_OUT_OF_SEQUENCE_G => MAX_OUT_OF_SEQUENCE_G)
      port map (
         axiClk_i        => axilClk,           -- [in]
         axiRst_i        => axilRst,           -- [in]
         axilReadMaster  => axilReadMaster,    -- [in]
         axilReadSlave   => axilReadSlave,     -- [out]
         axilWriteMaster => axilWriteMaster,   -- [in]
         axilWriteSlave  => axilWriteSlave,    -- [out]
         devClk_i        => axilClk,           -- [in]
         devRst_i        => axilRst,           -- [in]
         openRq_o        => openRq_o,          -- [out]
         closeRq_o       => closeRq_o,         -- [out]
         mode_o          => mode_o,            -- [out]
         injectFault_o   => injectFault_o,     -- [out]
         initSeqN_o      => initSeqN_o,        -- [out]
         appRssiParam_o  => appRssiParam,      -- [out]
         negRssiParam_i  => negRssiParam,      -- [in]
         txLastAckN_i    => txLastAckN_i,      -- [in]
         rxSeqN_i        => rxSeqN_i,          -- [in]
         rxAckN_i        => rxAckN_i,          -- [in]
         rxLastSeqN_i    => rxLastSeqN_i,      -- [in]
         txTspState_i    => txTspState_i,      -- [in]
         txAppState_i    => txAppState_i,      -- [in]
         txAckState_i    => txAckState_i,      -- [in]
         rxTspState_i    => rxTspState_i,      -- [in]
         rxAppState_i    => rxAppState_i,      -- [in]
         connState_i     => connState_i,       -- [in]
         frameRate_i     => frameRate,         -- [in]
         bandwidth_i     => bandwidth,         -- [in]
         status_i        => status_i,          -- [in]
         dropCnt_i       => dropCnt_i,         -- [in]
         validCnt_i      => validCnt_i,        -- [in]
         resendCnt_i     => resendCnt_i,       -- [in]
         reconCnt_i      => reconCnt_i);       -- [in]

end architecture mapping;
