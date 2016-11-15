------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
------------------------------------------------------------------------------
LIBRARY ieee;
USE work.ALL;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
Library unisim;
use unisim.vcomponents.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;

entity rogue_tb is end rogue_tb;

-- Define architecture
architecture rogue_tb of rogue_tb is

   constant TPD_C     : time := 1 ns;

   signal axiClk      : sl;
   signal axiClkRst   : sl;
   signal sAxisMaster : AxiStreamMasterType;
   signal sAxisSlave  : AxiStreamSlaveType;
   signal mAxisMaster : AxiStreamMasterType;
   signal mAxisSlave  : AxiStreamSlaveType;

begin

   process begin
      axiClk <= '1';
      wait for 5 ns;
      axiClk <= '0';
      wait for 5 ns;
   end process;

   process begin
      axiClkRst <= '1';
      wait for (100 ns);
      axiClkRst <= '0';
      wait;
   end process;

   U_RogueSim: entity work.RogueStreamSimWrap
      generic map (
         TPD_G            => 1 ns,
         DEST_ID_G        => 1,
         AXIS_CONFIG_G    => AXI_STREAM_CONFIG_INIT_C)
      port map ( 
         axisClk     => axiClk,
         axisClkRst  => axiClkRst,
         sAxisMaster => sAxisMaster,
         sAxisSlave  => sAxisSlave,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);

   sAxisMaster <= mAxisMaster;
   mAxisSlave  <= sAxisSlave;

end rogue_tb;

