-------------------------------------------------------------------------------
-- File       : SsiCmdMasterPkg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-25
-- Last update: 2014-04-30
-------------------------------------------------------------------------------
-- Description: SSI Command Master Pulser Module Package File
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

package SsiCmdMasterPkg is

   type SsiCmdMasterType is record
      valid   : sl;                     -- Command Opcode is valid (formerly cmdEn)
      opCode  : slv(7 downto 0);        -- Command OpCode
      context : slv(23 downto 0);       -- Command Context
   end record;

   type SsiCmdMasterArray is array (natural range <>) of SsiCmdMasterType;

   constant SSI_CMD_MASTER_INIT_C : SsiCmdMasterType := (
      valid   => '0',
      opCode  => (others => '0'),
      context => (others => '0'));

end SsiCmdMasterPkg;
