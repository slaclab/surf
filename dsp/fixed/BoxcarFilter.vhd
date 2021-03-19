-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simple boxcar filter
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;


library surf;
use surf.StdRtlPkg.all;

entity BoxcarFilter is
   generic (
      TPD_G        : time     := 1 ns;
      SIGNED_G     : boolean  := false;  -- Treat data as unsigned by default
      DOB_REG_G    : boolean  := false;  -- Extra reg on doutb (folded into BRAM)
      DATA_WIDTH_G : positive := 16;
      ADDR_WIDTH_G : positive := 10);
   port (
      clk      : in  sl;
      rst      : in  sl;
      -- Inbound Interface
      ibValid  : in  sl := '1';
      ibData   : in  slv(DATA_WIDTH_G-1 downto 0);
      -- Outbound Interface
      obValid  : out sl;
      obData   : out slv(DATA_WIDTH_G-1 downto 0);
      obFull   : out sl;
      obPeriod : out sl);
end BoxcarFilter;

architecture mapping of BoxcarFilter is

   signal intData : slv(DATA_WIDTH_G+ADDR_WIDTH_G-1 downto 0);

begin

   U_Integrator : entity surf.BoxcarIntegrator
      generic map (
         TPD_G        => TPD_G,
         SIGNED_G     => SIGNED_G,
         DOB_REG_G    => DOB_REG_G,
         DATA_WIDTH_G => DATA_WIDTH_G,
         ADDR_WIDTH_G => ADDR_WIDTH_G)
      port map (
         clk      => clk,
         rst      => rst,
         -- Configuration, intCount is 0 based, 0 = 1, 1 = 2, 1023 = 1024
         intCount => (others => '1'),
         -- Inbound Interface
         ibValid  => ibValid,
         ibData   => ibData,
         -- Outbound Interface
         obValid  => obValid,
         obData   => intData,
         obFull   => obFull,
         obPeriod => obPeriod);

   obData <= intData(DATA_WIDTH_G+ADDR_WIDTH_G-1 downto ADDR_WIDTH_G);  -- Truncate the integrator output (power of 2 divide)

end mapping;
