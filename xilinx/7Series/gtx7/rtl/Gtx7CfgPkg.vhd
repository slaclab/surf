-------------------------------------------------------------------------------
-- File       : Gtx7CfgPkg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-09-02
-- Last update: 2015-01-08
-------------------------------------------------------------------------------
-- Description: Provides useful functions for generating GTX7 configurations.
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

package Gtx7CfgPkg is

   constant GTX7CFG_0_C : sl := '0';
   constant GTX7CFG_1_C : sl := '1';

   -------------------------------------------------------------------------------------------------
   -- CPLL Config Types, Constants and Function declarations
   -------------------------------------------------------------------------------------------------
   type Gtx7CPllCfgType is record
      CPLL_REFCLK_DIV_G : integer;
      CPLL_FBDIV_G      : integer;
      CPLL_FBDIV_45_G   : integer;
      OUT_DIV_G         : integer;
      CLK25_DIV_G       : integer;
   end record Gtx7CPllCfgType;

   constant CPLL_REFCLK_DIV_VALIDS_C : IntegerArray := (1, 2);
   constant CPLL_FBDIV_VALIDS_C      : IntegerArray := (1, 2, 3, 4, 5);
   constant CPLL_FBDIV_45_VALIDS_C   : IntegerArray := (4, 5);
   constant CPLL_OUT_DIV_VALIDS_C    : IntegerArray := (1, 2, 4, 8);

   constant CPLL_LOW_C  : real := 1.6E9;
   constant CPLL_HIGH_C : real := 3.3E9;

   function getGtx7CPllCfg (refClkFreq : real; lineRate : real) return Gtx7CPllCfgType;

   -------------------------------------------------------------------------------------------------
   -- QPLL
   -------------------------------------------------------------------------------------------------
   type Gtx7QPllCfgType is record
      QPLL_CFG_G         : bit_vector(27 downto 0);
      QPLL_REFCLK_DIV_G  : integer;
      QPLL_FBDIV_RATIO_G : bit;
      QPLL_FBDIV_G       : bit_vector(9 downto 0);
      OUT_DIV_G          : integer;
      CLK25_DIV_G        : integer;
   end record Gtx7QPllCfgType;

   constant QPLL_CFG_VCO_UPPER_C : bit_vector := x"0680181";
   constant QPLL_CFG_VCO_LOWER_C : bit_vector := x"06801C1";

   constant QPLL_REFCLK_DIV_VALIDS_C : IntegerArray := (1, 2, 3, 4);
   constant QPLL_FBDIV_INT_VALIDS_C  : IntegerArray := (16, 20, 32, 40, 64, 66, 80, 100);
   constant QPLL_OUT_DIV_VALIDS_C    : IntegerArray := (1, 2, 4, 8, 16);

   constant QPLL_LOWER_BAND_LOW_C  : real := 5.93E9;
   constant QPLL_LOWER_BAND_HIGH_C : real := 8.0E9;
   constant QPLL_UPPER_BAND_LOW_C  : real := 9.8E9;
   constant QPLL_UPPER_BAND_HIGH_C : real := 12.5E9;

   function getQPllFbdiv (fbdivInt : integer) return bit_vector;

   function getGtx7QPllCfg (refClkFreq : real; lineRate : real) return Gtx7QPllCfgType;

   -------------------------------------------------------------------------------------------------
   -- GT config
   -------------------------------------------------------------------------------------------------
   type Gtx7CfgType is record
      CPLL_REFCLK_DIV_G : integer;
      CPLL_FBDIV_G      : integer;
      CPLL_FBDIV_45_G   : integer;
      RXOUT_DIV_G       : integer;
      TXOUT_DIV_G       : integer;
      RX_CLK25_DIV_G    : integer;
      TX_CLK25_DIV_G    : integer;
   end record Gtx7CfgType;

   function getGtx7Cfg (
      txPll   : string;
      rxPll   : string;
      cPllCfg : Gtx7CPllCfgType;
      qPllCfg : Gtx7QPllCfgType)
      return Gtx7CfgType;

end package Gtx7CfgPkg;

package body Gtx7CfgPkg is

   -------------------------------------------------------------------------------------------------
   -- CPLL Config
   -------------------------------------------------------------------------------------------------
   function getGtx7CPllCfg (
      refClkFreq : real;
      lineRate   : real)
      return Gtx7CPllCfgType
   is
      variable pllClk : real;
      variable rate   : real;
      variable found  : boolean;
      variable ret    : Gtx7CPllCfgType;
   begin
      found              := false;
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

                     found                 := true;

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
   function getQPllFbdiv (fbdivInt : integer) return bit_vector is
      variable ret : bit_vector(9 downto 0) := (others => '0');
   begin
      case (fbdivInt) is
         when 16        => ret := "0000100000";
         when 20        => ret := "0000110000";
         when 32        => ret := "0001100000";
         when 40        => ret := "0010000000";
         when 64        => ret := "0011100000";
         when 66        => ret := "0101000000";
         when 80        => ret := "0100100000";
         when 100       => ret := "0101110000";
         when others    => ret := "0000000000"; --Added others ulegat
      end case;
      return ret;
   end function getQPllFbdiv;

   function getGtx7QPllCfg (
      refClkFreq : real;
      lineRate   : real)
      return Gtx7QPllCfgType
   is
      variable ret    : Gtx7QPllCfgType;
      variable vcoClk : real;
      variable pllClk : real;
      variable rate   : real;
      variable found  : boolean;
   begin
      found              := false;
      -- Walk through all possible configs and look for one that works
      dloop : for d in QPLL_OUT_DIV_VALIDS_C'range loop
         mloop : for m in QPLL_REFCLK_DIV_VALIDS_C'range loop
            nloop : for n in QPLL_FBDIV_INT_VALIDS_C'range loop
               
               vcoClk := refClkFreq * real(QPLL_FBDIV_INT_VALIDS_C(n)) /
                         (real(QPLL_REFCLK_DIV_VALIDS_C(m)));
               pllClk := vcoClk / 2.0;
               rate   := pllClk * 2.0 / real(QPLL_OUT_DIV_VALIDS_C(d));

--               report
--                  "--------" & lf &
--                  "M: " & integer'image(QPLL_REFCLK_DIV_VALIDS_C(m)) & lf &
--                  "N: " & integer'image(QPLL_FBDIV_INT_VALIDS_C(n)) & lf &
--                  "D: " & integer'image(QPLL_OUT_DIV_VALIDS_C(d)) & lf &
--                  "vcoClk: " & real'image(vcoClk) & lf &
--                  "pllClk: " & real'image(pllClk) & lf &
--                  "rate: " &   real'image(rate) & lf                  
--                  severity note;

               if ( rate = lineRate) then
                  if (vcoClk >= QPLL_LOWER_BAND_LOW_C and vcoClk <= QPLL_LOWER_BAND_HIGH_C) then
                     ret.QPLL_CFG_G := QPLL_CFG_VCO_LOWER_C;
                     found := true;
                  elsif (vcoClk >= QPLL_UPPER_BAND_LOW_C and vcoClk <= QPLL_UPPER_BAND_HIGH_C) then
                     ret.QPLL_CFG_G := QPLL_CFG_VCO_UPPER_C;
                     found := true;
                  end if;
                   
                  if (found) then
                     ret.QPLL_REFCLK_DIV_G := QPLL_REFCLK_DIV_VALIDS_C(m);
                     ret.QPLL_FBDIV_G      := getQPllFbdiv(QPLL_FBDIV_INT_VALIDS_C(n));
                     if (QPLL_FBDIV_INT_VALIDS_C(n) = 66) then
                        ret.QPLL_FBDIV_RATIO_G := '0';
                     else
                        ret.QPLL_FBDIV_RATIO_G := '1';
                     end if;
                     ret.OUT_DIV_G   := QPLL_OUT_DIV_VALIDS_C(d);
                     ret.CLK25_DIV_G := integer(refClkFreq / 25.0E6);
--                     report "FOUND!!!" severity note;
                     exit dloop;
                  end if;
               end if;
            end loop;
         end loop;
      end loop;

      assert (found) report "getGtx7QPllCfg: no feasible configuration found for refClkFreq: " &
         real'image(refClkFreq) & " and lineRate: " & real'image(lineRate) severity failure;
      return ret;

   end function;

   -------------------------------------------------------------------------------------------------
   -- GT Config
   -------------------------------------------------------------------------------------------------
   function getGtx7Cfg (
      txPll   : string;
      rxPll   : string;
      cPllCfg : Gtx7CPllCfgType;
      qPllCfg : Gtx7QPllCfgType)
      return Gtx7CfgType is
      variable ret : Gtx7CfgType;
   begin
      ret.CPLL_REFCLK_DIV_G := cPllCfg.CPLL_REFCLK_DIV_G;
      ret.CPLL_FBDIV_G      := cPllCfg.CPLL_FBDIV_G;
      ret.CPLL_FBDIV_45_G   := cPllCfg.CPLL_FBDIV_45_G;

      if (txPll = "CPLL") then
         ret.TXOUT_DIV_G    := cPllCfg.OUT_DIV_G;
         ret.TX_CLK25_DIV_G := cPllCfg.CLK25_DIV_G;
      elsif (txPll = "QPLL") then
         ret.TXOUT_DIV_G    := qPllCfg.OUT_DIV_G;
         ret.TX_CLK25_DIV_G := qPllCfg.CLK25_DIV_G;
      else
         assert (false) report "Gtx7CfgPkg: getGtx7Cfg: Illegal TX PLL type: " & txPll severity failure;
      end if;

      if (rxPll = "CPLL") then
         ret.RXOUT_DIV_G    := cPllCfg.OUT_DIV_G;
         ret.RX_CLK25_DIV_G := cPllCfg.CLK25_DIV_G;
      elsif (rxPll = "QPLL") then
         ret.RXOUT_DIV_G    := qPllCfg.OUT_DIV_G;
         ret.RX_CLK25_DIV_G := qPllCfg.CLK25_DIV_G;
      else
         assert (false) report "Gtx7CfgPkg: getGtx7Cfg: Illegal RX PLL type: " & rxPll severity failure;
      end if;

      return ret;
   end function getGtx7Cfg;


end package body Gtx7CfgPkg;
