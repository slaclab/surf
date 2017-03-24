-------------------------------------------------------------------------------
-- File       : Code12b14bPkg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-10-05
-- Last update: 2016-10-17
-------------------------------------------------------------------------------
-- Description: 12B14B Package File
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.Code7b8bPkg.all;
--use work.TextUtilPkg.all;


package Code12b14bPkg is

   -------------------------------------------------------------------------------------------------
   -- Disparity types and helper functions
   -------------------------------------------------------------------------------------------------
   subtype BlockDisparityType is integer;
   subtype RunDisparityType is slv(1 downto 0);

--    constant DISP_N4_S : integer := -4;
--    constant DISP_N2_S : integer := -2;
--    constant DISP_Z_S  : integer := 0;
--    constant DISP_P2_S : integer := 2;
--    constant DISP_P4_S : integer := 4;

   function toSlv (d : BlockDisparityType) return slv;

   function toBlockDisparityType (d : slv(1 downto 0)) return BlockDisparityType;

   function getDisparity (vec : slv) return BlockDisparityType;


   type KCodeEntryType is record
      k12  : slv(11 downto 0);
      k14  : slv(13 downto 0);
      disp : BlockDisparityType;
   end record KCodeEntryType;

   type KCodeArray is array (natural range <>) of KCodeEntryType;


   -- These are depricated
--    type K78EntryType is record
--       b7   : slv(6 downto 0);
--       b8   : slv(7 downto 0);
--       disp : BlockDisparityType;
--    end record K78EntryType;

--    type K78Array is array (natural range <>) of K78EntryType;

--    type K56EntryType is record
--       b5   : slv(4 downto 0);
--       b6   : slv(5 downto 0);
--       disp : BlockDisparityType;
--    end record;

--    type K56Array is array (natural range <>) of K56EntryType;

   function toString (code : slv(11 downto 0); k : sl) return string;


   type Encode7b8bType is record
      in7b    : slv(6 downto 0);
      out8b   : slv(7 downto 0);
      outDisp : BlockDisparityType;
      alt8b   : slv(7 downto 0);
      altDisp : BlockDisparityType;
   end record Encode7b8bType;

   type Encode7b8bArray is array (natural range <>) of Encode7b8bType;

   function makeEncode7b8bTable(a : slv8Array(0 to 127)) return Encode7b8bArray;


--    type Decode7b8bType is record
--       valid : sl;
--       out7b : slv(6 downto 0);
--       k     : sl;
--       din   : BlockDisparityType;
--       dout  : BlockDisparityType;
--    end record Decode7b8bType;

--    type Decode7b8bArray is array (0 to 255) of Decode7b8bType;

--    function makeDecode7b8bTable return Decode7b8bArray;

--    constant DECODE_7B8B_TABLE_C : Decode7b8bArray := makeDecode7b8bTable;

   -------------------------------------------------------------------------------------------------
   -- 5B6B Code Constants
   -------------------------------------------------------------------------------------------------
   type Encode5b6bType is record
      in5b    : slv(4 downto 0);
      out6b   : slv(5 downto 0);
      outDisp : BlockDisparityType;
      alt6b   : slv(5 downto 0);
      altDisp : BlockDisparityType;
   end record Encode5b6bType;

   type Encode5b6bArray is array (natural range <>) of Encode5b6bType;

   function makeEncode5b6bTable(a : slv6Array(0 to 31)) return Encode5b6bArray;

--    type Decode5b6bType is record
--       valid : sl;
--       out5b : slv(4 downto 0);
--       k     : sl;
--       din   : BlockDisparityType;
--       dout  : BlockDisparityType;
--    end record Decode5b6bType;

--   type Decode5b6bArray is array (0 to 255) of Decode5b6bType;

--    function makeDecode5b6bArray return Decode5b6bArray;



   type EncodeTableType is record
      k78    : Encode7b8bArray(0 to 0);
      k56    : Encode5b6bArray(0 to 16);
      data78 : Encode7b8bArray(0 to 127);
      data56 : Encode5b6bArray(0 to 31);
   end record;



   procedure encode12b14b (
      constant CODES_C : in  EncodeTableType;
      dataIn           : in  slv(11 downto 0);
      dataKIn          : in  sl;
      dispIn           : in  RunDisparityType;
      dataOut          : out slv(13 downto 0);
      dispOut          : out RunDisparityType;
      invalidK         : out sl);

   procedure decode12b14b (
      constant CODES_C : in    EnCodeTableType;
      dataIn           : in    slv(13 downto 0);
      dispIn           : in    RunDisparityType;
      dataOut          : out   slv(11 downto 0);
      dataKOut         : inout sl;
      dispOut          : inout RunDisparityType;
      codeError        : out   sl;
      dispError        : inout sl);

end package Code12b14bPkg;

package body Code12b14bPkg is

   function toString (
      code : slv(11 downto 0);
      k    : sl)
      return string is
      variable s : string(1 to 8);
   begin
      s := resize(ite(k = '1', "K.", "D.") &
                  integer'image(conv_integer(code(6 downto 0))) &
                  "." &
                  integer'image(conv_integer(code(11 downto 7))), 8);
      return s;
   end function toString;

   -- Determine the disparity of a vector
   function getDisparity (vec : slv) return BlockDisparityType is
      variable ones      : integer;
      variable zeros     : integer;
      variable disparity : BlockDisparityType;
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

   function toSlv (d : BlockDisparityType) return slv is
      variable ret : slv(1 downto 0) := "01";
   begin
      case d is
         when -2 =>
            ret := "00";
         when 0 =>
            ret := "01";
         when 2 =>
            ret := "10";
         when 4 =>
            ret := "11";
         when others =>
            ret := "01";
      end case;
      return ret;
   end function;

   function toBlockDisparityType (d : slv(1 downto 0)) return BlockDisparityType is
   begin
      if (d = "00") then
         return -2;
      elsif (d = "01") then
         return 0;
      elsif (d = "10") then
         return 2;
      elsif (d = "11") then
         return 4;
      end if;
      return 0;
   end function;


   -- Given an running disparity and a selected code disparity,
   -- determine whether the selected code needs to be complimented, and what the out disparity is
   -- Should maybe implement DisparityType as a constrained integer and just use math here
   -- instead of this state machine. Not sure which is better.
--    procedure disparityControl (
--       prevDisp   : in    DisparityOutType;
--       blockDisp  : in    DisparityType;
--       compliment : inout sl;
--       nextDisp   : inout DisparityOutType) is
--    begin
--       compliment := '0';
--       case prevDisp is
--          when DISP_N2_S =>
--             if (blockDisp = DISP_N2_S) then
--                compliment := '1';
--                nextDisp   := DISP_Z_S;
--             elsif (blockDisp = DISP_N4_S) then
--                compliment := '1';
--                nextDisp   := DISP_P2_S;
--             else
--                nextDisp := DisparityOutType'leftof(blockDisp);
--             end if;

--          when DISP_Z_S =>
--             if (blockDisp = DISP_N4_S) then
--                compliment := '1';
--                nextDisp   := DISP_P4_S;
--             else
--                nextDisp := blockDisp;
--             end if;

--          when DISP_P2_S =>
--             if (blockDisp = DISP_P4_S) then
--                compliment := '1';
--                nextDisp   := DISP_N2_S;
--             elsif (blockDisp = DISP_P2_S) then
--                compliment := '1';
--                nextDisp   := DISP_Z_S;
--             else
--                nextDisp := DisparityType'rightof(blockDisp);
--             end if;

--          when DISP_P4_S =>
--             if (blockDisp = DISP_P4_S) then
--                compliment := '1';
--                nextDisp   := DISP_Z_S;
--             elsif (blockDisp = DISP_P2_S) then
--                compliment := '1';
--                nextDisp   := DISP_P2_S;
--             else
--                nextDisp := DisparityType'rightof(blockDisp);
--                nextDisp := DisparityType'rightof(nextDisp);
--             end if;

--       end case;
--    end procedure disparityControl;

   procedure disparityControl (
      prevDisp   : in    RunDisparityType;
      blockDisp  : in    BlockDisparityType;
      compliment : inout sl;
      runDisp    : inout RunDisparityType)
   is
      variable tmp : integer;
      variable b   : BlockDisparityType;
   begin
      compliment := '0';

      tmp := toBlockDisparityType(prevDisp) + blockDisp;

      if ((prevDisp = "10" and tmp = 4) or
          tmp > 4 or tmp <= -4) then
         compliment := '1';
         tmp        := toBlockDisparityType(prevDisp) - blockDisp;
      end if;
      b       := tmp;
      runDisp := toSlv(b);
   end procedure;

   -------------------------------------------------------------------------------------------------
   -- Make the encode table
   function makeEncode7b8bTable(a : slv8Array(0 to 127)) return Encode7b8bArray is
      variable ret : Encode7b8bArray(0 to 127);
   begin
      for i in ret'range loop
         ret(i).in7b    := conv_std_logic_vector(i, 7);
         ret(i).out8b   := a(i);
         ret(i).outDisp := getDisparity(ret(i).out8b);
         ret(i).altDisp := getDisparity(not ret(i).out8b);
         if (ret(i).outDisp /= 0) then
            ret(i).alt8b := not (ret(i).out8b);
         else
            ret(i).alt8b := ret(i).out8b;
         end if;
      end loop;
      return ret;
   end function makeEncode7b8bTable;

   -- Make the decode table
--    function makeDecode7b8bArray return Decode7b8bArray is
--       variable ret : Decode7b8bArray := (others => DECODE_7B8B_INIT_C);
--       variable tmp : integer;
--    begin
--       for i in ENCODE_7B8B_TABLE_C'range loop
--          tmp            := conv_integer(ENCODE_7B8B_TABLE_C(i).out8b);
--          ret(tmp).valid := '1'
--          ret(tmp).out7b := conv_std_logic_vector(i, 7);

--          tmp            := conv_integer(ENCODE_7B8B_TABLE_C(i).alt8b);
--          ret(tmp).valid := '1';
--          ret(tmp).out7b := conv_std_logic_vector(i, 7);
--       end loop;
--       return ret;
--    end function makeDecode7b8bArray;

   -------------------------------------------------------------------------------------------------
   -- Make the encode table
   function makeEncode5b6bTable (a : slv6Array(0 to 31)) return Encode5b6bArray is
      variable ret : Encode5b6bArray(0 to 31);
   begin
      for i in ret'range loop
         ret(i).in5b    := conv_std_logic_vector(i, 5);
         ret(i).out6b   := a(i);
         ret(i).outDisp := getDisparity(ret(i).out6b);
         ret(i).altDisp := getDisparity(not ret(i).out6b);
         if (ret(i).outDisp /= 0) then
            ret(i).alt6b := not (ret(i).out6b);
         else
            ret(i).alt6b := ret(i).out6b;
         end if;
         if (ret(i).out6b = "000111") then
            ret(i).alt6b := "111000";
         end if;
      end loop;
      return ret;
   end function makeEncode5b6bTable;

   -- Make the decode table
--    function makeDecode5b6bArray return Decode5b6bArray is
--       variable ret : Decode5b6bArray := (others => DECODE_5B6B_INIT_C);
--       variable tmp : integer;
--    begin
--       for i in ENCODE_5B6B_TABLE_C'range loop
--          tmp            := conv_integer(ENCODE_5B6B_TABLE_C(i).out6b);
--          ret(tmp).valid := '1'
--          ret(tmp).out5b := conv_std_logic_vector(i, 7);

--          tmp            := conv_integer(ENCODE_5B6B_TABLE_C(i).alt6b);
--          ret(tmp).valid := '1';
--          ret(tmp).out5b := conv_std_logic_vector(i, 7);
--       end loop;
--       return ret;
--    end function makeDecode5b6bArray;



   procedure encode12b14b (
      constant CODES_C : in  EncodeTableType;
      dataIn           : in  slv(11 downto 0);
      dataKIn          : in  sl;
      dispIn           : in  RunDisparityType;
      dataOut          : out slv(13 downto 0);
      dispOut          : out RunDisparityType;
      invalidK         : out sl)
   is
      variable blockDispIn : BlockDisparityType;

      variable dataIn7     : slv(6 downto 0);
      variable tmp78       : Encode7b8bType;
      variable data8       : slv(7 downto 0);
      variable blockDisp78 : BlockDisparityType;

      variable dataIn5     : slv(4 downto 0);
      variable tmp56       : Encode5b6bType;
      variable data6       : slv(5 downto 0);
      variable blockDisp56 : BlockDisparityType;

      variable debug : boolean := false;
      variable tmp   : integer;
   begin



      -- First, split in input word in two
      dataIn5 := dataIn(11 downto 7);
      dataIn7 := dataIn(6 downto 0);

      -- Now do the 7b8b part
      -- Default lookup first
      tmp78       := CODES_C.data78(conv_integer(dataIn7));
      data8       := tmp78.out8b;
      blockDisp78 := tmp78.outDisp;

      -- Override normal table lookup for control codes
      if (dataKIn = '1') then
         invalidK := '1';
         -- Search the table for valid K.x
         for i in CODES_C.k78'range loop
            if (dataIn7 = CODES_C.k78(i).in7b) then
               tmp78       := CODES_C.k78(i);
               data8       := tmp78.out8b;
               blockDisp78 := tmp78.outDisp;
               invalidK    := '0';
            end if;
         end loop;
      end if;

      -- Decide whether to invert
      blockDispIn := toBlockDisparityType(dispIn);
      tmp         := blockDispIn + tmp78.outDisp;

      if ((dispIn = "10" and tmp = 4) or tmp > 4 or tmp <= -4) then
         blockDisp78 := tmp78.altDisp;
         data8       := tmp78.alt8b;
      end if;

      -- Special case for D15
--       if (dataIn7 = "0001111" and (dispIn = DISP_P2_S or dispIn = DISP_P4_S)) then
--          compliment := '1';
--       end if;


      -- Now repeat for the 5b6b
      tmp56       := CODES_C.data56(conv_integer(dataIn5));
      data6       := tmp56.out6b;
      blockDisp56 := tmp56.outDisp;


      -- Hard code the K codes
--       if (dataKIn = '1' and invalidK = '0') then
--          invalidk := '1';

--          -- If on a K.120.y, check for valid y
--          if (dataIn7 = K_120_C) then      -- K.120
--             -- Search for a valid K.120.y
--             for i in K_5B6B_TABLE_C'range loop
--                if (dataIn5 = K_5B6B_TABLE_C(i).b6) then
--                   data6     := K_5B6B_TABLE_C(i).b6;
--                   blockDisp := K_5B6B_TABLE_C(i).outDisp;
--                   invalidK  := '0';
--                end if;
--             end loop;
--          end if;

--          -- If on a K.x.15, check for valid x
--          if (dataIn5 = K_X_15_C) then     -- K.x.15
--             data6     := K_X_15_CODE_C;
--             blockDisp := K_X_15_DISP_C;
--             for i in K_7B8B_TABLE_C'range loop
--                if (dataIn7 = K_7B8B_TABLE_C(i).b7) then
--                   invalidK := '0';
--                end if;
--             end loop;
--          end if;
--       end if;

      -- Decide whether to invert the output
      if ((blockDisp78 > 0 and blockDisp56 > 0) or
          (blockDisp78 < 0 and blockDisp56 < 0) or
          (blockDisp78 = 0 and blockDispIn > 0 and blockDisp56 > 0) or
          (blockDisp78 = 0 and blockDispIn < 0 and blockDisp56 < 0)) then
         blockDisp56 := tmp56.altDisp;
         data6       := tmp56.alt6b;
      end if;


      -- Special case for D/K.x.7
      -- Code is balanced but need to invert to avoid run length limits
      if (dataIn5 = "00111" and (blockDisp78 > 0)) then
         blockDisp56 := tmp56.altDisp;
         data6       := tmp56.alt6b;
      end if;


      dataOut(7 downto 0)  := data8;
      dataOut(13 downto 8) := data6;
      dispOut              := toSlv(blockDispIn + blockDisp56 + blockDisp78);

      -- If k-code being sent, override everything above and select the proper code
      -- from the K_CODE_TABLE_C.
--       if (dataKIn = '1')495 then
--          invalidK := '1';
--          -- Search table of KCODES
--          for i in CODES_C.codeK'range loop
--             if (dataIn = CODES_C.codeK(i).k12) then
--                dataOut   := CODES_C.codeK(i).k14;
--                blockDisp := CODES_C.codeK(i).outDisp;
--                disparityControl(dispIn, dispIn, blockDisp, compliment, dispK);
--                if (compliment = '1') then
--                   dataOut := not CODES_C.codeK(i).k14;
--                end if;
--                dispOut  := dispK;
--                invalidK := '0';
--             end if;
--          end loop;
--       end if;


   end;

   procedure decode12b14b (
      constant CODES_C : in    EncodeTableType;
      dataIn           : in    slv(13 downto 0);
      dispIn           : in    RunDisparityType;
      dataOut          : out   slv(11 downto 0);
      dataKOut         : inout sl;
      dispOut          : inout RunDisparityType;
      codeError        : out   sl;
      dispError        : inout sl)
   is
      variable valid78   : sl;
      variable valid56   : sl;
      variable dataIn8   : slv(7 downto 0);
      variable dataIn6   : slv(5 downto 0);
      variable dataOut5  : slv(4 downto 0);
      variable dataOut7  : slv(6 downto 0);
      variable inputDisp : integer;
      variable runDisp   : integer;
   begin

      -- Set default values
      codeError := '1';
      dispError := '0';
      dataKOut  := '0';
      valid78   := '0';
      valid56   := '0';
      dataOut5  := (others => '0');
      dataOut7  := (others => '0');


      -- Check the disparity of the input
      inputDisp := getDisparity(dataIn);
      if (inputDisp > 4 or inputDisp < -4) then
--          print("Input Disp Error");
--          print("dataIn: " & str(dataIn));
--          print("inputDisp: " & str(inputDisp));
         dispError := '1';
      end if;

      -- Check the running disparity
      runDisp := inputDisp + toBlockDisparityType(dispIn);
      if (runDisp > 4 or runDisp < -2) then
--          print("Run Disp Error");
--          print("dataIn: " & str(dataIn));
--          print("inputDisp: " & str(inputDisp));
--          print("runDisp: " & str(runDisp));         
         dispError := '1';
      end if;

      -- This probably isn't correct
      -- Need to figure out what to do when running disparity is out of range
      dispOut := toSlv(runDisp);
--       if (dispError = '1') then
--          dispOut := toSlv(0);
--       end if;



      dataIn8 := dataIn(7 downto 0);
      dataIn6 := dataIn(13 downto 8);

      dataOut7 := dataIn8(6 downto 0);
      dataOut5 := dataIn6(4 downto 0);

      -- Check for a k-code
      for i in CODES_C.k78'range loop
         if (dataIn8 = CODES_C.k78(i).out8b or
             dataIn8 = CODES_C.k78(i).alt8b) then
            dataOut7 := CODES_C.k78(i).in7b;
            dataKOut := '1';
            valid78  := '1';
            exit;
         end if;
      end loop;

      -- Need to check for valid k5/6 code
      if (dataKout = '1') then
         for i in CODES_C.k56'range loop
            if (dataIn6 = CODES_C.k56(i).out6b or
                dataIn6 = CODES_C.k56(i).alt6b) then
               dataOut5  := CODES_C.k56(i).in5b;
               dataKOut  := '1';
               valid56   := '1';
               codeError := '0';
               exit;
            end if;
         end loop;
      end if;

      if (dataKOut = '0') then
         -- Decode 7/8
         for i in CODES_C.data78'range loop
            if (dataIn8 = CODES_C.data78(i).out8b or
                dataIn8 = CODES_C.data78(i).alt8b) then
               dataOut7 := CODES_C.data78(i).in7b;
               valid78  := '1';
               exit;
            end if;
         end loop;

         for i in CODES_C.data56'range loop
            if (dataIn6 = CODES_C.data56(i).out6b or
                dataIn6 = CODES_C.data56(i).alt6b) then
               dataOut5 := CODES_C.data56(i).in5b;
               valid56  := '1';
               exit;
            end if;
         end loop;

      end if;

      if (valid56 = '1' and valid78 = '1') then
         codeError := '0';
      end if;

      dataOut(6 downto 0)  := dataOut7;
      dataOut(11 downto 7) := dataOut5;



   end procedure decode12b14b;


end package body Code12b14bPkg;
