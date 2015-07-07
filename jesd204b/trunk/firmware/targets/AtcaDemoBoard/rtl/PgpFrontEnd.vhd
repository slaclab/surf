-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PgpFrontEnd.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-08-22
-- Last update: 2015-06-10
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2013 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.Gtx7CfgPkg.all;
use work.Pgp2bPkg.all;

entity PgpFrontEnd is
   
   generic (
      TPD_G                  : time    := 1 ns;
      SIMULATION_G           : boolean := false;
      PGP_REFCLK_FREQ_G      : real    := 156.25E6;
      PGP_LINE_RATE_G        : real    := 3.125E9;
      PGP_CLK_FREQ_G         : real    := 156.25E6;
      AXIL_CLK_FREQ_G        : real    := 156.25E6;
      AXIS_CLK_FREQ_G        : real    := 185.0E6;
      AXIS_FIFO_ADDR_WIDTH_G : integer := 9;
      AXIS_CONFIG_G          : AxiStreamConfigType
      );
   port (
      stableClk : in sl;

      pgpRefClk : in sl;
      pgpClk    : in sl;
      pgpClkRst : in sl;

      -- PGP MGT signals
      pgpGtRxN : in  sl;                -- SFP+ 
      pgpGtRxP : in  sl;
      pgpGtTxN : out sl;
      pgpGtTxP : out sl;

      -- AXI-Lite master register interface
      axilClk         : in  sl;
      axilClkRst      : in  sl;
      axilWriteMaster : out AxiLiteWriteMasterType;
      axilWriteSlave  : in  AxiLiteWriteSlaveType;
      axilReadMaster  : out AxiLiteReadMasterType;
      axilReadSlave   : in  AxiLiteReadSlaveType;

      -- AXI Stream data interface
      axisClk       : in  sl;
      axisClkRst    : in  sl;
      axisTxMasters : in  AxiStreamMasterArray(1 downto 0);
      axisTxSlaves  : out AxiStreamSlaveArray(1 downto 0);
      axisTxCtrl    : out AxiStreamCtrlArray(1 downto 0);

      leds : out slv(1 downto 0));


end entity PgpFrontEnd;

architecture rtl of PgpFrontEnd is

   constant PGP_REFCLK_PERIOD_C : real := 1.0 / PGP_REFCLK_FREQ_G;

   -------------------------------------------------------------------------------------------------
   -- PGP MGT PLL Config
   -------------------------------------------------------------------------------------------------
   constant PGP_GTX_CPLL_CFG_C : Gtx7CPllCfgType := getGtx7CPllCfg(PGP_REFCLK_FREQ_G, PGP_LINE_RATE_G);

   -------------------------------------------------------------------------------------------------
   -- AXI Lite Config and Signals
   -------------------------------------------------------------------------------------------------
   constant NUM_AXI_MASTERS_C : natural := 2;

   constant EXT_AXI_INDEX_C : natural := 0;
   constant PGP_AXI_INDEX_C : natural := 1;

   constant EXT_AXI_BASE_ADDR_C : slv(31 downto 0) := X"00000000";
   constant PGP_AXI_BASE_ADDR_C : slv(31 downto 0) := X"00f00000";

   constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := (
      EXT_AXI_INDEX_C => (
         baseAddr     => EXT_AXI_BASE_ADDR_C,
         addrBits     => 20,
         connectivity => X"0001"),
      PGP_AXI_INDEX_C => (
         baseAddr     => PGP_AXI_BASE_ADDR_C,
         addrBits     => 14,
         connectivity => X"0001"));

   signal mAxilWriteMaster : AxiLiteWriteMasterType;
   signal mAxilWriteSlave  : AxiLiteWriteSlaveType;
   signal mAxilReadMaster  : AxiLiteReadMasterType;
   signal mAxilReadSlave   : AxiLiteReadSlaveType;

   signal sAxilWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal sAxilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal sAxilReadMasters  : AxiLiteReadMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal sAxilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);

   -------------------------------------------------------------------------------------------------
   -- PGP Signals and Virtual Channels
   -------------------------------------------------------------------------------------------------
   signal pgpTxIn      : Pgp2bTxInType;
   signal pgpTxOut     : Pgp2bTxOutType;
   signal pgpRxIn      : Pgp2bRxInType;
   signal pgpRxOut     : Pgp2bRxOutType;
   signal pgpTxMasters : AxiStreamMasterArray(3 downto 0);
   signal pgpTxSlaves  : AxiStreamSlaveArray(3 downto 0);
   signal pgpRxMasters : AxiStreamMasterArray(3 downto 0);
   signal pgpRxCtrl    : AxiStreamCtrlArray(3 downto 0);
   
begin


   -------------------------------------------------------------------------------------------------
   -- PGP / MGT
   -------------------------------------------------------------------------------------------------
   REAL_PGP : if (not SIMULATION_G) generate
      
      Pgp2bGthUltra_1 : entity work.Pgp2bGthUltra
         generic map (
            TPD_G             => TPD_G,
            PAYLOAD_CNT_TOP_G => 7,
            VC_INTERLEAVE_G   => 0,
            NUM_VC_EN_G       => 3)
         port map (
            stableClk        => stableClk,
            gtRefClk         => pgpRefClk,
            pgpGtTxP         => pgpGtTxP,
            pgpGtTxN         => pgpGtTxN,
            pgpGtRxP         => pgpGtRxP,
            pgpGtRxN         => pgpGtRxN,
            pgpTxReset       => pgpClkRst,
            pgpTxRecClk      => open,
            pgpTxClk         => pgpClk,
            pgpTxMmcmLocked  => '1',
            pgpRxReset       => pgpClkRst,
            pgpRxRecClk      => open,
            pgpRxClk         => pgpClk,
            pgpRxMmcmLocked  => '1',
            pgpRxIn          => pgpRxIn,
            pgpRxOut         => pgpRxOut,
            pgpTxIn          => pgpTxIn,
            pgpTxOut         => pgpTxOut,
            pgpTxMasters     => pgpTxMasters,
            pgpTxSlaves      => pgpTxSlaves,
            pgpRxMasters     => pgpRxMasters,
            pgpRxMasterMuxed => open,
            pgpRxCtrl        => pgpRxCtrl);

   end generate REAL_PGP;

   SIM_PGP : if (SIMULATION_G) generate
      PgpSimModel_1 : entity work.PgpSimModel
         generic map (
            TPD_G      => TPD_G,
            LANE_CNT_G => 1)
         port map (
            pgpTxClk         => pgpClk,
            pgpTxClkRst      => pgpClkRst,
            pgpTxIn          => pgpTxIn,
            pgpTxOut         => pgpTxOut,
            pgpTxMasters     => pgpTxMasters,
            pgpTxSlaves      => pgpTxSlaves,
            pgpRxClk         => pgpClk,
            pgpRxClkRst      => pgpClkRst,
            pgpRxIn          => pgpRxIn,
            pgpRxOut         => pgpRxOut,
            pgpRxMasters     => pgpRxMasters,
            pgpRxMasterMuxed => open,
            pgpRxCtrl        => pgpRxCtrl);
   end generate SIM_PGP;

   -------------------------------------------------------------------------------------------------
   -- SSI to AXI-Lite module on PGP VC 0
   -------------------------------------------------------------------------------------------------
   SsiAxiLiteMaster_1 : entity work.SsiAxiLiteMaster
      generic map (
         TPD_G               => TPD_G,
         EN_32BIT_ADDR_G     => false,
         BRAM_EN_G           => true,
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => (PGP_CLK_FREQ_G = AXIL_CLK_FREQ_G),
         FIFO_ADDR_WIDTH_G   => 9,
         FIFO_PAUSE_THRESH_G => 2**9-32,
         AXI_STREAM_CONFIG_G => SSI_PGP2B_CONFIG_C)
      port map (
         sAxisClk            => pgpClk,
         sAxisRst            => pgpClkRst,
         sAxisMaster         => pgpRxMasters(0),
         sAxisSlave          => open,
         sAxisCtrl           => pgpRxCtrl(0),
         mAxisClk            => pgpClk,
         mAxisRst            => pgpClkRst,
         mAxisMaster         => pgpTxMasters(0),
         mAxisSlave          => pgpTxSlaves(0),
         axiLiteClk          => axilClk,
         axiLiteRst          => axilClkRst,
         mAxiLiteWriteMaster => mAxilWriteMaster,
         mAxiLiteWriteSlave  => mAxilWriteSlave,
         mAxiLiteReadMaster  => mAxilReadMaster,
         mAxiLiteReadSlave   => mAxilReadSlave);

   -------------------------------------------------------------------------------------------------
   -- Top Axi Crossbar
   -------------------------------------------------------------------------------------------------
   AxiCrossbar : entity work.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXI_MASTERS_C,
         MASTERS_CONFIG_G   => AXI_CROSSBAR_MASTERS_CONFIG_C)
      port map (
         axiClk              => axilClk,
         axiClkRst           => axilClkRst,
         sAxiWriteMasters(0) => mAxilWriteMaster,
         sAxiWriteSlaves(0)  => mAxilWriteSlave,
         sAxiReadMasters(0)  => mAxilReadMaster,
         sAxiReadSlaves(0)   => mAxilReadSlave,
         mAxiWriteMasters    => sAxilWriteMasters,
         mAxiWriteSlaves     => sAxilWriteSlaves,
         mAxiReadMasters     => sAxilReadMasters,
         mAxiReadSlaves      => sAxilReadSlaves);

   -------------------------------------------------------------------------------------------------
   -- AXIL 0 is external port
   -------------------------------------------------------------------------------------------------
   axilWriteMaster     <= sAxilWriteMasters(0);
   sAxilWriteSlaves(0) <= axilWriteSlave;
   axilReadMaster      <= sAxilReadMasters(0);
   sAxilReadSlaves(0)  <= axilReadSlave;

   -------------------------------------------------------------------------------------------------
   -- AXIL 1 is PGP-AXIL interface
   -------------------------------------------------------------------------------------------------
   Pgp2bAxi_1 : entity work.Pgp2bAxi
      generic map (
         TPD_G              => TPD_G,
         COMMON_TX_CLK_G    => (PGP_CLK_FREQ_G = AXIL_CLK_FREQ_G),
         COMMON_RX_CLK_G    => (PGP_CLK_FREQ_G = AXIL_CLK_FREQ_G),
         WRITE_EN_G         => false,
         AXI_CLK_FREQ_G     => AXIL_CLK_FREQ_G,
         STATUS_CNT_WIDTH_G => 32,
         ERROR_CNT_WIDTH_G  => 16)
      port map (
         pgpTxClk        => pgpClk,
         pgpTxClkRst     => pgpClkRst,
         pgpTxIn         => pgpTxIn,
         pgpTxOut        => pgpTxOut,
         pgpRxClk        => pgpClk,
         pgpRxClkRst     => pgpClkRst,
         pgpRxIn         => pgpRxIn,
         pgpRxOut        => pgpRxOut,
         axilClk         => axilClk,
         axilRst         => axilClkRst,
         axilReadMaster  => sAxilReadMasters(1),
         axilReadSlave   => sAxilReadSlaves(1),
         axilWriteMaster => sAxilWriteMasters(1),
         axilWriteSlave  => sAxilWriteSlaves(1));

   leds(0) <= pgpRxOut.linkReady;
   leds(1) <= pgpTxOut.linkReady;

   -------------------------------------------------------------------------------------------------
   -- AXI Stream FIFOS
   -------------------------------------------------------------------------------------------------
   AXIS_FIFOS : for i in 1 downto 0 generate
      AxiStreamFifo_1 : entity work.AxiStreamFifo
         generic map (
            TPD_G               => TPD_G,
--            INT_PIPE_STAGES_G   => INT_PIPE_STAGES_G,
--            PIPE_STAGES_G       => PIPE_STAGES_G,
            SLAVE_READY_EN_G    => false,  -- Only use pause
            VALID_THOLD_G       => 1,
            BRAM_EN_G           => true,
            USE_BUILT_IN_G      => false,
            GEN_SYNC_FIFO_G     => false,
--            CASCADE_SIZE_G      => CASCADE_SIZE_G,
            FIFO_ADDR_WIDTH_G   => AXIS_FIFO_ADDR_WIDTH_G,
            FIFO_FIXED_THRESH_G => true,
            FIFO_PAUSE_THRESH_G => 2**AXIS_FIFO_ADDR_WIDTH_G-300,
--            CASCADE_PAUSE_SEL_G => CASCADE_PAUSE_SEL_G,
            SLAVE_AXI_CONFIG_G  => AXIS_CONFIG_G,
            MASTER_AXI_CONFIG_G => SSI_PGP2B_CONFIG_C)
         port map (
            sAxisClk    => axisClk,
            sAxisRst    => axisClkRst,
            sAxisMaster => axisTxMasters(i),
            sAxisSlave  => axisTxSlaves(i),
            sAxisCtrl   => axisTxCtrl(i),
            mAxisClk    => pgpClk,
            mAxisRst    => pgpClkRst,
            mAxisMaster => pgpTxMasters(i+1),
            mAxisSlave  => pgpTXSlaves(i+1));
   end generate AXIS_FIFOS;


end architecture rtl;
