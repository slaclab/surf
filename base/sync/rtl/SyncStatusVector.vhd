-------------------------------------------------------------------------------
-- File       : SyncStatusVector.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-11
-- Last update: 2014-06-02
-------------------------------------------------------------------------------
-- Description: General Purpose Status Vector and Status Counter module
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

entity SyncStatusVector is
   generic (
      TPD_G           : time     := 1 ns; -- Simulation FF output delay
      RST_POLARITY_G  : sl       := '1';  -- '1' for active HIGH reset, '0' for active LOW reset
      RST_ASYNC_G     : boolean  := false;-- true if reset is asynchronous, false if reset is synchronous
      COMMON_CLK_G    : boolean  := false;-- True if wrClk and rdClk are the same clock
      RELEASE_DELAY_G : positive := 3;    -- Delay between deassertion of async and sync resets
      IN_POLARITY_G   : slv      := "1";  -- 0 for active LOW, 1 for active HIGH (for statusIn port)
      OUT_POLARITY_G  : sl       := '1';  -- 0 for active LOW, 1 for active HIGH (for irqOut port)
      USE_DSP48_G     : string   := "no"; -- "no" for no DSP48 implementation, "yes" to use DSP48 slices
      SYNTH_CNT_G     : slv      := "1";  -- Set to 1 for synthesising counter RTL, '0' to not synthesis the counter
      CNT_RST_EDGE_G  : boolean  := true; -- true if counter reset should be edge detected, else level detected
      CNT_WIDTH_G     : positive := 32;   -- Counters' width
      WIDTH_G         : positive := 16);  -- Status vector width
   port (
      ---------------------------------------------
      -- Input Status bit Signals (wrClk domain)      
      ---------------------------------------------
      statusIn     : in  slv(WIDTH_G-1 downto 0);-- Data to be 'synced'
      ---------------------------------------------
      -- Output Status bit Signals (rdClk domain)      
      ---------------------------------------------
      statusOut    : out slv(WIDTH_G-1 downto 0);-- Synced data
      ---------------------------------------------
      -- Status Bit Counters Signals (rdClk domain)      
      ---------------------------------------------
      -- cntRstIn:
      --    This input is the common resets all the counters
      cntRstIn     : in  sl;
      -- rollOverEnIn:
      --    This input is counter roll over enable vector.  
      --    Each element of the vector corresponds to its respective counter.
      --    For example:   rollOverEnIn(0) is statusIn(0)'s counter roll over enable bit
      --                   rollOverEnIn(1) is statusIn(1)'s counter roll over enable bit
      --                   rollOverEnIn(2) is statusIn(2)'s counter roll over enable bit
      --                   .... and so on
      rollOverEnIn : in  slv(WIDTH_G-1 downto 0) := (others => '0');  -- No roll over for all counters by default
      -- cntOut:
      --    This output is counter value vector array.  
      --    The remapping of cntOut to a SLV array (outside of this module) is has followed:
      --
      --          for i in WIDTH_G-1 to 0 loop
      --             for j in CNT_WIDTH_G-1 to 0 loop
      --                MySlvArray(i)(j) <= cntOut(i, j);
      --             end loop;
      --          end loop;  
      --
      cntOut       : out SlVectorArray(WIDTH_G-1 downto 0, CNT_WIDTH_G-1 downto 0);
      ---------------------------------------------
      -- Interrupt Signals (rdClk domain)         
      ---------------------------------------------
      -- irqEnIn:
      --    This input is counter roll over enable vector.  
      --    Each element of the vector corresponds to its respective status bit.
      --    For example:   irqEnIn(0) is statusIn(0)'s enable interrupt bit
      --                   irqEnIn(1) is statusIn(1)'s enable interrupt bit
      --                   irqEnIn(2) is statusIn(2)'s enable interrupt bit
      --                   .... and so on      
      irqEnIn      : in  slv(WIDTH_G-1 downto 0) := (others => '0');  -- All bits disabled by default
      -- irqOut:
      --    This output is interrupt output signal.  
      irqOut       : out sl;
      ---------------------------------------------
      -- Clocks and Reset Ports
      ---------------------------------------------
      wrClk        : in  sl;
      wrRst        : in  sl := '0';
      rdClk        : in  sl;
      rdRst        : in  sl := '0');
end SyncStatusVector;

architecture rtl of SyncStatusVector is

   type RegType is record
      irqOut    : sl;
      hitVector : slv(WIDTH_G-1 downto 0);
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      not(OUT_POLARITY_G),
      (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal statusStrobe : slv(WIDTH_G-1 downto 0);
   
begin

   SyncVec_Inst : entity work.SynchronizerVector
      generic map (
         TPD_G         => TPD_G,
         BYPASS_SYNC_G => COMMON_CLK_G,
         STAGES_G      => RELEASE_DELAY_G,
         WIDTH_G       => WIDTH_G)
      port map (
         clk     => rdClk,
         dataIn  => statusIn,
         dataOut => statusOut);

   SyncOneShotCntVec_Inst : entity work.SynchronizerOneShotCntVector
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => RST_POLARITY_G,
         RST_ASYNC_G     => RST_ASYNC_G,
         COMMON_CLK_G    => COMMON_CLK_G,
         RELEASE_DELAY_G => RELEASE_DELAY_G,
         IN_POLARITY_G   => IN_POLARITY_G,
         OUT_POLARITY_G  => "1",
         USE_DSP48_G     => USE_DSP48_G,
         SYNTH_CNT_G     => SYNTH_CNT_G,
         CNT_RST_EDGE_G  => CNT_RST_EDGE_G,
         CNT_WIDTH_G     => CNT_WIDTH_G,
         WIDTH_G         => WIDTH_G)      
      port map (
         -- Write Ports (wrClk domain)    
         dataIn     => statusIn,
         -- Read Ports (rdClk domain)    
         rollOverEn => rollOverEnIn,
         cntRst     => cntRstIn,
         dataOut    => statusStrobe,
         cntOut     => cntOut,
         -- Clocks and Reset Ports
         wrClk      => wrClk,
         wrRst      => wrRst,
         rdClk      => rdClk,
         rdRst      => rdRst);           

   comb : process (irqEnIn, r, rdRst, statusStrobe) is
      variable i : integer;
      variable v : RegType;
   begin
      -- Reset signals
      v := REG_INIT_C;

      -- Refresh the mask check
      for i in 0 to (WIDTH_G-1) loop
         if irqEnIn(i) = '1' then
            v.hitVector(i) := statusStrobe(i);
         end if;
      end loop;

      -- Check the hitVector vector for a new interrupt
      if uOr(r.hitVector) = '1' then
         v.irqOut := OUT_POLARITY_G;
      end if;

      -- Sync Reset
      if (RST_ASYNC_G = false and rdRst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      irqOut <= r.irqOut;
      
   end process comb;

   seq : process (rdClk, rdRst) is
   begin
      if rising_edge(rdClk) then
         r <= rin after TPD_G;
      end if;
      -- Async Reset
      if (RST_ASYNC_G and rdRst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      end if;
   end process seq;

end rtl;
