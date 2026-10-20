-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: RTL Delay_Req stream to timing-port TX requests and records.
--
-- Replaces PtpTxTimestampTap in the timing-port build. The engine's Delay_Req
-- is a fixed 58-byte untagged frame. Its beats pass cut-through, one beat
-- registered, to the port. A SOF beat is accepted only when a table slot is
-- free; it then carries the request: cookie = slot, timestamp, the fixed
-- frame length and the port's live transport generation. Domain (frame byte
-- 18), sourcePortIdentity (34..43) and sequenceId (44..45) are recorded from
-- the passing beats, in network significance.
--
-- Each port completion frees its slot. A SENT completion produces the record
-- PtpDelayReqObserver publishes for a validly observed wire frame: the
-- default record with messageType Delay_Req, the recorded identity and the
-- completion capture, marked as an error when captureValid is low. WIRE_ERR,
-- DISCARDED and FLUSHED produce no record, as the tapped build observes no
-- valid wire frame for them, so PtpTxLedger keeps the key's unknown-fate
-- quarantine. The completion is held until its record is accepted, so none
-- is lost. Contract: ethernet/PtpCore/timing-port.md section 11.2.
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
use surf.SsiPkg.all;
use surf.EthMacPkg.all;
use surf.PtpPkg.all;

entity PtpMacPortTxAdapter is
   generic (
      TPD_G          : time                    := 1 ns;
      RST_POLARITY_G : sl                      := '1';
      RST_ASYNC_G    : boolean                 := false;
      -- Outstanding Delay_Req requests; at most the port's TX table depth.
      TABLE_DEPTH_G  : positive range 1 to 16 := 4);
   port (
      -- Common Ethernet/PHC clock domain
      clk : in sl;
      rst : in sl;

      -- Engine Delay_Req stream in EMAC_AXIS_CONFIG_C
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;

      -- Timing-port TX requests and completions
      portTxMaster        : out PtpMacPortTxMasterType;
      portTxSlave         : in  AxiStreamSlaveType;
      portGeneration      : in  slv(15 downto 0);
      portCompletion      : in  PtpMacPortTxCompletionMasterType;
      portCompletionReady : out sl;

      -- Observed Delay_Req records for the TX ledger
      messageMaster : out PtpRxMessageMasterType;
      messageReady  : in  sl);
end entity PtpMacPortTxAdapter;

architecture rtl of PtpMacPortTxAdapter is

   constant FRAME_BYTES_C : positive := PTP_ETH_HEADER_BYTES_C+PTP_TIMESTAMP_MSG_BYTES_C;
   constant BEAT_BYTES_C  : positive := EMAC_AXIS_CONFIG_C.TDATA_BYTES_C;

   -- Frame byte offsets of the recorded identity.
   constant DOMAIN_BYTE_C   : natural := 18;
   constant IDENTITY_BYTE_C : natural := 34;
   constant SEQUENCE_BYTE_C : natural := 44;

   type IdentityType is record
      domainNumber       : slv(7 downto 0);
      sourcePortIdentity : slv(79 downto 0);
      sequenceId         : slv(15 downto 0);
   end record;

   constant IDENTITY_INIT_C : IdentityType := (
      domainNumber       => (others => '0'),
      sourcePortIdentity => (others => '0'),
      sequenceId         => (others => '0'));

   type IdentityArray is array (natural range <>) of IdentityType;

   type RegType is record
      -- Outbound frame position and its table slot.
      inFrame       : sl;
      beat          : natural range 0 to 127;
      slot          : natural range 0 to TABLE_DEPTH_G-1;
      busy          : slv(TABLE_DEPTH_G-1 downto 0);
      identity      : IdentityArray(TABLE_DEPTH_G-1 downto 0);
      -- Registered port and ledger outputs.
      portTxMaster  : PtpMacPortTxMasterType;
      messageMaster : PtpRxMessageMasterType;
   end record;

   constant REG_INIT_C : RegType := (
      inFrame       => '0',
      beat          => 0,
      slot          => 0,
      busy          => (others => '0'),
      identity      => (others => IDENTITY_INIT_C),
      portTxMaster  => PTP_MAC_PORT_TX_MASTER_INIT_C,
      messageMaster => PTP_RX_MESSAGE_MASTER_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   assert FRAME_BYTES_C = 58
      report "PtpMacPortTxAdapter: Delay_Req frame layout changed" severity failure;

   comb : process (all) is
      variable v          : RegType;
      variable inReady    : sl;
      variable cmplReady  : sl;
      variable freeFound  : boolean;
      variable freeSlot   : natural range 0 to TABLE_DEPTH_G-1;
      variable byteIndex  : natural;
      variable octet      : slv(7 downto 0);
      variable cookieSlot : natural;
   begin
      v := r;

      -- Lowest free slot, from pre-edge occupancy.
      freeFound := false;
      freeSlot  := 0;
      for i in TABLE_DEPTH_G-1 downto 0 loop
         if r.busy(i) = '0' then
            freeFound := true;
            freeSlot  := i;
         end if;
      end loop;

      -------------------------------------------------------------------------
      -- Outbound: one registered beat toward the port.
      -------------------------------------------------------------------------
      if portTxSlave.tReady = '1' then
         v.portTxMaster.frame.tValid := '0';
      end if;

      -- The output register accepts a beat when it is empty or draining. A
      -- new frame additionally needs a free slot.
      inReady := not v.portTxMaster.frame.tValid;
      if r.inFrame = '0' and not freeFound then
         inReady := '0';
      end if;

      if sAxisMaster.tValid = '1' and inReady = '1' then
         v.portTxMaster.frame := sAxisMaster;

         if r.inFrame = '0' then
            -- SOF beat: reserve the slot and present the request with it.
            v.inFrame                                  := '1';
            v.beat                                     := 0;
            v.slot                                     := freeSlot;
            v.busy(freeSlot)                           := '1';
            v.identity(freeSlot)                       := IDENTITY_INIT_C;
            v.portTxMaster.request.cookie              := slv(to_unsigned(freeSlot, PTP_MAC_PORT_COOKIE_BITS_C));
            v.portTxMaster.request.timestamp           := '1';
            v.portTxMaster.request.frameLength         := slv(to_unsigned(FRAME_BYTES_C, 16));
            v.portTxMaster.request.transportGeneration := portGeneration;
         elsif r.beat < 127 then
            v.beat := r.beat+1;
         end if;

         -- Record identity octets as they pass, in network significance.
         for i in 0 to BEAT_BYTES_C-1 loop
            byteIndex := BEAT_BYTES_C*v.beat+i;
            octet     := sAxisMaster.tData(8*i+7 downto 8*i);
            if byteIndex = DOMAIN_BYTE_C then
               v.identity(v.slot).domainNumber := octet;
            end if;
            if byteIndex >= IDENTITY_BYTE_C and byteIndex < IDENTITY_BYTE_C+10 then
               v.identity(v.slot).sourcePortIdentity(79-8*(byteIndex-IDENTITY_BYTE_C) downto
                                                     72-8*(byteIndex-IDENTITY_BYTE_C)) := octet;
            end if;
            if byteIndex >= SEQUENCE_BYTE_C and byteIndex < SEQUENCE_BYTE_C+2 then
               v.identity(v.slot).sequenceId(15-8*(byteIndex-SEQUENCE_BYTE_C) downto
                                             8-8*(byteIndex-SEQUENCE_BYTE_C)) := octet;
            end if;
         end loop;

         if sAxisMaster.tLast = '1' then
            v.inFrame := '0';
         end if;
      end if;

      -------------------------------------------------------------------------
      -- Completions: one held record toward the ledger.
      -------------------------------------------------------------------------
      if messageReady = '1' then
         v.messageMaster.valid := '0';
      end if;

      cmplReady := not v.messageMaster.valid;

      if portCompletion.valid = '1' and cmplReady = '1' then
         cookieSlot := to_integer(unsigned(portCompletion.data.cookie));

         -- A cookie this adapter never issued cannot name a slot.
         if cookieSlot < TABLE_DEPTH_G then
            v.busy(cookieSlot) := '0';

            if portCompletion.data.outcome = PTP_MAC_PORT_OUTCOME_SENT_C then
               v.messageMaster.valid                   := '1';
               v.messageMaster.data                    := PTP_RX_MESSAGE_INIT_C;
               v.messageMaster.data.messageType        := PTP_MSG_DELAY_REQ_C;
               v.messageMaster.data.domainNumber       := r.identity(cookieSlot).domainNumber;
               v.messageMaster.data.sourcePortIdentity := r.identity(cookieSlot).sourcePortIdentity;
               v.messageMaster.data.sequenceId         := r.identity(cookieSlot).sequenceId;
               v.messageMaster.data.capture            := portCompletion.data.capture;
               v.messageMaster.data.capture.error      := portCompletion.data.capture.error or
                                                          not portCompletion.data.captureValid;
            end if;
         end if;
      end if;

      -- Combinational ready outputs before the reset; reset excludes transfers.
      if rst = RST_POLARITY_G then
         inReady   := '0';
         cmplReady := '0';
      end if;

      sAxisSlave          <= (tReady => inReady);
      portCompletionReady <= cmplReady;

      if not RST_ASYNC_G and rst = RST_POLARITY_G then
         v := REG_INIT_C;
      end if;

      rin <= v;

      portTxMaster  <= r.portTxMaster;
      messageMaster <= r.messageMaster;
   end process comb;

   seq : process (clk, rst) is
   begin

      if RST_ASYNC_G and rst = RST_POLARITY_G then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(clk) then
         r <= rin after TPD_G;
      end if;

   end process seq;

end architecture rtl;
