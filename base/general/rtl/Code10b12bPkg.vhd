-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Code10b12bPkg.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-10-05
-- Last update: 2016-10-19
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

package Code10b12bPkg is

   -------------------------------------------------------------------------------------------------
   -- Disparity types and helper functions
   -------------------------------------------------------------------------------------------------
   function toString (code : slv(9 downto 0); k : sl) return string;

   subtype DisparityType is integer range -1 to 1;
   function conv (d : sl) return DisparityType;
   function conv (d : DisparityType) return sl;

   -------------------------------------------------------------------------------------------------
   -- 5B6B Code Constants
   -------------------------------------------------------------------------------------------------
   type Code5b6bType is record
      out6b   : slv(5 downto 0);
      expDisp : DisparityType;
      outDisp : DisparityType;
   end record Code5b6bType;

   type Code5b6bArray is array (natural range <>) of Code5b6bType;

   constant CODE_TABLE_C : Code5b6bArray(0 to 31) := (
      ("000110", 1, -1),
      ("010001", 1, -1),
      ("010010", 1, -1),
      ("100011", 0, 0),
      ("010100", 1, -1),
      ("100101", 0, 0),
      ("100110", 0, 0),
      ("000111", -1, 0),                 -- D.7 Special case
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

   procedure encode10b12b (
      dataIn  : in  slv(9 downto 0);
      dataKIn : in  sl;
      dispIn  : in  sl;
      dataOut : out slv(11 downto 0);
      dispOut : out sl);

--    procedure decode10b12b (
--       dataIn    : in    slv(13 downto 0);
--       dispIn    : in    sl;
--       dataOut   : out   slv(11 downto 0);
--       dataKOut  : inout sl;
--       dispOut   : inout sl;
--       codeError : out   sl;
--       dispError : inout sl);

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
      tmp := CODE_TABLE_C(conv_integer(lowWordIn));

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

      -- K.28 is not in the table. Set it manually here
      if (dataKIn = '1') then
--         if (lowWordIn = "11100") then
            lowWordOut := "111100";
            lowDispOut := 1;
--         end if;
      end if;


      -- Select high output word
      tmp := CODE_TABLE_C(conv_integer(highWordIn));

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

--    procedure decode10b12b (
--       constant CODES_C : in    EncodeTableType;
--       dataIn           : in    slv(13 downto 0);
--       dispIn           : in    RunDisparityType;
--       dataOut          : out   slv(11 downto 0);
--       dataKOut         : inout sl;
--       dispOut          : inout RunDisparityType;
--       codeError        : out   sl;
--       dispError        : inout sl)
--    is
--       variable valid78   : sl;
--       variable valid56   : sl;
--       variable dataIn8   : slv(7 downto 0);
--       variable dataIn6   : slv(5 downto 0);
--       variable dataOut5  : slv(4 downto 0);
--       variable dataOut7  : slv(6 downto 0);
--       variable inputDisp : integer;
--       variable runDisp   : integer;
--    begin

--                                         -- Set default values
--       codeError := '1';
--       dispError := '0';
--       dataKOut  := '0';
--       valid78   := '0';
--       valid56   := '0';
--       dataOut5  := (others => '0');
--       dataOut7  := (others => '0');


--                                         -- Check the disparity of the input
--       inputDisp := getDisparity(dataIn);
--       if (inputDisp > 4 or inputDisp < -4) then
-- --          print("Input Disp Error");
-- --          print("dataIn: " & str(dataIn));
-- --          print("inputDisp: " & str(inputDisp));
--          dispError := '1';
--       end if;

--                                         -- Check the running disparity
--       runDisp := inputDisp + toBlockDisparityType(dispIn);
--       if (runDisp > 4 or runDisp < -2) then
-- --          print("Run Disp Error");
-- --          print("dataIn: " & str(dataIn));
-- --          print("inputDisp: " & str(inputDisp));
-- --          print("runDisp: " & str(runDisp));         
--          dispError := '1';
--       end if;

--                                         -- This probably isn't correct
--                                         -- Need to figure out what to do when running disparity is out of range
--       dispOut := toSlv(runDisp);
-- --       if (dispError = '1') then
-- --          dispOut := toSlv(0);
-- --       end if;



--       dataIn8 := dataIn(7 downto 0);
--       dataIn6 := dataIn(13 downto 8);

--       dataOut7 := dataIn8(6 downto 0);
--       dataOut5 := dataIn6(4 downto 0);

--                                         -- Check for a k-code
--       for i in CODES_C.k78'range loop
--          if (dataIn8 = CODES_C.k78(i).out8b or
--              dataIn8 = CODES_C.k78(i).alt8b) then
--             dataOut7 := CODES_C.k78(i).in7b;
--             dataKOut := '1';
--             valid78  := '1';
--             exit;
--          end if;
--       end loop;

--                                         -- Need to check for valid k5/6 code
--       if (dataKout = '1') then
--          for i in CODES_C.k56'range loop
--             if (dataIn6 = CODES_C.k56(i).out6b or
--                 dataIn6 = CODES_C.k56(i).alt6b) then
--                dataOut5  := CODES_C.k56(i).in5b;
--                dataKOut  := '1';
--                valid56   := '1';
--                codeError := '0';
--                exit;
--             end if;
--          end loop;
--       end if;

--       if (dataKOut = '0') then
--                                         -- Decode 7/8
--          for i in CODES_C.data78'range loop
--             if (dataIn8 = CODES_C.data78(i).out8b or
--                 dataIn8 = CODES_C.data78(i).alt8b) then
--                dataOut7 := CODES_C.data78(i).in7b;
--                valid78  := '1';
--                exit;
--             end if;
--          end loop;

--          for i in CODES_C.data56'range loop
--             if (dataIn6 = CODES_C.data56(i).out6b or
--                 dataIn6 = CODES_C.data56(i).alt6b) then
--                dataOut5 := CODES_C.data56(i).in5b;
--                valid56  := '1';
--                exit;
--             end if;
--          end loop;

--       end if;

--       if (valid56 = '1' and valid78 = '1') then
--          codeError := '0';
--       end if;

--       dataOut(6 downto 0)  := dataOut7;
--       dataOut(11 downto 7) := dataOut5;



--    end procedure decode10b12b;


end package body Code10b12bPkg;
