-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- AXI4-Stream Timer IP allowing to monitor NUM_EVENT_G start-of-frame and
-- end-of-frame events on NUM_STREAMS_G
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
      TPD_G             : time                  := 1 ns;
      NUM_STREAMS_G     : integer range 1 to 8  := 1;
      NUM_EVENT_G       : integer range 1 to 16 := 1
   );
   port (
      -- AXI-Stream interfaces
      axisClk         : in sl;
      axisRst         : in sl;
      streamMasters   : in AxiStreamMasterArray(NUM_STREAMS_G-1 downto 0);
      streamSlaves    : in AxiStreamSlaveArray(NUM_STREAMS_G-1 downto 0);

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

   type StateType is (
      IDLE_S,
      RUNNING_S,
      DONE_S);

   type ChannelStateType is record
      timeSof : Slv32Array(NUM_EVENT_G-1 downto 0);
      timeEof : Slv32Array(NUM_EVENT_G-1 downto 0);
      sofIdx  : integer range 0 to NUM_EVENT_G;
      eofIdx  : integer range 0 to NUM_EVENT_G;
      wasEof  : sl;
   end record;

   constant CHANNEL_STATE_INIT_C : ChannelStateType := (
      timeSof => (others => (others => '0')),
      timeEof => (others => (others => '0')),
      sofIdx  => 0,
      eofIdx  => 0,
      wasEof  => '1');

   type ChannelStateArray is array (natural range <>) of ChannelStateType;

   type RegType is record
      timer          : slv(31 downto 0);
      state          : StateType;
      channels       : ChannelStateArray(NUM_STREAMS_G-1 downto 0);
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
      runCmd         : sl;
   end record;

   constant REG_INIT_C : RegType := (
      timer          => (others => '0'),
      state          => IDLE_S,
      channels       => (others => CHANNEL_STATE_INIT_C),
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      runCmd         => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- Procedure used to monitor a single channel
   procedure monitorChannel(
      timer      : slv(31 downto 0);
      axisMaster : in AxiStreamMasterType;
      axisSlave  : in AxiStreamSlaveType;
      channel    : in ChannelStateType;
      variable vchannel   : inout ChannelStateType;
      variable notDoneSof : inout sl;
      variable notDoneEof : inout sl)
   is
      variable handshake  : sl;
      variable hasSof     : sl;
      variable hasEof     : sl;
   begin
      -- Find handshake
      handshake := axisMaster.tValid and axisSlave.tReady;

      -- Detect events
      hasSof := handshake and channel.wasEof;
      hasEof := handshake and axisMaster.tLast;

      -- Update future handshakes
      if handshake = '1' then
         vchannel.wasEof := axisMaster.tLast;
      end if;

      -- Check if we are done with listening for events
      if channel.sofIdx /= NUM_EVENT_G then
         notDoneSof := '1';
      else
         notDoneSof := '0';
      end if;

      if channel.eofIdx /= NUM_EVENT_G then
         notDoneEof := '1';
      else
         notDoneEof := '0';
      end if;

      if (hasSof = '1' and notDoneSof = '1') then
         vchannel.timeSof(channel.sofIdx) := timer;
         vchannel.sofIdx := channel.sofIdx + 1;
      end if;

      if (hasEof = '1' and notDoneEof = '1') then
         vchannel.timeEof(channel.eofIdx) := timer;
         vchannel.eofIdx := channel.eofIdx + 1;
      end if;
   end procedure;

begin

   comb : process (streamMasters, streamSlaves, axisRst, r, axilWriteIntMaster, axilReadIntMaster) is
      variable v           : RegType;
      variable notDoneSofs : slv(NUM_STREAMS_G-1 downto 0);
      variable notDoneEofs : slv(NUM_STREAMS_G-1 downto 0);
      variable axilEp      : AxiLiteEndPointType;
   begin
      -- Latch current value
      v := r;

      -- State machine
      case (r.state) is
         when IDLE_S =>
            if (r.runCmd = '1') then
               v.state    := RUNNING_S;
               v.timer    := (others => '0');
               v.channels := (others => CHANNEL_STATE_INIT_C);
            end if;
         when RUNNING_S =>
            -- Increment timer
            v.timer := r.timer + 1;

            -- Create monitor all streams
            for ch in NUM_STREAMS_G-1 downto 0 loop
               monitorChannel(r.timer, streamMasters(ch), streamSlaves(ch), r.channels(ch), v.channels(ch), notDoneSofs(ch), notDoneEofs(ch));
            end loop;

            -- Check DONE conditions
            if ((uOr(notDoneSofs) or uOr(notDoneEofs)) = '0') then
               v.state := DONE_S;
            end if;

         when DONE_S =>
            if (r.runCmd = '0') then
               v := REG_INIT_C;
            end if;
         when others =>
            v := REG_INIT_C;
      end case;

      -- Axi Lite registers
      axiSlaveWaitTxn(axilEp, axilWriteIntMaster, axilReadIntMaster, v.axilWriteSlave, v.axilReadSlave);
      axiSlaveRegister(axilEp, toSlv(0, 11), 0, v.runCmd);
      axiSlaveRegisterR(axilEp, toSlv(4, 11), 0, toSlv(NUM_STREAMS_G, 32));
      axiSlaveRegisterR(axilEp, toSlv(8, 11), 0, toSlv(NUM_EVENT_G, 32));

      for ev in NUM_EVENT_G-1 downto 0 loop
         for ch in NUM_STREAMS_G-1 downto 0 loop
            axiSlaveRegisterR(axilEp, toSlv(12+(ch*8)+(8*NUM_STREAMS_G*ev), 11), 0, r.channels(ch).timeSof(ev));
            axiSlaveRegisterR(axilEp, toSlv(16+(ch*8)+(8*NUM_STREAMS_G*ev), 11), 0, r.channels(ch).timeEof(ev));
         end loop;
      end loop;

      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);

      -- Reset logic
      if (axisRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Write outputs
      axilReadIntSlave  <= r.axilReadSlave;
      axilWriteIntSlave <= r.axilWriteSlave;
   end process comb;

   seq : process (axisClk) is
   begin
      if rising_edge(axisClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

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
