-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : ClockDivider.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-09-07
-- Last update: 2014-09-07
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
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

library unisim;
use unisim.vcomponents.all;

entity ClockDivider is
   generic (
      BUFR_DIVIDE_G : string := "BYPASS";    -- Values: "BYPASS, 1, 2, 3, 4, 5, 6, 7, 8"
      SIM_DEVICE_G  : string := "7SERIES");  -- Must be set to "7SERIES"
   port (
      clkIn  : in  sl;
      ce     : in  sl := '1';
      clr    : in  sl := '0';
      clkOut : out sl);            
end ClockDivider;

architecture mapping of ClockDivider is
   
   signal divClk : sl;
   
begin

   BUFR_Inst : BUFR
      generic map (
         BUFR_DIVIDE => BUFR_DIVIDE_G,
         SIM_DEVICE  => SIM_DEVICE_G)
      port map (
         I   => clkIn,                  -- 1-bit input: Clock buffer input 
         CE  => ce,                     -- 1-bit input: Active high, clock enable input
         CLR => clr,                    -- 1-bit input: ACtive high reset input
         O   => divClk);                -- 1-bit output: Clock output port

   BUFG_Inst : BUFG
      port map (
         I => divClk,
         O => clkOut);    

end mapping;
