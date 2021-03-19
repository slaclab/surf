-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper for SelectioDeser
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;

library unisim;
use unisim.vcomponents.all;

entity SelectioDeserLane7Series is
   generic (
      TPD_G           : time   := 1 ns;
      IODELAY_GROUP_G : string := "DESER_GROUP";
      REF_FREQ_G      : real   := 300.0);  -- IDELAYCTRL's REFCLK (in units of Hz)
   port (
      -- SELECTIO Ports
      rxP     : in  sl;
      rxN     : in  sl;
      -- Clock and Reset Interface
      clkx4   : in  sl;
      clkx1   : in  sl;
      rstx1   : in  sl;
      -- Delay Configuration
      dlyLoad : in  sl;
      dlyCfg  : in  slv(8 downto 0);
      -- Output
      dataOut : out slv(7 downto 0));
end SelectioDeserLane7Series;

architecture mapping of SelectioDeserLane7Series is

   signal rx     : sl;
   signal rxDly  : sl;
   signal clkx4L : sl;

   attribute IODELAY_GROUP            : string;
   attribute IODELAY_GROUP of U_DELAY : label is IODELAY_GROUP_G;

begin

   U_IBUFDS : IBUFDS
      port map (
         I  => rxP,
         IB => rxN,
         O  => rx);

   U_DELAY : IDELAYE2
      generic map (
         REFCLK_FREQUENCY      => REF_FREQ_G,
         HIGH_PERFORMANCE_MODE => "TRUE",
         IDELAY_VALUE          => 0,
         DELAY_SRC             => "IDATAIN",
         IDELAY_TYPE           => "VAR_LOAD")
      port map(
         DATAIN     => '0',
         IDATAIN    => rx,
         DATAOUT    => rxDly,
         C          => clkx1,
         CE         => '0',
         INC        => '0',
         LD         => dlyLoad,
         LDPIPEEN   => '0',
         REGRST     => '0',
         CINVCTRL   => '0',
         CNTVALUEIN => dlyCfg(8 downto 4));

   U_ISERDES : ISERDESE2
      generic map (
         DATA_WIDTH     => 8,
         DATA_RATE      => "DDR",
         IOBDELAY       => "IFD",
         DYN_CLK_INV_EN => "FALSE",
         INTERFACE_TYPE => "NETWORKING")
      port map (
         D            => '0',
         DDLY         => rxDly,
         CE1          => '1',
         CE2          => '1',
         CLK          => clkx4,
         CLKB         => clkx4L,
         RST          => rstx1,
         CLKDIV       => clkx1,
         CLKDIVP      => '0',
         OCLK         => '0',
         OCLKB        => '0',
         DYNCLKSEL    => '0',
         DYNCLKDIVSEL => '0',
         SHIFTIN1     => '0',
         SHIFTIN2     => '0',
         BITSLIP      => '0',
         O            => open,
         Q8           => dataOut(0),
         Q7           => dataOut(1),
         Q6           => dataOut(2),
         Q5           => dataOut(3),
         Q4           => dataOut(4),
         Q3           => dataOut(5),
         Q2           => dataOut(6),
         Q1           => dataOut(7),
         OFB          => '0',
         SHIFTOUT1    => open,
         SHIFTOUT2    => open);

   clkx4L <= not(clkx4);

end mapping;
