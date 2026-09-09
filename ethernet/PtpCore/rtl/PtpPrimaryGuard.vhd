-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Reserve PTP transmit ownership at the application's EMAC
-- stream.
--
-- Inspects the first 16-byte primary TX beat, which must contain the complete
-- Ethernet header, full TKEEP and SSI SOF. Untagged EtherType 0x88F7 frames
-- and malformed initial beats are consumed and discarded through TLAST, with a
-- saturating count of rejected frames. This prevents application traffic from
-- impersonating a Delay_Req key reserved by the endpoint's private PTP
-- producer.
--
-- Other frames pass through a single registered ready/valid stage with the
-- complete AXI Stream record preserved, including payload and sidebands. The
-- frame decision is retained until TLAST, and accepted output data stays
-- stable under downstream backpressure.
--
-- EthMacPtpEndpoint places this guard before EthMacTop's primary TX input. The
-- private PTP stream enters through the MAC bypass path. This block assumes
-- EMAC_AXIS_CONFIG_C and classifies untagged Ethernet headers; it is not a
-- general packet parser.
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.EthMacPkg.all;
use surf.PtpPkg.all;

entity PtpPrimaryGuard is
   generic (
      TPD_G          : time := 1 ns;
      RST_POLARITY_G : sl   := '1');
   port (
      clk          : in  sl;
      rst          : in  sl;
      sMaster      : in  AxiStreamMasterType;
      sSlave       : out AxiStreamSlaveType;
      mMaster      : out AxiStreamMasterType;
      mSlave       : in  AxiStreamSlaveType;
      droppedCount : out slv(31 downto 0));
end entity PtpPrimaryGuard;

architecture rtl of PtpPrimaryGuard is

   type RegType is record
      -- Current-cycle calculations and diagnostics. Use v for same-edge
      -- decisions; these fields do not introduce a protocol pipeline stage.
      ready    : sl;
      discard  : sl;

      master   : AxiStreamMasterType;
      first    : sl;
      dropping : sl;
      dropped  : slv(31 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      ready    => '0',
      discard  => '0',
      master   => AXI_STREAM_MASTER_INIT_C,
      first    => '1',
      dropping => '0',
      dropped  => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (r, rst, sMaster, mSlave) is
      variable v : RegType;
   begin
      v := r;

      -- Drain an old output beat first; rejected frames can keep consuming
      -- input independently of downstream readiness.
      v.ready := not r.master.tValid or mSlave.tReady or r.dropping;
      if mSlave.tReady = '1' then
         v.master.tValid := '0';
      end if;
      -- Classify only the first accepted beat, then carry that decision
      -- through TLAST while preserving all forwarded stream sidebands.
      if sMaster.tValid = '1' and v.ready = '1' then
         v.discard := r.dropping;
         if r.first = '1' then
            v.discard := '0';
            -- The 16-byte EMAC first beat contains the complete L2 header.
            -- Reserve all untagged PTP on primary TX, preventing an application
            -- from impersonating a Delay_Req key owned by the endpoint ledger.
            -- A fragmented/short first beat is outside this wrapper's EMAC
            -- contract and is also drained, never partially sent to the MAC.
            if sMaster.tKeep(15 downto 0) /= x"FFFF" or
               axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, sMaster, EMAC_SOF_BIT_C, 0) = '0' or
               sMaster.tData(111 downto 96) = x"F788" then
               v.discard := '1';
               v.dropped := ptpSatInc(r.dropped);
            end if;
         end if;
         if v.discard = '0' then
            v.master := sMaster;
         end if;
         v.first    := sMaster.tLast;
         v.dropping := v.discard and not sMaster.tLast;
      end if;
      if rst = RST_POLARITY_G then
         v       := REG_INIT_C;
         v.ready := '0';
      end if;
      rin           <= v;
      sSlave.tReady <= v.ready;
      mMaster       <= r.master;
      droppedCount  <= r.dropped;
   end process comb;
   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
