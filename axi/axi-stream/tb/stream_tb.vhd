-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for STREAM module
-------------------------------------------------------------------------------
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

entity stream_tb is end stream_tb;

architecture stream_tb of stream_tb is

   signal axiClk    : sl;
   signal axiClkRst : sl;
   signal axiMaster : AxiStreamMasterType;
   signal axiSlave  : AxiStreamSlaveType;

   constant AXIS_CONFIG_C : AxiStreamConfigTYpe := ssiAxiStreamConfig (4);

begin

   -- Generate clocks and resets
   ClkRst_Inst : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => 10 ns,
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 1000 ns)
      port map (
         clkP => axiClk,
         clkN => open,
         rst  => axiClkRst,
         rstL => open);

   -- Loopback the AXI stream from software
   U_AxiStreamSim : entity surf.RogueTcpStreamWrap
      generic map (
         TPD_G         => 1 ns,
         PORT_NUM_G    => 9000,         -- Using ports 9000 and 9001
         SSI_EN_G      => true,
         CHAN_COUNT_G  => 1,
         AXIS_CONFIG_G => AXIS_CONFIG_C)
      port map (
         axisClk     => axiClk,
         axisRst     => axiClkRst,
         sAxisMaster => axiMaster,
         sAxisSlave  => axiSlave,
         mAxisMaster => axiMaster,
         mAxisSlave  => axiSlave);

end stream_tb;
