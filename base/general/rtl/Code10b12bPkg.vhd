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

   -------------------------------------------------------------------------------------------------
   -- 5B6B Code Constants
   -------------------------------------------------------------------------------------------------
   type Code5b6bType is record
      out6b   : slv(5 downto 0);
      expDisp : sl;
      outDisp : sl;
   end record Code5b6bType;

   type Code5b6bArray is array (natural range <>) of Code5b6bType;

   constant CODE_TABLE_C : Code5b6bArray(0 to 31) := (
      ("000110", '1', '0'),
      ("010001", '1', '0'),
      ("010010", '1', '0'),
      ("100011", 'X', 'X'),
      ("010100", '1', '0'),
      ("100101", 'X', 'X'),
      ("100110", 'X', 'X'),
      ("000111", '1', 'X'),             -- D.7 Special case
      ("011000", '1', '0'),
      ("101001", 'X', 'X'),
      ("101010", 'X', 'X'),
      ("001011", 'X', 'X'),
      ("101100", 'X', 'X'),
      ("001101", 'X', 'X'),
      ("001110", 'X', 'X'),
      ("111010", '0', '1'),
      ("110110", '0', '1'),
      ("110001", 'X', 'X'),
      ("110010", 'X', 'X'),
      ("010011", 'X', 'X'),
      ("110100", 'X', 'X'),
      ("010101", 'X', 'X'),
      ("010110", 'X', 'X'),
      ("010111", '0', '1'),
      ("001100", '1', '0'),
      ("011001", 'X', 'X'),
      ("011010", 'X', 'X'),
      ("011011", '0', '1'),
      ("011100", 'X', 'X'),
      ("011101", '0', '1'),
      ("011110", '0', '1'),
      ("110101", '0', '1'));

   procedure encode10b12b (
      dataIn   : in  slv(11 downto 0);
      dataKIn  : in  sl;
      dispIn   : in  sl;
      dataOut  : out slv(13 downto 0);
      dispOut  : out sl);

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

   procedure encode10b12b (
      dataIn   : in  slv(9 downto 0);
      dataKIn  : in  sl;
      dispIn   : in  sl;
      dataOut  : out slv(11 downto 0);
      dispOut  : out sl)
   is
      variable tmp : Code5b6bType;
      variable lowWordIn : slv(4 downto 0);
      variable lowWordOut : slv(5 downto 0);
      variable lowDispOut : sl;
      variable highWordIn : slv(4 downto 0);
      variable highWordOut : slv(5 downto 0);
      variable highDispOut : sl;
   begin

      -- First, split in input word in two
      highWordIn := dataIn(9 downto 5);
      lowWordIn  := dataIn(4 downto 0);

      -- Select low output word
      tmp := CODE_TABLE_C(conv_integer(lowWordIn));

      -- Decide whether to invert
      if (tmp.expDisp /= 'X') then
         if (dispIn /= tmp.expDisp) then
            lowWordOut := not tmp.out6b;
            lowDispOut := not tmp.outDisp;
         else
            lowWordOut := tmp.out6b;
            lowDispOut := tmp.outDisp;
         end if;
      else
         lowWordOut := tmp.out6b;
         lowDispOut := dispIn;
      end if;

      -- If selected code has even disparity,
      -- use dispIn to decide upper word disparity
      if (lowDispOut = 'X') then
         lowDispOut := dispIn;
      end if;

      -- K.28 is not in the table. Set it manually here
      if (dataKIn = '1') then
         if (lowWordIn = "11100") then
            lowWordOut := "111100";
            lowDispOut := '1';
         end if;
      end if;


      -- Select high output word
      tmp := CODE_TABLE_C(conv_integer(highWordIn));

      -- Decide whether to invert
      if (tmp.expDisp /= 'X') then
         if (lowDispOut /= tmp.expDisp) then
            highWordOut := not tmp.out6b;
            highDispOut := not tmp.outDisp;
         else
            highWordOut := tmp.out6b;
            highDispOut := tmp.outDisp;
         end if;
      else
         highWordOut := tmp.out6b;
         highDispOut := lowDispOut;
      end if;

      if (highDispOut = 'X') then
         highDispOut := lowDispOut;
      end if;

      -- Handle K.28.28 case
      if (dataKIn = '1') then
         if (highWordIn = "11100") then
            highWordOut := not "111100";
            highDispOut := dispIn;
         end if;
      end if;

      dispOut := highDispOut;
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
