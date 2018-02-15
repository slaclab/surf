-------------------------------------------------------------------------------
-- Title      : Support Package for Packetizer Version 2
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-04-07
-- Last update: 2018-02-14
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

   constant PACKETIZER2_VERSION_C : slv(7 downto 0) := X"02";

   subtype PACKETIZER2_HDR_VERSION_FIELD_C is natural range 7 downto 0;
   subtype PACKETIZER2_HDR_TUSER_FIELD_C is natural range 15 downto 8;
   subtype PACKETIZER2_HDR_TDEST_FIELD_C is natural range 23 downto 16;
   subtype PACKETIZER2_HDR_TID_FIELD_C is natural range 31 downto 24;
   constant PACKETIZER2_HDR_SOF_BIT_C : integer := 63;
   subtype PACKETIZER2_HDR_SEQ_FIELD_C is natural range 47 downto 32;

   constant PACKETIZER2_TAIL_EOF_BIT_C : integer := 8;
   subtype PACKETIZER2_TAIL_TUSER_FIELD_C is natural range 7 downto 0;
   subtype PACKETIZER2_TAIL_BYTES_FIELD_C is natural range 19 downto 16;
   subtype PACKETIZER2_TAIL_CRC_FIELD_C is natural range 63 downto 32;

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
      sof   : sl               := '1';
      tuser : slv(7 downto 0)  := (others => '0');
      tdest : slv(7 downto 0)  := (others => '0');
      tid   : slv(7 downto 0)  := (others => '0');
      seq   : slv(15 downto 0) := (others => '0'))
      return slv;

   function makePacketizer2Tail (
      eof   : sl               := '1';
      tuser : slv(7 downto 0)  := (others => '0');
      bytes : slv(3 downto 0)  := "1000";  -- Default 8 bytes
      crc   : slv(31 downto 0) := (others => '0'))
      return slv;

end package AxiStreamPacketizer2Pkg;

package body AxiStreamPacketizer2Pkg is

   function makePacketizer2Header (
      sof   : sl               := '1';
      tuser : slv(7 downto 0)  := (others => '0');
      tdest : slv(7 downto 0)  := (others => '0');
      tid   : slv(7 downto 0)  := (others => '0');
      seq   : slv(15 downto 0) := (others => '0'))
      return slv
   is
      variable ret : slv(63 downto 0);
   begin
      ret                             := (others => '0');
      ret(PACKETIZER2_HDR_VERSION_FIELD_C) := PACKETIZER2_VERSION_C;
      ret(PACKETIZER2_HDR_SOF_BIT_C)       := sof;
      ret(PACKETIZER2_HDR_TUSER_FIELD_C)   := tuser;
      ret(PACKETIZER2_HDR_TDEST_FIELD_C)   := tdest;
      ret(PACKETIZER2_HDR_TID_FIELD_C)     := tid;
      ret(PACKETIZER2_HDR_SEQ_FIELD_C)     := seq;
      return ret;
   end function makePacketizer2Header;

   function makePacketizer2Tail (
      eof   : sl               := '1';
      tuser : slv(7 downto 0)  := (others => '0');
      bytes : slv(3 downto 0)  := "1000";
      crc   : slv(31 downto 0) := (others => '0'))
      return slv
   is
      variable ret : slv(63 downto 0);
   begin
      ret                            := (others => '0');
      ret(PACKETIZER2_TAIL_EOF_BIT_C)     := eof;
      ret(PACKETIZER2_TAIL_TUSER_FIELD_C) := tuser;
      ret(PACKETIZER2_TAIL_BYTES_FIELD_C) := bytes;
      ret(PACKETIZER2_TAIL_CRC_FIELD_C)   := crc;
      return ret;
   end function makePacketizer2Tail;

end package body AxiStreamPacketizer2Pkg;


