-------------------------------------------------------------------------------
-- File       : GLinkEncoder.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-04-19
-- Last update: 2014-05-22
-------------------------------------------------------------------------------
-- Description: Encodes 16 bit data raw words into 20 bit GLink words.
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
use work.GLinkPkg.all;

entity GLinkEncoder is
   generic (
      TPD_G          : time    := 1 ns;
      RST_ASYNC_G    : boolean := false;
      RST_POLARITY_G : sl      := '1';  -- '1' for active HIGH reset, '0' for active LOW reset      
      FLAGSEL_G      : boolean := false);
   port (
      en          : in  sl := '1';
      clk         : in  sl;
      rst         : in  sl;
      gLinkTx     : in  GLinkTxType;
      encodedData : out slv(19 downto 0));    
end GLinkEncoder;

architecture rtl of GLinkEncoder is

   function disparity (vec : slv(19 downto 0)) return signed is
      variable onesCountVar : unsigned(4 downto 0);
      variable disparityVar : signed(5 downto 0);
   begin
      onesCountVar := onesCount(vec);
      disparityVar := (signed('0' & onesCountVar) - 10);
      return disparityVar(4 downto 0);
   end function;

   type RegType is record
      toggle           : sl;
      encodedData      : slv(19 downto 0);
      runningDisparity : signed(4 downto 0);
   end record;
   
   constant REG_INIT_C : RegType := (
      '0',
      (GLINK_IDLE_WORD_FF0_C & GLINK_CONTROL_WORD_C),
      (others => '0'));    

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
begin

   comb : process (gLinkTx, r, rst)
      variable v               : RegType;
      variable glinkWordVar    : GLinkWordType;
      variable rawBufferflyVar : slv(0 to 15);
      variable rawDisparityVar : signed(4 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Reverse the bit order
      rawBufferflyVar := bitReverse(gLinkTx.data);

      -- Check for idle or control
      if (gLinkTx.idle = '1') or (gLinkTx.control = '1') then
         glinkWordVar.c := GLINK_CONTROL_WORD_C; 
      else
         -- Check for flag select enabled
         if (FLAGSEL_G = true) then
            if (gLinkTx.flag = '1') then
               glinkWordVar.c := GLINK_DATA_WORD_FLAG_HIGH_C;
            else
               glinkWordVar.c := GLINK_DATA_WORD_FLAG_LOW_C;
            end if;
         else
            -- Check the toggle bit
            if r.toggle = '1' then
               glinkWordVar.c := GLINK_DATA_WORD_FLAG_HIGH_C;
               -- Toggle the bit
               v.toggle       := '0';
            else
               glinkWordVar.c := GLINK_DATA_WORD_FLAG_LOW_C;
               -- Toggle the bit
               v.toggle       := '1';
            end if;         
         end if;
      end if;
      
      -- Latch the reversed word
      glinkWordVar.w := rawBufferflyVar;

      -- Control overrides data assignments 
      if (gLinkTx.control = '1') then
         glinkWordVar.w := rawBufferflyVar(0 to 6) & "01" & rawBufferflyVar(7 to 13);
      end if;

      -- Idle overrides control
      if (gLinkTx.idle = '1') then
         glinkWordVar.w := GLINK_IDLE_WORD_FF1L_C;
      end if;

      -- Encode the G-Link word into an SLV
      v.encodedData := toSlv(glinkWordVar);

      -- Calculate the disparity of the encoded word so far
      rawDisparityVar := disparity(v.encodedData);

      -- Invert if necessary to reduce disparity
      if (rawDisparityVar(4) = r.runningDisparity(4)) then
         if (gLinkTx.idle = '1') then
            v.encodedData := GLINK_IDLE_WORD_FF1H_C & GLINK_CONTROL_WORD_C;
         else
            -- Normal data or control, invert everything
            v.encodedData := not v.encodedData;
         end if;
         -- Calculated raw disparity must be (2's complement) inverted too
         rawDisparityVar := (not rawDisparityVar) + 1;
      end if;

      -- Data now fully encoded. Calculate its disparity and add it to the running total
      v.runningDisparity := r.runningDisparity + rawDisparityVar;

      -- Synchronous Reset
      if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs      
      encodedData <= r.encodedData;
      
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

end rtl;
