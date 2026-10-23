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
use surf.SsiPkg.all;

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
      vc0FrameValid : in  sl               := '0';
      vc0FrameData  : in  slv(15 downto 0) := (others => '0');
      vc0FrameLast  : in  sl               := '0';
      vc0FrameSof   : in  sl               := '0';
      vc0FrameEofe  : in  sl               := '0';
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

   signal pgpTxMasters : AxiStreamMasterArray(3 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal pgpTxSlaves  : AxiStreamSlaveArray(3 downto 0);
   signal phyTxLaneOut : Pgp2fcTxPhyLaneOutType;
   signal pgpTxOut     : Pgp2fcTxOutType;
   signal pgpTxIn      : Pgp2fcTxInType                   := PGP2FC_TX_IN_INIT_C;

begin

   pgpTxIn.flush               <= txFlush;
   pgpTxIn.fcValid             <= txFcValid;
   pgpTxIn.fcWord(15 downto 0) <= txFcWord;
   pgpTxIn.locData             <= txLocData;
   pgpTxIn.flowCntlDis         <= txFlowCntlDis;
   pgpTxIn.resetTx             <= txReset;
   pgpTxIn.resetGt             <= gtReset;

   locOverflow   <= pgpTxOut.locOverflow;
   locPause      <= pgpTxOut.locPause;
   linkReady     <= pgpTxOut.linkReady;
   fcSent        <= pgpTxOut.fcSent;
   frameTx       <= pgpTxOut.frameTx;
   frameTxErr    <= pgpTxOut.frameTxErr;
   phyTxData     <= phyTxLaneOut.data;
   phyTxDataK    <= phyTxLaneOut.dataK;
   vc0FrameReady <= pgpTxSlaves(0).tReady;

   process (vc0FrameData, vc0FrameEofe, vc0FrameLast, vc0FrameSof,
            vc0FrameValid) is
      variable master : AxiStreamMasterType;
   begin
      master := AXI_STREAM_MASTER_INIT_C;
      if vc0FrameValid = '1' then
         master.tValid             := '1';
         master.tData(15 downto 0) := vc0FrameData;
         master.tKeep(1 downto 0)  := "11";
         master.tStrb(1 downto 0)  := "11";
         master.tLast              := vc0FrameLast;
         axiStreamSetUserBit(PGP2FC_AXIS_CONFIG_C, master, SSI_EOFE_C, vc0FrameEofe);
         axiStreamSetUserBit(PGP2FC_AXIS_CONFIG_C, master, SSI_SOF_C, vc0FrameSof, 0);
      end if;
      pgpTxMasters(0) <= master;
   end process;

   U_DUT : entity surf.Pgp2fcTx
      generic map (
         NUM_VC_EN_G => 1)
      port map (
         pgpTxClk      => clk,
         pgpTxClkRst   => rst,
         pgpTxIn       => pgpTxIn,
         pgpTxOut      => pgpTxOut,
         locLinkReady  => locLinkReady,
         pgpTxMasters  => pgpTxMasters,
         pgpTxSlaves   => pgpTxSlaves,
         locFifoStatus => (others => AXI_STREAM_CTRL_UNUSED_C),
         remFifoStatus => (others => AXI_STREAM_CTRL_UNUSED_C),
         phyTxLaneOut  => phyTxLaneOut,
         phyTxReady    => phyTxReady);

end architecture rtl;
