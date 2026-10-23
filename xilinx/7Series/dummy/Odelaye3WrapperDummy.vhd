-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Dummy component to prevent simulations from breaking in 7-series
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


library surf;
use surf.StdRtlPkg.all;

library unisim;
use unisim.vcomponents.all;

entity Odelaye3Wrapper is
   generic (
      TPD_G            : time    := 1 ns;
      CASCADE          : string  := "NONE";  -- Cascade setting (MASTER, NONE, SLAVE_END, SLAVE_MIDDLE)
      DELAY_FORMAT     : string  := "TIME";  -- (COUNT, TIME)
      DELAY_TYPE       : string  := "FIXED";  -- Set the type of tap delay line (FIXED, VARIABLE, VAR_LOAD)
      DELAY_VALUE      : integer := 0;  -- Output delay tap setting
      IS_CLK_INVERTED  : bit     := '0';  -- Optional inversion for CLK
      IS_RST_INVERTED  : bit     := '0';  -- Optional inversion for RST
      REFCLK_FREQUENCY : real    := 300.0;  -- IDELAYCTRL clock input frequency in MHz (200.0-2667.0).
      SIM_DEVICE       : string  := "ULTRASCALE";  -- Set the device version (ULTRASCALE, ULTRASCALE_PLUS)
      UPDATE_MODE      : string  := "ASYNC");  -- Determines when updates to the delay will take effect (ASYNC, MANUAL, SYNC)
   port (
      BUSY        : out sl;             -- 1-bit output: Patch module is busy
      CASC_OUT    : out sl;  -- 1-bit output: Cascade delay output to IDELAY input cascade
      CNTVALUEOUT : out slv(8 downto 0);  -- 9-bit output: Counter value output
      DATAOUT     : out sl;  -- 1-bit output: Delayed data from ODATAIN input port
      CASC_IN     : in  sl;  -- 1-bit input: Cascade delay input from slave IDELAY CASCADE_OUT
      CASC_RETURN : in  sl;  -- 1-bit input: Cascade delay returning from slave IDELAY DATAOUT
      CE          : in  sl;  -- 1-bit input: Active high enable increment/decrement input
      CLK         : in  sl;             -- 1-bit input: Clock input
      CNTVALUEIN  : in  slv(8 downto 0);  -- 9-bit input: Counter value input
      EN_VTC      : in  sl;  -- 1-bit input: Keep delay constant over VT
      INC         : in  sl;  -- 1-bit input: Increment/Decrement tap delay input
      LOAD        : in  sl;             -- 1-bit input: Load DELAY_VALUE input
      ODATAIN     : in  sl;             -- 1-bit input: Data input
      RST         : in  sl);  -- 1-bit input: Asynchronous Reset to the DELAY_VALUE
end Odelaye3Wrapper;

architecture rtl of Odelaye3Wrapper is

begin

   assert (false)
      report "surf.xilinx: Odelaye3Wrapper not supported in 7-series" severity failure;

end rtl;
