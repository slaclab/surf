-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Passive GMII/XGMII RX framing with inseparable SOF capture
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
use surf.SsiPkg.all;
use surf.PtpPkg.all;

entity PtpRxTimestampAdapter is
   generic (
      TPD_G             : time             := 1 ns;
      RST_POLARITY_G    : sl               := '1';
      RST_ASYNC_G       : boolean          := false;
      TX_OBSERVE_G      : boolean          := false;
      PHY_TYPE_G        : string           := "XGMII";
      INGRESS_LATENCY_G : slv(63 downto 0) := (others => '0'));
   port (
      -- One continuously running Ethernet clock domain. The owner must also
      -- flush the downstream frontend on link loss or a generation change.
      clk          : in  sl;
      rst          : in  sl;
      rxFlush      : in  sl;
      phyReady     : in  sl;
      generation   : in  slv(31 downto 0);
      -- PHC and unsteered counter values describe the current sampling edge.
      -- Capture uses the first byte after SFD, so a command/generation change
      -- at that edge can suppress the entire observation without extrapolation.
      phcTime      : in  PtpTimeType;
      phcIncrement : in  slv(63 downto 0);
      tickCount    : in  slv(63 downto 0);
      timeValid    : in  sl;
      captureAbort : in  sl               := '0';
      xgmiiRxd     : in  slv(63 downto 0) := (others => '0');
      xgmiiRxc     : in  slv(7 downto 0)  := (others => '1');
      gmiiRxd      : in  slv(7 downto 0)  := (others => '0');
      gmiiRxDv     : in  sl               := '0';
      gmiiRxEr     : in  sl               := '0';
      -- Registered, non-backpressurable output. Bytes include FCS but exclude
      -- preamble/control symbols; rxCapture is meaningful with the SOF beat.
      rxMaster     : out AxiStreamMasterType;
      rxCapture    : out PtpRxCaptureType);
end entity PtpRxTimestampAdapter;

architecture rtl of PtpRxTimestampAdapter is

   -- SEARCH finds a legal start; PREAMBLE qualifies all preamble/SFD bytes;
   -- FRAME forwards bytes; DRAIN ignores a damaged frame until its physical
   -- termination. Preamble state and the pending-first-byte flag can cross a
   -- word boundary, which is required for XGMII lane-four starts.
   type StateType is (
      SEARCH_S,
      PREAMBLE_S,
      FRAME_S,
      DRAIN_S);

   type RegType is record
      state      : StateType;
      preamble   : natural range 0 to 7;
      first      : sl;
      generation : slv(31 downto 0);
      master     : AxiStreamMasterType;
      capture    : PtpRxCaptureType;
   end record;

   constant REG_INIT_C : RegType := (
      state      => SEARCH_S,
      preamble   => 0,
      first      => '0',
      generation => (others => '0'),
      master     => AXI_STREAM_MASTER_INIT_C,
      capture    => PTP_RX_CAPTURE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   assert PHY_TYPE_G = "GMII" or PHY_TYPE_G = "XGMII"
      report "PtpRxTimestampAdapter supports 1G GMII or 10G XGMII" severity failure;

   comb : process (r, rst, rxFlush, phyReady, generation, phcTime, phcIncrement, captureAbort,
                   tickCount, timeValid, xgmiiRxd, xgmiiRxc, gmiiRxd, gmiiRxDv, gmiiRxEr) is
      variable v           : RegType;
      variable octet       : slv(7 downto 0);
      variable count       : natural range 0 to 8;
      variable captureLane : natural range 0 to 7;
   begin
      v := r;

      -- Rebuild one output beat each cycle. The capture is held separately in
      -- the same RegType so its value survives later beats without being
      -- sampled again or delayed independently of SOF.
      v.master       := AXI_STREAM_MASTER_INIT_C;
      v.master.tKeep := (others => '0');
      count          := 0;
      captureLane    := 0;
      if PHY_TYPE_G = "XGMII" then
         -- Walk lanes in wire order using v.state: a delimiter in an earlier
         -- lane affects later lanes of this same word. This loop is unrolled
         -- logic, not an eight-cycle serializer. count packs payload into
         -- contiguous low AXI lanes after stripping physical control symbols.
         for lane in 0 to 7 loop
            octet := xgmiiRxd(8*lane+7 downto 8*lane);
            case v.state is
               when SEARCH_S =>
                  -- /S/ replaces the first preamble octet and is recognized
                  -- only in legal start lanes. Data-valued 0xFB is not /S/.
                  if xgmiiRxc(lane) = '1' and octet = x"FB" and (lane = 0 or lane = 4) then
                     v.state    := PREAMBLE_S;
                     v.preamble := 0;
                  end if;
               when PREAMBLE_S =>
                  -- Six remaining 0x55 bytes followed by data-valued SFD.
                  -- Nothing is forwarded until the complete preamble matches.
                  if xgmiiRxc(lane) = '0' and octet = x"55" and v.preamble < 6 then
                     v.preamble := v.preamble+1;
                  elsif xgmiiRxc(lane) = '0' and octet = x"D5" and v.preamble = 6 then
                     v.state := FRAME_S;
                     v.first := '1';
                  else
                     v.state := DRAIN_S;
                     if xgmiiRxc(lane) = '1' and octet = x"FD" then
                        v.state := SEARCH_S;
                     end if;
                  end if;
               when FRAME_S =>
                  v.master.tValid := '1';
                  if xgmiiRxc(lane) = '0' then
                     if v.first = '1' then
                        -- This is the PTP message timestamp point: the first
                        -- destination-MAC byte, one byte after SFD. Save its
                        -- physical lane before packing it into AXI lane zero.
                        captureLane := lane;
                        ssiSetUserSof(PTP_RX_AXIS_CONFIG_C, v.master, '1');
                        v.first     := '0';
                     end if;
                     v.master.tData(8*count+7 downto 8*count) := octet;
                     v.master.tKeep(count)                    := '1';
                     count                                    := count+1;
                  else
                     -- /T/ ends the frame; any other in-frame control emits
                     -- an error termination and drains the damaged remainder.
                     -- count may be zero when /T/ follows a full prior word;
                     -- the resulting empty TLAST still completes validation.
                     v.master.tLast := '1';
                     if octet = x"FD" then
                        v.state := SEARCH_S;
                     else
                        ssiSetUserEofe(PTP_RX_AXIS_CONFIG_C, v.master, '1');
                        v.state := DRAIN_S;
                     end if;
                  end if;
               when DRAIN_S =>
                  -- In particular, a nested /S/ cannot retimestamp bytes from
                  -- the damaged frame. Require /T/ before searching again.
                  if xgmiiRxc(lane) = '1' and octet = x"FD" then
                     v.state := SEARCH_S;
                  end if;
            end case;
         end loop;
      else
         -- 1G GMII has one byte per cycle and carries all seven preamble bytes.
         -- There is no clock-enable handling for 10/100 modes in this slice.
         case v.state is
            when SEARCH_S =>
               if gmiiRxDv = '1' then
                  v.state := DRAIN_S;
                  if gmiiRxEr = '0' and gmiiRxd = x"55" then
                     v.state    := PREAMBLE_S;
                     v.preamble := 1;
                  end if;
               end if;
            when PREAMBLE_S =>
               if gmiiRxDv = '0' then
                  v.state := SEARCH_S;
               elsif gmiiRxEr = '0' and gmiiRxd = x"55" and v.preamble < 7 then
                  v.preamble := v.preamble+1;
               elsif gmiiRxEr = '0' and gmiiRxd = x"D5" and v.preamble = 7 then
                  v.state := FRAME_S;
                  v.first := '1';
               else
                  v.state := DRAIN_S;
               end if;
            when FRAME_S =>
               v.master.tValid := '1';
               if gmiiRxDv = '1' and gmiiRxEr = '0' then
                  if v.first = '1' then
                     captureLane := 0;
                     ssiSetUserSof(PTP_RX_AXIS_CONFIG_C, v.master, '1');
                     v.first     := '0';
                  end if;
                  v.master.tData(7 downto 0) := gmiiRxd;
                  v.master.tKeep(0)          := '1';
               else
                  -- A DV falling edge emits an empty final beat after the last
                  -- FCS byte. RX_ER instead terminates with EOFE, and if DV is
                  -- still high, DRAIN prevents accepting its remaining bytes.
                  v.master.tLast := '1';
                  v.state        := SEARCH_S;
                  if gmiiRxEr = '1' then
                     ssiSetUserEofe(PTP_RX_AXIS_CONFIG_C, v.master, '1');
                     if gmiiRxDv = '1' then
                        v.state := DRAIN_S;
                     end if;
                  end if;
               end if;
            when DRAIN_S =>
               if gmiiRxDv = '0' then
                  v.state := SEARCH_S;
               end if;
         end case;
      end if;
      -- A word can contain at most one accepted frame start. Compute the
      -- capture once after lane decoding instead of replicating the wide
      -- normalization/calibration arithmetic in each unrolled lane.
      if ssiGetUserSof(PTP_RX_AXIS_CONFIG_C, v.master) = '1' then
         v.capture       := ptpRxCapture(phcTime, phcIncrement, captureLane, tickCount,
                                  generation, timeValid, INGRESS_LATENCY_G);
         v.capture.error := v.capture.error or captureAbort;
      end if;
      -- These conditions win over any SOF/EOF decoded above, clearing both
      -- the pending frame and the output beat. Remember the new generation
      -- so admission can resume on a subsequent clean physical start.
      if rxFlush = '1' or phyReady = '0' or (not TX_OBSERVE_G and generation /= r.generation) then
         v            := REG_INIT_C;
         v.generation := generation;
      end if;
      if not RST_ASYNC_G and rst = RST_POLARITY_G then
         v := REG_INIT_C;
      end if;
      rin <= v;
      -- Both outputs come from the same register boundary. Never derive the
      -- capture from v while exposing frame bytes from r (or vice versa).
      rxMaster  <= r.master;
      rxCapture <= r.capture;
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
