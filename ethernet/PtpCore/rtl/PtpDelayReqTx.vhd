-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PTP Delay_Req scheduling, ledger reservation and frame transmission.
--
-- Owns the request interval, seeded jitter and AXI frame drain. Protocol policy
-- supplies enable and same-edge cancel; the ledger sees ledgerCancel one cycle
-- later. A reservation accepted on the cancel detection edge still creates a
-- frame, which drains even while cancel is asserted. ledgerCancel excludes a
-- reservation transfer at both ends. Only system reset discards a held frame.
--
-- Accepted Delay_Resp metadata updates the minimum interval. A reservation on
-- that same edge uses the previous minimum, preserving the protocol schedule.
-- Configuration and identity are sampled when the ledger accepts a reservation;
-- subsequent changes cannot alter an offered frame. All ports use clk, and
-- allocation valid and AXI payload/sidebands are registered and held when stalled.
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
use surf.PtpProtocolPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;
use surf.PtpPkg.all;

entity PtpDelayReqTx is
   generic (
      TPD_G          : time    := 1 ns;
      RST_POLARITY_G : sl      := '1';
      RST_ASYNC_G    : boolean := false);
   port (
      clk : in  sl;
      rst : in  sl;
      -- Current-edge policy; cancellation resets scheduling, never frame drain.
      enable   : in  sl;
      cancel   : in  sl;
      ticks    : in  slv(63 downto 0);
      config   : in  PtpPortConfigType;
      localMac : in  slv(47 downto 0);
      interval : in  PtpIntervalType;
      -- Registered protocol cancellation shared with PtpTxLedger.
      ledgerCancel : in  sl;
      allocate     : out sl;
      allocation   : in  PtpLedgerAllocationType;
      txMaster     : out AxiStreamMasterType;
      txSlave      : in  AxiStreamSlaveType);
end entity PtpDelayReqTx;

architecture rtl of PtpDelayReqTx is

   constant LFSR_SEED_C : slv(15 downto 0) := PTP_PORT_CONFIG_INIT_C.lfsrSeed;

   -- Untagged Delay_Req, excluding MAC-supplied padding and FCS.
   constant TX_FRAME_BYTES_C : positive                      := PTP_ETH_HEADER_BYTES_C+PTP_TIMESTAMP_MSG_BYTES_C;
   constant TX_BEAT_BYTES_C  : positive                      := PTP_RX_AXIS_CONFIG_C.TDATA_BYTES_C;
   constant TX_LAST_BEAT_C   : natural                       := (TX_FRAME_BYTES_C-1)/TX_BEAT_BYTES_C;
   constant TX_LAST_BYTES_C  : positive                      := TX_FRAME_BYTES_C-TX_LAST_BEAT_C*TX_BEAT_BYTES_C;
   constant TX_LAST_KEEP_C   : slv(TX_BEAT_BYTES_C-1 downto 0) := toSlv(2**TX_LAST_BYTES_C-1, TX_BEAT_BYTES_C);

   type RegType is record
      allocate : sl;
      master          : AxiStreamMasterType;
      frame           : slv(8*TX_FRAME_BYTES_C-1 downto 0);
      beat            : natural range 0 to TX_LAST_BEAT_C;
      lastRequest     : slv(63 downto 0);
      requestInterval : unsigned(63 downto 0);
      minimumInterval : unsigned(63 downto 0);
      requestStarted  : sl;
      lfsr            : slv(15 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      allocate        => '0',
      master          => AXI_STREAM_MASTER_INIT_C,
      frame           => (others => '0'),
      beat            => 0,
      lastRequest     => (others => '0'),
      requestInterval => (others => '0'),
      minimumInterval => (others => '0'),
      requestStarted  => '0',
      lfsr            => LFSR_SEED_C);

   function buildRequest (
      cfg                       : PtpPortConfigType;
      mac                       : slv(47 downto 0);
      seqId                     : slv(15 downto 0)) return slv is
      constant MESSAGE_LENGTH_C : slv(15 downto 0)                   := toSlv(PTP_TIMESTAMP_MSG_BYTES_C, 16);
      variable bytes            : Slv8Array(0 to TX_FRAME_BYTES_C-1) := (others => (others => '0'));
      variable resultValue      : slv(8*TX_FRAME_BYTES_C-1 downto 0);
   begin
      -- Ethernet header, bytes 0..13. Destination uses network significance;
      -- the SURF source MAC stores its first wire octet in the low byte.
      for i in 0 to 5 loop
         bytes(i)   := PTP_PRIMARY_MULTICAST_MAC_C(47-8*i downto 40-8*i);
         bytes(6+i) := mac(8*i+7 downto 8*i);
      end loop;
      bytes(12) := PTP_ETH_TYPE_C(15 downto 8);  -- EtherType, high octet first.
      bytes(13) := PTP_ETH_TYPE_C(7 downto 0);
      -- PTP common header, bytes 14..47. Explicit wire positions keep this
      -- encoder readable; protocol values and message sizes remain named.
      bytes(14) := PTP_TRANSPORT_SPECIFIC_C & PTP_MSG_DELAY_REQ_C;  -- transportSpecific/messageType.
      bytes(15) := cfg.minorVersion & PTP_MAJOR_VERSION_C;         -- minorVersionPTP/versionPTP.
      bytes(16) := MESSAGE_LENGTH_C(15 downto 8);                  -- messageLength.
      bytes(17) := MESSAGE_LENGTH_C(7 downto 0);
      bytes(18) := cfg.domainNumber;                              -- domainNumber.
      -- sourcePortIdentity, bytes 34..43, high octet first.
      for i in 0 to 9 loop
         bytes(34+i) := cfg.localIdentity(79-8*i downto 72-8*i);
      end loop;
      bytes(44) := seqId(15 downto 8);               -- sequenceId.
      bytes(45) := seqId(7 downto 0);
      -- 2019 Layer-2 transmits controlField=0; retain the 2008 encoding only
      -- when software explicitly selects minor version 0 compatibility.
      if cfg.minorVersion = PTP_MINOR_VERSION_MIN_C then
         bytes(46) := PTP_CONTROL_DELAY_REQ_C;
      end if;

      bytes(47) := PTP_LOG_INTERVAL_UNSPECIFIED_C;   -- logMessageInterval.
      -- Reserved fields, flags, correctionField and originTimestamp (48..57)
      -- retain their zero initialization. Pack into low-byte-first AXI lanes.
      for i in bytes'range loop
         resultValue(8*i+7 downto 8*i) := bytes(i);
      end loop;
      return resultValue;
   end function;

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (all) is
      variable v : RegType;
   begin
      v := r;

      if interval.valid = '1' and cancel = '0' then
         v.minimumInterval := unsigned(interval.ticks);
      end if;

      -- TX ownership survives abort. Once valid is presented, every byte and
      -- sideband stays stable under backpressure until the entire frame drains.
      if r.master.tValid = '1' and txSlave.tReady = '1' then
         v.master := AXI_STREAM_MASTER_INIT_C;
         if r.beat /= TX_LAST_BEAT_C then
            v.beat          := r.beat+1;
            v.master.tValid := '1';
            if v.beat = TX_LAST_BEAT_C then
               v.master.tData(8*TX_LAST_BYTES_C-1 downto 0) := r.frame(8*TX_FRAME_BYTES_C-1 downto 8*TX_LAST_BEAT_C*TX_BEAT_BYTES_C);
               v.master.tKeep(TX_BEAT_BYTES_C-1 downto 0)   := TX_LAST_KEEP_C;
               v.master.tLast := '1';
            else
               -- Static slices make the seven-way beat mux explicit to both
               -- synthesis frontends; the final two-byte beat is handled above.
               for i in 0 to TX_LAST_BEAT_C-1 loop
                  if v.beat = i then
                     v.master.tData(8*TX_BEAT_BYTES_C-1 downto 0) := r.frame(8*TX_BEAT_BYTES_C*(i+1)-1 downto 8*TX_BEAT_BYTES_C*i);
                  end if;
               end loop;
               v.master.tKeep(TX_BEAT_BYTES_C-1 downto 0) := (others => '1');
            end if;
         end if;
      end if;

      -- Offer a registered reservation request independently of ledger ready.
      -- Only the actual handshake creates a frame. A local abort on that edge
      -- cannot undo a reservation already accepted by the child: preserve and
      -- transmit that frame, then let the registered cancellation retire it.
      if r.allocate = '0' and enable = '1' and
         r.master.tValid = '0' and cancel = '0' and
         (r.requestStarted = '0' or unsigned(ticks)-unsigned(r.lastRequest) >= r.requestInterval) then
         v.allocate := '1';
      end if;

      if r.allocate = '1' and allocation.ready = '1' and ledgerCancel = '0' then
         v.allocate      := '0';
         v.frame         := buildRequest(config, localMac, allocation.sequenceId);
         v.master        := AXI_STREAM_MASTER_INIT_C;
         v.master.tValid := '1';
         v.master.tKeep(TX_BEAT_BYTES_C-1 downto 0)   := (others => '1');
         v.master.tData(8*TX_BEAT_BYTES_C-1 downto 0) := v.frame(8*TX_BEAT_BYTES_C-1 downto 0);
         ssiSetUserSof(PTP_RX_AXIS_CONFIG_C, v.master, '1');
         v.beat           := 0;
         v.lastRequest    := ticks;
         v.requestStarted := '1';
         -- A bounded three-point schedule (0.5, 1.0, 1.5 times mean) avoids a
         -- runtime multiplier while preserving deterministic seeded variation.
         v.requestInterval := unsigned(config.delayInterval);
         if r.minimumInterval > v.requestInterval then
            v.requestInterval := r.minimumInterval;
         end if;
         if r.lfsr(1 downto 0) = "00" then
            -- Unsigned division rounds the half interval down to whole ticks.
            v.requestInterval := v.requestInterval/2;
         elsif r.lfsr(1 downto 0) = "11" then
            v.requestInterval := v.requestInterval + v.requestInterval/2;
         end if;
         -- Fibonacci LFSR taps 16, 14, 13, 11 (one-based); shift toward bit 15,
         -- feed the XOR into bit 0. A nonzero seed avoids the all-zero lockup.
         v.lfsr := r.lfsr(14 downto 0) & (r.lfsr(15) xor r.lfsr(13) xor r.lfsr(12) xor r.lfsr(10));
      end if;

      if cancel = '1' then
         v.allocate        := '0';
         v.requestStarted  := '0';
         v.minimumInterval := (others => '0');
         v.lfsr            := config.lfsrSeed;
         if unsigned(v.lfsr) = 0 then
            v.lfsr := LFSR_SEED_C;
         end if;
      end if;

      if not RST_ASYNC_G and rst = RST_POLARITY_G then
         v := REG_INIT_C;
      end if;

      rin      <= v;
      allocate <= r.allocate;
      txMaster <= r.master;
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
