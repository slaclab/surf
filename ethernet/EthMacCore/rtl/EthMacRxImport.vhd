-------------------------------------------------------------------------------
-- Title      : 1GbE/10GbE Ethernet MAC
-------------------------------------------------------------------------------
-- File       : EthMacRxImport.vhd
-- Author     : Ryan Herbst <rherbst@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-09-09
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
use work.EthMacPkg.all;

entity EthMacRxImport is
   generic (
      TPD_G     : time    := 1 ns;
      GMII_EN_G : boolean := false);
   port (
      -- Clock and Reset
      ethClk      : in  sl;
      ethRst      : in  sl;
      -- AXIS Interface   
      macIbMaster : out AxiStreamMasterType;
      -- XGMII PHY Interface
      phyRxd      : in  slv(63 downto 0);
      phyRxc      : in  slv(7 downto 0);
      -- GMII PHY Interface
      gmiiRxDv    : in  sl              := '0';
      gmiiRxEr    : in  sl              := '0';
      gmiiRxd     : in  slv(7 downto 0) := x"00";
      -- Configuration and status
      phyReady    : in  sl;
      rxCountEn   : out sl;
      rxCrcError  : out sl);
end EthMacRxImport;

architecture mapping of EthMacRxImport is

begin

   U_10G_IMPORT : if (GMII_EN_G = false) generate
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
            phyRxd      => phyRxd,
            phyRxc      => phyRxc,
            -- Configuration and status
            phyReady    => phyReady,
            rxCountEn   => rxCountEn,
            rxCrcError  => rxCrcError);
   end generate;

   U_1G_IMPORT : if (GMII_EN_G = true) generate
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
