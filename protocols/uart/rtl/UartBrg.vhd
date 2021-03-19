-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: UART Baud Rate Generator
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


library surf;
use surf.StdRtlPkg.all;

entity UartBrg is

   generic (
      CLK_FREQ_G   : real    := 125.0E6;  -- Default 125 MHz
      BAUD_RATE_G  : integer := 115200;   -- Default 115.2 kbps
      MULTIPLIER_G : integer := 16);
   port (
      clk       : in  sl;
      rst       : in  sl;
      baudClkEn : out sl);

end entity UartBrg;

architecture rtl of UartBrg is

   constant CLK_DIV_C : integer := integer(CLK_FREQ_G / real(BAUD_RATE_G * MULTIPLIER_G)) - 1;

   type RegType is record
      count     : integer;
      baudClkEn : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      count     => 0,
      baudClkEn => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : Regtype;

begin

   comb : process (r, rst) is
      variable v : RegType;
   begin
      v := r;

      v.count     := r.count + 1;
      v.baudClkEn := '0';
      if (r.count = CLK_DIV_C) then
         v.count     := 0;
         v.baudClkEn := '1';
      end if;

      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      rin       <= v;
      baudClkEn <= r.baudClkEn;
   end process;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin;
      end if;
   end process;


end architecture rtl;
