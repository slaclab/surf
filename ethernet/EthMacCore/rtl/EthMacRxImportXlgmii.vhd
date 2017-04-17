-------------------------------------------------------------------------------
-- File       : EthMacRxImportXlgmii.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-09-13
-- Last update: 2016-09-14
-------------------------------------------------------------------------------
-- Description: 40GbE Import MAC core with XLGMII interface
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

entity EthMacRxImportXlgmii is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Clock and Reset
      ethClk      : in  sl;
      ethRst      : in  sl;
      -- AXIS Interface   
      macIbMaster : out AxiStreamMasterType;
      -- XLGMII PHY Interface
      phyRxd      : in  slv(127 downto 0);
      phyRxc      : in  slv(15 downto 0);
      -- Configuration and status
      phyReady    : in  sl;
      rxCountEn   : out sl;
      rxCrcError  : out sl);
end EthMacRxImportXlgmii;

architecture rtl of EthMacRxImportXlgmii is

begin
   -- Place holder for future code
   macIbMaster <= AXI_STREAM_MASTER_INIT_C;
   rxCountEn   <= '0';
   rxCrcError  <= '0';
end rtl;
