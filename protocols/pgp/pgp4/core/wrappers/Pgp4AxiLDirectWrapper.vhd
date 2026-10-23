-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for surf.Pgp4AxiL register testing
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
use surf.Pgp4Pkg.all;

entity Pgp4AxiLDirectWrapper is
   port (
      S_AXI_ACLK     : in  std_logic                     := '0';
      S_AXI_ARESETN  : in  std_logic                     := '0';
      S_AXI_AWADDR   : in  std_logic_vector(11 downto 0) := (others => '0');
      S_AXI_AWPROT   : in  std_logic_vector(2 downto 0)  := (others => '0');
      S_AXI_AWVALID  : in  std_logic                     := '0';
      S_AXI_AWREADY  : out std_logic;
      S_AXI_WDATA    : in  std_logic_vector(31 downto 0) := (others => '0');
      S_AXI_WSTRB    : in  std_logic_vector(3 downto 0)  := (others => '1');
      S_AXI_WVALID   : in  std_logic                     := '0';
      S_AXI_WREADY   : out std_logic;
      S_AXI_BRESP    : out std_logic_vector(1 downto 0);
      S_AXI_BVALID   : out std_logic;
      S_AXI_BREADY   : in  std_logic                     := '0';
      S_AXI_ARADDR   : in  std_logic_vector(11 downto 0) := (others => '0');
      S_AXI_ARPROT   : in  std_logic_vector(2 downto 0)  := (others => '0');
      S_AXI_ARVALID  : in  std_logic                     := '0';
      S_AXI_ARREADY  : out std_logic;
      S_AXI_RDATA    : out std_logic_vector(31 downto 0);
      S_AXI_RRESP    : out std_logic_vector(1 downto 0);
      S_AXI_RVALID   : out std_logic;
      S_AXI_RREADY   : in  std_logic                     := '0';
      txDisableOut   : out std_logic;
      flowCntlDisOut : out std_logic;
      resetTxOut     : out std_logic;
      resetRxOut     : out std_logic;
      loopbackOut    : out std_logic_vector(2 downto 0));
end entity Pgp4AxiLDirectWrapper;

architecture rtl of Pgp4AxiLDirectWrapper is

   signal axilClk         : sl;
   signal axilRst         : sl;
   signal axilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal axilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;

   signal pgpTxIn  : Pgp4TxInType  := PGP4_TX_IN_INIT_C;
   signal pgpRxIn  : Pgp4RxInType  := PGP4_RX_IN_INIT_C;
   signal pgpTxOut : Pgp4TxOutType := PGP4_TX_OUT_INIT_C;
   signal pgpRxOut : Pgp4RxOutType := PGP4_RX_OUT_INIT_C;

begin

   ---------------------------------------------------------------------------
   -- Flat AXI-Lite shim
   ---------------------------------------------------------------------------
   txDisableOut   <= pgpTxIn.disable;
   flowCntlDisOut <= pgpTxIn.flowCntlDis;
   resetTxOut     <= pgpTxIn.resetTx;
   resetRxOut     <= pgpRxIn.resetRx;
   loopbackOut    <= pgpRxIn.loopback;

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

   ---------------------------------------------------------------------------
   -- DUT hookup
   ---------------------------------------------------------------------------
   U_DUT : entity surf.Pgp4AxiL
      generic map (
         COMMON_TX_CLK_G => true,
         COMMON_RX_CLK_G => true,
         WRITE_EN_G      => true,
         NUM_VC_G        => 1)
      port map (
         pgpTxClk         => axilClk,
         pgpTxRst         => axilRst,
         pgpTxIn          => pgpTxIn,
         pgpTxOut         => pgpTxOut,
         locTxIn          => PGP4_TX_IN_INIT_C,
         phyTxFecByp      => open,
         pgpRxClk         => axilClk,
         pgpRxRst         => axilRst,
         pgpRxIn          => pgpRxIn,
         pgpRxOut         => pgpRxOut,
         locRxIn          => PGP4_RX_IN_INIT_C,
         phyRxClk         => axilClk,
         phyRxRst         => axilRst,
         phyRxFecByp      => open,
         phyRxFecLock     => '0',
         phyRxFecCorInc   => '0',
         phyRxFecUnCorInc => '0',
         txDiffCtrl       => open,
         txPreCursor      => open,
         txPostCursor     => open,
         txPolarity       => open,
         rxPolarity       => open,
         axilClk          => axilClk,
         axilRst          => axilRst,
         axilReadMaster   => axilReadMaster,
         axilReadSlave    => axilReadSlave,
         axilWriteMaster  => axilWriteMaster,
         axilWriteSlave   => axilWriteSlave);

end architecture rtl;
