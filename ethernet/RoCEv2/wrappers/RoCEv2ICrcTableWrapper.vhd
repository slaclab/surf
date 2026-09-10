-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Test-only probe wrapper that exposes RoCEv2ICrcPkg's own
--              elaboration-time CRC_TABLES_C constant, one table at a time,
--              so a GHDL sweep can compare every one of its 9,216 values
--              against the values captured from the deleted crc_tab_N.mem
--              files. This file exists only to make that constant
--              observable from outside the package; it is deliberately not
--              loaded by ethernet/RoCEv2/ruckus.tcl and therefore never
--              reaches synthesis. It must compute nothing of its own: a
--              wrapper that reimplemented the recurrence would only be
--              comparing that recurrence against itself.
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

library surf;
use surf.StdRtlPkg.all;
use surf.RoCEv2ICrcPkg.all;

entity RoCEv2ICrcTableWrapper is
   port (
      -- Table index. Six bits so a byte-wide cocotb value can drive it
      -- directly; only 0 to INTER_BYTE_NUM_C - 1 (0 to 35) select a real
      -- table.
      tabSel : in  std_logic_vector(5 downto 0);
      -- One flattened CrcByteTableType row: 256 entries at CRC_WIDTH_C bits
      -- each, one full table flattened into a single vector.
      tabRow : out std_logic_vector(8191 downto 0));
end entity RoCEv2ICrcTableWrapper;

architecture rtl of RoCEv2ICrcTableWrapper is

begin

   -- Reads CRC_TABLES_C directly and drives it out unchanged: no lookup
   -- call, no recomputed recurrence. A six-bit selector can express 36
   -- through 63, outside CRC_TABLES_C's own 0 to INTER_BYTE_NUM_C - 1 range,
   -- so the out-of-range branch below drives all zeros instead of an
   -- out-of-range array access.
   comb : process (tabSel) is
      variable tabIndex : natural;
   begin
      tabIndex := to_integer(unsigned(tabSel));
      if tabIndex <= INTER_BYTE_NUM_C - 1 then
         for b in CrcByteTableType'range loop
            tabRow(CRC_WIDTH_C * b + CRC_WIDTH_C - 1 downto CRC_WIDTH_C * b) <= CRC_TABLES_C(tabIndex)(b);
         end loop;
      else
         tabRow <= (others => '0');
      end if;
   end process comb;

end architecture rtl;
