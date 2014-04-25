-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : SsiPkg.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-25
-- Last update: 2014-04-25
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

package SsiPkg is

   constant SSI_SOF_TUSER_BIT_C  : integer := 0;
   constant SSI_EOF_TUSER_BIT_C  : integer := 1;
   constant SSI_EOFE_TUSER_BIT_C : integer := 2;
   constant SSI_OPEN_TUSER_BIT_C : integer := 3;

   type SsiMasterType is record
      tValid : sl;
      tData  : slv(127 downto 0);
      tKeep  : slv(15 downto 0);
      tLast  : sl;
      vc     : slv(3 downto 0);
      sof    : sl;
      eof    : sl;
      eofe   : sl;
   end record SsiMasterType;

   function toSsiMaster (axi : AxiStreamMasterType) return SsiMasterType;

   function toAxiStreamMaster (ssi : SsiMasterType) return AxiStreamMasterType;

   function ssiAxiStreamConfig (dataBytes : natural) return AxiStreamConfigType;

end package SsiPkg;

package body SsiPkg is

   function toSsiMaster (axi : AxiStreamMasterType) return SsiMasterType is
      variable ssi : SsiMasterType;
   begin
      ssi.tValid := axi.tValid;
      ssi.tData  := axi.tData;
      ssi.tKeep  := axi.tKeep;
      ssi.tLast  := axi.tLast;
      ssi.vc     := axi.tDest(3 downto 0);
      ssi.sof    := axi.tUser(SSI_SOF_TUSER_BIT_C);
      ssi.eof    := axi.tUser(SSI_EOF_TUSER_BIT_C);
      ssi.eofe   := axi.tUser(SSI_EOFE_TUSER_BIT_C);
      return ssi;
   end function toSsiMaster;

   function toAxiStreamMaster (ssi : SsiMasterType) return AxiStreamMasterType is
      variable axi : AxiStreamMasterType;
   begin
      axi.tValid                      := ssi.tValid;
      axi.tData                       := ssi.tData;
      axi.tKeep                       := ssi.tKeep;
      axi.tLast                       := ssi.tLast;
      axi.tDest(3 downto 0)           := ssi.vc;
      axi.tUser(SSI_SOF_TUSER_BIT_C)  := ssi.sof;
      axi.tUser(SSI_EOF_TUSER_BIT_C)  := ssi.eof;
      axi.tUser(SSI_EOFE_TUSER_BIT_C) := ssi.eofe;
   end function toAxiStreamMaster;

   function ssiAxiStreamConfig (dataBytes : natural; tKeepEn : boolean) return AxiStreamConfigType is
      variable ret : AxiStreamConfigType;
   begin
      ret.TDATA_BYTES_C := dataBytes;   -- Configurable data size
      ret.TUSER_BITS_C  := 4;           -- 4 TUSER bits for SOF, EOF, EOFE, USER
      ret.TDEST_BITS_C  := 4;           -- 4 TDEST bits for VC
      ret.TID_BITS_C    := 0;           -- TID not used
      ret.TKEEP_EN_C    := tKeepEn;     -- Optional TKEEP support
      ret.TSTRB_EN_C    := false;       -- No TSTRB support in SSI
      return ret;
   end function ssiAxiStreamConfig;

end package body SsiPkg;
