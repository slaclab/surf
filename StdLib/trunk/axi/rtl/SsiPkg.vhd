-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : SsiPkg.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-25
-- Last update: 2014-05-13
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
use work.AxiStreamPkg.all;

package SsiPkg is

   constant SSI_EOFE_C : integer := 0;
   constant SSI_SOF_C  : integer := 1;

   constant SSI_TUSER_BITS_C : integer := 2;
   constant SSI_TDEST_BITS_C : integer := 4;
   constant SSI_TID_BITS_C   : integer := 0;
   constant SSI_TSTRB_EN_C   : boolean := false;

   -------------------------------------------------------------------------------------------------
   -- Build an SSI configuration
   -------------------------------------------------------------------------------------------------
   function ssiAxiStreamConfig (
      dataBytes : natural;
      tKeepMode : TKeepModeType := TKEEP_COMP_C) 
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
      tKeepMode : TKeepModeType := TKEEP_COMP_C) 
      return AxiStreamConfigType is
      variable ret : AxiStreamConfigType;
   begin
      ret.TDATA_BYTES_C := dataBytes;           -- Configurable data size
      ret.TUSER_BITS_C  := SSI_TUSER_BITS_C;    -- 2 TUSER: EOFE, SOF
      ret.TDEST_BITS_C  := SSI_TDEST_BITS_C;    -- 4 TDEST bits for VC
      ret.TID_BITS_C    := SSI_TID_BITS_C;      -- TID not used
      ret.TKEEP_MODE_C  := tKeepMode;           -- Compress TKEEP
      ret.TSTRB_EN_C    := SSI_TSTRB_EN_C;      -- No TSTRB support in SSI
      ret.TUSER_MODE_C  := TUSER_FIRST_LAST_C;  -- User field valid on last only
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
      ret        := AXI_STREAM_MASTER_INIT_C;
      ret.tValid := ssiMaster.valid;
      ret.tData  := ssiMaster.data;
      ret.tLast  := ssiMaster.eof;
      ret.tStrb  := ssiMaster.strb;
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
      ret.packed := toSl(axiStreamPacked(axisConfig, axisMaster));
      ret.dest   := axisMaster.tDest(axisConfig.TDEST_BITS_C-1 downto 0);
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
   begin
      return axis2ssiMaster(axisConfig, AXI_STREAM_MASTER_INIT_C);
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
      ret := axiStreamGetUserBit(axisConfig, axisMaster, SSI_SOF_C);
      return ret;
   end function;

   procedure ssiSetUserSof (
      axisConfig : in    AxiStreamConfigType;
      axisMaster : inout AxiStreamMasterType;
      sof        : in    sl) is
   begin
      axiStreamSetUserBit(axisConfig, axisMaster, SSI_SOF_C, sof);
   end procedure;
   
   procedure ssiResetFlags (
      axisMaster : inout AxiStreamMasterType) is
   begin
      axisMaster.tValid := '0';
      axisMaster.tLast  := '0';
      axisMaster.tUser  := (others => '0');
   end procedure;
   
end package body SsiPkg;
