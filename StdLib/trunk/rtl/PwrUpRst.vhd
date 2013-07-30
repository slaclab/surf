-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PwrUpRst.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-30
-- Last update: 2013-07-30
-- Platform   : ISE 14.5
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2013 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;

entity PwrUpRst is
   generic (
      TPD_G          : time                           := 1 ns;
      SIM_SPEEDUP_G  : boolean                        := false;
      USE_DSP48_G    : string                         := "yes";      
      DURATION_G     : natural range 0 to ((2**31)-1) := 156250000);
   port (
      arst     : in  sl := '0';
      srst     : in  sl := '0';
      clk      : in  sl;
      rstOut   : out sl);
begin
   -- USE_DSP48_G check
   assert ((USE_DSP48_G = "yes") or (USE_DSP48_G = "no") or (USE_DSP48_G = "auto") or (USE_DSP48_G = "automax"))
      report "USE_DSP48_G must be either yes, no, auto, or automax"
      severity failure;
end PwrUpRst;

architecture rtl of PwrUpRst is

   constant CNT_SIZE_C : natural := ite(SIM_SPEEDUP_G,127,(DURATION_G-1));

   signal rst : sl := '1';
   signal cnt : natural range 0 to (DURATION_G-1) := 0;

   -- Attribute for XST
   attribute use_dsp48            : string;
   attribute use_dsp48 of cnt : signal is USE_DSP48_G;
   
begin

   rstOut <= rst;

   process(clk)
   begin
      if arst = '1' then
         rst <= '1' after TPD_G;
         cnt <= 0 after TPD_G;
      elsif rising_edge(clk) then
         if srst = '1' then
            rst <= '1' after TPD_G;
            cnt <= 0 after TPD_G;
         else
            if cnt = CNT_SIZE_C then
               rst <= '0' after TPD_G;
            else
               rst <= '1' after TPD_G;
               cnt <= cnt + 1 after TPD_G;               
            end if;
         end if;
      end if;
   end process;
   
end rtl;
