-------------------------------------------------------------------------------
-- Title      : GLink Encoder
-------------------------------------------------------------------------------
-- File       : GLinkEncoder.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-04-19
-- Last update: 2014-01-30
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
      TPD_G          : time := 1 ns;
      RST_POLARITY_G : sl   := '1');
   port (
      clk         : in  sl;
      rst         : in  sl;
      idle        : in  sl;
      control     : in  sl;
      rawData     : in  slv(15 downto 0);
      encodedData : out slv(19 downto 0));    
end GLinkEncoder;

architecture rtl of GLinkEncoder is

   type RegType is record
      encodedData      : slv(19 downto 0);
      runningDisparity : signed(4 downto 0);
      flag             : sl;
   end record;

   signal r, rin : RegType;

   function ones_2 (
      i : slv(1 downto 0))
      return slv
   is
      variable rtnVar : slv(1 downto 0);
   begin
      rtnVar := (i(0) and i(1)) & (i(0) xor i(1));
      return rtnVar;
   end function;

   function ones_4 (
      i : slv(3 downto 0))
      return slv
   is
      variable rtnVar : slv(2 downto 0);
   begin
      rtnVar := slv(('0' & unsigned(ones_2(i(3 downto 2)))) +
                    ('0' & unsigned(ones_2(i(1 downto 0)))));
      return rtnVar;
   end function;
   
   function ones_8 (
      i : slv(7 downto 0))
      return slv
   is
      variable rtnVar : slv(3 downto 0);
   begin
      rtnVar := slv(('0' & unsigned(ones_4(i(7 downto 4)))) +
                    ('0' &unsigned(ones_4(i(3 downto 0)))));
      return rtnVar;
   end function;

   function ones_20 (
      i : slv(19 downto 0))
      return slv
   is
      variable rtnVar : slv(4 downto 0);
   begin
      rtnVar := slv(('0' & unsigned(ones_4(i(19 downto 16)))) +
                    ('0' & unsigned(ones_8(i(15 downto 8)))) +
                    ('0' & unsigned(ones_8(i(7 downto 0)))));
      return rtnVar;
   end function;

   function ones (
      i : slv)
      return unsigned
   is
      variable topVar    : slv(i'high downto i'low+(i'length/2));
      variable bottomVar : slv(topVar'low-1 downto i'low);
      variable tmpVar    : slv(2 downto 0);
   begin
      if (i'length = 1) then
         return '0' & unsigned(i);
      end if;

      if (i'length = 2) then
         return uAnd(i) & uXor(i);
      end if;

      if (i'length = 3) then
         tmpVar := i;
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

      topVar    := i(i'high downto (i'high+1)-((i'length+1)/2));
      bottomVar := i(i'high-((i'length+1)/2) downto i'low);

      --if (topVar'length = bottomVar'length) then
      return ('0' & ones(topVar)) + ('0' & ones(bottomVar));
      --else
      --  return ones(topVar) + ones(bottomVar);
      -- end if;

   end function;
   
   function disparity (
      i : slv(19 downto 0))
      return signed
   is
      variable onesVar      : unsigned(4 downto 0);
      variable disparityVar : signed(5 downto 0);
   begin
      onesVar      := ones(i);
      disparityVar := (signed('0' & onesVar) - 10);
      return disparityVar(4 downto 0);
   end disparity;

begin  -- rtl

   seq : process (clk)
   begin  -- process seq
      if rising_edge(clk) then
         if rst = RST_POLARITY_G then
            r.runningDisparity <= (others => '0')                              after TPD_G;
            r.flag             <= '0'                                          after TPD_G;
            r.encodedData      <= GLINK_IDLE_WORD_FF0_C & GLINK_CONTROL_WORD_C after TPD_G;
         else
            r <= rin after TPD_G;
         end if;
      end if;
   end process seq;

   comb : process (r, idle, control, rawData)
      variable rVar            : RegType;
      variable glinkWordVar    : GLinkWordType;
      variable rawBufferflyVar : slv(0 to 15);
      variable rawDisparityVar : signed(4 downto 0);
      variable idle_invertVar  : slv(19 downto 0);

   begin  -- process comb
      rVar            := r;
      rawBufferflyVar := bitReverse(rawData);

      -- First set the everything according to inputs and flags
      -- Will decide later if and how to invert

      -- Default case - normal data
      if (r.flag = '1') then
         glinkWordVar.c := GLINK_DATA_WORD_FLAG_HIGH_C;
         -- rVar.encodedData(3 downto 0) := DATA_WORD_FLAG_HIGH_C;
      else
         glinkWordVar.c := GLINK_DATA_WORD_FLAG_LOW_C;
         -- rVar.encodedData(3 downto 0) := GLINK_DATA_WORD_FLAG_LOW_C;
      end if;
      -- rVar.encodedData(19 downto 4) := rawBufferflyVar;
      glinkWordVar.w := rawBufferflyVar;

      -- Control overrides data assignments
      if (control = '1') then
         glinkWordVar.c := GLINK_CONTROL_WORD_C;
         glinkWordVar.w := rawBufferflyVar(0 to 6) & "01" & rawBufferflyVar(7 to 13);
         -- rVar.encodedData(3 downto 0)  := CONTROL_WORD_C;
         -- rVar.encodedData(19 downto 4) := rawBufferflyVar(0 to 6) & "01" & rawBufferflyVar(7 to 13);
      end if;

      -- Idle overrides control
      if (idle = '1') then
         glinkWordVar.c := GLINK_CONTROL_WORD_C;
         glinkWordVar.w := GLINK_IDLE_WORD_FF1L_C;
         -- rVar.encodedData(3 downto 0)  := CONTROL_WORD_C;
         -- rVar.encodedData(19 downto 4) := IDLE_WORD_FF1L_C;
      end if;

      rVar.encodedData := toSLV(glinkWordVar);

      -- Calculate the disparity of the encoded word so far
      rawDisparityVar := disparity(rVar.encodedData);

      -- Invert if necessary to reduce disparity
      if (rawDisparityVar(4) = r.runningDisparity(4)) then
         if (idle = '1') then
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

      -- Invert flag every data word
      if (idle = '0' and control = '0') then
         rVar.flag := '0';              --not r.flag;
      end if;

      rin         <= rVar;
      encodedData <= r.encodedData;
   end process comb;

end rtl;
