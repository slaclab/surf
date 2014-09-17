-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Gtx7CfgPkg.vhd
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

package Gtx7CfgPkg is

   -------------------------------------------------------------------------------------------------
   -- CPLL Config Types, Constants and Function declarations
   -------------------------------------------------------------------------------------------------
   type Gtx7CPllCfgType is record
      CPLL_REFCLK_DIV_G : integer;
      CPLL_FBDIV_G      : integer;
      CPLL_FBDIV_45_G   : integer;
      OUT_DIV_G         : integer;
      CLK25_DIV_G       : integer;
   end record Gtx7CfgType;

   constant CPLL_REFCLK_DIV_VALIDS_C : IntegerArray := (1, 2);
   constant CPLL_FBDIV_VALIDS_C      : IntegerArray := (1, 2, 3, 4, 5);
   constant CPLL_FBDIV_45_VALIDS_C   : IntegerArray := (4, 5);
   constant CPLL_OUT_DIV_VALIDS_C    : IntegerArray := (1, 2, 4, 8);

   constant CPLL_LOW_C  : real := 1.6E9;
   constant CPLL_HIGH_C : real := 3.3E9;

   impure function getGtx7CPllCfg (refClkFreq : real; lineRate : real) return Gtx7CPllCfgType;

   -------------------------------------------------------------------------------------------------
   -- QPLL
   -------------------------------------------------------------------------------------------------
   type Gtx7QPllCfgType is record
      QPLL_REFCLK_DIV_G  : integer;
      QPLL_FBDIV_RATIO_G : integer;
      QPLL_FBDIV_G       : slv(9 downto 0);
      OUT_DIV_G          : integer;
      CLK25_DIV_G        : integer;
   end record Gtx7QPllCfgType;

   constant QPLL_REFCLK_DIV_VALIDS_C : IntegerArray := (1, 2, 3, 4);
   constant QPLL_FBDIV_INT_VALIDS_C  : IntegerArray := (16, 20, 32, 40, 64, 66, 80, 100);
   constant QPLL_OUT_DIV_VALIDS_C    : IntegerArray := (1, 2, 4, 8, 16);

   constant QPLL_LOWER_BAND_LOW_C  : real := 5.93E9;
   constant QPLL_LOWER_BAND_HIGH_C : real := 8.0E9;
   constant QPLL_UPPER_BAND_LOW_C  : real := 9.8E9;
   constant QPLL_UPPER_BAND_HIGH_C : real := 12.5E9;

   impure function getQPllFbdiv (fbdivInt : integer) return slv;

   impure function getGtx7QPllCfg (refClkFreq : real; lineRate : real) return Gtx7QPllCfgType;

end package Gtx7CfgPkg;

package body Gtx7CfgPkg is

   -------------------------------------------------------------------------------------------------
   -- CPLL Config
   -------------------------------------------------------------------------------------------------
   impure function getGtx7CPllCfg (
      refClkFreq : real;
      lineRate   : real)
      return Gtx7CPllCfgType
   is
      variable ret    : Gtx7CPllCfgType;
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

      assert (found) report "getGtx7CPllCfg: no feasible configuration found for refClkFreq: " &
         real'image(refClkFreq) & " and lineRate: " & real'image(lineRate) severity failure;
      return ret;

   end function;

   -------------------------------------------------------------------------------------------------
   -- QPLL
   -------------------------------------------------------------------------------------------------
   impure function getQPllFbdiv (fbdivInt : integer) return slv is
      variable ret : slv(9 downto 0) := (others => '0');
   begin
      case (fbdivInt) is
         when 16  => ret := "0000100000";
         when 20  => ret := "0000110000";
         when 32  => ret := "0001100000";
         when 40  => ret := "0010000000";
         when 64  => ret := "0011100000";
         when 66  => ret := "0101000000";
         when 80  => ret := "0100100000";
         when 100 => ret := "0101110000";
      end case;
      return ret;
   end function getQPllFbdiv;

   impure function getGtx7QPllCfg (
      refClkFreq : real;
      lineRate   : real)
      return Gtx7QPllCfgType
   is
      variable ret    : Gtx7QPllCfgType;
      variable pllClk : real;
      variable rate   : real;
      variable found  : boolean;
   begin
      found := false;
      -- Walk through all possible configs and look for one that works
      dloop : for d in QPLL_OUT_DIV_VALIDS_C'range loop
         mloop : for m in QPLL_REFCLK_DIV_VALIDS_C'range loop
            nloop : for n in QPLL_FBDIV_INT_VALIDS_C'range loop
               
               pllClk := refClkFreq * real(QPLL_FBDIV_INT_VALIDS_C(n)) /
                         (2.0 * real(QPLL_REFCLK_DIV_VALIDS_C(m)));
               rate := pllClk * 2.0 / real(QPLL_OUT_DIV_VALIDS_C(d));

               if (((pllClk > QPLL_LOWER_BAND_LOW_C and pllClk < QPLL_LOWER_BAND_HIGH_C) or
                    (pllClk > QPLL_UPPER_BAND_LOW_C and pllClk < QPLL_UPPER_BAND_HIGH_C))
                   and rate = lineRate) then

                  ret.QPLL_REFCLK_DIV_G  := QPLL_REFCLK_DIV_VALIDS_C(m);
                  ret.QPLL_FBDIV_G       := getQPllFbdiv(QPLL_FBDIV_INT_VALIDS_C(n));
                  ret.QPLL_FBDIV_RATIO_G := ite(QPLL_FBDIV_INT_VALIDS_C(n) = 66, 0, 1);
                  ret.OUT_DIV_G          := QPLL_OUT_DIV_VALIDS_C(d);
                  ret.CLK25_DIV_G        := integer(refClkFreq / 25.0E6);

                  found := true;

                  exit dloop;
               end if;
            end loop;
         end loop;
      end loop;

      assert (found) report "getGtx7QPllCfg: no feasible configuration found for refClkFreq: " &
         real'image(refClkFreq) & " and lineRate: " & real'image(lineRate) severity failure;
      return ret;

   end function;


end package body Gtx7CfgPkg;
