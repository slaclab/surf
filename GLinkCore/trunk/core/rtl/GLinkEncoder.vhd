-------------------------------------------------------------------------------
-- Title      : GLink Encoder
-------------------------------------------------------------------------------
-- File       : GLinkEncoder.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-04-19
-- Last update: 2014-01-31
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Encodes 16 bit data raw words into 20 bit GLink words.
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.GLinkPkg.all;

entity GLinkEncoder is
   generic (
      TPD_G          : time    := 1 ns;
      FLAGSEL_G      : boolean := false;
      RST_POLARITY_G : sl      := '1');
   port (
      clk         : in  sl;
      rst         : in  sl;
      gLinkTx     : in  GLinkTxType;
      encodedData : out slv(19 downto 0));    
end GLinkEncoder;

architecture rtl of GLinkEncoder is

   function ones (vec : slv) return unsigned is
      variable topVar    : slv(vec'high downto vec'low+(vec'length/2));
      variable bottomVar : slv(topVar'low-1 downto vec'low);
      variable tmpVar    : slv(2 downto 0);
   begin
      if (vec'length = 1) then
         return '0' & unsigned(vec);
      end if;

      if (vec'length = 2) then
         return uAnd(vec) & uXor(vec);
      end if;

      if (vec'length = 3) then
         tmpVar := vec;
         case tmpVar is
            when "000"  => return "00";
            when "001"  => return "01";
            when "010"  => return "01";
            when "011"  => return "10";
            when "100"  => return "01";
            when "101"  => return "10";
            when "110"  => return "10";
            when "111"  => return "11";
            when others => return "00";
         end case;
      end if;

      topVar    := vec(vec'high downto (vec'high+1)-((vec'length+1)/2));
      bottomVar := vec(vec'high-((vec'length+1)/2) downto vec'low);

      return ('0' & ones(topVar)) + ('0' & ones(bottomVar));
   end function;

   function disparity (vec : slv(19 downto 0)) return signed is
      variable onesVar      : unsigned(4 downto 0);
      variable disparityVar : signed(5 downto 0);
   begin
      onesVar      := ones(vec);
      disparityVar := (signed('0' & onesVar) - 10);
      return disparityVar(4 downto 0);
   end function;

   type RegType is record
      encodedData      : slv(19 downto 0);
      runningDisparity : signed(4 downto 0);
   end record;

   signal r, rin : RegType;
   
begin

   seq : process (clk)
   begin  -- process seq
      if rising_edge(clk) then
         if rst = RST_POLARITY_G then
            r.encodedData      <= GLINK_IDLE_WORD_FF0_C & GLINK_CONTROL_WORD_C after TPD_G;
            r.runningDisparity <= (others => '0')                              after TPD_G;
         else
            r <= rin after TPD_G;
         end if;
      end if;
   end process seq;

   comb : process (r, gLinkTx)
      variable rVar            : RegType;
      variable glinkWordVar    : GLinkWordType;
      variable rawBufferflyVar : slv(0 to 15);
      variable rawDisparityVar : signed(4 downto 0);
   begin
      rVar            := r;
      rawBufferflyVar := bitReverse(gLinkTx.data);

      -- Default case - normal data
      if (gLinkTx.flag = '1') and FLAGSEL_G then
         glinkWordVar.c := GLINK_DATA_WORD_FLAG_HIGH_C;
      else
         glinkWordVar.c := GLINK_DATA_WORD_FLAG_LOW_C;
      end if;
      glinkWordVar.w := rawBufferflyVar;

      -- Control overrides data assignments
      if (gLinkTx.control = '1') then
         glinkWordVar.c := GLINK_CONTROL_WORD_C;
         glinkWordVar.w := rawBufferflyVar(0 to 6) & "01" & rawBufferflyVar(7 to 13);
      end if;

      -- Idle overrides control
      if (gLinkTx.idle = '1') then
         glinkWordVar.c := GLINK_CONTROL_WORD_C;
         glinkWordVar.w := GLINK_IDLE_WORD_FF1L_C;
      end if;

      rVar.encodedData := toSLV(glinkWordVar);

      -- Calculate the disparity of the encoded word so far
      rawDisparityVar := disparity(rVar.encodedData);

      -- Invert if necessary to reduce disparity
      if (rawDisparityVar(4) = r.runningDisparity(4)) then
         if (gLinkTx.idle = '1') then
            rVar.encodedData := GLINK_IDLE_WORD_FF1H_C & GLINK_CONTROL_WORD_C;
         else
            -- Normal data or control, invert everything
            rVar.encodedData := not rVar.encodedData;
         end if;
         -- Calculated raw disparity must be (2's complement) inverted too
         rawDisparityVar := (not rawDisparityVar) + 1;
      end if;

      -- Data now fully encoded. Calculate its disparity and add it to the
      -- running total
      rVar.runningDisparity := r.runningDisparity + rawDisparityVar;

      rin         <= rVar;
      encodedData <= r.encodedData;
   end process comb;

end rtl;
