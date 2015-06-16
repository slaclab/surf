-------------------------------------------------------------------------------
-- Title      : Development board for JESD DAC test
-------------------------------------------------------------------------------
-- File       : JesdDacKcu105.vhd
-- Author     : Benjamin Reese <bareese@slac.stanford.edu>
--              Uros Legat <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory (Cosylab)
-- Created    : 2015-04-10
-- Last update: 2015-06-11
-- Platform   : Xilinx Kcu105 Development platform
--              TI DAC38J82EVM
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--    Outputs reference clock of 370MHz
--     - on FMC ADC LVDS output (to optionally provide reference from FPGA)
--     - on GPIO LVDS output (to optionally provide reference from FPGA)
--     - on USER Single ended output (to optionally provide reference from FPGA to LMK chip)
--    Configured for 4-byte operation: GT_WORD_SIZE_C=4
--    To configure for 2-byte operation: GT_WORD_SIZE_C=2, adjust LANE rate, GTX parameters, JESD clock MGMM 
--    LED indicators:
--    - LED0 - Axi Lite clock HB
--    - LED1 - PGP clock HB
--    - LED2 - PGP Rx link ready
--    - LED3 - PGP Tx link ready
--    - LED4 - JESD clock HB
--    - LED5 - JESD QPLL locked
--    - LED6 - JESD nSync signal
--    - LED7 - JESD Data valid
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

library UNISIM;
use UNISIM.VCOMPONENTS.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.Gtx7CfgPkg.all;
use work.jesd204bpkg.all;
use work.SsiPkg.all;

entity JesdDacKcu105 is
   
   generic (
      TPD_G                  : time    := 1 ns;
      SIMULATION_G           : boolean := false;
      -- PGP Config
      PGP_REFCLK_FREQ_G      : real    := 156.25E6;
      PGP_LINE_RATE_G        : real    := 3.125E9;
      -- AXIL Config
      AXIL_CLK_FREQ_G        : real    := 156.25E6;
      -- AXIS Config
      AXIS_CLK_FREQ_G        : real    := 185.0E6;
      AXIS_FIFO_ADDR_WIDTH_G : integer := 9;

      --JESD configuration
      -----------------------------------------------------
      -- GTX disconnected 
      SIM_G        : boolean := false;
      -- TRUE  Internal SYSREF
      -- FALSE External SYSREF
      SYSREF_GEN_G : boolean := false;

      REFCLK_FREQUENCY_G : real := 370.00E6;
      LINE_RATE_G        : real := 7.40E9;

      -- The JESD module supports values: 1,2,4(four byte GT word only)
      F_G : positive := 2;
      -- K*F/GT_WORD_SIZE_C has to be integer     
      K_G : positive := 32;
      -- Number of serial lanes: 1 to 16    
      L_G : positive := 2);
   port (
      sysClk125P : in sl;
      sysClk125N : in sl;

      -- PGP MGT signals
      pgpRefClkSel : out sl := '0';
      pgpRefClkP   : in  sl;
      pgpRefClkN   : in  sl;
      pgpGtRxN     : in  sl;            -- SFP+ 
      pgpGtRxP     : in  sl;
      pgpGtTxN     : out sl;
      pgpGtTxP     : out sl;

      -- FMC Signals -- 
      -- Signals from clock manager
      fpgaDevClkaP : in sl;             -- GBT_CLK_0_P - FMC D3
      fpgaDevClkaN : in sl;             -- GBT_CLK_0_N - FMC D4
--      fpgaDevClkbP : in sl;             -- LA00_P_CC - FMC G6
--      fpgaDevClkbN : in sl;             -- LA00_N_CC - FMC G7

      -- JESD synchronisation timing signal (Used in subclass 1 mode)
      -- has to meet setup and hold times of JESD devClk
      -- periodic (period has to be multiple of LMFC clock)
      -- single   (another pulse has to be generated if re-sync needed)      
      fpgaSysRefP : in sl;              -- LA03_P - FMC G9
      fpgaSysRefN : in sl;              -- LA04_N - FMC G10

      -- Signals to ADC (if clock manager not used)
--      adcDevClkP : out sl;              -- LA01_P_CC - FMC D7
--      adcDevClkN : out sl;              -- LA01_N_CC - FMC D8
--      adcSysRefP : out sl;              -- LA05_P_CC - FMC D11
--      adcSysRefN : out sl;              -- LA05_N_CC - FMC D12

      -- JESD MGT signals
      adcGtTxP : out slv(1 downto 0);   -- FMC HPC DP[3:0]
      adcGtTxN : out slv(1 downto 0);
      adcGtRxP : in  slv(1 downto 0);
      adcGtRxN : in  slv(1 downto 0);

      -- JESD receiver requesting sync (Used in all subclass modes)
      -- '1' - synchronisation OK
      -- '0' - synchronisation Not OK - synchronisation request
      syncbP : in sl;                   -- LA08_P - FMC G12
      syncbN : in sl;                   -- LA08_N - FMC G13

      -- Adc OVR/trigger signals
--      ovraTrigRdy : in sl;              -- LA25_P - FMC G27
--      ovrbTrigger : in sl;              -- LA26_P - FMC D26

      -- ADC SPI config interface
--      spiSclk : out sl;                 -- FMC H37
--      spiSdi  : out sl;                 -- FMC G36
--      spiSdo  : in  sl;                 -- FMC G37
--      spiCsL  : out sl;                 -- FMC H38

      -- Onboard LEDs
      leds : out slv(7 downto 0);

      sysRef : out sl;

      -- Out reference clock or debug clock
      usrClk  : out sl;
      gpioClk : out sl
      );
end entity JesdDacKcu105;

architecture rtl of JesdDacKcu105 is
   -------------------------------------------------------------------------------------------------
   -- PGP constants
   -------------------------------------------------------------------------------------------------
   constant PGP_REFCLK_PERIOD_C : real := 1.0 / PGP_REFCLK_FREQ_G;
   constant PGP_CLK_FREQ_C      : real := PGP_LINE_RATE_G / 20.0;

   -------------------------------------------------------------------------------------------------
   -- JESD constants and signals
   -------------------------------------------------------------------------------------------------
   -- constant REFCLK_FREQUENCY_C : real     := 370.00E6; 
   -- constant REFCLK_FREQUENCY_C : real     := 368.64E6; 
   -- constant REFCLK_FREQUENCY_C : real     := 125.0E6;
   -- constant LINE_RATE_C        : real     := 7.3728E9;
   -- constant LINE_RATE_C        : real     := 7.40E9;
   -- constant LINE_RATE_C        : real     := 2.50E9;
   constant DEVCLK_PERIOD_C : real := real(GT_WORD_SIZE_C)*10.0/(LINE_RATE_G);

   signal s_sysRef : sl;
   signal s_nsync  : sl;


   -------------------------------------------------------------------------------------------------
   -- Clock Signals
   -------------------------------------------------------------------------------------------------
   signal sysClk125  : sl;
   signal sysClk125G : sl;
   signal sysClk125Rst : sl;

   signal pgpRefClk     : sl;
   signal pgpRefClkDiv2 : sl;
   signal pgpRefClkG    : sl;
   signal axilClk       : sl;
   signal axilClkRst    : sl;
   signal pgpClk        : sl;
   signal pgpClkRst     : sl;
   signal pgpMmcmRst    : sl;

   signal jesdRefClk     : sl;
   signal jesdRefClkDiv2 : sl;
   signal jesdRefClkG    : sl;
   signal jesdClk        : sl;
   signal jesdClkRst     : sl;
   signal jesdMmcmRst    : sl;

   signal powerOnReset : sl;
   signal masterReset  : sl;
   signal fpgaReload   : sl;

   signal qPllLock : sl;
   -------------------------------------------------------------------------------------------------
   -- AXI Lite Config and Signals
   -------------------------------------------------------------------------------------------------
   constant NUM_AXI_MASTERS_C : natural := 2;

   constant VERSION_AXIL_INDEX_C : natural := 0;
   constant JESD_AXIL_INDEX_C    : natural := 1;

   constant VERSION_AXIL_BASE_ADDR_C : slv(31 downto 0) := X"00000000";
   constant JESD_AXIL_BASE_ADDR_C    : slv(31 downto 0) := X"00020000";

   constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := (
      VERSION_AXIL_INDEX_C => (
         baseAddr          => VERSION_AXIL_BASE_ADDR_C,
         addrBits          => 12,
         connectivity      => X"0001"),
      JESD_AXIL_INDEX_C    => (
         baseAddr          => JESD_AXIL_BASE_ADDR_C,
         addrBits          => 12,
         connectivity      => X"0001"));

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
   constant JESD_SSI_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(GT_WORD_SIZE_C, TKEEP_COMP_C);

   signal axisTxMasters : AxiStreamMasterArray(1 downto 0);
   signal axisTxSlaves  : AxiStreamSlaveArray(1 downto 0);
   signal axisTxCtrl    : AxiStreamCtrlArray(1 downto 0);

   -------------------------------------------------------------------------------------------------
   -- PGP Signals and Virtual Channels
   -------------------------------------------------------------------------------------------------
   signal s_usrClk : sl;
   signal s_usrRst : sl;

   -------------------------------------------------------------------------------------------------
   -- Debug
   -------------------------------------------------------------------------------------------------   
   signal s_syncAllLED  : sl;
   signal s_validAllLED : sl;

begin

   -------------------------------------------------------------------------------------------------
   -- System clock
   -------------------------------------------------------------------------------------------------
   IBUFDS_SYSCLK125 : IBUFDS
      port map (
         I  => sysClk125P,
         IB => sysClk125N,
         O  => sysClk125);

   BUFG_SYSCLK125 : BUFG
      port map (
         I => sysClk125,
         O => sysClk125G);

   PwrUpRst_1 : entity work.PwrUpRst
      generic map (
         TPD_G          => TPD_G,
         SIM_SPEEDUP_G  => SIMULATION_G,
         IN_POLARITY_G  => '1',
         OUT_POLARITY_G => '1')
      port map (
         clk    => sysClk125G,
         rstOut => powerOnReset);

   sysClk125Rst <= masterReset or powerOnReset;

   -------------------------------------------------------------------------------------------------
   -- ADC EVM Out reference clock (10.00 MHz)
   -------------------------------------------------------------------------------------------------
      ClockManager7_OUT : entity work.ClockManager7
      generic map (
         TPD_G              => TPD_G,
         TYPE_G             => "MMCM",
         INPUT_BUFG_G       => false,
         FB_BUFG_G          => true,
         NUM_CLOCKS_G       => 1,
         BANDWIDTH_G        => "HIGH",
         CLKIN_PERIOD_G     => 8.0,      --(10.0MHz)  (156.25MHz)(368.64MHz) (61.44 MHz) (370MHz)
         DIVCLK_DIVIDE_G    => 1,        --1,         --4,         --6,        --5,        --5,
         CLKFBOUT_MULT_F_G  => 8.000,    --8.0,       --55,        --50.875,   --47.000,   --37.000,
         CLKOUT0_DIVIDE_F_G => 100.0,    --100.0,     --11,        --2.875,    --19.125,   --2.5
         CLKOUT0_RST_HOLD_G => 16)
      port map (
         clkIn     => sysClk125G,
         rstIn     => '0',
         clkOut(0) => s_usrClk,
         rstOut(0) => s_usrRst);

   -------------------------------------------------------------------------------------------------
   -- PGP Refclk
   -------------------------------------------------------------------------------------------------
   PGPREFCLK_IBUFDS_GTE3 : IBUFDS_GTE3
      port map (
         I     => pgpRefClkP,
         IB    => pgpRefClkN,
         CEB   => '0',
         ODIV2 => pgpRefClkDiv2,
         O     => pgpRefClk);

   PGPREFCLK_BUFG_GT : BUFG_GT
      port map (
         I       => pgpRefClkDiv2,
         CE      => '1',
         CLR     => '0',
         CEMASK  => '1',
         CLRMASK => '1',
         DIV     => "000",              -- GT_WORD_SIZE_C=4
         O       => pgpRefClkG);

   pgpMmcmRst <= powerOnReset or masterReset;

   ClockManager7_PGP : entity work.ClockManager7
      generic map (
         TPD_G              => TPD_G,
         TYPE_G             => "MMCM",
         INPUT_BUFG_G       => false,
         FB_BUFG_G          => true,
         NUM_CLOCKS_G       => 1,
         BANDWIDTH_G        => "OPTIMIZED",
         CLKIN_PERIOD_G     => PGP_REFCLK_PERIOD_C*1.0E9,
         DIVCLK_DIVIDE_G    => 1,
         CLKFBOUT_MULT_F_G  => 6.375,
         CLKOUT0_DIVIDE_F_G => 6.375,
         CLKOUT0_RST_HOLD_G => 16)
      port map (
         clkIn     => pgpRefClkG,
         rstIn     => pgpMmcmRst,
         clkOut(0) => pgpClk,
         rstOut(0) => pgpClkRst);

   -- Use pgp clock for axil clock
   axilClk    <= pgpClk;
   axilClkRst <= pgpClkRst;

   -------------------------------------------------------------------------------------------------
   -- PGP Interface 
   -------------------------------------------------------------------------------------------------
   PgpFrontEnd_1 : entity work.PgpFrontEnd
      generic map (
         TPD_G                  => TPD_G,
         SIMULATION_G           => SIMULATION_G,
         PGP_REFCLK_FREQ_G      => PGP_REFCLK_FREQ_G,
         PGP_LINE_RATE_G        => PGP_LINE_RATE_G,
         AXIL_CLK_FREQ_G        => AXIL_CLK_FREQ_G,
         AXIS_CLK_FREQ_G        => AXIS_CLK_FREQ_G,
         AXIS_FIFO_ADDR_WIDTH_G => AXIS_FIFO_ADDR_WIDTH_G,
         AXIS_CONFIG_G          => JESD_SSI_CONFIG_C)
      port map (
         stableClk       => sysClk125G,
         pgpRefClk       => pgpRefClk,
         pgpClk          => pgpClk,
         pgpClkRst       => pgpClkRst,
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
         axisClk         => jesdClk,
         axisClkRst      => jesdClkRst,
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
         EN_DEVICE_DNA_G  => false,
         EN_DS2411_G      => false,
         EN_ICAP_G        => false,
         AUTO_RELOAD_EN_G => false)
      port map (
         axiClk         => axilClk,
         axiRst         => axilClkRst,
         axiReadMaster  => locAxilReadMasters(VERSION_AXIL_INDEX_C),
         axiReadSlave   => locAxilReadSlaves(VERSION_AXIL_INDEX_C),
         axiWriteMaster => locAxilWriteMasters(VERSION_AXIL_INDEX_C),
         axiWriteSlave  => locAxilWriteSlaves(VERSION_AXIL_INDEX_C),
         masterReset    => masterReset);


   -------------------------------------------------------------------------------------------------
   -- JESD Clocking
   -------------------------------------------------------------------------------------------------
   IBUFDS_GTE2_FPGADEVCLKA : IBUFDS_GTE3
      port map (
         I     => fpgaDevClkaP,
         IB    => fpgaDevClkaN,
         CEB   => '0',
         ODIV2 => jesdRefClkDiv2,
         O     => jesdRefClk
         ); 

   JESDREFCLK_BUFG_GT : BUFG_GT
      port map (
         I       => jesdRefClkDiv2,
         CE      => '1',
         CLR     => '0',
         CEMASK  => '1',
         CLRMASK => '1',

         DIV => "001",                  -- GT_WORD_SIZE_C=4
         --DIV    => "000",  -- GT_WORD_SIZE_C=2
         O   => jesdRefClkG);

   jesdMmcmRst <= powerOnReset or masterReset;

   ClockManager7_JESD : entity work.ClockManager7
      generic map (
         TPD_G              => TPD_G,
         TYPE_G             => "MMCM",
         INPUT_BUFG_G       => false,
         FB_BUFG_G          => true,
         NUM_CLOCKS_G       => 1,
         BANDWIDTH_G        => "OPTIMIZED",
         CLKIN_PERIOD_G     => DEVCLK_PERIOD_C*1.0E9,
         DIVCLK_DIVIDE_G    => 1,
         CLKFBOUT_MULT_F_G  => 5.375,   --2.6875,
         CLKOUT0_DIVIDE_F_G => 5.375,
         CLKOUT0_RST_HOLD_G => 16)
      port map (
         clkIn     => jesdRefClkG,
         rstIn     => jesdMmcmRst,
         clkOut(0) => jesdClk,
         rstOut(0) => jesdClkRst);
   
   -------------------------------------------------------------------------------------------------
   -- JESD Tx block
   -------------------------------------------------------------------------------------------------   
   Jesd204bTxGthUltra_INST : entity work.Jesd204bTxGthUltra
      generic map (
         TPD_G            => TPD_G,
         SYSREF_GEN_G     => SYSREF_GEN_G,
         SIM_G            => SIM_G,
         AXI_ERROR_RESP_G => AXI_RESP_SLVERR_C,
         F_G              => F_G,
         K_G              => K_G,
         L_G              => L_G)
      port map (
         stableClk => sysClk125,      -- Stable because it is never reset (jesdRefClk/2)
         refClk    => jesdRefClk,
         gtTxP(0)  => adcGtTxP(0),
         gtTxP(1)  => adcGtTxP(1),
         gtTxN(0)  => adcGtTxN(0),
         gtTxN(1)  => adcGtTxN(1),
         gtRxP(0)  => adcGtRxP(0),
         gtRxP(1)  => adcGtRxP(1),
         gtRxN(0)  => adcGtRxN(0),
         gtRxN(1)  => adcGtRxN(1),

         devClk_i  => jesdClk,
         devClk2_i => jesdClk,
         devRst_i  => jesdClkRst,
         axiClk    => axilClk,
         axiRst    => axilClkRst,

         axilReadMasterTx  => locAxilReadMasters(JESD_AXIL_INDEX_C),
         axilReadSlaveTx   => locAxilReadSlaves(JESD_AXIL_INDEX_C),
         axilWriteMasterTx => locAxilWriteMasters(JESD_AXIL_INDEX_C),
         axilWriteSlaveTx  => locAxilWriteSlaves(JESD_AXIL_INDEX_C),
         --Currently no AXI stream input
         rxAxisMasterArr_i => (L_G-1 downto 0 => AXI_STREAM_MASTER_INIT_C),
         rxAxisSlaveArr_o  => open,

         -- External sample data input
         extSampleDataArray_i => (L_G-1 downto 0 => (RX_STAT_WIDTH_C-1 downto 0 => '0')),

         leds_o(0)  => s_syncAllLED,    -- (0) Sync
         leds_o(1)  => s_validAllLED,   -- (1) Data_valid
         qPllLock_o => qPllLock,

         sysRef_i => s_sysRef,
         sysRef_o => open,              -- TODO Add internal sysref GEN output          
         nSync_i  => s_nSync);

   ----------------------------------------------------------------
   -- Get sync and sysref from differential io buffer
   ----------------------------------------------------------------
   IBUFDS_rsysref_inst : IBUFDS
      generic map (
         DIFF_TERM    => false,
         IBUF_LOW_PWR => true,
         IOSTANDARD   => "DEFAULT")
      port map (
         I  => fpgaSysRefP,
         IB => fpgaSysRefN,
         O  => s_sysRef
         );

   sysRef <= s_sysRef;

   IBUFDS_nsync_inst : IBUFDS
      generic map (
         DIFF_TERM    => false,
         IBUF_LOW_PWR => true,
         IOSTANDARD   => "DEFAULT")
      port map (
         O  => s_nSync,
         I  => syncbP,
         IB => syncbN
         );

   -------------------------------------------------------------------------------------------------
   -- LED Test Outputs
   -------------------------------------------------------------------------------------------------
   Heartbeat_pgpClk : entity work.Heartbeat
      generic map (
         TPD_G        => TPD_G,
         PERIOD_IN_G  => 6.4E-9,
         PERIOD_OUT_G => 1.0)
      port map (
         clk => pgpClk,
         o   => leds(0));

   Heartbeat_jesdclk : entity work.Heartbeat
      generic map (
         TPD_G        => TPD_G,
         PERIOD_IN_G  => 5.425E-9,
         PERIOD_OUT_G => 1.0)
      port map (
         clk => jesdClk,
         o   => leds(1));

   leds(5) <= qPllLock;
   leds(6) <= s_syncAllLED;
   leds(7) <= s_validAllLED;

   -- Output user clock for single ended reference  
   UserClkBufSingle_INST : entity work.ClkOutBufSingle
      generic map (
         XIL_DEVICE_G   => "ULTRASCALE",
         RST_POLARITY_G => '1',
         INVERT_G       => false)
      port map (
         clkIn  => s_usrClk,
         rstIn  => s_usrRst,
         clkOut => usrClk);

   -- Output JESD clk for debug
   GPioClkBufSingle_INST : entity work.ClkOutBufSingle
      generic map (
         XIL_DEVICE_G   => "ULTRASCALE",
         RST_POLARITY_G => '1',
         INVERT_G       => false)
      port map (
         clkIn  => s_usrClk,
         rstIn  => s_usrClk,
         clkOut => gpioClk);

end architecture rtl;
