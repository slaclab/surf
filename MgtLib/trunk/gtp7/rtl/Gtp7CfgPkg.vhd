-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Gtp7CfgPkg.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-09-02
-- Last update: 2014-09-15
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Provides useful functions for generating GTX7 configurations.
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
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
   end record Gtp7CfgType;

   constant QPLL_REFCLK_DIV_VALIDS_C : IntegerArray := (1, 2);
   constant QPLL_FBDIV_VALIDS_C      : IntegerArray := (1, 2, 3, 4, 5);
   constant QPLL_FBDIV_45_VALIDS_C   : IntegerArray := (4, 5);
   constant QPLL_OUT_DIV_VALIDS_C    : IntegerArray := (1, 2, 4, 8);

   constant QPLL_LOW_C  : real := 1.6E9;
   constant QPLL_HIGH_C : real := 3.3E9;

   impure function getGtp7QPllCfg (refClkFreq : real; lineRate : real) return Gtp7QPllCfgType;


end package Gtp7CfgPkg;

package body Gtp7CfgPkg is

   -------------------------------------------------------------------------------------------------
   -- QPLL Config
   -------------------------------------------------------------------------------------------------
   impure function getGtp7QPllCfg (
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
      dloop : for d in CPLL_OUT_DIV_VALIDS_C'range loop
         mloop : for m in CPLL_REFCLK_DIV_VALIDS_C'range loop
            n2loop : for n2 in CPLL_FBDIV_VALIDS_C'range loop
               n1loop : for n1 in CPLL_FBDIV_45_VALIDS_C'range loop
                  
                  pllClk := refClkFreq * real(CPLL_FBDIV_VALIDS_C(n2) * CPLL_FBDIV_45_VALIDS_C(n1)) /
                            real(CPLL_REFCLK_DIV_VALIDS_C(m));
                  rate := pllClk * 2.0 / real(CPLL_OUT_DIV_VALIDS_C(d));

                  if (pllClk > CPLL_LOW_C and pllClk < CPLL_HIGH_C and rate = lineRate) then

                     ret.CPLL_REFCLK_DIV_G := CPLL_REFCLK_DIV_VALIDS_C(m);
                     ret.CPLL_FBDIV_G      := CPLL_FBDIV_VALIDS_C(n2);
                     ret.CPLL_FBDIV_45_G   := CPLL_FBDIV_45_VALIDS_C(n1);
                     ret.OUT_DIV_G         := CPLL_OUT_DIV_VALIDS_C(d);
                     ret.CLK25_DIV_G       := integer(refClkFreq / 25.0E6);

                     found := true;

--                     report "Found GTX config: " & lf &
--                        "refClkFreq:        " & real'image(refClkFreq) & lf &
--                        "lineRate:          " & real'image(lineRate) & lf &
--                        "CPLL_REFCLK_DIV_G: " & integer'image(ret.CPLL_REFCLK_DIV_G) & lf &
--                        "CPLL_FBDIV_G:      " & integer'image(ret.CPLL_FBDIV_G) & lf &
--                        "CPLL_FBDIV_45_G:   " & integer'image(ret.CPLL_FBDIV_45_G) & lf &
--                        "OUT_DIV_G:         " & integer'image(ret.RXOUT_DIV_G) & lf
--                        severity note;

                     exit dloop;
                  end if;
               end loop;
            end loop;
         end loop;
      end loop;

      assert (found) report "getGtp7CPllCfg: no feasible configuration found for refClkFreq: " &
         real'image(refClkFreq) & " and lineRate: " & real'image(lineRate) severity failure;
      return ret;

   end function;


end package body Gtp7CfgPkg;
