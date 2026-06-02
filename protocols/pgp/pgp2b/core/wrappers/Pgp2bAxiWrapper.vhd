-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for surf.Pgp2bAxi register testing
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
use surf.Pgp2bPkg.all;

entity Pgp2bAxiWrapper is
   port (
      S_AXI_ACLK      : in  std_logic                     := '0';
      S_AXI_ARESETN   : in  std_logic                     := '0';
      S_AXI_AWADDR    : in  std_logic_vector(11 downto 0) := (others => '0');
      S_AXI_AWPROT    : in  std_logic_vector(2 downto 0)  := (others => '0');
      S_AXI_AWVALID   : in  std_logic                     := '0';
      S_AXI_AWREADY   : out std_logic;
      S_AXI_WDATA     : in  std_logic_vector(31 downto 0) := (others => '0');
      S_AXI_WSTRB     : in  std_logic_vector(3 downto 0)  := (others => '1');
      S_AXI_WVALID    : in  std_logic                     := '0';
      S_AXI_WREADY    : out std_logic;
      S_AXI_BRESP     : out std_logic_vector(1 downto 0);
      S_AXI_BVALID    : out std_logic;
      S_AXI_BREADY    : in  std_logic                     := '0';
      S_AXI_ARADDR    : in  std_logic_vector(11 downto 0) := (others => '0');
      S_AXI_ARPROT    : in  std_logic_vector(2 downto 0)  := (others => '0');
      S_AXI_ARVALID   : in  std_logic                     := '0';
      S_AXI_ARREADY   : out std_logic;
      S_AXI_RDATA     : out std_logic_vector(31 downto 0);
      S_AXI_RRESP     : out std_logic_vector(1 downto 0);
      S_AXI_RVALID    : out std_logic;
      S_AXI_RREADY    : in  std_logic                     := '0';
      flowCntlDisOut  : out std_logic;
      resetTxOut      : out std_logic;
      resetRxOut      : out std_logic;
      resetGtOut      : out std_logic;
      loopbackOut     : out std_logic_vector(2 downto 0);
      locDataOut      : out std_logic_vector(7 downto 0);
      locDataEnOut    : out std_logic;
      txDiffCtrlOut   : out std_logic_vector(4 downto 0);
      txPreCursorOut  : out std_logic_vector(4 downto 0);
      txPostCursorOut : out std_logic_vector(4 downto 0));
end entity Pgp2bAxiWrapper;

architecture rtl of Pgp2bAxiWrapper is

   signal axilClk         : sl;
   signal axilRst         : sl;
   signal axilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal axilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;

   signal pgpTxIn : Pgp2bTxInType := PGP2B_TX_IN_INIT_C;
   signal pgpRxIn : Pgp2bRxInType := PGP2B_RX_IN_INIT_C;
   signal locTxIn : Pgp2bTxInType := (
      flush       => '0',
      opCodeEn    => '0',
      opCode      => (others => '0'),
      locData     => x"C3",
      flowCntlDis => '0',
      resetTx     => '0',
      resetGt     => '0');
   signal pgpTxOut : Pgp2bTxOutType := (
      locOverflow => "0101",
      locPause    => "0011",
      phyTxReady  => '1',
      linkReady   => '1',
      frameTx     => '0',
      frameTxErr  => '0');
   signal pgpRxOut : Pgp2bRxOutType := (
      phyRxReady   => '1',
      linkReady    => '1',
      linkPolarity => "10",
      frameRx      => '0',
      frameRxErr   => '0',
      cellError    => '0',
      linkDown     => '0',
      linkError    => '0',
      opCodeEn     => '0',
      opCode       => (others => '0'),
      remLinkReady => '1',
      remLinkData  => x"A5",
      remOverflow  => "0011",
      remPause     => "0101");

   signal statusWord   : slv(63 downto 0);
   signal statusSend   : sl;
   signal txDiffCtrl   : slv(4 downto 0);
   signal txPreCursor  : slv(4 downto 0);
   signal txPostCursor : slv(4 downto 0);

begin

   flowCntlDisOut  <= pgpTxIn.flowCntlDis;
   resetTxOut      <= pgpTxIn.resetTx;
   resetRxOut      <= pgpRxIn.resetRx;
   resetGtOut      <= pgpTxIn.resetGt;
   loopbackOut     <= pgpRxIn.loopback;
   locDataOut      <= pgpTxIn.locData;
   locDataEnOut    <= ite(pgpTxIn.locData = locTxIn.locData, '0', '1');
   txDiffCtrlOut   <= txDiffCtrl;
   txPreCursorOut  <= txPreCursor;
   txPostCursorOut <= txPostCursor;

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

   U_DUT : entity surf.Pgp2bAxi
      generic map (
         COMMON_TX_CLK_G => true,
         COMMON_RX_CLK_G => true,
         WRITE_EN_G      => true)
      port map (
         pgpTxClk        => axilClk,
         pgpTxClkRst     => axilRst,
         pgpTxIn         => pgpTxIn,
         pgpTxOut        => pgpTxOut,
         locTxIn         => locTxIn,
         pgpRxClk        => axilClk,
         pgpRxClkRst     => axilRst,
         pgpRxIn         => pgpRxIn,
         pgpRxOut        => pgpRxOut,
         locRxIn         => PGP2B_RX_IN_INIT_C,
         statusWord      => statusWord,
         statusSend      => statusSend,
         txDiffCtrl      => txDiffCtrl,
         txPreCursor     => txPreCursor,
         txPostCursor    => txPostCursor,
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

end architecture rtl;
