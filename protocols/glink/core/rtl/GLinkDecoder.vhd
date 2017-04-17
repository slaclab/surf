-------------------------------------------------------------------------------
-- File       : GlinkDecoder.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-03-12
-- Last update: 2015-12-07
-------------------------------------------------------------------------------
-- Description: Decoder for the Condition Inversion Master Transition coding
-- used by the GLink Protocol.
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
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.GlinkPkg.all;

entity GLinkDecoder is
   generic (
      TPD_G          : time    := 1 ns;
      RST_ASYNC_G    : boolean := false;
      RST_POLARITY_G : sl      := '1';  -- '1' for active HIGH reset, '0' for active LOW reset      
      FLAGSEL_G      : boolean := false);
   port (
      en            : in  sl := '1';
      clk           : in  sl;
      rst           : in  sl;
      gtRxData      : in  slv(19 downto 0);
      rxReady       : in  sl;
      txReady       : in  sl;           -- TX Clock domain
      gLinkRx       : out GLinkRxType;
      decoderError  : out sl;
      decoderErrorL : out sl);  
end entity GLinkDecoder;

architecture rtl of GLinkDecoder is

   type RegType is record
      deglitch : slv(3 downto 0);
      toggle   : sl;
      gLinkRx  : GLinkRxType;
   end record;
   
   constant REG_INIT_C : RegType := (
      deglitch => (others => '0'),
      toggle   => '0',
      gLinkRx  => GLINK_RX_INIT_C);      

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal txRdy : sl;
   
begin

   Synchronizer_Inst : entity work.Synchronizer
      generic map (
         TPD_G          => TPD_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         RST_POLARITY_G => RST_POLARITY_G)
      port map (
         clk     => clk,
         rst     => rst,
         dataIn  => txReady,
         dataOut => txRdy);

   comb : process (gtRxData, r, rst, rxReady, txRdy) is
      variable v            : RegType;
      variable glinkWordVar : GLinkWordType;
   begin
      v := r;

      -- Shift Register
      v.deglitch(3)          := r.gLinkRx.error;
      v.deglitch(2 downto 0) := r.deglitch(3 downto 1);

      -- Update the TX and RX MGT ready values
      v.gLinkRx.rxReady := rxReady;
      v.gLinkRx.txReady := txRdy;

      -- Reset strobe signals
      v.gLinkRx.error     := '0';
      v.gLinkRx.isControl := '0';
      v.gLinkRx.isIdle    := '1';
      v.gLinkRx.isData    := '0';
      v.gLinkRx.flag      := '0';

      -- Convert input to GLinkWordType to use GLinkPkg functions for decoding
      glinkWordVar := toGLinkWord(gtRxData);

      if (not isValidWord(glinkWordVar)) then
         -- Invalid input, don't decode
         v.gLinkRx.error := '1';
      else
         -- Valid input, decode the input
         -- Check for control word
         if (isControlWord(glinkWordVar)) then
            -- Check for idle word (subcase of control word)
            if (not isIdleWord(glinkWordVar)) then
               v.gLinkRx.isIdle    := '0';
               v.gLinkRx.isControl := '1';
               v.gLinkRx.data      := getControlPayload(glinkWordVar);
            end if;
         end if;

         -- Check for data word
         if (isDataWord(glinkWordVar)) then
            -- Set the gLinkRx bus
            v.gLinkRx.isIdle := '0';
            v.gLinkRx.isData := '1';
            v.gLinkRx.data   := getDataPayload(gLinkWordVar);  -- Bit flip done by function
            v.gLinkRx.flag   := getFlag(gLinkWordVar);
            -- Check if FLAG is used for additional error checking
            if FLAGSEL_G then
               -- Set the flag
               v.gLinkRx.linkUp := '1';
            else
               -- Check for first data frame
               if r.gLinkRx.linkUp = '0' then
                  -- First frame Detected
                  v.gLinkRx.linkUp := '1';
                  -- Latch the flag value
                  v.toggle         := getFlag(gLinkWordVar);
               else
                  -- Check for flag error
                  if (r.toggle = getFlag(gLinkWordVar)) then
                     -- Invalid flag detected
                     v.gLinkRx.error := '1';
                  else
                     -- Latch the flag value
                     v.toggle := getFlag(gLinkWordVar);
                  end if;
               end if;
            end if;
         end if;

         -- Invert if necessary
         if (isInvertedWord(glinkWordVar)) then
            v.gLinkRx.data := not v.gLinkRx.data;
         end if;
      end if;

      -- Synchronous Reset
      if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs      
      gLinkRx       <= r.gLinkRx;
      decoderError  <= uAnd(r.deglitch);
      decoderErrorL <= not(uAnd(r.deglitch));
      
   end process comb;

   seq : process (clk, rst) is
   begin
      if rising_edge(clk) then
         if en = '1' then
            r <= rin after TPD_G;
         end if;
      end if;
      -- Asynchronous Reset
      if (RST_ASYNC_G and rst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      end if;
   end process seq;

end architecture rtl;
