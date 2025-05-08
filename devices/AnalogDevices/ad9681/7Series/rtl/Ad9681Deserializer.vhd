-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: 14 bit DDR deserializer using 7 series IDELAYE2 and ISERDESE2.
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

library surf;
use surf.StdRtlPkg.all;

library unisim;
use unisim.vcomponents.all;

entity Ad9681Deserializer is
   generic (
      TPD_G             : time    := 1 ns;
      DEFAULT_DELAY_G   : natural := 0;
      IODELAY_GROUP_G   : string;
      IDELAYCTRL_FREQ_G : real    := 200.0);
   port (
      clkIo    : in sl;
      clkIoInv : in sl;
      clkR     : in sl;
      rst      : in sl;
      slip     : in sl;

      sysClk   : in  sl;
      curDelay : out slv(4 downto 0);
      setDelay : in  slv(4 downto 0);
      setValid : in  sl;

      iData : in  sl;
      oData : out slv(7 downto 0));
end entity Ad9681Deserializer;

architecture rtl of Ad9681Deserializer is

   signal dlyData : sl;

   attribute IODELAY_GROUP            : string;
   attribute IODELAY_GROUP of U_DELAY : label is IODELAY_GROUP_G;

begin

   -- ADC frame delay
   U_DELAY : IDELAYE2
      generic map (
         DELAY_SRC             => "IDATAIN",
         HIGH_PERFORMANCE_MODE => "TRUE",
         IDELAY_TYPE           => "VAR_LOAD",
         IDELAY_VALUE          => DEFAULT_DELAY_G,  -- Here
         REFCLK_FREQUENCY      => IDELAYCTRL_FREQ_G,
         SIGNAL_PATTERN        => "DATA")
      port map (
         C           => sysClk,
         REGRST      => '0',
         LD          => setValid,
         CE          => '0',
         INC         => '1',
         CINVCTRL    => '0',
         CNTVALUEIN  => setDelay,
         IDATAIN     => iData,
         DATAIN      => '0',
         LDPIPEEN    => '0',
         DATAOUT     => dlyData,
         CNTVALUEOUT => curDelay);

   U_ISERDES_MASTER : ISERDESE2
      generic map (
         DATA_RATE         => "DDR",
         DATA_WIDTH        => 8,
         INTERFACE_TYPE    => "NETWORKING",
         DYN_CLKDIV_INV_EN => "FALSE",
         DYN_CLK_INV_EN    => "FALSE",
         NUM_CE            => 1,
         OFB_USED          => "FALSE",
         IOBDELAY          => "IFD",  -- Use input at DDLY to output the data on Q1-Q6
         SERDES_MODE       => "MASTER")
      port map (
         Q1           => oData(0),
         Q2           => oData(1),
         Q3           => oData(2),
         Q4           => oData(3),
         Q5           => oData(4),
         Q6           => oData(5),
         Q7           => oData(6),
         Q8           => oData(7),
         SHIFTOUT1    => open,          -- Cascade connection to Slave ISERDES
         SHIFTOUT2    => open,          -- Cascade connection to Slave ISERDES
         BITSLIP      => slip,  -- 1-bit Invoke Bitslip. This can be used with any
         -- DATA_WIDTH, cascaded or not.
         CE1          => '1',           -- 1-bit Clock enable input
         CE2          => '1',           -- 1-bit Clock enable input
         CLK          => clkIo,  -- Fast Source Synchronous SERDES clock from BUFIO
         CLKB         => clkIoInv,      -- Locally inverted clock
         CLKDIV       => clkR,          -- Slow clock driven by BUFR
         CLKDIVP      => '0',
         D            => '0',
         DDLY         => dlyData,       -- 1-bit Input signal from IODELAYE1.
         RST          => rst,           -- 1-bit Asynchronous reset only.
         SHIFTIN1     => '0',
         SHIFTIN2     => '0',
         -- unused connections
         DYNCLKDIVSEL => '0',
         DYNCLKSEL    => '0',
         OFB          => '0',
         OCLK         => '0',
         OCLKB        => '0',
         O            => open);         -- unregistered output of ISERDESE1

end architecture rtl;
