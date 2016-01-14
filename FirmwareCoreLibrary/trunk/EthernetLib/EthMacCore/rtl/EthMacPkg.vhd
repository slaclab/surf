-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EthMacPkg.vhd
-- Author     : Ryan Herbst  <rherbst@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-09-21
-- Last update: 2015-09-21
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;

package EthMacPkg is

   -- Default MAC is 01:03:00:56:44:00
   constant EMAC_ADDR_INIT_C : slv(47 downto 0) := x"020300564400";

   -- EOF Bit
   constant EMAC_SOF_BIT_C    : integer := 1;
   constant EMAC_EOFE_BIT_C   : integer := 0;
   constant EMAC_IPERR_BIT_C  : integer := 1;
   constant EMAC_TCPERR_BIT_C : integer := 2;
   constant EMAC_UDPERR_BIT_C : integer := 3;

   -- Ethernet AXI Stream Configuration
   constant EMAC_AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 8,
      TDEST_BITS_C  => 0,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 4,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   -- Generic XMAC Configuration
   type EthMacConfigType is record
      macAddress    : slv(47 downto 0);
      filtEnable    : sl;
      pauseEnable   : sl;
      pauseTime     : slv(15 downto 0);
      interFrameGap : slv(3  downto 0);
      txShift       : slv(3  downto 0);
      rxShift       : slv(3  downto 0);
      ipCsumEn      : sl;
      tcpCsumEn     : sl;
      udpCsumEn     : sl;
      dropOnPause   : sl;
   end record EthMacConfigType;

   constant ETH_MAC_CONFIG_INIT_C : EthMacConfigType := (
      macAddress    => EMAC_ADDR_INIT_C,
      filtEnable    => '1',
      pauseEnable   => '1',
      pauseTime     => x"00FF",
      interFrameGap => x"3",
      txShift       => (others=>'0'),
      rxShift       => (others=>'0'),
      ipCsumEn      => '0',
      tcpCsumEn     => '0',
      udpCsumEn     => '0',
      dropOnPause   => '0'
   );

   type EthMacConfigArray is array (natural range<>) of EthMacConfigType;


   -- Generic XMAC Status
   type EthMacStatusType is record
      rxPauseCnt    : sl;
      txPauseCnt    : sl;
      rxCountEn     : sl;
      rxOverFlow    : sl;
      rxCrcErrorCnt : sl;
      txCountEn     : sl;
      txUnderRunCnt : sl;
      txNotReadyCnt : sl;
   end record EthMacStatusType;

   constant ETH_MAC_STATUS_INIT_C : EthMacStatusType := (
      rxPauseCnt    => '0',
      txPauseCnt    => '0',
      rxCountEn     => '0',
      rxOverFlow    => '0',
      rxCrcErrorCnt => '0',
      txCountEn     => '0',
      txUnderRunCnt => '0',
      txNotReadyCnt => '0'
   );

   type EthMacStatusArray is array (natural range<>) of EthMacStatusType;

end package EthMacPkg;

