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

library unisim;
use unisim.vcomponents.all;

entity SugoiManagerRx is
   generic (
      TPD_G           : time   := 1 ns;
      SIM_DEVICE_G    : string := "ULTRASCALE";
      IODELAY_GROUP_G : string := "DESER_GROUP";  -- IDELAYCTRL not used in COUNT mode
      REF_FREQ_G      : real   := 300.0);         -- IDELAYCTRL not used in COUNT mode
   port (
      -- Clock and Reset
      clk     : in  sl;
      rst     : in  sl;
      -- SELECTIO Ports
      rxP     : in  sl;
      rxN     : in  sl;
      -- Delay Configuration
      dlyLoad : in  sl;
      dlyCfg  : in  slv(8 downto 0);
      -- Output
      inv     : in  sl;
      rx      : out sl);
end SugoiManagerRx;

architecture mapping of SugoiManagerRx is

   signal rxIn  : sl;
   signal rxDly : sl;
   signal clkL  : sl;
   signal Q1    : sl;
   signal Q2    : sl;

begin

   GEN_7SERIES : if (DEVICE_FAMILY_G = "7SERIES") generate
      U_SugoiManagerRx_1 : entity surf.SugoiManagerRx7Series
         generic map (
            TPD_G           => TPD_G,
            SIM_DEVICE_G    => SIM_DEVICE_G,
            IODELAY_GROUP_G => IODELAY_GROUP_G,
            REF_FREQ_G      => REF_FREQ_G)
         port map (
            clk     => clk,             -- [in]
            rst     => rst,             -- [in]
            rxP     => rxP,             -- [in]
            rxN     => rxN,             -- [in]
            dlyLoad => dlyLoad,         -- [in]
            dlyCfg  => dlyCfg,          -- [in]
            inv     => inv,             -- [in]
            rx      => rx);             -- [out]

   end generate GEN_7SERIES;

   GEN_ULTRASCALE : if (DEVICE_FAMILY_G = "ULTRASCALE" or DEVICE_FAMILY_G = "ULTRASCALE_PLUS") generate
      U_SugoiManagerRx_1 : entity surf.SugoiManagerRxUltrascale
         generic map (
            TPD_G           => TPD_G,
            SIM_DEVICE_G    => SIM_DEVICE_G,
            IODELAY_GROUP_G => IODELAY_GROUP_G,
            REF_FREQ_G      => REF_FREQ_G)
         port map (
            clk     => clk,             -- [in]
            rst     => rst,             -- [in]
            rxP     => rxP,             -- [in]
            rxN     => rxN,             -- [in]
            dlyLoad => dlyLoad,         -- [in]
            dlyCfg  => dlyCfg,          -- [in]
            inv     => inv,             -- [in]
            rx      => rx);             -- [out]

   end generate GEN_ULTRASCALE;


end mapping;
