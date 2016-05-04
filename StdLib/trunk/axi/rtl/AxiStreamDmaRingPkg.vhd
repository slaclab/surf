-------------------------------------------------------------------------------
-- Title      : AxiStreamDmaRingPkg Support Package
-------------------------------------------------------------------------------
-- File       : AxiStreamDmaRingPkg.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-03-08
-- Last update: 2016-04-26
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- This file is part of SLAC Firmware Standard Library. It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of SLAC Firmware Standard Library, including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;

package AxiStreamDmaRingPkg is

   constant AXIL_MASTERS_C : integer := 7;
   constant START_AXIL_C   : integer := 0;
   constant END_AXIL_C     : integer := 1;
   constant FIRST_AXIL_C   : integer := 2;
   constant NEXT_AXIL_C    : integer := 3;
   constant TRIG_AXIL_C    : integer := 4;
   constant MODE_AXIL_C    : integer := 5;
   constant STATUS_AXIL_C  : integer := 6;

   -- Status constants
   constant EMPTY_C     : integer := 0;
   constant FULL_C      : integer := 1;
   constant DONE_C      : integer := 2;
   constant TRIGGERED_C : integer := 3;
   constant ERROR_C     : integer := 4;
   subtype FST_C is integer range 31 downto 8;

   -- Mode constants
   constant ENABLED_C        : integer := 0;  -- Not currently used
   constant DONE_WHEN_FULL_C : integer := 1;
   constant INIT_C           : integer := 2;
   constant SOFT_TRIGGER_C   : integer := 3;
   subtype STATUS_TDEST_C is integer range 7 downto 4;
   subtype FAT_C is integer range 31 downto 8;

   constant INIT_BYTE_C : integer := INIT_C / 8;

   constant BUFFER_CLEAR_OFFSET_C : slv(7 downto 0) := X"18";

   function getBufferAddr (
      baseAddr : slv(31 downto 0);
      busIndex : integer range 0 to 7;
      buf      : slv(5 downto 0) := (others => '0');
      high     : sl              := '0')
      return slv;

   constant DMA_RING_STATUS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 1,
      TDEST_BITS_C  => 0,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_FIXED_C,  --ite(BSA_STREAM_BYTE_WIDTH_G = 4, TKEEP_FIXED_C, TKEEP_COMP_C),
      TUSER_BITS_C  => 1,
      TUSER_MODE_C  => TUSER_NONE_C);

end package AxiStreamDmaRingPkg;

package body AxiStreamDmaRingPkg is

   function getBufferAddr (
      baseAddr : slv(31 downto 0);
      busIndex : integer range 0 to 7;
      buf      : slv(5 downto 0) := (others => '0');
      high     : sl              := '0')
      return slv
   is
      variable ret : slv(31 downto 0);
   begin
      ret := baseAddr(31 downto 12) & toSlv(busIndex, 3) & buf & high & "00";
      return ret;
   end function;


--    function getAxilConfig (
--       baseAddr : slv(31 downto 0);
--       busIndex : integer)
--       return AxiLiteCrossbarMasterConfigType
--    is
--       variable ret : AxiLiteCrossbarMasterConfigType;
--    begin

--    end function getAxilConfig;

end package body AxiStreamDmaRingPkg;

