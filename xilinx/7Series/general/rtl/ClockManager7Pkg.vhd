-------------------------------------------------------------------------------
-- File       : ClockManager7.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-10-28
-- Last update: 2014-10-29
-------------------------------------------------------------------------------
-- Description: A wrapper over MMCM/PLL to avoid coregen use.
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.math_real.all;

library unisim;
use unisim.vcomponents.all;

use work.StdRtlPkg.all;

package ClockManager7Pkg is
   type ClockManager7CfgType is record
      CLKIN_PERIOD_G         : real;
      DIVCLK_DIVIDE_G        : integer range 1 to 106;
      CLKFBOUT_MULT_F_G      : real range 1.0 to 64.0;
      CLKFBOUT_MULT_G        : integer range 2 to 64;
      CLKOUT0_DIVIDE_F_G     : real range 1.0 to 128.0;
      CLKOUT0_DIVIDE_G       : integer range 1 to 128;
      CLKOUT1_DIVIDE_G       : integer range 1 to 128;
      CLKOUT2_DIVIDE_G       : integer range 1 to 128;
      CLKOUT3_DIVIDE_G       : integer range 1 to 128;
      CLKOUT4_DIVIDE_G       : integer range 1 to 128;
      CLKOUT5_DIVIDE_G       : integer range 1 to 128;
      CLKOUT6_DIVIDE_G       : integer range 1 to 128;
      CLKOUT0_PHASE_G        : real range -360.0 to 360.0;
      CLKOUT1_PHASE_G        : real range -360.0 to 360.0;
      CLKOUT2_PHASE_G        : real range -360.0 to 360.0;
      CLKOUT3_PHASE_G        : real range -360.0 to 360.0;
      CLKOUT4_PHASE_G        : real range -360.0 to 360.0;
      CLKOUT5_PHASE_G        : real range -360.0 to 360.0;
      CLKOUT6_PHASE_G        : real range -360.0 to 360.0;
      CLKOUT0_DUTY_CYCLE_G   : real range 0.01 to 0.99;
      CLKOUT1_DUTY_CYCLE_G   : real range 0.01 to 0.99;
      CLKOUT2_DUTY_CYCLE_G   : real range 0.01 to 0.99;
      CLKOUT3_DUTY_CYCLE_G   : real range 0.01 to 0.99;
      CLKOUT4_DUTY_CYCLE_G   : real range 0.01 to 0.99;
      CLKOUT5_DUTY_CYCLE_G   : real range 0.01 to 0.99;
      CLKOUT6_DUTY_CYCLE_G   : real range 0.01 to 0.99;
      CLKOUT0_RST_HOLD_G     : integer range 3 to positive'high;
      CLKOUT1_RST_HOLD_G     : integer range 3 to positive'high;
      CLKOUT2_RST_HOLD_G     : integer range 3 to positive'high;
      CLKOUT3_RST_HOLD_G     : integer range 3 to positive'high;
      CLKOUT4_RST_HOLD_G     : integer range 3 to positive'high;
      CLKOUT5_RST_HOLD_G     : integer range 3 to positive'high;
      CLKOUT6_RST_HOLD_G     : integer range 3 to positive'high;
      CLKOUT0_RST_POLARITY_G : sl;
      CLKOUT1_RST_POLARITY_G : sl;
      CLKOUT2_RST_POLARITY_G : sl;
      CLKOUT3_RST_POLARITY_G : sl;
      CLKOUT4_RST_POLARITY_G : sl;
      CLKOUT5_RST_POLARITY_G : sl;
      CLKOUT6_RST_POLARITY_G : sl;
   end record;

   type ClockManager7CfgArray is array (natural range <>) of ClockManager7CfgType;

   function makeClockManager7Cfg (
      CLKIN_PERIOD_G         : real                             := 10.0;  -- Input period in ns );
      DIVCLK_DIVIDE_G        : integer range 1 to 106           := 1;
      CLKFBOUT_MULT_F_G      : real range 1.0 to 64.0           := 1.0;
      CLKFBOUT_MULT_G        : integer range 2 to 64            := 5;
      CLKOUT0_DIVIDE_F_G     : real range 1.0 to 128.0          := 1.0;
      CLKOUT0_DIVIDE_G       : integer range 1 to 128           := 1;
      CLKOUT1_DIVIDE_G       : integer range 1 to 128           := 1;
      CLKOUT2_DIVIDE_G       : integer range 1 to 128           := 1;
      CLKOUT3_DIVIDE_G       : integer range 1 to 128           := 1;
      CLKOUT4_DIVIDE_G       : integer range 1 to 128           := 1;
      CLKOUT5_DIVIDE_G       : integer range 1 to 128           := 1;
      CLKOUT6_DIVIDE_G       : integer range 1 to 128           := 1;
      CLKOUT0_PHASE_G        : real range -360.0 to 360.0       := 0.0;
      CLKOUT1_PHASE_G        : real range -360.0 to 360.0       := 0.0;
      CLKOUT2_PHASE_G        : real range -360.0 to 360.0       := 0.0;
      CLKOUT3_PHASE_G        : real range -360.0 to 360.0       := 0.0;
      CLKOUT4_PHASE_G        : real range -360.0 to 360.0       := 0.0;
      CLKOUT5_PHASE_G        : real range -360.0 to 360.0       := 0.0;
      CLKOUT6_PHASE_G        : real range -360.0 to 360.0       := 0.0;
      CLKOUT0_DUTY_CYCLE_G   : real range 0.01 to 0.99          := 0.5;
      CLKOUT1_DUTY_CYCLE_G   : real range 0.01 to 0.99          := 0.5;
      CLKOUT2_DUTY_CYCLE_G   : real range 0.01 to 0.99          := 0.5;
      CLKOUT3_DUTY_CYCLE_G   : real range 0.01 to 0.99          := 0.5;
      CLKOUT4_DUTY_CYCLE_G   : real range 0.01 to 0.99          := 0.5;
      CLKOUT5_DUTY_CYCLE_G   : real range 0.01 to 0.99          := 0.5;
      CLKOUT6_DUTY_CYCLE_G   : real range 0.01 to 0.99          := 0.5;
      CLKOUT0_RST_HOLD_G     : integer range 3 to positive'high := 3;
      CLKOUT1_RST_HOLD_G     : integer range 3 to positive'high := 3;
      CLKOUT2_RST_HOLD_G     : integer range 3 to positive'high := 3;
      CLKOUT3_RST_HOLD_G     : integer range 3 to positive'high := 3;
      CLKOUT4_RST_HOLD_G     : integer range 3 to positive'high := 3;
      CLKOUT5_RST_HOLD_G     : integer range 3 to positive'high := 3;
      CLKOUT6_RST_HOLD_G     : integer range 3 to positive'high := 3;
      CLKOUT0_RST_POLARITY_G : sl                               := '1';
      CLKOUT1_RST_POLARITY_G : sl                               := '1';
      CLKOUT2_RST_POLARITY_G : sl                               := '1';
      CLKOUT3_RST_POLARITY_G : sl                               := '1';
      CLKOUT4_RST_POLARITY_G : sl                               := '1';
      CLKOUT5_RST_POLARITY_G : sl                               := '1';
      CLKOUT6_RST_POLARITY_G : sl                               := '1')
   return ClockManager7CfgType;

--   
--      DIVCLK_DIVIDE_G    : integer range 1 to 106;
--      CLKFBOUT_MULT_F_G  : real range 1.0 to 64.0;
--      CLKFBOUT_MULT_G    : integer range 2 to 64;
--      CLKOUT0_DIVIDE_F_G : real range 1.0 to 128.0;
--      CLKOUT0_DIVIDE_G   : integer range 1 to 128;
--      CLKOUT1_DIVIDE_G   : integer range 1 to 128;
--      CLKOUT2_DIVIDE_G   : integer range 1 to 128;
--      CLKOUT3_DIVIDE_G   : integer range 1 to 128;
--      CLKOUT4_DIVIDE_G   : integer range 1 to 128;
--      CLKOUT5_DIVIDE_G   : integer range 1 to 128;
--      CLKOUT6_DIVIDE_G   : integer range 1 to 128;
--   end record ClockManager7CfgType;

   function ite (i : boolean; t : ClockManager7CfgType; e : ClockManager7CfgType) return ClockManager7CfgType;
   
end package ClockManager7Pkg;

package body ClockManager7Pkg is

   function makeClockManager7Cfg (
      CLKIN_PERIOD_G         : real                             := 10.0;
      DIVCLK_DIVIDE_G        : integer range 1 to 106           := 1;
      CLKFBOUT_MULT_F_G      : real range 1.0 to 64.0           := 1.0;
      CLKFBOUT_MULT_G        : integer range 2 to 64            := 5;
      CLKOUT0_DIVIDE_F_G     : real range 1.0 to 128.0          := 1.0;
      CLKOUT0_DIVIDE_G       : integer range 1 to 128           := 1;
      CLKOUT1_DIVIDE_G       : integer range 1 to 128           := 1;
      CLKOUT2_DIVIDE_G       : integer range 1 to 128           := 1;
      CLKOUT3_DIVIDE_G       : integer range 1 to 128           := 1;
      CLKOUT4_DIVIDE_G       : integer range 1 to 128           := 1;
      CLKOUT5_DIVIDE_G       : integer range 1 to 128           := 1;
      CLKOUT6_DIVIDE_G       : integer range 1 to 128           := 1;
      CLKOUT0_PHASE_G        : real range -360.0 to 360.0       := 0.0;
      CLKOUT1_PHASE_G        : real range -360.0 to 360.0       := 0.0;
      CLKOUT2_PHASE_G        : real range -360.0 to 360.0       := 0.0;
      CLKOUT3_PHASE_G        : real range -360.0 to 360.0       := 0.0;
      CLKOUT4_PHASE_G        : real range -360.0 to 360.0       := 0.0;
      CLKOUT5_PHASE_G        : real range -360.0 to 360.0       := 0.0;
      CLKOUT6_PHASE_G        : real range -360.0 to 360.0       := 0.0;
      CLKOUT0_DUTY_CYCLE_G   : real range 0.01 to 0.99          := 0.5;
      CLKOUT1_DUTY_CYCLE_G   : real range 0.01 to 0.99          := 0.5;
      CLKOUT2_DUTY_CYCLE_G   : real range 0.01 to 0.99          := 0.5;
      CLKOUT3_DUTY_CYCLE_G   : real range 0.01 to 0.99          := 0.5;
      CLKOUT4_DUTY_CYCLE_G   : real range 0.01 to 0.99          := 0.5;
      CLKOUT5_DUTY_CYCLE_G   : real range 0.01 to 0.99          := 0.5;
      CLKOUT6_DUTY_CYCLE_G   : real range 0.01 to 0.99          := 0.5;
      CLKOUT0_RST_HOLD_G     : integer range 3 to positive'high := 3;
      CLKOUT1_RST_HOLD_G     : integer range 3 to positive'high := 3;
      CLKOUT2_RST_HOLD_G     : integer range 3 to positive'high := 3;
      CLKOUT3_RST_HOLD_G     : integer range 3 to positive'high := 3;
      CLKOUT4_RST_HOLD_G     : integer range 3 to positive'high := 3;
      CLKOUT5_RST_HOLD_G     : integer range 3 to positive'high := 3;
      CLKOUT6_RST_HOLD_G     : integer range 3 to positive'high := 3;
      CLKOUT0_RST_POLARITY_G : sl                               := '1';
      CLKOUT1_RST_POLARITY_G : sl                               := '1';
      CLKOUT2_RST_POLARITY_G : sl                               := '1';
      CLKOUT3_RST_POLARITY_G : sl                               := '1';
      CLKOUT4_RST_POLARITY_G : sl                               := '1';
      CLKOUT5_RST_POLARITY_G : sl                               := '1';
      CLKOUT6_RST_POLARITY_G : sl                               := '1')
      return ClockManager7CfgType
   is
      variable ret : ClockManager7CfgType;
   begin
      ret.CLKIN_PERIOD_G         := CLKIN_PERIOD_G;
      ret.DIVCLK_DIVIDE_G        := DIVCLK_DIVIDE_G;
      ret.CLKFBOUT_MULT_F_G      := CLKFBOUT_MULT_F_G;
      ret.CLKFBOUT_MULT_G        := CLKFBOUT_MULT_G;
      ret.CLKOUT0_DIVIDE_F_G     := CLKOUT0_DIVIDE_F_G;
      ret.CLKOUT0_DIVIDE_G       := CLKOUT0_DIVIDE_G;
      ret.CLKOUT1_DIVIDE_G       := CLKOUT1_DIVIDE_G;
      ret.CLKOUT2_DIVIDE_G       := CLKOUT2_DIVIDE_G;
      ret.CLKOUT3_DIVIDE_G       := CLKOUT3_DIVIDE_G;
      ret.CLKOUT4_DIVIDE_G       := CLKOUT4_DIVIDE_G;
      ret.CLKOUT5_DIVIDE_G       := CLKOUT5_DIVIDE_G;
      ret.CLKOUT6_DIVIDE_G       := CLKOUT6_DIVIDE_G;
      ret.CLKOUT0_PHASE_G        := CLKOUT0_PHASE_G;
      ret.CLKOUT1_PHASE_G        := CLKOUT1_PHASE_G;
      ret.CLKOUT2_PHASE_G        := CLKOUT2_PHASE_G;
      ret.CLKOUT3_PHASE_G        := CLKOUT3_PHASE_G;
      ret.CLKOUT4_PHASE_G        := CLKOUT4_PHASE_G;
      ret.CLKOUT5_PHASE_G        := CLKOUT5_PHASE_G;
      ret.CLKOUT6_PHASE_G        := CLKOUT6_PHASE_G;
      ret.CLKOUT0_DUTY_CYCLE_G   := CLKOUT0_DUTY_CYCLE_G;
      ret.CLKOUT1_DUTY_CYCLE_G   := CLKOUT1_DUTY_CYCLE_G;
      ret.CLKOUT2_DUTY_CYCLE_G   := CLKOUT2_DUTY_CYCLE_G;
      ret.CLKOUT3_DUTY_CYCLE_G   := CLKOUT3_DUTY_CYCLE_G;
      ret.CLKOUT4_DUTY_CYCLE_G   := CLKOUT4_DUTY_CYCLE_G;
      ret.CLKOUT5_DUTY_CYCLE_G   := CLKOUT5_DUTY_CYCLE_G;
      ret.CLKOUT6_DUTY_CYCLE_G   := CLKOUT6_DUTY_CYCLE_G;
      ret.CLKOUT0_RST_HOLD_G     := CLKOUT0_RST_HOLD_G;
      ret.CLKOUT1_RST_HOLD_G     := CLKOUT1_RST_HOLD_G;
      ret.CLKOUT2_RST_HOLD_G     := CLKOUT2_RST_HOLD_G;
      ret.CLKOUT3_RST_HOLD_G     := CLKOUT3_RST_HOLD_G;
      ret.CLKOUT4_RST_HOLD_G     := CLKOUT4_RST_HOLD_G;
      ret.CLKOUT5_RST_HOLD_G     := CLKOUT5_RST_HOLD_G;
      ret.CLKOUT6_RST_HOLD_G     := CLKOUT6_RST_HOLD_G;
      ret.CLKOUT0_RST_POLARITY_G := CLKOUT0_RST_POLARITY_G;
      ret.CLKOUT1_RST_POLARITY_G := CLKOUT1_RST_POLARITY_G;
      ret.CLKOUT2_RST_POLARITY_G := CLKOUT2_RST_POLARITY_G;
      ret.CLKOUT3_RST_POLARITY_G := CLKOUT3_RST_POLARITY_G;
      ret.CLKOUT4_RST_POLARITY_G := CLKOUT4_RST_POLARITY_G;
      ret.CLKOUT5_RST_POLARITY_G := CLKOUT5_RST_POLARITY_G;
      ret.CLKOUT6_RST_POLARITY_G := CLKOUT6_RST_POLARITY_G;
      return ret;
   end function makeClockManager7Cfg;

   function ite (i : boolean; t : ClockManager7CfgType; e : ClockManager7CfgType) return ClockManager7CfgType is
   begin
      if (i) then return t; else return e; end if;
   end function ite;

end package body ClockManager7Pkg;
