-------------------------------------------------------------------------------
-- File       : EthMacTxExport.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-09-08
-- Last update: 2016-10-06
-------------------------------------------------------------------------------
-- Description: Mapping for 1GbE/10GbE/40GbE ETH MAC TX path
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

entity EthMacTxExport is
   generic (
      TPD_G      : time   := 1 ns;
      PHY_TYPE_G : string := "XGMII");
   port (
      -- Clock and Reset
      ethClk         : in  sl;
      ethRst         : in  sl;
      -- AXIS Interface   
      macObMaster    : in  AxiStreamMasterType;
      macObSlave     : out AxiStreamSlaveType;
      -- XLGMII PHY Interface
      xlgmiiTxd      : out slv(127 downto 0);
      xlgmiiTxc      : out slv(15 downto 0);
      -- XGMII PHY Interface
      xgmiiTxd       : out slv(63 downto 0);
      xgmiiTxc       : out slv(7 downto 0);
      -- GMII PHY Interface
      gmiiTxEn       : out sl;
      gmiiTxEr       : out sl;
      gmiiTxd        : out slv(7 downto 0);
      -- Configuration and status
      macAddress     : in  slv(47 downto 0);
      phyReady       : in  sl;
      txCountEn      : out sl;
      txUnderRun     : out sl;
      txLinkNotReady : out sl);
end EthMacTxExport;

architecture mapping of EthMacTxExport is

begin

   assert ((PHY_TYPE_G = "XLGMII") or (PHY_TYPE_G = "XGMII") or (PHY_TYPE_G = "GMII")) report "EthMacTxExport: PHY_TYPE_G must be either GMII, XGMII, XLGMII" severity failure;

   U_40G : if (PHY_TYPE_G = "XLGMII") generate
      U_XLGMII : entity work.EthMacTxImportXlgmii
         generic map (
            TPD_G => TPD_G) 
         port map (
            -- Clock and Reset
            ethClk         => ethClk,
            ethRst         => ethRst,
            -- AXIS Interface 
            macObMaster    => macObMaster,
            macObSlave     => macObSlave,
            -- XLGMII PHY Interface
            phyTxd         => xlgmiiTxd,
            phyTxc         => xlgmiiTxc,
            -- Configuration and status
            phyReady       => phyReady,
            macAddress     => macAddress,
            txCountEn      => txCountEn,
            txUnderRun     => txUnderRun,
            txLinkNotReady => txLinkNotReady);
      -- Unused output ports
      xgmiiTxd <= (others => '0');
      xgmiiTxc <= (others => '0');
      gmiiTxEn <= '0';
      gmiiTxEr <= '0';
      gmiiTxd  <= (others => '0');
   end generate;

   U_10G : if (PHY_TYPE_G = "XGMII") generate
      U_XGMII : entity work.EthMacTxExportXgmii
         generic map (
            TPD_G => TPD_G) 
         port map (
            -- Clock and Reset
            ethClk         => ethClk,
            ethRst         => ethRst,
            -- AXIS Interface 
            macObMaster    => macObMaster,
            macObSlave     => macObSlave,
            -- XGMII PHY Interface
            phyTxd         => xgmiiTxd,
            phyTxc         => xgmiiTxc,
            -- Configuration and status
            phyReady       => phyReady,
            macAddress     => macAddress,
            txCountEn      => txCountEn,
            txUnderRun     => txUnderRun,
            txLinkNotReady => txLinkNotReady);
      -- Unused output ports
      xlgmiiTxd <= (others => '0');
      xlgmiiTxc <= (others => '0');
      gmiiTxEn  <= '0';
      gmiiTxEr  <= '0';
      gmiiTxd   <= (others => '0');
   end generate;

   U_1G : if (PHY_TYPE_G = "GMII") generate
      U_GMII : entity work.EthMacTxExportGmii
         generic map (
            TPD_G => TPD_G) 
         port map (
            -- Clock and Reset         
            ethClk         => ethClk,
            ethRst         => ethRst,
            -- AXIS Interface 
            macObMaster    => macObMaster,
            macObSlave     => macObSlave,
            -- GMII PHY Interface
            gmiiTxEn       => gmiiTxEn,
            gmiiTxEr       => gmiiTxEr,
            gmiiTxd        => gmiiTxd,
            -- Configuration and status
            phyReady       => phyReady,
            macAddress     => macAddress,
            txCountEn      => txCountEn,
            txUnderRun     => txUnderRun,
            txLinkNotReady => txLinkNotReady);
      -- Unused output ports
      xlgmiiTxd <= (others => '0');
      xlgmiiTxc <= (others => '0');
      xgmiiTxd  <= (others => '0');
      xgmiiTxc  <= (others => '0');
   end generate;

end mapping;
