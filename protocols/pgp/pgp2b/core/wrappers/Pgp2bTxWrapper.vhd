-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-- Description: Cocotb-facing wrapper for surf.Pgp2bTx
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library surf;
use surf.StdRtlPkg.all;
use surf.Pgp2bPkg.all;
use surf.AxiStreamPkg.all;

entity Pgp2bTxWrapper is
   port (
      clk            : in  sl;
      rst            : in  sl;
      txFlush        : in  sl              := '0';
      txOpCodeEn     : in  sl              := '0';
      txOpCode       : in  slv(7 downto 0) := (others => '0');
      txLocData      : in  slv(7 downto 0) := (others => '0');
      txFlowCntlDis  : in  sl              := '0';
      txReset        : in  sl              := '0';
      gtReset        : in  sl              := '0';
      locLinkReady   : in  sl              := '1';
      phyTxReady     : in  sl              := '1';
      locOverflow    : out slv(3 downto 0);
      locPause       : out slv(3 downto 0);
      linkReady      : out sl;
      frameTx        : out sl;
      frameTxErr     : out sl;
      phyTxData      : out slv(15 downto 0);
      phyTxDataK     : out slv(1 downto 0);
      vc0FrameReady  : out sl);
end entity Pgp2bTxWrapper;

architecture rtl of Pgp2bTxWrapper is

   signal pgpTxSlaves   : AxiStreamSlaveArray(3 downto 0);
   signal phyTxLanesOut : Pgp2bTxPhyLaneOutArray(0 to 0);
   signal pgpTxOut      : Pgp2bTxOutType;
   signal pgpTxIn       : Pgp2bTxInType := PGP2B_TX_IN_INIT_C;

begin

   pgpTxIn.flush       <= txFlush;
   pgpTxIn.opCodeEn    <= txOpCodeEn;
   pgpTxIn.opCode      <= txOpCode;
   pgpTxIn.locData     <= txLocData;
   pgpTxIn.flowCntlDis <= txFlowCntlDis;
   pgpTxIn.resetTx     <= txReset;
   pgpTxIn.resetGt     <= gtReset;

   locOverflow   <= pgpTxOut.locOverflow;
   locPause      <= pgpTxOut.locPause;
   linkReady     <= pgpTxOut.linkReady;
   frameTx       <= pgpTxOut.frameTx;
   frameTxErr    <= pgpTxOut.frameTxErr;
   phyTxData     <= phyTxLanesOut(0).data;
   phyTxDataK    <= phyTxLanesOut(0).dataK;
   vc0FrameReady <= pgpTxSlaves(0).tReady;

   U_DUT : entity surf.Pgp2bTx
      generic map (
         TX_LANE_CNT_G => 1,
         NUM_VC_EN_G   => 1)
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
         phyTxLanesOut => phyTxLanesOut,
         phyTxReady    => phyTxReady);

end architecture rtl;
