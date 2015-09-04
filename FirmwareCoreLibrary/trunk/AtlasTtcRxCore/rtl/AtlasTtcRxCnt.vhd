-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AtlasTtcRxCnt.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-03-19
-- Last update: 2014-11-13
-- Platform   : Vivado 2013.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: RTL for the bunch and event counters
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AtlasTtcRxPkg.all;

library unisim;
use unisim.vcomponents.all;

entity AtlasTtcRxCnt is
   generic (
      TPD_G       : time   := 1 ns;
      USE_DSP48_G : string := "no");  -- "no" for no DSP48 implementation, "yes" to use DSP48 slices
   port (
      -- Trigger Signals
      trigL1In        : in  sl;
      trigL1Out       : out sl;
      bc              : in  AtlasTTCRxBcType;
      forceBusy       : in  sl;
      presetECR       : in  slv(7 downto 0);
      pauseECR        : in  sl;
      ignoreExtBusyIn : in  sl;
      ignoreFifoFull  : in  sl;
      busyIn          : in  sl;
      busyOut         : out sl;
      busyP           : out sl;         -- RMB's busy LEMO interface
      busyN           : out sl;         -- RMB's busy LEMO interface
      bunchCnt        : out slv(11 downto 0);
      bunchRstCnt     : out slv(7 downto 0);
      eventCnt        : out slv(23 downto 0);
      eventRstCnt     : out slv(7 downto 0);
      busyRateRst     : in  sl;
      busyRateCnt     : out slv(31 downto 0);
      busyRate        : out slv(31 downto 0);
      -- FIFO Interface
      fifoAFull       : in  sl;
      fifoWr          : out sl;
      fifoData        : out slv(30 downto 0);
      -- Global Signals
      refClk200MHz    : in  sl;
      locClk          : in  sl;
      locClkEn        : in  sl;
      locRst          : in  sl);   
end AtlasTtcRxCnt;

architecture rtl of AtlasTtcRxCnt is

   constant MAX_CNT_C : slv(31 downto 0) := (others => '1');
   
   type StateType is (
      NORMAL_S,
      PAUSED_S);       

   type RegType is record
      bunchCnt     : slv(11 downto 0);
      bunchRstCnt  : slv(7 downto 0);
      eventCnt     : slv(23 downto 0);
      nextEventCnt : slv(23 downto 0);
      eventRstCnt  : slv(7 downto 0);
      fifoWr       : sl;
      trigL1       : sl;
      fifoData     : slv(30 downto 0);
      cnt          : slv(31 downto 0);
      busyRate     : slv(31 downto 0);
      state        : StateType;
   end record;
   
   constant REG_INIT_C : RegType := (
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      '0',
      '0',
      (others => '0'),
      (others => '0'),
      (others => '0'),
      state   => NORMAL_S); 

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal busy,
      busyInMasked,
      fifoAFullMasked : sl;
   
begin

   comb : process (bc, busy, busyRateRst, locClkEn, locRst, pauseECR, presetECR, r, trigL1In) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobe signals
      v.fifoWr := '0';
      if locClkEn = '1' then
         v.trigL1 := '0';
      end if;

      -- Check if we need to reset the bunch counter
      if (bc.valid = '1') and (bc.cmdData(0) = '1') then
         -- Reset the counter
         v.bunchCnt    := (others => '0');
         -- Increment the bunch reset counter
         v.bunchRstCnt := r.bunchRstCnt + 1;
      -- Increment the bunchCnt every 40 MHz clock cycle
      elsif locClkEn = '1' then
         -- Increment the counter
         v.bunchCnt := r.bunchCnt + 1;
      end if;

      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when NORMAL_S =>
            -----------------------------------------------------
            -- Note: bc.valid and locClkEn never '1' at same 
            --       time. (out of phase by 2 locClk cycles) This 
            --       was done on purpose to prevent resetting of 
            --       the counters at the same time as receiving
            --       an level-1 trigger 
            -----------------------------------------------------           
            -- Check if we need to reset the event counter
            if (bc.valid = '1') and (bc.cmdData(1) = '1') then
               -- Reset the counter
               v.nextEventCnt := (others => '0');
               -- Increment the event reset counter
               v.eventRstCnt  := r.eventRstCnt + 1;
            -- Check for a Level-1 Trigger
            elsif (locClkEn = '1') and (trigL1In = '1') then
               -- Set the trigger flag
               v.trigL1                 := '1';
               -- Set the event counter output
               v.eventCnt               := r.nextEventCnt;
               -- Write the values to the FIFO
               v.fifoWr                 := '1';
               v.fifoData(23 downto 0)  := r.nextEventCnt;
               v.fifoData(30 downto 24) := r.eventRstCnt(6 downto 0);
               -- Increment the counter
               v.nextEventCnt           := r.nextEventCnt + 1;
            end if;
            -- Check for a pause
            if pauseECR = '1' then
               -- Next State
               v.State := PAUSED_S;
            end if;
         ----------------------------------------------------------------------
         when PAUSED_S =>
            -- Check if we need to reset the event counter and not paused
            if (bc.valid = '1') and (bc.cmdData(1) = '1') and (pauseECR = '0') then
               -- Reset the counter
               v.nextEventCnt := (others => '0');
               -- Set the event reset counter to the preset value
               v.eventRstCnt  := presetECR;
               -- Next State
               v.State        := NORMAL_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Check if busy is active
      if (busy = '1') and (locClkEn = '1') then
         if r.cnt /= MAX_CNT_C then
            v.cnt := r.cnt + 1;
         end if;
      end if;
      -- Check if we need to reset the busyRate integrator
      if (bc.valid = '1') and (bc.cmdData(1) = '1') then
         -- Latch the counter value
         v.busyRate := r.cnt;
         -- Reset the counter
         v.cnt      := (others => '0');
      end if;
      -- Check for register reset of accumulator 
      if busyRateRst = '1' then
         -- Reset the counter
         v.cnt := (others => '0');
      end if;

      -- Synchronous Reset
      if locRst = '1' then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      trigL1Out   <= r.trigL1;
      bunchCnt    <= r.bunchCnt;
      bunchRstCnt <= r.bunchRstCnt;
      eventCnt    <= r.eventCnt;
      eventRstCnt <= r.eventRstCnt;
      busyRateCnt <= r.cnt;
      busyRate    <= r.busyRate;
      fifoWr      <= r.fifoWr;
      fifoData    <= r.fifoData;
      
   end process comb;

   seq : process (locClk) is
   begin
      if rising_edge(locClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   busyInMasked    <= busyIn and not(ignoreExtBusyIn);
   fifoAFullMasked <= fifoAFull and not(ignoreFifoFull);

   busy    <= busyInMasked or fifoAFullMasked or forceBusy;
   busyOut <= busy;

   OBUFDS_Inst : OBUFDS
      port map (
         I  => busy,
         O  => busyP,
         OB => busyN);

end rtl;
