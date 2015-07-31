-------------------------------------------------------------------------------
-- Title      : Development board for JESD ADC simulation
-------------------------------------------------------------------------------
-- File       : DevBoard.vhd
-- Author     : Uros Legat  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-05-05
-- Last update: 2015-07-30
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Used only for simulation
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

entity DevBoard is

  generic (
    TPD_G                  : time    := 1 ns;
    SIMULATION_G           : boolean := true;
    -- PGP Config
    PGP_REFCLK_FREQ_G      : real    := 156.25E6;
    PGP_LINE_RATE_G        : real    := 3.125E9;
    -- AXIL Config
    AXIL_CLK_FREQ_G        : real    := 156.25E6;
    -- AXIS Config
    AXIS_CLK_FREQ_G        : real    := 185.0E6;
    AXIS_FIFO_ADDR_WIDTH_G : integer := 12);
  port (
    sysClk125P : in sl;
    sysClk125N : in sl;

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
    --   fpgaDevClkaP : in sl;             -- FMC-D3-P
    --    fpgaDevClkaN : in sl;             -- FMC-D4-N
--      fpgaDevClkbP : in sl;             -- LA00_P_CC - FMC G6
--      fpgaDevClkbN : in sl;             -- LA00_N_CC - FMC G7

    -- JESD synchronisation timing signal (Used in subclass 1 mode)
    -- has to meet setup and hold times of JESD devClk
    -- periodic (period has to be multiple of LMFC clock)
    -- single   (another pulse has to be generated if re-sync needed)      
    fpgaSysRefP : in sl;                -- LA03_P - FMC G9
    fpgaSysRefN : in sl;                -- LA04_N - FMC G10

    syncbP : out sl;
    syncbN : out sl;

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

    -- Onboard LEDs
    leds : out slv(4 downto 0));


end entity DevBoard;

architecture rtl of DevBoard is
  -------------------------------------------------------------------------------------------------
  -- PGP constants
  -------------------------------------------------------------------------------------------------
  constant PGP_REFCLK_PERIOD_C : real := 1.0 / PGP_REFCLK_FREQ_G;
  constant PGP_CLK_FREQ_C      : real := PGP_LINE_RATE_G / 20.0;

  -------------------------------------------------------------------------------------------------
  -- SPI
  -------------------------------------------------------------------------------------------------   
  constant NUM_COMMON_SPI_CHIPS_C : positive range 1 to 8 := 4;
  signal   coreSclk               : slv(NUM_COMMON_SPI_CHIPS_C-1 downto 0);
  signal   coreSDout              : slv(NUM_COMMON_SPI_CHIPS_C-1 downto 0);
  signal   coreCsb                : slv(NUM_COMMON_SPI_CHIPS_C-1 downto 0);

  signal muxSDin  : sl;
  signal muxSClk  : sl;
  signal muxSDout : sl;

  signal lmkSDin : sl;

  signal spiSDinDac  : sl;
  signal spiSDoutDac : sl;

  -------------------------------------------------------------------------------------------------
  -- JESD constants and signals
  -------------------------------------------------------------------------------------------------
  constant REFCLK_FREQUENCY_C : real := 370.0E6;
  constant LINE_RATE_C        : real := 7.40E9;
  constant DEVCLK_PERIOD_C    : real := 1.0/(LINE_RATE_C/40.0);

  constant F_C         : positive := 2;
  constant K_C         : positive := 32;
  constant L_C         : positive := 6;
  constant SUB_CLASS_C : natural  := 1;


  signal s_sysRef : sl;
  signal s_nsync  : sl;

  -- QPLL config constants
  constant QPLL_CONFIG_C : Gtx7QPllCfgType := getGtx7QPllCfg(REFCLK_FREQUENCY_C, LINE_RATE_C);

  -- QPLL
  signal gtCPllRefClk   : sl;
  signal gtCPllLock     : sl;
  signal qPllOutClk     : sl;
  signal qPllOutRefClk  : sl;
  signal qPllLock       : sl;
  signal qPllRefClkLost : sl;
  signal qPllReset      : slv(L_C-1 downto 0);
  signal gtQPllReset    : sl;


  -------------------------------------------------------------------------------------------------
  -- Clock Signals
  -------------------------------------------------------------------------------------------------

  signal sysClk125    : sl;
  signal sysClk125G   : sl;
  signal sysClk125Rst : sl;

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
  constant NUM_AXI_MASTERS_C : natural := 10;

  constant VERSION_AXIL_INDEX_C : natural := 0;
  constant JESD_AXIL_RX_INDEX_C : natural := 1;
  constant JESD_AXIL_TX_INDEX_C : natural := 2;
  constant DAQ_AXIL_INDEX_C     : natural := 3;
  constant DISP_AXIL_INDEX_C    : natural := 4;
  constant ADC_0_INDEX_C        : natural := 5;
  constant ADC_1_INDEX_C        : natural := 6;
  constant ADC_2_INDEX_C        : natural := 7;
  constant LMK_INDEX_C          : natural := 8;
  constant DAC_INDEX_C          : natural := 9;

  constant VERSION_AXIL_BASE_ADDR_C : slv(31 downto 0) := X"0000_0000";
  constant JESD_AXIL_RX_BASE_ADDR_C : slv(31 downto 0) := X"0010_0000";
  constant JESD_AXIL_TX_BASE_ADDR_C : slv(31 downto 0) := X"0020_0000";
  constant DAQ_AXIL_BASE_ADDR_C     : slv(31 downto 0) := X"0030_0000";
  constant DISP_AXIL_BASE_ADDR_C    : slv(31 downto 0) := X"0040_0000";
  constant ADC_0_BASE_ADDR_C        : slv(31 downto 0) := X"0050_0000";
  constant ADC_1_BASE_ADDR_C        : slv(31 downto 0) := X"0060_0000";
  constant ADC_2_BASE_ADDR_C        : slv(31 downto 0) := X"0070_0000";
  constant LMK_BASE_ADDR_C          : slv(31 downto 0) := X"0080_0000";
  constant DAC_BASE_ADDR_C          : slv(31 downto 0) := X"0090_0000";

  constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := (
    VERSION_AXIL_INDEX_C => (
      baseAddr           => VERSION_AXIL_BASE_ADDR_C,
      addrBits           => 12,
      connectivity       => X"0001"),
    JESD_AXIL_RX_INDEX_C => (
      baseAddr           => JESD_AXIL_RX_BASE_ADDR_C,
      addrBits           => 12,
      connectivity       => X"0001"),
    JESD_AXIL_TX_INDEX_C => (
      baseAddr           => JESD_AXIL_TX_BASE_ADDR_C,
      addrBits           => 12,
      connectivity       => X"0001"),
    DAQ_AXIL_INDEX_C     => (
      baseAddr           => DAQ_AXIL_BASE_ADDR_C,
      addrBits           => 12,
      connectivity       => X"0001"),
    DISP_AXIL_INDEX_C    => (
      baseAddr           => DISP_AXIL_BASE_ADDR_C,
      addrBits           => 20,
      connectivity       => X"0001"),
    ADC_0_INDEX_C        => (
      baseAddr           => ADC_0_BASE_ADDR_C,
      addrBits           => 20,
      connectivity       => X"0001"),
    ADC_1_INDEX_C        => (
      baseAddr           => ADC_1_BASE_ADDR_C,
      addrBits           => 20,
      connectivity       => X"0001"),
    ADC_2_INDEX_C        => (
      baseAddr           => ADC_2_BASE_ADDR_C,
      addrBits           => 20,
      connectivity       => X"0001"),
    LMK_INDEX_C          => (
      baseAddr           => LMK_BASE_ADDR_C,
      addrBits           => 20,
      connectivity       => X"0001"),
    DAC_INDEX_C          => (
      baseAddr           => DAC_BASE_ADDR_C,
      addrBits           => 12,
      connectivity       => X"0001"));

  signal extAxilWriteMaster : AxiLiteWriteMasterType;
  signal extAxilWriteSlave  : AxiLiteWriteSlaveType;
  signal extAxilReadMaster  : AxiLiteReadMasterType;
  signal extAxilReadSlave   : AxiLiteReadSlaveType;

  signal locAxilWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
  signal locAxilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);
  signal locAxilReadMasters  : AxiLiteReadMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
  signal locAxilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);

  -- Sample data
  signal s_sampleDataArrIn : sampleDataArray(L_C-1 downto 0);
  signal s_dataValidVec    : slv(L_C-1 downto 0);

  signal s_sampleDataArrOut : sampleDataArray(L_C-1 downto 0);

  -------------------------------------------------------------------------------------------------
  -- PGP Signals and Virtual Channels
  -------------------------------------------------------------------------------------------------
  constant JESD_SSI_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(GT_WORD_SIZE_C, TKEEP_COMP_C);

  signal axisTxMasters : AxiStreamMasterArray(1 downto 0);
  signal axisTxSlaves  : AxiStreamSlaveArray(1 downto 0);
  signal axisTxCtrl    : AxiStreamCtrlArray(1 downto 0);

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

  --sysClk125Rst <= masterReset or powerOnReset;


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
      DIV     => "000",                 -- GT_WORD_SIZE_C=4
      O       => pgpRefClkG);

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
  -- IBUFDS_GTE2_FPGADEVCLKA : IBUFDS_GTE2
  -- port map (
  -- I     => fpgaDevClkaP,
  -- IB    => fpgaDevClkaN,
  -- CEB   => '0',
  -- ODIV2 => jesdRefClkDiv2,
  -- O     => jesdRefClk          
  -- );

  -- JESDREFCLK_BUFG : BUFG
  -- port map (
  -- I => jesdRefClkDiv2,
  -- O => jesdRefClkG);

  -- jesdMmcmRst <= powerOnReset or masterReset;

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
  -- JESD block
  -------------------------------------------------------------------------------------------------   
  Jesd204bRxTxSim_INST : entity work.Jesd204bRxTxSim
    generic map (
      TPD_G => TPD_G,

      -- Test tx module instead of GTX
      TEST_G => false,

      -- Internal SYSREF SELF_TEST_G= TRUE else 
      -- External SYSREF
      SYSREF_GEN_G => true,

      -- Simulation (no GT core, RX module is fed from Tx module)
      SIM_G => true,

      -- AXI
      AXI_ERROR_RESP_G => AXI_RESP_SLVERR_C,

      -- JESD
      F_G => F_C,
      K_G => K_C,
      L_G => L_C
      )
    port map (

      stableClk => jesdRefClkG,         -- Stable because it is never reset
      devClk_i  => jesdClk,             -- both same
      devClk2_i => jesdClk,             -- both same
      devRst_i  => jesdClkRst,

      axiClk => axilClk,
      axiRst => axilClkRst,

      axilReadMasterRx  => locAxilReadMasters(JESD_AXIL_RX_INDEX_C),
      axilReadSlaveRx   => locAxilReadSlaves(JESD_AXIL_RX_INDEX_C),
      axilWriteMasterRx => locAxilWriteMasters(JESD_AXIL_RX_INDEX_C),
      axilWriteSlaveRx  => locAxilWriteSlaves(JESD_AXIL_RX_INDEX_C),

      axilReadMasterTx  => locAxilReadMasters(JESD_AXIL_TX_INDEX_C),
      axilReadSlaveTx   => locAxilReadSlaves(JESD_AXIL_TX_INDEX_C),
      axilWriteMasterTx => locAxilWriteMasters(JESD_AXIL_TX_INDEX_C),
      axilWriteSlaveTx  => locAxilWriteSlaves(JESD_AXIL_TX_INDEX_C),


      sampleDataArr_o => s_sampleDataArrOut,
      dataValidVec_o  => s_dataValidVec,

      sampleDataArr_i => s_sampleDataArrIn,


      rxAxisMasterArr => open,
      rxCtrlArr       => (others => AXI_STREAM_CTRL_INIT_C),
      sysRef_i        => s_sysRef,
      nSync_o         => s_nSync,
      leds_o          => open
      );

  -------------------------------------------------------------------------------------------------
  -- DAQ Multiplexer block
  ------------------------------------------------------------------------------------------------- 
  AxisDaqMux_INST : entity work.AxisDaqMux
    generic map (
      TPD_G   => TPD_G,
      L_G     => L_C,
      L_AXI_G => 2)
    port map (
      axiClk          => axilClk,
      axiRst          => axilClkRst,
      devClk_i        => jesdClk,
      devRst_i        => jesdClkRst,
      trigHW_i        => '0',
      axilReadMaster  => locAxilReadMasters(DAQ_AXIL_INDEX_C),
      axilReadSlave   => locAxilReadSlaves(DAQ_AXIL_INDEX_C),
      axilWriteMaster => locAxilWriteMasters(DAQ_AXIL_INDEX_C),
      axilWriteSlave  => locAxilWriteSlaves(DAQ_AXIL_INDEX_C),

      sampleDataArr_i   => s_sampleDataArrOut,
      dataValidVec_i    => s_dataValidVec,
      rxAxisMasterArr_o => axisTxMasters,
      rxCtrlArr_i       => axisTxCtrl);

  -------------------------------------------------------------------------------------------------
  -- DAC Signal Generator block
  -------------------------------------------------------------------------------------------------    
  DacSignalGenerator_INST : entity work.DacSignalGenerator
    generic map (
      TPD_G            => TPD_G,
      AXI_ERROR_RESP_G => AXI_RESP_SLVERR_C,
      ADDR_WIDTH_G     => 12,
      DATA_WIDTH_G     => 32,
      L_G              => L_C)
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
      DIFF_TERM    => false,
      IBUF_LOW_PWR => true,
      IOSTANDARD   => "DEFAULT")
    port map (
      I  => fpgaSysRefP,
      IB => fpgaSysRefN,
      O  => s_sysRef
      );

  OBUFDS_nsync_inst : OBUFDS
    generic map (
      IOSTANDARD => "DEFAULT",
      SLEW       => "SLOW"
      )
    port map (
      I  => s_nSync,
      O  => syncbP,
      OB => syncbN
      );

  ----------------------------------------------------------------
  -- SPI interface ADCs and LMK 
  ----------------------------------------------------------------
  adcSpiChips : for I in NUM_COMMON_SPI_CHIPS_C-1 downto 0 generate
    AxiSpiMaster_INST : entity work.AxiSpiMaster
      generic map (
        TPD_G             => TPD_G,
        ADDRESS_SIZE_G    => 15,
        DATA_SIZE_G       => 8,
        CLK_PERIOD_G      => 8.0E-9,  --6.4E-9, TODO switch back for implementation
        SPI_SCLK_PERIOD_G => 24.0E-9)  --100.0E-6 TODO switch back for implementation
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
  end generate adcSpiChips;

  -- Input mux from "IO" port if LMK and from "I" port for ADCs 
  muxSDin <= lmkSDin when coreCsb = "0111" else spiSdo_i;

  -- Output mux
  with coreCsb select
    muxSclk <= coreSclk(0) when "1110",
    coreSclk(1)            when "1101",
    coreSclk(2)            when "1011",
    coreSclk(3)            when "0111",
    '0'                    when others;

  with coreCsb select
    muxSDout <= coreSDout(0) when "1110",
    coreSDout(1)             when "1101",
    coreSDout(2)             when "1011",
    coreSDout(3)             when "0111",
    '0'                      when others;

  -- Outputs 
  spiSclk_o <= muxSclk;
  spiSdi_o  <= muxSDout;

  ADC_SDIO_IOBUFT : IOBUF
    port map (
      I  => '0',
      O  => lmkSDin,
      IO => spiSdio_io,
      T  => muxSDout);

  -- Active low chip selects
  spiCsL_o <= coreCsb;

  ----------------------------------------------------------------
  -- SPI interface DAC
  ----------------------------------------------------------------  
  dacAxiSpiMaster_INST : entity work.AxiSpiMaster
    generic map (
      TPD_G             => TPD_G,
      ADDRESS_SIZE_G    => 7,
      DATA_SIZE_G       => 16,
      CLK_PERIOD_G      => 8.0E-9,  --6.4E-9, TODO switch back for implementation
      SPI_SCLK_PERIOD_G => 24.0E-9)  --100.0E-6 TODO switch back for implementation
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
      I  => '0',
      O  => spiSDinDac,
      IO => spiSdioDac_io,
      T  => spiSDoutDac);

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
      PERIOD_IN_G  => 2.7E-9,
      PERIOD_OUT_G => 1.0)
    port map (
      clk => jesdClk,
      o   => leds(4));

end architecture rtl;
