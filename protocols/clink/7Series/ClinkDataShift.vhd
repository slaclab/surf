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
      XIL_DEVICE_G : string := "7SERIES");
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

   signal intClk      : sl;
   signal intRst      : sl;
   signal intClk7x    : sl;
   signal intClk7xInv : sl;
   signal intDelay    : slv(4 downto 0);
   signal intLd       : sl;
   signal cblInDly    : slv(4 downto 0);
   signal cblIn       : slv(4 downto 0);
   signal rawIn       : slv(4 downto 0);
   signal dataShift   : Slv7Array(4 downto 0);
   signal clkReset    : sl;

   attribute IODELAY_GROUP : string;

begin

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
   U_ClkGen : entity surf.ClinkDataClk
      generic map (TPD_G => TPD_G)
      port map (
         clkIn           => rawIn(0),
         rstIn           => clkReset,
         clinkClk        => intClk,
         clinkClk7x      => intClk7x,
         clinkRst        => intRst,
         -- AXI-Lite Interface
         sysClk          => sysClk,
         sysRst          => sysRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

   -- Clock reset
   clkReset <= linkRst or dlyRst;

   -- Inverted clock
   intClk7xInv <= not intClk7x;

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
         dout   => intDelay);

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
      U_Delay : IDELAYE2
         generic map (
            CINVCTRL_SEL          => "FALSE",  -- Enable dynamic clock inversion (FALSE, TRUE)
            DELAY_SRC             => "IDATAIN",  -- Delay input (IDATAIN, DATAIN)
            HIGH_PERFORMANCE_MODE => "TRUE",  -- Reduced jitter ("TRUE"), Reduced power ("FALSE")
            IDELAY_TYPE           => "VAR_LOAD",  -- FIXED, VARIABLE, VAR_LOAD, VAR_LOAD_PIPE
            IDELAY_VALUE          => 0,  -- Input delay tap setting (0-31)
            PIPE_SEL              => "FALSE",  -- Select pipelined mode, FALSE, TRUE
            REFCLK_FREQUENCY      => 200.0,  -- IDELAYCTRL clock input frequency in MHz (190.0-210.0, 290.0-310.0).
            SIGNAL_PATTERN        => "DATA"  -- DATA, CLOCK input signal
            )
         port map (
            CNTVALUEOUT => open,        -- 5-bit output: Counter value output
            DATAOUT     => cblInDly(i),  -- 1-bit output: Delayed data output
            C           => dlyClk,      -- 1-bit input: Clock input
            CE          => '0',  -- 1-bit input: Active high enable increment/decrement input
            CINVCTRL    => '0',  -- 1-bit input: Dynamic clock inversion input
            CNTVALUEIN  => intDelay,    -- 5-bit input: Counter value input
            DATAIN      => '0',  -- 1-bit input: Internal delay data input
            IDATAIN     => cblIn(i),    -- 1-bit input: Data input from the I/O
            INC         => '0',  -- 1-bit input: Increment / Decrement tap delay input
            LD          => intLd,       -- 1-bit input: Load IDELAY_VALUE input
            LDPIPEEN    => '0',  -- 1-bit input: Enable PIPELINE register to load data input
            REGRST      => '0'  -- 1-bit input: Active-high reset tap-delay input
            );

      -- Deserializer
      U_Serdes : ISERDESE2
         generic map (
            DATA_RATE         => "SDR",    -- DDR, SDR
            DATA_WIDTH        => 7,     -- Parallel data width (2-8,10,14)
            DYN_CLKDIV_INV_EN => "FALSE",
            DYN_CLK_INV_EN    => "FALSE",
            INTERFACE_TYPE    => "NETWORKING",  -- MEMORY, MEMORY_DDR3, MEMORY_QDR, NETWORKING, OVERSAMPLE
            IOBDELAY          => "IFD",    -- NONE, BOTH, IBUF, IFD
            NUM_CE            => 1,     -- Number of clock enables (1,2)
            OFB_USED          => "FALSE",  -- Select OFB path (FALSE, TRUE)
            SERDES_MODE       => "MASTER"  -- MASTER, SLAVE
            )
         port map (
            Q1           => dataShift(i)(0),
            Q2           => dataShift(i)(1),
            Q3           => dataShift(i)(2),
            Q4           => dataShift(i)(3),
            Q5           => dataShift(i)(4),
            Q6           => dataShift(i)(5),
            Q7           => dataShift(i)(6),
            O            => rawIn(i),
            BITSLIP      => bitSlip,
            CE1          => '1',
            CE2          => '1',
            CLKDIVP      => '0',
            CLK          => intClk7x,
            CLKB         => intClk7xInv,
            CLKDIV       => intClk,
            OCLK         => '0',
            DYNCLKDIVSEL => '0',
            DYNCLKSEL    => '0',
            DDLY         => cblInDly(i),
            D            => cblIn(i),
            OFB          => '0',
            OCLKB        => '0',
            RST          => intRst,
            SHIFTIN1     => '0',
            SHIFTIN2     => '0'
            );

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

