-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Timing-capable MAC port: ownership, captures and lifecycle
-------------------------------------------------------------------------------
-- Controller-facing timing port for a timing-mode EthMacTop
-- (ethernet/PtpCore/timing-port.md). PtpMacPortTx admits tokened TX requests
-- and returns one completion per request; PtpMacPortRx allocates RX tokens
-- and delivers frames with their captures. This level registers the PHC
-- tuple on every edge, so both halves evaluate a capture from the values
-- that stood while the frame's first destination-MAC octet was on the pins
-- (section 2.4); owns the transport generation (section 6.1); and sequences
-- graceful drain and the four-step forced abort (section 6): close admission,
-- controller cancellation, MAC/hold-store owner abort, then one release of
-- every remaining entry with a generation advance.
--
-- All ports are in the Ethernet clock domain. ethClkEn must stay high; the
-- port reports a sticky fault if it ever samples it low.
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
use surf.EthMacPkg.all;
use surf.PtpPkg.all;

entity PtpMacPort is
   generic (
      TPD_G                 : time                    := 1 ns;
      RST_POLARITY_G        : sl                      := '1';  -- '1' for active HIGH reset, '0' for active LOW reset
      TX_TABLE_DEPTH_G      : positive range 1 to 255 := 16;
      RX_TABLE_DEPTH_G      : positive range 1 to 255 := 16;
      TX_STORE_ADDR_WIDTH_G : positive range 8 to 16  := 8;
      MEMORY_TYPE_G         : string                  := "block";
      SYNTH_MODE_G          : string                  := "inferred";
      INGRESS_LATENCY_G     : slv(63 downto 0)        := (others => '0');
      EGRESS_LATENCY_G      : slv(63 downto 0)        := (others => '0'));
   port (
      -- Ethernet clock and system reset
      clk              : in  sl;
      rst              : in  sl;
      ethClkEn         : in  sl := '1';
      -- PHC state standing during the current cycle
      phcTime          : in  PtpTimeType;
      phcStatus        : in  PtpPhcStatusType;
      captureAbort     : in  sl := '0';
      -- Controller lifecycle
      control          : in  PtpMacPortControlType;
      status           : out PtpMacPortStatusType;
      counters         : out PtpMacPortCountersType;
      -- Controller TX
      txMaster         : in  PtpMacPortTxMasterType;
      txSlave          : out AxiStreamSlaveType;
      completionMaster : out PtpMacPortTxCompletionMasterType;
      completionReady  : in  sl;
      -- Controller RX
      rxMaster         : out PtpMacPortRxMasterType;
      rxReady          : in  sl;
      -- Timing-mode EthMacTop
      macTxMaster      : out AxiStreamMasterType;
      macTxSlave       : in  AxiStreamSlaveType;
      macRxMaster      : in  AxiStreamMasterType;
      macRxSlave       : out AxiStreamSlaveType;
      rxNextToken      : out EthMacTokenType;
      rxFrameEvent     : in  EthMacFrameEventType;
      rxRetire         : in  EthMacTokenRetireArray(EMAC_RX_RETIRE_SOURCES_C-1 downto 0);
      txFrameEvent     : in  EthMacFrameEventType;
      txRetire         : in  EthMacTokenRetireArray(EMAC_TX_RETIRE_SOURCES_C-1 downto 0);
      macAbortReq      : out EthMacAbortRequestType;
      macAbortAck      : in  EthMacAbortAckType);
end entity PtpMacPort;

architecture rtl of PtpMacPort is

   -- RUN_S carries traffic; the ABORT states are section 6 steps two to four
   type StateType is (
      RUN_S,
      CANCEL_S,
      OWNERS_S,
      DONE_S);

   type RegType is record
      state        : StateType;
      phcTime      : PtpTimeType;
      phcStatus    : PtpPhcStatusType;
      captureAbort : sl;
      openPrev     : sl;
      admitOpen    : sl;
      generation   : slv(15 downto 0);
      cancelReq    : sl;
      macAbortReq  : EthMacAbortRequestType;
      txFlush      : sl;
      releaseAll   : sl;
      status       : PtpMacPortStatusType;
      counters     : PtpMacPortCountersType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state        => RUN_S,
      phcTime      => PTP_TIME_INIT_C,
      phcStatus    => PTP_PHC_STATUS_INIT_C,
      captureAbort => '0',
      openPrev     => '0',
      admitOpen    => '0',
      generation   => PTP_MAC_PORT_GENERATION_RESET_C,
      cancelReq    => '0',
      macAbortReq  => ETH_MAC_ABORT_REQUEST_INIT_C,
      txFlush      => '0',
      releaseAll   => '0',
      status       => PTP_MAC_PORT_STATUS_INIT_C,
      counters     => PTP_MAC_PORT_COUNTERS_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal admit          : sl;
   signal txIdle         : sl;
   signal rxIdle         : sl;
   signal rxCancelDone   : sl;
   signal txFault        : sl;
   signal rxFault        : sl;
   signal countSent      : sl;
   signal countWireError : sl;
   signal countDiscarded : sl;
   signal countFlushed   : sl;
   signal countRejected  : sl;
   signal incDelivered   : slv(0 downto 0);
   signal incDropped     : slv(8 downto 0);
   signal incLost        : slv(1 downto 0);

   -- Saturating counter step
   function bump (count : slv(31 downto 0); step : natural) return slv is
      variable sum : unsigned(32 downto 0);
   begin
      sum := resize(unsigned(count), 33) + step;
      if (sum(32) = '1') then
         return x"FFFFFFFF";
      end if;
      return slv(sum(31 downto 0));
   end function bump;

begin

   comb : process (captureAbort, control, ethClkEn, countDiscarded, countFlushed,
                   countRejected, countSent, countWireError, incDelivered, incDropped,
                   incLost, macAbortAck, phcStatus, phcTime, r, rst, rxCancelDone,
                   rxFault, rxIdle, txFault, txIdle) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- The PHC tuple standing during this cycle, for captures next cycle
      v.phcTime      := phcTime;
      v.phcStatus    := phcStatus;
      v.captureAbort := captureAbort;

      v.releaseAll := '0';
      v.openPrev   := control.openAdmission;

      case r.state is
         ----------------------------------------------------------------------
         when RUN_S =>
            -- openAdmission rising: the first live generation leaves reset
            if (control.openAdmission = '1') and (r.openPrev = '0') and
               (r.status.faultGeneration = '0') then
               v.admitOpen := '1';
               if (r.generation = PTP_MAC_PORT_GENERATION_RESET_C) then
                  v.generation := x"0001";
               end if;
            end if;
            if (control.abortRequest = '1') then
               -- Step one: close; step two: ask the controller to cancel
               v.admitOpen      := '0';
               v.cancelReq := '1';
               v.state     := CANCEL_S;
            end if;
         ----------------------------------------------------------------------
         when CANCEL_S =>
            if (control.cancelAck = '1') and (rxCancelDone = '1') then
               -- Step three: every MAC owner and the hold store
               v.macAbortReq.request := '1';
               v.txFlush             := '1';
               v.state               := OWNERS_S;
            end if;
         ----------------------------------------------------------------------
         when OWNERS_S =>
            if (macAbortAck.acknowledge = '1') then
               -- Step four: done events of step three are already applied
               v.releaseAll          := '1';
               v.macAbortReq.request := '0';
               v.txFlush             := '0';
               v.cancelReq           := '0';
               if (r.generation = x"FFFE") or (r.generation = PTP_MAC_PORT_GENERATION_EXHAUST_C) then
                  v.generation             := PTP_MAC_PORT_GENERATION_EXHAUST_C;
                  v.status.faultGeneration := '1';
               else
                  v.generation := slv(unsigned(r.generation) + 1);
               end if;
               v.state := DONE_S;
            end if;
         ----------------------------------------------------------------------
         when DONE_S =>
            if (control.abortRequest = '0') then
               v.state := RUN_S;
            end if;
      end case;

      -- Sticky faults
      if (ethClkEn = '0') then
         v.status.faultClockEnable := '1';
      end if;
      if (txFault = '1') or (rxFault = '1') then
         v.status.faultTokenProtocol := '1';
      end if;
      if (v.generation = PTP_MAC_PORT_GENERATION_EXHAUST_C) then
         v.admitOpen := '0';
      end if;

      -- Status
      v.status.admissionOpen       := v.admitOpen and not control.drainRequest;
      v.status.drainIdle           := txIdle and rxIdle;
      v.status.cancelRequest       := v.cancelReq;
      v.status.abortDone           := '0';
      if (v.state = DONE_S) then
         v.status.abortDone := '1';
      end if;
      v.status.transportGeneration := v.generation;

      -- Saturating counters
      v.counters.rxDelivered := bump(r.counters.rxDelivered, to_integer(unsigned(incDelivered)));
      v.counters.rxDropped   := bump(r.counters.rxDropped, to_integer(unsigned(incDropped)));
      v.counters.rxLost      := bump(r.counters.rxLost, to_integer(unsigned(incLost)));
      if (countSent = '1') then
         v.counters.txSent := bump(r.counters.txSent, 1);
      end if;
      if (countWireError = '1') then
         v.counters.txWireError := bump(r.counters.txWireError, 1);
      end if;
      if (countDiscarded = '1') then
         v.counters.txDiscarded := bump(r.counters.txDiscarded, 1);
      end if;
      if (countFlushed = '1') then
         v.counters.txFlushed := bump(r.counters.txFlushed, 1);
      end if;
      if (countRejected = '1') then
         v.counters.txRejected := bump(r.counters.txRejected, 1);
      end if;

      -- Reset
      if (rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Registered outputs
      admit       <= r.status.admissionOpen;
      status      <= r.status;
      counters    <= r.counters;
      macAbortReq <= r.macAbortReq;

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_Tx : entity surf.PtpMacPortTx
      generic map (
         TPD_G              => TPD_G,
         RST_POLARITY_G     => RST_POLARITY_G,
         TABLE_DEPTH_G      => TX_TABLE_DEPTH_G,
         STORE_ADDR_WIDTH_G => TX_STORE_ADDR_WIDTH_G,
         MEMORY_TYPE_G      => MEMORY_TYPE_G,
         SYNTH_MODE_G       => SYNTH_MODE_G,
         EGRESS_LATENCY_G   => EGRESS_LATENCY_G)
      port map (
         clk              => clk,
         rst              => rst,
         admit            => admit,
         generation       => r.generation,
         flush            => r.txFlush,
         releaseAll       => r.releaseAll,
         idle             => txIdle,
         protocolFault    => txFault,
         phcTime          => r.phcTime,
         phcStatus        => r.phcStatus,
         captureAbort     => r.captureAbort,
         txMaster         => txMaster,
         txSlave          => txSlave,
         completionMaster => completionMaster,
         completionReady  => completionReady,
         macTxMaster      => macTxMaster,
         macTxSlave       => macTxSlave,
         txFrameEvent     => txFrameEvent,
         txRetire         => txRetire,
         countSent        => countSent,
         countWireError   => countWireError,
         countDiscarded   => countDiscarded,
         countFlushed     => countFlushed,
         countRejected    => countRejected);

   U_Rx : entity surf.PtpMacPortRx
      generic map (
         TPD_G             => TPD_G,
         RST_POLARITY_G    => RST_POLARITY_G,
         TABLE_DEPTH_G     => RX_TABLE_DEPTH_G,
         INGRESS_LATENCY_G => INGRESS_LATENCY_G)
      port map (
         clk           => clk,
         rst           => rst,
         offer         => admit,
         generation    => r.generation,
         cancel        => r.cancelReq,
         releaseAll    => r.releaseAll,
         cancelDone    => rxCancelDone,
         idle          => rxIdle,
         protocolFault => rxFault,
         phcTime       => r.phcTime,
         phcStatus     => r.phcStatus,
         captureAbort  => r.captureAbort,
         rxNextToken   => rxNextToken,
         rxFrameEvent  => rxFrameEvent,
         rxRetire      => rxRetire,
         macRxMaster   => macRxMaster,
         macRxSlave    => macRxSlave,
         rxMaster      => rxMaster,
         rxReady       => rxReady,
         incDelivered  => incDelivered,
         incDropped    => incDropped,
         incLost       => incLost);

end architecture rtl;
