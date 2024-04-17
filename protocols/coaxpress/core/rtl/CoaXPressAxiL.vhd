-------------------------------------------------------------------------------
-- Title      : CoaXPress Protocol: http://jiia.org/wp-content/themes/jiia/pdf/standard_dl/coaxpress/CXP-001-2021.pdf
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: AXI-Lite block to manage the CoaXPress interface
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.CoaXPressPkg.all;

entity CoaXPressAxiL is
   generic (
      TPD_G              : time                   := 1 ns;
      NUM_LANES_G        : positive               := 1;
      STATUS_CNT_WIDTH_G : positive range 1 to 32 := 12;
      RX_FSM_CNT_WIDTH_C : positive range 1 to 24 := 16;  -- Optimize this down w.r.t camera to help make timing in CoaXPressRxHsFsm.vhd
      AXIL_CLK_FREQ_G    : real                   := 156.25E+6;  -- axilClk frequency (units of Hz)
      AXIS_CLK_FREQ_G    : real                   := 156.25E+6;  -- dataClk frequency (units of Hz)
      AXIS_CONFIG_G      : AxiStreamConfigType);
   port (
      -- Tx Interface (txClk domain)
      txClk           : in  sl;
      txRst           : in  sl;
      txTrigInv       : out sl;
      txPulseWidth    : out slv(31 downto 0);
      txTrig          : in  sl;
      swTrig          : out sl;
      txTrigDrop      : in  sl;
      trigAck         : in  sl;
      txLinkUp        : in  sl;
      txLsRate        : out sl;
      txLsLaneEn      : out slv(3 downto 0);
      -- Rx Interface (rxClk domain)
      rxClk           : in  slv(NUM_LANES_G-1 downto 0);
      rxRst           : in  slv(NUM_LANES_G-1 downto 0);
      rxDispErr       : in  slv(NUM_LANES_G-1 downto 0);
      rxDecErr        : in  slv(NUM_LANES_G-1 downto 0);
      rxLinkUp        : in  slv(NUM_LANES_G-1 downto 0);
      rxFsmRst        : out sl;         -- (rxClk(0) domain only)
      rxNumberOfLane  : out slv(2 downto 0);  -- (rxClk(0) domain only)
      rxOverflow      : in  sl;
      rxFsmError      : in  sl;         -- (rxClk(0) domain only)
      -- Config Interface (cfgClk domain)
      cfgClk          : in  sl;
      cfgRst          : in  sl;
      configTimerSize : out slv(31 downto 0);
      configErrResp   : out sl;
      configPktTag    : out sl;
      -- Data Interface (dataClk domain)
      dataClk         : in  sl;
      dataRst         : in  sl;
      dataMaster      : in  AxiStreamMasterType;
      dataSlave       : in  AxiStreamSlaveType;
      -- AXI-Lite Register Interface (axilClk domain)
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end CoaXPressAxiL;

architecture rtl of CoaXPressAxiL is

   constant TX_STATUS_CNT_C : positive := 4;
   constant RX_STATUS_CNT_C : positive := 2;

   type RegType is record
      rxNumberOfLane  : slv(3 downto 0);
      rxLaneMinusOne  : slv(3 downto 0);
      txTrigInv       : sl;
      txPulseWidth    : slv(31 downto 0);
      txLsRate        : sl;
      txLsLaneEn      : slv(3 downto 0);
      configTimerSize : slv(31 downto 0);
      configErrResp   : sl;
      configPktTag    : sl;
      swTrig          : sl;
      rxFsmRst        : sl;
      cntRst          : sl;
      axilWriteSlave  : AxiLiteWriteSlaveType;
      axilReadSlave   : AxiLiteReadSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      rxNumberOfLane  => toSlv(NUM_LANES_G, 4),
      rxLaneMinusOne  => toSlv(NUM_LANES_G-1, 4),
      txTrigInv       => '0',
      txPulseWidth    => toSlv(31250-1, 32),  -- 100 us
      txLsRate        => '0',
      txLsLaneEn      => x"1",
      configTimerSize => x"0F_FF_FF_FF",
      configErrResp   => '1',
      configPktTag    => '0',
      swTrig          => '0',
      rxFsmRst        => '0',
      cntRst          => '1',
      axilWriteSlave  => AXI_LITE_WRITE_SLAVE_INIT_C,
      axilReadSlave   => AXI_LITE_READ_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal rxLinkUpCnt       : SlVectorArray(NUM_LANES_G-1 downto 0, STATUS_CNT_WIDTH_G-1 downto 0);
   signal rxFifoOverflowCnt : SlVectorArray(NUM_LANES_G-1 downto 0, STATUS_CNT_WIDTH_G-1 downto 0);
   signal rxDecErrCnt       : SlVectorArray(NUM_LANES_G-1 downto 0, STATUS_CNT_WIDTH_G-1 downto 0);
   signal rxDispErrCnt      : SlVectorArray(NUM_LANES_G-1 downto 0, STATUS_CNT_WIDTH_G-1 downto 0);

   signal rxDispErrSync      : slv(NUM_LANES_G-1 downto 0);
   signal rxDecErrSync       : slv(NUM_LANES_G-1 downto 0);
   signal rxFifoOverflowSync : slv(NUM_LANES_G-1 downto 0);
   signal rxLinkUpSync       : slv(NUM_LANES_G-1 downto 0);
   signal rxLinkUpStatus     : slv(NUM_LANES_G-1 downto 0);
   signal rxOverflowSync     : sl;

   signal txCntOut    : SlVectorArray(TX_STATUS_CNT_C-1 downto 0, STATUS_CNT_WIDTH_G-1 downto 0);
   signal txStatusOut : slv(TX_STATUS_CNT_C-1 downto 0);

   signal rxCntOut    : SlVectorArray(RX_STATUS_CNT_C-1 downto 0, STATUS_CNT_WIDTH_G-1 downto 0);
   signal rxStatusOut : slv(RX_STATUS_CNT_C-1 downto 0);

   signal trigFreq  : slv(31 downto 0);
   signal txClkFreq : slv(31 downto 0);
   signal rxClkFreq : Slv32Array(NUM_LANES_G-1 downto 0);

   signal dataReset    : sl;
   signal frameCnt     : slv(63 downto 0);  -- units of frames
   signal frameSize    : slv(31 downto 0);  -- units of Byte
   signal frameSizeMax : slv(31 downto 0);  -- units of Byte
   signal frameSizeMin : slv(31 downto 0);  -- units of Byte
   signal frameRate    : slv(31 downto 0);  -- units of Hz
   signal frameRateMax : slv(31 downto 0);  -- units of Hz
   signal frameRateMin : slv(31 downto 0);  -- units of Hz
   signal bandwidth    : slv(63 downto 0);  -- units of Byte/s
   signal bandwidthMax : slv(63 downto 0);  -- units of Byte/s
   signal bandwidthMin : slv(63 downto 0);  -- units of Byte/s

begin

   process (axilReadMaster, axilRst, axilWriteMaster, bandwidth, bandwidthMax,
            bandwidthMin, frameCnt, frameRate, frameRateMax, frameRateMin,
            frameSize, frameSizeMax, frameSizeMin, r, rxClkFreq, rxCntOut,
            rxDecErrCnt, rxDispErrCnt, rxLinkUpCnt, rxLinkUpStatus,
            rxStatusOut, trigFreq, txClkFreq, txCntOut, txStatusOut) is
      variable v      : RegType;
      variable axilEp : AxiLiteEndpointType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobes
      v.cntRst   := '0';
      v.swTrig   := '0';
      v.rxFsmRst := '0';

      ------------------------
      -- AXI-Lite Transactions
      ------------------------

      -- Determine the transaction type
      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      for i in 0 to NUM_LANES_G-1 loop
         axiSlaveRegisterR(axilEp, x"000"+toSlv(i*4, 12), 0, muxSlVectorArray(rxLinkUpCnt, i));  -- 0x000:0x03F
         axiSlaveRegisterR(axilEp, x"040"+toSlv(i*4, 12), 0, muxSlVectorArray(rxDecErrCnt, i));  -- 0x040:0x07F
         axiSlaveRegisterR(axilEp, x"080"+toSlv(i*4, 12), 0, muxSlVectorArray(rxDispErrCnt, i));  -- 0x080:0x0BF
         axiSlaveRegisterR(axilEp, x"0C0"+toSlv(i*4, 12), 0, rxClkFreq(i));  -- 0x0C0:0x0FF
      end loop;

      axiSlaveRegisterR(axilEp, x"800", 0, trigFreq);
      axiSlaveRegisterR(axilEp, x"804", 0, rxLinkUpStatus);
      axiSlaveRegisterR(axilEp, x"808", 0, txStatusOut);
      axiSlaveRegisterR(axilEp, x"80C", 0, txClkFreq);

      axiSlaveRegisterR(axilEp, x"810", 0, muxSlVectorArray(txCntOut, 0));  -- txLinkUpCnt
      axiSlaveRegisterR(axilEp, x"814", 0, muxSlVectorArray(txCntOut, 1));  -- trigAckCnt
      axiSlaveRegisterR(axilEp, x"818", 0, muxSlVectorArray(txCntOut, 2));  -- txTrigCnt
      axiSlaveRegisterR(axilEp, x"81C", 0, muxSlVectorArray(txCntOut, 3));  -- txTrigDropCnt

      axiSlaveRegisterR(axilEp, x"820", 0, muxSlVectorArray(rxCntOut, 0));  -- rxOverflowCnt
      axiSlaveRegisterR(axilEp, x"824", 0, muxSlVectorArray(rxCntOut, 1));  -- rxFsmErrorCnt
      axiSlaveRegisterR(axilEp, x"828", 0, rxStatusOut);

      -- Matching with AxiStreamMonChannel Python device register mapping w/ offset=0x900
      axiSlaveRegisterR(axilEp, x"904", 0, frameCnt);      -- 0x904:0x90B
      axiSlaveRegisterR(axilEp, x"90C", 0, frameRate);
      axiSlaveRegisterR(axilEp, x"910", 0, frameRateMax);
      axiSlaveRegisterR(axilEp, x"914", 0, frameRateMin);
      axiSlaveRegisterR(axilEp, x"918", 0, bandwidth);     -- 0x918:0x91F
      axiSlaveRegisterR(axilEp, x"920", 0, bandwidthMax);  -- 0x920:0x927
      axiSlaveRegisterR(axilEp, x"928", 0, bandwidthMin);  -- 0x928:0x92F
      axiSlaveRegisterR(axilEp, x"930", 0, frameSize);
      axiSlaveRegisterR(axilEp, x"934", 0, frameSizeMax);
      axiSlaveRegisterR(axilEp, x"938", 0, frameSizeMin);

      axiSlaveRegisterR(axilEp, x"FE0", 0, toSlv(NUM_LANES_G, 8));
      axiSlaveRegisterR(axilEp, x"FE0", 8, toSlv(STATUS_CNT_WIDTH_G, 8));
      axiSlaveRegisterR(axilEp, x"FE0", 16, toSlv(RX_FSM_CNT_WIDTH_C, 8));

      axiSlaveRegister (axilEp, X"FE8", 0, v.rxFsmRst);
      axiSlaveRegister (axilEp, X"FEC", 0, v.txPulseWidth);
      axiSlaveRegister (axilEp, X"FF0", 0, v.swTrig);

      axiSlaveRegister (axilEp, x"FF4", 0, v.configTimerSize);

      axiSlaveRegister (axilEp, x"FF8", 0, v.rxNumberOfLane);  -- BIT3:BIT0
      axiSlaveRegister (axilEp, x"FF8", 24, v.txTrigInv);
      axiSlaveRegister (axilEp, x"FF8", 25, v.configErrResp);
      axiSlaveRegister (axilEp, x"FF8", 26, v.configPktTag);
      axiSlaveRegister (axilEp, x"FF8", 27, v.txLsRate);
      axiSlaveRegister (axilEp, x"FF8", 28, v.txLsLaneEn);     -- BIT31:BIT28

      axiSlaveRegister (axilEp, X"FFC", 0, v.cntRst);

      -- Close the transaction
      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);

      -- Prevent out of range values
      if (v.rxNumberOfLane = 0) or (v.rxNumberOfLane > NUM_LANES_G) then
         v.rxNumberOfLane := r.rxNumberOfLane;
      end if;
      v.rxLaneMinusOne := r.rxNumberOfLane - 1;

      -- Outputs
      axilReadSlave  <= r.axilReadSlave;
      axilWriteSlave <= r.axilWriteSlave;

      -- Reset
      if (axilRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Next register assignment
      rin <= v;

   end process;

   process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         r <= rin after TPD_G;
      end if;
   end process;

   ------------------------------
   -- Transmitter Synchronization
   ------------------------------
   U_txPulseWidth : entity surf.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 32)
      port map (
         clk     => txClk,
         dataIn  => r.txPulseWidth,
         dataOut => txPulseWidth);

   U_txTrigInv : entity surf.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => txClk,
         dataIn  => r.txTrigInv,
         dataOut => txTrigInv);

   U_swTrig : entity surf.SynchronizerOneShot
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => txClk,
         dataIn  => r.swTrig,
         dataOut => swTrig);

   U_txCntOut : entity surf.SyncStatusVector
      generic map (
         TPD_G       => TPD_G,
         CNT_WIDTH_G => STATUS_CNT_WIDTH_G,
         WIDTH_G     => TX_STATUS_CNT_C)
      port map (
         statusIn(0)  => txLinkUp,
         statusIn(1)  => trigAck,
         statusIn(2)  => txTrig,
         statusIn(3)  => txTrigDrop,
         rollOverEnIn => "0110",
         statusOut    => txStatusOut,
         cntRstIn     => r.cntRst,
         cntOut       => txCntOut,
         wrClk        => txClk,
         wrRst        => txRst,
         rdClk        => axilClk,
         rdRst        => axilRst);

   U_trigFreq : entity surf.SyncTrigRate
      generic map (
         TPD_G          => TPD_G,
         ONE_SHOT_G     => true,        -- true=SynchronizerOneShot
         REF_CLK_FREQ_G => AXIL_CLK_FREQ_G)
      port map (
         -- Trigger Input (locClk domain)
         trigIn      => txTrig,
         -- Trigger Rate Output (locClk domain)
         trigRateOut => trigFreq,
         -- Clocks
         locClk      => axilClk,
         refClk      => axilClk);

   U_txClkFreq : entity surf.SyncClockFreq
      generic map (
         TPD_G          => TPD_G,
         REF_CLK_FREQ_G => AXIL_CLK_FREQ_G,
         COMMON_CLK_G   => true,        -- locClk = refClk
         CNT_WIDTH_G    => 32)
      port map (
         freqOut => txClkFreq,
         clkIn   => txClk,
         locClk  => axilClk,
         refClk  => axilClk);

   U_txLsRate : entity surf.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => txClk,
         dataIn  => r.txLsRate,
         dataOut => txLsRate);

   U_txLsLaneEn : entity surf.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 4)
      port map (
         clk     => txClk,
         dataIn  => r.txLsLaneEn,
         dataOut => txLsLaneEn);

   ---------------------------
   -- Receiver Synchronization
   ---------------------------

   U_rxLinkUpSync : entity surf.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => NUM_LANES_G)
      port map (
         clk     => axilClk,
         rst     => axilRst,
         dataIn  => rxLinkUp,
         dataOut => rxLinkUpSync);

   U_rxLinkUp : entity surf.SyncStatusVector
      generic map (
         TPD_G       => TPD_G,
         CNT_WIDTH_G => STATUS_CNT_WIDTH_G,
         WIDTH_G     => NUM_LANES_G)
      port map (
         statusIn  => rxLinkUpSync,
         statusOut => rxLinkUpStatus,
         cntRstIn  => r.cntRst,
         cntOut    => rxLinkUpCnt,
         wrClk     => axilClk,
         wrRst     => axilRst,
         rdClk     => axilClk,
         rdRst     => axilRst);

   U_rxDecErrSync : entity surf.SynchronizerOneShotVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => NUM_LANES_G)
      port map (
         clk     => axilClk,
         rst     => axilRst,
         dataIn  => rxDecErr,
         dataOut => rxDecErrSync);

   U_rxDecErr : entity surf.SyncStatusVector
      generic map (
         TPD_G       => TPD_G,
         CNT_WIDTH_G => STATUS_CNT_WIDTH_G,
         WIDTH_G     => NUM_LANES_G)
      port map (
         statusIn => rxDecErrSync,
         cntRstIn => r.cntRst,
         cntOut   => rxDecErrCnt,
         wrClk    => axilClk,
         wrRst    => axilRst,
         rdClk    => axilClk,
         rdRst    => axilRst);

   U_rxDispErrSync : entity surf.SynchronizerOneShotVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => NUM_LANES_G)
      port map (
         clk     => axilClk,
         rst     => axilRst,
         dataIn  => rxDispErr,
         dataOut => rxDispErrSync);

   U_rxDispErr : entity surf.SyncStatusVector
      generic map (
         TPD_G       => TPD_G,
         CNT_WIDTH_G => STATUS_CNT_WIDTH_G,
         WIDTH_G     => NUM_LANES_G)
      port map (
         statusIn => rxDispErrSync,
         cntRstIn => r.cntRst,
         cntOut   => rxDispErrCnt,
         wrClk    => axilClk,
         wrRst    => axilRst,
         rdClk    => axilClk,
         rdRst    => axilRst);

   GEN_VEC :
   for i in (NUM_LANES_G-1) downto 0 generate

      U_rxClkFreq : entity surf.SyncClockFreq
         generic map (
            TPD_G          => TPD_G,
            REF_CLK_FREQ_G => AXIL_CLK_FREQ_G,
            COMMON_CLK_G   => true,     -- locClk = refClk
            CNT_WIDTH_G    => 32)
         port map (
            freqOut => rxClkFreq(i),
            clkIn   => rxClk(i),
            locClk  => axilClk,
            refClk  => axilClk);

   end generate GEN_VEC;

   U_rxNumberOfLane : entity surf.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 3)
      port map (
         clk     => rxClk(0),
         dataIn  => r.rxLaneMinusOne(2 downto 0),
         dataOut => rxNumberOfLane);  -- Output use minus 1 value because zero inclusive internally

   U_rxFsmRst : entity surf.SynchronizerOneShot
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => rxClk(0),
         dataIn  => r.rxFsmRst,
         dataOut => rxFsmRst);

   U_rxOverflow : entity surf.SynchronizerOneShot
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => axilClk,
         rst     => axilRst,
         dataIn  => rxOverflow,
         dataOut => rxOverflowSync);

   U_rxCntOut : entity surf.SyncStatusVector
      generic map (
         TPD_G       => TPD_G,
         CNT_WIDTH_G => STATUS_CNT_WIDTH_G,
         WIDTH_G     => RX_STATUS_CNT_C)
      port map (
         statusIn(0) => rxOverflowSync,
         statusIn(1) => rxFsmError,
         statusOut   => rxStatusOut,
         cntRstIn    => r.cntRst,
         cntOut      => rxCntOut,
         wrClk       => rxClk(0),
         wrRst       => rxRst(0),
         rdClk       => axilClk,
         rdRst       => axilRst);

   --------------------------------
   -- Configuration Synchronization
   --------------------------------
   U_configTimerSize : entity surf.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 32)
      port map (
         clk     => cfgClk,
         dataIn  => r.configTimerSize,
         dataOut => configTimerSize);

   U_configErrResp : entity surf.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => cfgClk,
         dataIn  => r.configErrResp,
         dataOut => configErrResp);

   U_configPktTag : entity surf.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => cfgClk,
         dataIn  => r.configPktTag,
         dataOut => configPktTag);

   -------------------------
   -- Data Stream Monitoring
   -------------------------
   U_AxiStreamMon : entity surf.AxiStreamMon
      generic map(
         TPD_G           => TPD_G,
         COMMON_CLK_G    => false,
         AXIS_CLK_FREQ_G => AXIS_CLK_FREQ_G,
         AXIS_CONFIG_G   => AXIS_CONFIG_G)
      port map(
         -- AXIS Stream Interface
         axisClk      => dataClk,
         axisRst      => dataReset,
         axisMaster   => dataMaster,
         axisSlave    => dataSlave,
         -- Status Clock and reset
         statusClk    => axilClk,
         statusRst    => r.cntRst,
         -- Status: Total number of frame received since statusRst
         frameCnt     => frameCnt,
         -- Status: Frame Size (units of Byte)
         frameSize    => frameSize,
         frameSizeMax => frameSizeMax,
         frameSizeMin => frameSizeMin,
         -- Status: Frame rate (units of Hz)
         frameRate    => frameRate,
         frameRateMax => frameRateMax,
         frameRateMin => frameRateMin,
         -- Status: Bandwidth (units of Byte/s)
         bandwidth    => bandwidth,
         bandwidthMax => bandwidthMax,
         bandwidthMin => bandwidthMin);

   U_dataReset : entity surf.SynchronizerOneShot
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => dataClk,
         dataIn  => r.cntRst,
         dataOut => dataReset);

end rtl;

