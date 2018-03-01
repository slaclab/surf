-------------------------------------------------------------------------------
-- Title      : Support Package for Packetizer Version 2
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-04-07
-- Last update: 2018-02-28
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of SURF. It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of SURF, including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

package AxiStreamPacketizer2Pkg is

   constant PACKETIZER2_VERSION_C : slv(3 downto 0) := X"2";

   subtype PACKETIZER2_HDR_VERSION_FIELD_C is natural range 3 downto 0;
   constant PACKETIZER2_HDR_CRC_TYPE_FIELD_C : integer := 7;
   subtype PACKETIZER2_HDR_TUSER_FIELD_C is natural range 15 downto 8;
   subtype PACKETIZER2_HDR_TDEST_FIELD_C is natural range 23 downto 16;
   subtype PACKETIZER2_HDR_TID_FIELD_C is natural range 31 downto 24;
   constant PACKETIZER2_HDR_SOF_BIT_C        : integer := 63;
   subtype PACKETIZER2_HDR_SEQ_FIELD_C is natural range 47 downto 32;

   constant PACKETIZER2_TAIL_EOF_BIT_C : integer := 8;
   subtype PACKETIZER2_TAIL_TUSER_FIELD_C is natural range 7 downto 0;
   subtype PACKETIZER2_TAIL_BYTES_FIELD_C is natural range 19 downto 16;
   subtype PACKETIZER2_TAIL_CRC_FIELD_C is natural range 63 downto 32;

   -- AxiStream format for packetized data
   constant PACKETIZER2_AXIS_CFG_C : AxiStreamConfigType :=(
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 8,
      TDEST_BITS_C  => 0,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_NORMAL_C,
      TUSER_BITS_C  => 2, 
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   type Packetizer2CfgType is record
--      OUTPUT_SSI_C    : boolean;
      CRC_EN_C        : boolean;
      CRC_HEAD_TAIL_C : boolean;
      AXIS_CFG_C      : AxiStreamConfigType;
   end record Packetizer2CfgType;

   type Packetizer2DebugType is record
      sof         : sl;
      eof         : sl;
      eofe        : sl;
      sop         : sl;
      eop         : sl;
      packetError : sl;
   end record Packetizer2DebugType;

   constant PACKETIZER2_DEBUG_INIT_C : Packetizer2DebugType := (
      sof         => '0',
      eof         => '0',
      eofe        => '0',
      sop         => '0',
      eop         => '0',
      packetError => '0');


   function makePacketizer2Header (
      CFG_C : Packetizer2CfgType;
      sof   : sl               := '1';
      tuser : slv(7 downto 0)  := (others => '0');
      tdest : slv(7 downto 0)  := (others => '0');
      tid   : slv(7 downto 0)  := (others => '0');
      seq   : slv(15 downto 0) := (others => '0'))
      return AxiStreamMasterType;

   function makePacketizer2Tail (
      CFG_C : Packetizer2CfgType;
      eof   : sl               := '1';
      tuser : slv(7 downto 0)  := (others => '0');
      bytes : slv(3 downto 0)  := "1000";  -- Default 8 bytes
      crc   : slv(31 downto 0) := (others => '0'))
      return axiStreamMasterType;

end package AxiStreamPacketizer2Pkg;

package body AxiStreamPacketizer2Pkg is

   function makePacketizer2Header (
      CRC_CFG_C : string;
      sof   : sl               := '1';
      tuser : slv(7 downto 0)  := (others => '0');
      tdest : slv(7 downto 0)  := (others => '0');
      tid   : slv(7 downto 0)  := (others => '0');
      seq   : slv(15 downto 0) := (others => '0'))
      return AxiStreamMasterType;
   is
      variable ret : AxiStreamMasterType;
   begin
      ret                                         := axiStreamMasterInit(PACKETIZER2_AXIS_CFG_C);
      ret.tData(PACKETIZER2_HDR_VERSION_FIELD_C)  := PACKETIZER2_VERSION_C;
      ret.tData(PACKETIZER2_HDR_CRC_TYPE_FIELD_C) := toSl(CRC_CFG_C = "FULL");
      ret.tData(PACKETIZER2_HDR_SOF_BIT_C)        := sof;
      ret.tData(PACKETIZER2_HDR_TUSER_FIELD_C)    := tuser;
      ret.tData(PACKETIZER2_HDR_TDEST_FIELD_C)    := tdest;
      ret.tData(PACKETIZER2_HDR_TID_FIELD_C)      := tid;
      ret.tData(PACKETIZER2_HDR_SEQ_FIELD_C)      := seq;
      axiStreamSetUserBit(CFG_C.AXIS_CFG_C, ret, SSI_SOF_C, '1', 0); 
      return ret;
   end function makePacketizer2Header;

   function makePacketizer2Tail (
      eof   : sl               := '1';
      tuser : slv(7 downto 0)  := (others => '0');
      bytes : slv(3 downto 0)  := "1000";
      crc   : slv(31 downto 0) := (others => '0'))
      return AxiStreamMasterType;
   is
      variable ret : AxiStreamMasterType;
   begin
      ret                                       := axiStreamMasterInit(PACKETIZER2_AXIS_CFG_C);
      ret.tData(PACKETIZER2_TAIL_EOF_BIT_C)     := eof;
      ret.tData(PACKETIZER2_TAIL_TUSER_FIELD_C) := tuser;
      ret.tData(PACKETIZER2_TAIL_BYTES_FIELD_C) := bytes;
      ret.tData(PACKETIZER2_TAIL_CRC_FIELD_C)   := crc;
      ret.tLast                                 := '1';
      return ret;
   end function makePacketizer2Tail;


end package body AxiStreamPacketizer2Pkg;


