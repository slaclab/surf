-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: AXI4-Stream Timer block File
-------------------------------------------------------------------------------
-- This file is part of 'SNL GRIDNET'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SNL GRIDNET', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;

entity AxiStreamTimer is
   generic (
      TPD_G             : time                 := 1 ns;
      EVENT_NUM_G       : integer range 1 to 7 := 1
   );
   port (
        -- AXI-Stream interfaces
      axisClk           : in sl;
      axisRst           : in sl;
      startStreamMaster : in AxiStreamMasterType;
      startStreamSlave  : in AxiStreamSlaveType;
      stopStreamMaster  : in AxiStreamMasterType;
      stopStreamSlave   : in AxiStreamSlaveType;


        -- AXI-Lite Interface
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType
    );
end AxiStreamTimer;

architecture rtl of AxiStreamTimer is

    -- Internal AXI Lite synced with axisClk
   signal axilReadIntMaster  : AxiLiteReadMasterType;
   signal axilReadIntSlave   : AxiLiteReadSlaveType;
   signal axilWriteIntMaster : AxiLiteWriteMasterType;
   signal axilWriteIntSlave  : AxiLiteWriteSlaveType;

   constant READ_REGISTER_NUM_C : integer := 4*EVENT_NUM_G+1;

   signal writeRegister  : Slv32Array(0           downto 0);
   signal readRegister   : Slv32Array(READ_REGISTER_NUM_C-1 downto 0) := (others => (others => '0'));

   type StateType is (
      IDLE_S,
      RUNNING_S,
      DONE_S);

   type EventType is record
      startSof    : Slv32Array(EVENT_NUM_G-1 downto 0);
      startEof    : Slv32Array(EVENT_NUM_G-1 downto 0);
      stopSof     : Slv32Array(EVENT_NUM_G-1 downto 0);
      stopEof     : Slv32Array(EVENT_NUM_G-1 downto 0);
      startSofidx : integer range 0 to 6;
      startEofidx : integer range 0 to 6;
      stopSofidx  : integer range 0 to 6;
      stopEofidx  : integer range 0 to 6;
      wasStartEof : sl;
      wasStopEof  : sl;
   end record;

   constant EVENT_INIT_C : EventType := (
        startSof     => (others => (others => '0')),
        startEof     => (others => (others => '0')),
        stopSof      => (others => (others => '0')),
        stopEof      => (others => (others => '0')),
        startSofidx  => 0,
        startEofidx  => 0,
        stopSofidx   => 0,
        stopEofidx   => 0,
        wasStartEof  => '1',
        wasStopEof   => '1');

   type RegType is record
      timer      : slv(31 downto 0);
      state      : StateType;
      eventTimes : EventType;
   end record;

   constant REG_INIT_C : RegType := (
        timer => (others => '0'),
        state => IDLE_S,
        eventTimes => EVENT_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (startStreamMaster, startStreamSlave, stopStreamMaster, stopStreamSlave, writeRegister, axisRst, r) is
      variable v               : RegType;
      variable handshakeStart  : sl;
      variable handshakeStop   : sl;
      variable hasStartSof     : sl;
      variable hasStartEof     : sl;
      variable hasStopSof      : sl;
      variable hasStopEof      : sl;
      variable notDoneStartSof : sl;
      variable notDoneStartEof : sl;
      variable notDoneStopSof  : sl;
      variable notDoneStopEof  : sl;
   begin
        -- Latch current value
        v := r;

        -- Find handshakes
        handshakeStart := startStreamMaster.tValid and startStreamSlave.tReady;
        handshakeStop  := stopStreamMaster.tValid  and stopStreamSlave.tReady;

        -- Detect events
        hasStartSof := handshakeStart and r.eventTimes.wasStartEof;
        hasStartEof := handshakeStart and startStreamMaster.tLast;
        hasStopSof  := handshakeStop  and r.eventTimes.wasStopEof;
        hasStopEof  := handshakeStop  and stopStreamMaster.tLast;

        -- Update future handshakes
      if handshakeStart = '1' then
            v.eventTimes.wasStartEof := startStreamMaster.tLast;
      end if;
      if handshakeStop = '1' then
            v.eventTimes.wasStopEof  := stopStreamMaster.tLast;
      end if;

        -- Check if we are done with listening for events
      if r.eventTimes.startSofidx /= EVENT_NUM_G then
            notDoneStartSof := '1';
      else
            notDoneStartSof := '0';
      end if;

      if r.eventTimes.startEofidx /= EVENT_NUM_G then
            notDoneStartEof := '1';
      else
            notDoneStartEof := '0';
      end if;

      if r.eventTimes.stopSofidx  /= EVENT_NUM_G then
            notDoneStopSof  := '1';
      else
            notDoneStopSof  := '0';
      end if;

      if r.eventTimes.stopEofidx  /= EVENT_NUM_G then
            notDoneStopEof  := '1';
      else
            notDoneStopEof  := '0';
      end if;

        -- State machine
      case (r.state) is
         when IDLE_S =>
            if (writeRegister(0)(0) = '1') then
                    v.state := RUNNING_S;
                    v.timer := (others => '0');
                    v.eventTimes := EVENT_INIT_C;
            end if;
         when RUNNING_S =>
                -- Increment timer
                v.timer := r.timer + 1;

                -- Listen for events
            if (hasStartSof = '1' and notDoneStartSof = '1') then
                    v.eventTimes.startSof(r.eventTimes.startSofidx) := v.timer;
                    v.eventTimes.startSofidx := r.eventTimes.startSofidx + 1;
            end if;
            if (hasStartEof = '1' and notDoneStartEof = '1') then
                    v.eventTimes.startEof(r.eventTimes.startEofidx) := v.timer;
                    v.eventTimes.startEofidx := r.eventTimes.startEofidx + 1;
            end if;
            if (hasStopSof = '1' and notDoneStopSof = '1') then
                    v.eventTimes.stopSof(r.eventTimes.stopSofidx) := v.timer;
                    v.eventTimes.stopSofidx := r.eventTimes.stopSofidx + 1;
            end if;
            if (hasStopEof = '1' and notDoneStopEof = '1') then
                    v.eventTimes.stopEof(r.eventTimes.stopEofidx) := v.timer;
                    v.eventTimes.stopEofidx := r.eventTimes.stopEofidx + 1;
            end if;

                -- Check DONE conditions
            if ((notDoneStartSof or notDoneStartEof or notDoneStopSof or notDoneStopEof) = '0') then
                    v.state := DONE_S;
            end if;

         when DONE_S =>
            if (writeRegister(0)(0) = '0') then
                    v := REG_INIT_C;
            end if;
         when others =>
                v := REG_INIT_C;
      end case;

        -- Reset logic
      if (axisRst = '1') then
            v := REG_INIT_C;
      end if;

        -- Register the variable for next clock cycle
      rin <= v;

        -- Send outputs to regs
      readRegister(0) <= std_logic_vector(to_unsigned(EVENT_NUM_G, readRegister(0)'length));
      readRegister(EVENT_NUM_G    downto  1) <= r.eventTimes.startSof;
      readRegister(EVENT_NUM_G+ 7 downto  8) <= r.eventTimes.startEof;
      readRegister(EVENT_NUM_G+14 downto 15) <= r.eventTimes.stopSof;
      readRegister(EVENT_NUM_G+21 downto 22) <= r.eventTimes.stopEof;
   end process comb;

   seq : process (axisClk) is
   begin
      if rising_edge(axisClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

    -- Get registers to/from AXI Lite
   U_AXIL_REGS : entity surf.AxiLiteRegs
      generic map(
         TPD_G => TPD_G,
         NUM_WRITE_REG_G => 1,
         NUM_READ_REG_G  => READ_REGISTER_NUM_C)
      port map(
         axiClk        => axisClk,
         axiClkRst     => axisRst,
         axiReadMaster  => axilReadIntMaster,
         axiReadSlave   => axilReadIntSlave,
         axiWriteMaster => axilWriteIntMaster,
         axiWriteSlave  => axilWriteIntSlave,
         writeRegister  => writeRegister,
         readRegister   => readRegister);

    -- Synch AXI Lite with axisClk
   U_AXIL_CDC : entity surf.AxiLiteAsync
      generic map(
         TPD_G => TPD_G)
      port map(
         sAxiClk         => axilClk,
         sAxiClkRst      => axilRst,
         sAxiReadMaster  => axilReadMaster,
         sAxiReadSlave   => axilReadSlave,
         sAxiWriteMaster => axilWriteMaster,
         sAxiWriteSlave  => axilWriteSlave,

         mAxiClk         => axisClk,
         mAxiClkRst      => axisRst,
         mAxiReadMaster  => axilReadIntMaster,
         mAxiReadSlave   => axilReadIntSlave,
         mAxiWriteMaster => axilWriteIntMaster,
         mAxiWriteSlave  => axilWriteIntSlave);

end rtl;
