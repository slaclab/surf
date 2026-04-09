-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for surf.Pgp4LiteRxLowSpeed
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
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.Pgp4Pkg.all;

entity Pgp4LiteRxLowSpeedWrapper is
   port (
      clk           : in  sl;
      rst           : in  sl;
      txValid       : in  sl;
      txReady       : out sl;
      txData        : in  slv(63 downto 0);
      txSof         : in  sl;
      txEof         : in  sl;
      txEofe        : in  sl;
      dlyLoad       : out sl;
      dlyCfg        : out slv(8 downto 0);
      rxValid       : out sl;
      rxLast        : out sl;
      rxData        : out slv(63 downto 0);
      rxDest        : out slv(7 downto 0);
      rxUser        : out slv(15 downto 0);
      S_AXI_ACLK    : in  std_logic                     := '0';
      S_AXI_ARESETN : in  std_logic                     := '0';
      S_AXI_AWADDR  : in  std_logic_vector(11 downto 0) := (others => '0');
      S_AXI_AWPROT  : in  std_logic_vector(2 downto 0)  := (others => '0');
      S_AXI_AWVALID : in  std_logic                     := '0';
      S_AXI_AWREADY : out std_logic;
      S_AXI_WDATA   : in  std_logic_vector(31 downto 0) := (others => '0');
      S_AXI_WSTRB   : in  std_logic_vector(3 downto 0)  := (others => '1');
      S_AXI_WVALID  : in  std_logic                     := '0';
      S_AXI_WREADY  : out std_logic;
      S_AXI_BRESP   : out std_logic_vector(1 downto 0);
      S_AXI_BVALID  : out std_logic;
      S_AXI_BREADY  : in  std_logic                     := '0';
      S_AXI_ARADDR  : in  std_logic_vector(11 downto 0) := (others => '0');
      S_AXI_ARPROT  : in  std_logic_vector(2 downto 0)  := (others => '0');
      S_AXI_ARVALID : in  std_logic                     := '0';
      S_AXI_ARREADY : out std_logic;
      S_AXI_RDATA   : out std_logic_vector(31 downto 0);
      S_AXI_RRESP   : out std_logic_vector(1 downto 0);
      S_AXI_RVALID  : out std_logic;
      S_AXI_RREADY  : in  std_logic                     := '0');
end entity Pgp4LiteRxLowSpeedWrapper;

architecture rtl of Pgp4LiteRxLowSpeedWrapper is

   signal axilClk         : sl;
   signal axilRst         : sl;
   signal axilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal axilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;

   signal pgpTxIn      : Pgp4TxInType := PGP4_TX_IN_INIT_C;
   signal pgpTxMaster  : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal pgpTxSlave   : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal phyTxValid   : sl;
   signal phyTxData    : slv(63 downto 0);
   signal phyTxHeader  : slv(1 downto 0);
   signal serWord      : slv(65 downto 0);
   signal deserData    : Slv8Array(0 downto 0);
   signal dlyLoads     : slv(0 downto 0);
   signal dlyCfgs      : Slv9Array(0 downto 0);
   signal rxMasters    : AxiStreamMasterArray(0 downto 0);

begin

   txReady <= pgpTxSlave.tReady;
   dlyLoad <= dlyLoads(0);
   dlyCfg  <= dlyCfgs(0);
   rxValid <= rxMasters(0).tValid;
   rxLast  <= rxMasters(0).tLast;
   rxData  <= rxMasters(0).tData(63 downto 0);
   rxDest  <= rxMasters(0).tDest(7 downto 0);
   rxUser  <= rxMasters(0).tUser(15 downto 0);

   pgpTxIn.disable     <= '0';
   pgpTxIn.flowCntlDis <= '1';
   pgpTxIn.resetTx     <= '0';
   pgpTxIn.skpInterval <= (others => '0');
   pgpTxIn.opCodeEn    <= '0';
   pgpTxIn.opCodeData  <= (others => '0');
   pgpTxIn.locData     <= (others => '0');

   pgpTxMaster.tValid             <= txValid;
   pgpTxMaster.tData(63 downto 0) <= txData;
   pgpTxMaster.tKeep(7 downto 0)  <= X"FF";
   pgpTxMaster.tStrb(7 downto 0)  <= X"FF";
   pgpTxMaster.tLast              <= txEof;
   pgpTxMaster.tUser(1)           <= txSof;
   pgpTxMaster.tUser(14)          <= txEofe;

   serWord(63 downto 0)  <= phyTxData;
   serWord(65 downto 64) <= phyTxHeader;

   U_Sh : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         ADDR_WIDTH => 12)
      port map (
         S_AXI_ACLK      => S_AXI_ACLK,
         S_AXI_ARESETN   => S_AXI_ARESETN,
         S_AXI_AWADDR    => S_AXI_AWADDR,
         S_AXI_AWPROT    => S_AXI_AWPROT,
         S_AXI_AWVALID   => S_AXI_AWVALID,
         S_AXI_AWREADY   => S_AXI_AWREADY,
         S_AXI_WDATA     => S_AXI_WDATA,
         S_AXI_WSTRB     => S_AXI_WSTRB,
         S_AXI_WVALID    => S_AXI_WVALID,
         S_AXI_WREADY    => S_AXI_WREADY,
         S_AXI_BRESP     => S_AXI_BRESP,
         S_AXI_BVALID    => S_AXI_BVALID,
         S_AXI_BREADY    => S_AXI_BREADY,
         S_AXI_ARADDR    => S_AXI_ARADDR,
         S_AXI_ARPROT    => S_AXI_ARPROT,
         S_AXI_ARVALID   => S_AXI_ARVALID,
         S_AXI_ARREADY   => S_AXI_ARREADY,
         S_AXI_RDATA     => S_AXI_RDATA,
         S_AXI_RRESP     => S_AXI_RRESP,
         S_AXI_RVALID    => S_AXI_RVALID,
         S_AXI_RREADY    => S_AXI_RREADY,
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

   U_TX : entity surf.Pgp4TxLite
      generic map (
         NUM_VC_G         => 1,
         PGP_COMMON_CLK_G => true,
         SKIP_EN_G        => false,
         FLOW_CTRL_EN_G   => false)
      port map (
         pgpTxClk        => clk,
         pgpTxRst        => rst,
         pgpTxIn         => pgpTxIn,
         pgpTxOut        => open,
         pgpTxActive     => '1',
         pgpTxMasters(0) => pgpTxMaster,
         pgpTxSlaves(0)  => pgpTxSlave,
         phyTxActive     => '1',
         phyTxReady      => '1',
         phyTxValid      => phyTxValid,
         phyTxStart      => open,
         phyTxData       => phyTxData,
         phyTxHeader     => phyTxHeader);

   U_Serializer : entity surf.Gearbox
      generic map (
         SLAVE_WIDTH_G  => 66,
         MASTER_WIDTH_G => 8)
      port map (
         clk         => clk,
         rst         => rst,
         slaveData   => serWord,
         slaveValid  => phyTxValid,
         slaveReady  => open,
         masterData  => deserData(0),
         masterValid => open,
         masterReady => '1');

   U_DUT : entity surf.Pgp4LiteRxLowSpeed
      generic map (
         SIMULATION_G       => true,
         DLY_STEP_SIZE_G    => 1,
         NUM_LANE_G         => 1,
         STATUS_CNT_WIDTH_G => 8,
         ERROR_CNT_WIDTH_G  => 4,
         AXIL_CLK_FREQ_G    => 100.0E+6,
         AXIL_BASE_ADDR_G   => x"00000000")
      port map (
         deserClk        => clk,
         deserRst        => rst,
         deserData       => deserData,
         dlyLoad         => dlyLoads,
         dlyCfg          => dlyCfgs,
         pgpRxMasters    => rxMasters,
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

end architecture rtl;
