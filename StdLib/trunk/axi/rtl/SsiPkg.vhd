-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : SsiPkg.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-25
-- Last update: 2014-04-29
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

end package body SsiPkg;

