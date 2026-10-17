-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Timing-capable 1GbE import leaf with GMII interface
-------------------------------------------------------------------------------
-- Timing-mode alternative to EthMacRxImportGmii for the timing port contract
-- (ethernet/PtpCore/timing-port.md, sections 2.4 and 3). Frame qualification
-- follows PtpRxTimestampAdapter exactly: seven 0x55 preamble octets then 0xD5,
-- with RX_DV high and RX_ER low throughout. A burst that does not qualify is
-- drained to RX_DV low with no beats and reported as lost.
--
-- The leaf registers start on the edge that samples the first destination-MAC
-- octet from the pins, which is the edge on which the passive adapter
-- registers its capture, and stamps the token sampled from nextToken on that
-- edge onto every beat. A frame started with EMAC_TOKEN_NONE_C produces no
-- beats; it still publishes start and done with token zero so the port can
-- count it. Every start has exactly one terminal event: done when at least
-- one frame byte follows the four FCS octets, otherwise a retire for the
-- abandoned token (token zero is never retired).
--
-- RX_ER, or phyReady falling while a frame is open, terminates the frame with
-- one tLast+EOFE beat and done with doneError. FCS is stripped; doneLength
-- counts destination MAC through the last payload octet.
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

entity EthMacRxImportTimingGmii is
   generic (
      TPD_G          : time                := 1 ns;
      RST_POLARITY_G : sl                  := '1';  -- '1' for active HIGH reset, '0' for active LOW reset
      -- MAC-internal stream format; must carry the eight-bit TID token.
      INT_CONFIG_G   : AxiStreamConfigType := EMAC_TIMING_AXIS_CONFIG_C;
      SYNTH_MODE_G   : string              := "inferred");  -- Synthesis mode for internal RAMs
   port (
      -- Clock and Reset
      ethClkEn    : in  sl;
      ethClk      : in  sl;
      ethRst      : in  sl;
      -- AXIS Interface
      macIbMaster : out AxiStreamMasterType;
      -- GMII PHY Interface
      gmiiRxDv    : in  sl;
      gmiiRxEr    : in  sl;
      gmiiRxd     : in  slv(7 downto 0);
      -- Configuration and status
      phyReady    : in  sl;
      rxCountEn   : out sl;
      rxCrcError  : out sl;
      -- Timing port: allocation offered for the next start, and wire events
      nextToken   : in  EthMacTokenType;
      frameEvent  : out EthMacFrameEventType;
      retire      : out EthMacTokenRetireType);
end EthMacRxImportTimingGmii;

architecture rtl of EthMacRxImportTimingGmii is

   constant PREAMBLE_C       : slv(7 downto 0) := x"55";
   constant SFD_C            : slv(7 downto 0) := x"D5";
   constant PREAMBLE_BYTES_C : positive        := 7;
   constant FCS_BYTES_C      : positive        := 4;

   -- CrcPkg register value after a frame and its own FCS; any other value
   -- marks a corrupted frame. CrcPkg consumes bit-reversed octets.
   constant CRC_INIT_C    : slv(31 downto 0) := x"FFFFFFFF";
   constant CRC_RESIDUE_C : slv(31 downto 0) := x"C704DD7B";

   constant AXI_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => INT_CONFIG_G.TSTRB_EN_C,
      TDATA_BYTES_C => 1,               -- 8-bit AXI stream interface
      TDEST_BITS_C  => INT_CONFIG_G.TDEST_BITS_C,
      TID_BITS_C    => INT_CONFIG_G.TID_BITS_C,
      TKEEP_MODE_C  => INT_CONFIG_G.TKEEP_MODE_C,
      TUSER_BITS_C  => INT_CONFIG_G.TUSER_BITS_C,
      TUSER_MODE_C  => INT_CONFIG_G.TUSER_MODE_C);

   -- SEARCH_S waits for a burst; PREAMBLE_S qualifies the preamble and SFD;
   -- FRAME_S carries the frame; DRAIN_S discards the rest of a burst that
   -- failed qualification or was terminated with RX_DV still high.
   type StateType is (
      SEARCH_S,
      PREAMBLE_S,
      FRAME_S,
      DRAIN_S);

   type RegType is record
      state      : StateType;
      preamble   : natural range 0 to PREAMBLE_BYTES_C;
      first      : sl;
      token      : EthMacTokenType;
      owned      : sl;
      crc        : slv(31 downto 0);
      -- FCS strip: the newest four octets may still be FCS, and the newest
      -- frame byte is held until the next one proves it is not the last.
      fcsDelay   : Slv8Array(FCS_BYTES_C-1 downto 0);
      fcsCount   : natural range 0 to FCS_BYTES_C;
      pendValid  : sl;
      pendData   : slv(7 downto 0);
      pendSof    : sl;
      length     : slv(15 downto 0);
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
      fcsDelay   => (others => (others => '0')),
      fcsCount   => 0,
      pendValid  => '0',
      pendData   => (others => '0'),
      pendSof    => '0',
      length     => (others => '0'),
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
      report "EthMacRxImportTimingGmii: INT_CONFIG_G must carry the eight-bit token in TID"
      severity failure;

   DATA_MUX : entity surf.AxiStreamFifoV2
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         RST_POLARITY_G      => RST_POLARITY_G,
         PIPE_STAGES_G       => 0,
         SLAVE_READY_EN_G    => true,
         VALID_THOLD_G       => 1,
         -- FIFO configurations
         SYNTH_MODE_G        => SYNTH_MODE_G,
         MEMORY_TYPE_G       => "distributed",
         GEN_SYNC_FIFO_G     => true,
         CASCADE_SIZE_G      => 1,
         FIFO_ADDR_WIDTH_G   => 4,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => AXI_CONFIG_C,  --  8-bit AXI stream interface
         MASTER_AXI_CONFIG_G => INT_CONFIG_G)  -- 128-bit AXI stream interface
      port map (
         -- Slave Port
         sAxisClk    => ethClk,
         sAxisRst    => ethRst,
         sAxisMaster => macMaster,      -- 8-bit AXI stream interface
         sAxisSlave  => open,
         -- Master Port
         mAxisClk    => ethClk,
         mAxisRst    => ethRst,
         mAxisMaster => macIbMaster,    -- 128-bit AXI stream interface
         mAxisSlave  => AXI_STREAM_SLAVE_FORCE_C);

   comb : process (ethClkEn, ethRst, gmiiRxDv, gmiiRxEr, gmiiRxd, nextToken,
                   phyReady, r) is
      variable v         : RegType;
      variable dataByte  : sl;
      variable terminate : sl;
      variable crcGood   : sl;
   begin
      -- Latch the current value
      v := r;

      -- Reset the pulses and the single-beat output
      v.rxCountEn        := '0';
      v.rxCrcError       := '0';
      v.frameEvent       := ETH_MAC_FRAME_EVENT_INIT_C;
      v.retire           := ETH_MAC_TOKEN_RETIRE_INIT_C;
      v.macMaster        := AXI_STREAM_MASTER_INIT_C;
      v.macMaster.tKeep  := (others => '1');

      dataByte  := '0';
      terminate := '0';

      -- Check for clock enable
      if (ethClkEn = '1') then

         case r.state is
            ----------------------------------------------------------------------
            when SEARCH_S =>
               -- Like the passive adapter, which is held in reset while the
               -- PHY is not ready, no burst is examined without the link.
               if (phyReady = '1') and (gmiiRxDv = '1') then
                  if (gmiiRxEr = '0') and (gmiiRxd = PREAMBLE_C) then
                     v.preamble := 1;
                     v.state    := PREAMBLE_S;
                  else
                     v.frameEvent.lost := '1';
                     v.state           := DRAIN_S;
                  end if;
               end if;
            ----------------------------------------------------------------------
            when PREAMBLE_S =>
               if (phyReady = '0') or (gmiiRxDv = '0') then
                  v.frameEvent.lost := '1';
                  v.state           := SEARCH_S;
               elsif (gmiiRxEr = '0') and (gmiiRxd = PREAMBLE_C) and (r.preamble < PREAMBLE_BYTES_C) then
                  v.preamble := r.preamble + 1;
               elsif (gmiiRxEr = '0') and (gmiiRxd = SFD_C) and (r.preamble = PREAMBLE_BYTES_C) then
                  v.first := '1';
                  v.state := FRAME_S;
               else
                  v.frameEvent.lost := '1';
                  v.state           := DRAIN_S;
               end if;
            ----------------------------------------------------------------------
            when FRAME_S =>
               if (phyReady = '1') and (gmiiRxDv = '1') and (gmiiRxEr = '0') then
                  dataByte := '1';
               elsif (r.first = '1') then
                  -- No destination-MAC octet arrived: the passive adapter takes
                  -- no capture either, so there is no start to terminate.
                  v.frameEvent.lost := '1';
                  v.first           := '0';
                  v.state           := SEARCH_S;
               else
                  terminate := '1';
               end if;

               -- Termination ends the frame; RX_DV still high means the rest of
               -- this burst must not be searched for a new start.
               if (terminate = '1') then
                  if (phyReady = '1') and (gmiiRxDv = '1') then
                     v.state := DRAIN_S;
                  else
                     v.state := SEARCH_S;
                  end if;
               end if;
            ----------------------------------------------------------------------
            when DRAIN_S =>
               if (phyReady = '0') or (gmiiRxDv = '0') then
                  v.state := SEARCH_S;
               end if;
         ----------------------------------------------------------------------
         end case;

         -- Start: this edge samples the first destination-MAC octet
         if (dataByte = '1') and (r.first = '1') then
            v.first                 := '0';
            v.token                 := nextToken;
            v.owned                 := '0';
            v.crc                   := CRC_INIT_C;
            v.fcsCount              := 0;
            v.pendValid             := '0';
            v.length                := (others => '0');
            v.frameEvent.start      := '1';
            v.frameEvent.startLane  := (others => '0');
            v.frameEvent.startToken := nextToken;
            if (nextToken /= EMAC_TOKEN_NONE_C) then
               v.owned := '1';
            end if;
         end if;

         -- Frame byte: the octet leaving the FCS delay line is payload. Any
         -- held byte is now known not to be last and is published.
         if (dataByte = '1') then
            v.crc := crc32Parallel1Byte(v.crc, bitReverse(gmiiRxd));
            if (v.fcsCount = FCS_BYTES_C) then
               if (v.pendValid = '1') and (v.owned = '1') then
                  v.macMaster.tValid            := '1';
                  v.macMaster.tData(7 downto 0) := v.pendData;
                  v.macMaster.tId(EMAC_TOKEN_BITS_C-1 downto 0) := v.token;
                  axiStreamSetUserBit(AXI_CONFIG_C, v.macMaster, EMAC_SOF_BIT_C, v.pendSof, 0);
               end if;
               v.pendValid := '1';
               v.pendData  := v.fcsDelay(FCS_BYTES_C-1);
               v.pendSof   := '0';
               if (unsigned(v.length) = 0) then
                  v.pendSof := '1';
               end if;
               v.length := slv(unsigned(v.length) + 1);
            else
               v.fcsCount := v.fcsCount + 1;
            end if;
            v.fcsDelay := v.fcsDelay(FCS_BYTES_C-2 downto 0) & gmiiRxd;
         end if;

         -- Frame end: publish the held byte with tLast, then exactly one
         -- terminal event for the token sampled at start.
         if (terminate = '1') then
            crcGood := '0';
            if (r.crc = CRC_RESIDUE_C) and (gmiiRxEr = '0') and (phyReady = '1') then
               crcGood := '1';
            end if;

            if (r.pendValid = '1') or (r.owned = '0') then
               if (r.owned = '1') then
                  v.macMaster.tValid            := '1';
                  v.macMaster.tLast             := '1';
                  v.macMaster.tData(7 downto 0) := r.pendData;
                  v.macMaster.tId(EMAC_TOKEN_BITS_C-1 downto 0) := r.token;
                  axiStreamSetUserBit(AXI_CONFIG_C, v.macMaster, EMAC_SOF_BIT_C, r.pendSof, 0);
                  axiStreamSetUserBit(AXI_CONFIG_C, v.macMaster, EMAC_EOFE_BIT_C, not crcGood, 0);
               end if;
               v.frameEvent.done       := '1';
               v.frameEvent.doneError  := not crcGood;
               v.frameEvent.doneLength := r.length;
               v.frameEvent.doneToken  := r.token;
               v.rxCountEn             := crcGood;
               v.rxCrcError            := not crcGood;
            else
               -- Owned start with no frame byte after the FCS octets
               v.retire.valid := '1';
               v.retire.token := r.token;
            end if;

            v.pendValid := '0';
            v.owned     := '0';
            v.token     := EMAC_TOKEN_NONE_C;
         end if;

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
