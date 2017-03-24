-------------------------------------------------------------------------------
-- File       : Ad9249Pkg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-05-26
-- Last update: 2016-06-06
-------------------------------------------------------------------------------
-- Description: AD9249 Package File
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
use work.AxiStreamPkg.all;

package Ad9249Pkg is

   -- Interface to AD9249 chip
   -- Chip has two SerialGroup outputs
   type Ad9249SerialGroupType is record
      fClkP : sl;                       -- Frame clock
      fClkN : sl;
      dClkP : sl;                       -- Data clock
      dClkN : sl;
      chP   : slv(7 downto 0);          -- Serial Data channels
      chN   : slv(7 downto 0);
   end record;

   type Ad9249SerialGroupArray is array (natural range <>) of Ad9249SerialGroupType;

   constant AD9249_AXIS_CFG_G : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 2,
      TDEST_BITS_C  => 0,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_FIXED_C,
      TUSER_BITS_C  => 0,
      TUSER_MODE_C  => TUSER_NONE_C);

   -- Deserialized data output
--   type Ad9249ReadoutType is record
--     valid : sl;
--     data  : slv16Array(15 downto 0);
--   end record;

--   constant ADC_READOUT_INIT_C : Ad9249ReadoutType := (
--      valid => '0',
--      data => (others => X"0000"));

--   type Ad9249ReadoutArray is array (natural range <>) of Ad9249ReadoutType;

end package Ad9249Pkg;
