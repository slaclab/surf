-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : DevBoard.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-08-22
-- Last update: 2015-04-02
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2013 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;

library UNISIM;
use UNISIM.VCOMPONENTS.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.ClockManager7Pkg.all;
use work.AxiMicronP30Pkg.all;

entity DevBoard is
   
   generic (
      TPD_G          : time           := 1 ns);
   port (
      -- GTP Reference Clocks
      gtRefClk125P : in sl;
      gtRefClk125N : in sl;
      gtRefClk250P : in sl;
      gtRefClk250N : in sl;

      -- Fixed Latency GTP link
      sysGtTxP : out sl;
      sysGtTxN : out sl;
      sysGtRxP : in  sl;
      sysGtRxN : in  sl;

      dataGtTxP : out slv(3 downto 0);
      dataGtTxN : out slv(3 downto 0);
      dataGtRxP : in  slv(3 downto 0);
      dataGtRxN : in  slv(3 downto 0);

      -- XADC Interface
      vAuxP : in slv(15 downto 0);
      vAuxN : in slv(15 downto 0);
      vPIn  : in sl;
      vNIn  : in sl;

      leds : out slv(7 downto 0);       -- Test outputs

      -- Flash PROM Interface
      flashDq   : inout slv(15 downto 0);
      flashAddr : out   slv(25 downto 0);
      flashCeL  : out   sl;
      flashOeL  : out   sl;
      flashWeL  : out   sl;
      flashAdv  : out   sl;
      flashWait : in    sl
      );

end entity DevBoard;

architecture rtl of DevBoard is


   -------------------------------------------------------------------------------------------------
   -- Clock Signals
   -------------------------------------------------------------------------------------------------
   signal gtRefClk125  : sl;
   signal gtRefClk125G : sl;
   signal gtRefClk250  : sl;

   signal axiClk        : sl;
   signal axiRst        : sl;
   signal axiClkMmcmRst : sl;

   signal clk250MmcmRst : sl;
   signal clk200        : sl;
   signal clk200Rst     : sl;
   signal clk250        : sl;
   signal clk250Rst     : sl;

   signal powerOnReset : sl;
   signal masterReset  : sl;
   signal fpgaReload   : sl;

   -------------------------------------------------------------------------------------------------
   -- AXI Signals
   -------------------------------------------------------------------------------------------------

   constant NUM_AXI_MASTERS_C : natural := 4;

   constant XADC_AXI_INDEX_C    : natural := 0;
   constant VERSION_AXI_INDEX_C : natural := 1;
   constant PGP_AXI_INDEX_C     : natural := 2;
   constant PROM_AXI_INDEX_C    : natural := 3;

   constant XADC_AXI_BASE_ADDR_C    : slv(31 downto 0) := X"00000000";
   constant VERSION_AXI_BASE_ADDR_C : slv(31 downto 0) := X"00200000";
   constant PGP_AXI_BASE_ADDR_C     : slv(31 downto 0) := X"00210000";
   constant PROM_AXI_BASE_ADDR_C    : slv(31 downto 0) := X"00800000";

   constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := (
      XADC_AXI_INDEX_C    => (
         baseAddr         => XADC_AXI_BASE_ADDR_C,
         addrBits         => 12,
         connectivity     => X"0001"),
      VERSION_AXI_INDEX_C => (
         baseAddr         => VERSION_AXI_BASE_ADDR_C,
         addrBits         => 12,
         connectivity     => X"0001"),
      PGP_AXI_INDEX_C     => (
         baseAddr         => PGP_AXI_BASE_ADDR_C,
         addrBits         => 14,
         connectivity     => X"0001"),
      PROM_AXI_INDEX_C    => (
         baseAddr         => PROM_AXI_BASE_ADDR_C,
         addrBits         => 8,
         connectivity     => X"0001"));


   signal extAxilWriteMaster : AxiLiteWriteMasterType;
   signal extAxilWriteSlave  : AxiLiteWriteSlaveType;
   signal extAxilReadMaster  : AxiLiteReadMasterType;
   signal extAxilReadSlave   : AxiLiteReadSlaveType;

   signal locAxilWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal locAxilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal locAxilReadMasters  : AxiLiteReadMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal locAxilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);

   -------------------------------------------------------------------------------------------------
   -- PROM Streaming interface
   -------------------------------------------------------------------------------------------------
   signal promRxAxisMaster : AxiStreamMasterType;
   signal promRxAxisSlave  : AxiStreamSlaveType;
   signal promTxAxisMaster : AxiStreamMasterType;
   signal promTxAxisSlave  : AxiStreamSlaveType;

   -------------------------------------------------------------------------------------------------
   -- Flash prom local io records
   -------------------------------------------------------------------------------------------------
   signal flashIn    : AxiMicronP30InType;
   signal flashOut   : AxiMicronP30OutType;
   signal flashInOut : AxiMicronP30InOutType;

begin

   -------------------------------------------------------------------------------------------------
   -- Bring in gt reference clocks
   -------------------------------------------------------------------------------------------------
   IBUFDS_GTE2_GTREFCLK125 : IBUFDS_GTE2
      port map (
         I   => gtRefClk125P,
         IB  => gtRefClk125N,
         CEB => '0',
         O   => gtRefClk125);

   IBUFDS_GTE2_GTREFCLK250 : IBUFDS_GTE2
      port map (
         I   => gtRefClk250P,
         IB  => gtRefClk250N,
         CEB => '0',
         O   => gtRefClk250);

   GTREFCLK125_BUFG : BUFG
      port map (
         I => gtRefClk125,
         O => gtRefClk125G);

   IBUFDS_GTE2_DAQREFCLK : IBUFDS_GTE2
      port map (
         I   => daqRefClkP,
         IB  => daqRefClkN,
         CEB => '0',
         O   => daqRefClk);

   DAQREFCLK_BUFG : BUFG
      port map (
         I => daqRefClk,
         O => daqRefClkG);

   PwrUpRst_1 : entity work.PwrUpRst
      generic map (
         TPD_G          => TPD_G,
         SIM_SPEEDUP_G  => SIMULATION_G,
         IN_POLARITY_G  => '1',
         OUT_POLARITY_G => '1')
      port map (
         clk    => gtRefClk125G,
         rstOut => powerOnReset);

   -------------------------------------------------------------------------------------------------
   -- Create global clocks from gt ref clocks
   -------------------------------------------------------------------------------------------------
   axiClkMmcmRst <= masterReset or powerOnReset;

   U_CtrlClockManager7 : entity work.ClockManager7
      generic map (
         TPD_G              => TPD_G,
         TYPE_G             => "MMCM",
         INPUT_BUFG_G       => false,
         FB_BUFG_G          => true,
         NUM_CLOCKS_G       => 1,
         BANDWIDTH_G        => "OPTIMIZED",
         CLKIN_PERIOD_G     => 8.0,
         DIVCLK_DIVIDE_G    => 1,
         CLKFBOUT_MULT_F_G  => 8.0,
         CLKOUT0_DIVIDE_F_G => 8.0,
         CLKOUT0_RST_HOLD_G => 100)
      port map (
         clkIn     => gtRefClk125G,
         rstIn     => axiClkMmcmRst,
         clkOut(0) => axiClk,
         rstOut(0) => axiRst);


   clk250MmcmRst <= masterReset or powerOnReset;

   U_DataClockManager7 : entity work.ClockManager7
      generic map (
         TPD_G              => TPD_G,
         TYPE_G             => "MMCM",
         INPUT_BUFG_G       => true,
         FB_BUFG_G          => true,
         NUM_CLOCKS_G       => 2,
         BANDWIDTH_G        => "OPTIMIZED",
         CLKIN_PERIOD_G     => 4.0,
         DIVCLK_DIVIDE_G    => 1,
         CLKFBOUT_MULT_F_G  => DATA_MMCM_CFG_C.CLKFBOUT_MULT_F_G,
         CLKOUT0_DIVIDE_F_G => DATA_MMCM_CFG_C.CLKOUT0_DIVIDE_F_G,
         CLKOUT0_RST_HOLD_G => DATA_MMCM_CFG_C.CLKOUT0_RST_HOLD_G,
         CLKOUT1_DIVIDE_G   => DATA_MMCM_CFG_C.CLKOUT1_DIVIDE_G,
         CLKOUT1_RST_HOLD_G => DATA_MMCM_CFG_C.CLKOUT1_RST_HOLD_G)
      port map (
         clkIn     => gtRefClk250,
         rstIn     => clk250MmcmRst,
         clkOut(0) => clk250,
         clkOut(1) => pgpDataClk,
         rstOut(0) => clk250Rst,
         rstOut(1) => pgpDataClkRst);


   -------------------------------------------------------------------------------------------------
   -- LED Test Outputs
   -------------------------------------------------------------------------------------------------
   Heartbeat_1 : entity work.Heartbeat
      generic map (
         TPD_G        => TPD_G,
         PERIOD_IN_G  => 8.0E-9,
         PERIOD_OUT_G => 0.8)
      port map (
         clk => axiClk,
         o   => leds(0));

   Heartbeat_2 : entity work.Heartbeat
      generic map (
         TPD_G        => TPD_G,
         PERIOD_IN_G  => 5.0E-9,
         PERIOD_OUT_G => 0.5)
      port map (
         clk => pgpDataClk,
         o   => leds(1));

   
   Heartbeat_3 : entity work.Heartbeat
      generic map (
         TPD_G        => TPD_G,
         PERIOD_IN_G  => 8.0E-9,
         PERIOD_OUT_G => 0.8)
      port map (
         clk => daqClk125,
         rst => daqClk125Rst,
         o   => leds(2));


   -------------------------------------------------------------------------------------------------
   -- PGP Interface 
   -------------------------------------------------------------------------------------------------

   -------------------------------------------------------------------------------------------------
   -- Top Axi Crossbar
   -------------------------------------------------------------------------------------------------
   TopAxiCrossbar : entity work.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXI_MASTERS_C,
         MASTERS_CONFIG_G   => AXI_CROSSBAR_MASTERS_CONFIG_C)
      port map (
         axiClk              => axiClk,
         axiClkRst           => axiRst,
         sAxiWriteMasters(0) => extAxilWriteMaster,
         sAxiWriteSlaves(0)  => extAxilWriteSlave,
         sAxiReadMasters(0)  => extAxilReadMaster,
         sAxiReadSlaves(0)   => extAxilReadSlave,
         mAxiWriteMasters    => locAxilWriteMasters,
         mAxiWriteSlaves     => locAxilWriteSlaves,
         mAxiReadMasters     => locAxilReadMasters,
         mAxiReadSlaves      => locAxilReadSlaves);

   AxiXadcWrapper_1 : entity work.AxiXadcWrapper
      generic map (
         TPD_G => TPD_G)
      port map (
         axiClk         => axiClk,
         axiRst         => axiRst,
         axiReadMaster  => locAxilReadMasters(XADC_AXI_INDEX_C),
         axiReadSlave   => locAxilReadSlaves(XADC_AXI_INDEX_C),
         axiWriteMaster => locAxilWriteMasters(XADC_AXI_INDEX_C),
         axiWriteSlave  => locAxilWriteSlaves(XADC_AXI_INDEX_C),
         vPIn           => vPIn,
         vNIn           => vNIn,
         vAuxP          => vAuxP,
         vAuxN          => vAuxN);


   -------------------------------------------------------------------------------------------------
   -- Put version info on AXI Bus
   -------------------------------------------------------------------------------------------------
   AxiVersion_1 : entity work.AxiVersion
      generic map (
         TPD_G              => TPD_G,
         EN_DEVICE_DNA_G    => true,
         EN_DS2411_G        => true,
         EN_ICAP_G          => true,
         AUTO_RELOAD_EN_G   => true,
         AUTO_RELOAD_TIME_G => 10.0,
         AUTO_RELOAD_ADDR_G => X"04000000")
      port map (
         axiClk         => axiClk,
         axiRst         => axiRst,
         axiReadMaster  => locAxilReadMasters(VERSION_AXI_INDEX_C),
         axiReadSlave   => locAxilReadSlaves(VERSION_AXI_INDEX_C),
         axiWriteMaster => locAxilWriteMasters(VERSION_AXI_INDEX_C),
         axiWriteSlave  => locAxilWriteSlaves(VERSION_AXI_INDEX_C),
         masterReset    => masterReset,
         fdSerSdio      => fdSerSdio);

   -------------------------------------------------------------------------------------------------
   -- FLASH Interface
   -------------------------------------------------------------------------------------------------

   AxiMicronP30Core_1 : entity work.AxiMicronP30Core
      generic map (
         TPD_G            => TPD_G,
         AXI_CLK_FREQ_G   => 125.0E6,
         AXI_ERROR_RESP_G => AXI_RESP_SLVERR_C)
      port map (
         flashIn        => flashIn,
         flashInOut.dq  => flashDq,
         flashOut       => flashOut,
         axiReadMaster  => locAxilReadMasters(PROM_AXI_INDEX_C),
         axiReadSlave   => locAxilReadSlaves(PROM_AXI_INDEX_C),
         axiWriteMaster => locAxilWriteMasters(PROM_AXI_INDEX_C),
         axiWriteSlave  => locAxilWriteSlaves(PROM_AXI_INDEX_C),
         mAxisMaster    => promTxAxisMaster,
         mAxisSlave     => promTxAxisSlave,
         sAxisMaster    => promRxAxisMaster,
         sAxisSlave     => promRxAxisSlave,
         axiClk         => axiClk,
         axiRst         => axiRst);

   flashAddr         <= flashOut.addr(25 downto 0);
   flashCel          <= flashOut.ceL;
   flashOel          <= flashOut.oeL;
   flashWeL          <= flashOut.weL;
   flashAdv          <= flashOut.adv;
   flashIn.flashWait <= flashWait;

end architecture rtl;
