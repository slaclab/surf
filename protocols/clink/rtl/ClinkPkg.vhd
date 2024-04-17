-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- CameraLink Package
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

library surf;
use surf.StdRtlPkg.all;

package ClinkPkg is

   ------------------------------------
   -- Link Modes
   ------------------------------------
   constant CLM_NONE_C : slv(2 downto 0) := "000";
   constant CLM_BASE_C : slv(2 downto 0) := "001";
   constant CLM_MEDM_C : slv(2 downto 0) := "010";
   constant CLM_FULL_C : slv(2 downto 0) := "011";
   constant CLM_DECA_C : slv(2 downto 0) := "100";

   ------------------------------------
   -- Data Modes
   ------------------------------------
   constant CDM_NONE_C  : slv(3 downto 0) := "0000";
   constant CDM_8BIT_C  : slv(3 downto 0) := "0001";
   constant CDM_10BIT_C : slv(3 downto 0) := "0010";
   constant CDM_12BIT_C : slv(3 downto 0) := "0011";
   constant CDM_14BIT_C : slv(3 downto 0) := "0100";
   constant CDM_16BIT_C : slv(3 downto 0) := "0101";
   constant CDM_24BIT_C : slv(3 downto 0) := "0110";
   constant CDM_30BIT_C : slv(3 downto 0) := "0111";
   constant CDM_36BIT_C : slv(3 downto 0) := "1000";

   ------------------------------------
   -- Framing Modes
   ------------------------------------
   constant CFM_NONE_C  : slv(1 downto 0) := "00";
   constant CFM_LINE_C  : slv(1 downto 0) := "01";
   constant CFM_FRAME_C : slv(1 downto 0) := "10";

   ------------------------------------
   -- Link Configuration Record
   ------------------------------------
   type ClLinkConfigType is record
      cntRst : sl;
      rstFsm : sl;
      rstPll : sl;
   end record ClLinkConfigType;

   constant CL_LINK_CONFIG_INIT_C : ClLinkConfigType := (
      cntRst => '0',
      rstFsm => '0',
      rstPll => '0');

   type ClLinkConfigArray is array (natural range<>) of ClLinkConfigType;

   ------------------------------------
   -- Link Status Record
   ------------------------------------
   type ClLinkStatusType is record
      clkInFreq    : slv(31 downto 0);
      clinkClkFreq : slv(31 downto 0);
      locked       : sl;
      delay        : slv(4 downto 0);
      shiftCnt     : slv(2 downto 0);
   end record ClLinkStatusType;

   constant CL_LINK_STATUS_INIT_C : ClLinkStatusType := (
      clkInFreq    => (others => '0'),
      clinkClkFreq => (others => '0'),
      locked       => '0',
      delay        => (others => '0'),
      shiftCnt     => (others => '0'));

   type ClLinkStatusArray is array (natural range<>) of ClLinkStatusType;

   ------------------------------------
   -- Channel Configuration Record
   ------------------------------------
   type ClChanConfigType is record
      hSkip       : slv(15 downto 0);
      hActive     : slv(15 downto 0);
      vSkip       : slv(15 downto 0);
      vActive     : slv(15 downto 0);
      swCamCtrl   : slv(3 downto 0);
      swCamCtrlEn : slv(3 downto 0);
      serBaud     : slv(23 downto 0);
      serThrottle : slv(15 downto 0);
      linkMode    : slv(2 downto 0);
      dataMode    : slv(3 downto 0);
      tapCount    : slv(3 downto 0);
      frameMode   : slv(3 downto 0);
      cntRst      : sl;
      blowoff     : sl;
      dataEn      : sl;
   end record ClChanConfigType;

   constant CL_CHAN_CONFIG_INIT_C : ClChanConfigType := (
      hSkip       => (others => '0'),
      hActive     => (others => '1'),
      vSkip       => (others => '0'),
      vActive     => (others => '1'),
      swCamCtrl   => (others => '0'),
      swCamCtrlEn => (others => '0'),
      serBaud     => toSlv(9600, 24),   -- Default of 9600 baud
      serThrottle => toSlv(10000, 16),  -- Default of 10ms per byte throttle rate
      linkMode    => (others => '0'),
      dataMode    => (others => '0'),
      tapCount    => (others => '0'),
      frameMode   => (others => '0'),
      cntRst      => '0',
      blowoff     => '0',
      dataEn      => '0');

   type ClChanConfigArray is array (natural range<>) of ClChanConfigType;

   ------------------------------------
   -- Channel Status Record
   ------------------------------------
   type ClChanStatusType is record
      running    : sl;
      frameSize  : slv(31 downto 0);
      frameCount : slv(31 downto 0);
      dropCount  : slv(31 downto 0);
   end record ClChanStatusType;

   constant CL_CHAN_STATUS_INIT_C : ClChanStatusType := (
      running    => '0',
      frameSize  => (others => '0'),
      frameCount => (others => '0'),
      dropCount  => (others => '0'));

   type ClChanStatusArray is array (natural range<>) of ClChanStatusType;

   ------------------------------------
   -- Data Type
   ------------------------------------
   type ClDataType is record
      valid : sl;
      data  : Slv8Array(15 downto 0);
      dv    : sl;
      fv    : sl;
      lv    : sl;
   end record ClDataType;

   constant CL_DATA_INIT_C : ClDataType := (
      valid => '0',
      data  => (others => (others => '0')),
      dv    => '0',
      fv    => '0',
      lv    => '0');

end package ClinkPkg;

package body ClinkPkg is

end package body ClinkPkg;

