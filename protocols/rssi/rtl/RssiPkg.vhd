-------------------------------------------------------------------------------
-- File       : RssiPkg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-08-09
-- Last update: 2016-07-12
-------------------------------------------------------------------------------
-- Description: RSSI Package File
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.SsiPkg.all;
use work.AxiStreamPkg.all;

package RssiPkg is

   --------------------------------------------------------------------------
   -- Common constant definitions
   --------------------------------------------------------------------------
   constant RSSI_WORD_WIDTH_C  : positive            := 8;  -- 64 bit word (FIXED)
   constant RSSI_AXIS_CONFIG_C : AxiStreamConfigType :=
      ssiAxiStreamConfig(
         dataBytes => RSSI_WORD_WIDTH_C,
         tKeepMode => TKEEP_COMP_C,
         tUserMode => TUSER_FIRST_LAST_C,
         tDestBits => 0,
         tUserBits => 2);

   -- Header sizes
   constant SYN_HEADER_SIZE_C  : natural := 24;
   constant ACK_HEADER_SIZE_C  : natural := 8;
   constant EACK_HEADER_SIZE_C : natural := 8;
   constant RST_HEADER_SIZE_C  : natural := 8;
   constant NULL_HEADER_SIZE_C : natural := 8;
   constant DATA_HEADER_SIZE_C : natural := 8;

   -------------------------------------------------------------------------- 
   -- Sub-types 
   -------------------------------------------------------------------------- 
   type RssiParamType is record
      version     : slv(3 downto 0);
      chksumEn    : slv(0 downto 0);
      timeoutUnit : slv(7 downto 0);

      maxOutsSeg : slv(7 downto 0);     -- Receiver parameter       
      maxSegSize : slv(15 downto 0);    -- Receiver parameter

      retransTout  : slv(15 downto 0);
      cumulAckTout : slv(15 downto 0);
      nullSegTout  : slv(15 downto 0);

      maxRetrans : slv(7 downto 0);
      maxCumAck  : slv(7 downto 0);

      maxOutofseq : slv(7 downto 0);

      connectionId : slv(31 downto 0);
   end record RssiParamType;

   constant RSSI_PARAM_INIT_C : RssiParamType := (
      version      => (others => '0'),
      chksumEn     => (others => '0'),
      timeoutUnit  => (others => '0'),
      maxOutsSeg   => (others => '0'),
      maxSegSize   => (others => '0'),
      retransTout  => (others => '0'),
      cumulAckTout => (others => '0'),
      nullSegTout  => (others => '0'),
      maxRetrans   => (others => '0'),
      maxCumAck    => (others => '0'),
      maxOutofseq  => (others => '0'),
      connectionId => (others => '0'));

   type flagsType is record
      syn  : sl;
      ack  : sl;
      eack : sl;
      rst  : sl;
      nul  : sl;
      data : sl;
      busy : sl;
      eofe : sl;
   end record flagsType;

   type WindowType is record
      seqN     : slv(7 downto 0);
      segType  : slv(2 downto 0);
      keep     : slv(15 downto 0);
      segSize  : natural;
      occupied : sl;
   end record WindowType;

   constant WINDOW_INIT_C : WindowType := (
      seqN     => (others => '0'),
      segType  => (others => '0'),
      keep     => (others => '1'),
      segSize  => 0,
      occupied => '0');

   -- Arrays   
   type WindowTypeArray is array (natural range<>) of WindowType;

   --------------------------------------------------------------------------  
   -- Function declarations
   --------------------------------------------------------------------------  
   -- Swap little and big endians
   -- 64-bit header word
   function endianSwap64(data_slv : slv(63 downto 0)) return std_logic_vector;

end RssiPkg;

package body RssiPkg is

   --------------------------------------------------------------------------  
   -- Function bodies
   --------------------------------------------------------------------------  
   -- Swap little or big endians 64-bit header
   function endianSwap64(data_slv : slv(63 downto 0)) return std_logic_vector is
      variable vSlv : slv(63 downto 0);
   begin
      vSlv := (others => '0');

      for i in 7 downto 0 loop
         vSlv((8*(7-i))+7 downto 8*(7-i)) := data_slv((8*i)+7 downto 8*i);
      end loop;

      return vSlv;

   end endianSwap64;
--------------------------------------------------------------------------------------------
end package body RssiPkg;
