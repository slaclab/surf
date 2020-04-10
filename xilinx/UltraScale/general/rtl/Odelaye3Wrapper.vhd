-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper on ODELAYE3 that patches the silicon's issue of increments > 8
-- https://forums.xilinx.com/t5/Versal-and-UltraScale/IDELAY-ODELAY-Usage/td-p/812362
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
      BUSY        : out sl;  -- 1-bit output: Patch module is busy
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

   signal currentCntValue : slv(8 downto 0);
   signal patchCntValue   : slv(8 downto 0);
   signal patchLoad       : sl;

begin

   CNTVALUEOUT <= currentCntValue;

   U_patch : entity surf.Delaye3PatchFsm
      generic map (
         TPD_G           => TPD_G,
         DELAY_TYPE      => DELAY_TYPE,
         DELAY_VALUE     => DELAY_VALUE,
         IS_CLK_INVERTED => IS_CLK_INVERTED,
         IS_RST_INVERTED => IS_RST_INVERTED)
      port map (
         -- Inputs
         CLK           => CLK,
         RST           => RST,
         LOAD          => LOAD,
         CNTVALUEIN    => CNTVALUEIN,
         CNTVALUEOUT   => currentCntValue,
         -- Outputs
         patchLoad     => patchLoad,
         patchCntValue => patchCntValue,
         busy          => BUSY);

   U_ODELAYE3 : ODELAYE3
      generic map (
         CASCADE          => CASCADE,
         DELAY_FORMAT     => DELAY_FORMAT,
         DELAY_TYPE       => DELAY_TYPE,
         DELAY_VALUE      => DELAY_VALUE,
         IS_CLK_INVERTED  => IS_CLK_INVERTED,
         IS_RST_INVERTED  => IS_RST_INVERTED,
         REFCLK_FREQUENCY => REFCLK_FREQUENCY,
         SIM_DEVICE       => SIM_DEVICE,
         UPDATE_MODE      => UPDATE_MODE)
      port map (
         CASC_OUT    => CASC_OUT,
         CNTVALUEOUT => currentCntValue,
         DATAOUT     => DATAOUT,
         CASC_IN     => CASC_IN,
         CASC_RETURN => CASC_RETURN,
         CE          => CE,
         CLK         => CLK,
         CNTVALUEIN  => patchCntValue,
         EN_VTC      => EN_VTC,
         INC         => INC,
         LOAD        => patchLoad,
         ODATAIN     => ODATAIN,
         RST         => RST);

end rtl;
