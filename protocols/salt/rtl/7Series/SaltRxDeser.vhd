-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper for SelectioDeser
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;

entity SaltRxDeser is
   generic (
      TPD_G           : time   := 1 ns;
      SIM_DEVICE_G    : string := "ULTRASCALE";
      IODELAY_GROUP_G : string := "SALT_GROUP";
      REF_FREQ_G      : real   := 200.0);  -- IDELAYCTRL's REFCLK (in units of Hz)
   port (
      -- SELECTIO Ports
      rxP     : in  sl;
      rxN     : in  sl;
      -- Clock and Reset Interface
      clkx4   : in  sl;
      clkx1   : in  sl;
      rstx1   : in  sl;
      -- Delay Configuration
      dlyLoad : in  sl;
      dlyCfg  : in  slv(8 downto 0);
      -- Output
      dataOut : out slv(7 downto 0));
end SaltRxDeser;

architecture mapping of SaltRxDeser is

begin

   U_Deser : entity surf.SelectioDeserLane7Series
      generic map (
         TPD_G           => TPD_G,
         IODELAY_GROUP_G => IODELAY_GROUP_G,
         REF_FREQ_G      => REF_FREQ_G)
      port map (
         -- SELECTIO Ports
         rxP     => rxP,
         rxN     => rxN,
         -- Clock and Reset Interface
         clkx4   => clkx4,
         clkx1   => clkx1,
         rstx1   => rstx1,
         -- Delay Configuration
         dlyLoad => dlyLoad,
         dlyCfg  => dlyCfg,
         -- Output
         dataOut => dataOut);

end mapping;
