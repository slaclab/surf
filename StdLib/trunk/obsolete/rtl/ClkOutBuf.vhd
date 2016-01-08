-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : ClkOutBuf.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-12-07
-- Last update: 2013-05-14
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Special buffer for outputting a clock on Xilinx FPGA pins.
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
use work.StdRtlPkg.all;

library UNISIM;
use UNISIM.VCOMPONENTS.all;

entity ClkOutBuf is
  generic (
    INVERT_G   : boolean := false;
    DIFF_OUT_G : boolean := true);       
  port (
    clkIn   : in  sl;
    clkOutP : out sl;                   -- differential output buffer
    clkOutN : out sl;                   -- differential output buffer
    clkOut  : out sl);                  -- Single ended output buffer
end ClkOutBuf;

architecture rtl of ClkOutBuf is

  signal clkDdr : sl;

begin

  ODDR_I : ODDR
    port map (
      C  => clkIn,
      Q  => clkDdr,
      CE => '1',
      D1 => toSl(not INVERT_G),
      D2 => toSl(INVERT_G),
      R  => '0',
      S  => '0');

  DIFF_OUT_OPT : if (DIFF_OUT_G) generate
    OBUFDS_I : OBUFDS
      port map (
        I  => clkDdr,
        O  => clkOutP,
        OB => clkOutN);
    clkOut <= '0';
  end generate DIFF_OUT_OPT;
  SINGLE_OUT_OPT : if (not DIFF_OUT_G) generate
    -- Single ended output buffer
    OBUF_I : OBUF
      port map (
        I => clkDdr,
        O => clkOut);
    clkOutP <= '0';
    clkOutN <= '0';
  end generate SINGLE_OUT_OPT;
end rtl;
