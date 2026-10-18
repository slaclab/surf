-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Timing-capable 10GbE import leaf with XGMII interface
-------------------------------------------------------------------------------
-- Timing-mode alternative to EthMacRxImportXgmii for the timing port contract
-- (ethernet/PtpCore/timing-port.md, sections 2.4 and 3). The per-lane
-- decoder follows PtpRxTimestampAdapter exactly: /S/ in lane 0 or 4, six
-- 0x55 data octets and a data-valued 0xD5; /T/ ends the frame; any other
-- control octet inside a frame (including a nested /S/) terminates it with
-- an error and drains to /T/. A start that does not qualify is reported as
-- lost and produces no beats.
--
-- start is registered on the edge that samples the word holding the first
-- destination-MAC octet, with that octet's lane, which is the edge on which
-- the passive adapter registers its capture. The token sampled from
-- nextToken on that edge is stamped on every beat; a frame started with
-- EMAC_TOKEN_NONE_C produces no beats but still publishes start and done.
-- Frame octets pass through a byte buffer that holds back four octets (the
-- FCS), so beats are FCS-stripped; the last beat carries EOFE for a CRC
-- error, an error termination or link loss, and done reports the frame.
-- A start whose frame ends with no byte beyond its four FCS octets publishes
-- a retire instead of done. phyReady falling while a frame is open ends it.
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.CrcPkg.all;
use surf.EthMacPkg.all;

entity EthMacRxImportTimingXgmii is
   generic (
      TPD_G          : time                := 1 ns;
      RST_POLARITY_G : sl                  := '1';  -- '1' for active HIGH reset, '0' for active LOW reset
      -- MAC-internal stream format; must carry the eight-bit TID token.
      INT_CONFIG_G   : AxiStreamConfigType := EMAC_TIMING_AXIS_CONFIG_C);
   port (
      -- Clock and Reset
      ethClk      : in  sl;
      ethRst      : in  sl;
      -- AXIS Interface
      macIbMaster : out AxiStreamMasterType;
      -- PHY Interface
      phyRxdata   : in  slv(63 downto 0);
      phyRxChar   : in  slv(7 downto 0);
      -- Configuration and status
      phyReady    : in  sl;
      rxCountEn   : out sl;
      rxCrcError  : out sl;
      -- Timing port: allocation offered for the next start, and wire events
      nextToken   : in  EthMacTokenType;
      frameEvent  : out EthMacFrameEventType;
      retire      : out EthMacTokenRetireType);
end EthMacRxImportTimingXgmii;

architecture rtl of EthMacRxImportTimingXgmii is

   constant START_C           : slv(7 downto 0)  := x"FB";
   constant TERMINATE_C       : slv(7 downto 0)  := x"FD";
   constant PREAMBLE_C        : slv(7 downto 0)  := x"55";
   constant SFD_C             : slv(7 downto 0)  := x"D5";
   -- /S/ replaces the first of the seven preamble octets
   constant PREAMBLE_OCTETS_C : positive         := 6;
   constant FCS_BYTES_C       : positive         := 4;
   constant CRC_INIT_C        : slv(31 downto 0) := x"FFFFFFFF";
   constant CRC_RESIDUE_C     : slv(31 downto 0) := x"C704DD7B";
   -- Buffer: four held-back octets, up to eight more, and one input word
   constant BUF_BYTES_C       : positive         := 20;

   constant AXI_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => INT_CONFIG_G.TSTRB_EN_C,
      TDATA_BYTES_C => 8,               -- 64-bit AXI stream interface
      TDEST_BITS_C  => INT_CONFIG_G.TDEST_BITS_C,
      TID_BITS_C    => INT_CONFIG_G.TID_BITS_C,
      TKEEP_MODE_C  => INT_CONFIG_G.TKEEP_MODE_C,
      TUSER_BITS_C  => INT_CONFIG_G.TUSER_BITS_C,
      TUSER_MODE_C  => INT_CONFIG_G.TUSER_MODE_C);

   -- CRC32 over the first n octets of a word (lane 0 first). CrcPkg takes
   -- the first octet at the high end with each octet bit-reversed.
   function crcWord (crc : slv(31 downto 0); word : slv(63 downto 0); n : natural range 1 to 8) return slv is
      variable data : slv(63 downto 0);
   begin
      for i in 0 to 7 loop
         data(63-8*i downto 56-8*i) := bitReverse(word(8*i+7 downto 8*i));
      end loop;
      case n is
         when 1      => return crc32Parallel1Byte(crc, data(63 downto 56));
         when 2      => return crc32Parallel2Byte(crc, data(63 downto 48));
         when 3      => return crc32Parallel3Byte(crc, data(63 downto 40));
         when 4      => return crc32Parallel4Byte(crc, data(63 downto 32));
         when 5      => return crc32Parallel5Byte(crc, data(63 downto 24));
         when 6      => return crc32Parallel6Byte(crc, data(63 downto 16));
         when 7      => return crc32Parallel7Byte(crc, data(63 downto 8));
         when others => return crc32Parallel8Byte(crc, data);
      end case;
   end function crcWord;

   -- SEARCH_S waits for /S/; PREAMBLE_S qualifies the preamble and SFD;
   -- FRAME_S carries the frame; DRAIN_S discards until /T/.
   type StateType is (
      SEARCH_S,
      PREAMBLE_S,
      FRAME_S,
      DRAIN_S);

   type RegType is record
      state      : StateType;
      preamble   : natural range 0 to PREAMBLE_OCTETS_C;
      first      : sl;
      token      : EthMacTokenType;
      owned      : sl;
      crc        : slv(31 downto 0);
      buf        : slv(8*BUF_BYTES_C-1 downto 0);
      bufCount   : natural range 0 to BUF_BYTES_C;
      sofPending : sl;
      length     : slv(15 downto 0);
      tailValid  : sl;
      tailData   : slv(63 downto 0);
      tailBytes  : natural range 0 to 8;
      tailSof    : sl;
      tailError  : sl;
      tailToken  : EthMacTokenType;
      macMaster  : AxiStreamMasterType;
      rxCountEn  : sl;
      rxCrcError : sl;
      frameEvent : EthMacFrameEventType;
      retire     : EthMacTokenRetireType;
   end record;

   constant REG_INIT_C : RegType := (
      state      => SEARCH_S,
      preamble   => 0,
      first      => '0',
      token      => EMAC_TOKEN_NONE_C,
      owned      => '0',
      crc        => CRC_INIT_C,
      buf        => (others => '0'),
      bufCount   => 0,
      sofPending => '0',
      length     => (others => '0'),
      tailValid  => '0',
      tailData   => (others => '0'),
      tailBytes  => 0,
      tailSof    => '0',
      tailError  => '0',
      tailToken  => EMAC_TOKEN_NONE_C,
      macMaster  => AXI_STREAM_MASTER_INIT_C,
      rxCountEn  => '0',
      rxCrcError => '0',
      frameEvent => ETH_MAC_FRAME_EVENT_INIT_C,
      retire     => ETH_MAC_TOKEN_RETIRE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal macMaster : AxiStreamMasterType;

begin

   assert INT_CONFIG_G.TID_BITS_C = EMAC_TOKEN_BITS_C
      report "EthMacRxImportTimingXgmii: INT_CONFIG_G must carry the eight-bit token in TID"
      severity failure;

   U_Resize : entity surf.AxiStreamResize
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         RST_POLARITY_G      => RST_POLARITY_G,
         READY_EN_G          => false,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => AXI_CONFIG_C,  --  64-bit AXI stream interface
         MASTER_AXI_CONFIG_G => INT_CONFIG_G)  -- 128-bit AXI stream interface
      port map (
         -- Clock and reset
         axisClk     => ethClk,
         axisRst     => ethRst,
         -- Slave Port
         sAxisMaster => macMaster,      -- 64-bit AXI stream interface
         sAxisSlave  => open,
         -- Master Port
         mAxisMaster => macIbMaster,    -- 128-bit AXI stream interface
         mAxisSlave  => AXI_STREAM_SLAVE_FORCE_C);

   comb : process (ethRst, nextToken, phyReady, phyRxChar, phyRxdata, r) is
      variable v         : RegType;
      variable octet     : slv(7 downto 0);
      variable word      : slv(63 downto 0);
      variable count     : natural range 0 to 8;
      variable startWord : sl;
      variable startLane : natural range 0 to 7;
      variable terminate : sl;
      variable termGood  : sl;
      variable payload   : integer range -FCS_BYTES_C to BUF_BYTES_C;
      variable crcGood   : sl;
      variable shifted   : slv(8*BUF_BYTES_C-1 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Reset the pulses and the single-beat output
      v.rxCountEn        := '0';
      v.rxCrcError       := '0';
      v.frameEvent       := ETH_MAC_FRAME_EVENT_INIT_C;
      v.retire           := ETH_MAC_TOKEN_RETIRE_INIT_C;
      v.macMaster        := AXI_STREAM_MASTER_INIT_C;
      v.macMaster.tKeep  := (others => '0');

      word      := (others => '0');
      count     := 0;
      startWord := '0';
      startLane := 0;
      terminate := '0';
      termGood  := '0';

      -- A tail beat left from the previous frame end goes out first. The next
      -- frame cannot emit a beat in this cycle: its first destination-MAC
      -- word holds at most eight octets, below the emission threshold, and a
      -- frame ending in that same word has no octet beyond its FCS.
      if (r.tailValid = '1') then
         v.tailValid                                   := '0';
         v.macMaster.tValid                            := '1';
         v.macMaster.tLast                             := '1';
         v.macMaster.tData(63 downto 0)                := r.tailData;
         v.macMaster.tId(EMAC_TOKEN_BITS_C-1 downto 0) := r.tailToken;
         for i in 0 to 7 loop
            if (i < r.tailBytes) then
               v.macMaster.tKeep(i) := '1';
            end if;
         end loop;
         axiStreamSetUserBit(AXI_CONFIG_C, v.macMaster, EMAC_SOF_BIT_C, r.tailSof, 0);
         axiStreamSetUserBit(AXI_CONFIG_C, v.macMaster, EMAC_EOFE_BIT_C, r.tailError);
      end if;

      -- Decode lanes in wire order exactly as the passive adapter does. A
      -- delimiter in an earlier lane changes how later lanes of the word are
      -- read; frame octets are packed into the low lanes of word.
      if (phyReady = '1') then
         for lane in 0 to 7 loop
            octet := phyRxdata(8*lane+7 downto 8*lane);
            case v.state is
               when SEARCH_S =>
                  if (phyRxChar(lane) = '1') and (octet = START_C) then
                     if (lane = 0) or (lane = 4) then
                        v.state    := PREAMBLE_S;
                        v.preamble := 0;
                     else
                        v.frameEvent.lost := '1';
                     end if;
                  end if;
               when PREAMBLE_S =>
                  if (phyRxChar(lane) = '0') and (octet = PREAMBLE_C) and (v.preamble < PREAMBLE_OCTETS_C) then
                     v.preamble := v.preamble + 1;
                  elsif (phyRxChar(lane) = '0') and (octet = SFD_C) and (v.preamble = PREAMBLE_OCTETS_C) then
                     v.state := FRAME_S;
                     v.first := '1';
                  else
                     v.frameEvent.lost := '1';
                     v.state           := DRAIN_S;
                     if (phyRxChar(lane) = '1') and (octet = TERMINATE_C) then
                        v.state := SEARCH_S;
                     end if;
                  end if;
               when FRAME_S =>
                  if (phyRxChar(lane) = '0') then
                     if (v.first = '1') then
                        startWord := '1';
                        startLane := lane;
                        v.first   := '0';
                     end if;
                     word(8*count+7 downto 8*count) := octet;
                     count                          := count + 1;
                  else
                     if (v.first = '1') then
                        -- No destination-MAC octet: no capture, no start
                        v.frameEvent.lost := '1';
                        v.first           := '0';
                     else
                        terminate := '1';
                        if (octet = TERMINATE_C) then
                           termGood := '1';
                        end if;
                     end if;
                     if (octet = TERMINATE_C) then
                        v.state := SEARCH_S;
                     else
                        -- A nested /S/ is a start that cannot be qualified
                        if (octet = START_C) then
                           v.frameEvent.lost := '1';
                        end if;
                        v.state := DRAIN_S;
                     end if;
                  end if;
               when DRAIN_S =>
                  if (phyRxChar(lane) = '1') and (octet = TERMINATE_C) then
                     v.state := SEARCH_S;
                  elsif (phyRxChar(lane) = '1') and (octet = START_C) then
                     v.frameEvent.lost := '1';
                  end if;
            end case;
         end loop;
      elsif (r.state = FRAME_S) and (r.first = '0') then
         -- Link loss ends the open frame
         terminate := '1';
      end if;

      -- Start: this edge samples the first destination-MAC octet
      if (startWord = '1') then
         v.token                 := nextToken;
         v.owned                 := '0';
         v.crc                   := CRC_INIT_C;
         v.buf                   := (others => '0');
         v.bufCount              := 0;
         v.sofPending            := '1';
         v.length                := (others => '0');
         v.frameEvent.start      := '1';
         v.frameEvent.startLane  := slv(to_unsigned(startLane, 3));
         v.frameEvent.startToken := nextToken;
         if (nextToken /= EMAC_TOKEN_NONE_C) then
            v.owned := '1';
         end if;
      end if;

      -- Frame octets: CRC and the hold-back buffer
      if (count /= 0) then
         v.crc := crcWord(v.crc, word, count);
         for i in 0 to 7 loop
            if (i < count) then
               v.buf(8*(v.bufCount+i)+7 downto 8*(v.bufCount+i)) := word(8*i+7 downto 8*i);
            end if;
         end loop;
         v.bufCount := v.bufCount + count;
      end if;

      -- Emit one full beat once thirteen octets are buffered: four may be
      -- FCS and at least one more is kept, so the last beat is never empty
      if (terminate = '0') and (v.bufCount > 8 + FCS_BYTES_C) then
         if (v.owned = '1') then
            v.macMaster.tValid                            := '1';
            v.macMaster.tData(63 downto 0)                := v.buf(63 downto 0);
            v.macMaster.tKeep(7 downto 0)                 := x"FF";
            v.macMaster.tId(EMAC_TOKEN_BITS_C-1 downto 0) := v.token;
            axiStreamSetUserBit(AXI_CONFIG_C, v.macMaster, EMAC_SOF_BIT_C, v.sofPending, 0);
         end if;
         v.sofPending := '0';
         v.length     := slv(unsigned(v.length) + 8);
         shifted      := (others => '0');
         shifted(8*(BUF_BYTES_C-8)-1 downto 0) := v.buf(8*BUF_BYTES_C-1 downto 64);
         v.buf        := shifted;
         v.bufCount   := v.bufCount - 8;
      end if;

      -- Frame end: remaining payload with tLast (spilling to one tail beat)
      -- and exactly one terminal event for the token sampled at start
      if (terminate = '1') then
         crcGood := '0';
         if (termGood = '1') and (v.crc = CRC_RESIDUE_C) then
            crcGood := '1';
         end if;
         payload := v.bufCount - FCS_BYTES_C;

         if (unsigned(v.length) = 0) and (payload <= 0) and (v.owned = '1') then
            -- No frame byte beyond the FCS octets: nothing was delivered
            v.retire.valid := '1';
            v.retire.token := v.token;
         else
            if (payload < 0) then
               payload := 0;
            end if;
            if (v.owned = '1') then
               if (payload > 8) then
                  -- Full beat now, the rest as the tail beat next cycle
                  v.macMaster.tValid                            := '1';
                  v.macMaster.tData(63 downto 0)                := v.buf(63 downto 0);
                  v.macMaster.tKeep(7 downto 0)                 := x"FF";
                  v.macMaster.tId(EMAC_TOKEN_BITS_C-1 downto 0) := v.token;
                  axiStreamSetUserBit(AXI_CONFIG_C, v.macMaster, EMAC_SOF_BIT_C, v.sofPending, 0);
                  v.tailValid := '1';
                  v.tailData  := v.buf(127 downto 64);
                  v.tailBytes := payload - 8;
                  v.tailSof   := '0';
                  v.tailError := not crcGood;
                  v.tailToken := v.token;
               elsif (payload > 0) then
                  v.macMaster.tValid                            := '1';
                  v.macMaster.tLast                             := '1';
                  v.macMaster.tData(63 downto 0)                := v.buf(63 downto 0);
                  v.macMaster.tId(EMAC_TOKEN_BITS_C-1 downto 0) := v.token;
                  for i in 0 to 7 loop
                     if (i < payload) then
                        v.macMaster.tKeep(i) := '1';
                     end if;
                  end loop;
                  axiStreamSetUserBit(AXI_CONFIG_C, v.macMaster, EMAC_SOF_BIT_C, v.sofPending, 0);
                  axiStreamSetUserBit(AXI_CONFIG_C, v.macMaster, EMAC_EOFE_BIT_C, not crcGood);
               else
                  -- The held-back octets were all FCS: close with an empty tLast
                  v.macMaster.tValid                            := '1';
                  v.macMaster.tLast                             := '1';
                  v.macMaster.tId(EMAC_TOKEN_BITS_C-1 downto 0) := v.token;
                  axiStreamSetUserBit(AXI_CONFIG_C, v.macMaster, EMAC_EOFE_BIT_C, not crcGood);
               end if;
            end if;
            v.frameEvent.done       := '1';
            v.frameEvent.doneError  := not crcGood;
            v.frameEvent.doneLength := slv(unsigned(v.length) + payload);
            v.frameEvent.doneToken  := v.token;
            v.rxCountEn             := crcGood;
            v.rxCrcError            := not crcGood;
         end if;

         v.owned    := '0';
         v.token    := EMAC_TOKEN_NONE_C;
         v.bufCount := 0;
      end if;

      -- The passive adapter is held in reset while the PHY is not ready
      if (phyReady = '0') then
         v.state    := SEARCH_S;
         v.first    := '0';
         v.preamble := 0;
      end if;

      -- Reset
      if (ethRst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      macMaster  <= r.macMaster;
      rxCountEn  <= r.rxCountEn;
      rxCrcError <= r.rxCrcError;
      frameEvent <= r.frameEvent;
      retire     <= r.retire;

   end process comb;

   seq : process (ethClk) is
   begin
      if rising_edge(ethClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
