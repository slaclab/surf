-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-- Description: Cocotb-facing wrapper for surf.Pgp2bTxPhy
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library surf;
use surf.StdRtlPkg.all;

entity Pgp2bTxPhyWrapper is
   port (
      clk             : in  sl;
      rst             : in  sl;
      pgpTxOpCodeEn   : in  sl               := '0';
      pgpTxOpCode     : in  slv(7 downto 0)  := (others => '0');
      pgpLocLinkReady : in  sl               := '1';
      pgpLocData      : in  slv(7 downto 0)  := x"5A";
      cellTxSOC       : in  sl               := '0';
      cellTxSOF       : in  sl               := '0';
      cellTxEOC       : in  sl               := '0';
      cellTxEOF       : in  sl               := '0';
      cellTxEOFE      : in  sl               := '0';
      cellTxData      : in  slv(15 downto 0) := (others => '0');
      phyTxReady      : in  sl               := '1';
      pgpTxLinkReady  : out sl;
      phyTxData       : out slv(15 downto 0);
      phyTxDataK      : out slv(1 downto 0));
end entity Pgp2bTxPhyWrapper;

architecture rtl of Pgp2bTxPhyWrapper is

begin

   U_DUT : entity surf.Pgp2bTxPhy
      generic map (
         TX_LANE_CNT_G => 1)
      port map (
         pgpTxClk        => clk,
         pgpTxClkRst     => rst,
         pgpTxLinkReady  => pgpTxLinkReady,
         pgpTxOpCodeEn   => pgpTxOpCodeEn,
         pgpTxOpCode     => pgpTxOpCode,
         pgpLocLinkReady => pgpLocLinkReady,
         pgpLocData      => pgpLocData,
         cellTxSOC       => cellTxSOC,
         cellTxSOF       => cellTxSOF,
         cellTxEOC       => cellTxEOC,
         cellTxEOF       => cellTxEOF,
         cellTxEOFE      => cellTxEOFE,
         cellTxData      => cellTxData,
         phyTxData       => phyTxData,
         phyTxDataK      => phyTxDataK,
         phyTxReady      => phyTxReady);

end architecture rtl;
