-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : ArbiterPkg.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-05-01
-- Last update: 2013-05-01
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2013 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--use ieee.std_logic_unsigned.all;
use work.StdRtlPkg.all;

package ArbiterPkg is

   function priorityEncode (v : slv; p : integer) return unsigned;

   procedure arbitrate (
      req          : in    slv;
      lastSelected : in    unsigned;
      nextSelected : inout unsigned;
      valid        : inout sl;
      ack          : out   slv);

end package ArbiterPkg;

package body ArbiterPkg is

   
   function priorityEncode (v : slv; p : integer) return unsigned is
      variable bestReq  : integer;
      variable rotatedV : unsigned(v'range);
      variable ret      : unsigned(bitSize(v'length)-1 downto 0) := (others => '0');
   begin
      -- Rotate input by n to give n top priority
      rotatedV := rotate_right(unsigned(v), p);

      -- Find lowest index with value of '1'
      bestReq := 0;
      for i in v'range loop
         if (rotatedV(i) = '1') then
            bestReq := i;
         end if;
      end loop;

      -- Convert integer to unsigned
      ret := to_unsigned(bestReq, ret'length);

      -- Add p to encoded value to undo the rotation
      ret := ret + p;

      return ret;
   end function priorityEncode;

   procedure arbitrate (
      req          : in    slv;
      lastSelected : in    unsigned;
      nextSelected : inout unsigned;
      valid        : inout sl;
      ack          : out   slv) is
   begin
      nextSelected := priorityEncode(req, to_integer(unsigned(lastSelected)+1));
      valid        := uOr(req);
      ack          := (others => '0');
      if (valid = '1') then
         ack := decode(slv(nextSelected));
      end if;
   end procedure arbitrate;

end package body ArbiterPkg;
