-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AxiStreamPkg.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-24
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

package AxiStreamPkg is

   type AxiStreamMasterType is record
      tValid : sl;
      tData  : slv(127 downto 0);
      tStrb  : slv(15  downto 0);
      tKeep  : slv(15  downto 0);
      tLast  : sl;
      tDest  : slv(127 downto 0);
      tId    : slv(127 downto 0);
      tUser  : slv(127 downto 0);
   end record AxiStreamMasterType;

   constant AXI_STREAM_MASTER_INIT_C : AxiStreamMasterType := (
      tValid => '0',
      tData  => (others=>'0'),
      tStrb  => (others=>'0'),
      tKeep  => (others=>'0'),
      tLast  => '0',
      tDest  => (others=>'0'),
      tId    => (others=>'0'),
      tUser  => (others=>'0')
   );

   type AxiStreamSlaveType is record
      tReady : sl;
   end record AxiStreamSlaveType;

   constant AXI_STREAM_SLAVE_INIT_C : AxiStreamSlaveType := (
      tReady => '0'
   );

   type AxiStreamConfigType is record
      TKEEP_EN_C            : boolean;
      TSTRB_EN_C            : boolean;
      TDATA_BYTES_C         : natural range 1 to 16;
      TDEST_BITS_C          : natural range 0 to 128;
      TID_BITS_C            : natural range 0 to 128;
      TUSER_BITS_PER_BYTE_C : natural range 0 to 8;
   end record AxiStreamConfigType;

   constant AXI_STREAM_CONFIG_INIT_C : AxiStreamConfigType := (
      TKEEP_EN_C            => false,
      TSTRB_EN_C            => false,
      TDATA_BYTES_C         => 16,
      TDEST_BITS_C          => 4,
      TID_BITS_C            => 0,
      TUSER_BITS_PER_BYTE_C => 4
   );

end package AxiStreamPkg;

