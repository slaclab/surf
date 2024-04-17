-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: AD9681 Package File
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;

package Ad9681Pkg is

   -- Interface to AD9681 chip
   -- Chip has two Serial outputs
   type Ad9681SerialType is record
      fClkP : slv(1 downto 0);                       -- Frame clock
      fClkN : slv(1 downto 0);
      dClkP : slv(1 downto 0);                       -- Data clock
      dClkN : slv(1 downto 0);
      chP   : slv8Array(1 downto 0);          -- Serial Data channels
      chN   : slv8Array(1 downto 0);
   end record;

   type Ad9681SerialArray is array (natural range <>) of Ad9681SerialType;

   constant AD9681_AXIS_CFG_G : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 2,
      TDEST_BITS_C  => 0,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_FIXED_C,
      TUSER_BITS_C  => 0,
      TUSER_MODE_C  => TUSER_NONE_C);

   -- Deserialized data output
--   type Ad9681ReadoutType is record
--     valid : sl;
--     data  : slv16Array(15 downto 0);
--   end record;

--   constant ADC_READOUT_INIT_C : Ad9681ReadoutType := (
--      valid => '0',
--      data => (others => X"0000"));

--   type Ad9681ReadoutArray is array (natural range <>) of Ad9681ReadoutType;

end package Ad9681Pkg;
