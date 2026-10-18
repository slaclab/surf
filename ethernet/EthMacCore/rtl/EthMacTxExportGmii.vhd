-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: 1GbE Export MAC core with GMII interface
-------------------------------------------------------------------------------
-- TIMING_EN_G adds the timing-port leaf behaviour of
-- ethernet/PtpCore/timing-port.md section 4.0, leaving the default path
-- unchanged: the frame token is latched from tId at SOF; start is registered
-- one edge after the first destination-MAC octet is launched onto the pins;
-- done reports the last FCS octet (doneError for underrun or link loss); a
-- frame dumped because the PHY was not ready at SOF publishes a retire
-- instead. Link loss after SOF stops driving the pins: an outstanding input
-- remainder is drained through tLast before done, otherwise done is
-- immediate. Token zero (generated pause frames) publishes no done or retire.
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.EthMacPkg.all;

entity EthMacTxExportGmii is
   generic (
      TPD_G          : time := 1 ns;
      RST_POLARITY_G : sl   := '1';  -- '1' for active HIGH reset, '0' for active LOW reset
      -- MAC-internal stream format; EMAC_TIMING_AXIS_CONFIG_C adds the TID token.
      INT_CONFIG_G   : AxiStreamConfigType := INT_EMAC_AXIS_CONFIG_C;
      -- Timing-port leaf events and link-loss drain; requires the TID token.
      TIMING_EN_G    : boolean             := false);
   port (
      -- Clock and Reset
      ethClkEn       : in  sl;
      ethClk         : in  sl;
      ethRst         : in  sl;
      -- AXIS Interface
      macObMaster    : in  AxiStreamMasterType;
      macObSlave     : out AxiStreamSlaveType;
      -- GMII PHY Interface
      gmiiTxEn       : out sl;
      gmiiTxEr       : out sl;
      gmiiTxd        : out slv(7 downto 0);
      phyReady       : in  sl;
      -- Status
      txCountEn      : out sl;
      txUnderRun     : out sl;
      txLinkNotReady : out sl;
      -- Timing port wire events (TIMING_EN_G only)
      frameEvent     : out EthMacFrameEventType;
      retire         : out EthMacTokenRetireType;
      -- Forced abort (TIMING_EN_G only): ends a frame on the pins as link loss
      -- does, starts no new frame, and acknowledges once idle
      abortReq       : in  sl := '0';
      abortAck       : out sl);
end EthMacTxExportGmii;

architecture rtl of EthMacTxExportGmii is

   constant AXI_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => INT_CONFIG_G.TSTRB_EN_C,
      TDATA_BYTES_C => 1,               -- 8-bit AXI stream interface
      TDEST_BITS_C  => INT_CONFIG_G.TDEST_BITS_C,
      TID_BITS_C    => INT_CONFIG_G.TID_BITS_C,
      TKEEP_MODE_C  => INT_CONFIG_G.TKEEP_MODE_C,
      TUSER_BITS_C  => INT_CONFIG_G.TUSER_BITS_C,
      TUSER_MODE_C  => INT_CONFIG_G.TUSER_MODE_C);

   type StateType is (
      IDLE_S,
      TX_PREAMBLE_S,
      TX_DATA_S,
      PAD_S,
      TX_CRC_S,
      TX_CRC0_S,
      TX_CRC1_S,
      TX_CRC2_S,
      TX_CRC3_S,
      DUMP_S,
      INTERGAP_S);

   type RegType is record
      gmiiTxEn       : sl;
      gmiiTxEr       : sl;
      gmiiTxd        : slv(7 downto 0);
      txCount        : slv(7 downto 0);
      txData         : slv(7 downto 0);
      txCountEn      : sl;
      txUnderRun     : sl;
      txLinkNotReady : sl;
      crcReset       : sl;
      crcDataValid   : sl;
      crcIn          : slv(7 downto 0);
      state          : StateType;
      macSlave       : AxiStreamSlaveType;
      -- Timing-port state (TIMING_EN_G only)
      token          : EthMacTokenType;
      inputEofSeen   : sl;
      dumpDone       : sl;
      sfdLoaded      : sl;
      dmacLoaded     : sl;
      length         : slv(15 downto 0);
      frameEvent     : EthMacFrameEventType;
      retire         : EthMacTokenRetireType;
      abortAck       : sl;
   end record;

   constant REG_INIT_C : RegType := (
      gmiiTxEn       => '0',
      gmiiTxEr       => '0',
      gmiiTxd        => (others => '0'),
      txCount        => (others => '0'),
      txData         => (others => '0'),
      txCountEn      => '0',
      txUnderRun     => '0',
      txLinkNotReady => '0',
      crcReset       => '0',
      crcDataValid   => '0',
      crcIn          => (others => '0'),
      state          => IDLE_S,
      macSlave       => AXI_STREAM_SLAVE_INIT_C,
      token          => EMAC_TOKEN_NONE_C,
      inputEofSeen   => '0',
      dumpDone       => '0',
      sfdLoaded      => '0',
      dmacLoaded     => '0',
      length         => (others => '0'),
      frameEvent     => ETH_MAC_FRAME_EVENT_INIT_C,
      retire         => ETH_MAC_TOKEN_RETIRE_INIT_C,
      abortAck       => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal macMaster    : AxiStreamMasterType;
   signal macSlave     : AxiStreamSlaveType;
   signal crcOut       : slv(31 downto 0);
   signal crcDataValid : sl;
   signal crcIn        : slv(7 downto 0);

   -- attribute dont_touch                 : string;
   -- attribute dont_touch of r            : signal is "TRUE";
   -- attribute dont_touch of macMaster    : signal is "TRUE";
   -- attribute dont_touch of macSlave     : signal is "TRUE";
   -- attribute dont_touch of crcOut       : signal is "TRUE";
   -- attribute dont_touch of crcDataValid : signal is "TRUE";
   -- attribute dont_touch of crcIn        : signal is "TRUE";

begin

   assert (TIMING_EN_G = false) or (INT_CONFIG_G.TID_BITS_C = EMAC_TOKEN_BITS_C)
      report "EthMacTxExportGmii: TIMING_EN_G requires the eight-bit token in INT_CONFIG_G TID"
      severity failure;

   U_Resize : entity surf.AxiStreamResize
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         RST_POLARITY_G      => RST_POLARITY_G,
         READY_EN_G          => true,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => INT_CONFIG_G,  -- 128-bit AXI stream interface
         MASTER_AXI_CONFIG_G => AXI_CONFIG_C)  -- 8-bit AXI stream interface
      port map (
         -- Clock and reset
         axisClk     => ethClk,
         axisRst     => ethRst,
         -- Slave Port
         sAxisMaster => macObMaster,    -- 128-bit AXI stream interface
         sAxisSlave  => macObSlave,
         -- Master Port
         mAxisMaster => macMaster,      -- 8-bit AXI stream interface
         mAxisSlave  => macSlave);

   comb : process (abortReq, crcOut, ethClkEn, ethRst, macMaster, phyReady, r) is
      variable v       : RegType;
      variable linkCut : boolean;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      v.macSlave       := AXI_STREAM_SLAVE_INIT_C;
      v.crcDataValid   := '0';
      v.txCountEn      := '0';
      v.txUnderRun     := '0';
      v.txLinkNotReady := '0';
      v.sfdLoaded      := '0';
      v.dmacLoaded     := '0';
      v.frameEvent     := ETH_MAC_FRAME_EVENT_INIT_C;
      v.retire         := ETH_MAC_TOKEN_RETIRE_INIT_C;

      -- Timing mode: link loss or forced abort once a frame has left IDLE_S
      -- ends it on the wire
      linkCut := TIMING_EN_G and ((phyReady = '0') or (abortReq = '1'));

      -- Check for clock enable
      if (ethClkEn = '1') then

         -- State Machine
         case r.state is
            ----------------------------------------------------------------------
            when IDLE_S =>
               -- Reset the flags
               v.crcReset := '1';
               v.txCount  := x"00";
               v.txData   := x"55";     -- Preset to PREAMBLE CHAR
               v.gmiiTxd  := x"00";
               v.gmiiTxEn := '0';
               v.gmiiTxEr := '0';
               -- Wait for start flag
               if ((macMaster.tValid = '1') and (ethRst = '0') and
                   ((TIMING_EN_G = false) or (abortReq = '0'))) then
                  -- Frame token travels on every beat; latch it at SOF
                  if TIMING_EN_G then
                     v.token        := macMaster.tId(EMAC_TOKEN_BITS_C-1 downto 0);
                     v.inputEofSeen := '0';
                     v.dumpDone     := '0';
                     v.length       := (others => '0');
                  end if;
                  -- Phy is ready
                  if phyReady = '1' then
                     v.state := TX_PREAMBLE_S;
                  -- Phy is not ready dump data
                  else
                     v.txLinkNotReady := '1';
                     v.state          := DUMP_S;
                  end if;
               end if;
            ----------------------------------------------------------------------
            when TX_PREAMBLE_S =>
               v.crcReset := '0';
               v.gmiiTxEn := '1';
               v.gmiiTxd  := r.txData;
               if linkCut then
                  -- No input consumed yet: drain the whole frame, then done
                  v.gmiiTxEn := '0';
                  v.gmiiTxd  := x"00";
                  v.txCount  := x"00";
                  v.dumpDone := '1';
                  v.state    := DUMP_S;
               elsif (r.txCount = x"06") then
                  v.txCount := x"00";
                  v.txData  := x"D5";   -- Set to SFD char
                  v.state   := TX_DATA_S;
               else
                  v.txCount := r.txCount +1;
                  v.txData  := x"55";   -- Set to PREAMBLE char
               end if;
            ----------------------------------------------------------------------
            when TX_DATA_S =>
               if linkCut then
                  -- The input remainder is outstanding: drain it, then done
                  v.gmiiTxEn := '0';
                  v.gmiiTxd  := x"00";
                  v.txCount  := x"00";
                  v.dumpDone := '1';
                  v.state    := DUMP_S;
               else
                  v.macSlave.tReady := '1';
                  v.crcDataValid    := '1';
                  v.crcIn           := macMaster.tdata(7 downto 0);
                  v.txData          := macMaster.tdata(7 downto 0);
                  v.gmiiTxd         := r.txData;
                  -- First cycle launches the SFD loaded at the end of the preamble
                  if TIMING_EN_G and (r.txCount = x"00") then
                     v.sfdLoaded := '1';
                  end if;
                  if (r.txCount < x"3C") then  -- Minimum frame of 60B (= 84B - 8B Preamble - 4B CRC - 12B intergap)
                     v.txCount := r.txCount + 1;
                  end if;
                  if (macMaster.tValid = '1') then
                     v.length := r.length + 1;
                     if (macMaster.tlast = '1') then
                        v.inputEofSeen := '1';
                        if (v.txCount = x"3C") then
                           v.state := TX_CRC_S;
                        else
                           v.state := PAD_S;
                        end if;
                     end if;
                  else
                     v.gmiiTxEr   := '1';
                     v.txUnderRun := '1';
                     v.dumpDone   := '1';
                     v.state      := DUMP_S;
                  end if;
               end if;
            ----------------------------------------------------------------------
            when PAD_S =>
               v.crcDataValid := '1';
               v.crcIn        := x"00";
               v.txData       := x"00";
               v.gmiiTxd      := r.txData;
               v.length       := r.length + 1;
               if (r.txCount < x"3C") then
                  v.txCount := v.txCount + 1;
               else
                  v.state := TX_CRC_S;
               end if;
            ----------------------------------------------------------------------
            when TX_CRC_S =>
               v.gmiiTxd := r.txData;
               v.state   := TX_CRC0_S;
            ----------------------------------------------------------------------
            when TX_CRC0_S =>
               v.gmiitxd := crcOut(31 downto 24);
               v.state   := TX_CRC1_S;
            ----------------------------------------------------------------------
            when TX_CRC1_S =>
               v.gmiitxd := crcOut(23 downto 16);
               v.state   := TX_CRC2_S;
            ----------------------------------------------------------------------
            when TX_CRC2_S =>
               v.gmiitxd := crcOut(15 downto 8);
               v.state   := TX_CRC3_S;
            ----------------------------------------------------------------------
            when TX_CRC3_S =>
               v.txCountEn := '1';
               v.gmiitxd   := crcOut(7 downto 0);
               v.txCount   := x"00";
               v.state     := INTERGAP_S;
               -- Last FCS octet launched: the frame was transmitted
               if TIMING_EN_G and (r.token /= EMAC_TOKEN_NONE_C) then
                  v.frameEvent.done       := '1';
                  v.frameEvent.doneError  := '0';
                  v.frameEvent.doneLength := r.length;
                  v.frameEvent.doneToken  := r.token;
               end if;
            ----------------------------------------------------------------------
            when DUMP_S =>
               v.gmiiTxEn        := '0';
               v.gmiiTxd         := x"00";
               v.macSlave.tReady := '1';
               v.txCount         := x"00";
               if TIMING_EN_G and (macMaster.tValid = '1') then
                  v.length := r.length + 1;
               end if;
               if ((macMaster.tValid = '1') and (macMaster.tlast = '1')) then
                  v.state := INTERGAP_S;
                  -- One terminal event: done once the frame touched the pins,
                  -- otherwise a retire for a frame dumped at SOF
                  if TIMING_EN_G and (r.token /= EMAC_TOKEN_NONE_C) then
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
            ----------------------------------------------------------------------
            when INTERGAP_S =>
               v.gmiiTxEn := '0';
               v.gmiiTxd  := x"00";
               v.txCount  := r.txCount +1;
               if r.txCount = x"0A" then  -- 12 Octets (11 in INTERGAP_S + 1 in IDLE_S)
                  v.txCount := x"00";
                  v.state   := IDLE_S;
               end if;
         ----------------------------------------------------------------------
         end case;

         -- Link loss after the input tLast was accepted (padding or FCS on the
         -- pins): nothing remains to drain, so done is immediate.
         if linkCut and (r.inputEofSeen = '1') and
            ((r.state = PAD_S) or (r.state = TX_CRC_S) or (r.state = TX_CRC0_S) or
             (r.state = TX_CRC1_S) or (r.state = TX_CRC2_S) or (r.state = TX_CRC3_S)) then
            v.gmiiTxEn         := '0';
            v.gmiiTxd          := x"00";
            v.txCount          := x"00";
            v.txCountEn        := '0';
            v.state            := INTERGAP_S;
            v.frameEvent.done  := '0';
            if (r.token /= EMAC_TOKEN_NONE_C) then
               v.frameEvent.done       := '1';
               v.frameEvent.doneError  := '1';
               v.frameEvent.doneLength := r.length;
               v.frameEvent.doneToken  := r.token;
            end if;
         end if;

         -- Abort acknowledge: idle for at least one edge, so any terminal
         -- event for the frame that was on the pins has already been published
         v.abortAck := '0';
         if TIMING_EN_G and (abortReq = '1') and ((r.state = IDLE_S) or (r.state = INTERGAP_S)) then
            v.abortAck := '1';
         end if;

         -- Start: the first destination-MAC octet was launched on the
         -- previous edge and is on the pins now, so register start on this
         -- edge, the edge the passive TX tap captures.
         if TIMING_EN_G then
            if (r.sfdLoaded = '1') and (v.gmiiTxEn = '1') and (v.gmiiTxEr = '0') then
               v.dmacLoaded := '1';
            end if;
            v.frameEvent.start      := r.dmacLoaded;
            v.frameEvent.startLane  := (others => '0');
            v.frameEvent.startToken := r.token;
         end if;

      end if;

      -- Combinatorial outputs before the reset
      macSlave     <= v.macSlave;
      crcDataValid <= v.crcDataValid;
      crcIn        <= v.crcIn;

      -- Reset
      if (ethRst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Registered Outputs
      txCountEn      <= r.txCountEn;
      txUnderRun     <= r.txUnderRun;
      txLinkNotReady <= r.txLinkNotReady;
      gmiiTxEn       <= r.gmiiTxEn;
      gmiiTxEr       <= r.gmiiTxEr;
      gmiiTxd        <= r.gmiiTxd;
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

   -- CRC
   U_Crc32 : entity surf.Crc32Parallel
      generic map (
         TPD_G        => TPD_G,
         BYTE_WIDTH_G => 1)
      port map (
         crcOut       => crcOut,
         crcClk       => ethClk,
         crcDataValid => crcDataValid,
         crcDataWidth => "000",
         crcIn        => crcIn,
         crcReset     => r.crcReset);

end rtl;
