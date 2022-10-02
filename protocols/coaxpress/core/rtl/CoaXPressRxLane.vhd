-------------------------------------------------------------------------------
-- Title      : CoaXPress Protocol: http://jiia.org/wp-content/themes/jiia/pdf/standard_dl/coaxpress/CXP-001-2021.pdf
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: CoaXPress RX FSM
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
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;
use surf.CoaXPressPkg.all;
use surf.Code8b10bPkg.all;

entity CoaXPressRxLane is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Clock and Reset
      rxClk          : in  sl;
      rxRst          : in  sl;
      -- Config Interface
      cfgMaster      : out AxiStreamMasterType;
      -- Data Interface
      dataMaster     : out AxiStreamMasterType;
      -- Heartbeat Interface
      heatbeatMaster : out AxiStreamMasterType;
      -- Image header Interface
      imageHdrMaster : out AxiStreamMasterType;
      -- ACK Interface
      ioAck          : out sl;
      eventAck       : out sl;
      eventTag       : out slv(7 downto 0);
      -- RX PHY Interface
      rxData         : in  slv(31 downto 0);
      rxDataK        : in  slv(3 downto 0);
      rxLinkUp       : in  sl);
end entity CoaXPressRxLane;

architecture rtl of CoaXPressRxLane is

   type StateType is (
      IO_ACK_S,
      IDLE_S,
      TYPE_S,
      CTRL_ACK_TAG_S,
      CTRL_ACK_S,
      HEARTBEAT_S,
      EVENT_ACK_S,
      STREAM_ID_S,
      PACKET_TAG_S,
      DSIZE_UPPER_S,
      DSIZE_LOWER_S,
      STREAM_DATA_S);

   type RegType is record
      errDet  : sl;
      -- ACK Interface
      ioAck          : sl;
      eventAck       : sl;
      eventTag       : slv(7 downto 0);
      ackCnt         : natural range 0 to 15;
      -- Stream data payload
      streamID       : slv(7 downto 0);
      packetTag      : slv(7 downto 0);
      dsize          : slv(15 downto 0);
      dcnt           : slv(15 downto 0);
      dbgCnt         : slv(31 downto 0);
      -- AXIS Interfaces
      cfgMaster      : AxiStreamMasterType;
      dataMaster     : AxiStreamMasterType;
      heatbeatMaster : AxiStreamMasterType;
      -- State Types
      saved          : StateType;
      state          : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      errDet         => '0',
      -- ACK Interface
      ioAck          => '0',
      eventAck       => '0',
      eventTag       => (others => '0'),
      ackCnt         => 0,
      -- Stream data payload
      streamID       => (others => '0'),
      packetTag      => (others => '0'),
      dsize          => (others => '0'),
      dcnt           => (others => '0'),
      dbgCnt         => (others => '0'),
      -- AXIS Interfaces
      cfgMaster      => AXI_STREAM_MASTER_INIT_C,
      dataMaster     => AXI_STREAM_MASTER_INIT_C,
      heatbeatMaster => AXI_STREAM_MASTER_INIT_C,
      -- State Types
      saved          => IDLE_S,
      state          => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- attribute dont_touch      : string;
   -- attribute dont_touch of r : signal is "TRUE";

begin

   comb : process (r, rxData, rxDataK, rxLinkUp, rxRst) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobes
      v.errDet                := '0';
      v.ioAck                 := '0';
      v.eventAck              := '0';
      v.cfgMaster.tValid      := '0';
      v.dataMaster.tValid     := '0';
      v.dataMaster.tLast      := '0';
      v.heatbeatMaster.tValid := '0';

      -- Check for I/O
      if (rxDataK = x"F") and (rxData = CXP_IO_ACK_C) then
         -- Save current state
         v.saved := r.state;
         -- Next State
         v.state := IO_ACK_S;

      -- Check for non-IDLE word
      elsif (rxDataK /= CXP_IDLE_K_C) or (rxData /= CXP_IDLE_C) then

         -- State Machine
         case r.state is
            ----------------------------------------------------------------------
            when IO_ACK_S =>
               -- Check for Trigger packet received OK
               if (rxDataK = x"0") and (rxData = x"01_01_01_01") then
                  -- Set the flag
                  v.ioAck := '1';
               end if;
               -- Next State
               v.state := r.saved;
            ----------------------------------------------------------------------
            when IDLE_S =>
               -- Reset counters
               v.ackCnt := 0;
               v.dcnt   := (others => '0');

               -- Reset data bus
               v.cfgMaster.tData := (others => '1');

               -- Check for Start of packet indication
               if (rxDataK = x"F") and (rxData = CXP_SOP_C) then
                  -- Next State
                  v.state := TYPE_S;
               end if;
            ----------------------------------------------------------------------
            when TYPE_S =>
               -- Check for non-k word
               if (rxDataK = x"0") then

                  -- Check for "Stream data packet"
                  if (rxData = x"01_01_01_01") then
                     -- Next State
                     v.state := STREAM_ID_S;

                  -- Check for "control acknowledge with no tag"
                  elsif (rxData = x"03_03_03_03") then
                     -- Next State
                     v.state := CTRL_ACK_S;

                  -- Check for "control acknowledge with tag"
                  elsif (rxData = x"06_06_06_06") then
                     -- Next State
                     v.state := CTRL_ACK_TAG_S;

                  -- Check for "control acknowledge with tag"
                  elsif (rxData = x"07_07_07_07") then
                     -- Next State
                     v.state := EVENT_ACK_S;

                  -- Check for "Heartbeat Payload"
                  elsif (rxData = x"09_09_09_09") then
                     -- Next State
                     v.state := HEARTBEAT_S;

                  -- Else undefined tag, return to IDLE
                  else
                     -- Set the flag
                     v.errDet := '1';
                     -- Next State
                     v.state := IDLE_S;
                  end if;
               else
                  -- Set the flag
                  v.errDet := '1';
                  -- Next State
                  v.state := IDLE_S;
               end if;
            ----------------------------------------------------------------------
            when CTRL_ACK_TAG_S =>
               -- Check for non-k word
               if (rxDataK = x"0") then
                  -- Next State
                  v.state := CTRL_ACK_S;
               else
                  -- Set the flag
                  v.errDet := '1';
                  -- Next State
                  v.state := IDLE_S;
               end if;
            ----------------------------------------------------------------------
            when CTRL_ACK_S =>
               -- Check for non-k word
               if (rxDataK = x"0") then

                  -- Increment the counter
                  v.ackCnt := r.ackCnt + 1;

                  -- "Acknowledgment code" index
                  if (r.ackCnt = 0) then

                     -- Save the response code
                     v.cfgMaster.tData(31 downto 0) := rxData;

                     -- Check for Success ACK
                     if (rxData = x"01_01_01_01") or (rxData = x"04_04_04_04") then
                        -- Always send ZERO for successful ACK
                        v.cfgMaster.tData(31 downto 0) := (others => '0');
                     end if;

                  -- "Data field" index
                  elsif (r.ackCnt = 2) then

                     -- Save the data field
                     v.cfgMaster.tData(63 downto 32) := rxData;

                     -- Forward the response
                     v.cfgMaster.tValid := '1';

                     -- Next State
                     v.state := IDLE_S;

                  end if;

               else
                  -- Forward the response
                  v.cfgMaster.tValid := '1';
                  -- Next State
                  v.state            := IDLE_S;
               end if;
            ----------------------------------------------------------------------
            when EVENT_ACK_S =>
               -- Check for non-k word
               if (rxDataK = x"0") then

                  -- Increment the counter
                  v.ackCnt := r.ackCnt + 1;

                  -- "Acknowledgment code" index
                  if (r.ackCnt = 4) then

                     -- Generate the ACK message w/ package tag
                     v.eventAck := '1';
                     v.eventTag := rxData(7 downto 0);

                     -- Next State
                     v.state := IDLE_S;

                  end if;

               else
                  -- Set the flag
                  v.errDet := '1';
                  -- Next State
                  v.state := IDLE_S;
               end if;
            ----------------------------------------------------------------------
            when HEARTBEAT_S =>
               -- Check for non-k word
               if (rxDataK = x"0") then

                  -- Increment the counter
                  v.ackCnt := r.ackCnt + 1;

                  -- Save the response code
                  v.heatbeatMaster.tData(8*r.ackCnt+7 downto 8*r.ackCnt) := rxData(7 downto 0);

                  -- "Acknowledgment code" index
                  if (r.ackCnt = 11) then

                     -- Forward the response
                     v.heatbeatMaster.tValid := '1';
                     v.heatbeatMaster.tLast  := '1';

                     -- Next State
                     v.state := IDLE_S;

                  end if;

               else
                  -- Set the flag
                  v.errDet := '1';
                  -- Next State
                  v.state := IDLE_S;
               end if;
            ----------------------------------------------------------------------
            when STREAM_ID_S =>
               -- Check for non-k word
               if (rxDataK = x"0")
                  and (rxData(7 downto 0) = rxData(15 downto 8))
                  and (rxData(7 downto 0) = rxData(23 downto 16))
                  and (rxData(7 downto 0) = rxData(31 downto 24)) then
                  -- Save the value
                  v.streamID := rxData(7 downto 0);
                  -- Next State
                  v.state    := PACKET_TAG_S;
               else
                  -- Set the flag
                  v.errDet := '1';
                  -- Next State
                  v.state := IDLE_S;
               end if;
            ----------------------------------------------------------------------
            when PACKET_TAG_S =>
               -- Check for non-k word
               if (rxDataK = x"0")
                  and (rxData(7 downto 0) = rxData(15 downto 8))
                  and (rxData(7 downto 0) = rxData(23 downto 16))
                  and (rxData(7 downto 0) = rxData(31 downto 24)) then
                  -- Save the value
                  v.packetTag := rxData(7 downto 0);
                  -- Next State
                  v.state     := DSIZE_UPPER_S;
               else
                  -- Set the flag
                  v.errDet := '1';
                  -- Next State
                  v.state := IDLE_S;
               end if;
            ----------------------------------------------------------------------
            when DSIZE_UPPER_S =>
               -- Check for non-k word
               if (rxDataK = x"0")
                  and (rxData(7 downto 0) = rxData(15 downto 8))
                  and (rxData(7 downto 0) = rxData(23 downto 16))
                  and (rxData(7 downto 0) = rxData(31 downto 24)) then
                  -- Set the TDEST to the packet tag
                  v.dsize(15 downto 8) := rxData(7 downto 0);
                  -- Next State
                  v.state              := DSIZE_LOWER_S;
               else
                  -- Set the flag
                  v.errDet := '1';
                  -- Next State
                  v.state := IDLE_S;
               end if;
            ----------------------------------------------------------------------
            when DSIZE_LOWER_S =>
               -- Check for non-k word
               if (rxDataK = x"0")
                  and (rxData(7 downto 0) = rxData(15 downto 8))
                  and (rxData(7 downto 0) = rxData(23 downto 16))
                  and (rxData(7 downto 0) = rxData(31 downto 24)) then
                  -- Set the TDEST to the packet tag
                  v.dsize(7 downto 0) := rxData(7 downto 0);
                  -- Next State
                  v.state             := STREAM_DATA_S;
               else
                  -- Set the flag
                  v.errDet := '1';
                  -- Next State
                  v.state := IDLE_S;
               end if;
            ----------------------------------------------------------------------
            when STREAM_DATA_S =>
               -- Move the data
               v.dataMaster.tValid             := '1';
               v.dataMaster.tData(31 downto 0) := rxData;
               v.dataMaster.tUser(3 downto 0)  := rxDataK;

               -- Increment counter
               v.dbgCnt := r.dbgCnt + 1;

               -- Check the counter
               if (r.dcnt = (r.dsize-1)) then
                  -- Terminate the frame
                  v.dataMaster.tLast := '1';

                  -- Next State
                  v.state := IDLE_S;

               else
                  -- Increment counter
                  v.dcnt := r.dcnt + 1;
               end if;
         ----------------------------------------------------------------------
         end case;

      end if;

      -- Outputs
      cfgMaster      <= r.cfgMaster;
      dataMaster     <= r.dataMaster;
      heatbeatMaster <= r.heatbeatMaster;
      ioAck          <= r.ioAck;
      eventAck       <= r.eventAck;
      eventTag       <= r.eventTag;

      -- Reset
      if (rxRst = '1') or (rxLinkUp = '0') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (rxClk) is
   begin
      if (rising_edge(rxClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
