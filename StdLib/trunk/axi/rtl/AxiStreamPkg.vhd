-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AxiStreamPkg.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-24
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

package AxiStreamPkg is

   type AxiStreamMasterType is record
      tValid : sl;
      tData  : slv(127 downto 0);
      tStrb  : slv(15 downto 0);
      tKeep  : slv(15 downto 0);
      tLast  : sl;
      tDest  : slv(7 downto 0);
      tId    : slv(7 downto 0);
      tUser  : slv(15 downto 0);
   end record AxiStreamMasterType;

   constant AXI_STREAM_MASTER_INIT_C : AxiStreamMasterType := (
      tValid => '0',
      tData  => (others => '0'),
      tStrb  => (others => '1'),
      tKeep  => (others => '1'),
      tLast  => '0',
      tDest  => (others => '0'),
      tId    => (others => '0'),
      tUser  => (others => '0'));
   type AxiStreamMasterArray is array (natural range<>) of AxiStreamMasterType;

   type AxiStreamSlaveType is record
      tReady : sl;
   end record AxiStreamSlaveType;

   type AxiStreamSlaveArray is array (natural range<>) of AxiStreamSlaveType;

   constant AXI_STREAM_SLAVE_INIT_C : AxiStreamSlaveType := (
      tReady => '0');

   constant AXI_STREAM_SLAVE_FORCE_C : AxiStreamSlaveType := (
      tReady => '1');

   type TUserModeType is (TUSER_NORMAL_C, TUSER_LAST_C);


   type AxiStreamConfigType is record
      TKEEP_EN_C    : boolean;
      TSTRB_EN_C    : boolean;
      TDATA_BYTES_C : natural;
      TDEST_BITS_C  : natural;
      TID_BITS_C    : natural;
      TUSER_BITS_C  : natural;
      TUSER_MODE_C  : TUserModeType;
   end record AxiStreamConfigType;

   constant AXI_STREAM_CONFIG_INIT_C : AxiStreamConfigType := (
      TKEEP_EN_C    => false,
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 16,
      TDEST_BITS_C  => 4,
      TID_BITS_C    => 0,
      TUSER_BITS_C  => 4,
      TUSER_MODE_C  => TUSER_NORMAL_C);

   type AxiStreamFifoStatusType is record
      almostFull : sl;
      overflow   : sl;
   end record AxiStreamFifoStatusType;

   type AxiStreamFifoStatusArray is array (natural range<>) of AxiStreamFifoStatusType;

   constant SSI_EOFE_TUSER_BIT_C : integer := 0;

end package AxiStreamPkg;

