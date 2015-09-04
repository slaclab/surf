-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AtlasTtcTxEmuTrig.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-06-05
-- Last update: 2014-07-15
-- Platform   : Vivado 2014.1
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AtlasTtcTxEmuPkg.all;

entity AtlasTtcTxEmuTrig is
   generic (
      TPD_G : time := 1 ns);      
   port (
      clk          : in  sl;
      rst          : in  sl;
      sync         : in  sl;
      busy         : in  sl;
      config       : in  AtlasTtcTxEmuConfigType;
      trigBurstCnt : out slv(31 downto 0);
      chA          : out sl);      
end AtlasTtcTxEmuTrig;

architecture rtl of AtlasTtcTxEmuTrig is

   type RegType is record
      chA          : sl;
      cnt          : slv(31 downto 0);
      trigBurstCnt : slv(31 downto 0);
   end record;
   
   constant REG_INIT_C : RegType := (
      '0',
      (others => '0'),
      (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (busy, config, r) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals
      v.chA := '0';

      -- Check if continuous mode
      if config.enbleContinousMode = '1' then
         -- Increment the counter
         v.cnt := r.cnt + 1;
         -- Check the counter value
         if r.cnt = config.trigPeriod then
            -- Reset the counter
            v.cnt := (others => '0');
            -- Set the trigger flag
            v.chA := not(busy);
         end if;
      -- Check if burst mode and not burst reset
      elsif (config.enbleBurstMode = '1') and (config.burstRst = '0') then
         -- Increment the counter
         v.cnt := r.cnt + 1;
         -- Check the counter value
         if r.cnt = config.trigPeriod then
            -- Reset the counter
            v.cnt := (others => '0');
            -- Check the burst counter and busy status
            if (config.trigBurstCnt /= r.trigBurstCnt) and (busy = '0') then
               -- Increment the counter
               v.trigBurstCnt := r.trigBurstCnt + 1;
               -- Set the trigger flag
               v.chA          := '1';
            end if;
         end if;
      else
         -- Reset the counter
         v.cnt := (others => '0');
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      chA          <= r.chA;
      trigBurstCnt <= r.trigBurstCnt;
      
   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         -- Check for reset
         if (rst = '1') then
            r <= REG_INIT_C after TPD_G;
         else
            -- Phase up with the time multiplexer
            if sync = '1' then
               r <= rin after TPD_G;
            end if;
            -- Check for continuous reset
            if (config.rstCnt(0) = '1') then
               -- Reset the counter
               r.cnt <= (others => '0') after TPD_G;
            end if;
            -- Check for burst reset
            if config.burstRst = '1' then
               -- Reset the counter
               r.trigBurstCnt <= (others => '0') after TPD_G;
               -- Check if not continuous mode
               if config.enbleContinousMode = '0' then
                  -- Block the burst trigger during reset
                  r.chA <= '0' after TPD_G;
               end if;
            end if;
         end if;
      end if;
   end process seq;

end rtl;
