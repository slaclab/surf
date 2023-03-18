-------------------------------------------------------------------------------
-- Title      : CoaXPress Protocol: http://jiia.org/wp-content/themes/jiia/pdf/standard_dl/coaxpress/CXP-001-2021.pdf
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: CoaXPress Core
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
use surf.AxiLitePkg.all;
use surf.CoaXPressPkg.all;

entity CoaXPressCore is
   generic (
      TPD_G              : time                   := 1 ns;
      NUM_LANES_G        : positive range 1 to 8  := 1;
      STATUS_CNT_WIDTH_G : positive range 1 to 32 := 12;
      RX_FSM_CNT_WIDTH_C : positive range 1 to 24 := 16;  -- Optimize this down w.r.t camera to help make timing in CoaXPressRxHsFsm.vhd
      AXIL_CLK_FREQ_G    : real                   := 156.25E+6;  -- axilClk frequency (units of Hz)
      AXIS_CLK_FREQ_G    : real                   := 156.25E+6;  -- dataClk frequency (units of Hz)
      DATA_AXIS_CONFIG_G : AxiStreamConfigType;
      CFG_AXIS_CONFIG_G  : AxiStreamConfigType);
   port (
      -- Data Interface (dataClk domain)
      dataClk         : in  sl;
      dataRst         : in  sl;
      dataMaster      : out AxiStreamMasterType;
      dataSlave       : in  AxiStreamSlaveType;
      imageHdrMaster  : out AxiStreamMasterType;
      imageHdrSlave   : in  AxiStreamSlaveType;
      -- Config Interface (cfgClk domain)
      cfgClk          : in  sl;
      cfgRst          : in  sl;
      cfgIbMaster     : in  AxiStreamMasterType;
      cfgIbSlave      : out AxiStreamSlaveType;
      cfgObMaster     : out AxiStreamMasterType;
      cfgObSlave      : in  AxiStreamSlaveType;
      -- Tx Interface (txClk domain)
      txClk           : in  sl;
      txRst           : in  sl;
      txLsValid       : out sl;
      txLsData        : out slv(7 downto 0);
      txLsDataK       : out sl;
      txLsRate        : out sl;
      txLsLaneEn      : out slv(3 downto 0);
      txTrig          : in  sl;
      txLinkUp        : in  sl;
      -- Rx Interface (rxClk domain)
      rxClk           : in  slv(NUM_LANES_G-1 downto 0);
      rxRst           : in  slv(NUM_LANES_G-1 downto 0);
      rxData          : in  slv32Array(NUM_LANES_G-1 downto 0);
      rxDataK         : in  Slv4Array(NUM_LANES_G-1 downto 0);
      rxDispErr       : in  slv(NUM_LANES_G-1 downto 0);
      rxDecErr        : in  slv(NUM_LANES_G-1 downto 0);
      rxLinkUp        : in  slv(NUM_LANES_G-1 downto 0);
      -- AXI-Lite Register Interface (axilClk domain)
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end entity CoaXPressCore;

architecture mapping of CoaXPressCore is

   signal cfgTxMaster : AxiStreamMasterType;
   signal cfgTxSlave  : AxiStreamSlaveType;
   signal cfgRxMaster : AxiStreamMasterType;

   signal configTimerSize : slv(31 downto 0);
   signal configErrResp   : sl;
   signal configPktTag    : sl;

   signal txTrigInv    : sl;
   signal txPulseWidth : slv(31 downto 0);
   signal swTrig       : sl;
   signal txTrigDrop   : sl;

   signal eventAck : sl;
   signal eventTag : slv(7 downto 0);

   signal trigAck     : sl;
   signal txLsRateInt : sl;

   signal dataMasterInt : AxiStreamMasterType;
   signal dataSlaveInt  : AxiStreamSlaveType;

   signal rxOverflow     : sl;
   signal rxFsmError     : sl;
   signal rxFsmRst       : sl;
   signal rxNumberOfLane : slv(2 downto 0);

begin

   txLsRate     <= txLsRateInt;
   dataMaster   <= dataMasterInt;
   dataSlaveInt <= dataSlave;

   U_Config : entity surf.CoaXPressConfig
      generic map (
         TPD_G         => TPD_G,
         AXIS_CONFIG_G => CFG_AXIS_CONFIG_G)
      port map (
         -- Clock and Reset
         cfgClk          => cfgClk,
         cfgRst          => cfgRst,
         -- Config Interface (cfgClk domain)
         configTimerSize => configTimerSize,
         configErrResp   => configErrResp,
         configPktTag    => configPktTag,
         cfgIbMaster     => cfgIbMaster,
         cfgIbSlave      => cfgIbSlave,
         cfgObMaster     => cfgObMaster,
         cfgObSlave      => cfgObSlave,
         -- TX Interface
         cfgTxMaster     => cfgTxMaster,
         cfgTxSlave      => cfgTxSlave,
         -- RX Interface
         cfgRxMaster     => cfgRxMaster);

   U_Tx : entity surf.CoaXPressTx
      generic map (
         TPD_G => TPD_G)
      port map (
         -- Config Interface (cfgClk domain)
         cfgClk       => cfgClk,
         cfgRst       => cfgRst,
         cfgTxMaster  => cfgTxMaster,
         cfgTxSlave   => cfgTxSlave,
         -- Event ACK Interface (cfgClk domain)
         eventAck     => eventAck,
         eventTag     => eventTag,
         -- TX PHY Interface (txClk domain)
         txClk        => txClk,
         txRst        => txRst,
         txLsRate     => txLsRateInt,
         txLsValid    => txLsValid,
         txLsData     => txLsData,
         txLsDataK    => txLsDataK,
         -- Trigger Interface (txClk domain)
         txTrigInv    => txTrigInv,
         txPulseWidth => txPulseWidth,
         swTrig       => swTrig,
         txTrig       => txTrig,
         txTrigDrop   => txTrigDrop);

   U_Rx : entity surf.CoaXPressRx
      generic map (
         TPD_G              => TPD_G,
         NUM_LANES_G        => NUM_LANES_G,
         RX_FSM_CNT_WIDTH_C => RX_FSM_CNT_WIDTH_C,
         AXIS_CONFIG_G      => DATA_AXIS_CONFIG_G)
      port map (
         -- Data Interface (dataClk domain)
         dataClk        => dataClk,
         dataRst        => dataRst,
         dataMaster     => dataMasterInt,
         dataSlave      => dataSlaveInt,
         imageHdrMaster => imageHdrMaster,
         imageHdrSlave  => imageHdrSlave,
         -- Config Interface (cfgClk domain)
         cfgClk         => cfgClk,
         cfgRst         => cfgRst,
         cfgRxMaster    => cfgRxMaster,
         -- Event ACK Interface (cfgClk domain)
         eventAck       => eventAck,
         eventTag       => eventTag,
         -- Trigger ACK Interface (txClk domain)
         txClk          => txClk,
         txRst          => txRst,
         trigAck        => trigAck,
         -- Rx Interface (rxClk domain)
         rxClk          => rxClk,
         rxRst          => rxRst,
         rxData         => rxData,
         rxDataK        => rxDataK,
         rxLinkUp       => rxLinkUp,
         rxOverflow     => rxOverflow,
         rxFsmError     => rxFsmError,
         rxFsmRst       => rxFsmRst,
         rxNumberOfLane => rxNumberOfLane);

   U_Axil : entity surf.CoaXPressAxiL
      generic map (
         TPD_G              => TPD_G,
         NUM_LANES_G        => NUM_LANES_G,
         STATUS_CNT_WIDTH_G => STATUS_CNT_WIDTH_G,
         RX_FSM_CNT_WIDTH_C => RX_FSM_CNT_WIDTH_C,
         AXIL_CLK_FREQ_G    => AXIL_CLK_FREQ_G,
         AXIS_CLK_FREQ_G    => AXIS_CLK_FREQ_G,
         AXIS_CONFIG_G      => DATA_AXIS_CONFIG_G)
      port map (
         -- Tx Interface (txClk domain)
         txClk           => txClk,
         txRst           => txRst,
         txTrigInv       => txTrigInv,
         txPulseWidth    => txPulseWidth,
         txTrig          => txTrig,
         swTrig          => swTrig,
         txTrigDrop      => txTrigDrop,
         trigAck         => trigAck,
         txLinkUp        => txLinkUp,
         txLsRate        => txLsRateInt,
         txLsLaneEn      => txLsLaneEn,
         -- Rx Interface (rxClk domain)
         rxClk           => rxClk,
         rxRst           => rxRst,
         rxDispErr       => rxDispErr,
         rxDecErr        => rxDecErr,
         rxLinkUp        => rxLinkUp,
         rxFsmRst        => rxFsmRst,
         rxNumberOfLane  => rxNumberOfLane,
         rxOverflow      => rxOverflow,
         rxFsmError      => rxFsmError,
         -- Config Interface (cfgClk domain)
         cfgClk          => cfgClk,
         cfgRst          => cfgClk,
         configTimerSize => configTimerSize,
         configErrResp   => configErrResp,
         configPktTag    => configPktTag,
         -- Data Interface (dataClk domain)
         dataClk         => dataClk,
         dataRst         => dataRst,
         dataMaster      => dataMasterInt,
         dataSlave       => dataSlaveInt,
         -- AXI-Lite Register Interface (axilClk domain)
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

end mapping;
