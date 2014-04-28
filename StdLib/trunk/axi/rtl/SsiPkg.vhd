-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : SsiPkg.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-25
-- Last update: 2014-04-28
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

   function ssiAxiStreamConfig (dataBytes : natural) return AxiStreamConfigType;

   function ssiTxnIsComplaint (axisConfig : AxiStreamConfigType; axisMaster : AxiStreamMasterType) return boolean;

   function ssiSetUserBits (axisConfig : AxiStreamConfigType; eofe : sl ) return slv;

   function ssiGetUserEofe (axisConfig : AxiStreamConfigType; axisMaster : AxiStreamMasterType ) return sl;

end package SsiPkg;

package body SsiPkg is


   function ssiAxiStreamConfig (dataBytes : natural) return AxiStreamConfigType is
      variable ret : AxiStreamConfigType;
   begin
      ret.TDATA_BYTES_C := dataBytes;   -- Configurable data size
      ret.TUSER_BITS_C  := 2;           -- 2 TUSER EOFE, USER
      ret.TDEST_BITS_C  := 4;           -- 4 TDEST bits for VC
      ret.TID_BITS_C    := 0;           -- TID not used
      ret.TSTRB_EN_C    := false;       -- No TSTRB support in SSI
      return ret;
   end function ssiAxiStreamConfig;

   function ssiTxnIsComplaint (axisConfig : AxiStreamConfigType; axisMaster : AxiStreamMasterType) return boolean is
   begin
      return
         --allBits(axisMaster.tKeep(axisConfig.TDATA_BYTES_C-1 downto 0)) and  -- all expected tkeep
         --noBits(axisMaster.tKeep(axisMaster.tKeep'high downto axisConfig.TDATA_BYTES_C)) and
         allBits(axisMaster.tStrb(axisConfig.TDATA_BYTES_C-1 downto 0),'1') and  -- all expected tstrb
         noBits(axisMaster.tStrb(axisMaster.tStrb'high downto axisConfig.TDATA_BYTES_C),'1');
   end function ssiTxnIsComplaint;

   function ssiSetUserBits (axisConfig : AxiStreamConfigType; eofe : sl ) return slv is
      variable ret : slv(15 downto 0);
   begin
      ret := (others=>'0');

      for i in 0 to axisConfig.TDATA_BYTES_C-1 loop
         ret((axisConfig.TUSER_BITS_C*i) + SSI_EOFE_C) := eofe;
      end loop;

      return ret;
   end function;

   function ssiGetUserEofe (axisConfig : AxiStreamConfigType; axisMaster : AxiStreamMasterType ) return sl is
      variable ret       : sl;
      variable byteCount : integer;
   begin

      byteCount := conv_integer(onesCount(axisMaster.tKeep(axisConfig.TDATA_BYTES_C-1 downto 0)));
      ret := axisMaster.tUser(axisConfig.TUSER_BITS_C*(byteCount-1) + SSI_EOFE_C);

      return ret;

   end function;

end package body SsiPkg;
