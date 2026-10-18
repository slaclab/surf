-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Timing-capable 10GbE export leaf with XGMII interface
-------------------------------------------------------------------------------
-- Timing-mode alternative to EthMacTxExportXgmii for the timing port contract
-- (ethernet/PtpCore/timing-port.md, sections 2.4 and 4.0). Each cycle the
-- leaf fetches one 64-bit word (input, or zero padding to 60 bytes) into a
-- hold register and the running CRC, and drives the previous word onto the
-- registered pins; the last word is followed by its FCS and /T/, spilling
-- into one tail word when needed. Frames always start in lane 0, so the first
-- destination-MAC octet is lane 0 of the word after the preamble.
--
-- start is registered one edge after that word is launched, from the leaf's
-- own registered pins, which is the edge on which the passive TX tap
-- registers its capture. done reports the word holding the last FCS octet;
-- an EOFE input frame is sent with an inverted FCS and doneError. Underrun,
-- link loss or forced abort while a frame is on the pins ends it with /E/ and
-- /T/ in lanes 0 and 1, drains only an outstanding input remainder and then
-- publishes done with doneError. A frame offered while the PHY is not ready
-- is dumped through tLast with one retire. Token zero (generated pause
-- frames) publishes no done or retire.
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

entity EthMacTxExportTimingXgmii is
   generic (
      TPD_G          : time                := 1 ns;
      RST_POLARITY_G : sl                  := '1';  -- '1' for active HIGH reset, '0' for active LOW reset
      -- MAC-internal stream format; must carry the eight-bit TID token.
      INT_CONFIG_G   : AxiStreamConfigType := EMAC_TIMING_AXIS_CONFIG_C;
      SYNTH_MODE_G   : string              := "inferred");  -- Synthesis mode for internal RAMs
   port (
      -- Clock and Reset
      ethClk         : in  sl;
      ethRst         : in  sl;
      -- AXIS Interface
      macObMaster    : in  AxiStreamMasterType;
      macObSlave     : out AxiStreamSlaveType;
      -- XGMII PHY Interface
      phyTxd         : out slv(63 downto 0);
      phyTxc         : out slv(7 downto 0);
      phyReady       : in  sl;
      -- Status
      txCountEn      : out sl;
      txUnderRun     : out sl;
      txLinkNotReady : out sl;
      -- Timing port wire events and forced abort
      frameEvent     : out EthMacFrameEventType;
      retire         : out EthMacTokenRetireType;
      abortReq       : in  sl := '0';
      abortAck       : out sl);
end EthMacTxExportTimingXgmii;

architecture rtl of EthMacTxExportTimingXgmii is

   constant IDLE_WORD_C     : slv(63 downto 0) := x"0707070707070707";
   constant PREAMBLE_WORD_C : slv(63 downto 0) := x"D5555555555555FB";
   constant TERMINATE_C     : slv(7 downto 0)  := x"FD";
   constant ERROR_C         : slv(7 downto 0)  := x"FE";
   constant IDLE_C          : slv(7 downto 0)  := x"07";
   constant MIN_FRAME_C     : natural          := 60;
   -- Idle words after each terminating word: at least 16 idle octets
   constant IFG_WORDS_C     : natural          := 2;
   constant CRC_INIT_C      : slv(31 downto 0) := x"FFFFFFFF";

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

   -- FCS octet j (0 is sent first) for a CRC register value
   function fcsOctet (crc : slv(31 downto 0); j : natural range 0 to 3) return slv is
   begin
      return bitReverse(not crc(31-8*j downto 24-8*j));
   end function fcsOctet;

   type StateType is (
      IDLE_S,
      DATA_S,
      TAIL_S,
      ABORT_S,
      DUMP_S);

   type RegType is record
      state          : StateType;
      gap            : natural range 0 to IFG_WORDS_C;
      token          : EthMacTokenType;
      inputEofSeen   : sl;
      dumpDone       : sl;
      error          : sl;
      crc            : slv(31 downto 0);
      length         : slv(15 downto 0);
      holdData       : slv(63 downto 0);
      holdBytes      : natural range 0 to 8;
      holdLast       : sl;
      tailFcs        : slv(31 downto 0);
      tailFrom       : natural range 0 to 4;
      phyTxd         : slv(63 downto 0);
      phyTxc         : slv(7 downto 0);
      pinPreamble    : sl;
      txCountEn      : sl;
      txUnderRun     : sl;
      txLinkNotReady : sl;
      frameEvent     : EthMacFrameEventType;
      retire         : EthMacTokenRetireType;
      abortAck       : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state          => IDLE_S,
      gap            => IFG_WORDS_C,
      token          => EMAC_TOKEN_NONE_C,
      inputEofSeen   => '0',
      dumpDone       => '0',
      error          => '0',
      crc            => CRC_INIT_C,
      length         => (others => '0'),
      holdData       => (others => '0'),
      holdBytes      => 0,
      holdLast       => '0',
      tailFcs        => (others => '0'),
      tailFrom       => 0,
      phyTxd         => IDLE_WORD_C,
      phyTxc         => x"FF",
      pinPreamble    => '0',
      txCountEn      => '0',
      txUnderRun     => '0',
      txLinkNotReady => '0',
      frameEvent     => ETH_MAC_FRAME_EVENT_INIT_C,
      retire         => ETH_MAC_TOKEN_RETIRE_INIT_C,
      abortAck       => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal macMaster : AxiStreamMasterType;
   signal macSlave  : AxiStreamSlaveType;

begin

   assert INT_CONFIG_G.TID_BITS_C = EMAC_TOKEN_BITS_C
      report "EthMacTxExportTimingXgmii: INT_CONFIG_G must carry the eight-bit token in TID"
      severity failure;

   DATA_MUX : entity surf.AxiStreamFifoV2
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         RST_POLARITY_G      => RST_POLARITY_G,
         INT_PIPE_STAGES_G   => 0,
         PIPE_STAGES_G       => 1,
         SLAVE_READY_EN_G    => true,
         VALID_THOLD_G       => 1,
         -- FIFO configurations
         SYNTH_MODE_G        => SYNTH_MODE_G,
         MEMORY_TYPE_G       => "distributed",
         GEN_SYNC_FIFO_G     => true,
         CASCADE_SIZE_G      => 1,
         FIFO_ADDR_WIDTH_G   => 4,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => INT_CONFIG_G,  -- 128-bit AXI stream interface
         MASTER_AXI_CONFIG_G => AXI_CONFIG_C)  -- 64-bit AXI stream interface
      port map (
         -- Slave Port
         sAxisClk    => ethClk,
         sAxisRst    => ethRst,
         sAxisMaster => macObMaster,    -- 128-bit AXI stream interface
         sAxisSlave  => macObSlave,
         -- Master Port
         mAxisClk    => ethClk,
         mAxisRst    => ethRst,
         mAxisMaster => macMaster,      -- 64-bit AXI stream interface
         mAxisSlave  => macSlave);

   comb : process (abortReq, ethRst, macMaster, phyReady, r) is
      variable v        : RegType;
      variable cut      : sl;
      variable fetch    : boolean;
      variable underrun : sl;
      variable bytes    : natural range 0 to 8;
      variable word     : slv(63 downto 0);
      variable txd      : slv(63 downto 0);
      variable txc      : slv(7 downto 0);
      variable lane     : natural range 0 to 12;
      variable endFrame : boolean;
      variable errMask  : slv(7 downto 0);
      variable slave    : AxiStreamSlaveType;
   begin
      -- Latch the current value
      v := r;

      -- Reset the pulses and the default idle pin word
      slave            := AXI_STREAM_SLAVE_INIT_C;
      v.txCountEn      := '0';
      v.txUnderRun     := '0';
      v.txLinkNotReady := '0';
      v.frameEvent     := ETH_MAC_FRAME_EVENT_INIT_C;
      v.retire         := ETH_MAC_TOKEN_RETIRE_INIT_C;
      txd              := IDLE_WORD_C;
      txc              := x"FF";
      fetch            := false;
      underrun         := '0';
      endFrame         := false;

      -- Link loss or forced abort ends a frame on the pins
      cut := (not phyReady) or abortReq;

      -- A declared (EOFE) error is sent as an inverted FCS
      errMask := (others => r.error);

      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            if (r.gap < IFG_WORDS_C) then
               v.gap := r.gap + 1;
            elsif (macMaster.tValid = '1') and (abortReq = '0') then
               v.token        := macMaster.tId(EMAC_TOKEN_BITS_C-1 downto 0);
               v.inputEofSeen := '0';
               v.dumpDone     := '0';
               v.error        := '0';
               v.crc          := CRC_INIT_C;
               v.length       := (others => '0');
               if (phyReady = '1') then
                  txd     := PREAMBLE_WORD_C;
                  txc     := x"01";
                  fetch   := true;
                  v.state := DATA_S;
               else
                  v.txLinkNotReady := '1';
                  v.state          := DUMP_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when DATA_S =>
            if (cut = '1') then
               v.state := ABORT_S;
            elsif (r.holdLast = '0') then
               txd   := r.holdData;
               txc   := x"00";
               fetch := true;
            else
               -- Last word: data, FCS (inverted for a declared error), /T/
               txd := r.holdData;
               txc := x"00";
               for i in 0 to 3 loop
                  lane := r.holdBytes + i;
                  if (lane < 8) then
                     txd(8*lane+7 downto 8*lane) := fcsOctet(r.crc, i) xor errMask;
                  end if;
               end loop;
               v.tailFcs := r.crc;
               if (r.holdBytes + 4 < 8) then
                  for i in 0 to 7 loop
                     if (i = r.holdBytes + 4) then
                        txd(8*i+7 downto 8*i) := TERMINATE_C;
                        txc(i)                := '1';
                     elsif (i > r.holdBytes + 4) then
                        txd(8*i+7 downto 8*i) := IDLE_C;
                        txc(i)                := '1';
                     end if;
                  end loop;
                  endFrame := true;
               elsif (r.holdBytes + 4 = 8) then
                  -- FCS fills the word; /T/ opens the tail word
                  v.tailFrom := 4;
                  v.state    := TAIL_S;
                  endFrame   := true;
               else
                  v.tailFrom := 8 - r.holdBytes;
                  v.state    := TAIL_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when TAIL_S =>
            if (cut = '1') then
               v.state := ABORT_S;
            else
               lane := 0;
               for i in 0 to 3 loop
                  if (i >= r.tailFrom) then
                     txd(8*lane+7 downto 8*lane) := fcsOctet(r.tailFcs, i) xor errMask;
                     txc(lane)                   := '0';
                     lane                        := lane + 1;
                  end if;
               end loop;
               txd(8*lane+7 downto 8*lane) := TERMINATE_C;
               txc(lane)                   := '1';
               v.state                     := IDLE_S;
               v.gap                       := 0;
               -- The last FCS octet is launched here unless DATA_S already
               -- launched it and published done (tailFrom = 4)
               if (r.tailFrom /= 4) then
                  v.txCountEn := '1';
                  if (r.token /= EMAC_TOKEN_NONE_C) then
                     v.frameEvent.done       := '1';
                     v.frameEvent.doneError  := r.error;
                     v.frameEvent.doneLength := r.length;
                     v.frameEvent.doneToken  := r.token;
                  end if;
               end if;
            end if;
         ----------------------------------------------------------------------
         when ABORT_S =>
            null;
         ----------------------------------------------------------------------
         when DUMP_S =>
            slave.tReady := '1';
            if (macMaster.tValid = '1') then
               bytes := 0;
               for i in 0 to 7 loop
                  if (macMaster.tKeep(i) = '1') then
                     bytes := bytes + 1;
                  end if;
               end loop;
               v.length := slv(unsigned(r.length) + bytes);
               if (macMaster.tLast = '1') then
                  v.state := IDLE_S;
                  v.gap   := 0;
                  if (r.token /= EMAC_TOKEN_NONE_C) then
                     if (r.dumpDone = '1') then
                        v.frameEvent.done       := '1';
                        v.frameEvent.doneError  := '1';
                        v.frameEvent.doneLength := v.length;
                        v.frameEvent.doneToken  := r.token;
                     else
                        v.retire.valid := '1';
                        v.retire.token := r.token;
                     end if;
                  end if;
               end if;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Frame ended in DATA_S: done for the word holding the last FCS octet
      if endFrame and (r.state = DATA_S) then
         v.txCountEn := '1';
         if (v.state = DATA_S) then
            v.state := IDLE_S;
            v.gap   := 0;
         end if;
         if (r.token /= EMAC_TOKEN_NONE_C) then
            v.frameEvent.done       := '1';
            v.frameEvent.doneError  := r.error;
            v.frameEvent.doneLength := r.length;
            v.frameEvent.doneToken  := r.token;
         end if;
      end if;

      -- Fetch the next word into the hold register and the CRC
      if fetch then
         word  := (others => '0');
         bytes := 0;
         if (v.inputEofSeen = '1') then
            -- Padding after the input tLast
            bytes := 8;
            if (unsigned(v.length) + 8 >= MIN_FRAME_C) then
               bytes := MIN_FRAME_C - to_integer(unsigned(v.length));
            end if;
            v.holdLast := '0';
            if (unsigned(v.length) + bytes >= MIN_FRAME_C) then
               v.holdLast := '1';
            end if;
         elsif (macMaster.tValid = '1') then
            slave.tReady := '1';
            for i in 0 to 7 loop
               if (macMaster.tKeep(i) = '1') then
                  word(8*i+7 downto 8*i) := macMaster.tData(8*i+7 downto 8*i);
                  bytes                  := bytes + 1;
               end if;
            end loop;
            v.holdLast := macMaster.tLast;
            if (macMaster.tLast = '1') then
               v.inputEofSeen := '1';
               v.error        := v.error or axiStreamGetUserBit(AXI_CONFIG_C, macMaster, EMAC_EOFE_BIT_C);
               -- A short frame is padded with zeros, first within this word
               if (unsigned(v.length) + bytes < MIN_FRAME_C) then
                  bytes := 8;
                  if (unsigned(v.length) + 8 >= MIN_FRAME_C) then
                     bytes := MIN_FRAME_C - to_integer(unsigned(v.length));
                  end if;
                  v.holdLast := '0';
                  if (unsigned(v.length) + bytes >= MIN_FRAME_C) then
                     v.holdLast := '1';
                  end if;
               end if;
            end if;
         else
            underrun := '1';
         end if;

         if (underrun = '1') then
            v.txUnderRun := '1';
            v.state      := ABORT_S;
         else
            v.holdData  := word;
            v.holdBytes := bytes;
            if (bytes /= 0) then
               v.crc := crcWord(v.crc, word, bytes);
            end if;
            v.length := slv(unsigned(v.length) + bytes);
         end if;
      end if;

      -- Error termination: /E/ /T/ now, then drain only an outstanding
      -- remainder. ABORT_S is entered on cut (this cycle) or after an
      -- underrun detected while the previous word was launched.
      if (r.state = ABORT_S) or ((r.state = DATA_S or r.state = TAIL_S) and (cut = '1')) then
         txd            := IDLE_WORD_C;
         txd(7 downto 0)  := ERROR_C;
         txd(15 downto 8) := TERMINATE_C;
         txc            := x"FF";
         v.error        := '1';
         if (v.inputEofSeen = '1') then
            v.state := IDLE_S;
            v.gap   := 0;
            if (r.token /= EMAC_TOKEN_NONE_C) then
               v.frameEvent.done       := '1';
               v.frameEvent.doneError  := '1';
               v.frameEvent.doneLength := v.length;
               v.frameEvent.doneToken  := r.token;
            end if;
         else
            v.dumpDone := '1';
            v.state    := DUMP_S;
         end if;
      end if;

      -- Drive the pins
      v.phyTxd := txd;
      v.phyTxc := txc;

      -- Start: the preamble was on the pins last cycle and the word now on
      -- the pins carries the first destination-MAC octet in lane 0
      v.pinPreamble := '0';
      if (r.phyTxd = PREAMBLE_WORD_C) and (r.phyTxc = x"01") then
         v.pinPreamble := '1';
      end if;
      v.frameEvent.start      := r.pinPreamble and not r.phyTxc(0);
      v.frameEvent.startLane  := (others => '0');
      v.frameEvent.startToken := r.token;

      -- Abort acknowledge: idle for at least one edge
      v.abortAck := '0';
      if (abortReq = '1') and (r.state = IDLE_S) then
         v.abortAck := '1';
      end if;

      -- Combinatorial outputs before the reset
      macSlave <= slave;

      -- Reset
      if (ethRst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Registered Outputs
      phyTxd         <= r.phyTxd;
      phyTxc         <= r.phyTxc;
      txCountEn      <= r.txCountEn;
      txUnderRun     <= r.txUnderRun;
      txLinkNotReady <= r.txLinkNotReady;
      frameEvent     <= r.frameEvent;
      retire         <= r.retire;
      abortAck       <= r.abortAck;

   end process comb;

   seq : process (ethClk) is
   begin
      if rising_edge(ethClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
