-------------------------------------------------------------------------------
-- File       : SsiPkg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-25
-- Last update: 2016-05-04
-------------------------------------------------------------------------------
-- Description: SSI Package File
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;

package SsiPkg is

   constant SSI_EOFE_C : integer := 0;
   constant SSI_SOF_C  : integer := 1;

   constant SSI_TUSER_BITS_C : integer := 2;
   constant SSI_TDEST_BITS_C : integer := 4;
   constant SSI_TID_BITS_C   : integer := 0;
   constant SSI_TSTRB_EN_C   : boolean := false;

   constant SSI_MASTER_FORCE_EOFE_C : AxiStreamMasterType := (
      tValid => '1',                                   -- Force
      tData  => (others => '0'),
      tStrb  => (others => '1'),
      tKeep  => (others => '1'),
      tLast  => '1',                                   -- EOF
      tDest  => (others => '0'),
      tId    => (others => '0'),
      tUser  => x"01010101010101010101010101010101");  -- EOFE   

   -------------------------------------------------------------------------------------------------
   -- Build an SSI configuration
   -------------------------------------------------------------------------------------------------
   function ssiAxiStreamConfig (
      dataBytes : natural;
      tKeepMode : TKeepModeType        := TKEEP_COMP_C;
      tUserMode : TUserModeType        := TUSER_FIRST_LAST_C;
      tDestBits : integer range 0 to 8 := 4;
      tUserBits : integer range 2 to 8 := 2)
      return AxiStreamConfigType;

   -- A default SSI config is useful to have
   constant SSI_CONFIG_INIT_C : AxiStreamConfigType := ssiAxiStreamConfig(16);

   -------------------------------------------------------------------------------------------------
   -- SSI Records and AXI-Stream conversion functions
   -------------------------------------------------------------------------------------------------
   type SsiMasterType is record
      valid  : sl;
      data   : slv(127 downto 0);
      strb   : slv(15 downto 0);
      keep   : slv(15 downto 0);
      dest   : slv(SSI_TDEST_BITS_C-1 downto 0);
      packed : sl;
      sof    : sl;
      eof    : sl;
      eofe   : sl;
   end record SsiMasterType;

   type SsiSlaveType is record
      ready    : sl;
      pause    : sl;
      overflow : sl;
   end record SsiSlaveType;

   function ssi2AxisMaster (
      axisConfig : AxiStreamConfigType;
      ssiMaster  : SsiMasterType)
      return AxiStreamMasterType;

   function ssi2AxisSlave (
      ssiSlave : SsiSlaveType)
      return AxiStreamSlaveType;

   function ssi2AxisCtrl (
      ssiSlave : SsiSlaveType)
      return AxiStreamCtrlType;

   function axis2SsiMaster (
      axisConfig : AxiStreamConfigType;
      axisMaster : AxiStreamMasterType)
      return SsiMasterType;

   function axis2SsiSlave (
      axisConfig : AxiStreamConfigType;
      axisSlave  : AxiStreamSlaveType := AXI_STREAM_SLAVE_INIT_C;
      axisCtrl   : AxiStreamCtrlType  := AXI_STREAM_CTRL_UNUSED_C)
      return SsiSlaveType;

   function ssiMasterInit (
      axisConfig : AxiStreamConfigType)
      return SsiMasterType;

   function ssiSlaveInit (
      axisConfig : AxiStreamConfigType)
      return SsiSlaveType;

--   constant SSI_MASTER_INIT_C : SsiMasterType := axis2SsiMaster(SSI_CONFIG_INIT_C, AXI_STREAM_MASTER_INIT_C);
--   constant SSI_SLAVE_INIT_C  : SsiSlaveType  := axis2SsiSlave(AXI_STREAM_SLAVE_INIT_C, AXI_STREAM_CTRL_UNUSED_C);


   -------------------------------------------------------------------------------------------------
   -- Functions to interpret TUSER bits
   -------------------------------------------------------------------------------------------------
   function ssiGetUserEofe (
      axisConfig : AxiStreamConfigType;
      axisMaster : AxiStreamMasterType)
      return sl;

   procedure ssiSetUserEofe (
      axisConfig : in    AxiStreamConfigType;
      axisMaster : inout AxiStreamMasterType;
      eofe       : in    sl);

   function ssiGetUserSof (
      axisConfig : AxiStreamConfigType;
      axisMaster : AxiStreamMasterType)
      return sl;

   procedure ssiSetUserSof (
      axisConfig : in    AxiStreamConfigType;
      axisMaster : inout AxiStreamMasterType;
      sof        : in    sl);

   procedure ssiResetFlags (
      axisMaster : inout AxiStreamMasterType);

end package SsiPkg;

package body SsiPkg is

   function ssiAxiStreamConfig (
      dataBytes : natural;
      tKeepMode : TKeepModeType        := TKEEP_COMP_C;
      tUserMode : TUserModeType        := TUSER_FIRST_LAST_C;
      tDestBits : integer range 0 to 8 := 4;
      tUserBits : integer range 2 to 8 := 2)
      return AxiStreamConfigType is
      variable ret : AxiStreamConfigType;
   begin
      ret.TDATA_BYTES_C := dataBytes;       -- Configurable data size
      ret.TUSER_BITS_C  := tUserBits;       -- 2 TUSER: EOFE, SOF
      ret.TDEST_BITS_C  := tDestBits;       -- 4 TDEST bits for VC
      ret.TID_BITS_C    := SSI_TID_BITS_C;  -- TID not used
      ret.TKEEP_MODE_C  := tKeepMode;       -- 
      ret.TSTRB_EN_C    := SSI_TSTRB_EN_C;  -- No TSTRB support in SSI
      ret.TUSER_MODE_C  := tUserMode;       -- User field valid on last only
      return ret;
   end function ssiAxiStreamConfig;

   function ssiGetUserEofe (
      axisConfig : AxiStreamConfigType;
      axisMaster : AxiStreamMasterType)
      return sl is
      variable ret : sl;
   begin
      ret := axiStreamGetUserBit(axisConfig, axisMaster, SSI_EOFE_C);
      return ret;
   end function;

   -------------------------------------------------------------------------------------------------
   function ssi2AxisMaster (
      axisConfig : AxiStreamConfigType;
      ssiMaster  : SsiMasterType)
      return AxiStreamMasterType
   is
      variable ret : AxiStreamMasterType;
   begin
      ret                                    := AXI_STREAM_MASTER_INIT_C;
      ret.tValid                             := ssiMaster.valid;
      ret.tData                              := ssiMaster.data;
      ret.tLast                              := ssiMaster.eof;
      ret.tStrb                              := ssiMaster.strb;
      ret.tKeep                              := ssiMaster.keep;
      ret.tDest(SSI_TDEST_BITS_C-1 downto 0) := ssiMaster.dest;
      ssiSetUserSof(axisConfig, ret, ssiMaster.sof);
      ssiSetUserEofe(axisConfig, ret, ssiMaster.eofe);
      return ret;
   end function ssi2AxisMaster;

   function ssi2AxisSlave (
      ssiSlave : SsiSlaveType)
      return AxiStreamSlaveType
   is
      variable ret : AxiStreamSlaveType;
   begin
      ret.tReady := ssiSlave.ready;
      return ret;
   end function ssi2AxisSlave;

   function ssi2AxisCtrl (
      ssiSlave : SsiSlaveType)
      return AxiStreamCtrlType
   is
      variable ret : AxiStreamCtrlType;
   begin
      ret.pause    := ssiSlave.pause;
      ret.overflow := ssiSlave.overflow;
      return ret;
   end function ssi2AxisCtrl;

   function axis2SsiMaster (
      axisConfig : AxiStreamConfigType;
      axisMaster : AxiStreamMasterType)
      return SsiMasterType
   is
      variable ret : SsiMasterType;
   begin
      ret.valid  := axisMaster.tValid;
      ret.data   := axisMaster.tData;
      ret.strb   := axisMaster.tStrb;
      ret.keep   := axisMaster.tKeep;
      ret.packed := toSl(axiStreamPacked(axisConfig, axisMaster));
      ret.dest   := axisMaster.tDest(SSI_TDEST_BITS_C-1 downto 0);
      ret.sof    := ssiGetUserSof(axisConfig, axisMaster);
      ret.eof    := axisMaster.tLast;
      ret.eofe   := ssiGetUserEofe(axisConfig, axisMaster);
      return ret;
   end function axis2SsiMaster;

   function axis2SsiSlave (
      axisConfig : AxiStreamConfigType;
      axisSlave  : AxiStreamSlaveType := AXI_STREAM_SLAVE_INIT_C;
      axisCtrl   : AxiStreamCtrlType  := AXI_STREAM_CTRL_UNUSED_C)
      return SsiSlaveType
   is
      variable ret : SsiSlaveType;
   begin
      ret.ready    := axisSlave.tReady;
      ret.pause    := axisCtrl.pause;
      ret.overflow := axisCtrl.overflow;
      return ret;
   end function axis2SsiSlave;

   function ssiMasterInit (
      axisConfig : AxiStreamConfigType)
      return SsiMasterType is
      variable ret : SsiMasterType;
   begin
      ret      := axis2ssiMaster(axisConfig, AXI_STREAM_MASTER_INIT_C);
      ret.keep := genTKeep(axisConfig.TDATA_BYTES_C);
      return ret;
   end function ssiMasterInit;

   function ssiSlaveInit (
      axisConfig : AxiStreamConfigType)
      return SsiSlaveType is
   begin
      return axis2ssiSlave(axisConfig, AXI_STREAM_SLAVE_INIT_C, AXI_STREAM_CTRL_UNUSED_C);
   end function ssiSlaveInit;


   -------------------------------------------------------------------------------------------------
   procedure ssiSetUserEofe (
      axisConfig : in    AxiStreamConfigType;
      axisMaster : inout AxiStreamMasterType;
      eofe       : in    sl) is
   begin
      axiStreamSetUserBit(axisConfig, axisMaster, SSI_EOFE_C, eofe);
   end procedure;

   function ssiGetUserSof (
      axisConfig : AxiStreamConfigType;
      axisMaster : AxiStreamMasterType)
      return sl is
      variable ret : sl;
   begin
      ret := axiStreamGetUserBit(axisConfig, axisMaster, SSI_SOF_C, 0);
      return ret;
   end function;

   procedure ssiSetUserSof (
      axisConfig : in    AxiStreamConfigType;
      axisMaster : inout AxiStreamMasterType;
      sof        : in    sl) is
   begin
      axiStreamSetUserBit(axisConfig, axisMaster, SSI_SOF_C, sof, 0);
   end procedure;

   procedure ssiResetFlags (
      axisMaster : inout AxiStreamMasterType) is
   begin
      axisMaster.tValid := '0';
      axisMaster.tLast  := '0';
      axisMaster.tUser  := (others => '0');
   end procedure;

end package body SsiPkg;
