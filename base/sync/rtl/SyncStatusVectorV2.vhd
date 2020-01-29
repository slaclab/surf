-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Version2 of General Purpose Status Vector and Status Counter module
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

library surf;
use surf.StdRtlPkg.all;

entity SyncStatusVectorV2 is
   generic (
      TPD_G           : time     := 1 ns;  -- Simulation FF output delay
      RST_POLARITY_G  : sl       := '1';  -- '1' for active HIGH reset, '0' for active LOW reset
      RST_ASYNC_G     : boolean  := false;  -- true if reset is asynchronous, false if reset is synchronous
      COMMON_CLK_G    : boolean  := false;  -- True if wrClk and rdClk are the same clock
      RELEASE_DELAY_G : positive := 3;  -- Delay between deassertion of async and sync resets
      IN_POLARITY_G   : slv      := "1";  -- 0 for active LOW, 1 for active HIGH (for statusIn port)
      USE_DSP_G       : string   := "no";  -- "no" for no DSP implementation, "yes" to use DSP slices
      SYNTH_CNT_G     : slv      := "1";  -- Set to 1 for synthesizing counter RTL, '0' to not synthesis the counter
      CNT_RST_EDGE_G  : boolean  := true;  -- true if counter reset should be edge detected, else level detected
      CNT_WIDTH_G     : positive := 32;   -- Counters' width
      WIDTH_G         : positive := 16);  -- Status vector width
   port (
      ---------------------------------------------
      -- Input Status bit Signals (wrClk domain)      
      ---------------------------------------------
      statusIn     : in  slv(WIDTH_G-1 downto 0);  -- Data to be 'synced'
      ---------------------------------------------
      -- Output Status bit Signals (rdClk domain)      
      ---------------------------------------------
      statusOut    : out slv(WIDTH_G-1 downto 0);  -- Synced data
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
      -- cntOut[addrIn]:
      --    This output is counter value with respect to addrIn index
      cntOut       : out slv(CNT_WIDTH_G-1 downto 0);
      addrIn       : in  slv(bitSize(WIDTH_G-1)-1 downto 0);
      ---------------------------------------------
      -- Clocks and Reset Ports
      ---------------------------------------------
      wrClk        : in  sl;
      wrRst        : in  sl                      := '0';
      rdClk        : in  sl;
      rdRst        : in  sl                      := '0');
end SyncStatusVectorV2;

architecture rtl of SyncStatusVectorV2 is

   function fillVectorArray (INPUT : slv) return slv is
   begin
      return ite(INPUT = "1", slvOne(WIDTH_G),
                 ite(INPUT = "0", slvZero(WIDTH_G),
                     INPUT));
   end function fillVectorArray;

   constant IN_POLARITY_C : slv(WIDTH_G-1 downto 0) := fillVectorArray(IN_POLARITY_G);
   constant SYNTH_CNT_C   : slv(WIDTH_G-1 downto 0) := fillVectorArray(SYNTH_CNT_G);

   type MySlvArray is array (WIDTH_G-1 downto 0) of slv(CNT_WIDTH_G-1 downto 0);
   signal cnt : MySlvArray;

   constant ADDR_WIDTH_C : positive := bitSize(WIDTH_G-1);

   type RegType is record
      data : slv(CNT_WIDTH_G-1 downto 0);
      addr : slv(ADDR_WIDTH_C-1 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      data => (others => '0'),
      addr => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   U_SyncVec : entity surf.SynchronizerVector
      generic map (
         TPD_G         => TPD_G,
         BYPASS_SYNC_G => COMMON_CLK_G,
         STAGES_G      => RELEASE_DELAY_G,
         WIDTH_G       => WIDTH_G)
      port map (
         clk     => rdClk,
         dataIn  => statusIn,
         dataOut => statusOut);

   GEN_VEC :
   for i in (WIDTH_G-1) downto 0 generate

      SyncOneShotCnt_Inst : entity surf.SynchronizerOneShotCnt
         generic map (
            TPD_G           => TPD_G,
            RST_POLARITY_G  => RST_POLARITY_G,
            RST_ASYNC_G     => RST_ASYNC_G,
            COMMON_CLK_G    => true,    -- Using LUTRAM for Synchronization
            RELEASE_DELAY_G => RELEASE_DELAY_G,
            IN_POLARITY_G   => IN_POLARITY_C(i),
            USE_DSP_G       => USE_DSP_G,
            SYNTH_CNT_G     => SYNTH_CNT_C(i),
            CNT_RST_EDGE_G  => CNT_RST_EDGE_G,
            CNT_WIDTH_G     => CNT_WIDTH_G)
         port map (
            -- Write Ports (wrClk domain)    
            dataIn     => statusIn(i),
            -- Read Ports (rdClk domain)    
            rollOverEn => rollOverEnIn(i),
            cntRst     => cntRstIn,
            cntOut     => cnt(i),
            -- Clocks and Reset Ports
            wrClk      => wrClk,
            wrRst      => wrRst,
            rdClk      => wrClk,
            rdRst      => wrRst);

   end generate GEN_VEC;

   comb : process (cnt, r, wrRst) is
      variable v     : RegType;
      variable index : natural range 0 to (2**WIDTH_G)-1;
   begin
      -- Latch the current value
      v := r;

      -- Increment the counter
      v.addr := r.addr + 1;

      -- Update the variable index
      index := conv_integer(v.addr);

      -- Check for in-of-range index
      if (index < WIDTH_G) then
         v.data := cnt(index);
      end if;

      -- Synchronous Reset
      if (wrRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (wrClk) is
   begin
      if (rising_edge(wrClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_LUTRAM : entity surf.SimpleDualPortRam
      generic map(
         TPD_G         => TPD_G,
         DOB_REG_G     => false,          -- zero latency read access
         MEMORY_TYPE_G => "distributed",  -- Use LUTRAM
         DATA_WIDTH_G  => CNT_WIDTH_G,
         ADDR_WIDTH_G  => ADDR_WIDTH_C)
      port map (
         -- Port A
         clka  => wrClk,
         wea   => '1',
         addra => r.addr,
         dina  => r.data,
         -- Port B
         clkb  => rdClk,
         addrb => addrIn,
         doutb => cntOut);

end rtl;
