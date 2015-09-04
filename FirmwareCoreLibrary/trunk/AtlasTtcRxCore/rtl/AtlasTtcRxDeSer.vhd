-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AtlasTtcRxDeSer.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-03-14
-- Last update: 2014-04-15
-- Platform   : Vivado 2013.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: This module is an ATLAS TTC-RX Deserializer.
--          
-- Note: This module assumes that an ADN2816 IC 
--       is used for the Clock Data Recovery (CDR).
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AtlasTtcRxPkg.all;

entity AtlasTtcRxDeSer is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Serial Data Signals
      serDataEdgeSel : in  sl;
      serDataRising  : in  sl;
      serDataFalling : in  sl;
      -- Level-1 Trigger
      trigL1         : out sl;
      -- BC Encoded Message
      bcValid        : out sl;
      bcData         : out slv(7 downto 0);
      bcCheck        : out slv(4 downto 0);
      -- IAC Encoded Message
      iacValid       : out sl;
      iacData        : out slv(31 downto 0);
      iacCheck       : out slv(6 downto 0);
      -- Status Monitoring
      clkLocked      : in  sl;
      bpmLocked      : out sl;
      bpmErr         : out sl;
      deSerErr       : out sl;
      -- Global Signals
      clkSync        : out sl;
      locClkEn       : out sl;
      locClk         : in  sl;
      locRst         : in  sl);
end AtlasTtcRxDeSer;

architecture rtl of AtlasTtcRxDeSer is

   constant MAX_SIZE_C : slv(15 downto 0) := (others => '1');

   type BpmStateType is (
      RESET_S,
      CH_A_SMPL_S,
      CH_A_S,
      CH_B_SMPL_S,
      CH_B_S);   
   type BpmType is record
      serData    : sl;
      serDataDly : sl;
      chA        : sl;
      chB        : sl;
      data       : sl;
      trig       : sl;
      clkSync    : sl;
      locked     : sl;
      phase      : slv(1 downto 0);
      cnt        : slv(4 downto 0);
      errDet     : sl;
      state      : BpmStateType;
   end record;
   constant BPM_INIT_C : BpmType := (
      '0',
      '0',
      '0',
      '0',
      '0',
      '0',
      '0',
      '0',
      (others => '0'),
      (others => '0'),
      '0',
      RESET_S);      
   signal bpm : BpmType := BPM_INIT_C;
   
   type DeserStateType is (
      IDLE_S,
      FMT_S,
      SHIFT_REG_S,
      STOP_S);   
   type DeserType is record
      fmt      : sl;
      bcValid  : sl;
      bcData   : slv(7 downto 0);
      bcCheck  : slv(4 downto 0);
      iacValid : sl;
      iacData  : slv(31 downto 0);
      iacCheck : slv(6 downto 0);
      shiftReg : slv(38 downto 0);
      cnt      : slv(5 downto 0);
      errDet   : sl;
      state    : DeserStateType;
   end record;
   constant DESER_INIT_C : DeserType := (
      '0',
      '0',
      (others => '0'),
      (others => '0'),
      '0',
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      '0',
      IDLE_S);      
   signal deSer : DeserType := DESER_INIT_C;

begin

   trigL1   <= bpm.trig;
   locClkEn <= bpm.chA;
   clkSync  <= bpm.clkSync;

   bpmLocked <= bpm.locked;
   bpmErr    <= bpm.errDet;
   deSerErr  <= deSer.errDet;

   bcValid <= deSer.bcValid;
   bcData  <= deSer.bcData;
   bcCheck <= deSer.bcCheck;

   iacValid <= deSer.iacValid;
   iacData  <= deSer.iacData;
   iacCheck <= deSer.iacCheck;

   TIME_DIVISION_MULTIPLEXED : process(locClk)
   begin
      if rising_edge(locClk) then
         bpm.errDet     <= '0'         after TPD_G;
         bpm.chA        <= '0'         after TPD_G;
         bpm.chB        <= '0'         after TPD_G;
         bpm.trig       <= '0'         after TPD_G;
         bpm.clkSync    <= '0'         after TPD_G;
         bpm.serDataDly <= bpm.serData after TPD_G;
         -- Check for a reset
         if locRst = '1'then
            bpm <= BPM_INIT_C after TPD_G;
         else
            if serDataEdgeSel = '0' then
               bpm.serData <= serDataRising after TPD_G;
            else
               bpm.serData <= serDataFalling after TPD_G;
            end if;
            -- State Machine
            case bpm.state is
               ----------------------------------------------------------------------
               when RESET_S =>
                  -- Increment the counter
                  bpm.phase <= bpm.phase + 1 after TPD_G;
                  -- Check the phase counter
                  if bpm.phase = "11" then
                     -- Check for a logic low
                     if (bpm.serData = bpm.serDataDly) then
                        -- Reset the counter
                        bpm.phase <= (others => '0') after TPD_G;
                        -- Increment the counter
                        bpm.cnt   <= bpm.cnt + 1     after TPD_G;
                        -- Check for 23 consecutively non-triggers
                        if bpm.cnt = toSlv(22, 5) then
                           -- Reset the counter and slip by one cycle
                           bpm.cnt     <= (others => '0') after TPD_G;
                           -- Sync Up for the 40 MHz clock
                           bpm.clkSync <= '1'             after TPD_G;
                           -- Assert the locked status
                           bpm.locked  <= '1'             after TPD_G;
                           -- Next State
                           bpm.state   <= CH_B_SMPL_S     after TPD_G;
                        end if;
                     else
                        -- Try re-sampling on the next cycle (1 cycle slip)
                        bpm.phase <= "11"            after TPD_G;
                        -- Reset the non-triggers counter
                        bpm.cnt   <= (others => '0') after TPD_G;
                     end if;
                  end if;
               ----------------------------------------------------------------------
               when CH_A_SMPL_S =>
                  -- Next State
                  bpm.state <= CH_A_S after TPD_G;
               ----------------------------------------------------------------------
               when CH_A_S =>
                  -- Check for a logic low (no trigger)
                  if (bpm.serData = bpm.serDataDly) then
                     -- Strobe the channel A status signal
                     bpm.chA   <= '1'             after TPD_G;
                     -- Reset the trigger counter
                     bpm.cnt   <= (others => '0') after TPD_G;
                     -- Next State
                     bpm.state <= CH_B_SMPL_S     after TPD_G;
                  else
                     -- Check for illegal trigger length
                     if bpm.cnt = toSlv(22, 5) then
                        -- Reset the trigger counter
                        bpm.cnt    <= (others => '0') after TPD_G;
                        -- Error Detected
                        bpm.errDet <= '1'             after TPD_G;
                        -- De-assert the locked status
                        bpm.locked <= '0'             after TPD_G;
                        -- Next State
                        bpm.state  <= RESET_S         after TPD_G;
                     else
                        -- Strobe the trigger 
                        bpm.trig  <= clkLocked   after TPD_G;
                        -- Strobe the channel A status signal
                        bpm.chA   <= '1'         after TPD_G;
                        -- increment the counter
                        bpm.cnt   <= bpm.cnt + 1 after TPD_G;
                        -- Next State
                        bpm.state <= CH_B_SMPL_S after TPD_G;
                     end if;
                  end if;
               ----------------------------------------------------------------------
               when CH_B_SMPL_S =>
                  -- Next State
                  bpm.state <= CH_B_S after TPD_G;
               ----------------------------------------------------------------------
               when CH_B_S =>
                  -- Strobe the channel B status signal
                  bpm.chB   <= clkLocked                        after TPD_G;
                  -- Latch the data value
                  bpm.data  <= (bpm.serData xor bpm.serDataDly) after TPD_G;
                  -- Next State
                  bpm.state <= CH_A_SMPL_S                      after TPD_G;
            ----------------------------------------------------------------------
            end case;
         end if;
      end if;
   end process TIME_DIVISION_MULTIPLEXED;

   DESERIALIZER : process(locClk)
   begin
      if rising_edge(locClk) then
         deSer.errDet   <= '0' after TPD_G;
         deSer.bcValid  <= '0' after TPD_G;
         deSer.iacValid <= '0' after TPD_G;
         -- Check for a reset
         if locRst = '1' then
            deSer <= DESER_INIT_C after TPD_G;
         -- Check if BMP is not locked
         elsif bpm.state = RESET_S then
            deSer.state <= IDLE_S after TPD_G;
         elsif bpm.chB = '1' then
            case deSer.state is
               ----------------------------------------------------------------------
               when IDLE_S =>
                  -- Wait for the start bit
                  if bpm.data = '0' then      -- Start Bit
                     -- Next State
                     deSer.state <= FMT_S after TPD_G;
                  end if;
               ----------------------------------------------------------------------
               when FMT_S =>
                  -- Latch the format value
                  deSer.fmt      <= bpm.data        after TPD_G;
                  -- Reset the shift register
                  deSer.shiftReg <= (others => '0') after TPD_G;
                  -- Next State
                  deSer.state    <= SHIFT_REG_S     after TPD_G;
               ----------------------------------------------------------------------
               when SHIFT_REG_S =>
                  -- Shift Register
                  deSer.shiftReg(0)           <= bpm.data                    after TPD_G;
                  deSer.shiftReg(38 downto 1) <= deSer.shiftReg(37 downto 0) after TPD_G;
                  -- Increment the counter
                  deSer.cnt                   <= deSer.cnt + 1               after TPD_G;
                  -- Check if this is a BC Message or IAC message
                  if deSer.fmt = '0' then     -- BC Message
                     -- Check the counter Value
                     if deSer.cnt = 12 then   -- (8 data bits + 5 check bits - 1)
                        -- Reset the counter
                        deSer.cnt   <= (others => '0') after TPD_G;
                        -- Next State
                        deSer.state <= STOP_S          after TPD_G;
                     end if;
                  else                        -- IAC Message
                     -- Check the counter Value
                     if deSer.cnt = 38 then   -- (32 data bits + 7 check bits - 1)
                        -- Reset the counter
                        deSer.cnt   <= (others => '0') after TPD_G;
                        -- Next State
                        deSer.state <= STOP_S          after TPD_G;
                     end if;
                  end if;
               ----------------------------------------------------------------------
               when STOP_S =>
                  -- Check for a stop bit
                  if bpm.data = '1' then      -- Stop Bit
                     if deSer.fmt = '0' then  -- BC Message
                        deSer.bcValid <= '1'                         after TPD_G;
                        deSer.bcData  <= deSer.shiftReg(12 downto 5) after TPD_G;
                        deSer.bcCheck <= deSer.shiftReg(4 downto 0)  after TPD_G;
                     else                     -- IAC Message
                        deSer.iacValid <= '1'                         after TPD_G;
                        deSer.iacData  <= deSer.shiftReg(38 downto 7) after TPD_G;
                        deSer.iacCheck <= deSer.shiftReg(6 downto 0)  after TPD_G;
                     end if;
                  else
                     -- Error Detected
                     deSer.errDet <= '1' after TPD_G;
                  end if;
                  -- Next State
                  deSer.state <= IDLE_S after TPD_G;
            ----------------------------------------------------------------------
            end case;
         end if;
      end if;
   end process DESERIALIZER;
   
end rtl;
