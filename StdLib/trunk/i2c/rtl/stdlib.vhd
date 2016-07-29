------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2012, Aeroflex Gaisler
--
--  This program is free software; you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation; either version 2 of the License, or
--  (at your option) any later version.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program; if not, write to the Free Software
--  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA 
-----------------------------------------------------------------------------
-- Package: 	stdlib
-- File:	stdlib.vhd
-- Author:	Jiri Gaisler - Gaisler Research
-- Description:	Package for common VHDL functions
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
-- pragma translate_off
use std.textio.all;
-- pragma translate_on
--library grlib;
--use grlib.version.all;

package stdlib is

--constant LIBVHDL_VERSION : integer := grlib_version;
--constant LIBVHDL_BUILD : integer := grlib_build;
---- pragma translate_off
--constant LIBVHDL_DATE : string := grlib_date;
---- pragma translate_on
constant zero32 : std_logic_vector(31 downto 0) := (others => '0');
constant zero64 : std_logic_vector(63 downto 0) := (others => '0');
constant zero128 : std_logic_vector(127 downto 0) := (others => '0');
constant one32  : std_logic_vector(31 downto 0) := (others => '1');
constant one64  : std_logic_vector(63 downto 0) := (others => '1');
constant one128  : std_logic_vector(127 downto 0) := (others => '1');

type log2arr is array(0 to 512) of integer;
constant log2   : log2arr := (
0,0,1,2,2,3,3,3,3,4,4,4,4,4,4,4,4,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,
  6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,
  7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
  7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
  8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
  8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
  8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
  8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
  others => 9);
constant log2x  : log2arr := (
0,1,1,2,2,3,3,3,3,4,4,4,4,4,4,4,4,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,
  6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,
  7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
  7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
  8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
  8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
  8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
  8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
  others => 9);

function decode(v : std_logic_vector) return std_logic_vector;
function genmux(s,v : std_logic_vector) return std_ulogic;
function xorv(d : std_logic_vector) return std_ulogic;
function orv(d : std_logic_vector) return std_ulogic;
function andv(d : std_logic_vector) return std_ulogic;
function notx(d : std_logic_vector) return boolean;
function notx(d : std_ulogic) return boolean;
function "-" (d : std_logic_vector; i : integer) return std_logic_vector;
function "-" (i : integer; d : std_logic_vector) return std_logic_vector;
function "+" (d : std_logic_vector; i : integer) return std_logic_vector;
function "+" (i : integer; d : std_logic_vector) return std_logic_vector;
function "-" (d : std_logic_vector; i : std_ulogic) return std_logic_vector;
function "+" (d : std_logic_vector; i : std_ulogic) return std_logic_vector;
function "-" (a, b : std_logic_vector) return std_logic_vector;
function "+" (a, b : std_logic_vector) return std_logic_vector;
function "*" (a, b : std_logic_vector) return std_logic_vector;
function unsigned_mul (a, b : std_logic_vector) return std_logic_vector;
function signed_mul (a, b : std_logic_vector) return std_logic_vector;
function mixed_mul (a, b : std_logic_vector; sign : std_logic) return std_logic_vector;
--function ">" (a, b : std_logic_vector) return boolean;
function "<" (i : integer; b : std_logic_vector) return boolean;
function conv_integer(v : std_logic_vector) return integer;
function conv_integer(v : std_logic) return integer;
function conv_std_logic_vector(i : integer; w : integer) return std_logic_vector;
function conv_std_logic_vector_signed(i : integer; w : integer) return std_logic_vector;
function conv_std_logic(b : boolean) return std_ulogic;
attribute sync_set_reset : string;
attribute async_set_reset : string;

-- Reporting and diagnostics

-- pragma translate_off

function tost(v:std_logic_vector) return string;
function tost(v:std_logic) return string;
function tost(i : integer) return string;
function tost_any(s: std_ulogic) return string;
function tost_bits(s: std_logic_vector) return string;
function tost(b: boolean) return string;
function tost(r: real) return string;
procedure print(s : string);

component report_version
  generic (msg1, msg2, msg3, msg4 : string := ""; mdel : integer := 4);
end component;

-- pragma translate_on

end;

package body stdlib is

function notx(d : std_logic_vector) return boolean is
variable res : boolean;
begin
  res := true;
-- pragma translate_off
  res := not is_x(d);
-- pragma translate_on
  return (res);
end;

function notx(d : std_ulogic) return boolean is
variable res : boolean;
begin
  res := true;
-- pragma translate_off
  res := not is_x(d);
-- pragma translate_on
  return (res);
end;

-- generic decoder

function decode(v : std_logic_vector) return std_logic_vector is
variable res : std_logic_vector((2**v'length)-1 downto 0);
variable i : integer;
begin
  res := (others => '0'); i := 0;
  if notx(v) then i := to_integer(unsigned(v)); end if;
  res(i) := '1';
  return(res);
end;

-- generic multiplexer

function genmux(s,v : std_logic_vector) return std_ulogic is
variable res : std_logic_vector(v'length-1 downto 0);
variable i : integer;
begin
  res := v; i := 0;
  if notx(s) then i := to_integer(unsigned(s)); end if;
  return(res(i));
end;

-- vector XOR

function xorv(d : std_logic_vector) return std_ulogic is
variable tmp : std_ulogic;
begin
  tmp := '0';
  for i in d'range loop tmp := tmp xor d(i); end loop;
  return(tmp);
end;

-- vector OR

function orv(d : std_logic_vector) return std_ulogic is
variable tmp : std_ulogic;
begin
  tmp := '0';
  for i in d'range loop tmp := tmp or d(i); end loop;
  return(tmp);
end;

-- vector AND

function andv(d : std_logic_vector) return std_ulogic is
variable tmp : std_ulogic;
begin
  tmp := '1';
  for i in d'range loop tmp := tmp and d(i); end loop;
  return(tmp);
end;

-- unsigned multiplication

function "*" (a, b : std_logic_vector) return std_logic_vector is
variable z : std_logic_vector(a'length+b'length-1 downto 0);
begin
-- pragma translate_off
  if notx(a&b) then
-- pragma translate_on
    return(std_logic_vector(unsigned(a) * unsigned(b)));
-- pragma translate_off
  else
     z := (others =>'X'); return(z);
  end if;
-- pragma translate_on
end;

-- signed multiplication

function signed_mul (a, b : std_logic_vector) return std_logic_vector is
variable z : std_logic_vector(a'length+b'length-1 downto 0);
begin
-- pragma translate_off
  if notx(a&b) then
-- pragma translate_on
    return(std_logic_vector(signed(a) * signed(b)));
-- pragma translate_off
  else
     z := (others =>'X'); return(z);
  end if;
-- pragma translate_on
end;

-- unsigned multiplication

function unsigned_mul (a, b : std_logic_vector) return std_logic_vector is
variable z : std_logic_vector(a'length+b'length-1 downto 0);
begin
-- pragma translate_off
  if notx(a&b) then
-- pragma translate_on
    return(std_logic_vector(unsigned(a) * unsigned(b)));
-- pragma translate_off
  else
     z := (others =>'X'); return(z);
  end if;
-- pragma translate_on
end;

-- signed/unsigned multiplication

function mixed_mul (a, b : std_logic_vector; sign : std_logic) return std_logic_vector is
variable z : std_logic_vector(a'length+b'length-1 downto 0);
begin
-- pragma translate_off
  if notx(a&b) then
-- pragma translate_on
    if sign = '0' then
      return(std_logic_vector(unsigned(a) * unsigned(b)));
    else
      return(std_logic_vector(signed(a) * signed(b)));
    end if;
-- pragma translate_off
  else
     z := (others =>'X'); return(z);
  end if;
-- pragma translate_on
end;

-- unsigned addition

function "+" (a, b : std_logic_vector) return std_logic_vector is
variable x : std_logic_vector(a'length-1 downto 0);
variable y : std_logic_vector(b'length-1 downto 0);
begin
-- pragma translate_off
  if notx(a&b) then
-- pragma translate_on
    return(std_logic_vector(unsigned(a) + unsigned(b)));
-- pragma translate_off
  else
     x := (others =>'X'); y := (others =>'X');
     if (x'length > y'length) then return(x); else return(y); end if;
  end if;
-- pragma translate_on
end;

function "+" (i : integer; d : std_logic_vector) return std_logic_vector is
variable x : std_logic_vector(d'length-1 downto 0);
begin
-- pragma translate_off
  if notx(d) then
-- pragma translate_on
    return(std_logic_vector(unsigned(d) + i));
-- pragma translate_off
  else x := (others =>'X'); return(x);
  end if;
-- pragma translate_on
end;

function "+" (d : std_logic_vector; i : integer) return std_logic_vector is
variable x : std_logic_vector(d'length-1 downto 0);
begin
-- pragma translate_off
  if notx(d) then
-- pragma translate_on
    return(std_logic_vector(unsigned(d) + i));
-- pragma translate_off
  else x := (others =>'X'); return(x);
  end if;
-- pragma translate_on
end;

function "+" (d : std_logic_vector; i : std_ulogic) return std_logic_vector is
variable x : std_logic_vector(d'length-1 downto 0);
variable y : std_logic_vector(0 downto 0);
begin
  y(0) := i;
-- pragma translate_off
  if notx(d) then
-- pragma translate_on
    return(std_logic_vector(unsigned(d) + unsigned(y)));
-- pragma translate_off
  else x := (others =>'X'); return(x); 
  end if;
-- pragma translate_on
end;

-- unsigned subtraction

function "-" (a, b : std_logic_vector) return std_logic_vector is
variable x : std_logic_vector(a'length-1 downto 0);
variable y : std_logic_vector(b'length-1 downto 0);
begin
-- pragma translate_off
  if notx(a&b) then
-- pragma translate_on
    return(std_logic_vector(unsigned(a) - unsigned(b)));
-- pragma translate_off
  else
     x := (others =>'X'); y := (others =>'X');
     if (x'length > y'length) then return(x); else return(y); end if; 
  end if;
-- pragma translate_on
end;

function "-" (d : std_logic_vector; i : integer) return std_logic_vector is
variable x : std_logic_vector(d'length-1 downto 0);
begin
-- pragma translate_off
  if notx(d) then
-- pragma translate_on
    return(std_logic_vector(unsigned(d) - i));
-- pragma translate_off
  else x := (others =>'X'); return(x); 
  end if;
-- pragma translate_on
end;

function "-" (i : integer; d : std_logic_vector) return std_logic_vector is
variable x : std_logic_vector(d'length-1 downto 0);
begin
-- pragma translate_off
  if notx(d) then
-- pragma translate_on
    return(std_logic_vector(i - unsigned(d)));
-- pragma translate_off
  else x := (others =>'X'); return(x); 
  end if;
-- pragma translate_on
end;

function "-" (d : std_logic_vector; i : std_ulogic) return std_logic_vector is
variable x : std_logic_vector(d'length-1 downto 0);
variable y : std_logic_vector(0 downto 0);
begin
  y(0) := i;
-- pragma translate_off
  if notx(d) then
-- pragma translate_on
    return(std_logic_vector(unsigned(d) - unsigned(y)));
-- pragma translate_off
  else x := (others =>'X'); return(x); 
  end if;
-- pragma translate_on
end;

function ">=" (a, b : std_logic_vector) return boolean is
begin
  return(unsigned(a) >= unsigned(b));
end;

function "<" (i : integer; b : std_logic_vector) return boolean is
begin
  return( i < to_integer(unsigned(b)));
end;

function ">" (a, b : std_logic_vector) return boolean is
begin
  return(unsigned(a) > unsigned(b));
end;

function conv_integer(v : std_logic_vector) return integer is
begin
  if notx(v) then return(to_integer(unsigned(v)));
  else return(0); end if;
end;

function conv_integer(v : std_logic) return integer is
begin
  if notx(v) then
    if v = '1' then return(1);
    else return(0); end if;
  else return(0); end if;
end;

function conv_std_logic_vector(i : integer; w : integer) return std_logic_vector is
variable tmp : std_logic_vector(w-1 downto 0);
begin
  tmp := std_logic_vector(to_unsigned(i, w));
  return(tmp);
end;

function conv_std_logic_vector_signed(i : integer; w : integer) return std_logic_vector is
variable tmp : std_logic_vector(w-1 downto 0);
begin
  tmp := std_logic_vector(to_signed(i, w));
  return(tmp);
end;

function conv_std_logic(b : boolean) return std_ulogic is
begin
  if b then return('1'); else return('0'); end if;
end;

-- pragma translate_off
subtype nibble is std_logic_vector(3 downto 0);

function todec(i:integer) return character is
begin
  case i is
  when 0 => return('0');
  when 1 => return('1');
  when 2 => return('2');
  when 3 => return('3');
  when 4 => return('4');
  when 5 => return('5');
  when 6 => return('6');
  when 7 => return('7');
  when 8 => return('8');
  when 9 => return('9');
  when others => return('0');
  end case;
end;

function tohex(n:nibble) return character is
begin
  case n is
  when "0000" => return('0');
  when "0001" => return('1');
  when "0010" => return('2');
  when "0011" => return('3');
  when "0100" => return('4');
  when "0101" => return('5');
  when "0110" => return('6');
  when "0111" => return('7');
  when "1000" => return('8');
  when "1001" => return('9');
  when "1010" => return('a');
  when "1011" => return('b');
  when "1100" => return('c');
  when "1101" => return('d');
  when "1110" => return('e');
  when "1111" => return('f');
  when others => return('X');
  end case;
end;

function tost(v:std_logic_vector) return string is
constant vlen : natural := v'length; --'
constant slen : natural := (vlen+3)/4;
variable vv : std_logic_vector(0 to slen*4-1) := (others => '0');
variable s : string(1 to slen);
variable nz : boolean := false;
variable index : integer := -1;
begin
  vv(slen*4-vlen to slen*4-1) := v;
  for i in 0 to slen-1 loop
    if (vv(i*4 to i*4+3) = "0000") and nz and (i /= (slen-1)) then
      index := i;
    else
      nz := false;
      s(i+1) := tohex(vv(i*4 to i*4+3));
    end if;
  end loop;
  if ((index +2) = slen) then return(s(slen to slen));
  else return(string'("0x") & s(index+2 to slen)); end if; --'
end;

function tost(v:std_logic) return string is
begin
  if to_x01(v) = '1' then return("1"); else return("0"); end if;
end;

function tost_any(s: std_ulogic) return string is
begin
  case s is
    when '1' => return "1";
    when '0' => return "0";
    when '-' => return "-";
    when 'U' => return "U";
    when 'X' => return "X";
    when 'Z' => return "Z";
    when 'H' => return "H";
    when 'L' => return "L";
    when 'W' => return "W";
  end case;
end;

function tost_bits(s: std_logic_vector) return string is
  constant len: natural := s'length;
  variable str: string(1 to len);
  variable i: integer;
begin
  i := 1;
  for x in s'range loop      
    str(i to i) := tost_any(s(x));
    i := i+1;
  end loop;
  return str;
end;

function tost(b: boolean) return string is
begin
  if b then return "true"; else return "false"; end if;
end tost;
  
function tost(i : integer) return string is
variable L : line;
variable s, x : string(1 to 128);
variable n, tmp : integer := 0;
begin
  tmp := i;
  if i < 0 then tmp := -i; end if;
  loop
    s(128-n) := todec(tmp mod 10);
    tmp := tmp / 10;
    n := n+1;
    if tmp = 0 then exit; end if;
  end loop;
  x(1 to n) := s(129-n to 128);
  if i < 0 then return "-" & x(1 to n); end if;
  return(x(1 to n));
end;

function tost(r: real) return string is
  variable x: real;
  variable i,j: integer;
  variable s: string(1 to 30);
  variable c: character;
begin
  if r = 0.0 then
    return "0.0000";
  elsif r < 0.0 then
    return "-" & tost(-r);
  elsif r < 0.001 then
    x:=r; i:=0;
    while x<1.0 loop x:=x*10.0; i:=i+1; end loop;
    return tost(x) & "e-" & tost(i);
  elsif r >= 1000000.0 then
    x:=10000000.0; i:=6;
    while r>=x loop x:=x*10.0; i:=i+1; end loop;
    return tost(10.0*r/x) & "e+" & tost(i);
  else
    i:=0; x:=r+0.00005;
    while x >= 10.0 loop x:=x/10.0; i:=i+1; end loop;
    j := 1;
    while i > -5 loop
      if x >= 9.0 then c:='9'; x:=x-9.0;
      elsif x >= 8.0 then c:='8'; x:=x-8.0;
      elsif x >= 7.0 then c:='7'; x:=x-7.0;
      elsif x >= 6.0 then c:='6'; x:=x-6.0;
      elsif x >= 5.0 then c:='5'; x:=x-5.0;
      elsif x >= 4.0 then c:='4'; x:=x-4.0;
      elsif x >= 3.0 then c:='3'; x:=x-3.0;
      elsif x >= 2.0 then c:='2'; x:=x-2.0;
      elsif x >= 1.0 then c:='1'; x:=x-1.0;
      else c:='0';
      end if;
      s(j) := c;
      j:=j+1;
      if i=0 then s(j):='.'; j:=j+1; end if;
      i:=i-1;
      x := x * 10.0;
    end loop;
    return s(1 to j-1);
  end if;    
end tost;

procedure print(s : string) is
    variable L : line;
begin
  L := new string'(s); writeline(output, L);
end;

-- pragma translate_on
end;


