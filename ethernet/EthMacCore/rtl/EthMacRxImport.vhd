-------------------------------------------------------------------------------
-- File       : EthMacRxImport.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-09-09
-- Last update: 2016-09-14
-------------------------------------------------------------------------------
-- Description: Mapping for 1GbE/10GbE/40GbE ETH MAC RX path
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

entity EthMacRxImport is
   generic (
      TPD_G      : time   := 1 ns;
      PHY_TYPE_G : string := "XGMII");
   port (
      -- Clock and Reset
      ethClk      : in  sl;
      ethRst      : in  sl;
      -- AXIS Interface   
      macIbMaster : out AxiStreamMasterType;
      -- XLGMII PHY Interface
      xlgmiiRxd   : in  slv(127 downto 0);
      xlgmiiRxc   : in  slv(15 downto 0);
      -- XGMII PHY Interface
      xgmiiRxd    : in  slv(63 downto 0);
      xgmiiRxc    : in  slv(7 downto 0);
      -- GMII PHY Interface
      gmiiRxDv    : in  sl;
      gmiiRxEr    : in  sl;
      gmiiRxd     : in  slv(7 downto 0);
      -- Configuration and status
      phyReady    : in  sl;
      rxCountEn   : out sl;
      rxCrcError  : out sl);
end EthMacRxImport;

architecture mapping of EthMacRxImport is

begin

   assert ((PHY_TYPE_G = "XLGMII") or (PHY_TYPE_G = "XGMII") or (PHY_TYPE_G = "GMII")) report "EthMacRxImport: PHY_TYPE_G must be either GMII, XGMII, XLGMII" severity failure;

   U_40G : if (PHY_TYPE_G = "XLGMII") generate
      U_XLGMII : entity work.EthMacRxImportXlgmii
         generic map (
            TPD_G => TPD_G) 
         port map (
            -- Clock and Reset
            ethClk      => ethClk,
            ethRst      => ethRst,
            -- AXIS Interface 
            macIbMaster => macIbMaster,
            -- XLGMII PHY Interface
            phyRxd      => xlgmiiRxd,
            phyRxc      => xlgmiiRxc,
            -- Configuration and status
            phyReady    => phyReady,
            rxCountEn   => rxCountEn,
            rxCrcError  => rxCrcError);
   end generate;

   U_10G : if (PHY_TYPE_G = "XGMII") generate
      U_XGMII : entity work.EthMacRxImportXgmii
         generic map (
            TPD_G => TPD_G) 
         port map (
            -- Clock and Reset
            ethClk      => ethClk,
            ethRst      => ethRst,
            -- AXIS Interface 
            macIbMaster => macIbMaster,
            -- XGMII PHY Interface
            phyRxd      => xgmiiRxd,
            phyRxc      => xgmiiRxc,
            -- Configuration and status
            phyReady    => phyReady,
            rxCountEn   => rxCountEn,
            rxCrcError  => rxCrcError);
   end generate;

   U_1G : if (PHY_TYPE_G = "GMII") generate
      U_GMII : entity work.EthMacRxImportGmii
         generic map (
            TPD_G => TPD_G) 
         port map (
            -- Clock and Reset         
            ethClk      => ethClk,
            ethRst      => ethRst,
            -- AXIS Interface 
            macIbMaster => macIbMaster,
            -- GMII PHY Interface
            gmiiRxDv    => gmiiRxDv,
            gmiiRxEr    => gmiiRxEr,
            gmiiRxd     => gmiiRxd,
            -- Configuration and status
            phyReady    => phyReady,
            rxCountEn   => rxCountEn,
            rxCrcError  => rxCrcError);
   end generate;

end mapping;
