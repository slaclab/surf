-------------------------------------------------------------------------------
-- File       : SynchronizerOneShotCnt.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-11
-- Last update: 2014-04-14
-------------------------------------------------------------------------------
-- Description: Wrapper for SynchronizerOneShot with counter output
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;

entity SynchronizerOneShotCnt is
   generic (
      TPD_G           : time     := 1 ns; -- Simulation FF output delay
      RST_POLARITY_G  : sl       := '1';  -- '1' for active HIGH reset, '0' for active LOW reset
      RST_ASYNC_G     : boolean  := false;-- true if reset is asynchronous, false if reset is synchronous
      COMMON_CLK_G    : boolean  := false;-- True if wrClk and rdClk are the same clock
      RELEASE_DELAY_G : positive := 3;    -- Delay between deassertion of async and sync resets
      IN_POLARITY_G   : sl       := '1';  -- 0 for active LOW, 1 for active HIGH (dataIn port)
      OUT_POLARITY_G  : sl       := '1';  -- 0 for active LOW, 1 for active HIGH (dataOut port)
      USE_DSP48_G     : string   := "no"; -- "no" for no DSP48 implementation, "yes" to use DSP48 slices
      SYNTH_CNT_G     : sl       := '1';  -- Set to 1 for synthesising counter RTL, '0' to not synthesis the counter
      CNT_RST_EDGE_G  : boolean  := true; -- true if counter reset should be edge detected, else level detected
      CNT_WIDTH_G     : positive := 16);
   port (
      -- Write Ports (wrClk domain)    
      dataIn     : in  sl;                         -- trigger to be sync'd
      -- Read Ports (rdClk domain)    
      rollOverEn : in  sl;                         -- '1' allows roll over of the counter
      cntRst     : in  sl := not RST_POLARITY_G;   -- Optional counter reset
      dataOut    : out sl;                         -- synced one-shot pulse
      cntOut     : out slv(CNT_WIDTH_G-1 downto 0);-- synced counter
      -- Clocks and Reset Ports
      wrClk      : in  sl;
      wrRst      : in  sl := not RST_POLARITY_G;
      rdClk      : in  sl;                         -- clock to be SYNC'd to
      rdRst      : in  sl := not RST_POLARITY_G);   
begin

end SynchronizerOneShotCnt;

architecture rtl of SynchronizerOneShotCnt is

   constant MAX_CNT_C : slv(CNT_WIDTH_G-1 downto 0) := (others => '1');

   type RegType is record
      dataInDly : sl;
      cntOut    : slv(CNT_WIDTH_G-1 downto 0);
   end record RegType;
   constant REG_INIT_C : RegType := (
      not(IN_POLARITY_G),
      (others => '0'));
   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   signal syncRst,
      cntRstSync,
      rollOverEnSync : sl;
   signal cntOutSync : slv(CNT_WIDTH_G-1 downto 0);

   -- Attribute for XST
   attribute use_dsp48      : string;
   attribute use_dsp48 of r : signal is USE_DSP48_G;
   
begin

   SyncOneShot_0 : entity work.SynchronizerOneShot
      generic map (
         TPD_G             => TPD_G,
         RST_POLARITY_G    => RST_POLARITY_G,
         RST_ASYNC_G       => RST_ASYNC_G,
         BYPASS_SYNC_G     => COMMON_CLK_G,
         RELEASE_DELAY_G   => RELEASE_DELAY_G,
         IN_POLARITY_G     => IN_POLARITY_G,
         OUT_POLARITY_G    => OUT_POLARITY_G)      
      port map (
         clk     => rdClk,
         rst     => rdRst,
         dataIn  => dataIn,
         dataOut => dataOut);

   CNT_RST_EDGE : if (CNT_RST_EDGE_G = true) generate
      
      SyncOneShot_1 : entity work.SynchronizerOneShot
         generic map (
            TPD_G             => TPD_G,
            RST_POLARITY_G    => RST_POLARITY_G,
            RST_ASYNC_G       => RST_ASYNC_G,
            BYPASS_SYNC_G     => COMMON_CLK_G,
            RELEASE_DELAY_G   => RELEASE_DELAY_G,
            IN_POLARITY_G     => RST_POLARITY_G,
            OUT_POLARITY_G    => RST_POLARITY_G)      
         port map (
            clk     => wrClk,
            rst     => wrRst,
            dataIn  => cntRst,
            dataOut => cntRstSync);

   end generate;

   CNT_RST_LEVEL : if (CNT_RST_EDGE_G = false) generate
      
      Synchronizer_0 : entity work.Synchronizer
         generic map (
            TPD_G          => TPD_G,
            RST_POLARITY_G => RST_POLARITY_G,
            OUT_POLARITY_G => '1',
            RST_ASYNC_G    => RST_ASYNC_G,
            BYPASS_SYNC_G  => COMMON_CLK_G,
            STAGES_G       => (RELEASE_DELAY_G-1))      
         port map (
            clk     => wrClk,
            rst     => wrRst,
            dataIn  => cntRst,
            dataOut => cntRstSync);       

   end generate;

   Synchronizer_1 : entity work.Synchronizer
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         OUT_POLARITY_G => '1',
         RST_ASYNC_G    => RST_ASYNC_G,
         BYPASS_SYNC_G  => COMMON_CLK_G,         
         STAGES_G       => (RELEASE_DELAY_G-1))      
      port map (
         clk     => wrClk,
         rst     => wrRst,
         dataIn  => rollOverEn,
         dataOut => rollOverEnSync);   

   BYPASS_CNT : if (SYNTH_CNT_G = '0') generate
      
      cntOut <= (others => '0');
      
   end generate;

   GEN_CNT : if (SYNTH_CNT_G = '1') generate

      comb : process (cntRstSync, dataIn, r, rollOverEnSync, wrRst) is
         variable v : RegType;
      begin
         -- Latch the current value
         v := r;

         -- Keep a record of the last syncData
         v.dataInDly := dataIn;

         -- Active HIGH logic
         if IN_POLARITY_G = '1' then
            -- Check for a rising edge
            if (dataIn = '1') and (r.dataInDly = '0') then
               -- Check for counter roll over
               if (rollOverEnSync = '1') or (r.cntOut /= MAX_CNT_C) then
                  -- Increment the counter
                  v.cntOut := r.cntOut + 1;
               end if;
            end if;
         -- Active LOW logic
         else
            -- Check for a falling edge
            if (dataIn = '0') and (r.dataInDly = '1') then
               -- Check for counter roll over
               if (rollOverEnSync = '1') or (r.cntOut /= MAX_CNT_C) then
                  -- Increment the counter
                  v.cntOut := r.cntOut + 1;
               end if;
            end if;
         end if;

         -- Check for a counter reset
         if cntRstSync = RST_POLARITY_G then
            v.cntOut := (others => '0');
         end if;

         -- Sync Reset
         if (RST_ASYNC_G = false and wrRst = RST_POLARITY_G) then
            v.cntOut      := (others => '0');
            v.dataInDly   := dataIn;  -- prevent accidental edge detection
         end if;

         -- Register the variable for next clock cycle
         rin <= v;

         -- Outputs
         cntOutSync <= r.cntOut;
         
      end process comb;

      seq : process (dataIn, wrClk, wrRst) is
      begin
         if rising_edge(wrClk) then
            r <= rin after TPD_G;
         end if;
         -- Async Reset
         if (RST_ASYNC_G and wrRst = RST_POLARITY_G) then
            r           <= REG_INIT_C after TPD_G;
            r.dataInDly <= dataIn     after TPD_G;  -- prevent accidental edge detection
         end if;
      end process seq;

      SyncFifo_Inst : entity work.SynchronizerFifo
         generic map (
            TPD_G         => TPD_G,
            COMMON_CLK_G  => COMMON_CLK_G,
            SYNC_STAGES_G => RELEASE_DELAY_G,
            DATA_WIDTH_G  => CNT_WIDTH_G)
         port map (
            -- Asynchronous Reset
            rst    => wrRst,
            --Write Ports (wr_clk domain)
            wr_clk => wrClk,
            din    => cntOutSync,
            --Read Ports (rd_clk domain)
            rd_clk => rdClk,
            dout   => cntOut);      

   end generate;
   
end architecture rtl;
