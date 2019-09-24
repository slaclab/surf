-------------------------------------------------------------------------------
-- Title      : SSI Protocol: https://confluence.slac.stanford.edu/x/0oyfD
-------------------------------------------------------------------------------
-- File       : SsiResizeFifoEofeTb.vhd
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

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.EthMacPkg.all;

entity SsiResizeFifoEofeTb is end SsiResizeFifoEofeTb;

architecture testbed of SsiResizeFifoEofeTb is

   constant TPD_G : time := 1 ns;

   constant SIZE_C : positive := 195+1;

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
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3)),
      2    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4)),
      3    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5)),
      4    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6)),
      5    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7)),
      6    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8)),
      7    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2)),
      8    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3)),
      9    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4)),
      10    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5)),
      11    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6)),
      12    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7)),
      13    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8)),
      14    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2)),
      15    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3)),
      16    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4)),
      17    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5)),
      18    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6)),
      19    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7)),
      20    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8)),
      21    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2)),
      22    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3)),
      23    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4)),
      24    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5)),
      25    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6)),
      26    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7)),
      27    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8)),
      28    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2)),
      29    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3)),
      30    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4)),
      31    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5)),
      32    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6)),
      33    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7)),
      34    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8)),
      35    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2)),
      36    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3)),
      37    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4)),
      38    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5)),
      39    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6)),
      40    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7)),
      41    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8)),
      42    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2)),
      43    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3)),
      44    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4)),
      45    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5)),
      46    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6)),
      47    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7)),
      48    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8)),
      49    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2)),
      50    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3)),
      51    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4)),
      52    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5)),
      53    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6)),
      54    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7)),
      55    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8)),
      56    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2)),
      57    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3)),
      58    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4)),
      59    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5)),
      60    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6)),
      61    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7)),
      62    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8)),
      63    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2)),
      64    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3)),
      65    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4)),
      66    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5)),
      67    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6)),
      68    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7)),
      69    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8)),
      70    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2)),
      71    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3)),
      72    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4)),
      73    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5)),
      74    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6)),
      75    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7)),
      76    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8)),
      77    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2)),
      78    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3)),
      79    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4)),
      80    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5)),
      81    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6)),
      82    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7)),
      83    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8)),
      84    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2)),
      85    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3)),
      86    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4)),
      87    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5)),
      88    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6)),
      89    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7)),
      90    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8)),
      91    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2)),
      92    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3)),
      93    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4)),
      94    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5)),
      95    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6)),
      96    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7)),
      97    => (                         
         0 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8)),
      98    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2)),
      99    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3)),
      100    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4)),
      101    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5)),
      102    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6)),
      103    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7)),
      104    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8)),
      105    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2)),
      106    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3)),
      107    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4)),
      108    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5)),
      109    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6)),
      110    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7)),
      111    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8)),
      112    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2)),
      113    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3)),
      114    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4)),
      115    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5)),
      116    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6)),
      117    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7)),
      118    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8)),
      119    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2)),
      120    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3)),
      121    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4)),
      122    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5)),
      123    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6)),
      124    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7)),
      125    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8)),
      126    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2)),
      127    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3)),
      128    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4)),
      129    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5)),
      130    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6)),
      131    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7)),
      132    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8)),
      133    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2)),
      134    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3)),
      135    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4)),
      136    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5)),
      137    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6)),
      138    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7)),
      139    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8)),
      140    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2)),
      141    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3)),
      142    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4)),
      143    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5)),
      144    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6)),
      145    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7)),
      146    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8),
         1 => ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8)),
      147    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2)),
      148    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3)),
      149    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4)),
      150    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5)),
      151    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6)),
      152    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7)),
      153    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8)),
      154    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2)),
      155    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3)),
      156    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4)),
      157    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5)),
      158    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6)),
      159    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7)),
      160    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8)),
      161    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2)),
      162    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3)),
      163    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4)),
      164    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5)),
      165    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6)),
      166    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7)),
      167    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8)),
      168    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2)),
      169    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3)),
      170    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4)),
      171    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5)),
      172    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6)),
      173    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7)),
      174    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8)),
      175    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2)),
      176    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3)),
      177    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4)),
      178    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5)),
      179    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6)),
      180    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7)),
      181    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8)),
      182    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2)),
      183    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3)),
      184    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4)),
      185    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5)),
      186    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6)),
      187    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7)),
      188    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8)),
      189    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 2)),
      190    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 3)),
      191    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 4)),
      192    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 5)),
      193    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 6)),
      194    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 7)),
      195    => (                         
         0 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8),
         1 => ssiAxiStreamConfig(64, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, 8)));

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

   U_ClkRst : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => 10 ns,
         RST_START_DELAY_G => 0 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 200 ns)   -- Hold reset for this long)
      port map (
         clkP => clk,
         rst  => rst);

   GEN_VEC :
   for i in SIZE_C-1 downto 0 generate
      U_AxiStreamFifoV2 : entity work.AxiStreamFifoV2
         generic map (
            -- General Configurations
            TPD_G               => TPD_G,
            -- FIFO configurations
            BRAM_EN_G           => false,
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

            -- Check if EOFE detected
            if (ssiGetUserEofe(AXI_STREAM_CONFIG_C(i, 1), mAxisMasters(i)) = '1') then
               -- Channel passed test
               v.passed(i) := '1';
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
