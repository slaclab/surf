-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- ADC Readout Controller
-- Receives ADC Data from an AD9592 chip.
-- Designed specifically for Xilinx 7 series FPGAs
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

library UNISIM;
use UNISIM.vcomponents.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.Ad9249Pkg.all;

entity Ad9249Deserializer is
   generic (
      TPD_G             : time            := 1 ns;
      SIM_DEVICE_G      : string          := "ULTRASCALE";
      IODELAY_GROUP_G   : string          := "DEFAULT_GROUP";
      IDELAY_CASCADE_G  : boolean         := false;
      IDELAYCTRL_FREQ_G : real            := 300.0;
      DEFAULT_DELAY_G   : slv(8 downto 0) := (others => '0');
      ADC_INVERT_CH_G   : sl              := '0';
      BIT_REV_G         : sl              := '0');
   port (
      -- Serial Data from ADC
      dClk          : in  sl;                -- Data clock
      dRst          : in  sl;                -- Data reset
      dClkDiv4      : in  sl;
      dRstDiv4      : in  sl;
      sDataP        : in  sl;                -- Frame clock
      sDataN        : in  sl;
      -- Signal to control data gearboxes
      loadDelay     : in  sl;
      delay         : in  slv(8 downto 0) := "000000000";
      delayValueOut : out slv(8 downto 0);
      bitSlip       : in  sl;                -- dClkDiv4 domain
      adcData       : out slv(13 downto 0);  -- dClkDiv4 domain
      adcValid      : out sl                 -- dClkDiv4 domain
      );
end Ad9249Deserializer;

-- Define architecture
architecture rtl of Ad9249Deserializer is

   attribute keep : string;
   -------------------------------------------------------------------------------------------------
   -- ADC Readout Clocked Registers
   -------------------------------------------------------------------------------------------------

   constant CASCADE_C : string := ite(IDELAY_CASCADE_G, "MASTER", "NONE");


   -- Local signals
   signal sDataPadP : sl;
   signal sDataPadN : sl;
   signal sData_i   : sl;
   signal sData_d   : sl;

   -- idelay signals
   signal masterCntValue1 : slv(8 downto 0);
   signal masterCntValue2 : slv(8 downto 0);
   signal cascOut         : sl;
   signal cascRet         : sl;
   -- iserdes signal
   signal masterData      : slv(7 downto 0);
   signal iAdcData        : slv(13 downto 0);

   attribute keep of sData_i : signal is "true";

begin

   -------------------------------------------------------------------------------------------------
   -- Create Clocks
   -------------------------------------------------------------------------------------------------

   -- input sData buffer
   --
   U_IBUFDS_sData : IBUFDS_DIFF_OUT
      generic map (
         DQS_BIAS => "FALSE"            -- (FALSE, TRUE)
         )
      port map (
         O  => sDataPadP,               -- 1-bit output: Buffer output
         OB => sDataPadN,
         I  => sDataP,  -- 1-bit input: Diff_p buffer input (connect directly to top-level port)
         IB => sDataN   -- 1-bit input: Diff_n buffer input (connect directly to top-level port)
         );
   -- Optionally invert the pad input
   sData_i <= sDataPadP when ADC_INVERT_CH_G = '0' else sDataPadN;
   ----------------------------------------------------------------------------
   -- idelay3
   ----------------------------------------------------------------------------
   U_IDELAYE3_0 : entity surf.Idelaye3Wrapper
      generic map (
         CASCADE          => CASCADE_C,   -- Cascade setting (MASTER, NONE, SLAVE_END, SLAVE_MIDDLE)
         DELAY_FORMAT     => "COUNT",   -- Units of the DELAY_VALUE (COUNT, TIME)
         DELAY_SRC        => "IDATAIN",   -- Delay input (DATAIN, IDATAIN)
         DELAY_TYPE       => "VAR_LOAD",  -- Set the type of tap delay line (FIXED, VARIABLE, VAR_LOAD)
         DELAY_VALUE      => conv_integer(DEFAULT_DELAY_G),  -- Input delay value setting
         IS_CLK_INVERTED  => '0',       -- Optional inversion for CLK
         IS_RST_INVERTED  => '0',       -- Optional inversion for RST
         REFCLK_FREQUENCY => IDELAYCTRL_FREQ_G,  -- IDELAYCTRL clock input frequency in MHz (200.0-2667.0)
         SIM_DEVICE       => SIM_DEVICE_G,  -- Set the device version (ULTRASCALE, ULTRASCALE_PLUS, ULTRASCALE_PLUS_ES1,
         -- ULTRASCALE_PLUS_ES2)
         UPDATE_MODE      => "ASYNC"  -- Determines when updates to the delay will take effect (ASYNC, MANUAL,
       -- SYNC)
         )
      port map (
         CASC_IN     => '0',      -- 1-bit input: Cascade delay input from slave ODELAY CASCADE_OUT
         CASC_OUT    => cascOut,  -- 1-bit output: Cascade delay output to ODELAY input cascade
         CASC_RETURN => cascRet,  -- 1-bit input: Cascade delay returning from slave ODELAY DATAOUT
         CNTVALUEOUT => masterCntValue1,  -- 9-bit output: Counter value output
         DATAOUT     => sData_d,        -- 1-bit output: Delayed data output
         CE          => '0',            -- 1-bit input: Active high enable increment/decrement input
         CLK         => dClkDiv4,       -- 1-bit input: Clock input
         CNTVALUEIN  => delay,          -- 9-bit input: Counter value input
         DATAIN      => '1',            -- 1-bit input: Data input from the logic
         EN_VTC      => '0',            -- 1-bit input: Keep delay constant over VT
         IDATAIN     => sData_i,        -- 1-bit input: Data input from the IOBUF
         INC         => '0',            -- 1-bit input: Increment / Decrement tap delay input
         LOAD        => loadDelay,      -- 1-bit input: Load DELAY_VALUE input
         RST         => dRstDiv4        -- 1-bit input: Asynchronous Reset to the DELAY_VALUE
         );

   G_IdelayCascade : if IDELAY_CASCADE_G = true generate
      signal masterCntValue : slv(9 downto 0);
   begin

      U_ODELAYE3_0 : entity surf.Odelaye3Wrapper
         generic map (
            CASCADE          => "SLAVE_END",  -- Cascade setting (MASTER, NONE, SLAVE_END, SLAVE_MIDDLE)
            DELAY_FORMAT     => "COUNT",  -- Units of the DELAY_VALUE (COUNT, TIME)
            DELAY_TYPE       => "VAR_LOAD",  -- Set the type of tap delay line (FIXED, VARIABLE, VAR_LOAD)
            DELAY_VALUE      => conv_integer(DEFAULT_DELAY_G),  -- Input delay value setting
            IS_CLK_INVERTED  => '0',    -- Optional inversion for CLK
            IS_RST_INVERTED  => '0',    -- Optional inversion for RST
            REFCLK_FREQUENCY => IDELAYCTRL_FREQ_G,  -- IDELAYCTRL clock input frequency in MHz (200.0-2400.0)
            SIM_DEVICE       => SIM_DEVICE_G,
            UPDATE_MODE      => "ASYNC")  -- Determines when updates to the delay will take effect (ASYNC, MANUAL, SYNC)
         port map (
            CASC_IN     => cascOut,  -- 1-bit input: Cascade delay input from slave IDELAY CASCADE_OUT
            CASC_OUT    => open,     -- 1-bit output: Cascade delay output to IDELAY input cascade
            CASC_RETURN => '0',  -- 1-bit input: Cascade delay returning from slave IDELAY DATAOUT
            ODATAIN     => '0',         -- 1-bit input: Data input
            DATAOUT     => cascRet,     -- 1-bit output: Delayed data from ODATAIN input port
            CLK         => dClkDiv4,    -- 1-bit input: Clock input
            EN_VTC      => '0',         -- 1-bit input: Keep delay constant over VT
            INC         => '0',         -- 1-bit input: Increment / Decrement tap delay input
            CE          => '0',         -- 1-bit input: Active high enable increment/decrement input
            LOAD        => loadDelay,   -- 1-bit input: Load DELAY_VALUE input
            RST         => dRstDiv4,    -- 1-bit input: Asynchronous Reset to the DELAY_VALUE
            CNTVALUEIN  => delay,       -- 9-bit input: Counter value input
            CNTVALUEOUT => masterCntValue2);  -- 9-bit output: Counter value output

      masterCntValue <= resize(masterCntValue1, 10, '0') + masterCntValue2;
      delayValueOut  <= masterCntValue(9 downto 1);

   end generate;
   G_IdelayNoCascade : if IDELAY_CASCADE_G = false generate
      delayValueOut   <= masterCntValue1;
      masterCntValue2 <= (others => '0');
      cascRet         <= '0';
   end generate;

   ----------------------------------------------------------------------------
   -- iserdes3
   ----------------------------------------------------------------------------
   U_ISERDESE3_master : ISERDESE3
      generic map (
         DATA_WIDTH        => 8,        -- Parallel data width (4,8)
         FIFO_ENABLE       => "FALSE",  -- Enables the use of the FIFO
         FIFO_SYNC_MODE    => "FALSE",  -- Enables the use of internal 2-stage synchronizers on the FIFO
         IS_CLK_B_INVERTED => '1',      -- Optional inversion for CLK_B
         IS_CLK_INVERTED   => '0',      -- Optional inversion for CLK
         IS_RST_INVERTED   => '0',      -- Optional inversion for RST
         SIM_DEVICE        => SIM_DEVICE_G  -- Set the device version (ULTRASCALE, ULTRASCALE_PLUS, ULTRASCALE_PLUS_ES1,
         )
      port map (
         FIFO_EMPTY      => open,       -- 1-bit output: FIFO empty flag
         INTERNAL_DIVCLK => open,  -- 1-bit output: Internally divided down clock used when FIFO is
         Q               => masterData,     -- bit registered output
         CLK             => dClk,       -- 1-bit input: High-speed clock
         CLKDIV          => dClkDiv4,   -- 1-bit input: Divided Clock
         CLK_B           => dClk,       -- 1-bit input: Inversion of High-speed clock CLK
         D               => sData_d,    -- 1-bit input: Serial Data Input
         FIFO_RD_CLK     => '1',        -- 1-bit input: FIFO read clock
         FIFO_RD_EN      => '1',        -- 1-bit input: Enables reading the FIFO when asserted
         RST             => dRstDiv4    -- 1-bit input: Asynchronous Reset
         );

   U_Gearbox : entity surf.Gearbox
      generic map (
         TPD_G                => TPD_G,
         SLAVE_WIDTH_G        => 8,
         MASTER_WIDTH_G       => 14,
         MASTER_BIT_REVERSE_G => toBoolean(BIT_REV_G)
         )
      port map (
         clk         => dClkDiv4,
         rst         => dRstDiv4,
         slip        => bitSlip,        -- bitslip by the Microblaze alignment code
         -- Slave Interface
         slaveValid  => '1',
         slaveData   => masterData,
         -- Master Interface
         masterValid => adcValid,
         masterData  => adcData,
         masterReady => '1');

end rtl;

