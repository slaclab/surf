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
--    6 lane JESD receiver
--    2 lane AXI stream interface DAQ (selectable between 6 ADC channels)
--    2 lane JESD transmitter
--    2 lane Signal generator (For DAC outputs)
--    SPI: 1 LMK chip, 3 ADC chips, and 1 DAC chip
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
      AXIS_FIFO_ADDR_WIDTH_G : integer := 14;
	  CASCADE_SIZE_G         : integer range 1 to (2**24) := 12;
      
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
      L_RX_G             : positive := 6;
      L_TX_G             : positive := 2;
      L_AXI_G            : positive := 2;
      -- DAC Signal generator RAM size 
      GEN_BRAM_ADDR_WIDTH_G  : integer range 1 to (2**24) := 12
   );
   port (

      -- RTM's High Speed Ports
      -- PGP MGT signals (SFP)
      rtmHsRxP      : in    sl;
      rtmHsRxN      : in    sl;
      rtmHsTxP      : out   sl;
      rtmHsTxN      : out   sl;
      -- 156.25MHz
      genClkP       : in    sl;
      genClkN       : in    sl;

      -- FMC Signals -- 
      -------------------------------------------------------------------

      -- JESD PORTS
      jesdRxP       : in    Slv6Array(1 downto 1);
      jesdRxN       : in    Slv6Array(1 downto 1);
      jesdTxP       : out   Slv6Array(1 downto 1);
      jesdTxN       : out   Slv6Array(1 downto 1);

      jesdClkP      : in    Slv1Array(1 downto 1);
      jesdClkN      : in    Slv1Array(1 downto 1);         
            
      -- AMC's System Reference Ports
      sysRefP       : in Slv1Array(1 downto 1);
      sysRefN       : in Slv1Array(1 downto 1);           

      -- JESD receiver sending sync to ADCs (Used in all subclass modes)
      -- '1' - synchronisation OK
      -- '0' - synchronisation Not OK - synchronisation request
      syncOutP       : out Slv3Array(1 downto 1);
      syncOutN       : out Slv3Array(1 downto 1);
      
      -- JESD transmitter receiving sync from DAC (Used in all subclass modes)
      -- '1' - synchronisation OK
      -- '0' - synchronisation Not OK - synchronisation request      
      syncInP       : in Slv1Array(1 downto 1);
      syncInN       : in Slv1Array(1 downto 1);     
        
      -- ADC and LMK SPI config interface
      spiSclk_o  : out   sl;               
      spiSdi_o   : out   sl;               
      spiSdo_i   : in    sl;
      spiSdio_io : inout sl;
      spiCsL_o   : out   slv(3 downto 0);

      -- DAC SPI config interface
      spiSclkDac_o  : out   sl;               
      spiSdioDac_io : inout sl;
      spiCsLDac_o   : out   sl;
         
      -- External HW Acquisition trigger
      trigHW: in sl;
      
      -- Debug Signals connected to RTM -- 
      -------------------------------------------------------------------
      rtmLsP : out   slv(31 downto 24);
      rtmLsN : out   slv(31 downto 24)
      
   );
end entity AtcaDemoBoard;

architecture rtl of AtcaDemoBoard is
      
   -------------------------------------------------------------------------------------------------
   -- PGP constants
   -------------------------------------------------------------------------------------------------
   constant PGP_REFCLK_PERIOD_C : real := 1.0 / PGP_REFCLK_FREQ_G;
   constant PGP_CLK_FREQ_C      : real := PGP_LINE_RATE_G / 20.0;
   
   -------------------------------------------------------------------------------------------------
   -- SPI
   -------------------------------------------------------------------------------------------------   
   constant NUM_COMMON_SPI_CHIPS_C : positive range 1 to 8 := 4;
   signal  coreSclk  : slv(NUM_COMMON_SPI_CHIPS_C-1 downto 0); 
   signal  coreSDout : slv(NUM_COMMON_SPI_CHIPS_C-1 downto 0);
   signal  coreCsb   : slv(NUM_COMMON_SPI_CHIPS_C-1 downto 0);   

   signal  muxSDin  : sl; 
   signal  muxSClk  : sl;
   signal  muxSDout : sl;
   
   signal  lmkSDin  : sl;
   
   signal  spiSDinDac  : sl;
   signal  spiSDoutDac : sl;
   
   -------------------------------------------------------------------------------------------------
   -- JESD constants and signals
   -------------------------------------------------------------------------------------------------
   constant DEVCLK_PERIOD_C    : real     := real(GT_WORD_SIZE_C)*10.0/(LINE_RATE_G);
   
   signal   s_sysRef    : sl;
   signal   s_sysRefOut : sl;   
   signal   s_nsyncADC  : sl;
   signal   s_nsyncDAC  : sl;
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

   signal jesdMmcmLocked : sl;
   
   
   signal powerOnReset : sl;
   signal masterReset  : sl;
   signal fpgaReload   : sl;
  

   -------------------------------------------------------------------------------------------------
   -- AXI Lite Config and Signals
   -------------------------------------------------------------------------------------------------
   constant NUM_AXI_MASTERS_C : natural := 10;

   constant VERSION_AXIL_INDEX_C    : natural   := 0;
   constant JESD_AXIL_RX_INDEX_C    : natural   := 1;
   constant JESD_AXIL_TX_INDEX_C    : natural   := 2;
   constant DAQ_AXIL_INDEX_C        : natural   := 3;
   constant DISP_AXIL_INDEX_C       : natural   := 4;
   constant ADC_0_INDEX_C           : natural   := 5;
   constant ADC_1_INDEX_C           : natural   := 6;
   constant ADC_2_INDEX_C           : natural   := 7;
   constant LMK_INDEX_C             : natural   := 8;
   constant DAC_INDEX_C             : natural   := 9;

   constant VERSION_AXIL_BASE_ADDR_C : slv(31 downto 0)   := X"0000_0000";
   constant JESD_AXIL_RX_BASE_ADDR_C : slv(31 downto 0)   := X"0010_0000";
   constant JESD_AXIL_TX_BASE_ADDR_C : slv(31 downto 0)   := X"0020_0000";
   constant DAQ_AXIL_BASE_ADDR_C     : slv(31 downto 0)   := X"0030_0000";
   constant DISP_AXIL_BASE_ADDR_C    : slv(31 downto 0)   := X"0040_0000";
   constant ADC_0_BASE_ADDR_C        : slv(31 downto 0)   := X"0050_0000";
   constant ADC_1_BASE_ADDR_C        : slv(31 downto 0)   := X"0060_0000";
   constant ADC_2_BASE_ADDR_C        : slv(31 downto 0)   := X"0070_0000";
   constant LMK_BASE_ADDR_C          : slv(31 downto 0)   := X"0080_0000";   
   constant DAC_BASE_ADDR_C          : slv(31 downto 0)   := X"0090_0000";   

   constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := (
      VERSION_AXIL_INDEX_C => (
         baseAddr          => VERSION_AXIL_BASE_ADDR_C,
         addrBits          => 12,
         connectivity      => X"0001"),
      JESD_AXIL_RX_INDEX_C    => (
         baseAddr          => JESD_AXIL_RX_BASE_ADDR_C,
         addrBits          => 12,
         connectivity      => X"0001"),
      JESD_AXIL_TX_INDEX_C    => (
         baseAddr          => JESD_AXIL_TX_BASE_ADDR_C,
         addrBits          => 12,
         connectivity      => X"0001"),   
      DAQ_AXIL_INDEX_C    => (
         baseAddr          => DAQ_AXIL_BASE_ADDR_C,
         addrBits          => 12,
         connectivity      => X"0001"),
      DISP_AXIL_INDEX_C    => (
         baseAddr          => DISP_AXIL_BASE_ADDR_C,
         addrBits          => 20,
         connectivity      => X"0001"),
      ADC_0_INDEX_C => (
         baseAddr          => ADC_0_BASE_ADDR_C,
         addrBits          => 20,
         connectivity      => X"0001"),
      ADC_1_INDEX_C    => (
         baseAddr          => ADC_1_BASE_ADDR_C,
         addrBits          => 20,
         connectivity      => X"0001"),
      ADC_2_INDEX_C    => (
         baseAddr          => ADC_2_BASE_ADDR_C,
         addrBits          => 20,
         connectivity      => X"0001"),
      LMK_INDEX_C    => (
         baseAddr          => LMK_BASE_ADDR_C,
         addrBits          => 20,
         connectivity      => X"0001"),   
      DAC_INDEX_C    => (
         baseAddr          => DAC_BASE_ADDR_C,
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
   
   -- Sample data
   signal s_sampleDataArrOut  : sampleDataArray(L_RX_G-1 downto 0);
   signal s_dataValidVec      : slv(L_RX_G-1 downto 0);
   signal s_sampleDataArrIn   : sampleDataArray(L_TX_G-1 downto 0);

   -------------------------------------------------------------------------------------------------
   -- PGP Signals and Virtual Channels
   -------------------------------------------------------------------------------------------------
   constant JESD_SSI_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(GT_WORD_SIZE_C, TKEEP_COMP_C);

   signal axisRxMasters : AxiStreamMasterArray(L_AXI_G-1 downto 0);
   signal axisRxSlaves  : AxiStreamSlaveArray(L_AXI_G-1 downto 0);
   signal axisRxCtrl    : AxiStreamCtrlArray(L_AXI_G-1 downto 0);
    
   
   -------------------------------------------------------------------------------------------------
   -- Debug RX and TX digital pulses for latency measurements
   -------------------------------------------------------------------------------------------------   
   signal s_rxPulse     : slv(L_RX_G-1 downto 0);
   signal s_txPulse     : slv(L_TX_G-1 downto 0);   
 
   
begin
   -------------------------------------------------------------------------------------------------
   -- PGP Refclk
   -------------------------------------------------------------------------------------------------
   PGPREFCLK_IBUFDS_GTE3 : IBUFDS_GTE3
      port map (
         I     => genClkP,
         IB    => genClkN,
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

   pgpMmcmRst <= powerOnReset;

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
		 CASCADE_SIZE_G         => CASCADE_SIZE_G,
         AXIS_CONFIG_G          => JESD_SSI_CONFIG_C)
      port map (
         stableClk       => pgpRefClkG,
         pgpRefClk       => pgpRefClk,
         pgpClk          => pgpClk,
         pgpClkRst       => pgpClkRst,
         pgpGtRxN        => rtmHsRxN,
         pgpGtRxP        => rtmHsRxP,
         pgpGtTxN        => rtmHsTxN,
         pgpGtTxP        => rtmHsTxP,
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
         leds            => open);--leds(3 downto 2));

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
         I     => jesdClkP(1)(0),
         IB    => jesdClkN(1)(0),
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
         
   JesdPwrUpRst_1 : entity work.PwrUpRst
   generic map (
      TPD_G          => TPD_G,
      SIM_SPEEDUP_G  => SIMULATION_G,
      IN_POLARITY_G  => '1',
      OUT_POLARITY_G => '1')
   port map (
      clk    => jesdRefClkG,
      rstOut => jesdMmcmRst);      

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
         rstOut(0) => jesdClkRst,
         locked    => jesdMmcmLocked
         );
            
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
      
      devClkActive_i    => jesdMmcmLocked,
      
      -- Remap the ports to match channel numbers on LLRF board
      gtTxP(0)          => jesdTxP(1)(4),
      gtTxP(1)          => jesdTxP(1)(5),
      gtTxP(2)          => jesdTxP(1)(0),
      gtTxP(3)          => jesdTxP(1)(1),
      gtTxP(4)          => jesdTxP(1)(2),
      gtTxP(5)          => jesdTxP(1)(3),
      
      gtTxN(0)          => jesdTxN(1)(4),
      gtTxN(1)          => jesdTxN(1)(5),      
      gtTxN(2)          => jesdTxN(1)(0),      
      gtTxN(3)          => jesdTxN(1)(1),      
      gtTxN(4)          => jesdTxN(1)(2),
      gtTxN(5)          => jesdTxN(1)(3),
      
      gtRxP(0)          => jesdRxP(1)(4),
      gtRxP(1)          => jesdRxP(1)(5),
      gtRxP(2)          => jesdRxP(1)(0),
      gtRxP(3)          => jesdRxP(1)(1),
      gtRxP(4)          => jesdRxP(1)(2),
      gtRxP(5)          => jesdRxP(1)(3),
      
      gtRxN(0)          => jesdRxN(1)(4),
      gtRxN(1)          => jesdRxN(1)(5),   
      gtRxN(2)          => jesdRxN(1)(0),
      gtRxN(3)          => jesdRxN(1)(1),
      gtRxN(4)          => jesdRxN(1)(2),
      gtRxN(5)          => jesdRxN(1)(3),

      axiClk            => axilClk,
      axiRst            => axilClkRst,
      
      axilReadMasterRx  => locAxilReadMasters(JESD_AXIL_RX_INDEX_C),
      axilReadSlaveRx   => locAxilReadSlaves(JESD_AXIL_RX_INDEX_C),
      axilWriteMasterRx => locAxilWriteMasters(JESD_AXIL_RX_INDEX_C),
      axilWriteSlaveRx  => locAxilWriteSlaves(JESD_AXIL_RX_INDEX_C), 
      
      axilReadMasterTx  => locAxilReadMasters(JESD_AXIL_TX_INDEX_C),
      axilReadSlaveTx   => locAxilReadSlaves(JESD_AXIL_TX_INDEX_C),
      axilWriteMasterTx => locAxilWriteMasters(JESD_AXIL_TX_INDEX_C),
      axilWriteSlaveTx  => locAxilWriteSlaves(JESD_AXIL_TX_INDEX_C),
      
      -- AXI stream interface not used because of external DAQ module 
      rxAxisMasterArr   => open,
      rxCtrlArr         => (others => AXI_STREAM_CTRL_INIT_C),
      
      sampleDataArr_o   => s_sampleDataArrOut,
      dataValidVec_o    => s_dataValidVec,
      
      sampleDataArr_i   => s_sampleDataArrIn,

      sysRef_i          => s_sysRef,
      sysRef_o          => s_sysRefOut,          
      nSync_o           => s_nSyncADC,
      nSync_i           => s_nSyncDAC,
      
      rxPulse_o           => s_rxPulse,
      txPulse_o           => s_txPulse,
      
      ledsRx_o         => open,
      ledsTx_o         => open,
      
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
      
      sampleDataArr_i   => s_sampleDataArrOut,
      dataValidVec_i    => s_dataValidVec,
      rxAxisMasterArr_o => axisRxMasters,
      rxCtrlArr_i       => axisRxCtrl);
   -------------------------------------------------------------------------------------------------
   -- DAC Signal Generator block
   -------------------------------------------------------------------------------------------------    
   DacSignalGenerator_INST: entity work.DacSignalGenerator
   generic map (
      TPD_G            => TPD_G,
      AXI_ERROR_RESP_G => AXI_RESP_SLVERR_C,
      ADDR_WIDTH_G     => GEN_BRAM_ADDR_WIDTH_G,
      DATA_WIDTH_G     => (GT_WORD_SIZE_C*8),
      L_G              => L_TX_G)
   port map (
      axiClk          => axilClk,
      axiRst          => axilClkRst,
      devClk_i        => jesdClk,
      devRst_i        => jesdClkRst,
      axilReadMaster  => locAxilReadMasters(DISP_AXIL_INDEX_C),
      axilReadSlave   => locAxilReadSlaves(DISP_AXIL_INDEX_C),
      axilWriteMaster => locAxilWriteMasters(DISP_AXIL_INDEX_C),
      axilWriteSlave  => locAxilWriteSlaves(DISP_AXIL_INDEX_C),  
      sampleDataArr_o => s_sampleDataArrIn);

   ----------------------------------------------------------------
   -- Put sync and sysref on differential io buffer
   ----------------------------------------------------------------
   IBUFDS_rsysref_inst : IBUFDS
   generic map (
      DIFF_TERM => FALSE,
      IBUF_LOW_PWR => TRUE,
      IOSTANDARD => "DEFAULT")
   port map (
      I  => sysRefP(1)(0),
      IB => sysRefN(1)(0),
      O  => s_sysRef
   );
   
   -- ADC Sync outputs are all combined (TODO consider separating if having problems)   
   OBUFDS_nsync1_inst : OBUFDS
   generic map (
      IOSTANDARD => "DEFAULT",
      SLEW => "SLOW"
   )
   port map (
      I =>  s_nsyncADC,
      O =>  syncOutP(1)(0), 
      OB => syncOutN(1)(0) 
   );
   
   OBUFDS_nsync2_inst : OBUFDS
   generic map (
      IOSTANDARD => "DEFAULT",
      SLEW => "SLOW"
   )
   port map (
      I =>  s_nSyncADC,
      O =>  syncOutP(1)(1), 
      OB => syncOutN(1)(1) 
   );
   
   OBUFDS_nsync3_inst : OBUFDS
   generic map (
      IOSTANDARD => "DEFAULT",
      SLEW => "SLOW"
   )
   port map (
      I =>  s_nSyncADC,
      O =>  syncOutP(1)(2), 
      OB => syncOutN(1)(2) 
   );
   
   IBUFDS_nsync4_inst : IBUFDS
   generic map (
      DIFF_TERM => FALSE,
      IBUF_LOW_PWR => TRUE,
      IOSTANDARD => "DEFAULT")
   port map (
      I  => syncInP(1)(0),
      IB => syncInN(1)(0),
      O  => s_nSyncDAC
   );
   
   
   ----------------------------------------------------------------
   -- SPI interface ADCs and LMK 
   ----------------------------------------------------------------
   gen_dcSpiChips : for I in NUM_COMMON_SPI_CHIPS_C-1 downto 0 generate
      AxiSpiMaster_INST: entity work.AxiSpiMaster
      generic map (
         TPD_G             => TPD_G,
         ADDRESS_SIZE_G    => 15,
         DATA_SIZE_G       => 8,   
         CLK_PERIOD_G      => 6.4E-9, 
         SPI_SCLK_PERIOD_G => 100.0E-6) -- TODO check
      port map (
         axiClk         => axilClk,
         axiRst         => axilClkRst,
         axiReadMaster  => locAxilReadMasters(ADC_0_INDEX_C+I),
         axiReadSlave   => locAxilReadSlaves(ADC_0_INDEX_C+I),
         axiWriteMaster => locAxilWriteMasters(ADC_0_INDEX_C+I),
         axiWriteSlave  => locAxilWriteSlaves(ADC_0_INDEX_C+I),  
         coreSclk       => coreSclk(I),
         coreSDin       => muxSDin,
         coreSDout      => coreSDout(I),
         coreCsb        => coreCsb(I));
   end generate gen_dcSpiChips;
   
   -- Input mux from "IO" port if LMK and from "I" port for ADCs 
   muxSDin <= lmkSDin when coreCsb = "0111" else spiSdo_i;
   
   -- Output mux
   with coreCsb select
   muxSclk  <= coreSclk(0) when "1110",
               coreSclk(1) when "1101",
               coreSclk(2) when "1011",
               coreSclk(3) when "0111",
               '0'         when others;
              
   with coreCsb select  
   muxSDout <= coreSDout(0) when "1110",
               coreSDout(1) when "1101",
               coreSDout(2) when "1011",
               coreSDout(3) when "0111",
               '0'          when others;
   
   -- Outputs 
   spiSclk_o <= muxSclk;
   spiSdi_o  <= muxSDout;

   ADC_SDIO_IOBUFT : IOBUF
      port map (
         I => '0',
         O => lmkSDin,
         IO => spiSdio_io,
         T => muxSDout);

   -- Active low chip selects
   spiCsL_o <= coreCsb;
   
   ----------------------------------------------------------------
   -- SPI interface DAC
   ----------------------------------------------------------------  
   dacAxiSpiMaster_INST: entity work.AxiSpiMaster
   generic map (
      TPD_G             => TPD_G,
      ADDRESS_SIZE_G    => 7,
      DATA_SIZE_G       => 16,
      CLK_PERIOD_G      => 6.4E-9, 
      SPI_SCLK_PERIOD_G => 100.0E-6) -- TODO check
   port map (
      axiClk         => axilClk,
      axiRst         => axilClkRst,
      axiReadMaster  => locAxilReadMasters(DAC_INDEX_C),
      axiReadSlave   => locAxilReadSlaves(DAC_INDEX_C),
      axiWriteMaster => locAxilWriteMasters(DAC_INDEX_C),
      axiWriteSlave  => locAxilWriteSlaves(DAC_INDEX_C),  
      coreSclk       => spiSclkDac_o,
      coreSDin       => spiSDinDac,
      coreSDout      => spiSDoutDac,
      coreCsb        => spiCsLDac_o);
   
       
   DAC_SDIO_IOBUFT : IOBUF
      port map (
         I => '0',
         O  => spiSDinDac,
         IO => spiSdioDac_io,
         T  => spiSDoutDac);   

   -------------------------------------------------------------------------------------------------
   -- Debug outputs
   -------------------------------------------------------------------------------------------------
   
   -- Digital outputs for latency measurements
   
   -- 6 Lane RX pulses (generated from comparing thersholds)
   gen_rxLanes : for I in L_RX_G-1 downto 0 generate
      OBUFDSPulseOut_rx_INSTX : OBUFDS
      generic map (
         IOSTANDARD => "DEFAULT",
         SLEW => "SLOW"
      )
      port map (
         I =>  s_rxPulse(I),
         O =>  rtmLsP(24+I), 
         OB => rtmLsN(24+I) 
      );
   end generate gen_rxLanes;
   
   -- 2 Lane TX pulses (digital square wave signal)
   gen_txLanes : for I in L_TX_G-1 downto 0 generate
      OBUFDSPulseOut_tx_INSTX : OBUFDS
      generic map (
         IOSTANDARD => "DEFAULT",
         SLEW => "SLOW"
      )
      port map (
         I =>  s_txPulse(I),
         O =>  rtmLsP(30+I), 
         OB => rtmLsN(30+I) 
      );
   end generate gen_txLanes; 
   --
end architecture rtl;
