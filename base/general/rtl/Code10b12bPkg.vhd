-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Code10b12bPkg.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-10-05
-- Last update: 2016-10-20
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of SURF. It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of SURF, including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
--use work.TextUtilPkg.all;

package Code10b12bPkg is

   -------------------------------------------------------------------------------------------------
   -- Disparity types and helper functions
   -------------------------------------------------------------------------------------------------
   function toString (code : slv(9 downto 0); k : sl) return string;

   subtype DisparityType is integer range -1 to 1;
   function conv (d : sl) return DisparityType;
   function conv (d : DisparityType) return sl;

   function getDisparity (vec : slv) return integer;

   -------------------------------------------------------------------------------------------------
   -- 5B6B Code Constants
   -------------------------------------------------------------------------------------------------
   type Code5b6bType is record
      out6b   : slv(5 downto 0);
      expDisp : DisparityType;
      outDisp : DisparityType;
   end record Code5b6bType;

   type Code5b6bArray is array (natural range <>) of Code5b6bType;

   constant D_CODE_TABLE_C : Code5b6bArray(0 to 31) := (
      ("000110", 1, -1),
      ("010001", 1, -1),
      ("010010", 1, -1),
      ("100011", 0, 0),
      ("010100", 1, -1),
      ("100101", 0, 0),
      ("100110", 0, 0),
      ("000111", -1, 0),                -- D.7 Special case
      ("011000", 1, -1),
      ("101001", 0, 0),
      ("101010", 0, 0),
      ("001011", 0, 0),
      ("101100", 0, 0),
      ("001101", 0, 0),
      ("001110", 0, 0),
      ("000101", 1, -1),                -- ("111010", -1, 1),
      ("001001", 1, -1),                -- ("110110", -1, 1),
      ("110001", 0, 0),
      ("110010", 0, 0),
      ("010011", 0, 0),
      ("110100", 0, 0),
      ("010101", 0, 0),
      ("010110", 0, 0),
      ("101000", 1, -1),                -- ("010111", -1, 1),
      ("001100", 1, -1),
      ("011001", 0, 0),
      ("011010", 0, 0),
      ("100100", 1, -1),                -- ("011011", -1, 1),
      ("011100", 0, 0),
      ("100010", 1, -1),                -- ("011101", -1, 1),
      ("100001", 1, -1),                -- ("011110", -1, 1),
      ("001010", 1, -1));               -- ("110101", -1, 1));

   constant K_CODE_TABLE_C : Code5b6bArray(0 to 31) := (
      ("000110", 1, -1),
      ("010001", 1, -1),
      ("010010", 1, -1),
      ("100011", 1, 0),
      ("010100", 1, -1),
      ("100101", 1, 0),
      ("100110", 1, 0),
      ("000111", -1, 0),                -- D.7 Special case
      ("011000", 1, -1),
      ("101001", 1, 0),
      ("101010", 1, 0),
      ("001011", 1, 0),
      ("101100", 1, 0),
      ("001101", 1, 0),
      ("001110", 1, 0),
      ("000101", 1, -1),                -- ("111010", -1, 1),
      ("001001", 1, -1),                -- ("110110", -1, 1),
      ("110001", 1, 0),
      ("110010", 1, 0),
      ("010011", 1, 0),
      ("110100", 1, 0),
      ("010101", 1, 0),
      ("010110", 1, 0),
      ("101000", 1, -1),                -- ("010111", -1, 1),
      ("001100", 1, -1),
      ("011001", 1, 0),
      ("011010", 1, 0),
      ("100100", 1, -1),                -- ("011011", -1, 1),
      ("000011", 1, -1),
      ("100010", 1, -1),                -- ("011101", -1, 1),
      ("100001", 1, -1),                -- ("011110", -1, 1),
      ("001010", 1, -1));               -- ("110101", -1, 1));   

   procedure encode10b12b (
      dataIn  : in  slv(9 downto 0);
      dataKIn : in  sl;
      dispIn  : in  sl;
      dataOut : out slv(11 downto 0);
      dispOut : out sl);

   procedure decode10b12b (
      dataIn    : in    slv(11 downto 0);
      dispIn    : in    sl;
      dataOut   : out   slv(9 downto 0);
      dataKOut  : inout sl;
      dispOut   : inout sl;
      codeError : out   sl;
      dispError : inout sl);

end package Code10b12bPkg;

package body Code10b12bPkg is

   function toString (code : slv(9 downto 0); k : sl) return string is
      variable s : string(1 to 8);
   begin
      s := resize(ite(k = '1', "K.", "D.") &
                  integer'image(conv_integer(code(4 downto 0))) &
                  "." &
                  integer'image(conv_integer(code(9 downto 5))), 8);
      return s;
   end function toString;

   function conv (d : sl) return DisparityType is
   begin
      if (d = '1') then
         return 1;
      else
         return -1;
      end if;
   end function conv;

   function conv (d : DisparityType) return sl is
   begin
      if (d = -1) then
         return '0';
      else
         return '1';
      end if;
   end function conv;

   function getDisparity (vec : slv) return integer is
      variable ones      : integer;
      variable zeros     : integer;
      variable disparity : integer;
   begin
      zeros := 0;
      ones  := 0;
      for i in vec'range loop
         if (vec(i) = '0') then
            zeros := zeros + 1;
         end if;
      end loop;

      ones      := vec'length-zeros;
      disparity := ones-zeros;

      return disparity;

   end function getDisparity;


   procedure encode10b12b (
      dataIn  : in  slv(9 downto 0);
      dataKIn : in  sl;
      dispIn  : in  sl;
      dataOut : out slv(11 downto 0);
      dispOut : out sl)
   is
      variable tmp         : Code5b6bType;
      variable lowWordIn   : slv(4 downto 0);
      variable lowWordOut  : slv(5 downto 0);
      variable lowDispOut  : DisparityType;
      variable highWordIn  : slv(4 downto 0);
      variable highWordOut : slv(5 downto 0);
      variable highDispOut : DisparityType;
   begin

      -- First, split in input word in two
      highWordIn := dataIn(9 downto 5);
      lowWordIn  := dataIn(4 downto 0);

      -- Select low output word
      tmp := D_CODE_TABLE_C(conv_integer(lowWordIn));
      if (dataKIn = '1') then
         tmp := K_CODE_TABLE_C(conv_integer(lowWordIn));
      end if;

      -- K.28 is not in the table. Set it manually here
--       if (dataKIn = '1') then
--          if (lowWordIn = "11100") then
--             tmp := K_28_CODE_C;
--          end if;
--       end if;


      -- Decide whether to invert
      if (tmp.expDisp /= 0) then
         if (conv(dispIn) /= tmp.expDisp) then
            lowWordOut := not tmp.out6b;
            lowDispOut := tmp.outDisp * (-1);
         else
            lowWordOut := tmp.out6b;
            lowDispOut := tmp.outDisp;
         end if;
      else
         lowWordOut := tmp.out6b;
         lowDispOut := conv(dispIn);
      end if;

      -- If selected code has even disparity,
      -- use dispIn to decide upper word disparity
      if (lowDispOut = 0) then
         lowDispOut := conv(dispIn);
      end if;



      -- Select high output word
      tmp := D_CODE_TABLE_C(conv_integer(highWordIn));
      if (dataKIn = '1') then
         tmp := K_CODE_TABLE_C(conv_integer(highWordIn));
      end if;

      -- Decide whether to invert
      if (tmp.expDisp /= 0) then
         if (lowDispOut /= tmp.expDisp) then
            highWordOut := not tmp.out6b;
            highDispOut := tmp.outDisp * (-1);
         else
            highWordOut := tmp.out6b;
            highDispOut := tmp.outDisp;
         end if;
      else
         highWordOut := tmp.out6b;
         highDispOut := lowDispOut;
      end if;

      if (highDispOut = 0) then
         highDispOut := lowDispOut;
      end if;

      -- Handle K.28.28 case
      if (dataKIn = '1') then
         if (highWordIn = "11100") then
            highWordOut := not "111100";
            highDispOut := conv(dispIn);
         end if;
      end if;

      dispOut := conv(highDispOut);
      dataOut := highWordOut & lowWordOut;

   end procedure;

   procedure decode10b12b (
      dataIn    : in    slv(11 downto 0);
      dispIn    : in    sl;
      dataOut   : out   slv(9 downto 0);
      dataKOut  : inout sl;
      dispOut   : inout sl;
      codeError : out   sl;
      dispError : inout sl)
   is
      variable tmp           : Code5b6bType;
      variable lowWordIn     : slv(5 downto 0);
      variable lowWordOut    : slv(4 downto 0);
      variable lowWordValid  : sl;
      variable highWordIn    : slv(5 downto 0);
      variable highWordOut   : slv(4 downto 0);
      variable highWordValid : sl;
      variable inputDisp     : integer;
      variable runDisp       : integer;
   begin

--      print("------------");
      -- Set default values
      codeError   := '1';
      dispError   := '0';
      dataKOut    := '0';
      lowWordOut  := (others => '0');
      highWordOut := (others => '0');

      -- Check the disparity of the input
      inputDisp := getDisparity(dataIn);
      if (inputDisp > 2 or inputDisp < -2) then
--         print(">>>>Input Disp Error");
--          print("dataIn: " & str(dataIn));
--          print("inputDisp: " & str(inputDisp));
         dispError := '1';
      end if;

      -- Check the running disparity
      runDisp := inputDisp + (conv(dispIn)*2);
      if (runDisp > 2 or runDisp < -2) then
--         print(">>>>Run Disp Error");
--          print("dataIn: " & str(dataIn));
--          print("inputDisp: " & str(inputDisp));
--          print("runDisp: " & str(runDisp));         
         dispError := '1';
      end if;

--      print("dataIn: " & str(dataIn));
--      print("inputDisp: " & str(inputDisp));
--      print("runDisp: " & str(runDisp));


      -- This probably isn't correct
      -- Need to figure out what to do when running disparity is out of range
      if (runDisp > 0) then
         dispOut := '1';
      elsif (runDisp < 0) then
         dispOut := '0';
      else
         dispOut := conv(inputDisp/2);
      end if;

--      print("dispOut: " & str(dispOut));
--      print("------------");

      lowWordIn  := dataIn(5 downto 0);
      highWordIn := dataIn(11 downto 6);

      -- Check for a k-code
      if ((lowWordIn = K_CODE_TABLE_C(28).out6b) or
          (lowWordIn = not(K_CODE_TABLE_C(28).out6b))) then

         lowWordOut   := conv_std_logic_vector(28, 5);
         dataKOut     := '1';
         lowWordValid := '1';
      end if;


      -- Need to check for valid k5/6 code
      if (dataKout = '1') then
         for i in K_CODE_TABLE_C'range loop
            tmp := K_CODE_TABLE_C(i);
            if ((highWordIn = tmp.out6b) or
                ((highWordIn = not (tmp.out6b)) and (tmp.expDisp /= 0))) then

               highWordOut   := conv_std_logic_vector(i, 5);
               dataKOut      := '1';
               highWordValid := '1';
               exit;
            end if;
         end loop;
      end if;

      if (dataKOut = '0') then

         -- Decode low word
         for i in D_CODE_TABLE_C'range loop
            tmp := D_CODE_TABLE_C(i);
            if ((lowWordIn = tmp.out6b) or
                ((lowWordIn = not (tmp.out6b)) and (tmp.expDisp /= 0))) then

               lowWordOut   := conv_std_logic_vector(i, 5);
               lowWordValid := '1';
               exit;
            end if;
         end loop;

         -- Decode high word
         for i in D_CODE_TABLE_C'range loop
            tmp := D_CODE_TABLE_C(i);
            if ((highWordIn = tmp.out6b) or
                ((highWordIn = not (tmp.out6b)) and (tmp.expDisp /= 0))) then

               highWordOut   := conv_std_logic_vector(i, 5);
               highWordValid := '1';
               exit;
            end if;
         end loop;


      end if;

      if (lowWordValid = '1' and highWordValid = '1') then
         codeError := '0';
      end if;

      dataOut(4 downto 0) := lowWordOut;
      dataOut(9 downto 5) := highWordOut;

   end procedure decode10b12b;


end package body Code10b12bPkg;
