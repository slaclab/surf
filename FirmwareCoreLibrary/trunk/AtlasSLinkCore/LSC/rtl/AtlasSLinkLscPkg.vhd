-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AtlasSLinkLscPkg.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-10
-- Last update: 2015-04-24
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:   This package contains all the constants, types, and records.
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;

package AtlasSLinkLscPkg is

   type AtlasSLinkLscConfigType is record
      startCmd    : slv(31 downto 0);
      stopCmd     : slv(31 downto 0);
      blowOff     : sl;
      blowOffMask : slv(31 downto 0);
      userRst     : sl;
   end record;
   constant ATLAS_SLINK_CONFIG_INIT_C : AtlasSLinkLscConfigType := (
      startCmd    => x"B0F00000",
      stopCmd     => x"E0F00000",
      blowOff     => '1',
      blowOffMask => x"FFFFFFFF",
      userRst     => '1'); 

   type AtlasSLinkLscStatusType is record
      debug      : Slv32Array(0 to 0);
      xorCheck   : sl;
      linkActive : sl;
      flowCtrl   : sl;
      overflow   : sl;
      testMode   : sl;
      linkFull   : sl;
      linkUp     : sl;
      linkDown   : sl;
      gtxReady   : sl;
      packetSent : sl;
      fullRate   : slv(31 downto 0);
      pktCnt     : slv(31 downto 0);
      pktCntMax  : slv(31 downto 0);
      pktCntMin  : slv(31 downto 0);
      dmaSize    : slv(31 downto 0);
      dmaMaxSize : slv(31 downto 0);
      dmaMinSize : slv(31 downto 0);
   end record;
   constant ATLAS_SLINK_STATUS_INIT_C : AtlasSLinkLscStatusType := (
      debug      => (others => (others => '0')),
      xorCheck   => '0',
      linkActive => '0',
      flowCtrl   => '0',
      overflow   => '0',
      testMode   => '0',
      linkFull   => '0',
      linkUp     => '0',
      linkDown   => '0',
      gtxReady   => '0',
      packetSent => '0',
      fullRate   => (others => '0'),
      pktCnt     => (others => '0'),
      pktCntMax  => (others => '0'),
      pktCntMin  => (others => '0'),
      dmaSize    => (others => '0'),
      dmaMaxSize => (others => '0'),
      dmaMinSize => (others => '0'));  

end package AtlasSLinkLscPkg;
