-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for surf.Pgp2fcTx
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library surf;
use surf.StdRtlPkg.all;
use surf.Pgp2fcPkg.all;
use surf.AxiStreamPkg.all;

entity Pgp2fcTxWrapper is
   port (
      clk           : in  sl;
      rst           : in  sl;
      txFlush       : in  sl               := '0';
      txFcValid     : in  sl               := '0';
      txFcWord      : in  slv(15 downto 0) := (others => '0');
      txLocData     : in  slv(7 downto 0)  := (others => '0');
      txFlowCntlDis : in  sl               := '0';
      txReset       : in  sl               := '0';
      gtReset       : in  sl               := '0';
      locLinkReady  : in  sl               := '1';
      phyTxReady    : in  sl               := '1';
      locOverflow   : out slv(3 downto 0);
      locPause      : out slv(3 downto 0);
      linkReady     : out sl;
      fcSent        : out sl;
      frameTx       : out sl;
      frameTxErr    : out sl;
      phyTxData     : out slv(15 downto 0);
      phyTxDataK    : out slv(1 downto 0);
      vc0FrameReady : out sl);
end entity Pgp2fcTxWrapper;

architecture rtl of Pgp2fcTxWrapper is

   signal pgpTxSlaves : AxiStreamSlaveArray(3 downto 0);
   signal phyTxLaneOut : Pgp2fcTxPhyLaneOutType;
   signal pgpTxOut : Pgp2fcTxOutType;
   signal pgpTxIn  : Pgp2fcTxInType := PGP2FC_TX_IN_INIT_C;

begin

   pgpTxIn.flush       <= txFlush;
   pgpTxIn.fcValid     <= txFcValid;
   pgpTxIn.fcWord(15 downto 0) <= txFcWord;
   pgpTxIn.locData     <= txLocData;
   pgpTxIn.flowCntlDis <= txFlowCntlDis;
   pgpTxIn.resetTx     <= txReset;
   pgpTxIn.resetGt     <= gtReset;

   locOverflow   <= pgpTxOut.locOverflow;
   locPause      <= pgpTxOut.locPause;
   linkReady     <= pgpTxOut.linkReady;
   fcSent        <= pgpTxOut.fcSent;
   frameTx       <= pgpTxOut.frameTx;
   frameTxErr    <= pgpTxOut.frameTxErr;
   phyTxData     <= phyTxLaneOut.data;
   phyTxDataK    <= phyTxLaneOut.dataK;
   vc0FrameReady <= pgpTxSlaves(0).tReady;

   U_DUT : entity surf.Pgp2fcTx
      generic map (
         NUM_VC_EN_G => 1)
      port map (
         pgpTxClk      => clk,
         pgpTxClkRst   => rst,
         pgpTxIn       => pgpTxIn,
         pgpTxOut      => pgpTxOut,
         locLinkReady  => locLinkReady,
         pgpTxMasters  => (others => AXI_STREAM_MASTER_INIT_C),
         pgpTxSlaves   => pgpTxSlaves,
         locFifoStatus => (others => AXI_STREAM_CTRL_UNUSED_C),
         remFifoStatus => (others => AXI_STREAM_CTRL_UNUSED_C),
         phyTxLaneOut  => phyTxLaneOut,
         phyTxReady    => phyTxReady);

end architecture rtl;
