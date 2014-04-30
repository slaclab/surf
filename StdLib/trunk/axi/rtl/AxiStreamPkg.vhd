-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AxiStreamPkg.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-24
-- Last update: 2014-04-30
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;

package AxiStreamPkg is

   type AxiStreamMasterType is record
      tValid : sl;
      tData  : slv(127 downto 0);
      tStrb  : slv(15  downto 0);
      tKeep  : slv(15  downto 0);
      tLast  : sl;
      tDest  : slv(7   downto 0);
      tId    : slv(7   downto 0);
      tUser  : slv(127 downto 0);
   end record AxiStreamMasterType;

   constant AXI_STREAM_MASTER_INIT_C : AxiStreamMasterType := (
      tValid => '0',
      tData  => (others => '0'),
      tStrb  => (others => '0'),
      tKeep  => (others => '0'),
      tLast  => '0',
      tDest  => (others => '0'),
      tId    => (others => '0'),
      tUser  => (others => '0'));
   type AxiStreamMasterArray is array (natural range<>) of AxiStreamMasterType;

   type AxiStreamSlaveType is record
      tReady : sl;
   end record AxiStreamSlaveType;

   type AxiStreamSlaveArray is array (natural range<>) of AxiStreamSlaveType;

   constant AXI_STREAM_SLAVE_INIT_C : AxiStreamSlaveType := (
      tReady => '0');

   constant AXI_STREAM_SLAVE_FORCE_C : AxiStreamSlaveType := (
      tReady => '1');

   type TUserModeType is (TUSER_NORMAL_C, TUSER_LAST_C);

   type AxiStreamConfigType is record
      TSTRB_EN_C    : boolean;
      TDATA_BYTES_C : natural range 1 to 16;
      TDEST_BITS_C  : natural range 0 to 8;
      TID_BITS_C    : natural range 0 to 8;
      TUSER_BITS_C  : natural range 2 to 8;
      TUSER_MODE_C  : TUserModeType;
   end record AxiStreamConfigType;

   constant AXI_STREAM_CONFIG_INIT_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 16,
      TDEST_BITS_C  => 4,
      TID_BITS_C    => 0,
      TUSER_BITS_C  => 4,
      TUSER_MODE_C  => TUSER_NORMAL_C);

   type AxiStreamCtrlType is record
      pause    : sl;
      overflow : sl;
   end record AxiStreamCtrlType;

   constant AXI_STREAM_CTRL_INIT_C : AxiStreamCtrlType := (
      pause    => '1',
      overflow => '0');

   type AxiStreamCtrlArray is array (natural range<>) of AxiStreamCtrlType;

   function axiStreamPacked (
      constant CONFIG_C : AxiStreamConfigType;
      axisMaster        : AxiStreamMasterType)
      return boolean;

   function axiStreamGetUserField (
      axisConfig : AxiStreamConfigType; 
      axisMaster : AxiStreamMasterType; 
      bytePos    : integer := -1 ) -- -1 = last
      return slv;

   function axiStreamGetUserBit (
      axisConfig : AxiStreamConfigType; 
      axisMaster : AxiStreamMasterType; 
      bitPos     : integer; 
      bytePos    : integer := -1)  -- -1 = last
      return sl;

   procedure axiStreamSetUserField (
      axisConfig : in    AxiStreamConfigType; 
      axisMaster : inout AxiStreamMasterType; 
      fieldValue : in    slv;
      bytePos    : in    integer := -1); -- -1 = last

   procedure axiStreamSetUserBit (
      axisConfig : in    AxiStreamConfigType; 
      axisMaster : inout AxiStreamMasterType; 
      bitPos     : in    integer;
      bitValue   : in    sl;
      bytePos    : in    integer := -1); -- -1 = last

end package AxiStreamPkg;

package body AxiStreamPkg is

   function axiStreamPacked (
      constant CONFIG_C : AxiStreamConfigType;
      axisMaster        : AxiStreamMasterType)
      return boolean is
   begin
      return 
         allBits(axisMaster.tKeep(CONFIG_C.TDATA_BYTES_C-1 downto 0), '1') and  -- all expected tkeep
         allBits(axisMaster.tStrb(CONFIG_C.TDATA_BYTES_C-1 downto 0), '1');  -- all expected tstrb
   end function;

   function axiStreamGetUserField (
      axisConfig : AxiStreamConfigType; 
      axisMaster : AxiStreamMasterType; 
      bytePos    : integer := -1 )
      return slv is

      variable pos : integer;
      variable ret : slv(axisConfig.TUSER_BITS_C-1 downto 0);
   begin

      if bytePos = -1 then
         pos := conv_integer(onesCount(axisMaster.tKeep(axisConfig.TDATA_BYTES_C-1 downto 0))) - 1;
      else
         pos := bytePos;
      end if;

      ret := axisMaster.tUser((axisConfig.TUSER_BITS_C*pos)+axisConfig.TUSER_BITS_C-1 downto ((axisConfig.TUSER_BITS_C*pos)));
      
      return(ret); 
   end function;

   function axiStreamGetUserBit (
      axisConfig : AxiStreamConfigType; 
      axisMaster : AxiStreamMasterType; 
      bitPos     : integer; 
      bytePos    : integer := -1) -- -1 = last
      return sl is

      variable user : slv(axisConfig.TUSER_BITS_C-1 downto 0);
   begin

      user := axiStreamGetuserField(axisConfig,axisMaster,bytePos);
      return(user(bitPos));

   end function;

   procedure axiStreamSetUserField (
      axisConfig : in    AxiStreamConfigType; 
      axisMaster : inout AxiStreamMasterType; 
      fieldValue : in    slv;
      bytePos    : in    integer := -1) is

      variable pos : integer;
   begin

      if bytePos = -1 then
         pos := conv_integer(onesCount(axisMaster.tKeep(axisConfig.TDATA_BYTES_C-1 downto 0))) - 1;
      else
         pos := bytePos;
      end if;

      axisMaster.tUser((axisConfig.TUSER_BITS_C*pos)+axisConfig.TUSER_BITS_C-1 downto ((axisConfig.TUSER_BITS_C*pos))) := fieldValue;

   end procedure;

   procedure axiStreamSetUserBit (
      axisConfig : in    AxiStreamConfigType; 
      axisMaster : inout AxiStreamMasterType; 
      bitPos     : in    integer;
      bitValue   : in    sl;
      bytePos    : in    integer := -1) is

      variable pos : integer;
   begin

      if bytePos = -1 then
         pos := conv_integer(onesCount(axisMaster.tKeep(axisConfig.TDATA_BYTES_C-1 downto 0))) - 1;
      else
         pos := bytePos;
      end if;

      axisMaster.tUser((axisConfig.TUSER_BITS_C*pos)+axisConfig.TUSER_BITS_C-1 downto ((axisConfig.TUSER_BITS_C*pos)))(bitPos) := bitValue;

   end procedure;

end package body AxiStreamPkg;

