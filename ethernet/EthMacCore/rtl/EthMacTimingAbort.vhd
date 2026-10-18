-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Forced-abort sequencer for a timing-mode EthMacTop
-------------------------------------------------------------------------------
-- Implements the MAC side of the timing-port forced abort
-- (ethernet/PtpCore/timing-port.md, section 6, step 3). On request the
-- exporter first ends any frame on the pins with its normal done/doneError
-- and starts no new frame; once it acknowledges, a synchronous flush reset of
-- FLUSH_CYCLES_G cycles clears every other tokened owner (TX FIFO, checksum,
-- pause and export buffering, the import leaf, RX pause/checksum/filter and
-- the RX FIFO). Flushed owners publish no retire. The aggregate acknowledge
-- then holds until the request falls. macRst is ethRst combined with the
-- flush, in the RST_POLARITY_G sense; this sequencer itself sees only ethRst.
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
use surf.EthMacPkg.all;

entity EthMacTimingAbort is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';  -- '1' for active HIGH reset, '0' for active LOW reset
      FLUSH_CYCLES_G : positive := 4);
   port (
      -- Clock and Reset
      ethClk         : in  sl;
      ethRst         : in  sl;
      -- Port-facing handshake
      abortReq       : in  EthMacAbortRequestType;
      abortAck       : out EthMacAbortAckType;
      -- Exporter handshake
      exportAbortReq : out sl;
      exportAbortAck : in  sl;
      -- Reset for every flushed owner
      macRst         : out sl);
end EthMacTimingAbort;

architecture rtl of EthMacTimingAbort is

   type StateType is (
      IDLE_S,
      EXPORT_S,
      FLUSH_S,
      ACK_S);

   type RegType is record
      state     : StateType;
      exportReq : sl;
      flush     : sl;
      count     : natural range 0 to FLUSH_CYCLES_G-1;
      abortAck  : EthMacAbortAckType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state     => IDLE_S,
      exportReq => '0',
      flush     => '0',
      count     => 0,
      abortAck  => ETH_MAC_ABORT_ACK_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (abortReq, ethRst, exportAbortAck, r) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            if (abortReq.request = '1') then
               v.exportReq := '1';
               v.state     := EXPORT_S;
            end if;
         ----------------------------------------------------------------------
         when EXPORT_S =>
            -- The exporter has published the terminal event of any frame on
            -- the pins and is idle; nothing tokened moves on the wire now.
            if (exportAbortAck = '1') then
               v.flush := '1';
               v.count := FLUSH_CYCLES_G-1;
               v.state := FLUSH_S;
            end if;
         ----------------------------------------------------------------------
         when FLUSH_S =>
            if (r.count = 0) then
               v.flush := '0';
               v.state := ACK_S;
            else
               v.count := r.count - 1;
            end if;
         ----------------------------------------------------------------------
         when ACK_S =>
            v.abortAck.acknowledge := abortReq.request;
            if (abortReq.request = '0') then
               v.exportReq := '0';
               v.state     := IDLE_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (ethRst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      abortAck       <= r.abortAck;
      exportAbortReq <= r.exportReq;
      if (RST_POLARITY_G = '1') then
         macRst <= ethRst or r.flush;
      else
         macRst <= ethRst and not r.flush;
      end if;

   end process comb;

   seq : process (ethClk) is
   begin
      if rising_edge(ethClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
