-------------------------------------------------------------------------------
-- File       : EthMacRxShift.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-09-08
-- Last update: 2016-09-14
-------------------------------------------------------------------------------
-- Description: Ethernet MAC's RX byte Shifting Module
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

entity EthMacRxShift is
   generic (
      TPD_G      : time    := 1 ns;
      SHIFT_EN_G : boolean := false);
   port (
      -- Clock and Reset
      ethClk      : in  sl;
      ethRst      : in  sl;
      -- AXIS Interface
      sAxisMaster : in  AxiStreamMasterType;
      mAxisMaster : out AxiStreamMasterType;
      -- Configuration
      rxShift     : in  slv(3 downto 0));
end EthMacRxShift;

architecture mapping of EthMacRxShift is

begin

   U_RxShiftEnGen : if (SHIFT_EN_G = true) generate
      -- Shift inbound data n bytes to the left.
      -- This adds bytes of data at start of the packet. 
      U_RxShift : entity work.AxiStreamShift
         generic map (
            TPD_G          => TPD_G,
            AXIS_CONFIG_G  => EMAC_AXIS_CONFIG_C,
            ADD_VALID_EN_G => true) 
         port map (
            axisClk     => ethClk,
            axisRst     => ethRst,
            axiStart    => '1',
            axiShiftDir => '0',         -- 0 = left (lsb to msb)
            axiShiftCnt => rxShift,
            sAxisMaster => sAxisMaster,
            sAxisSlave  => open,
            mAxisMaster => mAxisMaster,
            mAxisSlave  => AXI_STREAM_SLAVE_FORCE_C);
   end generate;

   U_RxShiftDisGen : if (SHIFT_EN_G = false) generate
      mAxisMaster <= sAxisMaster;
   end generate;

end mapping;
