-------------------------------------------------------------------------------
-- File       : EthMacTxImportXlgmii.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-09-13
-- Last update: 2016-09-14
-------------------------------------------------------------------------------
-- Description: 40GbE Export MAC core with XLGMII interface
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

entity EthMacTxImportXlgmii is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Clock and Reset
      ethClk         : in  sl;
      ethRst         : in  sl;
      -- AXIS Interface   
      macObMaster    : in  AxiStreamMasterType;
      macObSlave     : out AxiStreamSlaveType;
      -- XLGMII PHY Interface
      phyTxd         : out slv(127 downto 0);
      phyTxc         : out slv(15 downto 0);
      phyReady       : in  sl;
      -- Configuration
      macAddress     : in  slv(47 downto 0);
      -- Errors
      txCountEn      : out sl;
      txUnderRun     : out sl;
      txLinkNotReady : out sl);
end EthMacTxImportXlgmii;

architecture rtl of EthMacTxImportXlgmii is

begin
   -- Place holder for future code
   macObSlave     <= AXI_STREAM_SLAVE_FORCE_C;
   phyTxd         <= (others => '0');
   phyTxc         <= (others => '0');
   txCountEn      <= '0';
   txUnderRun     <= '0';
   txLinkNotReady <= '0';
end rtl;
