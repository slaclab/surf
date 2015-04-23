-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : DevBoard.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-08-22
-- Last update: 2015-04-22
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

entity DevBoard is
   
   generic (
      TPD_G                  : time    := 1 ns;
      -- PGP Config
      PGP_REFCLK_FREQ_G      : real    := 125.0E6;
      PGP_LINE_RATE_G        : real    := 3.125E9;
      -- AXIL Config
      AXIL_CLK_FREQ_C        : real    := 125.0E6;
      -- AXIS Config
      AXIS_CLK_FREQ_G        : real : 160.0E6;
      AXIS_FIFO_ADDR_WIDTH_G : integer := 9);
   port (
      pgpRefClkP : in sl;
      pgpRefClkN : in sl;

      -- PGP MGT signals
      pgpGtRxN : in  sl;                -- SFP+ 
      pgpGtRxP : in  sl;
      pgpGtTxN : out sl;
      pgpGtTxP : out sl;

      -- FMC Signals -- 
      -- Signals from clock manager
      fpgaDevClkaP : in sl;             -- GBT_CLK_0_P - FMC D3
      fpgaDevClkaN : in sl;             -- GBT_CLK_0_N - FMC D4
      fpgaDevClkbP : in sl;             -- LA00_P_CC - FMC G6
      fpgaDevClkbN : in sl;             -- LA00_N_CC - FMC G7
      fpgaSysRefP  : in sl;             -- LA03_P - FMC G9
      fpgaSysRefN  : in sl;             -- LA04_N - FMC G10

      -- Signals to ADC (if clock manager not used)
      adcDevClkP : out sl;              -- LA01_P_CC - FMC D7
      adcDevClkN : out sl;              -- LA01_N_CC - FMC D8
      adcSysRefP : out sl;              -- LA05_P_CC - FMC D11
      adcSysRefN : out sl;              -- LA05_N_CC - FMC D12

      -- JESD MGT signals
      adcGtTxP : out slv(3 downto 0);   -- FMC HPC DP[3:0]
      adcGtTxN : out slv(3 downto 0);
      adcGtRxP : in  slv(3 downto 0);
      adcGtRxN : in  slv(3 downto 0);

      -- Synchronization JESD signals (Used in subclass 0 and subclass 2 modes)
      syncbP : out sl;                  -- LA08_P - FMC G12
      syncbN : out sl;                  -- LA08_N - FMC G13

      -- Adc OVR/trigger signals
      ovraTrigRdy : in sl;              -- LA25_P - FMC G27
      ovrbTrigger : in sl;              -- LA26_P - FMC D26

      -- ADC SPI config interface
      spiSclk : out sl;                 -- FMC H37
      spiSdi  : out sl;                 -- FMC G36
      spiSdo  : in  sl;                 -- FMC G37
      spiCsL  : out sl;                 -- FMC H38

      -- Onboard LEDs
      leds : out slv(3 downto 0));


end entity DevBoard;

architecture rtl of DevBoard is

   constant PGP_REFCLK_PERIOD_C : real := 1.0 / PGP_REFCLK_FREQ_C;
   constant AXI_CLK_FREQ_C      : real := PGP_LINE_RATE_C / 20;

   -------------------------------------------------------------------------------------------------
   -- Clock Signals
   -------------------------------------------------------------------------------------------------
   signal gtRefClk125  : sl;
   signal gtRefClk125G : sl;

   signal axilClk    : sl;
   signal axilClkRst : sl;
   signal pgpClk     : sl;
   signal pgpClkRst  : sl;
   signal jesdClk    : sl;
   signal jesdClkRst : sl;
   signal mmcmRst    : sl;

   signal powerOnReset : sl;
   signal masterReset  : sl;
   signal fpgaReload   : sl;

   -------------------------------------------------------------------------------------------------
   -- PGP MGT PLL Config
   -------------------------------------------------------------------------------------------------
   constant PGP_GTX_CPLL_CONFIG_G : Gtx7CfgType := getGtx7CPllCfg(PGP_REFCLK_FREQ_C, PGP_LINE_RATE_C);

   -------------------------------------------------------------------------------------------------
   -- AXI Lite Config and Signals
   -------------------------------------------------------------------------------------------------
   constant NUM_AXI_MASTERS_C : natural := 2;

   constant VERSION_AXI_INDEX_C : natural := 0;
   constant ADC_SPI_AXI_INDEX_C : natural := 1;

   constant VERSION_AXI_BASE_ADDR_C : slv(31 downto 0) := X"00000000";
   constant ADC_SPI_AXI_BASE_ADDR_C : slv(31 downto 0) := X"00010000";

   constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := (
      VERSION_AXI_INDEX_C => (
         baseAddr         => VERSION_AXI_BASE_ADDR_C,
         addrBits         => 12,
         connectivity     => X"0001"),
      ADC_SPI_AXI_INDEX_C => (
         baseAddr         => ADC_SPI_AXI_BASE_ADDR_C,
         addrBits         => 14,
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
   -- PGP Signals and Virtual Channels
   -------------------------------------------------------------------------------------------------
   signal axisTxMasters : AxiStreamMasterArray(1 downto 0);
   signal axisTxSlaves  : AxiStreamSlaveArray(1 downto 0);

   signal axisFifoPauseThreshold : slv(AXIS_FIFO_ADDR_WIDTH_G-1 downto 0);
   
begin

   -------------------------------------------------------------------------------------------------
   -- Bring in gt reference clocks
   -------------------------------------------------------------------------------------------------
   IBUFDS_GTE2_GTREFCLK125 : IBUFDS_GTE2
      port map (
         I   => pgpRefClkP,
         IB  => pgpRefClkN,
         CEB => '0',
         O   => pgpRefClk);

   GTREFCLK125_BUFG : BUFG
      port map (
         I => pgpRefClk,
         O => pgpRefClkG);

   PwrUpRst_1 : entity work.PwrUpRst
      generic map (
         TPD_G          => TPD_G,
         SIM_SPEEDUP_G  => SIMULATION_G,
         IN_POLARITY_G  => '1',
         OUT_POLARITY_G => '1')
      port map (
         clk    => pgpRefClkG,
         rstOut => powerOnReset);

   -------------------------------------------------------------------------------------------------
   -- Create global clocks from gt ref clocks
   -------------------------------------------------------------------------------------------------
   mmcmRst <= masterReset or powerOnReset;

   U_CtrlClockManager7 : entity work.ClockManager7
      generic map (
         TPD_G              => TPD_G,
         TYPE_G             => "MMCM",
         INPUT_BUFG_G       => false,
         FB_BUFG_G          => true,
         NUM_CLOCKS_G       => 1,
         BANDWIDTH_G        => "OPTIMIZED",
         CLKIN_PERIOD_G     => PGP_REFCLK_PERIOD_C*1.0E9,
         DIVCLK_DIVIDE_G    => 1,
         CLKFBOUT_MULT_F_G  => 7.5,
         CLKOUT0_DIVIDE_F_G => 7.5,
         CLKOUT0_RST_HOLD_G => 16,
         CLKOUT1_DIVIDE_G => 6,
         CLKOUT1_RST_HOLD_G => 16)
      port map (
         clkIn     => ctrlRefClkG,
         rstIn     => axilClkMmcmRst,
         clkOut(0) => axilClk,
         clkOut(1) => pgpClk,
         rstOut(0) => axilClkRst,
         rstOut(1) => pgpClkRst);

   -------------------------------------------------------------------------------------------------
   -- LED Test Outputs
   -------------------------------------------------------------------------------------------------
   Heartbeat_axilClk : entity work.Heartbeat
      generic map (
         TPD_G        => TPD_G,
         PERIOD_IN_G  => 8.0E-9,
         PERIOD_OUT_G => 0.8)
      port map (
         clk => axilClk,
         o   => leds(0));
   
   Heartbeat_pgpClk : entity work.Heartbeat
      generic map (
         TPD_G        => TPD_G,
         PERIOD_IN_G  => 6.4E-9,
         PERIOD_OUT_G => 0.64)
      port map (
         clk => pgpClk,
         o   => leds(1));
   -------------------------------------------------------------------------------------------------
   -- PGP Interface 
   -------------------------------------------------------------------------------------------------
   PgpFrontEnd_1 : entity work.PgpFrontEnd
      generic map (
         TPD_G                 => TPD_G,
         PGP_REFCLK_FREQ_G     => PGP_REFCLK_FREQ_G,
         PGP_LINE_RATE_G       => PGP_LINE_RATE_G,
         AXI_LITE_CLK_FREQ_G   => AXI_LITE_CLK_FREQ_G,
         AXI_STREAM_CLK_FREQ_G => AXI_STREAM_CLK_FREQ_G,
         AXI_STREAM_CONFIG_C   => AXI_STREAM_CONFIG_C)
      port map (
         pgpRefClk       => pgpRefClk,
         pgpClk          => pgpClk,
         pgpGtRxN        => pgpGtRxN,
         pgpGtRxP        => pgpGtRxP,
         pgpGtTxN        => pgpGtTxN,
         pgpGtTxP        => pgpGtTxP,
         axilClk         => axilClk,
         axilClkRst      => axilClkRst,
         axilWriteMaster => extAxilWriteMaster,
         axilWriteSlave  => extAxilWriteSlave,
         axilReadMaster  => extAxilReadMaster,
         axilReadSlave   => extAxilReadSlave,
         axisClk         => axisClk,
         axisClkRst      => axisClkRst,
         axisTxMasters   => axisTxMasters,
         axisTxSlaves    => axisTxSlaves,
         axisTxCtrl      => axisTxCtrl,
         leds            => leds(3 downto 2));

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
         axiClk              => axilClk,
         axiClkRst           => axilClkRst,
         sAxiWriteMasters(0) => extAxilWriteMaster,
         sAxiWriteSlaves(0)  => extAxilWriteSlave,
         sAxiReadMasters(0)  => extAxilReadMaster,
         sAxiReadSlaves(0)   => extAxilReadSlave,
         mAxiWriteMasters    => locAxilWriteMasters,
         mAxiWriteSlaves     => locAxilWriteSlaves,
         mAxiReadMasters     => locAxilReadMasters,
         mAxiReadSlaves      => locAxilReadSlaves);

   -------------------------------------------------------------------------------------------------
   -- Put version info on AXI Bus
   -------------------------------------------------------------------------------------------------
   AxiVersion_1 : entity work.AxiVersion
      generic map (
         TPD_G            => TPD_G,
         EN_DEVICE_DNA_G  => true,
         EN_DS2411_G      => true,
         EN_ICAP_G        => true,
         AUTO_RELOAD_EN_G => false)
      port map (
         axiClk                                           => axilClk,
         axiRst                                           => axilClkRst,
         axiReadMaster                                    => locAxilReadMasters(VERSION_AXI_INDEX_C),
         axiReadSlave                                     => locAxilReadSlaves(VERSION_AXI_INDEX_C),
         axiWriteMaster                                   => locAxilWriteMasters(VERSION_AXI_INDEX_C),
         axiWriteSlave                                    => locAxilWriteSlaves(VERSION_AXI_INDEX_C),
         masterReset                                      => masterReset,
         userValues(0)(AXIS_FIFO_ADDR_WIDTH_G-1 downto 0) => axisFifoPauseThreshold);



end architecture rtl;
