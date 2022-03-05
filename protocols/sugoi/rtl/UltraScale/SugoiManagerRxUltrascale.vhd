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

entity SugoiManagerRxUltrascale is
   generic (
      TPD_G           : time    := 1 ns;
      DIFF_PAIR_G     : boolean := true;
      DEVICE_FAMILY_G : string  := "ULTRASCALE";
      IODELAY_GROUP_G : string  := "DESER_GROUP";  -- IDELAYCTRL not used in COUNT mode
      REF_FREQ_G      : real    := 300.0);  -- IDELAYCTRL not used in COUNT mode
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
end SugoiManagerRxUltrascale;

architecture mapping of SugoiManagerRxUltrascale is

   signal rxIn  : sl;
   signal rxDly : sl;
   signal clkL  : sl;
   signal Q1    : sl;
   signal Q2    : sl;

begin

   GEN_LVDS : if (DIFF_PAIR_G = true) generate
      U_IBUFDS : IBUFDS
         port map (
            I  => rxP,
            IB => rxN,
            O  => rxIn);
   end generate;
   GEN_CMOS : if (DIFF_PAIR_G = false) generate
      U_IBUF : IBUF
         port map (
            I => rxP,
            O => rxIn);
   end generate;

   U_DELAY : entity surf.Idelaye3Wrapper
      generic map (
         DELAY_FORMAT     => "COUNT",
         SIM_DEVICE       => DEVICE_FAMILY_G,
         DELAY_VALUE      => 0,
         REFCLK_FREQUENCY => REF_FREQ_G,  -- IDELAYCTRL not used in COUNT mode
         UPDATE_MODE      => "ASYNC",
         CASCADE          => "NONE",
         DELAY_SRC        => "IDATAIN",
         DELAY_TYPE       => "VAR_LOAD")
      port map(
         DATAIN      => '0',
         IDATAIN     => rxIn,
         DATAOUT     => rxDly,
         CLK         => clk,
         RST         => rst,
         CE          => '0',
         INC         => '0',
         LOAD        => dlyLoad,
         EN_VTC      => '0',
         CASC_IN     => '0',
         CASC_RETURN => '0',
         CNTVALUEIN  => dlyCfg);

   U_IDDR : IDDRE1
      generic map (
         DDR_CLK_EDGE => "SAME_EDGE_PIPELINED")  -- "OPPOSITE_EDGE", "SAME_EDGE", or "SAME_EDGE_PIPELINED"
      port map (
         Q1 => Q1,
         Q2 => Q2,
         C  => clk,                     -- 1-bit input: High-speed clock
         CB => clkL,   -- 1-bit input: Inversion of High-speed clock C
         D  => rxDly,                   -- 1-bit input: Serial Data Input
         R  => rst);                    -- 1-bit input: Active High Async Reset

   clkL <= not(clk);

   rx <= Q1 xor inv;

end mapping;
