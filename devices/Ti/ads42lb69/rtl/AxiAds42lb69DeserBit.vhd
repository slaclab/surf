-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: ADC DDR Deserializer
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
use surf.AxiAds42lb69Pkg.all;

library unisim;
use unisim.vcomponents.all;

entity AxiAds42lb69DeserBit is
   generic (
      TPD_G           : time            := 1 ns;
      DELAY_INIT_G    : slv(8 downto 0) := (others => '0');
      IODELAY_GROUP_G : string          := "AXI_ADS42LB69_IODELAY_GRP";
      XIL_DEVICE_G    : string          := "7SERIES");
   port (
      -- ADC Data (clk domain)
      dataP        : in  sl;
      dataN        : in  sl;
      Q1           : out sl;
      Q2           : out sl;
      -- IO_Delay (delayClk domain)
      delayClk     : in  sl;
      delayRst     : in  sl;
      delayInLoad  : in  sl;
      delayInData  : in  slv(8 downto 0);
      delayOutData : out slv(9 downto 0);
      -- Clocks
      clk          : in  sl);
end AxiAds42lb69DeserBit;

architecture rtl of AxiAds42lb69DeserBit is

   component Idelaye3Wrapper
      generic (
         TPD_G            : time    := 1 ns;
         CASCADE          : string  := "NONE";  -- Cascade setting (MASTER, NONE, SLAVE_END, SLAVE_MIDDLE)
         DELAY_FORMAT     : string  := "TIME";  -- Units of the DELAY_VALUE (COUNT, TIME)
         DELAY_SRC        : string  := "IDATAIN";  -- Delay input (DATAIN, IDATAIN)
         DELAY_TYPE       : string  := "FIXED";  -- Set the type of tap delay line (FIXED, VARIABLE, VAR_LOAD)
         DELAY_VALUE      : integer := 0;  -- Input delay value setting
         IS_CLK_INVERTED  : bit     := '0';  -- Optional inversion for CLK
         IS_RST_INVERTED  : bit     := '0';  -- Optional inversion for RST
         REFCLK_FREQUENCY : real    := 300.0;  -- IDELAYCTRL clock input frequency in MHz (200.0-2667.0)
         SIM_DEVICE       : string  := "ULTRASCALE";  -- Set the device version (ULTRASCALE, ULTRASCALE_PLUS)
         UPDATE_MODE      : string  := "ASYNC");  -- Determines when updates to the delay will take effect (ASYNC, MANUAL, SYNC)
      port (
         BUSY        : out sl;             -- 1-bit output: Patch module is busy
         CASC_OUT    : out sl;  -- 1-bit output: Cascade delay output to ODELAY input cascade
         CNTVALUEOUT : out slv(8 downto 0);  -- 9-bit output: Counter value output
         DATAOUT     : out sl;             -- 1-bit output: Delayed data output
         CASC_IN     : in  sl;  -- 1-bit input: Cascade delay input from slave ODELAY CASCADE_OUT
         CASC_RETURN : in  sl;  -- 1-bit input: Cascade delay returning from slave ODELAY DATAOUT
         CE          : in  sl;  -- 1-bit input: Active high enable increment/decrement input
         CLK         : in  sl;             -- 1-bit input: Clock input
         CNTVALUEIN  : in  slv(8 downto 0);  -- 9-bit input: Counter value input
         DATAIN      : in  sl;  -- 1-bit input: Data input from the logic
         EN_VTC      : in  sl;  -- 1-bit input: Keep delay constant over VT
         IDATAIN     : in  sl;  -- 1-bit input: Data input from the IOBUF
         INC         : in  sl;  -- 1-bit input: Increment / Decrement tap delay input
         LOAD        : in  sl;             -- 1-bit input: Load DELAY_VALUE input
         RST         : in  sl);  -- 1-bit input: Asynchronous Reset to the DELAY_VALUE
   end component;

   component Odelaye3Wrapper
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
   end component;

   signal data       : sl;
   signal dataDly    : sl;
   signal clkb       : sl;
   signal cascOut    : sl;
   signal cascRet    : sl;
   signal delayOutData1 : slv(8 downto 0);
   signal delayOutData2 : slv(8 downto 0);

begin

   GEN_7SERIES : if (XIL_DEVICE_G = "7SERIES") generate
      attribute IODELAY_GROUP                  : string;
      attribute IODELAY_GROUP of IDELAYE2_inst : label is IODELAY_GROUP_G;
   begin

      IBUFDS_Inst : IBUFDS
         port map (
            I  => dataP,
            IB => dataN,
            O  => data);

      IDELAYE2_inst : IDELAYE2
         generic map (
            CINVCTRL_SEL          => "FALSE",     -- Enable dynamic clock inversion (FALSE, TRUE)
            DELAY_SRC             => "IDATAIN",   -- Delay input (IDATAIN, DATAIN)
            HIGH_PERFORMANCE_MODE => "FALSE",     -- Reduced jitter ("TRUE"), Reduced power ("FALSE")
            IDELAY_TYPE           => "VAR_LOAD",  -- FIXED, VARIABLE, VAR_LOAD, VAR_LOAD_PIPE
            IDELAY_VALUE          => conv_integer(DELAY_INIT_G(4 downto 0)),  -- Input delay tap setting (0-31)
            PIPE_SEL              => "FALSE",     -- Select pipelined mode, FALSE, TRUE
            REFCLK_FREQUENCY      => 200.0,  -- IDELAYCTRL clock input frequency in MHz (190.0-210.0, 290.0-310.0).
            SIGNAL_PATTERN        => "DATA")      -- DATA, CLOCK input signal
         port map (
            CNTVALUEOUT => delayOutData(4 downto 0),   -- 5-bit output: Counter value output
            DATAOUT     => dataDly,        -- 1-bit output: Delayed data output
            C           => delayClk,       -- 1-bit input: Clock input
            CE          => '0',            -- 1-bit input: Active high enable increment/decrement input
            CINVCTRL    => '0',            -- 1-bit input: Dynamic clock inversion input
            CNTVALUEIN  => delayInData(4 downto 0),    -- 5-bit input: Counter value input
            DATAIN      => '0',            -- 1-bit input: Internal delay data input
            IDATAIN     => data,           -- 1-bit input: Data input from the I/O
            INC         => '0',            -- 1-bit input: Increment / Decrement tap delay input
            LD          => delayInLoad,    -- 1-bit input: Load IDELAY_VALUE input
            LDPIPEEN    => '0',            -- 1-bit input: Enable PIPELINE register to load data input
            REGRST      => '0');           -- 1-bit input: Active-high reset tap-delay input

      IDDR_Inst : IDDR
         generic map (
            DDR_CLK_EDGE => "SAME_EDGE_PIPELINED",  -- "OPPOSITE_EDGE", "SAME_EDGE", or "SAME_EDGE_PIPELINED"
            INIT_Q1      => '0',           -- Initial value of Q1: '0' or '1'
            INIT_Q2      => '0',           -- Initial value of Q2: '0' or '1'
            SRTYPE       => "SYNC")        -- Set/Reset type: "SYNC" or "ASYNC"
         port map (
            D  => dataDly,                 -- 1-bit DDR data input
            C  => clk,                     -- 1-bit clock input
            CE => '1',                     -- 1-bit clock enable input
            R  => '0',                     -- 1-bit reset
            S  => '0',                     -- 1-bit set
            Q1 => Q1,                      -- 1-bit output for positive edge of clock
            Q2 => Q2);                     -- 1-bit output for negative edge of clock

   end generate;

   GEN_ULTRASCALE : if (XIL_DEVICE_G = "ULTRASCALE") generate

      -- when DELAY_FORMAT is "COUNT" the delay is not PVT calibrated
      -- Therefore, do not use an IDELAYCTRL component
      -- Leave the REFCLK_FREQUENCY attribute at the default value (300 MHz).
      -- Tie the EN_VTC input pin Low

      IBUFDS_Inst : IBUFDS
         port map (
            I  => dataP,
            IB => dataN,
            O  => data);

      IDELAYE3_inst : Idelaye3Wrapper
         generic map (
            CASCADE => "MASTER",       -- Cascade setting (MASTER, NONE, SLAVE_END, SLAVE_MIDDLE)
            DELAY_FORMAT => "COUNT",   -- Units of the DELAY_VALUE (COUNT, TIME)
            DELAY_SRC => "IDATAIN",    -- Delay input (DATAIN, IDATAIN)
            DELAY_TYPE => "VAR_LOAD",  -- Set the type of tap delay line (FIXED, VARIABLE, VAR_LOAD)
            DELAY_VALUE => conv_integer(DELAY_INIT_G), -- Input delay value setting
            IS_CLK_INVERTED => '0',    -- Optional inversion for CLK
            IS_RST_INVERTED => '0',    -- Optional inversion for RST
            REFCLK_FREQUENCY => 300.0, -- IDELAYCTRL clock input frequency in MHz (200.0-2400.0)
            UPDATE_MODE => "ASYNC")    -- Determines when updates to the delay will take effect (ASYNC, MANUAL, SYNC)
         port map (
            CASC_IN     => '0',           -- 1-bit input: Cascade delay input from slave ODELAY CASCADE_OUT
            CASC_OUT    => cascOut,       -- 1-bit output: Cascade delay output to ODELAY input cascade
            CASC_RETURN => cascRet,       -- 1-bit input: Cascade delay returning from slave ODELAY DATAOUT
            DATAIN      => '0',           -- 1-bit input: Data input from the logic
            IDATAIN     => data,          -- 1-bit input: Data input from the IOBUF
            DATAOUT     => dataDly,       -- 1-bit output: Delayed data output
            CLK         => delayClk,           -- 1-bit input: Clock input
            EN_VTC      => '0',           -- 1-bit input: Keep delay constant over VT
            INC         => '0',           -- 1-bit input: Increment / Decrement tap delay input
            CE          => '0',           -- 1-bit input: Active high enable increment/decrement input
            LOAD        => delayInLoad,   -- 1-bit input: Load DELAY_VALUE input
            RST         => delayRst,      -- 1-bit input: Asynchronous Reset to the DELAY_VALUE
            CNTVALUEIN  => delayInData,      -- 9-bit input: Counter value input
            CNTVALUEOUT => delayOutData1);   -- 9-bit output: Counter value output

      ODELAYE3_inst : Odelaye3Wrapper
         generic map (
            CASCADE => "SLAVE_END",    -- Cascade setting (MASTER, NONE, SLAVE_END, SLAVE_MIDDLE)
            DELAY_FORMAT => "COUNT",   -- Units of the DELAY_VALUE (COUNT, TIME)
            DELAY_TYPE => "VAR_LOAD",  -- Set the type of tap delay line (FIXED, VARIABLE, VAR_LOAD)
            DELAY_VALUE => conv_integer(DELAY_INIT_G), -- Input delay value setting
            IS_CLK_INVERTED => '0',    -- Optional inversion for CLK
            IS_RST_INVERTED => '0',    -- Optional inversion for RST
            REFCLK_FREQUENCY => 300.0, -- IDELAYCTRL clock input frequency in MHz (200.0-2400.0)
            UPDATE_MODE => "ASYNC")    -- Determines when updates to the delay will take effect (ASYNC, MANUAL, SYNC)
         port map (
            CASC_IN     => cascOut,       -- 1-bit input: Cascade delay input from slave IDELAY CASCADE_OUT
            CASC_OUT    => open,          -- 1-bit output: Cascade delay output to IDELAY input cascade
            CASC_RETURN => '0',           -- 1-bit input: Cascade delay returning from slave IDELAY DATAOUT
            ODATAIN     => '0',           -- 1-bit input: Data input
            DATAOUT     => cascRet,       -- 1-bit output: Delayed data from ODATAIN input port
            CLK         => delayClk,           -- 1-bit input: Clock input
            EN_VTC      => '0',           -- 1-bit input: Keep delay constant over VT
            INC         => '0',           -- 1-bit input: Increment / Decrement tap delay input
            CE          => '0',           -- 1-bit input: Active high enable increment/decrement input
            LOAD        => delayInLoad,   -- 1-bit input: Load DELAY_VALUE input
            RST         => delayRst,      -- 1-bit input: Asynchronous Reset to the DELAY_VALUE
            CNTVALUEIN  => delayInData,      -- 9-bit input: Counter value input
            CNTVALUEOUT => delayOutData2);   -- 9-bit output: Counter value output

      delayOutData <= resize(delayOutData1, 10, '0') + delayOutData2;

      IDDR_Inst : IDDRE1
         generic map (
            DDR_CLK_EDGE   => "SAME_EDGE_PIPELINED",  -- "OPPOSITE_EDGE", "SAME_EDGE", or "SAME_EDGE_PIPELINED"
            IS_C_INVERTED  => '0')
         port map (
            D  => dataDly,                 -- 1-bit DDR data input
            C  => clk,                     -- 1-bit clock input
            CB => clkb,                    -- 1-bit inverted clock input
            R  => '0',                     -- 1-bit reset
            Q1 => Q1,                      -- 1-bit output for positive edge of clock
            Q2 => Q2);                     -- 1-bit output for negative edge of clock

         clkb <= not clk;

   end generate;

end rtl;
