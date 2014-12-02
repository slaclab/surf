-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : ClkOutBuf.vhd
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

entity ClkOutBufDiff is
   generic (
      RST_POLARITY_G : sl      := '1';
      INVERT_G       : boolean := false);
   port (
      rstIn   : in  sl := not RST_POLARITY_G;-- Optional reset
      clkIn   : in  sl;
      clkOutP : out sl;                 -- differential output buffer
      clkOutN : out sl);                -- differential output buffer
end ClkOutBufDiff;

architecture rtl of ClkOutBufDiff is

   signal clkDdr : sl;
   signal rst    : sl;

begin

   rst <= rstIn when(RST_POLARITY_G='1') else not(rstIn);

   ODDR_I : ODDR
      port map (
         C  => clkIn,
         Q  => clkDdr,
         CE => '1',
         D1 => toSl(not INVERT_G),
         D2 => toSl(INVERT_G),
         R  => rst,
         S  => '0');

   OBUFDS_I : OBUFDS
      port map (
         I  => clkDdr,
         O  => clkOutP,
         OB => clkOutN);

end rtl;
