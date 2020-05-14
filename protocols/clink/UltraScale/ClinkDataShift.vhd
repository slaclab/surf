-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- Block to de-serialize a block of 28 bits packed into 4 7-bit serial streams.
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
use surf.AxiLitePkg.all;
use surf.ClinkPkg.all;

library unisim;
use unisim.vcomponents.all;

entity ClinkDataShift is
   generic (
      TPD_G        : time   := 1 ns;
      XIL_DEVICE_G : string := "ULTRASCALE");
   port (
      -- Input clock and data
      cblHalfP        : inout slv(4 downto 0);
      cblHalfM        : inout slv(4 downto 0);
      -- Async link reset
      linkRst         : in    sl;
      -- Delay clock, 200Mhz
      dlyClk          : in    sl;
      dlyRst          : in    sl;
      -- Parallel Clock and reset Output, 85Mhz
      clinkClk        : out   sl;
      clinkRst        : out   sl;
      -- Parallel clock and data output (clinkClk)
      parData         : out   slv(27 downto 0);
      parClock        : out   slv(6 downto 0);
      -- Control inputs
      delay           : in    slv(4 downto 0);
      delayLd         : in    sl;
      bitSlip         : in    sl;
      -- Frequency Measurements
      clkInFreq       : out   slv(31 downto 0);
      clinkClkFreq    : out   slv(31 downto 0);
      -- AXI-Lite Interface
      sysClk          : in    sl;
      sysRst          : in    sl;
      axilReadMaster  : in    AxiLiteReadMasterType;
      axilReadSlave   : out   AxiLiteReadSlaveType;
      axilWriteMaster : in    AxiLiteWriteMasterType;
      axilWriteSlave  : out   AxiLiteWriteSlaveType);
end ClinkDataShift;

architecture structure of ClinkDataShift is

   signal intClk    : sl;
   signal intRst    : sl;
   signal intClk4x  : sl;
   signal intClk1x  : sl;
   signal intDelay  : slv(8 downto 0) := (others => '0');
   signal intLd     : sl;
   signal cblInDly  : slv(4 downto 0);
   signal cblIn     : slv(4 downto 0);
   signal rawIn     : slv(4 downto 0);
   signal serdes    : Slv8Array(4 downto 0);
   signal dataShift : Slv7Array(4 downto 0);
   signal clkReset  : sl;
   signal dlyRstL   : sl;

   attribute IODELAY_GROUP : string;

begin

   dlyRstL <= not(dlyRst);

   U_clkInFreq : entity surf.SyncClockFreq
      generic map (
         TPD_G          => TPD_G,
         REF_CLK_FREQ_G => 200.0E+6,
         REFRESH_RATE_G => 1.0,
         CNT_WIDTH_G    => 32)
      port map (
         -- Frequency Measurement (locClk domain)
         freqOut => clkInFreq,
         -- Clocks
         clkIn   => rawIn(0),
         locClk  => sysClk,
         refClk  => dlyClk);

   U_clinkClkFreq : entity surf.SyncClockFreq
      generic map (
         TPD_G          => TPD_G,
         REF_CLK_FREQ_G => 200.0E+6,
         REFRESH_RATE_G => 1.0,
         CNT_WIDTH_G    => 32)
      port map (
         -- Frequency Measurement (locClk domain)
         freqOut => clinkClkFreq,
         -- Clocks
         clkIn   => intClk,
         locClk  => sysClk,
         refClk  => dlyClk);

   --------------------------------------
   -- Clock Generation
   --------------------------------------
   U_MMCM : entity surf.ClockManagerUltraScale
      generic map(
         TPD_G              => TPD_G,
         TYPE_G             => "MMCM",
         INPUT_BUFG_G       => true,
         FB_BUFG_G          => true,
         RST_IN_POLARITY_G  => '1',
         NUM_CLOCKS_G       => 3,
         -- MMCM attributes
         BANDWIDTH_G        => "OPTIMIZED",
         CLKIN_PERIOD_G     => 10.0,    -- 100 MHz
         CLKFBOUT_MULT_F_G  => 12.0,    -- VCO = 1200MHz
         CLKOUT0_DIVIDE_F_G => 12.0,    -- 100 MHz (100 MHz x 7   = 600 Mb/s)
         CLKOUT1_DIVIDE_G   => 4,       -- 300 MHz (300 MHz x DDR = 600 Mb/s)
         CLKOUT2_DIVIDE_G   => 16)      --  75 MHz ( 75 MHz x 8   = 600 Mb/s)
      port map(
         clkIn           => rawIn(0),
         rstIn           => clkReset,
         -- Clock Outputs
         clkOut(0)       => intClk,
         clkOut(1)       => intClk4x,
         clkOut(2)       => intClk1x,
         -- Resets Outputs
         rstOut(0)       => intRst,
         rstOut(1)       => open,
         rstOut(2)       => open,
         -- AXI-Lite Interface
         axilClk         => sysClk,
         axilRst         => sysRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

   -- Clock reset
   clkReset <= linkRst or dlyRst;

   --------------------------------------
   -- Sync delay inputs
   --------------------------------------
   U_SyncDelay : entity surf.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 5)
      port map (
         rst    => intRst,
         wr_clk => intClk,
         wr_en  => delayLd,
         din    => delay,
         rd_clk => dlyClk,
         valid  => intLd,
         dout   => intDelay(8 downto 4));

      --------------------------------------
      -- Input Chain
      --------------------------------------
      U_InputGen : for i in 0 to 4 generate
         attribute IODELAY_GROUP of U_Delay : label is "CLINK_CORE";
      begin

         -- Input buffer
         U_InBuff : IOBUFDS
            port map(
               I   => '0',
               O   => cblIn(i),
               T   => '1',
               IO  => cblHalfP(i),
               IOB => cblHalfM(i));

         -- Each delay tap = 1/(32 * 2 * 200Mhz) = 78ps
         -- Input rate = 85Mhz * 7 = 595Mhz = 1.68nS = 21.55 taps
         U_Delay : entity surf.Idelaye3Wrapper
            generic map (
               CASCADE          => "NONE",  -- Cascade setting (MASTER, NONE, SLAVE_END, SLAVE_MIDDLE)
               DELAY_FORMAT     => "COUNT",  -- Units of the DELAY_VALUE (COUNT, TIME)
               DELAY_SRC        => "IDATAIN",  -- Delay input (DATAIN, IDATAIN)
               DELAY_TYPE       => "VAR_LOAD",  -- Set the type of tap delay line (FIXED, VARIABLE, VAR_LOAD)
               DELAY_VALUE      => 0,   -- Input delay value setting
               IS_CLK_INVERTED  => '0',  -- Optional inversion for CLK
               IS_RST_INVERTED  => '0',  -- Optional inversion for RST
               REFCLK_FREQUENCY => 200.0,  -- IDELAYCTRL clock input frequency in MHz (200.0-2667.0)
               SIM_DEVICE       => XIL_DEVICE_G,  -- Set the device version (ULTRASCALE, ULTRASCALE_PLUS, ULTRASCALE_PLUS_ES1, ULTRASCALE_PLUS_ES2)
               UPDATE_MODE      => "ASYNC")  -- Determines when updates to the delay will take effect (ASYNC, MANUAL, SYNC)
            port map (
               CASC_OUT    => open,  -- 1-bit output: Cascade delay output to ODELAY input cascade
               CNTVALUEOUT => open,     -- 9-bit output: Counter value output
               DATAOUT     => cblInDly(i),  -- 1-bit output: Delayed data output
               CASC_IN     => '0',  -- 1-bit input: Cascade delay input from slave ODELAY CASCADE_OUT
               CASC_RETURN => '0',  -- 1-bit input: Cascade delay returning from slave ODELAY DATAOUT
               CE          => '0',  -- 1-bit input: Active high enable increment/decrement input
               CLK         => dlyClk,   -- 1-bit input: Clock input
               CNTVALUEIN  => intDelay,  -- 9-bit input: Counter value input
               DATAIN      => '0',  -- 1-bit input: Data input from the logic
               EN_VTC      => '0',  -- 1-bit input: Keep delay constant over VT
               IDATAIN     => cblIn(i),  -- 1-bit input: Data input from the IOBUF
               INC         => '0',  -- 1-bit input: Increment / Decrement tap delay input
               LOAD        => intLd,    -- 1-bit input: Load DELAY_VALUE input
               RST         => '0');  -- 1-bit input: Asynchronous Reset to the DELAY_VALUE

         rawIn(i) <= cblInDly(i);

         -- Deserializer
         U_Serdes : ISERDESE3
            generic map (
               DATA_WIDTH        => 8,  -- Parallel data width (4,8)
               FIFO_ENABLE       => "FALSE",  -- Enables the use of the FIFO
               FIFO_SYNC_MODE    => "FALSE",  -- Enables the use of internal 2-stage synchronizers on the FIFO
               IS_CLK_B_INVERTED => '1',      -- Optional inversion for CLK_B
               IS_CLK_INVERTED   => '0',      -- Optional inversion for CLK
               IS_RST_INVERTED   => '0',      -- Optional inversion for RST
               SIM_DEVICE        => XIL_DEVICE_G)  -- Set the device version (ULTRASCALE, ULTRASCALE_PLUS, ULTRASCALE_PLUS_ES1, ULTRASCALE_PLUS_ES2)
            port map (
               Q           => serdes(i),      -- 8-bit registered output
               CLK         => intClk4x,  -- 1-bit input: High-speed clock
               CLK_B       => intClk4x,  -- 1-bit input: Inversion of High-speed clock CLK (IS_CLK_B_INVERTED='1')
               CLKDIV      => intClk1x,  -- 1-bit input: Divided Clock
               D           => cblInDly(i),    -- 1-bit input: Serial Data Input
               RST         => intRst,   -- 1-bit input: Asynchronous Reset
               FIFO_RD_CLK => '0',      -- 1-bit input: FIFO read clock
               FIFO_RD_EN  => '0',  -- 1-bit input: Enables reading the FIFO when asserted
               FIFO_EMPTY  => open);    -- 1-bit output: FIFO empty flag

         U_Gearbox : entity surf.AsyncGearbox
            generic map (
               TPD_G          => TPD_G,
               SLAVE_WIDTH_G  => 8,
               MASTER_WIDTH_G => 7)
            port map (
               slip       => bitslip,
               -- Slave Port
               slaveClk   => intClk1x,
               slaveRst   => '0',
               slaveData  => serdes(i),
               -- Master Port
               masterClk  => intClk,
               masterRst  => '0',
               masterData => dataShift(i));

      end generate;

   -------------------------------------------------------
   -- Timing diagram from DS90CR288A data sheet
   -------------------------------------------------------
   -- Lane   T0   T1   T2   T3   T4   T5   T6
   --    0    7    6    4    3    2    1    0
   --    1   18   15   14   13   12    9    8
   --    2   26   25   24   22   21   20   19
   --    3   23   17   16   11   10    5   27
   --
   -- Iserdes Bits
   --         6    5    4    3    2    1    0
   -------------------------------------------------------
   parData(7) <= dataShift(1)(6);
   parData(6) <= dataShift(1)(5);
   parData(4) <= dataShift(1)(4);
   parData(3) <= dataShift(1)(3);
   parData(2) <= dataShift(1)(2);
   parData(1) <= dataShift(1)(1);
   parData(0) <= dataShift(1)(0);

   parData(18) <= dataShift(2)(6);
   parData(15) <= dataShift(2)(5);
   parData(14) <= dataShift(2)(4);
   parData(13) <= dataShift(2)(3);
   parData(12) <= dataShift(2)(2);
   parData(9)  <= dataShift(2)(1);
   parData(8)  <= dataShift(2)(0);

   parData(26) <= dataShift(3)(6);
   parData(25) <= dataShift(3)(5);
   parData(24) <= dataShift(3)(4);
   parData(22) <= dataShift(3)(3);
   parData(21) <= dataShift(3)(2);
   parData(20) <= dataShift(3)(1);
   parData(19) <= dataShift(3)(0);

   parData(23) <= dataShift(4)(6);
   parData(17) <= dataShift(4)(5);
   parData(16) <= dataShift(4)(4);
   parData(11) <= dataShift(4)(3);
   parData(10) <= dataShift(4)(2);
   parData(5)  <= dataShift(4)(1);
   parData(27) <= dataShift(4)(0);

   parClock <= dataShift(0);
   clinkClk <= intClk;
   clinkRst <= intRst;

end structure;

