-------------------------------------------------------------------------------
-- Title      : Development board for JESD ADC/DAC demo
-------------------------------------------------------------------------------
-- File       : AtcaDemoBoard.vhd
-- Author     : Benjamin Reese <bareese@slac.stanford.edu>
--              Uros Legat <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory (Cosylab)
-- Created    : 2015-04-10
-- Last update: 2015-05-29
-- Platform   : LCLS2 Common Plaform Carrier
--              AMC ADC/Analog demo
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
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

entity AtcaDemoBoard is
   
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
      -- Test tx module instead of GTX
      TEST_G             : boolean := false;
      -- TRUE  Internal SYSREF
      -- FALSE External SYSREF
      SYSREF_GEN_G       : boolean := false;      

      LINE_RATE_G        : real     := 7.40E9;
      
      -- The JESD module supports values: 1,2,4(four byte GT word only)
      F_G                : positive := 2;
      -- K*F/GT_WORD_SIZE_C has to be integer     
      K_G                : positive := 32;
      -- Number of serial lanes: 1 to 16    
      L_RX_G                : positive := 6;
      L_AXI_G               : positive := 2
   );
   port (
      -- PGP MGT signals (SFP)
      pgpRefClkSel : out sl := '0';
      pgpRefClkP   : in  sl;
      pgpRefClkN   : in  sl;
      pgpGtRxN     : in  sl;
      pgpGtRxP     : in  sl;
      pgpGtTxN     : out sl;
      pgpGtTxP     : out sl;

      -- FMC Signals -- 
      -------------------------------------------------------------------
      -- Signals from clock manager
      fpgaDevClkaP : in sl;             
      fpgaDevClkaN : in sl;             
      
      -- JESD synchronisation timing signal (Used in subclass 1 mode)
      -- has to meet setup and hold times of JESD devClk
      -- periodic (period has to be multiple of LMFC clock)
      -- single   (another pulse has to be generated if re-sync needed)      
      fpgaSysRefP  : in sl;            
      fpgaSysRefN  : in sl;            

      -- JESD MGT signals
      adcGtTxP : out slv(5 downto 0);    
      adcGtTxN : out slv(5 downto 0);
      adcGtRxP : in  slv(5 downto 0);
      adcGtRxN : in  slv(5 downto 0);

      -- JESD receiver requesting sync (Used in all subclass modes)
      -- '1' - synchronisation OK
      -- '0' - synchronisation Not OK - synchronisation request
      syncb1P : out sl;                  
      syncb1N : out sl;
      syncb2P : out sl;                  
      syncb2N : out sl;
      syncb3P : out sl;                  
      syncb3N : out sl;     

      -- ADC SPI config interface
--      spiSclk : out sl;
--      spiSdi  : out sl;
--      spiSdo  : in  sl;
--      spiCsL  : out sl;
         
      -- External HW Acquisition trigger
      trigHW: in sl;
      
      -- Debug Signals -- 
      -------------------------------------------------------------------
      -- Onboard LEDs
      leds : out slv(7 downto 0);
          
      -- Out JESD clock 185MHz
      gpioClk    : out sl;
      
      -- Sysref output pin      
      sysrefDbg  : out sl;
      
      -- Digital square wave signal for deterministic latency check (Adjustable by setting the threshold registers)      
      rePulseDbg : out slv(1 downto 0) 
      
   );
end entity AtcaDemoBoard;

architecture rtl of AtcaDemoBoard is
   -------------------------------------------------------------------------------------------------
   -- PGP constants
   -------------------------------------------------------------------------------------------------
   constant PGP_REFCLK_PERIOD_C : real := 1.0 / PGP_REFCLK_FREQ_G;
   constant PGP_CLK_FREQ_C      : real := PGP_LINE_RATE_G / 20.0;

   -------------------------------------------------------------------------------------------------
   -- JESD constants and signals
   -------------------------------------------------------------------------------------------------
   constant DEVCLK_PERIOD_C    : real     := real(GT_WORD_SIZE_C)*10.0/(LINE_RATE_G);
   
   signal   s_sysRef    : sl;
   signal   s_sysRefOut : sl;   
   signal   s_nsync     : sl;

   -- QPLL
   signal  qPllLock      : sl; 

   -------------------------------------------------------------------------------------------------
   -- Clock Signals
   -------------------------------------------------------------------------------------------------
   signal pgpRefClk     : sl;
   signal pgpRefClkDiv2 : sl;
   signal pgpRefClkG    : sl;
   signal axilClk       : sl;
   signal axilClkRst    : sl;
   signal pgpClk        : sl;
   signal pgpClkRst     : sl;
   signal pgpMmcmRst    : sl;
   
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
   constant NUM_AXI_MASTERS_C : natural := 3;

   constant VERSION_AXIL_INDEX_C : natural              := 0;
   constant JESD_AXIL_INDEX_C    : natural              := 1;
   constant DAQ_AXIL_INDEX_C     : natural              := 2;
   
   constant VERSION_AXIL_BASE_ADDR_C : slv(31 downto 0)   := X"00000000";
   constant JESD_AXIL_BASE_ADDR_C    : slv(31 downto 0)   := X"00010000";
   constant DAQ_AXIL_BASE_ADDR_C     : slv(31 downto 0)   := X"00030000";   

   constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := (
      VERSION_AXIL_INDEX_C => (
         baseAddr          => VERSION_AXIL_BASE_ADDR_C,
         addrBits          => 12,
         connectivity      => X"0001"),
      JESD_AXIL_INDEX_C    => (
         baseAddr          => JESD_AXIL_BASE_ADDR_C,
         addrBits          => 12,
         connectivity      => X"0001"),
      DAQ_AXIL_INDEX_C    => (
         baseAddr          => DAQ_AXIL_BASE_ADDR_C,
         addrBits          => 12,
         connectivity      => X"0001")  );

   signal extAxilWriteMaster : AxiLiteWriteMasterType;
   signal extAxilWriteSlave  : AxiLiteWriteSlaveType;
   signal extAxilReadMaster  : AxiLiteReadMasterType;
   signal extAxilReadSlave   : AxiLiteReadSlaveType;

   signal locAxilWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal locAxilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal locAxilReadMasters  : AxiLiteReadMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal locAxilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);
   
   -- Sample data
   signal s_sampleDataArr   : sampleDataArray(L_RX_G-1 downto 0);
   signal s_dataValidVec    : slv(L_RX_G-1 downto 0); 

   -------------------------------------------------------------------------------------------------
   -- PGP Signals and Virtual Channels
   -------------------------------------------------------------------------------------------------
   constant JESD_SSI_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(GT_WORD_SIZE_C, TKEEP_COMP_C);

   signal axisRxMasters : AxiStreamMasterArray(L_AXI_G-1 downto 0);
   signal axisRxSlaves  : AxiStreamSlaveArray(L_AXI_G-1 downto 0);
   signal axisRxCtrl    : AxiStreamCtrlArray(L_AXI_G-1 downto 0);
   
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
   signal s_rePulse     : slv(L_RX_G-1 downto 0);
   signal rxUserRdyOut  : slv(L_RX_G-1 downto 0);   
   signal rxMmcmResetOut: slv(L_RX_G-1 downto 0); 
   
begin
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
         DIV     => "000",
         O       => pgpRefClkG);
         
   -------------------------------------------------------------------------------------------------
   -- Power up reset generated from PGP clock
   -------------------------------------------------------------------------------------------------
   PwrUpRst_1 : entity work.PwrUpRst
      generic map (
         TPD_G          => TPD_G,
         SIM_SPEEDUP_G  => SIMULATION_G,
         IN_POLARITY_G  => '1',
         OUT_POLARITY_G => '1')
      port map (
         clk    => pgpRefClkG,
         rstOut => powerOnReset);

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
         stableClk       => pgpRefClkG,
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
         axisTxMasters   => axisRxMasters,
         axisTxSlaves    => axisRxSlaves,
         axisTxCtrl      => axisRxCtrl,
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
         ODIV2 => jesdRefClkDiv2, -- Frequency the same as jesdRefClk
         O     => jesdRefClk          
   );
     
   JESDREFCLK_BUFG_GT : BUFG_GT
      port map (
         I => jesdRefClkDiv2,   
         CE     => '1',         
         CLR    => '0',
         CEMASK => '1',
         CLRMASK=> '1',

         DIV    => "000",
         O      => jesdRefClkG);

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
         CLKFBOUT_MULT_F_G  => 5.375,--12.75,--6.375,--6.375,
         CLKOUT0_DIVIDE_F_G => 5.375,--12.75,--6.375,
         CLKOUT0_RST_HOLD_G => 16)
      port map (
         clkIn     => jesdRefClkG,
         rstIn     => jesdMmcmRst,
         clkOut(0) => jesdClk,
         rstOut(0) => jesdClkRst);
            
   -------------------------------------------------------------------------------------------------
   -- JESD block
   -------------------------------------------------------------------------------------------------   
   Jesd204bGthWrapper_INST: entity work.Jesd204bGthWrapper
   generic map (
      TPD_G       => TPD_G,
        
      -- Test tx module instead of GTX
      TEST_G      =>  TEST_G,
      -- Internal SYSREF SYSREF_GEN_G= TRUE else 
      -- External SYSREF
      SYSREF_GEN_G =>  SYSREF_GEN_G,      
      
      -- AXI
      AXI_ERROR_RESP_G      => AXI_RESP_SLVERR_C,
      
      -- JESD
      F_G                => F_G,
      K_G                => K_G,
      L_RX_G             => L_RX_G
   )
   port map (
     
      stableClk         => jesdRefClkG, --pgpClk Stable because it is never reset
      refClk            => jesdRefClk,       
      
      devClk_i          => jesdClk, -- both same
      devClk2_i         => jesdClk, -- both same
      devRst_i          => jesdClkRst, 
          
      gtTxP          => adcGtTxP,   
      gtTxN          => adcGtTxN, 
      gtRxP          => adcGtRxP,   
      gtRxN          => adcGtRxN,
   
      axiClk            => axilClk,
      axiRst            => axilClkRst,
      
      axilReadMaster  => locAxilReadMasters(JESD_AXIL_INDEX_C),
      axilReadSlave   => locAxilReadSlaves(JESD_AXIL_INDEX_C),
      axilWriteMaster => locAxilWriteMasters(JESD_AXIL_INDEX_C),
      axilWriteSlave  => locAxilWriteSlaves(JESD_AXIL_INDEX_C),
      
      -- AXI stream interface not used because of external DAQ module 
      rxAxisMasterArr   => open,
      rxCtrlArr         => (others => AXI_STREAM_CTRL_INIT_C),
      
      sampleDataArr_o   => s_sampleDataArr,
      dataValidVec_o    => s_dataValidVec,
      
      sysRef_i          => s_sysRef,
      sysRef_o          => s_sysRefOut,          
      nSync_o           => s_nSync,
      
      pulse_o           => s_rePulse,
      
      leds_o(0)         => s_syncAllLED, -- (0) Sync (OR)
      leds_o(1)         => s_validAllLED,-- (1) Data_valid
      
      qPllLock_o        => qPllLock
   );
   
   -------------------------------------------------------------------------------------------------
   -- DAQ Multiplexer block
   ------------------------------------------------------------------------------------------------- 
   AxisDaqMux_INST: entity work.AxisDaqMux
   generic map (
      TPD_G   => TPD_G,
      L_G     => L_RX_G,
      L_AXI_G => L_AXI_G)
   port map (
      axiClk            => axilClk,
      axiRst            => axilClkRst,
      devClk_i          => jesdClk,
      devRst_i          => jesdClkRst,
      trigHW_i          => trigHW,
      
      axilReadMaster  => locAxilReadMasters(DAQ_AXIL_INDEX_C),
      axilReadSlave   => locAxilReadSlaves(DAQ_AXIL_INDEX_C),
      axilWriteMaster => locAxilWriteMasters(DAQ_AXIL_INDEX_C),
      axilWriteSlave  => locAxilWriteSlaves(DAQ_AXIL_INDEX_C),
      
      sampleDataArr_i   => s_sampleDataArr,
      dataValidVec_i    => s_dataValidVec,
      rxAxisMasterArr_o => axisRxMasters,
      rxCtrlArr_i       => axisRxCtrl);

   
   
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
   
   -- Sync outputs are all combined (TODO consider separating if having problems)   
   OBUFDS_nsync1_inst : OBUFDS
   generic map (
      IOSTANDARD => "DEFAULT",
      SLEW => "SLOW"
   )
   port map (
      I =>  s_nSync,
      O =>  syncb1P, 
      OB => syncb1N
   );
   
   OBUFDS_nsync2_inst : OBUFDS
   generic map (
      IOSTANDARD => "DEFAULT",
      SLEW => "SLOW"
   )
   port map (
      I =>  s_nSync,
      O =>  syncb2P, 
      OB => syncb2N
   );
   
   OBUFDS_nsync3_inst : OBUFDS
   generic map (
      IOSTANDARD => "DEFAULT",
      SLEW => "SLOW"
   )
   port map (
      I =>  s_nSync,
      O =>  syncb3P, 
      OB => syncb3N
   );
   
   -------------------------------------------------------------------------------------------------
   -- Debug outputs
   -------------------------------------------------------------------------------------------------
   -- LED Test Outputs
   Heartbeat_axilClk : entity work.Heartbeat
      generic map (
         TPD_G        => TPD_G,
         PERIOD_IN_G  => 8.0E-9,
         PERIOD_OUT_G => 1.0)
      port map (
         clk => axilClk,
         o   => leds(0));

   Heartbeat_pgpClk : entity work.Heartbeat
      generic map (
         TPD_G        => TPD_G,
         PERIOD_IN_G  => 6.4E-9,
         PERIOD_OUT_G => 1.0)
      port map (
         clk => pgpClk,
         o   => leds(1));
         
   Heartbeat_jesdclk : entity work.Heartbeat
      generic map (
         TPD_G        => TPD_G,
         PERIOD_IN_G  => 5.425E-9,
         PERIOD_OUT_G => 1.0)
      port map (
         clk => jesdClk,
         o   => leds(4));
         
   leds(5) <= qPllLock;
   leds(6) <= s_syncAllLED;
   leds(7) <= s_validAllLED;
      
   -- Debug output pins
   OBUF_sysref_inst : OBUF
   port map (
      I => s_sysRefOut,
      O =>  sysrefDbg 
   );
     
   -- Debug output pins
   OBUF_rePulse_0_inst : OBUF
   port map (
      I => s_rePulse(0),
      O => rePulseDbg(0)
   );
   
   -- Debug output pins
   OBUF_rePulse_1_inst : OBUF
   port map (
      I => s_rePulse(1),
      O => rePulseDbg(1)
   );
   
   -- Output user clock for single ended reference
   UserClkBufSingle_INST: entity work.ClkOutBufSingle
   generic map (
      XIL_DEVICE_G   => "ULTRASCALE",
      RST_POLARITY_G => '1',
      INVERT_G       => false)
   port map (
      clkIn  => jesdClk,
      rstIn  => jesdClkRst,
      clkOut => gpioClk);
   
end architecture rtl;
