-------------------------------------------------------------------------------
-- Title      : SSI Protocol: https://confluence.slac.stanford.edu/x/0oyfD
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the AxiStreamFifo + EOFE module
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;
use surf.EthMacPkg.all;

entity SsiResizeFifoEofeTb is end SsiResizeFifoEofeTb;

architecture testbed of SsiResizeFifoEofeTb is

   constant TPD_G : time := 1 ns;

   constant SIZE_C : positive := 159+1;

   -------------------------------------------------------------------------------
   --   function ssiAxiStreamConfig (
   --      dataBytes : positive;
   --      tKeepMode : TKeepModeType         := TKEEP_COMP_C;
   --      tUserMode : TUserModeType         := TUSER_FIRST_LAST_C;
   --      tDestBits : natural range 0 to 8  := 4;
   --      tUserBits : positive range 2 to 8 := 2)
   -------------------------------------------------------------------------------
   constant AXI_STREAM_CONFIG_C : AxiStreamConfigVectorArray(0 to SIZE_C-1, 0 to 1) := (
      0    => (
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2)),
      1    => (
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8)),
      2    => (
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2)),
      3    => (
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8)),
      4    => (
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2)),
      5    => (
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8)),
      6    => (
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2)),
      7    => (
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8)),
      8    => (
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2)),
      9    => (
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8)),
      10    => (
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2)),
      11    => (
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8)),
      12    => (
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2)),
      13    => (
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8)),
      14    => (
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2)),
      15    => (
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8)),
      16    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NORMAL_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NORMAL_C, 4, 4)),
      17    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NORMAL_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_FIRST_LAST_C, 4, 4)),
      18    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NORMAL_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_LAST_C, 4, 4)),
      19    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NORMAL_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NONE_C, 4, 4)),
      20    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NORMAL_C, 4, 4)),
      21    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_FIRST_LAST_C, 4, 4)),
      22    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_LAST_C, 4, 4)),
      23    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NONE_C, 4, 4)),
      24    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NORMAL_C, 4, 4)),
      25    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_FIRST_LAST_C, 4, 4)),
      26    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_LAST_C, 4, 4)),
      27    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NONE_C, 4, 4)),
      28    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NONE_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NORMAL_C, 4, 4)),
      29    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NONE_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_FIRST_LAST_C, 4, 4)),
      30    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NONE_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_LAST_C, 4, 4)),
      31    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NONE_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NONE_C, 4, 4)),
      32    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NORMAL_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NORMAL_C, 4, 4)),
      33    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NORMAL_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4)),
      34    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NORMAL_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_LAST_C, 4, 4)),
      35    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NORMAL_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NONE_C, 4, 4)),
      36    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NORMAL_C, 4, 4)),
      37    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4)),
      38    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_LAST_C, 4, 4)),
      39    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NONE_C, 4, 4)),
      40    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NORMAL_C, 4, 4)),
      41    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4)),
      42    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_LAST_C, 4, 4)),
      43    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NONE_C, 4, 4)),
      44    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NONE_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NORMAL_C, 4, 4)),
      45    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NONE_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4)),
      46    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NONE_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_LAST_C, 4, 4)),
      47    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NONE_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NONE_C, 4, 4)),
      48    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NORMAL_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NORMAL_C, 4, 4)),
      49    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NORMAL_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_FIRST_LAST_C, 4, 4)),
      50    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NORMAL_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_LAST_C, 4, 4)),
      51    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NORMAL_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NONE_C, 4, 4)),
      52    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NORMAL_C, 4, 4)),
      53    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_FIRST_LAST_C, 4, 4)),
      54    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_LAST_C, 4, 4)),
      55    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NONE_C, 4, 4)),
      56    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NORMAL_C, 4, 4)),
      57    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_FIRST_LAST_C, 4, 4)),
      58    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_LAST_C, 4, 4)),
      59    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NONE_C, 4, 4)),
      60    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NONE_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NORMAL_C, 4, 4)),
      61    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NONE_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_FIRST_LAST_C, 4, 4)),
      62    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NONE_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_LAST_C, 4, 4)),
      63    => (
         0 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NONE_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NONE_C, 4, 4)),
      64    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NORMAL_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NORMAL_C, 4, 4)),
      65    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NORMAL_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_FIRST_LAST_C, 4, 4)),
      66    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NORMAL_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_LAST_C, 4, 4)),
      67    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NORMAL_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NONE_C, 4, 4)),
      68    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NORMAL_C, 4, 4)),
      69    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_FIRST_LAST_C, 4, 4)),
      70    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_LAST_C, 4, 4)),
      71    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NONE_C, 4, 4)),
      72    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NORMAL_C, 4, 4)),
      73    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_FIRST_LAST_C, 4, 4)),
      74    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_LAST_C, 4, 4)),
      75    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NONE_C, 4, 4)),
      76    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NONE_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NORMAL_C, 4, 4)),
      77    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NONE_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_FIRST_LAST_C, 4, 4)),
      78    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NONE_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_LAST_C, 4, 4)),
      79    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NONE_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NONE_C, 4, 4)),
      80    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NORMAL_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NORMAL_C, 4, 4)),
      81    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NORMAL_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4)),
      82    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NORMAL_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_LAST_C, 4, 4)),
      83    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NORMAL_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NONE_C, 4, 4)),
      84    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NORMAL_C, 4, 4)),
      85    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4)),
      86    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_LAST_C, 4, 4)),
      87    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NONE_C, 4, 4)),
      88    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NORMAL_C, 4, 4)),
      89    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4)),
      90    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_LAST_C, 4, 4)),
      91    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NONE_C, 4, 4)),
      92    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NONE_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NORMAL_C, 4, 4)),
      93    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NONE_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4)),
      94    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NONE_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_LAST_C, 4, 4)),
      95    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NONE_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NONE_C, 4, 4)),
      96    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NORMAL_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NORMAL_C, 4, 4)),
      97    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NORMAL_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_FIRST_LAST_C, 4, 4)),
      98    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NORMAL_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_LAST_C, 4, 4)),
      99    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NORMAL_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NONE_C, 4, 4)),
      100    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NORMAL_C, 4, 4)),
      101    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_FIRST_LAST_C, 4, 4)),
      102    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_LAST_C, 4, 4)),
      103    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NONE_C, 4, 4)),
      104    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NORMAL_C, 4, 4)),
      105    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_FIRST_LAST_C, 4, 4)),
      106    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_LAST_C, 4, 4)),
      107    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NONE_C, 4, 4)),
      108    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NONE_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NORMAL_C, 4, 4)),
      109    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NONE_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_FIRST_LAST_C, 4, 4)),
      110    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NONE_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_LAST_C, 4, 4)),
      111    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NONE_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NONE_C, 4, 4)),
      112    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NORMAL_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NORMAL_C, 4, 4)),
      113    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NORMAL_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_FIRST_LAST_C, 4, 4)),
      114    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NORMAL_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_LAST_C, 4, 4)),
      115    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NORMAL_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NONE_C, 4, 4)),
      116    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NORMAL_C, 4, 4)),
      117    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_FIRST_LAST_C, 4, 4)),
      118    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_LAST_C, 4, 4)),
      119    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NONE_C, 4, 4)),
      120    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NORMAL_C, 4, 4)),
      121    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_FIRST_LAST_C, 4, 4)),
      122    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_LAST_C, 4, 4)),
      123    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NONE_C, 4, 4)),
      124    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NONE_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NORMAL_C, 4, 4)),
      125    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NONE_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_FIRST_LAST_C, 4, 4)),
      126    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NONE_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_LAST_C, 4, 4)),
      127    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NONE_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_NORMAL_C, TUSER_NONE_C, 4, 4)),
      128    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NORMAL_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NORMAL_C, 4, 4)),
      129    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NORMAL_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4)),
      130    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NORMAL_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_LAST_C, 4, 4)),
      131    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NORMAL_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NONE_C, 4, 4)),
      132    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NORMAL_C, 4, 4)),
      133    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4)),
      134    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_LAST_C, 4, 4)),
      135    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NONE_C, 4, 4)),
      136    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NORMAL_C, 4, 4)),
      137    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4)),
      138    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_LAST_C, 4, 4)),
      139    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NONE_C, 4, 4)),
      140    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NONE_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NORMAL_C, 4, 4)),
      141    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NONE_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4)),
      142    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NONE_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_LAST_C, 4, 4)),
      143    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NONE_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_NONE_C, 4, 4)),
      144    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NORMAL_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NORMAL_C, 4, 4)),
      145    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NORMAL_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_FIRST_LAST_C, 4, 4)),
      146    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NORMAL_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_LAST_C, 4, 4)),
      147    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NORMAL_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NONE_C, 4, 4)),
      148    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NORMAL_C, 4, 4)),
      149    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_FIRST_LAST_C, 4, 4)),
      150    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_LAST_C, 4, 4)),
      151    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NONE_C, 4, 4)),
      152    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NORMAL_C, 4, 4)),
      153    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_FIRST_LAST_C, 4, 4)),
      154    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_LAST_C, 4, 4)),
      155    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NONE_C, 4, 4)),
      156    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NONE_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NORMAL_C, 4, 4)),
      157    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NONE_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_FIRST_LAST_C, 4, 4)),
      158    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NONE_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_LAST_C, 4, 4)),
      159    => (
         0 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NONE_C, 4, 4),
         1 => ssiAxiStreamConfig(8, TKEEP_COUNT_C, TUSER_NONE_C, 4, 4)));

   type RegType is record
      passDly      : sl;
      failDly      : sl;
      passed       : slv(SIZE_C-1 downto 0);
      failed       : slv(SIZE_C-1 downto 0);
      sAxisMasters : AxiStreamMasterArray(SIZE_C-1 downto 0);
   end record RegType;
   constant REG_INIT_C : RegType := (
      passDly      => '0',
      failDly      => '0',
      passed       => (others => '0'),
      failed       => (others => '0'),
      sAxisMasters => (others => AXI_STREAM_MASTER_INIT_C));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal clk : sl := '0';
   signal rst : sl := '1';

   signal sAxisMasters : AxiStreamMasterArray(SIZE_C-1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal sAxisSlaves  : AxiStreamSlaveArray(SIZE_C-1 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);
   signal mAxisMasters : AxiStreamMasterArray(SIZE_C-1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);

   signal passed : sl := '0';
   signal failed : sl := '0';

begin

   U_ClkRst : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => 10 ns,
         RST_START_DELAY_G => 0 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 200 ns)   -- Hold reset for this long)
      port map (
         clkP => clk,
         rst  => rst);

   GEN_VEC :
   for i in SIZE_C-1 downto 0 generate
      U_AxiStreamFifoV2 : entity surf.AxiStreamFifoV2
         generic map (
            -- General Configurations
            TPD_G               => TPD_G,
            -- FIFO configurations
            MEMORY_TYPE_G       => "distributed",
            GEN_SYNC_FIFO_G     => true,
            FIFO_ADDR_WIDTH_G   => 4,
            -- AXI Stream Port Configurations
            SLAVE_AXI_CONFIG_G  => AXI_STREAM_CONFIG_C(i, 0),
            MASTER_AXI_CONFIG_G => AXI_STREAM_CONFIG_C(i, 1))
         port map (
            -- Slave Port
            sAxisClk    => clk,
            sAxisRst    => rst,
            sAxisMaster => sAxisMasters(i),
            sAxisSlave  => sAxisSlaves(i),
            -- Master Port
            mAxisClk    => clk,
            mAxisRst    => rst,
            mAxisMaster => mAxisMasters(i),
            mAxisSlave  => AXI_STREAM_SLAVE_FORCE_C);
   end generate GEN_VEC;

   comb : process (mAxisMasters, r, rst, sAxisSlaves) is
      variable v : RegType;
      variable eofe : sl;
   begin
      -- Latch the current value
      v := r;

      -- Loop through the channel
      for i in SIZE_C-1 downto 0 loop

         -- AXIS Stream flow control
         if sAxisSlaves(i).tReady = '1' then
            v.sAxisMasters(i).tValid := '0';
         end if;

         -- Check if EOFE not sent yet and ready to send packet
         if (v.sAxisMasters(i).tValid = '0') and (r.sAxisMasters(i).tLast = '0') then
            -- Send an EOFE packet
            v.sAxisMasters(i).tValid := '1';
            v.sAxisMasters(i).tLast  := '1';
            ssiSetUserEofe(AXI_STREAM_CONFIG_C(i, 0), v.sAxisMasters(i), '1');
         end if;

         -- Check if received EOF
         if (mAxisMasters(i).tValid = '1') and (mAxisMasters(i).tLast = '1') then

            -- Get the EOFE
            eofe := ssiGetUserEofe(AXI_STREAM_CONFIG_C(i, 1), mAxisMasters(i));

            -- Check if EOFE detected and both AXIS config TUserModeType /= TUSER_NONE_C
            if (eofe = '1') and
            (AXI_STREAM_CONFIG_C(i, 1).TUSER_MODE_C /= TUSER_NONE_C) and
            (AXI_STREAM_CONFIG_C(i, 0).TUSER_MODE_C /= TUSER_NONE_C)  then
               -- Channel passed test
               v.passed(i) := '1';

            -- Check if EOFE not detected and either AXIS config has TUserModeType = TUSER_NONE_C
            elsif (eofe = '0') and (
            (AXI_STREAM_CONFIG_C(i, 1).TUSER_MODE_C = TUSER_NONE_C) or
            (AXI_STREAM_CONFIG_C(i, 0).TUSER_MODE_C = TUSER_NONE_C))  then
               -- Channel passed test
               v.passed(i) := '1';

            -- Failed conditions
            else
               -- Channel failed test
               v.failed(i) := '1';
            end if;

         end if;

      end loop;

      -- Update the results
      v.passDly := uAnd(r.passed);      -- Check that all channels passed
      v.failDly := uOr(r.failed);       -- Check if any channel failed

      -- Outputs
      sAxisMasters <= r.sAxisMasters;
      passed       <= r.passDly;
      failed       <= r.failDly;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   process(failed, passed)
   begin
      if passed = '1' then
         assert false
            report "Simulation Passed!" severity failure;
      elsif failed = '1' then
         assert false
            report "Simulation Failed!" severity failure;
      end if;
   end process;

end testbed;
