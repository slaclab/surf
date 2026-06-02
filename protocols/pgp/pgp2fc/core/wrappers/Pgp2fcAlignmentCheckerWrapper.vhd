-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for surf.Pgp2fcAlignmentChecker
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library surf;
use surf.StdRtlPkg.all;
use surf.Pgp2fcPkg.all;

entity Pgp2fcAlignmentCheckerWrapper is
   port (
      clk        : in  sl;
      rst        : in  sl;
      data       : in  slv(15 downto 0) := (others => '0');
      dataK      : in  slv(1 downto 0)  := (others => '0');
      dispErr    : in  slv(1 downto 0)  := (others => '0');
      decErr     : in  slv(1 downto 0)  := (others => '0');
      error      : out sl;
      latchError : out sl);
end entity Pgp2fcAlignmentCheckerWrapper;

architecture rtl of Pgp2fcAlignmentCheckerWrapper is

   signal rxLane : Pgp2fcRxPhyLaneInType := PGP2FC_RX_PHY_LANE_IN_INIT_C;

begin

   rxLane.data    <= data;
   rxLane.dataK   <= dataK;
   rxLane.dispErr <= dispErr;
   rxLane.decErr  <= decErr;

   U_DUT : entity surf.Pgp2fcAlignmentChecker
      port map (
         clk    => clk,
         rst    => rst,
         rxLane => rxLane,
         error  => error);

   U_LATCH : entity surf.Pgp2fcAlignmentChecker
      generic map (
         LATCH_ERROR => true)
      port map (
         clk    => clk,
         rst    => rst,
         rxLane => rxLane,
         error  => latchError);

end architecture rtl;
