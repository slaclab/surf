-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: AxiMicronMt28ew Package File
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

package AxiMicronMt28ewPkg is

   type AxiMicronMt28ewInOutType is record
      dq : slv(15 downto 0);
   end record;
   type AxiMicronMt28ewInOutArray is array (natural range <>) of AxiMicronMt28ewInOutType;
   type AxiMicronMt28ewInOutVectorArray is array (integer range<>, integer range<>)of AxiMicronMt28ewInOutType;

   type AxiMicronMt28ewOutType is record
      ceL  : sl;
      oeL  : sl;
      weL  : sl;
      addr : slv(25 downto 0);
      rstL : sl;
   end record;
   type AxiMicronMt28ewOutArray is array (natural range <>) of AxiMicronMt28ewOutType;
   type AxiMicronMt28ewOutVectorArray is array (integer range<>, integer range<>)of AxiMicronMt28ewOutType;

end package;
