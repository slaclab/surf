-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Mode for TCA9548A (8-channel I2C switch)
-------------------------------------------------------------------------------
-- Datasheet:  https://www.ti.com/lit/gpn/tca9548a
-------------------------------------------------------------------------------
-- This file is part of SLAC Firmware Standard Library. It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of SLAC Firmware Standard Library, including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library surf;
use surf.StdRtlPkg.all;
use surf.i2cPkg.all;

entity Tca9548a is

   generic (
      TPD_G  : time := 1 ns;
      ADDR_G : slv(6 downto 0));

   port (
      scl : inout sl;
      sda : inout sl;
      sc  : inout slv(7 downto 0);
      sd  : inout slv(7 downto 0));

end entity Tca9548a;

architecture sim of Tca9548a is

   signal clk : sl;
   signal rst : sl;

   signal i2ci : i2c_in_type;
   signal i2co : i2c_out_type;

   signal fanout_i2ci : i2c_in_array(7 downto 0);
   signal fanout_i2co : i2c_out_array(7 downto 0);

   signal wrData : slv(7 downto 0);

   signal iScIo : slv(7 downto 0);
   signal iScOi : slv(7 downto 0);

   signal iSdIo : slv(7 downto 0);
   signal iSdOi : slv(7 downto 0);


   constant I2C_ADDR_C : integer := conv_integer(ADDR_G);

begin

   U_ClkI2c : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => 8.0 ns,   -- 156.25 MHz
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 1000 ns)
      port map (
         clkP => clk,
         rst  => rst);


   U_I2cRegSlave_1 : entity surf.I2cRegSlave
      generic map (
         TPD_G                => TPD_G,
         TENBIT_G             => 0,
         I2C_ADDR_G           => I2C_ADDR_C,
         OUTPUT_EN_POLARITY_G => 0,
--         FILTER_G             => FILTER_G,
         ADDR_SIZE_G          => 0,
         DATA_SIZE_G          => 1,
         ENDIANNESS_G         => 0)
      port map (
         sRst   => rst,                 -- [in]
         clk    => clk,                 -- [in]
         wrEn   => open,                -- [out]
         wrData => wrData,              -- [out]
--         rdEn   => rdEn,                -- [out]
         rdData => wrData,              -- [in]
         i2ci   => i2ci,                -- [in]
         i2co   => i2co);               -- [out]

   sda      <= i2co.sda when i2co.sdaoen = '0' else 'Z';
   i2ci.sda <= sda;

   scl      <= i2co.scl when i2co.scloen = '0' else 'Z';
   i2ci.scl <= scl;

   back : for i in 7 downto 0 generate
      scl      <= iScIo(i) when wrData(i) = '1' else 'Z';
      iScOi(i) <= scl;

      sda      <= iSdIo(i) when wrData(i) = '1' else 'Z';
      iSdOi(i) <= sda;

      sc(i)    <= iScOi(i) when wrData(i) = '1' else 'Z';
      iScIo(i) <= sc(i);

      sd(i)    <= iSdOi(i) when wrData(i) = '1' else 'Z';
      iScIo(i) <= sd(i);

   end generate back;


end architecture sim;
