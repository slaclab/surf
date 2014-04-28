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

   function ssiTxnIsComplaint (axiConfig : AxiStreamConfigType; axisMaster : AxiStreamMasterType) return boolean;

end package SsiPkg;

package body SsiPkg is


   function ssiAxiStreamConfig (dataBytes : natural) return AxiStreamConfigType is
      variable ret : AxiStreamConfigType;
   begin
      ret.TDATA_BYTES_C := dataBytes;   -- Configurable data size
      ret.TUSER_BITS_C  := 1;           -- 4 TUSER bits for SOF, EOF, EOFE, USER
      ret.TDEST_BITS_C  := 4;           -- 4 TDEST bits for VC
      ret.TID_BITS_C    := 0;           -- TID not used
      ret.TKEEP_EN_C    := true;        -- Optional TKEEP support
      ret.TSTRB_EN_C    := false;       -- No TSTRB support in SSI
      return ret;
   end function ssiAxiStreamConfig;

   function ssiTxnIsComplaint (axiConfig : AxiStreamConfigType; axisMaster : AxiStreamMasterType) return boolean is
   begin
      return
         allBits(axisMaster.tKeep(axisConfig.TDATA_BYTES_C-1 downto 0)) and  -- all expected tkeep
         noBits(axisMaster.tKeep(axisMaster.tKeep'high downto axisConfig.TDATA_BYTES_C)) and
         allBits(axisMaster.tStrb(axisConfig.TDATA_BYTES_C-1 downto 0)) and  -- all expected tstrb
         noBits(axisMaster.tStrb(axisMaster.tStrb'high downto axisConfig.TDATA_BYTES_C)) 
   end function ssiTxnIsComplaint;

end package body SsiPkg;
