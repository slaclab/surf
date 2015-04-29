-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : DevBoard.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-08-22
-- Last update: 2015-04-29
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
use work.Gtx7CfgPkg.all;
use work.SsiPkg.all;

entity DevBoard is
   
   generic (
      TPD_G                  : time    := 1 ns;
      SIMULATION_G           : boolean := false;
      -- PGP Config
      PGP_REFCLK_FREQ_G      : real    := 125.0E6;
      PGP_LINE_RATE_G        : real    := 3.125E9;
      -- AXIL Config
      AXIL_CLK_FREQ_G        : real    := 125.0E6;
      -- AXIS Config
      AXIS_CLK_FREQ_G        : real    := 185.0E6;
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
--      fpgaDevClkbP : in sl;             -- LA00_P_CC - FMC G6
--      fpgaDevClkbN : in sl;             -- LA00_N_CC - FMC G7
      
      -- JESD synchronisation timing signal (Used in subclass 1 mode)
      -- has to meet setup and hold times of JESD devClk
      -- periodic (period has to be multiple of LMFC clock)
      -- single   (another pulse has to be generated if re-sync needed)      
      fpgaSysRefP  : in sl;             -- LA03_P - FMC G9
      fpgaSysRefN  : in sl;             -- LA04_N - FMC G10

      -- Signals to ADC (if clock manager not used)
--      adcDevClkP : out sl;              -- LA01_P_CC - FMC D7
--      adcDevClkN : out sl;              -- LA01_N_CC - FMC D8
--      adcSysRefP : out sl;              -- LA05_P_CC - FMC D11
--      adcSysRefN : out sl;              -- LA05_N_CC - FMC D12

      -- JESD MGT signals
      adcGtTxP : out slv(3 downto 0);   -- FMC HPC DP[3:0]
      adcGtTxN : out slv(3 downto 0);
      adcGtRxP : in  slv(3 downto 0);
      adcGtRxN : in  slv(3 downto 0);

      -- JESD receiver requesting sync (Used in all subclass modes)
      -- '1' - synchronisation OK
      -- '0' - synchronisation Not OK - synchronisation request
      syncbP : out sl;                  -- LA08_P - FMC G12
      syncbN : out sl;                  -- LA08_N - FMC G13

      -- Adc OVR/trigger signals
--      ovraTrigRdy : in sl;              -- LA25_P - FMC G27
--      ovrbTrigger : in sl;              -- LA26_P - FMC D26

      -- ADC SPI config interface
--      spiSclk : out sl;                 -- FMC H37
--      spiSdi  : out sl;                 -- FMC G36
--      spiSdo  : in  sl;                 -- FMC G37
--      spiCsL  : out sl;                 -- FMC H38

      -- Onboard LEDs
      leds : out slv(3 downto 0));


end entity DevBoard;

architecture rtl of DevBoard is
   -------------------------------------------------------------------------------------------------
   -- PGP constants
   -------------------------------------------------------------------------------------------------
   constant PGP_REFCLK_PERIOD_C : real := 1.0 / PGP_REFCLK_FREQ_G;
   constant PGP_CLK_FREQ_C      : real := PGP_LINE_RATE_G / 20.0;

   -------------------------------------------------------------------------------------------------
   -- JESD constants and signals
   -------------------------------------------------------------------------------------------------
   constant REFCLK_FREQUENCY_C : real     := 370.0E6;
   constant LINE_RATE_C        : real     := 7.40E9;
   constant DEVCLK_PERIOD_C    : real     := 1.0/(LINE_RATE_C/40.0);
   
   constant AXI_PACKET_SIZE_C  : positive := 2**8;
   constant F_C                : positive := 2;
   constant K_C                : positive := 32;
   constant L_C                : positive := 2;
   constant GT_WORD_SIZE_C     : positive := 4; -- NOTE: This constant has to be the same as in the Jesd204bPkg
   constant SUB_CLASS_C        : positive := 1;
   
   
   signal  s_sysRef : sl;
   signal  s_nsync  : sl;

   -- QPLL config constants
   constant QPLL_CONFIG_C     : Gtx7QPllCfgType := getGtx7QPllCfg(REFCLK_FREQUENCY_C, LINE_RATE_C);   

   -- QPLL
   signal  gtCPllRefClk  : sl; 
   signal  gtCPllLock    : sl; 
   signal  qPllOutClk    : sl; 
   signal  qPllOutRefClk : sl; 
   signal  qPllLock      : sl; 
   signal  qPllRefClkLost: sl; 
   signal  qPllReset     : slv(L_C-1 downto 0); 
   signal  gtQPllReset   : sl;
   

   -------------------------------------------------------------------------------------------------
   -- Clock Signals
   -------------------------------------------------------------------------------------------------
   signal pgpRefClk  : sl;
   signal pgpRefClkG : sl;
   signal axilClk    : sl;
   signal axilClkRst : sl;
   signal pgpClk     : sl;
   signal pgpClkRst  : sl;
   signal pgpMmcmRst : sl;

   signal jesdRefClkDiv2 : sl;
   signal jesdRefClk     : sl;
   signal jesdRefClkG    : sl;
   signal jesdClk        : sl;
   signal jesdClkRst     : sl;
   signal jesdMmcmRst    : sl;

   signal powerOnReset : sl;
   signal masterReset  : sl;
   signal fpgaReload   : sl;
  

   -------------------------------------------------------------------------------------------------
   -- AXI Lite Config and Signals
   -------------------------------------------------------------------------------------------------
   constant NUM_AXI_MASTERS_C : natural := 2;

   constant VERSION_AXIL_INDEX_C : natural              := 0;
   constant JESD_AXIL_INDEX_C    : natural              := 1;

   constant VERSION_AXIL_BASE_ADDR_C : slv(31 downto 0)   := X"00000000";
   constant JESD_AXIL_BASE_ADDR_C    : slv(31 downto 0)   := X"00010000";

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
   constant JESD_SSI_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(4, TKEEP_COMP_C);

   signal axisTxMasters : AxiStreamMasterArray(1 downto 0);
   signal axisTxSlaves  : AxiStreamSlaveArray(1 downto 0);
   signal axisTxCtrl    : AxiStreamCtrlArray(1 downto 0);

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
   pgpMmcmRst <= masterReset or powerOnReset;

   ClockManager7_PGP : entity work.ClockManager7
      generic map (
         TPD_G              => TPD_G,
         TYPE_G             => "MMCM",
         INPUT_BUFG_G       => false,
         FB_BUFG_G          => true,
         NUM_CLOCKS_G       => 2,
         BANDWIDTH_G        => "OPTIMIZED",
         CLKIN_PERIOD_G     => PGP_REFCLK_PERIOD_C*1.0E9,
         DIVCLK_DIVIDE_G    => 1,
         CLKFBOUT_MULT_F_G  => 7.5,
         CLKOUT0_DIVIDE_F_G => 7.5,
         CLKOUT0_RST_HOLD_G => 16,
         CLKOUT1_DIVIDE_G   => 6,
         CLKOUT1_RST_HOLD_G => 16)
      port map (
         clkIn     => pgpRefClkG,
         rstIn     => pgpMmcmRst,
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
         TPD_G                  => TPD_G,
         SIMULATION_G           => SIMULATION_G,
         PGP_REFCLK_FREQ_G      => PGP_REFCLK_FREQ_G,
         PGP_LINE_RATE_G        => PGP_LINE_RATE_G,
         AXIL_CLK_FREQ_G        => AXIL_CLK_FREQ_G,
         AXIS_CLK_FREQ_G        => AXIS_CLK_FREQ_G,
         AXIS_FIFO_ADDR_WIDTH_G => AXIS_FIFO_ADDR_WIDTH_G,
         AXIS_CONFIG_G          => JESD_SSI_CONFIG_C)
      port map (
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
         EN_DEVICE_DNA_G  => true,
         EN_DS2411_G      => false,
         EN_ICAP_G        => true,
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
   IBUFDS_GTE2_FPGADEVCLKA : IBUFDS_GTE2
      port map (
         I     => fpgaDevClkaP,
         IB    => fpgaDevClkaN,
         CEB   => '0',
         ODIV2 => jesdRefClkDiv2,
         O     => jesdRefClk          
   );
     
   JESDREFCLK_BUFG : BUFG
      port map (
         I => jesdRefClkDiv2,
         O => jesdRefClkG);

   jesdMmcmRst <= powerOnReset or masterReset;

   -- ClockManager7_JESD : entity work.ClockManager7
      -- generic map (
         -- TPD_G              => TPD_G,
         -- TYPE_G             => "MMCM",
         -- INPUT_BUFG_G       => false,
         -- FB_BUFG_G          => true,
         -- NUM_CLOCKS_G       => 1,
         -- BANDWIDTH_G        => "OPTIMIZED",
         -- CLKIN_PERIOD_G     => DEVCLK_PERIOD_C*1.0E9,
         -- DIVCLK_DIVIDE_G    => 1,
         -- CLKFBOUT_MULT_F_G  => 5.375,
         -- CLKOUT0_DIVIDE_F_G => 5.375,
         -- CLKOUT0_RST_HOLD_G => 16)
      -- port map (
         -- clkIn     => jesdRefClkG,
         -- rstIn     => jesdMmcmRst,
         -- clkOut(0) => jesdClk,
         -- rstOut(0) => jesdClkRst);
         
   jesdClk    <= pgpClk;
   jesdClkRst <= pgpClkRst;
    
   -------------------------------------------------------------------------------------------------
   -- QPLL for JESD MGTs
   ------------------------------------------------------------------------------------------------- 
   Gtx7QuadPll_INST: entity work.Gtx7QuadPll
   generic map (
      TPD_G               => TPD_G,
      QPLL_CFG_G          => x"0680181", -- TODO check
      QPLL_REFCLK_SEL_G   => "001",      -- Should be ok
      QPLL_FBDIV_G        => QPLL_CONFIG_C.QPLL_FBDIV_G,      -- use getGtx7QPllCfg to set
      QPLL_FBDIV_RATIO_G  => QPLL_CONFIG_C.QPLL_FBDIV_RATIO_G,-- use getGtx7QPllCfg to set
      QPLL_REFCLK_DIV_G   => QPLL_CONFIG_C.QPLL_REFCLK_DIV_G  -- use getGtx7QPllCfg to set
   )
   port map (
      qPllRefClk     => jesdRefClk, -- Reference clock directly from the output
      qPllOutClk     => qPllOutClk,
      qPllOutRefClk  => qPllOutRefClk,
      qPllLock       => qPllLock,
      qPllLockDetClk => '0',
      qPllRefClkLost => qPllRefClkLost,
      qPllPowerDown  => '0',
      qPllReset      => qPllReset(0)
   );      
  
   -------------------------------------------------------------------------------------------------
   -- JESD block
   -------------------------------------------------------------------------------------------------   
   Jesd204bGtx7_INST: entity work.Jesd204bGtx7
   generic map (
      TPD_G                 => TPD_G,
      
      -- CPLL Configurations (not used)
      CPLL_FBDIV_G          => 4,  -- use getGtx7CPllCfg to set
      CPLL_FBDIV_45_G       => 4,  -- use getGtx7CPllCfg to set
      CPLL_REFCLK_DIV_G     => 1,  -- use getGtx7CPllCfg to set
      
      RXOUT_DIV_G           => QPLL_CONFIG_C.OUT_DIV_G,  -- use getGtx7QPllCfg to set
      RX_CLK25_DIV_G        => QPLL_CONFIG_C.CLK25_DIV_G,-- use getGtx7QPllCfg to set,
                                                       
      -- Configure PLL sources
      TX_PLL_G              =>  "QPLL", -- "QPLL" or "CPLL"
      RX_PLL_G              =>  "QPLL", -- "QPLL" or "CPLL"
      
      -- AXI
      AXI_ERROR_RESP_G      => AXI_RESP_SLVERR_C,
      AXI_PACKET_SIZE_G     => AXI_PACKET_SIZE_C,
      
      -- JESD
      F_G                => F_C,
      K_G                => K_C,
      L_G                => L_C,
      GT_WORD_SIZE_G     => GT_WORD_SIZE_C,
      SUB_CLASS_G        => SUB_CLASS_C
   )
   port map (
      
      stableClk         => jesdRefClkG, -- Stable because it is never reset
      devClk_i          => jesdClk, -- both same
      devClk2_i         => jesdClk, -- both same
      devRst_i          => jesdClkRst,
      
      qPllRefClkIn      => qPllOutRefClk,
      qPllClkIn         => qPllOutClk,
      qPllLockIn        => qPllLock,
      qPllRefClkLostIn  => qPllRefClkLost,
      qPllResetOut      => qPllReset, 

      gtTxP             => adcGtTxP(1 downto 0),
      gtTxN             => adcGtTxN(1 downto 0),
      gtRxP             => adcGtRxP(1 downto 0),
      gtRxN             => adcGtRxN(1 downto 0),
   
      axiClk            => axilClk,
      axiRst            => axilClkRst,
      axilReadMaster    => locAxilReadMasters(JESD_AXIL_INDEX_C),
      axilReadSlave     => locAxilReadSlaves(JESD_AXIL_INDEX_C),
      axilWriteMaster   => locAxilWriteMasters(JESD_AXIL_INDEX_C),
      axilWriteSlave    => locAxilWriteSlaves(JESD_AXIL_INDEX_C),  
      txAxisMasterArr   => axisTxMasters,
      txCtrlArr         => axisTxCtrl,
      sysRef_i          => s_sysRef,
      nSync_o           => s_nSync
   );
   
   ----------------------------------------------------------------
   -- Put sync and sysref on differential io buffer
   ----------------------------------------------------------------
   IBUFDS_rsysref_inst : IBUFDS
   generic map (
      DIFF_TERM => FALSE,
      IBUF_LOW_PWR => TRUE,
      IOSTANDARD => "DEFAULT")
   port map (
      I  => fpgaSysRefP,
      IB => fpgaSysRefN,
      O  => s_sysRef
   );
   
   OBUFDS_nsync_inst : OBUFDS
   generic map (
      IOSTANDARD => "DEFAULT",
      SLEW => "SLOW"
   )
   port map (
      I =>  s_nSync,
      O =>  syncbP, 
      OB => syncbN
   );

end architecture rtl;
