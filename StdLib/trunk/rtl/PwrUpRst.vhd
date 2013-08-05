-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PwrUpRst.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-30
-- Last update: 2013-08-02
-- Platform   : ISE 14.5
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Synchronizes a reset signal and holds it for a parametized
-- number of cycles.
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
      IN_POLARITY_G  : sl                             := '1';
      OUT_POLARITY_G : sl                             := '1';
      USE_DSP48_G    : string                         := "auto";
      DURATION_G     : natural range 0 to ((2**31)-1) := 156250000);
   port (
      arst   : in  sl := not IN_POLARITY_G;
      clk    : in  sl;
      rstOut : out sl);
begin
   -- USE_DSP48_G check
   assert ((USE_DSP48_G = "yes") or (USE_DSP48_G = "no") or (USE_DSP48_G = "auto") or (USE_DSP48_G = "automax"))
      report "USE_DSP48_G must be either yes, no, auto, or automax"
      severity failure;
end PwrUpRst;

architecture rtl of PwrUpRst is

   constant CNT_SIZE_C : natural := ite(SIM_SPEEDUP_G, 127, (DURATION_G-1));

   signal rstSync : sl;

   signal rst : sl                                := OUT_POLARITY_G;
   signal cnt : natural range 0 to (DURATION_G-1) := 0;

   -- Attribute for XST
   attribute use_dsp48        : string;
   attribute use_dsp48 of cnt : signal is USE_DSP48_G;
   
begin

   RstSync_1 : entity work.RstSync
      generic map (
         TPD_G           => TPD_G,
         IN_POLARITY_G   => IN_POLARITY_G,
         OUT_POLARITY_G  => OUT_POLARITY_G)
      port map (
         clk      => clk,
         asyncRst => arst,
         syncRst  => rstSync);

   process (clk, rstSync)
   begin
      if rstSync = OUT_POLARITY_G then
         rst <= OUT_POLARITY_G after TPD_G;
         cnt <= 0              after TPD_G;
      elsif rising_edge(clk) then
         if cnt = CNT_SIZE_C then
            rst <= not OUT_POLARITY_G after TPD_G;
         else
            rst <= OUT_POLARITY_G after TPD_G;
            cnt <= cnt + 1        after TPD_G;
         end if;
      end if;
   end process;

   rstOut <= rst;
   
end rtl;
