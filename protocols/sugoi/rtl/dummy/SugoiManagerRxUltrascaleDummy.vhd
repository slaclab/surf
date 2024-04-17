-------------------------------------------------------------------------------
-- Title      : SUGOI Protocol: https://confluence.slac.stanford.edu/x/3of_E
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Manager side Receiver
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

entity SugoiManagerRxUltrascale is
   generic (
      TPD_G           : time    := 1 ns;
      DIFF_PAIR_G     : boolean := true;
      DEVICE_FAMILY_G : string  := "ULTRASCALE";
      IODELAY_GROUP_G : string  := "DESER_GROUP";  -- IDELAYCTRL not used in COUNT mode
      REF_FREQ_G      : real    := 300.0);  -- IDELAYCTRL not used in COUNT mode
   port (
      -- Clock and Reset
      clk     : in  sl              := '0';
      rst     : in  sl              := '0';
      -- SELECTIO Ports
      rxP     : in  sl              := '0';
      rxN     : in  sl              := '0';
      -- Delay Configuration
      dlyLoad : in  sl              := '0';
      dlyCfg  : in  slv(8 downto 0) := (others => '0');
      -- Output
      inv     : in  sl              := '0';
      rx      : out sl              := '0');
end SugoiManagerRxUltrascale;

architecture mapping of SugoiManagerRxUltrascale is

begin

   assert (false)
      report "surf.protocols.sugoi: SugoiManagerRxUltrascale not supported" severity failure;

end mapping;
