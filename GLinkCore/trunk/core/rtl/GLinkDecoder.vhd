-------------------------------------------------------------------------------
-- Title      : GLink Decoder
-------------------------------------------------------------------------------
-- File       : GlinkDecoder.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-03-12
-- Last update: 2014-01-30
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
      TPD_G          : time := 1 ns;
      RST_POLARITY_G : sl   := '1');
   port (
      clk          : in  sl;
      rst          : in  sl;
      gtRxData     : in  slv(19 downto 0);
      decodedData  : out slv(15 downto 0);
      isControl    : out sl;
      isData       : out sl;
      isIdle       : out sl;
      flag         : out sl;
      decoderError : out sl);  
end entity GLinkDecoder;

architecture rtl of GLinkDecoder is

   type RegType is
   record
      decodedData  : slv(15 downto 0);
      lastGtRxData : slv(9 downto 0);
      isControl    : sl;
      isData       : sl;
      isIdle       : sl;
      flag         : sl;
      error        : sl;
   end record RegType;

   signal r, rin : RegType;
   
begin

   seq : process (clk)
   begin  -- process seq
      if rising_edge(clk) then
         if rst = RST_POLARITY_G then
            r.decodedData  <= (others => '0') after TPD_G;
            r.lastGtRxData <= (others => '0') after TPD_G;
            r.isControl    <= '0'             after TPD_G;
            r.isData       <= '0'             after TPD_G;
            r.isIdle       <= '1'             after TPD_G;
            r.flag         <= '0'             after TPD_G;
            r.error        <= '0'             after TPD_G;
         else
            r <= rin after TPD_G;
         end if;
      end if;
   end process seq;

   comb : process (r, gtRxData) is
      variable rVar         : RegType;
      variable glinkWordVar : GLinkWordType;
   begin  -- process comb
      rVar := r;

      -- Default outputs
      rVar.error       := '0';
      rVar.isControl   := '0';
      rVar.isData      := '0';
      rVar.isIdle      := '0';
      rVar.flag        := '0';
      rVar.decodedData := (others => '0');

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
               rVar.isControl   := '1';
               rVar.decodedData := getControlPayload(glinkWordVar);
            else
               rVar.isIdle      := '1';
               rVar.decodedData := (others => '0');  -- Don't care (is this a good idea?
            end if;
         end if;

         -- Check for data word
         if (isDataWord(glinkWordVar)) then
            rVar.isData      := '1';
            rVar.decodedData := getDataPayload(gLinkWordVar);  -- Bit flip done by function
            rVar.flag        := getFlag(gLinkWordVar);
         end if;

         -- Invert if necessary
         if (isInvertedWord(glinkWordVar)) then
            rVar.decodedData := not rVar.decodedData;
         end if;
      end if;

      rin <= rVar;

      -- Assign outputs
      decodedData  <= r.decodedData;
      isControl    <= r.isControl;
      isData       <= r.isData;
      isIdle       <= r.isIdle;
      flag         <= r.flag;
      decoderError <= r.error;
   end process comb;

end architecture rtl;
