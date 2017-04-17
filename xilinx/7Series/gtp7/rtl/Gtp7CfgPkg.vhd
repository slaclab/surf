-------------------------------------------------------------------------------
-- File       : Gtp7CfgPkg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-09-02
-- Last update: 2016-11-04
-------------------------------------------------------------------------------
-- Description: Provides useful functions for generating GTP7 configurations.
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.math_real.all;

use work.StdRtlPkg.all;

package Gtp7CfgPkg is

   -------------------------------------------------------------------------------------------------
   -- QPLL Config Types, Constants and Function declarations
   -------------------------------------------------------------------------------------------------
   type Gtp7QPllCfgType is record
      QPLL_REFCLK_DIV_G : integer;
      QPLL_FBDIV_G      : integer;
      QPLL_FBDIV_45_G   : integer;
      OUT_DIV_G         : integer;
      CLK25_DIV_G       : integer;
   end record;

   constant QPLL_REFCLK_DIV_VALIDS_C : IntegerArray := (1, 2);
   constant QPLL_FBDIV_VALIDS_C      : IntegerArray := (1, 2, 3, 4, 5);
   constant QPLL_FBDIV_45_VALIDS_C   : IntegerArray := (4, 5);
   constant QPLL_OUT_DIV_VALIDS_C    : IntegerArray := (1, 2, 4, 8);

   constant QPLL_LOW_C  : real := 1.6E9;
   constant QPLL_HIGH_C : real := 3.3E9;

   function getGtp7QPllCfg (refClkFreq : real; lineRate : real) return Gtp7QPllCfgType;

   function ite (i : boolean; t : Gtp7QPllCfgType; e : Gtp7QPllCfgType) return Gtp7QPllCfgType;


end package Gtp7CfgPkg;

package body Gtp7CfgPkg is

   -------------------------------------------------------------------------------------------------
   -- QPLL Config
   -------------------------------------------------------------------------------------------------
   function getGtp7QPllCfg (
      refClkFreq : real;
      lineRate   : real)
      return Gtp7QPllCfgType
   is
      variable ret    : Gtp7QPllCfgType;
      variable pllClk : real;
      variable rate   : real;
      variable found  : boolean;
   begin
      found := false;
      -- Walk through all possible configs and look for one that works
      dloop : for d in QPLL_OUT_DIV_VALIDS_C'range loop
         mloop : for m in QPLL_REFCLK_DIV_VALIDS_C'range loop
            n2loop : for n2 in QPLL_FBDIV_VALIDS_C'range loop
               n1loop : for n1 in QPLL_FBDIV_45_VALIDS_C'range loop

                  pllClk := refClkFreq * real(QPLL_FBDIV_VALIDS_C(n2) * QPLL_FBDIV_45_VALIDS_C(n1)) /
                            real(QPLL_REFCLK_DIV_VALIDS_C(m));
                  rate := pllClk * 2.0 / real(QPLL_OUT_DIV_VALIDS_C(d));

                  if (pllClk > QPLL_LOW_C and pllClk < QPLL_HIGH_C and rate = lineRate) then

                     ret.QPLL_REFCLK_DIV_G := QPLL_REFCLK_DIV_VALIDS_C(m);
                     ret.QPLL_FBDIV_G      := QPLL_FBDIV_VALIDS_C(n2);
                     ret.QPLL_FBDIV_45_G   := QPLL_FBDIV_45_VALIDS_C(n1);
                     ret.OUT_DIV_G         := QPLL_OUT_DIV_VALIDS_C(d);
                     ret.CLK25_DIV_G       := integer(refClkFreq / 25.0E6);

                     found := true;

--                     report "Found GTX config: " & lf &
--                        "refClkFreq:        " & real'image(refClkFreq) & lf &
--                        "lineRate:          " & real'image(lineRate) & lf &
--                        "QPLL_REFCLK_DIV_G: " & integer'image(ret.QPLL_REFCLK_DIV_G) & lf &
--                        "QPLL_FBDIV_G:      " & integer'image(ret.QPLL_FBDIV_G) & lf &
--                        "QPLL_FBDIV_45_G:   " & integer'image(ret.QPLL_FBDIV_45_G) & lf &
--                        "OUT_DIV_G:         " & integer'image(ret.OUT_DIV_G) & lf
--                        severity note;

                     exit dloop;
                  end if;
               end loop;
            end loop;
         end loop;
      end loop;

      assert (found) report "getGtp7QPllCfg: no feasible configuration found for refClkFreq: " &
         real'image(refClkFreq) & " and lineRate: " & real'image(lineRate) severity failure;
      return ret;

   end function;

   function ite (i : boolean; t : Gtp7QPllCfgType; e : Gtp7QPllCfgType) return Gtp7QPllCfgType is
   begin
      if (i) then
         return t;
      else
         return e;
      end if;
   end function ite;


end package body Gtp7CfgPkg;
