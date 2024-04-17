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

entity SugoiManagerRx7Series is
   generic (
      TPD_G           : time    := 1 ns;
      DIFF_PAIR_G     : boolean := true;
      DEVICE_FAMILY_G : string  := "7SERIES";
      IODELAY_GROUP_G : string  := "DESER_GROUP";
      REF_FREQ_G      : real    := 300.0);  -- IDELAYCTRL's REFCLK (in units of Hz)
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
end SugoiManagerRx7Series;

architecture mapping of SugoiManagerRx7Series is

   signal rxIn  : sl;
   signal rxDly : sl;
   signal Q1    : sl;
   signal Q2    : sl;

   attribute IODELAY_GROUP            : string;
   attribute IODELAY_GROUP of U_DELAY : label is IODELAY_GROUP_G;

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

   U_DELAY : IDELAYE2
      generic map (
         REFCLK_FREQUENCY      => REF_FREQ_G,
         HIGH_PERFORMANCE_MODE => "TRUE",
         IDELAY_VALUE          => 0,
         DELAY_SRC             => "IDATAIN",
         IDELAY_TYPE           => "VAR_LOAD")
      port map(
         DATAIN     => '0',
         IDATAIN    => rxIn,
         DATAOUT    => rxDly,
         C          => clk,
         CE         => '0',
         INC        => '0',
         LD         => dlyLoad,
         LDPIPEEN   => '0',
         REGRST     => '0',
         CINVCTRL   => '0',
         CNTVALUEIN => dlyCfg(8 downto 4));

   U_IDDR : IDDR
      generic map (
         DDR_CLK_EDGE => "SAME_EDGE_PIPELINED",  -- "OPPOSITE_EDGE", "SAME_EDGE", or "SAME_EDGE_PIPELINED"
         INIT_Q1      => '0',           -- Initial value of Q1: '0' or '1'
         INIT_Q2      => '0',           -- Initial value of Q2: '0' or '1'
         SRTYPE       => "SYNC")        -- Set/Reset type: "SYNC" or "ASYNC"
      port map (
         Q1 => Q1,                -- 1-bit output for positive edge of clock
         Q2 => Q2,                -- 1-bit output for negative edge of clock
         C  => clk,                     -- 1-bit clock input
         CE => '1',                     -- 1-bit clock enable input
         D  => rxDly,                   -- 1-bit DDR data input
         R  => rst,                     -- 1-bit reset
         S  => '0');                    -- 1-bit set

   rx <= Q1 xor inv;

end mapping;
