-------------------------------------------------------------------------------
-- Title      : GLink Decoder
-------------------------------------------------------------------------------
-- File       : GlinkDecoder.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-03-12
-- Last update: 2014-01-31
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Decoder for the Condition Inversion Master Transition coding
-- used by the GLink Protocol.
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.GlinkPkg.all;

entity GLinkDecoder is
   generic (
      TPD_G          : time    := 1 ns;
      FLAGSEL_G      : boolean := false;
      RST_POLARITY_G : sl      := '1');
   port (
      clk          : in  sl;
      rst          : in  sl;
      gtRxData     : in  slv(19 downto 0);
      gLinkRx      : out GLinkRxType;
      decoderError : out sl);  
end entity GLinkDecoder;

architecture rtl of GLinkDecoder is

   type RegType is record
      lastGtRxData : slv(9 downto 0);
      gLinkRx      : GLinkRxType;
      error        : sl;
   end record;
   
   constant REG_TYPE_INIT_C : RegType := (
      (others => '0'),
      GLINK_RX_INIT_C,
      '0');      

   signal r, rin : RegType := REG_TYPE_INIT_C;
   
begin

   seq : process (clk)
   begin
      if rising_edge(clk) then
         if rst = RST_POLARITY_G then
            r <= REG_TYPE_INIT_C after TPD_G;
         else
            r <= rin after TPD_G;
         end if;
      end if;
   end process seq;

   comb : process (r, gtRxData) is
      variable rVar         : RegType;
      variable glinkWordVar : GLinkWordType;
   begin
      rVar := r;

      -- Default outputs
      rVar.gLinkRx := GLINK_RX_INIT_C;
      rVar.error   := '0';

      -- Convert input to GLinkWordType to use GLinkPkg functions for decoding
      glinkWordVar := toGLinkWord(gtRxData);

      if (not isValidWord(glinkWordVar)) then
         -- Invalid input, don't decode
         rVar.error := not toSl(isValidWord(glinkWordVar));
      else
         -- Valid input, decode the input
         -- Check for control word
         if (isControlWord(glinkWordVar)) then
            -- Check for idle word (subcase of control word)
            if (not isIdleWord(glinkWordVar)) then
               rVar.gLinkRx.isIdle    := '0';
               rVar.gLinkRx.isControl := '1';
               rVar.gLinkRx.data      := getControlPayload(glinkWordVar);
            end if;
         end if;

         -- Check for data word
         if (isDataWord(glinkWordVar)) then
            rVar.gLinkRx.isIdle := '0';
            rVar.gLinkRx.isData := '1';
            rVar.gLinkRx.data   := getDataPayload(gLinkWordVar);  -- Bit flip done by function
            if FLAGSEL_G then
               rVar.gLinkRx.flag   := getFlag(gLinkWordVar);
            end if;
         end if;

         -- Invert if necessary
         if (isInvertedWord(glinkWordVar)) then
            rVar.gLinkRx.data := not rVar.gLinkRx.data;
         end if;
      end if;

      rin <= rVar;

      -- Assign outputs
      gLinkRx      <= r.gLinkRx;
      decoderError <= r.error;
   end process comb;

end architecture rtl;
