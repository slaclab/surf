-------------------------------------------------------------------------------
-- Title      : 1GbE/10GbE Ethernet MAC
-------------------------------------------------------------------------------
-- File       : EthMacTxExport.vhd
-- Author     : Larry Ruckman <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-09-08
-- Last update: 2016-09-09
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Ethernet Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Ethernet Library', including this file, 
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
      TPD_G     : time    := 1 ns;
      GMII_EN_G : boolean := false);    -- False = XGMII Interface only, True = GMII Interface only
   port (
      -- Clock and Reset
      ethClk         : in  sl;
      ethRst         : in  sl;
      -- AXIS Interface   
      macObMaster    : in  AxiStreamMasterType;
      macObSlave     : out AxiStreamSlaveType;
      -- XGMII PHY Interface
      phyTxd         : out slv(63 downto 0);
      phyTxc         : out slv(7 downto 0);
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

   U_10G_EXPORT : if (GMII_EN_G = false) generate
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
            phyTxd         => phyTxd,
            phyTxc         => phyTxc,
            -- Configuration and status
            phyReady       => phyReady,
            interFrameGap  => x"3",
            macAddress     => macAddress,
            txCountEn      => txCountEn,
            txUnderRun     => txUnderRun,
            txLinkNotReady => txLinkNotReady);
      -- Unused output ports
      gmiiTxEn <= '0';
      gmiiTxEr <= '0';
      gmiiTxd  <= (others => '0');
   end generate;

   U_1G_EXPORT : if (GMII_EN_G = true) generate
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
      phyTxd <= (others => '0');
      phyTxc <= (others => '0');
   end generate;

end mapping;
