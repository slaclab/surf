-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Provides functions for handling text.
------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use std.textio.all;

library surf;
use surf.StdRtlPkg.all;

package TextUtilPkg is

   -- prints a message to the screen
   procedure print(text : string);

   -- prints the message when active
   -- useful for debug switches
   procedure print(active : boolean; text : string);

   -- converts std_logic into a character
   function chr(sl : std_logic) return character;

   -- converts std_logic into a string (1 to 1)
   function str(sl : std_logic) return string;

   -- converts std_logic_vector into a string (binary base)
   function str(slv : std_logic_vector) return string;

   -- converts boolean into a string
   function str(b : boolean) return string;

   -- converts an integer into a single character
   -- (can also be used for hex conversion and other bases)
   function chr(int : integer) return character;

   -- Converts a character into an integer
   function int(c : character) return integer;
   
   -- converts integer into string using specified base
   function str(int : integer; base : integer) return string;

   -- converts a string with specified base into an integer
   function int(s : string; base : integer) return integer;

   -- converts integer to string, using base 10
   function str(int : integer) return string;

   -- converts a time to a string
   function str (tim : time) return string;

   -- convert std_logic_vector into a string in hex format
   function hstr(slv : std_logic_vector) return string;

   ----------------------------------
   -- functions to manipulate strings
   -----------------------------------

   -- convert a character to upper case
   function toUpper(c : character) return character;

   -- convert a character to lower case
   function toLower(c : character) return character;

   -- convert a string to upper case
   function toUpper(s : string) return string;

   -- convert a string to lower case
   function toLower(s : string) return string;

   -- checks if whitespace (JFF)
   function isWhitespace(c : character) return boolean;

   -- remove leading whitespace (JFF)
   function strip(s : string) return string;

   -- return first nonwhitespace substring (JFF)
   function firstString(s : string) return string;

   -- finds the first non-whitespace substring in a string and (JFF)  
   -- returns both the substring and the original with the substring removed 
   procedure chomp(variable s : inout string; variable shead : out string);


   -------------------------------------------------- 
   -- functions to convert strings into other formats
   --------------------------------------------------

   -- converts a character into std_logic
   function toSl(c : character) return std_logic;

   -- converts a string into std_logic_vector
   function toSlv(s : string) return std_logic_vector;


   -----------
   -- file I/O
   -----------

   -- read variable length string from input file
   procedure strRead(file in_file :     text;
                     res_string   : out string);

   -- print string to a file and start new line
   procedure print(file out_file :    text;
                   new_string    : in string);

   -- print character to a file and start new line
   procedure print(file out_file :    text;
                   char          : in character);



end TextUtilPkg;

package body TextUtilPkg is

   -- prints text to the screen
   procedure print(text : string) is
      variable msg_line : line;
   begin
      write(msg_line, text);
      writeline(output, msg_line);
   end print;

   -- prints text to the screen when active
   procedure print(active : boolean; text : string) is
   begin
      if active then
         print(text);
      end if;
   end print;

   -- converts std_logic into a character
   function chr(sl : std_logic) return character is
      variable c : character;
   begin
      case sl is
         when 'U' => c := 'U';
         when 'X' => c := 'X';
         when '0' => c := '0';
         when '1' => c := '1';
         when 'Z' => c := 'Z';
         when 'W' => c := 'W';
         when 'L' => c := 'L';
         when 'H' => c := 'H';
         when '-' => c := '-';
      end case;
      return c;
   end chr;

   -- converts std_logic into a string (1 to 1)
   function str(sl : std_logic) return string is
      variable s : string(1 to 1);
   begin
      s(1) := chr(sl);
      return s;
   end str;

   -- converts std_logic_vector into a string (binary base)
   -- (this also takes care of the fact that the range of
   --  a string is natural while a std_logic_vector may
   --  have an integer range)
   function str(slv : std_logic_vector) return string is
      variable result : string (1 to slv'length);
      variable r      : integer;
   begin
      r := 1;
      for i in slv'range loop
         result(r) := chr(slv(i));
         r         := r + 1;
      end loop;
      return result;
   end str;

   -- Converts a boolean into "true" or "false"
   function str(b : boolean) return string is
   begin
      if b then
         return "true";
      else
         return "false";
      end if;
   end str;

   -- converts an integer into a character
   -- for 0 to 9 the obvious mapping is used, higher
   -- values are mapped to the characters A-Z
   -- (this is usefull for systems with base > 10)
   -- (adapted from Steve Vogwell's posting in comp.lang.vhdl)
   function chr(int : integer) return character is
      variable c : character;
   begin
      case int is
         when 0      => c := '0';
         when 1      => c := '1';
         when 2      => c := '2';
         when 3      => c := '3';
         when 4      => c := '4';
         when 5      => c := '5';
         when 6      => c := '6';
         when 7      => c := '7';
         when 8      => c := '8';
         when 9      => c := '9';
         when 10     => c := 'A';
         when 11     => c := 'B';
         when 12     => c := 'C';
         when 13     => c := 'D';
         when 14     => c := 'E';
         when 15     => c := 'F';
         when 16     => c := 'G';
         when 17     => c := 'H';
         when 18     => c := 'I';
         when 19     => c := 'J';
         when 20     => c := 'K';
         when 21     => c := 'L';
         when 22     => c := 'M';
         when 23     => c := 'N';
         when 24     => c := 'O';
         when 25     => c := 'P';
         when 26     => c := 'Q';
         when 27     => c := 'R';
         when 28     => c := 'S';
         when 29     => c := 'T';
         when 30     => c := 'U';
         when 31     => c := 'V';
         when 32     => c := 'W';
         when 33     => c := 'X';
         when 34     => c := 'Y';
         when 35     => c := 'Z';
         when others => c := '?';
      end case;
      return c;
   end chr;

   -- Convert a character into an integer.
   function int (c : character) return integer is
      variable tmp : character;
   begin
      tmp := toUpper(c);
      case tmp is
         when '0'    => return 0;
         when '1'    => return 1;
         when '2'    => return 2;
         when '3'    => return 3;
         when '4'    => return 4;
         when '5'    => return 5;
         when '6'    => return 6;
         when '7'    => return 7;
         when '8'    => return 8;
         when '9'    => return 9;
         when 'A'    => return 10;
         when 'B'    => return 11;
         when 'C'    => return 12;
         when 'D'    => return 13;
         when 'E'    => return 14;
         when 'F'    => return 15;
         when 'G'    => return 16;
         when 'H'    => return 17;
         when 'I'    => return 18;
         when 'J'    => return 19;
         when 'K'    => return 20;
         when 'L'    => return 21;
         when 'M'    => return 22;
         when 'N'    => return 23;
         when 'O'    => return 24;
         when 'P'    => return 25;
         when 'Q'    => return 26;
         when 'R'    => return 27;
         when 'S'    => return 28;
         when 'T'    => return 29;
         when 'U'    => return 30;
         when 'V'    => return 31;
         when 'W'    => return 32;
         when 'X'    => return 33;
         when 'Y'    => return 34;
         when 'Z'    => return 35;
         when others => return -1;
      end case;
   end function int;

   -- convert integer to string using specified base
   -- (adapted from Steve Vogwell's posting in comp.lang.vhdl)
   function str(int : integer; base : integer) return string is
      variable temp    : string(1 to 10);
      variable num     : integer;
      variable abs_int : integer;
      variable len     : integer := 1;
      variable power   : integer := 1;
   begin
      -- bug fix for negative numbers
      abs_int := abs(int);
      num     := abs_int;

      while num >= base loop            -- Determine how many
         len := len + 1;                -- characters required
         num := num / base;             -- to represent the
      end loop;  -- number.

      for i in len downto 1 loop                  -- Convert the number to
         temp(i) := chr(abs_int/power mod base);  -- a string starting
         power   := power * base;                 -- with the right hand
      end loop;  -- side.

      -- return result and add sign if required
      if int < 0 then
         return '-'& temp(1 to len);
      else
         return temp(1 to len);
      end if;

   end str;

   -- Convert a string and base into an integer.
   function int (s : string; base : integer) return integer is
      variable ret : integer;
      variable tmp : integer;
   begin
      ret := 0;
      for i in s'range loop
         tmp := int(s(i));
         assert (tmp < base and tmp >= 0) report
            "TextUtilPkg::int(string, integer): Input string (" & s & ") " &
            "has character (" & s(i) & ") outside of base (" & str(base) & ") character set."
            severity error;
         ret := ret * base + tmp;
      end loop;
      return ret;
   end function int;


   -- convert integer to string, using base 10
   function str(int : integer) return string is
   begin
      return str(int, 10);
   end str;

   -- convert a time to string
   function str (tim : time) return string is
   begin
      return time'image(tim);
   end str;

   -- converts a std_logic_vector into a hex string.
   function hstr(slv : std_logic_vector) return string is
      constant hexlen  : integer                                 := ite(slv'length mod 4 = 0, slv'length/4, slv'length/4 +1);
      variable longslv : std_logic_vector(slv'length+3 downto 0) := (others => '0');
      variable hex     : string(1 to hexlen);
      variable fourbit : std_logic_vector(3 downto 0);
   begin
      longslv(slv'length-1 downto 0) := slv;
      for i in (hexlen -1) downto 0 loop
         fourbit := longslv(((i*4)+3) downto (i*4));
         case fourbit is
            when "0000" => hex(hexlen -I) := '0';
            when "0001" => hex(hexlen -I) := '1';
            when "0010" => hex(hexlen -I) := '2';
            when "0011" => hex(hexlen -I) := '3';
            when "0100" => hex(hexlen -I) := '4';
            when "0101" => hex(hexlen -I) := '5';
            when "0110" => hex(hexlen -I) := '6';
            when "0111" => hex(hexlen -I) := '7';
            when "1000" => hex(hexlen -I) := '8';
            when "1001" => hex(hexlen -I) := '9';
            when "1010" => hex(hexlen -I) := 'A';
            when "1011" => hex(hexlen -I) := 'B';
            when "1100" => hex(hexlen -I) := 'C';
            when "1101" => hex(hexlen -I) := 'D';
            when "1110" => hex(hexlen -I) := 'E';
            when "1111" => hex(hexlen -I) := 'F';
            when "ZZZZ" => hex(hexlen -I) := 'z';
            when "UUUU" => hex(hexlen -I) := 'u';
            when "XXXX" => hex(hexlen -I) := 'x';
            when others => hex(hexlen -I) := '?';
         end case;
      end loop;
--      print("HSTR Out: " & hex(1 to hexlen));      
      return hex(1 to hexlen);
   end hstr;

   ---------------------------------------------------------------------------------------------------------------------
   -- functions to manipulate strings
   ---------------------------------------------------------------------------------------------------------------------

   -- convert a character to upper case
   function toUpper(c : character) return character is
      variable u : character;
   begin
      case c is
         when 'a'    => u := 'A';
         when 'b'    => u := 'B';
         when 'c'    => u := 'C';
         when 'd'    => u := 'D';
         when 'e'    => u := 'E';
         when 'f'    => u := 'F';
         when 'g'    => u := 'G';
         when 'h'    => u := 'H';
         when 'i'    => u := 'I';
         when 'j'    => u := 'J';
         when 'k'    => u := 'K';
         when 'l'    => u := 'L';
         when 'm'    => u := 'M';
         when 'n'    => u := 'N';
         when 'o'    => u := 'O';
         when 'p'    => u := 'P';
         when 'q'    => u := 'Q';
         when 'r'    => u := 'R';
         when 's'    => u := 'S';
         when 't'    => u := 'T';
         when 'u'    => u := 'U';
         when 'v'    => u := 'V';
         when 'w'    => u := 'W';
         when 'x'    => u := 'X';
         when 'y'    => u := 'Y';
         when 'z'    => u := 'Z';
         when others => u := c;
      end case;
      return u;
   end toUpper;

   -- convert a character to lower case
   function toLower(c : character) return character is
      variable l : character;
   begin
      case c is
         when 'A'    => l := 'a';
         when 'B'    => l := 'b';
         when 'C'    => l := 'c';
         when 'D'    => l := 'd';
         when 'E'    => l := 'e';
         when 'F'    => l := 'f';
         when 'G'    => l := 'g';
         when 'H'    => l := 'h';
         when 'I'    => l := 'i';
         when 'J'    => l := 'j';
         when 'K'    => l := 'k';
         when 'L'    => l := 'l';
         when 'M'    => l := 'm';
         when 'N'    => l := 'n';
         when 'O'    => l := 'o';
         when 'P'    => l := 'p';
         when 'Q'    => l := 'q';
         when 'R'    => l := 'r';
         when 'S'    => l := 's';
         when 'T'    => l := 't';
         when 'U'    => l := 'u';
         when 'V'    => l := 'v';
         when 'W'    => l := 'w';
         when 'X'    => l := 'x';
         when 'Y'    => l := 'y';
         when 'Z'    => l := 'z';
         when others => l := c;
      end case;
      return l;
   end toLower;

   -- convert a string to upper case
   function toUpper(s : string) return string is
      variable uppercase : string (s'range);
   begin
      for i in s'range loop
         uppercase(i) := toUpper(s(i));
      end loop;
      return uppercase;
   end toUpper;

   -- convert a string to lower case
   function toLower(s : string) return string is
      variable lowercase : string (s'range);
   begin
      for i in s'range loop
         lowercase(i) := toLower(s(i));
      end loop;
      return lowercase;
   end toLower;

   ---------------------------------------------------------------------------------------------------------------------


   -- checks if whitespace (JFF)
   function isWhitespace(c : character) return boolean is
   begin
      if (c = ' ') or (c = HT) then
         return true;
      else return false;
      end if;
   end isWhitespace;


   -- remove leading whitespace (JFF)
   function strip(s : string) return string is
      variable stemp : string (s'range);
      variable j, k  : positive := 1;
   begin
      -- fill stemp with blanks
      for i in s'range loop
         stemp(i) := ' ';
      end loop;

      -- find first non-whitespace in s
      for i in s'range loop
         if isWhitespace(s(i)) then
            j := j + 1;
         else exit;
         end if;
      end loop;
      -- j points to first non-whitespace

      -- copy remainder of s into stemp
      -- starting at 1
      for i in j to s'length loop
         stemp(k) := s(i);
         k        := k + 1;
      end loop;

      return stemp;
   end strip;



   -- return first non-whitespacesubstring (JFF)
   function firstString(s : string) return string is
      variable stemp : string (s'range);
      variable s2    : string(s'range);
   begin
      -- fill s2 with blanks
      for i in s'range loop
         s2(i) := ' ';
      end loop;

      -- remove leading whitespace
      stemp := strip(s);

      -- copy until first whitespace
      for i in stemp'range loop
         if not isWhitespace(stemp(i)) then
            s2(i) := stemp(i);
         else exit;
         end if;
      end loop;

      return s2;
   end firstString;


   -- removes first non-whitespace string from a string (JFF)
   procedure chomp(variable s : inout string; variable shead : out string) is
      variable stemp  : string (s'range);
      variable stemp2 : string (s'range);
      variable j      : positive := 1;
      variable k      : positive := 1;
   begin
      -- fill stemp and stemp2 with blanks
      for i in s'range loop
         stemp(i) := ' '; stemp2(i) := ' ';
      end loop;

      stemp := strip(s);
      shead := firstString(stemp);

      -- find first whitespace in stemp
      for i in stemp'range loop
         if not isWhitespace(stemp(i)) then
            j := j + 1;
         else exit;
         end if;
      end loop;
      -- j points to first whitespace

      -- copy remainder of stemp into stemp2
      -- starting at 1
      for i in j to stemp'length loop
         stemp2(k) := stemp(i);
         k         := k + 1;
      end loop;

      s := stemp2;
   end chomp;



   -- functions to convert strings into other types
   ---------------------------------------------------------------------------------------------------------------------

   -- converts a character into a std_logic
   function toSl(c : character) return std_logic is
      variable sl : std_logic;
   begin
      case c is
         when 'U' =>
            sl := 'U';
         when 'X' =>
            sl := 'X';
         when '0' =>
            sl := '0';
         when '1' =>
            sl := '1';
         when 'Z' =>
            sl := 'Z';
         when 'W' =>
            sl := 'W';
         when 'L' =>
            sl := 'L';
         when 'H' =>
            sl := 'H';
         when '-' =>
            sl := '-';
         when others =>
            sl := 'X';
      end case;
      return sl;
   end toSl;


   -- converts a string into std_logic_vector
   function toSlv(s : string) return std_logic_vector is
      variable slv : std_logic_vector(s'high-s'low downto 0);
      variable k   : integer;
   begin
      k := s'high-s'low;
      for i in s'range loop
         slv(k) := toSl(s(i));
         k      := k - 1;
      end loop;
      return slv;
   end toSlv;

   ---------------------------------------------------------------------------------------------------------------------
   -- file I/O  -- 
   ---------------------------------------------------------------------------------------------------------------------

   -- read variable length string from input file
   procedure strRead(file in_file :     text;
                     res_string   : out string) is
      variable l         : line;
      variable c         : character;
      variable is_string : boolean;
   begin
      readline(in_file, l);
      -- clear the contents of the result string
      for i in res_string'range loop
         res_string(i) := ' ';
      end loop;
      -- read all characters of the line, up to the length  
      -- of the results string
      for i in res_string'range loop
         read(l, c, is_string);
         res_string(i) := c;
         if not is_string then          -- found end of line
            exit;
         end if;
      end loop;
   end strRead;


   -- print string to a file
   procedure print(file out_file :    text;
                   new_string    : in string) is
      variable l : line;
   begin
      write(l, new_string);
      writeline(out_file, l);
   end print;


   -- print character to a file and start new line
   procedure print(file out_file :    text;
                   char          : in character) is
      variable l : line;
   begin
      write(l, char);
      writeline(out_file, l);
   end print;

   -- appends contents of a string to a file until line feed occurs
   -- (LF is considered to be the end of the string)
   procedure strWrite(file out_file :    text;
                      new_string    : in string) is
   begin
      for i in new_string'range loop
         print(out_file, new_string(i));
         if new_string(i) = LF then     -- end of string
            exit;
         end if;
      end loop;
   end strWrite;


end TextUtilPkg;




