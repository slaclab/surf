-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : RawEthFramer.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-05-23
-- Last update: 2016-05-24
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

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;

entity RawEthFramer is
   generic (
      TPD_G         : time             := 1 ns;
      REMOTE_SIZE_G : positive         := 1;
      ETH_TYPE_G    : slv(15 downto 0) := x"0010");  --  0x1000 (big-Endian configuration)
   port (
      -- Local Configurations
      localMac     : in  slv(47 downto 0);           --  big-Endian configuration
      remoteMac    : in  Slv48Array(REMOTE_SIZE_G-1 downto 0);  --  big-Endian configuration
      -- Interface to Ethernet Media Access Controller (MAC)
      obMacMaster  : in  AxiStreamMasterType;
      obMacSlave   : out AxiStreamSlaveType;
      ibMacMaster  : out AxiStreamMasterType;
      ibMacSlave   : in  AxiStreamSlaveType;
      -- Interface to Application engine(s)
      ibAppMasters : out AxiStreamMasterArray(REMOTE_SIZE_G-1 downto 0);
      ibAppSlaves  : in  AxiStreamSlaveArray(REMOTE_SIZE_G-1 downto 0);
      obAppMasters : in  AxiStreamMasterArray(REMOTE_SIZE_G-1 downto 0);
      obAppSlaves  : out AxiStreamSlaveArray(REMOTE_SIZE_G-1 downto 0);
      -- Clock and Reset
      clk          : in  sl;
      rst          : in  sl);
end RawEthFramer;

architecture mapping of RawEthFramer is

   signal ibAppMaster : AxiStreamMasterType;
   signal ibAppSlave  : AxiStreamSlaveType;
   signal obAppMaster : AxiStreamMasterType;
   signal obAppSlave  : AxiStreamSlaveType;

begin

   U_Mux : entity work.AxiStreamMux
      generic map (
         TPD_G        => TPD_G,
         NUM_SLAVES_G => REMOTE_SIZE_G)
      port map (
         -- Clock and reset
         axisClk      => clk,
         axisRst      => rst,
         -- Slaves
         sAxisMasters => obAppMasters,
         sAxisSlaves  => obAppSlaves,
         -- Master
         mAxisMaster  => obAppMaster,
         mAxisSlave   => obAppSlave); 

   U_Tx : entity work.RawEthFramerTx
      generic map (
         TPD_G         => TPD_G,
         REMOTE_SIZE_G => REMOTE_SIZE_G,
         ETH_TYPE_G    => ETH_TYPE_G) 
      port map (
         -- Local Configurations
         localMac    => localMac,
         remoteMac   => remoteMac,
         -- Interface to Ethernet Media Access Controller (MAC)
         ibMacMaster => ibMacMaster,
         ibMacSlave  => ibMacSlave,
         -- Interface to Application engine(s)
         obAppMaster => obAppMaster,
         obAppSlave  => obAppSlave,
         -- Clock and Reset
         clk         => clk,
         rst         => rst);

   U_Rx : entity work.RawEthFramerRx
      generic map (
         TPD_G         => TPD_G,
         REMOTE_SIZE_G => REMOTE_SIZE_G,
         ETH_TYPE_G    => ETH_TYPE_G) 
      port map (
         -- Local Configurations
         localMac    => localMac,
         remoteMac   => remoteMac,
         -- Interface to Ethernet Media Access Controller (MAC)
         obMacMaster => obMacMaster,
         obMacSlave  => obMacSlave,
         -- Interface to Application engine(s)
         ibAppMaster => ibAppMaster,
         ibAppSlave  => ibAppSlave,
         -- Clock and Reset
         clk         => clk,
         rst         => rst); 

   U_DeMux : entity work.AxiStreamDeMux
      generic map (
         TPD_G         => TPD_G,
         NUM_MASTERS_G => REMOTE_SIZE_G)
      port map (
         -- Clock and reset
         axisClk      => clk,
         axisRst      => rst,
         -- Slaves
         sAxisMaster  => ibAppMaster,
         sAxisSlave   => ibAppSlave,
         -- Master
         mAxisMasters => ibAppMasters,
         mAxisSlaves  => ibAppSlaves); 
end mapping;
