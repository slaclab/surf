-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-- Description: Cocotb-facing wrapper for surf.Pgp2bRxPhy
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library surf;
use surf.StdRtlPkg.all;

entity Pgp2bRxPhyWrapper is
   port (
      clk             : in  sl;
      rst             : in  sl;
      phyRxData       : in  slv(15 downto 0) := x"BCBC";
      phyRxDataK      : in  slv(1 downto 0)  := "11";
      phyRxDispErr    : in  slv(1 downto 0)  := (others => '0');
      phyRxDecErr     : in  slv(1 downto 0)  := (others => '0');
      phyRxReady      : in  sl               := '1';
      pgpRxLinkReady  : out sl;
      pgpRxLinkDown   : out sl;
      pgpRxLinkError  : out sl;
      pgpRxOpCodeEn   : out sl;
      pgpRxOpCode     : out slv(7 downto 0);
      pgpRemLinkReady : out sl;
      pgpRemData      : out slv(7 downto 0);
      cellRxPause     : out sl;
      cellRxSOC       : out sl;
      cellRxSOF       : out sl;
      cellRxEOC       : out sl;
      cellRxEOF       : out sl;
      cellRxEOFE      : out sl;
      cellRxData      : out slv(15 downto 0);
      phyRxPolarity   : out slv(0 downto 0);
      phyRxInit       : out sl);
end entity Pgp2bRxPhyWrapper;

architecture rtl of Pgp2bRxPhyWrapper is

begin

   U_DUT : entity surf.Pgp2bRxPhy
      generic map (
         RX_LANE_CNT_G => 1)
      port map (
         pgpRxClk        => clk,
         pgpRxClkRst     => rst,
         pgpRxLinkReady  => pgpRxLinkReady,
         pgpRxLinkDown   => pgpRxLinkDown,
         pgpRxLinkError  => pgpRxLinkError,
         pgpRxOpCodeEn   => pgpRxOpCodeEn,
         pgpRxOpCode     => pgpRxOpCode,
         pgpRemLinkReady => pgpRemLinkReady,
         pgpRemData      => pgpRemData,
         cellRxPause     => cellRxPause,
         cellRxSOC       => cellRxSOC,
         cellRxSOF       => cellRxSOF,
         cellRxEOC       => cellRxEOC,
         cellRxEOF       => cellRxEOF,
         cellRxEOFE      => cellRxEOFE,
         cellRxData      => cellRxData,
         phyRxPolarity   => phyRxPolarity,
         phyRxData       => phyRxData,
         phyRxDataK      => phyRxDataK,
         phyRxDispErr    => phyRxDispErr,
         phyRxDecErr     => phyRxDecErr,
         phyRxReady      => phyRxReady,
         phyRxInit       => phyRxInit);

end architecture rtl;
