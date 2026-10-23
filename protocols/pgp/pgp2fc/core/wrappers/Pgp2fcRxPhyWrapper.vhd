-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for surf.Pgp2fcRxPhy
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library surf;
use surf.StdRtlPkg.all;

entity Pgp2fcRxPhyWrapper is
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
      fcValid         : out sl;
      fcWord          : out slv(15 downto 0);
      fcError         : out sl;
      pgpRemLinkReady : out sl;
      pgpRemData      : out slv(7 downto 0);
      cellRxPause     : out sl;
      cellRxSOC       : out sl;
      cellRxSOF       : out sl;
      cellRxEOC       : out sl;
      cellRxEOF       : out sl;
      cellRxEOFE      : out sl;
      cellRxData      : out slv(15 downto 0);
      phyRxInit       : out sl);
end entity Pgp2fcRxPhyWrapper;

architecture rtl of Pgp2fcRxPhyWrapper is

begin

   U_DUT : entity surf.Pgp2fcRxPhy
      port map (
         pgpRxClk        => clk,
         pgpRxClkRst     => rst,
         pgpRxLinkReady  => pgpRxLinkReady,
         pgpRxLinkDown   => pgpRxLinkDown,
         pgpRxLinkError  => pgpRxLinkError,
         fcValid         => fcValid,
         fcWord          => fcWord,
         fcError         => fcError,
         pgpRemLinkReady => pgpRemLinkReady,
         pgpRemData      => pgpRemData,
         cellRxPause     => cellRxPause,
         cellRxSOC       => cellRxSOC,
         cellRxSOF       => cellRxSOF,
         cellRxEOC       => cellRxEOC,
         cellRxEOF       => cellRxEOF,
         cellRxEOFE      => cellRxEOFE,
         cellRxData      => cellRxData,
         phyRxData       => phyRxData,
         phyRxDataK      => phyRxDataK,
         phyRxDispErr    => phyRxDispErr,
         phyRxDecErr     => phyRxDecErr,
         phyRxReady      => phyRxReady,
         phyRxInit       => phyRxInit);

end architecture rtl;
