-------------------------------------------------------------------------------
-- File       : GLinkGtx7RxRst.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-12-17
-- Last update: 2014-11-10
-------------------------------------------------------------------------------
-- Description: G-Link GTX7 Reset module
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
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity GLinkGtx7RxRst is
   generic(
      TPD_G                  : time                  := 1 ns;
      EXAMPLE_SIMULATION     : integer               := 0;
      GT_TYPE                : string                := "GTX";
      STABLE_CLOCK_PERIOD    : integer range 4 to 20 := 8;  --Period of the stable clock driving this state-machine, unit is [ns]
      RETRY_COUNTER_BITWIDTH : integer range 2 to 8  := 8
      );     
   port (
      lpmMode                : in  std_logic;
      STABLE_CLOCK           : in  std_logic;  --Stable Clock, either a stable clock from the PCB
                                               --or reference-clock present at startup.
      RXUSERCLK              : in  std_logic;  --RXUSERCLK as used in the design
      SOFT_RESET             : in  std_logic;  --User Reset, can be pulled any time
      PLLREFCLKLOST          : in  std_logic;  --PLL Reference-clock for the GT is lost
      PLLLOCK                : in  std_logic;  --Lock Detect from the PLL of the GT
      RXRESETDONE            : in  std_logic;
      MMCM_LOCK              : in  std_logic;
      RECCLK_STABLE          : in  std_logic;
      RECCLK_MONITOR_RESTART : in  std_logic := '0';
      DATA_VALID             : in  std_logic;
      TXUSERRDY              : in  std_logic;  --TXUSERRDY from GT 
      GTRXRESET              : out std_logic := '0';
      MMCM_RESET             : out std_logic := '1';
      PLL_RESET              : out std_logic := '0';        --Reset PLL 
      RX_FSM_RESET_DONE      : out std_logic;  --Reset-sequence has sucessfully been finished.
      RXUSERRDY              : out std_logic := '0';
      RUN_PHALIGNMENT        : out std_logic;
      PHALIGNMENT_DONE       : in  std_logic;  -- Drive high if phase alignment not needed
      RESET_PHALIGNMENT      : out std_logic := '0';
      RXDFEAGCHOLD           : out std_logic;
      RXDFELFHOLD            : out std_logic;
      RXLPMLFHOLD            : out std_logic;
      RXLPMHFHOLD            : out std_logic;

      RETRY_COUNTER : out std_logic_vector (RETRY_COUNTER_BITWIDTH-1 downto 0) := (others => '0')  -- Number of 
                                        -- Retries it took to get the transceiver up and running
      );
end GLinkGtx7RxRst;

--Interdependencies:
-- * Timing depends on the frequency of the stable clock. Hence counters-sizes
--   are calculated at design-time based on the Generics
--   
-- * if either of the PLLs is reset during TX-startup, it does not need to be reset again by RX
--   => signal which PLL has been reset
-- * 



architecture RTL of GLinkGtx7RxRst is
   type rx_rst_fsm_type is(
      INIT, ASSERT_ALL_RESETS, RELEASE_PLL_RESET, VERIFY_RECCLK_STABLE,
      RELEASE_MMCM_RESET, WAIT_RESET_DONE, DO_PHASE_ALIGNMENT,
      MONITOR_DATA_VALID, FSM_DONE);

   signal rx_state : rx_rst_fsm_type := INIT;

   constant MMCM_LOCK_CNT_MAX : integer := 1024;
   constant STARTUP_DELAY     : integer := 500;  --AR43482: Transceiver needs to wait for 500 ns after configuration
   constant WAIT_CYCLES       : integer := STARTUP_DELAY / STABLE_CLOCK_PERIOD;  -- Number of Clock-Cycles to wait after configuration
   constant WAIT_MAX          : integer := WAIT_CYCLES + 10;  -- 500 ns plus some additional margin

   constant WAIT_TIMEOUT_2ms   : integer := 3000000 / STABLE_CLOCK_PERIOD;  --  2 ms time-out
   constant WAIT_TLOCK_MAX     : integer := 100000 / STABLE_CLOCK_PERIOD;   --100 us time-out
   constant WAIT_TIMEOUT_500us : integer := 500000 / STABLE_CLOCK_PERIOD;   --500 us time-out
   constant WAIT_TIMEOUT_1us   : integer := 1000 / STABLE_CLOCK_PERIOD;     --1 us time-out
   constant WAIT_TIMEOUT_100us : integer := 100000 / STABLE_CLOCK_PERIOD;   --100 us time-out
   constant WAIT_TIME_ADAPT    : integer := (37000000 /integer(3.125))/STABLE_CLOCK_PERIOD;

   signal soft_reset_sync : std_logic;
   signal soft_reset_rise : std_logic;
   signal soft_reset_fall : std_logic;

                                         
   signal init_wait_count          : integer range 0 to WAIT_MAX := 0;
   signal init_wait_done           : std_logic                   := '0';
   signal pll_reset_asserted       : std_logic                   := '0';
   signal rx_fsm_reset_done_int    : std_logic                   := '0';
   signal rx_fsm_reset_done_int_s3 : std_logic                   := '0';

   signal rxresetdone_s3 : std_logic := '0';

   constant MAX_RETRIES            : integer                             := 2**RETRY_COUNTER_BITWIDTH-1;
   signal retry_counter_int        : integer range 0 to MAX_RETRIES      := 0;
   signal time_out_counter         : integer range 0 to WAIT_TIMEOUT_2ms := 0;
   signal recclk_mon_restart_count : integer range 0 to 3                := 0;
   signal recclk_mon_count_reset   : std_logic                           := '0';

   signal reset_time_out  : std_logic := '0';
   signal time_out_2ms    : std_logic := '0';  --\Flags that the various time-out points 
   signal time_tlock_max  : std_logic := '0';  --|have been reached.
   signal time_out_500us  : std_logic := '0';  --|
   signal time_out_1us    : std_logic := '0';  --/
   signal time_out_100us  : std_logic := '0';  --/
   signal check_tlock_max : std_logic := '0';

   signal mmcm_lock_count     : integer range 0 to MMCM_LOCK_CNT_MAX-1 := 0;
   signal mmcm_lock_int       : std_logic                              := '0';
   signal mmcm_lock_reclocked : std_logic_vector(3 downto 0)           := (others => '0');

   signal run_phase_alignment_int    : std_logic := '0';
   signal run_phase_alignment_int_s3 : std_logic := '0';

   constant MAX_WAIT_BYPASS       : integer   := 5000;  --5000 RXUSRCLK cycles is the max time for Multi lanes designs
   signal wait_bypass_count       : integer range 0 to MAX_WAIT_BYPASS-1;
   signal time_out_wait_bypass    : std_logic := '0';
   signal time_out_wait_bypass_s3 : std_logic := '0';

   signal refclk_lost : std_logic;

   signal time_out_adapt    : std_logic := '0';
   signal adapt_count_reset : std_logic := '0';
   signal adapt_count       : integer range 0 to WAIT_TIME_ADAPT-1;

   signal data_valid_sync       : std_logic := '0';
   signal plllock_sync          : std_logic := '0';
   signal phalignment_done_sync : std_logic := '0';
   
  signal fsmCnt : std_logic_vector(15 downto 0);     
   
   attribute KEEP_HIERARCHY : string;
   attribute KEEP_HIERARCHY of 
      Synchronizer_run_phase_alignment,
      Synchronizer_fsm_reset_done,
      Synchronizer_SOFT_RESET,
      Synchronizer_RXRESETDONE,
      Synchronizer_time_out_wait_bypass,
      Synchronizer_mmcm_lock_reclocked,
      Synchronizer_data_valid,
      Synchronizer_PLLLOCK,
      Synchronizer_PHALIGNMENT_DONE : label is "TRUE";
   
begin

   --Alias section, signals used within this module mapped to output ports:
   RETRY_COUNTER     <= std_logic_vector(TO_UNSIGNED(retry_counter_int, RETRY_COUNTER_BITWIDTH));
   RUN_PHALIGNMENT   <= run_phase_alignment_int;
   RX_FSM_RESET_DONE <= rx_fsm_reset_done_int;

   process(STABLE_CLOCK)
   begin
      if rising_edge(STABLE_CLOCK) then
         -- The counter starts running when configuration has finished and 
         -- the clock is stable. When its maximum count-value has been reached,
         -- the 500 ns from Answer Record 43482 have been passed.
         if init_wait_count = WAIT_MAX then
            init_wait_done <= '1';
         else
            init_wait_count <= init_wait_count + 1;
         end if;
      end if;
   end process;


   adapt_wait_sim : if(EXAMPLE_SIMULATION = 1) generate
      time_out_adapt <= '1';
   end generate;

   adapt_wait_hw : if(EXAMPLE_SIMULATION = 0) generate
      process(STABLE_CLOCK)
      begin
         if rising_edge(STABLE_CLOCK) then
            if(adapt_count_reset = '1') then
               adapt_count    <= 0;
               time_out_adapt <= '0';
            elsif(adapt_count = WAIT_TIME_ADAPT -1) then
               time_out_adapt <= '1';
            else
               adapt_count <= adapt_count + 1;
            end if;
         end if;
      end process;
   end generate;

   retries_recclk_monitor : process(STABLE_CLOCK)
   begin
      --This counter monitors, how many retries the RECCLK monitor
      --runs. If during startup too many retries are necessary, the whole 
      --initialisation-process of the transceivers gets restarted.
      if rising_edge(STABLE_CLOCK) then
         if recclk_mon_count_reset = '1' then
            recclk_mon_restart_count <= 0;
         elsif RECCLK_MONITOR_RESTART = '1' then
            if recclk_mon_restart_count = 3 then
               recclk_mon_restart_count <= 0;
            else
               recclk_mon_restart_count <= recclk_mon_restart_count + 1;
            end if;
         end if;
      end if;
   end process;

   timeouts : process(STABLE_CLOCK)
   begin
      if rising_edge(STABLE_CLOCK) then
         -- One common large counter for generating three time-out signals.
         -- Intermediate time-outs are derived from calculated values, based
         -- on the period of the provided clock.
         if reset_time_out = '1' then
            time_out_counter <= 0;
            time_out_2ms     <= '0';
            time_tlock_max   <= '0';
            time_out_500us   <= '0';
            time_out_1us     <= '0';
            time_out_100us   <= '0';
         else
            if time_out_counter = WAIT_TIMEOUT_2ms then
               time_out_2ms <= '1';
            else
               time_out_counter <= time_out_counter + 1;
            end if;

            if (time_out_counter > WAIT_TLOCK_MAX) and (check_tlock_max = '1') then
               time_tlock_max <= '1';
            end if;

            if time_out_counter = WAIT_TIMEOUT_500us then
               time_out_500us <= '1';
            end if;

            if time_out_counter = WAIT_TIMEOUT_1us then
               time_out_1us <= '1';
            end if;

            if time_out_counter = WAIT_TIMEOUT_100us then
               time_out_100us <= '1';
            end if;

         end if;
      end if;
   end process;


   mmcm_lock_wait : process(RXUSERCLK, MMCM_LOCK)
   begin
      --The lock-signal from the MMCM is not immediately used but 
      --enabling a counter. Only when the counter hits its maximum,
      --the MMCM is considered as "really" locked. 
      --The counter avoids that the FSM already starts on only a 
      --coarse lock of the MMCM (=toggling of the LOCK-signal).
      if MMCM_LOCK = '0' then
         mmcm_lock_count <= 0;
         mmcm_lock_int   <= '0';
      elsif rising_edge(RXUSERCLK) then
         if mmcm_lock_count < MMCM_LOCK_CNT_MAX - 1 then
            mmcm_lock_count <= mmcm_lock_count + 1;
         else
            mmcm_lock_int <= '1';
         end if;
      end if;
   end process;


   -- Clock Domain Crossing
   Synchronizer_run_phase_alignment : entity work.Synchronizer
      generic map (
         TPD_G    => TPD_G,
         STAGES_G => 3,
         INIT_G   => "000")
      port map (
         clk     => RXUSERCLK,
         dataIn  => run_phase_alignment_int,
         dataOut => run_phase_alignment_int_s3);

   Synchronizer_fsm_reset_done : entity work.Synchronizer
      generic map (
         TPD_G    => TPD_G,
         STAGES_G => 3,
         INIT_G   => "000")
      port map (
         clk     => RXUSERCLK,
         dataIn  => rx_fsm_reset_done_int,
         dataOut => rx_fsm_reset_done_int_s3);

   Synchronizer_SOFT_RESET : entity work.SynchronizerEdge
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => STABLE_CLOCK,
         dataIn  => SOFT_RESET,
         dataOut => soft_reset_sync,
         risingEdge => soft_reset_rise,
         fallingEdge => soft_reset_fall);

   Synchronizer_RXRESETDONE : entity work.Synchronizer
      generic map (
         TPD_G    => TPD_G,
         STAGES_G => 3,
         INIT_G   => "000")
      port map (
         clk     => STABLE_CLOCK,
         dataIn  => RXRESETDONE,
         dataOut => rxresetdone_s3);

   Synchronizer_time_out_wait_bypass : entity work.Synchronizer
      generic map (
         TPD_G    => TPD_G,
         STAGES_G => 3,
         INIT_G   => "000")
      port map (
         clk     => STABLE_CLOCK,
         dataIn  => time_out_wait_bypass,
         dataOut => time_out_wait_bypass_s3);

   Synchronizer_mmcm_lock_reclocked : entity work.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => STABLE_CLOCK,
         dataIn  => mmcm_lock_int,
         dataOut => mmcm_lock_reclocked(0));

   Synchronizer_data_valid : entity work.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => STABLE_CLOCK,
         dataIn  => DATA_VALID,
         dataOut => data_valid_sync);


   Synchronizer_PLLLOCK : entity work.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => STABLE_CLOCK,
         dataIn  => PLLLOCK,
         dataOut => plllock_sync);

   -- Phase aligner might run on rxusrclk in some cases
   -- Synchronizer it just in case
   Synchronizer_PHALIGNMENT_DONE : entity work.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => STABLE_CLOCK,
         dataIn  => PHALIGNMENT_DONE,
         dataOut => phalignment_done_sync);


   timeout_buffer_bypass : process(RXUSERCLK)
   begin
      if rising_edge(RXUSERCLK) then
         if run_phase_alignment_int_s3 = '0' then
            wait_bypass_count    <= 0;
            time_out_wait_bypass <= '0';
         elsif (run_phase_alignment_int_s3 = '1') and (rx_fsm_reset_done_int_s3 = '0') then
            if wait_bypass_count = MAX_WAIT_BYPASS - 1 then
               time_out_wait_bypass <= '1';
            else
               wait_bypass_count <= wait_bypass_count + 1;
            end if;
         end if;
      end if;
   end process;

   -- Lock Detect Clock should be driven by STABLE_CLOCK, no need to synchronize
   refclk_lost <= PLLREFCLKLOST;



   --FSM for resetting the GTX/GTH/GTP in the 7-series. 
   --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
   --
   -- Following steps are performed:
   -- 1) After configuration wait for approximately 500 ns as specified in 
   --    answer-record 43482
   -- 2) Assert all resets on the GT and on an MMCM potentially connected. 
   --    After that wait until a reference-clock has been detected.
   -- 3) Release the reset to the GT and wait until the GT-PLL has locked.
   -- 4) Release the MMCM-reset and wait until the MMCM has signalled lock.
   --    Also get info from the TX-side which PLL has been reset.
   -- 5) Wait for the RESET_DONE-signal from the GT.
   -- 6) Signal to start the phase-alignment procedure and wait for it to 
   --    finish.
   -- 7) Reset-sequence has successfully run through. Signal this to the 
   --    rest of the design by asserting RX_FSM_RESET_DONE.

   reset_fsm : process(STABLE_CLOCK)
   begin
      if rising_edge(STABLE_CLOCK) then
         if (soft_reset_sync = '1' or
             (not(rx_state = INIT) and not(rx_state = ASSERT_ALL_RESETS) and refclk_lost = '1')) then
            rx_state                <= INIT;
            RXUSERRDY               <= '0';
            GTRXRESET               <= '0';
            MMCM_RESET              <= '1';
            rx_fsm_reset_done_int   <= '0';
            PLL_RESET               <= '0';
            pll_reset_asserted      <= '0';
            reset_time_out          <= '1';
            retry_counter_int       <= 0;
            run_phase_alignment_int <= '0';
            check_tlock_max         <= '0';
            RESET_PHALIGNMENT       <= '1';
            recclk_mon_count_reset  <= '1';
            adapt_count_reset       <= '1';
            RXDFEAGCHOLD            <= '0';
            RXDFELFHOLD             <= '0';
            RXLPMLFHOLD             <= '0';
            RXLPMHFHOLD             <= '0';
            fsmCnt                  <= (others=>'0');

         else
            
            case rx_state is
               when INIT =>
                  --Initial state after configuration. This state will be left after
                  --approx. 500 ns and not be re-entered. 
                  if init_wait_done = '1' then
                     rx_state <= ASSERT_ALL_RESETS;
                  end if;
                  
               when ASSERT_ALL_RESETS =>
                  --This is the state into which the FSM will always jump back if any
                  --time-outs will occur. 
                  --The number of retries is reported on the output RETRY_COUNTER. In 
                  --case the transceiver never comes up for some reason, this machine 
                  --will still continue its best and rerun until the FPGA is turned off
                  --or the transceivers come up correctly.
                  if pll_reset_asserted = '0' then
                     PLL_RESET          <= '1';
                     pll_reset_asserted <= '1';
                  else
                     PLL_RESET <= '0';
                  end if;

                  RXUSERRDY               <= '0';
                  GTRXRESET               <= '1';
                  MMCM_RESET              <= '1';
                  run_phase_alignment_int <= '0';
                  RESET_PHALIGNMENT       <= '1';
                  check_tlock_max         <= '0';
                  recclk_mon_count_reset  <= '1';
                  adapt_count_reset       <= '1';


                  if (PLLREFCLKLOST = '0' and pll_reset_asserted = '1') then
                     rx_state       <= RELEASE_PLL_RESET;
                     reset_time_out <= '1';
                  end if;
                  
               when RELEASE_PLL_RESET =>
                  --PLL-Reset of the GTX gets released and the time-out counter
                  --starts running.
                  pll_reset_asserted <= '0';
                  reset_time_out     <= '0';


                  if (plllock_sync = '1') then
                     rx_state               <= VERIFY_RECCLK_STABLE;
                     reset_time_out         <= '1';
                     recclk_mon_count_reset <= '0';
                     adapt_count_reset      <= '0';
                  end if;

                  if time_out_2ms = '1' then
                     if retry_counter_int = MAX_RETRIES then
                        -- If too many retries are performed compared to what is specified in 
                        -- the generic, the counter simply wraps around.
                        retry_counter_int <= 0;
                     else
                        retry_counter_int <= retry_counter_int + 1;
                     end if;
                     rx_state <= ASSERT_ALL_RESETS;
                  end if;

               when VERIFY_RECCLK_STABLE =>
                  --reset_time_out  <= '0';
                  --Time-out counter is not released in this state as here the FSM
                  --does not wait for a certain period of time but checks on the number
                  --of retries in the RECCLK monitor 
                  GTRXRESET <= '0';
                  if RECCLK_STABLE = '1' then
                     rx_state       <= RELEASE_MMCM_RESET;
                     reset_time_out <= '1';
                     
                  end if;

                  if recclk_mon_restart_count = 2 then
                     --If two retries are performed in the RECCLK monitor
                     --the whole initialisation-sequence gets restarted.
                     if retry_counter_int = MAX_RETRIES then
                        -- If too many retries are performed compared to what is specified in 
                        -- the generic, the counter simply wraps around.
                        retry_counter_int <= 0;
                     else
                        retry_counter_int <= retry_counter_int + 1;
                     end if;
                     rx_state <= ASSERT_ALL_RESETS;
                  end if;

               when RELEASE_MMCM_RESET =>
                  --Release of the MMCM-reset. Waiting for the MMCM to lock.
                  reset_time_out  <= '0';
                  check_tlock_max <= '1';

                  MMCM_RESET <= '0';
                  if mmcm_lock_reclocked(0) = '1' then
                     rx_state       <= WAIT_RESET_DONE;
                     reset_time_out <= '1';
                  end if;

                  if time_tlock_max = '1' and reset_time_out = '0' then
                     if retry_counter_int = MAX_RETRIES then
                        -- If too many retries are performed compared to what is specified in 
                        -- the generic, the counter simply wraps around.
                        retry_counter_int <= 0;
                     else
                        retry_counter_int <= retry_counter_int + 1;
                     end if;
                     rx_state <= ASSERT_ALL_RESETS;
                  end if;

               when WAIT_RESET_DONE =>
                  --When TXOUTCLK is the source for RXUSRCLK, RXUSERRDY depends on TXUSERRDY
                  --If RXOUTCLK is the source for RXUSRCLK, TXUSERRDY can be tied to '1'
                  if TXUSERRDY = '1' then
                     RXUSERRDY <= '1';
                  end if;
                  reset_time_out <= '0';
                  if rxresetdone_s3 = '1' then
                     rx_state       <= DO_PHASE_ALIGNMENT;
                     reset_time_out <= '1';
                  end if;

                  if time_out_2ms = '1' and reset_time_out = '0' then
                     if retry_counter_int = MAX_RETRIES then
                        -- If too many retries are performed compared to what is specified in 
                        -- the generic, the counter simply wraps around.
                        retry_counter_int <= 0;
                     else
                        retry_counter_int <= retry_counter_int + 1;
                     end if;
                     rx_state <= ASSERT_ALL_RESETS;
                  end if;

               when DO_PHASE_ALIGNMENT =>
                  --The direct handling of the signals for the Phase Alignment is done outside
                  --this state-machine. 
                  RESET_PHALIGNMENT       <= '0';
                  run_phase_alignment_int <= '1';
                  reset_time_out          <= '0';

                  if phalignment_done_sync = '1' then 
                     rx_state       <= MONITOR_DATA_VALID;
                     reset_time_out <= '1';
                  end if;

                  if time_out_wait_bypass_s3 = '1' then
                     if retry_counter_int = MAX_RETRIES then
                        -- If too many retries are performed compared to what is specified in 
                        -- the generic, the counter simply wraps around.
                        retry_counter_int <= 0;
                     else
                        retry_counter_int <= retry_counter_int + 1;
                     end if;
                     rx_state <= ASSERT_ALL_RESETS;
                  end if;

               when MONITOR_DATA_VALID =>
                  reset_time_out <= '0';

                  if (time_out_100us = '1' and (data_valid_sync = '0') and reset_time_out = '0') then
                     fsmCnt                <= (others=>'0');
                     rx_state              <= ASSERT_ALL_RESETS;
                     rx_fsm_reset_done_int <= '0';
                 elsif fsmCnt = x"FFFF" then
                    fsmCnt                <= (others=>'0');
                    rx_state              <= ASSERT_ALL_RESETS; 
                    rx_fsm_reset_done_int <= '0';                          
                  elsif (data_valid_sync = '1') then
                     fsmCnt                <= fsmCnt + 1;
                     rx_state              <= FSM_DONE;
                     rx_fsm_reset_done_int <= '0';
                     reset_time_out        <= '1';
                  end if;

               when FSM_DONE =>
                  reset_time_out <= '0';
                  if (data_valid_sync = '0') then
                     rx_fsm_reset_done_int <= '0';
                     reset_time_out        <= '1';
                     rx_state              <= MONITOR_DATA_VALID;
                  elsif (time_out_1us = '1') then
                     rx_fsm_reset_done_int <= '1';
                  end if;

                  if(time_out_adapt = '1') then
                     if(lpmMode = '0') then
                        RXDFEAGCHOLD <= '1';
                        RXDFELFHOLD  <= '1';
                     else
                        RXDFEAGCHOLD <= '0';
                        RXDFELFHOLD <= '0';
                        RXLPMHFHOLD <= '0';
                        RXLPMLFHOLD <= '0';
                     end if;
                  end if;
                  
            end case;
         end if;
      end if;
   end process;

end RTL;


