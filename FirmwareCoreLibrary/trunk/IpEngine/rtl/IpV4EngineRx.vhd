-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : IpV4EngineRx.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-08-12
-- Last update: 2015-08-12
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.IpMacTablePkg.all;
use work.AxiStreamPkg.all;

entity IpV4EngineRx is
   generic (
      TPD_G  : time    := 1 ns;
      VLAN_G : boolean := false);       
   port (
      -- Interface to IP/MAC Table 
      ipv4DestReq  : out IpMacTableType;
      ipv4DestAck  : in  IpMacTableType;
      ipv4IpMacReq : out IpMacTableType;
      ipv4IpMacAck : in  IpMacTableType;
      -- Interface to UDP Engine  
      sUdpMaster   : in  AxiStreamMasterType;
      sUdpSlave    : out AxiStreamSlaveType;
      mUdpMaster   : out AxiStreamMasterType;
      mUdpSlave    : in  AxiStreamSlaveType;
      -- Interface to TCP Engine  
      sTcpMaster   : in  AxiStreamMasterType;
      sTcpSlave    : out AxiStreamSlaveType;
      mTcpMaster   : out AxiStreamMasterType;
      mTcpSlave    : in  AxiStreamSlaveType;
      -- Interface to Etherenet Frame MUX/DEMUX 
      ibIpv4Master : in  AxiStreamMasterType;
      ibIpv4Slave  : out AxiStreamSlaveType;
      obIpv4Master : out AxiStreamMasterType;
      obIpv4Slave  : in  AxiStreamSlaveType;
      -- Clock and Reset
      clk          : in  sl;
      rst          : in  sl);
end IpV4EngineRx;

architecture mapping of IpV4EngineRx is

begin

    

end mapping;
