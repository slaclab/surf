-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : ArbiterPkg.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-05-01
-- Last update: 2013-11-07
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
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
use ieee.numeric_std.all;
use work.StdRtlPkg.all;
--use work.TextUtilPkg.all;

package ArbiterPkg is

   function priorityEncode (v : slv; p : integer) return slv;

   procedure arbitrate (
      req          : in    slv;
      lastSelected : in    slv;
      nextSelected : inout slv;
      valid        : inout sl;
      ack          : out   slv);

end package ArbiterPkg;

package body ArbiterPkg is

   -- Priority encoder with index p having top priority
   -- followed by p-1, p-2, etc., rolling over to the highest index when 0 reached
   -- Returns highest priority index with value '1', encoded as unsigned slv.
   function priorityEncode (v : slv; p : integer) return slv is
      variable bestReq  : integer;
      variable rotatedV : unsigned(v'range);
      variable ret      : unsigned(bitSize(v'length-1)-1 downto 0) := (others => '0');
   begin
--      print("priorityEncode(" & str(v) & ", " & str(p) & ")");
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
      ret := (ret + p) mod v'length;

      return slv(ret);
   end function priorityEncode;

   
   procedure arbitrate (
      req          : in    slv;
      lastSelected : in    slv;
      nextSelected : inout slv;
      valid        : inout sl;
      ack          : out   slv) is
   begin
--      print("arbitrate(" & str(req'length));-- & ", " & str(lastSelected'length) & ", " str(nextSelected'length) & ", " & ")");
      valid          := uOr(req);
      if (valid = '1') then
         nextSelected   := priorityEncode(req, to_integer(unsigned(lastSelected)+1) mod req'length);
         ack := decode(slv(nextSelected))(req'range);
      else
         nextSelected := lastSelected;
         ack(ack'range) := (others => '0');
      end if;
   end procedure arbitrate;
   
end package body ArbiterPkg;
