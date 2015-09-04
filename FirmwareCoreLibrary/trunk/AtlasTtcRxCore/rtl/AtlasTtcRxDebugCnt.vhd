-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AtlasTtcRxDebugCnt.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-11-13
-- Last update: 2014-11-13
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: RTL for the ECR and EC debugging (no resets)
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AtlasTtcRxPkg.all;

entity AtlasTtcRxDebugCnt is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Trigger Signals
      trigL1In    : in  sl;
      bc          : in  AtlasTTCRxBcType;
      eventCnt    : out slv(23 downto 0);
      eventRstCnt : out slv(7 downto 0);
      ecrDet      : out sl;
      -- Global Signals
      locClk      : in  sl;
      locClkEn    : in  sl;
      locRst      : in  sl);   
end AtlasTtcRxDebugCnt;

architecture rtl of AtlasTtcRxDebugCnt is

   constant MAX_CNT_C : slv(31 downto 0) := (others => '1');

   type RegType is record
      ecrDet       : sl;
      eventCnt     : slv(23 downto 0);
      nextEventCnt : slv(23 downto 0);
      eventRstCnt  : slv(7 downto 0);
   end record;
   
   constant REG_INIT_C : RegType := (
      ecrDet       => '0',
      eventCnt     => (others => '0'),
      nextEventCnt => (others => '0'),
      eventRstCnt  => (others => '0')); 

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
begin

   comb : process (bc, locClkEn, r, trigL1In) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;
      
      -- Reset the strobing signals
      v.ecrDet := '0';
      
      -- Check if we need to reset the event counter
      if (bc.valid = '1') and (bc.cmdData(1) = '1') then
         -- Reset the counter
         v.nextEventCnt := (others => '0');
         -- Increment the event reset counter
         v.eventRstCnt  := r.eventRstCnt + 1;
         -- Assert the flag
         v.ecrDet       := '1';
      -- Check for a Level-1 Trigger
      elsif (locClkEn = '1') and (trigL1In = '1') then
         -- Set the event counter output
         v.eventCnt := r.nextEventCnt;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      eventCnt    <= r.eventCnt;
      eventRstCnt <= r.eventRstCnt;
      
   end process comb;

   seq : process (locClk) is
   begin
      if rising_edge(locClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
