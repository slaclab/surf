-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-- Description: Cocotb-facing wrapper for surf.Pgp2bRx
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library surf;
use surf.StdRtlPkg.all;
use surf.Pgp2bPkg.all;
use surf.AxiStreamPkg.all;

entity Pgp2bRxWrapper is
   port (
      clk          : in  sl;
      rst          : in  sl;
      rxFlush      : in  sl               := '0';
      rxReset      : in  sl               := '0';
      rxLoopback   : in  slv(2 downto 0)  := (others => '0');
      phyRxData    : in  slv(15 downto 0) := x"BCBC";
      phyRxDataK   : in  slv(1 downto 0)  := "11";
      phyRxDispErr : in  slv(1 downto 0)  := (others => '0');
      phyRxDecErr  : in  slv(1 downto 0)  := (others => '0');
      phyRxReady   : in  sl               := '1';
      phyRxInit    : out sl;
      phyPolarity  : out sl;
      linkReady    : out sl;
      frameRx      : out sl;
      frameRxErr   : out sl;
      cellError    : out sl;
      linkDown     : out sl;
      linkError    : out sl;
      opCodeEn     : out sl;
      opCode       : out slv(7 downto 0);
      remLinkReady : out sl;
      remLinkData  : out slv(7 downto 0);
      remOverflow  : out slv(3 downto 0);
      remPause     : out slv(3 downto 0));
end entity Pgp2bRxWrapper;

architecture rtl of Pgp2bRxWrapper is

   signal phyRxLanesOut : Pgp2bRxPhyLaneOutArray(0 to 0);
   signal phyRxInitInt  : sl;
   signal phyRxLanesIn  : Pgp2bRxPhyLaneInArray(0 to 0);
   signal pgpRxOut      : Pgp2bRxOutType := PGP2B_RX_OUT_INIT_C;
   signal pgpRxIn       : Pgp2bRxInType  := PGP2B_RX_IN_INIT_C;

begin

   pgpRxIn.flush    <= rxFlush;
   pgpRxIn.resetRx  <= rxReset;
   pgpRxIn.loopback <= rxLoopback;

   phyPolarity  <= phyRxLanesOut(0).polarity;
   linkReady    <= pgpRxOut.linkReady;
   frameRx      <= pgpRxOut.frameRx;
   frameRxErr   <= pgpRxOut.frameRxErr;
   cellError    <= pgpRxOut.cellError;
   linkDown     <= pgpRxOut.linkDown;
   linkError    <= pgpRxOut.linkError;
   opCodeEn     <= pgpRxOut.opCodeEn;
   opCode       <= pgpRxOut.opCode;
   remLinkReady <= pgpRxOut.remLinkReady;
   remLinkData  <= pgpRxOut.remLinkData;
   remOverflow  <= pgpRxOut.remOverflow;
   remPause     <= pgpRxOut.remPause;
   phyRxInit    <= phyRxInitInt;

   phyRxLanesIn(0).data    <= phyRxData;
   phyRxLanesIn(0).dataK   <= phyRxDataK;
   phyRxLanesIn(0).dispErr <= phyRxDispErr;
   phyRxLanesIn(0).decErr  <= phyRxDecErr;

   U_DUT : entity surf.Pgp2bRx
      generic map (
         RX_LANE_CNT_G => 1)
      port map (
         pgpRxClk      => clk,
         pgpRxClkRst   => rst,
         pgpRxIn       => pgpRxIn,
         pgpRxOut      => pgpRxOut,
         pgpRxMaster   => open,
         remFifoStatus => open,
         phyRxLanesOut => phyRxLanesOut,
         phyRxLanesIn  => phyRxLanesIn,
         phyRxReady    => phyRxReady,
         phyRxInit     => phyRxInitInt);

end architecture rtl;
