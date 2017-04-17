-------------------------------------------------------------------------------
-- File       : AxiAd9467Mon.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-09-23
-- Last update: 2014-09-24
-------------------------------------------------------------------------------
-- Description: AD9467 Monitor Module
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

use work.StdRtlPkg.all;

entity AxiAd9467Mon is
   generic (
      TPD_G          : time := 1 ns;
      ADC_CLK_FREQ_G : real := 250.0E+6);  -- units of Hz
   port (
      adcClk     : in  sl;
      adcRst     : in  sl;
      adcData    : in  slv(15 downto 0);
      adcDataMon : out Slv16Array(0 to 15));            
end AxiAd9467Mon;

architecture rtl of AxiAd9467Mon is
   
   constant MAX_CNT_C : natural := getTimeRatio(ADC_CLK_FREQ_G, 1.0);  -- 1 second refresh rate
   
   type StateType is (
      IDLE_S,
      SMPL_S);

   type RegType is record
      cnt        : natural range 0 to MAX_CNT_C;
      smplCnt    : natural range 0 to 15;
      adcDataMon : Slv16Array(0 to 15);
      state      : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      0,
      0,
      (others => x"0000"),
      IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
begin

   comb : process (adcData, adcRst, r) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Increment the counter
      v.cnt := r.cnt + 1;

      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check the counter
            if r.cnt = MAX_CNT_C then
               -- Reset the counter
               v.cnt   := 0;
               -- Next State
               v.state := SMPL_S;
            end if;
         ----------------------------------------------------------------------
         when SMPL_S =>
            -- Sample the ADC value
            v.adcDataMon(r.smplCnt) := adcData;
            -- Increment the counter
            v.smplCnt               := r.smplCnt + 1;
            -- Check the counter
            if r.smplCnt = 15 then
               -- Reset the counter
               v.smplCnt := 0;
               -- Next State
               v.state   := IDLE_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (adcRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      adcDataMon <= r.adcDataMon;

   end process comb;

   seq : process (adcClk) is
   begin
      if rising_edge(adcClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
