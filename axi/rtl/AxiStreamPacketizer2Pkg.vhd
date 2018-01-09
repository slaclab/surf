-------------------------------------------------------------------------------
-- Title      : Support Package for Packetizer Version 2
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-04-07
-- Last update: 2017-04-14
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

--    constant AXIS_CONFIG_C : AxiStreamConfigType := (
--       TSTRB_EN_C    => false,
--       TDATA_BYTES_C => 8,
--       TDEST_BITS_C  => 0,
--       TID_BITS_C    => 0,
--       TKEEP_MODE_C  => TKEEP_NORMAL_C,
--       TUSER_BITS_C  => 2,
--       TUSER_MODE_C  => TUSER_FIRST_LAST_C);

--    constant AXIS_CONFIG_C : AxiStreamConfigType := (
--       TSTRB_EN_C    => false,
--       TDATA_BYTES_C => 8,
--       TDEST_BITS_C  => 8,
--       TID_BITS_C    => 8,
--       TKEEP_MODE_C  => TKEEP_COMP_C,
--       TUSER_BITS_C  => 8,
--       TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   type PACKET_HDR_TUSER_FIELD_C is range 7 downto 0;
   type PACKET_HDR_TDEST_FIELD_C is range 15 downto 8;
   type PACKET_HDR_TID_FIELD_C is range 23 downto 16;
   constant PACKET_HDR_SOF_BIT_C : integer := 24;
   type PACKET_HDR_SEQ_FIELD_C is range 47 downto 32;

   constant PACKET_TAIL_EOF_BIT_C : integer := 8;
   type PACKET_TAIL_TUSER_FIELD_C is range 7 downto 0;
   type PACKET_TAIL_BYTES_FIELD_C is range 18 downto 16;
   type PACKET_TAIL_CRC_FIELD_C is range 63 downto 32;

   type Packetizer2DebugType is record
      sof  : sl;
      eof  : sl;
      eofe : sl;
      sop  : sl;
      eop  : sl;
      packetError : sl;
   end record Packetizer2DebugType;

   constant PACKETIZER2_DEBUG_INIT_C : Packetizer2DebugType := (
      sof  => '0',
      eof  => '0',
      eofe => '0',
      sop  => '0',
      eop  => '0',
      packetError => '0');

end package AxiStreamPacketizer2Pkg;


