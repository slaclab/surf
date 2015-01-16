-------------------------------------------------------------------------------
-- Title         : Ethernet Client, Core Package File
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : EthClientPackage.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 10/18/2010
-------------------------------------------------------------------------------
-- Description:
-- Core package file for general purpose firmware ethenet client.
-------------------------------------------------------------------------------
-- Copyright (c) 2010 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 10/18/2010: created.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

package EthClientPackage is

   -- Register delay for simulation
   constant tpd : time := 0.5 ns;

   -- Type for IP address
   type IPAddrType is array(3 downto 0) of std_logic_vector(7 downto 0);
   constant IP_ADDR_INIT_C : IPAddrType := (3 => x"C0", 2 => x"A8", 1 => x"01", 0 => x"14");

   -- Type for mac address
   type MacAddrType is array(5 downto 0) of std_logic_vector(7 downto 0);
   constant MAC_ADDR_INIT_C : MacAddrType := (5 => x"01", 4 => x"03", 3 => x"00", 2 => x"56", 1 => x"44", 0 => x"00");

   -- Ethernet header field constants
   constant EthTypeIPV4 : std_logic_vector(15 downto 0) := x"0800";
   constant EthTypeARP  : std_logic_vector(15 downto 0) := x"0806";
   constant EthTypeMac  : std_logic_vector(15 downto 0) := x"8808";

   -- UDP header field constants
   constant UDPProtocol : std_logic_vector(7 downto 0) := x"11";

   -- ARP Message container
   type ARPMsgType is array(27 downto 0) of std_logic_vector(7 downto 0);

   -- IPV4/UDP Header container
   type UDPMsgType is array(27 downto 0) of std_logic_vector(7 downto 0);

end EthClientPackage;

