-------------------------------------------------------------------------------
-- File       : ClinkDeSerial.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-11-13
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
use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.ClinkPkg.all;
library unisim;
use unisim.vcomponents.all;

-- 20 partial
-- 10 partial
-- 30 fail
-- 15 ok

entity ClinkDeSerial is
   generic (
      TPD_G           : time                  := 1 ns;
      IDELAY_VALUE_G  : integer range 0 to 31 := 15); -- 1/2 high speed period , 10
   port (
      -- Input clock and data
      cblIn      : in  slv(4 downto 0);
      -- Delay clock and reset, 200Mhz
      dlyClk     : in  sl; 
      dlyRst     : in  sl; 
      -- System clock and reset
      sysClk     : in  sl;
      sysRst     : in  sl;
      -- Status
      linkConfig : in  ClLinkConfigType;
      linkStatus : out ClLinkStatusType;
      -- Data output
      parData    : out slv(27 downto 0);
      parValid   : out sl;
      parReady   : in  sl := '1');
end ClinkDeSerial;

architecture structure of ClinkDeSerial is

   type LinkState is (RESET_S, DELAY_S, CHECK_S, SHIFT_S, DONE_S);

   type RegType is record
      state    : LinkState;
      load     : sl;
      count    : integer range 0 to 99;
      status   : ClLinkStatusType;
      shift    : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state    => RESET_S,
      load     => '0',
      count    => 0,
      status   => CL_LINK_STATUS_INIT_C,
      shift    => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal intRst        : sl;
   signal rawInput      : slv(4 downto 0);
   signal cblInDly      : slv(4 downto 0);
   signal dataShift     : Slv7Array(4 downto 0);
   signal delaySync     : slv(4 downto 0);
   signal delayLoad     : sl;
   signal parDataIn     : slv(27 downto 0);
   signal clinkClk      : sl;
   signal clinkRst      : sl;
   signal clinkClk7x    : sl;
   signal clinkClk7xInv : sl;

   attribute IODELAY_GROUP : string;           

begin

   intRst <= sysRst or linkConfig.reset;

   --------------------------------------
   -- Clock Generation
   --------------------------------------
   U_ClkGen : entity work.ClockManager7
      generic map (
         TPD_G               => TPD_G,
         INPUT_BUFG_G        => true,
         FB_BUFG_G           => true,
         OUTPUT_BUFG_G       => true, 
         NUM_CLOCKS_G        => 2,
         BANDWIDTH_G         => "OPTIMIZED",
         CLKIN_PERIOD_G      => 11.765, -- 85 Mhz
         DIVCLK_DIVIDE_G     => 1,
         CLKFBOUT_MULT_F_G   => 14.0, -- 1190Mhz
         CLKOUT0_DIVIDE_F_G  => 14.0, -- 85Mhz
         CLKOUT0_PHASE_G     => 0.0,
         CLKOUT1_DIVIDE_G    => 2,    -- 595Mhz
         CLKOUT1_PHASE_G     => 0.0)
      port map (
         clkIn            => rawInput(0),
         rstIn            => intRst,
         clkOut(0)        => clinkClk,
         clkOut(1)        => clinkClk7x,
         rstOut(0)        => clinkRst,
         rstOut(1)        => open);

   -- Inverted clock
   clinkClk7xInv <= not clinkClk7x;

   --------------------------------------
   -- Input paths
   --------------------------------------

   -- Sync delay load control
   U_DelayLdSync : entity work.SynchronizerOneShot
      generic map ( TPD_G => TPD_G )
      port map (
         clk     => dlyClk,
         rst     => dlyRst,
         dataIn  => r.load,
         dataOut => delayLoad);

   -- Sync delay load
   U_DelaySync: entity work.SynchronizerVector
      generic map ( 
         TPD_G   => TPD_G,
         WIDTH_G => 5)
      port map (
         clk     => dlyClk,
         rst     => dlyRst,
         dataIn  => linkConfig.delay,
         dataOut => delaySync);

   U_InputGen: for i in 0 to 4 generate
      attribute IODELAY_GROUP of U_Delay : label is "CLINK_CORE";
   begin

      -- Each delay tap = 1/(32 * 2 * 200Mhz) = 78ps 
      -- Input rate = 85Mhz * 7 = 595Mhz = 1.68nS = 21.55 taps
      U_Delay : IDELAYE2
         generic map (
            CINVCTRL_SEL          => "FALSE",        -- Enable dynamic clock inversion (FALSE, TRUE)
            DELAY_SRC             => "IDATAIN",      -- Delay input (IDATAIN, DATAIN)
            HIGH_PERFORMANCE_MODE => "TRUE",         -- Reduced jitter ("TRUE"), Reduced power ("FALSE")
            IDELAY_TYPE           => "VAR_LOAD",     -- FIXED, VARIABLE, VAR_LOAD, VAR_LOAD_PIPE
            IDELAY_VALUE          => IDELAY_VALUE_G, -- Input delay tap setting (0-31)
            PIPE_SEL              => "FALSE",        -- Select pipelined mode, FALSE, TRUE
            REFCLK_FREQUENCY      => 200.0,          -- IDELAYCTRL clock input frequency in MHz (190.0-210.0, 290.0-310.0).
            SIGNAL_PATTERN        => "DATA"          -- DATA, CLOCK input signal
         )
         port map (
            CNTVALUEOUT => open,        -- 5-bit output: Counter value output
            DATAOUT     => cblInDly(i), -- 1-bit output: Delayed data output
            C           => dlyClk,      -- 1-bit input: Clock input
            CE          => '0',         -- 1-bit input: Active high enable increment/decrement input
            CINVCTRL    => '0',         -- 1-bit input: Dynamic clock inversion input
            CNTVALUEIN  => delaySync,   -- 5-bit input: Counter value input
            DATAIN      => '0',         -- 1-bit input: Internal delay data input
            IDATAIN     => cblIn(i),    -- 1-bit input: Data input from the I/O
            INC         => '0',         -- 1-bit input: Increment / Decrement tap delay input
            LD          => delayLoad,   -- 1-bit input: Load IDELAY_VALUE input
            LDPIPEEN    => '0',         -- 1-bit input: Enable PIPELINE register to load data input
            REGRST      => '0'          -- 1-bit input: Active-high reset tap-delay input
         );

      U_Serdes : ISERDESE2
         generic map (
            DATA_RATE         => "SDR",        -- DDR, SDR
            DATA_WIDTH        => 7,            -- Parallel data width (2-8,10,14)
            DYN_CLKDIV_INV_EN => "FALSE",
            DYN_CLK_INV_EN    => "FALSE",
            INTERFACE_TYPE    => "NETWORKING", -- MEMORY, MEMORY_DDR3, MEMORY_QDR, NETWORKING, OVERSAMPLE
            IOBDELAY          => "IFD",        -- NONE, BOTH, IBUF, IFD
            NUM_CE            => 1,            -- Number of clock enables (1,2)
            OFB_USED          => "FALSE",      -- Select OFB path (FALSE, TRUE)
            SERDES_MODE       => "MASTER"      -- MASTER, SLAVE
         )
         port map (
            Q1           => dataShift(i)(0),
            Q2           => dataShift(i)(1),
            Q3           => dataShift(i)(2),
            Q4           => dataShift(i)(3),
            Q5           => dataShift(i)(4),
            Q6           => dataShift(i)(5),
            Q7           => dataShift(i)(6),
            O            => rawInput(i),
            BITSLIP      => r.shift,
            CE1          => '1',
            CE2          => '1',
            CLKDIVP      => '0',
            CLK          => clinkClk7x,
            CLKB         => clinkClk7xInv,
            CLKDIV       => clinkClk,
            OCLK         => '0',
            DYNCLKDIVSEL => '0',
            DYNCLKSEL    => '0',
            DDLY         => cblInDly(i),
            D            => cblIn(i),
            OFB          => '0',
            OCLKB        => '0',
            RST          => clinkRst,
            SHIFTIN1     => '0',
            SHIFTIN2     => '0'
         );

   end generate;

   --------------------------------------
   -- Determine proper shift count using
   -- known slow clock to data alignment
   --------------------------------------

   -- Data tracking
   comb : process (clinkRst, r, dataShift) is
      variable v  : RegType;
   begin

      v := r;

      v.shift := '0';
      v.load  := '0';
      v.count := r.count + 1;

      case r.state is
         when RESET_S =>
            if r.count = 99 then
               v.state := DELAY_S;
            end if;

         when DELAY_S =>
            v.load := '1';

            if r.count = 10 then
               v.state := CHECK_S;
               v.count := 0;
            end if;

         when CHECK_S =>
            if r.count = 99 then
               v.count := 0;

               if dataShift(0) = "1100011" then
                  v.state := DONE_S;
               else
                  v.state := SHIFT_S;
               end if;
            end if;

         when SHIFT_S =>
            v.count := 0;
            v.shift := '1';
            v.state := CHECK_S;
            v.status.shiftCnt := r.status.shiftCnt + 1;

         when DONE_S =>
            if r.count = 99 then
               if dataShift(0) = "1100011" then
                  v.status.locked := '1';
               else
                  v.status.locked := '0';
               end if;
            end if;

         when others =>
      end case;

      -- Reset
      if (clinkRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   -- sync logic
   seq : process (clinkClk) is
   begin
      if (rising_edge(clinkClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

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
   parDataIn(7)  <= dataShift(1)(6);
   parDataIn(6)  <= dataShift(1)(5);
   parDataIn(4)  <= dataShift(1)(4);
   parDataIn(3)  <= dataShift(1)(3);
   parDataIn(2)  <= dataShift(1)(2);
   parDataIn(1)  <= dataShift(1)(1);
   parDataIn(0)  <= dataShift(1)(0);

   parDataIn(18) <= dataShift(2)(6);
   parDataIn(15) <= dataShift(2)(5);
   parDataIn(14) <= dataShift(2)(4);
   parDataIn(13) <= dataShift(2)(3);
   parDataIn(12) <= dataShift(2)(2);
   parDataIn(9)  <= dataShift(2)(1);
   parDataIn(8)  <= dataShift(2)(0);

   parDataIn(26) <= dataShift(3)(6);
   parDataIn(25) <= dataShift(3)(5);
   parDataIn(24) <= dataShift(3)(4);
   parDataIn(22) <= dataShift(3)(3);
   parDataIn(21) <= dataShift(3)(2);
   parDataIn(20) <= dataShift(3)(1);
   parDataIn(19) <= dataShift(3)(0);

   parDataIn(23) <= dataShift(4)(6);
   parDataIn(17) <= dataShift(4)(5);
   parDataIn(16) <= dataShift(4)(4);
   parDataIn(11) <= dataShift(4)(3);
   parDataIn(10) <= dataShift(4)(2);
   parDataIn(5)  <= dataShift(4)(1);
   parDataIn(27) <= dataShift(4)(0);

   --------------------------------------
   -- Output FIFO and status
   --------------------------------------
   U_DataFifo: entity work.Fifo
      generic map (
         TPD_G           => TPD_G,
         BRAM_EN_G       => false,
         FWFT_EN_G       => true,
         DATA_WIDTH_G    => 28,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => clinkRst,
         wr_clk        => clinkClk,
         wr_en         => '1',
         din           => parDataIn,
         rd_clk        => sysClk,
         rd_en         => parReady,
         dout          => parData,
         valid         => parValid);

   U_Locked: entity work.Synchronizer
      generic map ( TPD_G => TPD_G )
      port map (
         clk     => sysClk,
         rst     => sysRst,
         dataIn  => r.status.locked,
         dataOut => linkStatus.locked);

   U_ShiftCnt: entity work.SynchronizerVector
      generic map ( 
         TPD_G   => TPD_G,
         WIDTH_G => 8)
      port map (
         clk     => sysClk,
         rst     => sysRst,
         dataIn  => r.status.shiftCnt,
         dataOut => linkStatus.shiftCnt);

end structure;

