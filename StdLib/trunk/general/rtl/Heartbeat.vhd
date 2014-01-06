-------------------------------------------------------------------------------
-- Title      : Heartbeat
-------------------------------------------------------------------------------
-- File       : Heartbeat.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-04-30
-- Last update: 2013-11-22
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Heartbeat LED output
-------------------------------------------------------------------------------
-- Copyright (c) 2013 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;

entity Heartbeat is
   generic (
      TPD_G        : time   := 1 ns;
      USE_DSP48_G  : string := "no";
      PERIOD_IN_G  : real   := 6.4E-9;   --units of seconds
      PERIOD_OUT_G : real   := 1.0E-0);  --units of seconds
   port (
      clk : in  sl;
      o   : out sl);
begin
   -- USE_DSP48_G check
   assert ((USE_DSP48_G = "yes") or (USE_DSP48_G = "no") or (USE_DSP48_G = "auto") or (USE_DSP48_G = "automax"))
      report "USE_DSP48_G must be either yes, no, auto, or automax"
      severity failure;
end entity Heartbeat;

architecture rtl of Heartbeat is
   
   constant CNT_SIZE_C : natural                             := getTimeRatio(PERIOD_OUT_G, getRealMult(2, PERIOD_IN_G));
   constant CNT_MAX_C  : slv(bitSize(CNT_SIZE_C)-1 downto 0) := conv_std_logic_vector((CNT_SIZE_C-1), bitSize(CNT_SIZE_C));

   signal cnt    : slv(bitSize(CNT_SIZE_C)-1 downto 0) := (others => '0');
   signal toggle : sl                                  := '0';

   -- Attribute for XST
   attribute use_dsp48        : string;
   attribute use_dsp48 of cnt : signal is USE_DSP48_G;
   
begin
   o <= toggle;

   process (clk)
   begin
      if rising_edge(clk) then
         --check for max value
         if cnt = CNT_MAX_C then
            --reset the counter
            cnt    <= (others => '0') after TPD_G;
            --toggle the output bit
            toggle <= not(toggle);
         else
            --increment the counter
            cnt <= cnt + 1 after TPD_G;
         end if;
      end if;
   end process;

end architecture rtl;
