-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : SynchronizerOneShotCnt.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-11
-- Last update: 2014-04-11
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;

entity SynchronizerOneShotCnt is
   generic (
      TPD_G           : time                  := 1 ns; -- Simulation FF output delay
      RST_POLARITY_G  : sl                    := '1';  -- '1' for active HIGH reset, '0' for active LOW reset
      RST_ASYNC_G     : boolean               := false;-- Reset is asynchronous
      RELEASE_DELAY_G : positive              := 3;    -- Delay between deassertion of async and sync resets
      IN_POLARITY_G   : sl                    := '1';  -- 0 for active LOW, 1 for active HIGH
      OUT_POLARITY_G  : sl                    := '1';  -- 0 for active LOW, 1 for active HIGH
      USE_DSP48_G     : string                := "no";
      CNT_ROLLOVER_G  : boolean               := false;-- Set to true to allow the counter roll over
      CNT_WIDTH_G     : natural range 1 to 48 := 16);
   port (
      clk     : in  sl;                            -- clock to be SYNC'd to
      rst     : in  sl := not RST_POLARITY_G;      -- Optional reset
      dataIn  : in  sl;                            -- trigger to be sync'd
      dataOut : out sl;                            -- synced one-shot pulse
      cntOut  : out slv(CNT_WIDTH_G-1 downto 0));  -- synced counter
begin
   -- USE_DSP48_G check
   assert ((USE_DSP48_G = "yes") or (USE_DSP48_G = "no") or (USE_DSP48_G = "auto") or (USE_DSP48_G = "automax"))
      report "USE_DSP48_G must be either yes, no, auto, or automax"
      severity failure;
end SynchronizerOneShotCnt;

architecture rtl of SynchronizerOneShotCnt is

   constant MAX_CNT_C : slv(CNT_WIDTH_G-1 downto 0) := (others => '1');

   type RegType is record
      dataOut : sl;
      cntOut  : slv(CNT_WIDTH_G-1 downto 0);
   end record RegType;
   constant REG_INIT_C : RegType := (
      (not OUT_POLARITY_G),
      (others => '0'));
   signal r       : RegType := REG_INIT_C;
   signal rin     : RegType;
   signal syncRst : sl;

   -- Attribute for XST
   attribute use_dsp48      : string;
   attribute use_dsp48 of r : signal is USE_DSP48_G;
   
begin

   SyncOneShot_Inst : entity work.SynchronizerOneShot
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => RST_POLARITY_G,
         RST_ASYNC_G     => RST_ASYNC_G,
         RELEASE_DELAY_G => RELEASE_DELAY_G,
         IN_POLARITY_G   => IN_POLARITY_G,
         OUT_POLARITY_G  => OUT_POLARITY_G)      
      port map (
         clk     => clk,
         rst     => rst,
         dataIn  => dataIn,
         dataOut => syncRst); 

   comb : process (r, rst, syncRst) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobe signals
      v.dataOut := not OUT_POLARITY_G;

      -- Check for a one-shot signal
      if syncRst = OUT_POLARITY_G then
         -- Propagate the one-shot signal
         v.dataOut := OUT_POLARITY_G;
         -- Check for counter roll over
         if CNT_ROLLOVER_G or (r.cntOut /= MAX_CNT_C) then
            -- Increment the counter
            v.cntOut := r.cntOut + 1;
         end if;
      end if;

      -- Sync Reset
      if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      dataOut <= r.dataOut;
      cntOut  <= r.cntOut;
      
   end process comb;

   seq : process (clk, rst) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
      -- Async Reset
      if (RST_ASYNC_G and rst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      end if;
   end process seq;
   
end architecture rtl;
