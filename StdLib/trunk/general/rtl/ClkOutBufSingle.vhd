-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : ClkOutBufSingle.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-12-07
-- Last update: 2013-06-24
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Special buffer for outputting a clock on Xilinx FPGA pins.
-------------------------------------------------------------------------------
-- Copyright (c) 2012 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use work.StdRtlPkg.all;

library UNISIM;
use UNISIM.VCOMPONENTS.all;

entity ClkOutBufSingle is
   generic (
      INVERT_G : boolean := false);
   port (
      clkIn  : in  sl;
      clkOut : out sl);                 -- Single ended output buffer
end ClkOutBufSingle;

architecture rtl of ClkOutBufSingle is

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

   -- Single ended output buffer
   OBUF_I : OBUF
      port map (
         I => clkDdr,
         O => clkOut);

end rtl;
