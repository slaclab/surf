-------------------------------------------------------------------------------
-- File       : EthMacTxShift.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-09-08
-- Last update: 2016-09-14
-------------------------------------------------------------------------------
-- Description: Ethernet MAC's TX byte Shifting Module
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

use work.AxiStreamPkg.all;
use work.StdRtlPkg.all;
use work.EthMacPkg.all;

entity EthMacTxShift is
   generic (
      TPD_G      : time    := 1 ns;
      SHIFT_EN_G : boolean := false);
   port (
      -- Clock and Reset
      ethClk      : in  sl;
      ethRst      : in  sl;
      -- AXIS Interface
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;
      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType;
      -- Configuration
      txShift     : in  slv(3 downto 0));
end EthMacTxShift;

architecture mapping of EthMacTxShift is

begin

   U_TxShiftEnGen : if (SHIFT_EN_G = true) generate
      -- Shift outbound data n bytes to the right.
      -- This removes bytes of data at start 
      -- of the packet. These were added by software
      -- to create a software friendly alignment of 
      -- outbound data.
      U_TxShift : entity work.AxiStreamShift
         generic map (
            TPD_G         => TPD_G,
            AXIS_CONFIG_G => EMAC_AXIS_CONFIG_C) 
         port map (
            axisClk     => ethClk,
            axisRst     => ethRst,
            axiStart    => '1',
            axiShiftDir => '1',         -- 1 = right (msb to lsb)
            axiShiftCnt => txShift,
            sAxisMaster => sAxisMaster,
            sAxisSlave  => sAxisSlave,
            mAxisMaster => mAxisMaster,
            mAxisSlave  => mAxisSlave);
   end generate;

   U_TxShiftDisGen : if (SHIFT_EN_G = false) generate
      mAxisMaster <= sAxisMaster;
      sAxisSlave  <= mAxisSlave;
   end generate;

end mapping;
