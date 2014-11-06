---------------------------------------------------------------------------------
-- Title         : Gigabit Ethernet (1000 BASE X) ability match
-- Project       : General Purpose Core
---------------------------------------------------------------------------------
-- File          : AbilityMatch.vhd
-- Author        : Kurtis Nishimura, kurtisn@slac.stanford.edu
-- Created       : 05/27/2014
---------------------------------------------------------------------------------
-- Description:
-- Ability match for auto-negotiation (Clause 37)
---------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
---------------------------------------------------------------------------------
-- Modification history:
-- 05/22/2014: created.
---------------------------------------------------------------------------------

LIBRARY ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.StdRtlPkg.all;

entity AbilityMatch is 
   generic (
      TPD_G         : time                 := 1 ns
   );
   port ( 

      -- System clock, reset & control
      ethRxClk          : in  sl;               -- Master clock (62.5 MHz)
      ethRxClkRst       : in  sl;               -- Synchronous reset input
      -- Link is stable
      ethRxLinkSync     : in  sl;               -- Synchronized
      -- Entering a new state (abMatch should be reset on new state)
      newState          : in  sl;
      -- Output match signal
      abilityMatch      : out sl;               -- Ability match output signal
      ability           : out slv(15 downto 0); -- Current ability register
      -- Physical Interface Signals
      phyRxData         : in  slv(15 downto 0); -- PHY receive data
      phyRxDataK        : in  slv( 1 downto 0)  -- PHY receive data is K character
   ); 

end AbilityMatch;


-- Define architecture
architecture rtl of GigEthAutoNeg is

   -- 8B10B Characters and code pairs
   constant K_COM_C  : slv(7 downto 0) := "10111100"; -- K28.5, 0xBC
   constant D_215_C  : slv(7 downto 0) := "10110101"; -- D21.5, 0xB5
   constant D_022_C  : slv(7 downto 0) := "01000010"; -- D2.2,  0x42
   constant D_056_C  : slv(7 downto 0) := "11000101"; -- D5.6,  0xC5
   constant D_162_C  : slv(7 downto 0) := "01010000"; -- D16.2, 0x50
   
   -- Ordered sets
   constant OS_C1_C  : slv(15 downto 0) := D_215_C & K_COM_C; -- /C1/
   constant OS_C2_C  : slv(15 downto 0) := D_022_C & K_COM_C; -- /C2/
   constant OS_I1_C  : slv(15 downto 0) := D_056_C & K_COM_C; -- /I1/
   constant OS_I2_C  : slv(15 downto 0) := D_162_C & K_COM_C; -- /I2/
   constant OS_BL_C  : slv(15 downto 0) := (others => '0');   -- Breaklink
--   constant OS_CN_C  : slv(15 downto 0) := x"0020";           --Config reg, no ack
--   constant OS_CA_C  : slv(15 downto 0) := x"4020";           --Config reg, with ack
   constant OS_CN_C  : slv(15 downto 0) := x"01a0";           --Config reg, no ack
   constant OS_CA_C  : slv(15 downto 0) := x"41a0";           --Config reg, with ack

   
   -- Link timer
   constant LINK_TIMER_C : slv(23 downto 0) := x"1312D0"; -- 1250000 cycles @ 125 MHz, ~10 ms
   
   type RegType is record
      ability      : slv(15 downto 0);
      abCount      : slv(2 downto 0);
      abMatch      : sl;
      wordIsConfig : sl;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      ability      => (others => '0'),
      abCount      => (others => '0'),
      abMatch      => '0',
      wordIsConfig => '0'
   );
   
   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
   attribute mark_debug : string;
   attribute mark_debug of r : signal is "true";

begin

   comb : process(r,phyRxData,phyRxDataK,ethRxClkRst,ethRxLinkSync,newState) is
      variable v : RegType;
   begin
      v := r;

      -- Check for /C1/ or /C2/
      if ( phyRxDataK = "01" and (phyRxData = OS_C1_C or phyRxData = OS_C2_C)) then
         v.wordIsConfig := '1';
      end if;

      -- On /I1/ or /I2/, reset abCount
      if ( phyRxDataK = "01" and (phyRxData = OS_I1_C or phyRxDataK = OS_I2_C)) then
         v.abCount := 0;
      -- If we just saw /C1/ or /C2/ the next word is the ability word
      elsif (r.wordIsConfig = '1') then
         v.ability := phyRxData;
         -- If the ability word doesn't match the last one, reset the counter
         -- Note we ignore the ack bit in this comparison
         if (v.ability(15) /= r.ability(15) or (v.ability(13 downto 0) /= r.ability(13 downto 0))) then
            v.abCount := 0;
         -- Otherwise, we match.  Increment the ability count
         elsif (r.abCount < 3) then
            v.abCount := r.abCount + 1;
         end if;      
      end if;
      
      -- If the ability count is 3, we're matched
      if (r.abCount = 3) then
         v.abMatch = '1';
      -- Otherwise, we're not
      else
         v.abMatch = '0';
      end if;
               
      -- Reset on ethernet reset or sync down
      if (ethRxClkRst = '1' or ethRxLinkSync = '0' or newState = '0') then
         v := REG_INIT_C;
      end if;

      -- Outputs to ports
      abilityMatch <= r.abMatch;
      ability      <= r.ability;
      
      rin <= v;

   end process;

   seq : process (ethRxClk) is
   begin
      if (rising_edge(ethRxClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;   

end rtl;

