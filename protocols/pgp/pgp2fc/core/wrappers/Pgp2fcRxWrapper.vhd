-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for surf.Pgp2fcRx
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library surf;
use surf.StdRtlPkg.all;
use surf.Pgp2fcPkg.all;

entity Pgp2fcRxWrapper is
   port (
      clk          : in  sl;
      rst          : in  sl;
      rxFlush      : in  sl               := '0';
      rxReset      : in  sl               := '0';
      rxLoopback   : in  slv(2 downto 0)  := (others => '0');
      phyRxData    : in  slv(15 downto 0) := (others => '0');
      phyRxDataK   : in  slv(1 downto 0)  := (others => '0');
      phyRxDispErr : in  slv(1 downto 0)  := (others => '0');
      phyRxDecErr  : in  slv(1 downto 0)  := (others => '0');
      phyRxReady   : in  sl               := '1';
      phyRxInit    : out sl;
      linkReady    : out sl;
      frameRx      : out sl;
      frameRxErr   : out sl;
      cellError    : out sl;
      linkDown     : out sl;
      linkError    : out sl;
      fcValid      : out sl;
      fcError      : out sl;
      fcWord       : out slv(15 downto 0);
      remLinkReady : out sl;
      remLinkData  : out slv(7 downto 0);
      remOverflow  : out slv(3 downto 0);
      remPause     : out slv(3 downto 0));
end entity Pgp2fcRxWrapper;

architecture rtl of Pgp2fcRxWrapper is

   signal phyRxInitInt : sl;
   signal phyRxLaneIn  : Pgp2fcRxPhyLaneInType := PGP2FC_RX_PHY_LANE_IN_INIT_C;
   signal pgpRxOut     : Pgp2fcRxOutType       := PGP2FC_RX_OUT_INIT_C;
   signal pgpRxIn      : Pgp2fcRxInType        := PGP2FC_RX_IN_INIT_C;

begin

   pgpRxIn.flush    <= rxFlush;
   pgpRxIn.resetRx  <= rxReset;
   pgpRxIn.loopback <= rxLoopback;

   phyRxLaneIn.data    <= phyRxData;
   phyRxLaneIn.dataK   <= phyRxDataK;
   phyRxLaneIn.dispErr <= phyRxDispErr;
   phyRxLaneIn.decErr  <= phyRxDecErr;

   phyRxInit    <= phyRxInitInt;
   linkReady    <= pgpRxOut.linkReady;
   frameRx      <= pgpRxOut.frameRx;
   frameRxErr   <= pgpRxOut.frameRxErr;
   cellError    <= pgpRxOut.cellError;
   linkDown     <= pgpRxOut.linkDown;
   linkError    <= pgpRxOut.linkError;
   fcValid      <= pgpRxOut.fcValid;
   fcError      <= pgpRxOut.fcError;
   fcWord       <= pgpRxOut.fcWord(15 downto 0);
   remLinkReady <= pgpRxOut.remLinkReady;
   remLinkData  <= pgpRxOut.remLinkData;
   remOverflow  <= pgpRxOut.remOverflow;
   remPause     <= pgpRxOut.remPause;

   U_DUT : entity surf.Pgp2fcRx
      port map (
         pgpRxClk      => clk,
         pgpRxClkRst   => rst,
         pgpRxIn       => pgpRxIn,
         pgpRxOut      => pgpRxOut,
         pgpRxMaster   => open,
         remFifoStatus => open,
         phyRxLaneIn   => phyRxLaneIn,
         phyRxReady    => phyRxReady,
         phyRxInit     => phyRxInitInt);

end architecture rtl;
