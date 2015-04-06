-------------------------------------------------------------------------------
-- Title      : 10G Ethernet MAC Core Package
-------------------------------------------------------------------------------
-- File       : XMacPkg.vhd
-- Author     : Ryan Herbst <rherbst@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-02-12
-- Last update: 2015-02-23
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 10G Ethernet MAC Core: constants & types.
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;

package XMacPkg is

   -- Default MAC is 01:03:00:56:44:00
   constant XMAC_ADDR_INIT_C : slv(47 downto 0) := x"010300564400";

   type XMacConfig is record
      macAddress      : slv(47 downto 0);
      byteSwap        : sl;
      -- Outbound Configurations
      txShift         : slv(3 downto 0);
      txShiftEn       : sl;
      txInterFrameGap : slv(3 downto 0);
      txPauseTime     : slv(15 downto 0);
      -- Inbound Configurations
      rxShift         : slv(3 downto 0);
      rxShiftEn       : sl;
   end record;
   
   constant XMAC_CONFIG_INIT_C : TenGigEthMacConfig := (
      macAddress      => TEN_GIG_ETH_MAC_ADDR_INIT_C,
      byteSwap        => '0',
      -- Inbound Configurations
      rxShift         => (others => '0'),
      rxShiftEn       => '0',
      -- Outbound Configurations
      txShift         => (others => '0'),
      txShiftEn       => '0',
      txInterFrameGap => (others => '1'),
      txPauseTime     => (others => '1'));

   type XMacStatus is record
      -- PHY Pause Interface
      rxPauseReq     : sl;
      rxPauseSet     : sl;
      rxPauseValue   : slv(15 downto 0);
      -- Inbound Status
      rxCountEn      : sl;
      rxOverFlow     : sl;
      rxCrcError     : sl;
      -- Outbound Status
      txCountEn      : sl;
      txUnderRun     : sl;
      txLinkNotReady : sl;
   end record;
   
end XMacPkg;
