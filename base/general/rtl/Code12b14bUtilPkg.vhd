-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Code12b14bPkg.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-10-05
-- Last update: 2016-10-12
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of SURF. It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of SURF, including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.Code7b8bPkg.all;
use work.TextUtilPkg.all;

package Code12b14bUtilPkg is

   subtype DisparityType is integer range -4 to 4;
   subtype DisparityOutType is integer range -2 to 4;
   constant DISP_N4_S : integer := -4;
   constant DISP_N2_S : integer := -2;
   constant DISP_Z_S  : integer := 0;
   constant DISP_P2_S : integer := 2;
   constant DISP_P4_S : integer := 4;

   function getDisparity (vec : slv) return DisparityType;

   function toSlv (      d : DisparityOutType)      return slv;
   function toDisparityOutType (      d : slv(1 downto 0))      return DisparityOutType;

end package;

package body Code12b14bUtilPkg is

      -- Determine the disparity of a vector
   function getDisparity (vec : slv) return DisparityType is
      variable ones      : integer;
      variable zeros     : integer;
      variable disparity : DisparityType;
   begin
      zeros := 0;
      ones  := 0;
      for i in vec'range loop
         if (vec(i) = '0') then
            zeros := zeros + 1;
         end if;
      end loop;

      ones      := vec'length-zeros;
      disparity := ones-zeros;

      return disparity;
   end function getDisparity;

      function toSlv (      d : DisparityOutType)      return slv is
      variable ret : slv(1 downto 0) := "01";
   begin
      if (d = -2) then
         ret := "00";
      elsif (d = 0) then
         ret := "01";
      elsif (d = 2) then
         ret := "10";
      elsif (d = 4) then
         ret := "11";
      end if;
      return ret;
   end function;
      
   function toDisparityOutType (      d : slv(1 downto 0))      return DisparityOutType is
      variable ret : DisparityOutType := 2;
   begin
      if (d = "00") then
         return -2;
      elsif (d = "01") then
         return 0;
      elsif (d = "10") then
         return 2;
      elsif (d = "11") then
         return 4;
      end if;
      return 0;
   end function;


end package body Code12b14bUtilPkg;
