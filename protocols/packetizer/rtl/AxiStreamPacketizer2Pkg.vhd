-------------------------------------------------------------------------------
-- Title      : AxiStreamPackerizerV2 Protocol: https://confluence.slac.stanford.edu/x/3nh4DQ
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Support Package for Packetizer Version 2
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


library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

package AxiStreamPacketizer2Pkg is

   constant PACKETIZER2_VERSION_C : slv(3 downto 0) := x"2";

   constant PACKETIZER2_CRC_MODE_NONE_C    : slv(3 downto 0) := x"0";
   constant PACKETIZER2_CRC_MODE_DATA_C    : slv(3 downto 0) := x"1";
   constant PACKETIZER2_CRC_MODE_FULL_C    : slv(3 downto 0) := x"2";
   constant PACKETIZER2_CRC_MODE_INVALID_C : slv(3 downto 0) := x"F";

   ---------------------------------------------------------------
   -- Header Definition
   ---------------------------------------------------------------
   subtype PACKETIZER2_HDR_VERSION_FIELD_C is natural range 3 downto 0;
   subtype PACKETIZER2_HDR_CRC_TYPE_FIELD_C is natural range 7 downto 4;
   subtype PACKETIZER2_HDR_TUSER_FIELD_C is natural range 15 downto 8;
   constant PACKETIZER2_HDR_TDEST_BIT_C : integer := 16;
   subtype PACKETIZER2_HDR_TDEST_FIELD_C is natural range 23 downto PACKETIZER2_HDR_TDEST_BIT_C;
   subtype PACKETIZER2_HDR_TID_FIELD_C is natural range 31 downto 24;
   subtype PACKETIZER2_HDR_SEQ_FIELD_C is natural range 47 downto 32;
   -- BIT62:BIT48 unused
   constant PACKETIZER2_HDR_SOF_BIT_C   : integer := 63;
   ---------------------------------------------------------------

   ---------------------------------------------------------------
   -- Tail Definition
   ---------------------------------------------------------------
   subtype PACKETIZER2_TAIL_TUSER_FIELD_C is natural range 7 downto 0;
   constant PACKETIZER2_TAIL_EOF_BIT_C : integer := 8;
   -- BIT15:BIT9 unused
   subtype PACKETIZER2_TAIL_BYTES_FIELD_C is natural range 19 downto 16;
   -- BIT31:BIT20 unused
   subtype PACKETIZER2_TAIL_CRC_FIELD_C is natural range 63 downto 32;

   -- AxiStream format for packetized data
   constant PACKETIZER2_AXIS_CFG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 8,
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 8,
      TKEEP_MODE_C  => TKEEP_NORMAL_C,
      TUSER_BITS_C  => 2,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   type Packetizer2DebugType is record
      initDone     : sl;
      sof          : sl;
      eof          : sl;
      eofe         : sl;
      sop          : sl;
      eop          : sl;
      packetError  : sl;
      sofError     : sl;
      seqError     : sl;
      versionError : sl;
      crcModeError : sl;
      eofeError    : sl;
      crcError     : sl;
   end record Packetizer2DebugType;
   type Packetizer2DebugArray is array (natural range<>) of Packetizer2DebugType;
   constant PACKETIZER2_DEBUG_INIT_C : Packetizer2DebugType := (
      initDone     => '0',
      sof          => '0',
      eof          => '0',
      eofe         => '0',
      sop          => '0',
      eop          => '0',
      packetError  => '0',
      sofError     => '0',
      seqError     => '0',
      versionError => '0',
      crcModeError => '0',
      eofeError    => '0',
      crcError     => '0');

   function crcStrToSlv (CRC_MODE_C : string) return slv;

   function makePacketizer2Header (
      CRC_MODE_C : string;
      valid      : sl               := '0';
      sof        : sl               := '1';
      tuser      : slv(7 downto 0)  := (others => '0');
      tdest      : slv(7 downto 0)  := (others => '0');
      tid        : slv(7 downto 0)  := (others => '0');
      seq        : slv(15 downto 0) := (others => '0'))
      return AxiStreamMasterType;

   function makePacketizer2TailTdata (
      CRC_MODE_C : string;
      eof        : sl               := '1';
      tuser      : slv(7 downto 0)  := (others => '0');
      bytes      : slv(3 downto 0)  := "1000";  -- Default 8 bytes
      crc        : slv(31 downto 0) := (others => '0'))
      return slv;

   function makePacketizer2Tail (
      CRC_MODE_C : string;
      valid      : sl               := '0';
      eof        : sl               := '1';
      tuser      : slv(7 downto 0)  := (others => '0');
      bytes      : slv(3 downto 0)  := "1000";  -- Default 8 bytes
      crc        : slv(31 downto 0) := (others => '0'))
      return axiStreamMasterType;

end package AxiStreamPacketizer2Pkg;

package body AxiStreamPacketizer2Pkg is

   function crcStrToSlv (CRC_MODE_C : string) return slv is
      variable retVar : slv(3 downto 0);
   begin
      if (CRC_MODE_C = "NONE") then
         retVar := PACKETIZER2_CRC_MODE_NONE_C;
      elsif (CRC_MODE_C = "DATA") then
         retVar := PACKETIZER2_CRC_MODE_DATA_C;
      elsif (CRC_MODE_C = "FULL") then
         retVar := PACKETIZER2_CRC_MODE_FULL_C;
      else
         retVar := PACKETIZER2_CRC_MODE_INVALID_C;
      end if;
      return retVar;
   end function;

   function makePacketizer2Header (
      CRC_MODE_C : string;
      valid      : sl               := '0';
      sof        : sl               := '1';
      tuser      : slv(7 downto 0)  := (others => '0');
      tdest      : slv(7 downto 0)  := (others => '0');
      tid        : slv(7 downto 0)  := (others => '0');
      seq        : slv(15 downto 0) := (others => '0'))
      return AxiStreamMasterType
   is
      variable ret : AxiStreamMasterType;
   begin
      ret                                         := axiStreamMasterInit(PACKETIZER2_AXIS_CFG_C);
      ret.tValid                                  := valid;
      ret.tData(PACKETIZER2_HDR_VERSION_FIELD_C)  := PACKETIZER2_VERSION_C;
      ret.tData(PACKETIZER2_HDR_CRC_TYPE_FIELD_C) := crcStrToSlv(CRC_MODE_C);
      ret.tData(PACKETIZER2_HDR_SOF_BIT_C)        := sof;
      ret.tData(PACKETIZER2_HDR_TUSER_FIELD_C)    := tuser;
      ret.tData(PACKETIZER2_HDR_TDEST_FIELD_C)    := tdest;
      ret.tData(PACKETIZER2_HDR_TID_FIELD_C)      := tid;
      ret.tData(PACKETIZER2_HDR_SEQ_FIELD_C)      := seq;
      axiStreamSetUserBit(PACKETIZER2_AXIS_CFG_C, ret, SSI_SOF_C, '1', 0);
      return ret;
   end function makePacketizer2Header;

   function makePacketizer2TailTdata (
      CRC_MODE_C : string;
      eof        : sl               := '1';
      tuser      : slv(7 downto 0)  := (others => '0');
      bytes      : slv(3 downto 0)  := "1000";
      crc        : slv(31 downto 0) := (others => '0'))
      return slv
   is
      variable ret : slv(63 downto 0);
   begin
      ret                                 := (others => '0');
      ret(PACKETIZER2_TAIL_EOF_BIT_C)     := eof;
      ret(PACKETIZER2_TAIL_TUSER_FIELD_C) := tuser;
      ret(PACKETIZER2_TAIL_BYTES_FIELD_C) := bytes;
      ret(PACKETIZER2_TAIL_CRC_FIELD_C)   := ite((CRC_MODE_C /= "NONE"), crc, x"00000000");
      return ret;
   end function makePacketizer2TailTdata;

   function makePacketizer2Tail (
      CRC_MODE_C : string;
      valid      : sl               := '0';
      eof        : sl               := '1';
      tuser      : slv(7 downto 0)  := (others => '0');
      bytes      : slv(3 downto 0)  := "1000";
      crc        : slv(31 downto 0) := (others => '0'))
      return AxiStreamMasterType
   is
      variable ret : AxiStreamMasterType;
   begin
      ret        := axiStreamMasterInit(PACKETIZER2_AXIS_CFG_C);
      ret.tValid := valid;
      ret.tLast  := '1';
      ret.tData(63 downto 0) :=
         makePacketizer2TailTdata(
            CRC_MODE_C => CRC_MODE_C,
            eof        => eof,
            tuser      => tuser,
            bytes      => bytes,
            crc        => crc);
      return ret;
   end function makePacketizer2Tail;

end package body AxiStreamPacketizer2Pkg;
