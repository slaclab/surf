-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : SsiPkg.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-25
-- Last update: 2014-05-02
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

   function ssiAxiStreamConfig (
      dataBytes : natural) 
      return AxiStreamConfigType;

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

end package SsiPkg;

package body SsiPkg is

   function ssiAxiStreamConfig (
      dataBytes : natural) 
      return AxiStreamConfigType is
      variable ret : AxiStreamConfigType;
   begin
      ret.TDATA_BYTES_C := dataBytes;          -- Configurable data size
      ret.TUSER_BITS_C  := 2;                  -- 2 TUSER: EOFE, SOF
      ret.TDEST_BITS_C  := 4;                  -- 4 TDEST bits for VC
      ret.TID_BITS_C    := 0;                  -- TID not used
      ret.TKEEP_MODE_C  := TKEEP_COMP_C;       -- Compress TKEEP
      ret.TSTRB_EN_C    := false;              -- No TSTRB support in SSI
      ret.TUSER_MODE_C  := TUSER_FIRST_LAST_C; -- User field valid on last only
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
   
end package body SsiPkg;
