-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: AxiMicronP30 Package File
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

package AxiMicronP30Pkg is

   type AxiMicronP30InType is record
      flashWait : sl;
   end record;
   constant AXI_MICRON_P30_IN_INIT_C : AxiMicronP30InType := (
      flashWait => '0');
   type AxiMicronP30InArray is array (natural range <>) of AxiMicronP30InType;
   type AxiMicronP30InVectorArray is array (integer range<>, integer range<>)of AxiMicronP30InType;

   type AxiMicronP30InOutType is record
      dq : slv(15 downto 0);
   end record;
   constant AXI_MICRON_P30_INOUT_INIT_C : AxiMicronP30InOutType := (
      dq => (others => '0'));
   type AxiMicronP30InOutArray is array (natural range <>) of AxiMicronP30InOutType;
   type AxiMicronP30InOutVectorArray is array (integer range<>, integer range<>)of AxiMicronP30InOutType;

   type AxiMicronP30OutType is record
      ceL  : sl;
      oeL  : sl;
      weL  : sl;
      addr : slv(30 downto 0);
      adv  : sl;
      clk  : sl;
      rstL : sl;
   end record;
   constant AXI_MICRON_P30_OUT_INIT_C : AxiMicronP30OutType := (
      ceL  => '1',
      oeL  => '1',
      weL  => '1',
      addr => (others => '0'),
      adv  => '0',
      clk  => '0',
      rstL => '1');
   type AxiMicronP30OutArray is array (natural range <>) of AxiMicronP30OutType;
   type AxiMicronP30OutVectorArray is array (integer range<>, integer range<>)of AxiMicronP30OutType;

end package;
