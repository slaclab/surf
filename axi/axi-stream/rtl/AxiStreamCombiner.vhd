------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Combines multiple "narrower" buses into a "wide" AXI stream bus
-------------------------------------------------------------------------------
-- Note: This module does NOT support interleaving of TDEST
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
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

entity AxiStreamCombiner is
   generic (
      TPD_G               : time     := 1 ns;
      RST_ASYNC_G         : boolean  := false;
      LANES_G             : positive := 4;
      SLAVE_AXI_CONFIG_G  : AxiStreamConfigType;
      MASTER_AXI_CONFIG_G : AxiStreamConfigType);
   port (
      -- Clock and Reset
      axisClk      : in  sl;
      axisRst      : in  sl;
      -- Slave Ports
      sAxisMasters : in  AxiStreamMasterArray(LANES_G-1 downto 0);
      sAxisSlaves  : out AxiStreamSlaveArray (LANES_G-1 downto 0);
      -- Master Port
      mAxisMaster  : out AxiStreamMasterType;
      mAxisSlave   : in  AxiStreamSlaveType);
end AxiStreamCombiner;

architecture rtl of AxiStreamCombiner is

   constant SEQ_C : slv(15 downto 8) := x"55";

   type FrameState is (
      SOF_S,
      EOF_S,
      ERR_S);

   type RegType is record
      master  : AxiStreamMasterType;
      state   : FrameState;
      sof     : sl;
      first   : slv (LANES_G-1 downto 0);
      discard : slv (LANES_G-1 downto 0);
      slaves  : AxiStreamSlaveArray (LANES_G-1 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      master  => axiStreamMasterInit(MASTER_AXI_CONFIG_G),
      state   => SOF_S,
      sof     => '0',
      first   => (others => '1'),
      discard => (others => '0'),
      slaves  => (others => AXI_STREAM_SLAVE_INIT_C));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   assert (MASTER_AXI_CONFIG_G.TDATA_BYTES_C = LANES_G*SLAVE_AXI_CONFIG_G.TDATA_BYTES_C)
      report "MASTER_AXI_CONFIG_G.TDATA_BYTES_C must be LANES_G*SLAVE_AXI_CONFIG_G.TDATA_BYTES_C" severity failure;

   comb : process (axisRst, mAxisSlave, r, sAxisMasters) is
      variable v      : RegType;
      variable m, n   : integer;
      variable hdrErr : sl;
      variable seqOff : Slv8Array(LANES_G-1 downto 1);
      variable notSeq : slv(LANES_G-1 downto 0);
      variable ready  : sl;
      variable tready : slv(LANES_G-1 downto 0);
      variable tlast  : slv(LANES_G-1 downto 0);
   begin
      -- Latch the current value
      v := r;

      tready := (others => '0');

      for i in 0 to LANES_G-1 loop
         tlast(i) := sAxisMasters(i).tLast;
      end loop;

      -- process acknowledge
      if mAxisSlave.tReady = '1' then
         v.master.tValid := '0';
      end if;

      -- wait for all streams to contribute
      ready := '1';
      for i in 0 to LANES_G-1 loop
         if sAxisMasters(i).tValid = '0' then
            ready := '0';
         end if;
      end loop;

      case r.state is
         when SOF_S =>
            if ready = '1' then
               if allBits(r.first, '1') then  -- wait for all lanes to start
                  --  test sequence numbers
                  notSeq := (others => '0');
                  for i in 0 to LANES_G-1 loop
                     if sAxisMasters(i).tData(SEQ_C'range) /= SEQ_C then
                        notSeq(i) := '1';
                     end if;
                  end loop;
                  if notSeq /= 0 then
                     v.discard := notSeq;
                     v.state   := ERR_S;
                  else
                     hdrErr := '0';
                     for i in 1 to LANES_G-1 loop
                        seqOff(i) := sAxisMasters(i).tData(7 downto 0) - sAxisMasters(0).tData(7 downto 0);
                        if sAxisMasters(0).tData(7 downto 0) /= sAxisMasters(i).tData(7 downto 0) then
                           hdrErr := '1';
                        end if;
                     end loop;
                     if hdrErr = '1' then  -- sequence mismatch - discard late lanes
                        v.discard := (others => '0');
                        for i in 1 to LANES_G-1 loop
                           if seqOff(i)(7) = '1' then
                              v.discard(i) := '1';
                           elsif seqOff(i) /= 0 then
                              v.discard(0) := '1';
                           end if;
                        end loop;
                        v.state := ERR_S;
                     else
                        tready    := (others => '1');
                        v.discard := (others => '0');
                        v.sof     := '1';
                        v.state   := EOF_S;
                     end if;
                  end if;
               else
                  v.discard := not r.first;
                  v.state   := ERR_S;
               end if;
            end if;
         when EOF_S =>
            if ready = '1' and v.master.tValid = '0' then
               v.sof    := '0';
               tready   := (others => '1');
               v.master := sAxisMasters(0);
               -- assemble the data
               for i in 0 to LANES_G-1 loop
                  for j in 0 to SLAVE_AXI_CONFIG_G.TDATA_BYTES_C-1 loop
                     m                            := 8*j;
                     n                            := 8*(LANES_G*j+i);
                     v.master.tData(n+7 downto n) := sAxisMasters(i).tData(m+7 downto m);
                     v.master.tKeep(LANES_G*j+i)  := sAxisMasters(i).tKeep(j);
                  end loop;
               end loop;
               -- user bits
               ssiSetUserSof(MASTER_AXI_CONFIG_G, v.master, r.sof);
               -- cleanup
               if allBits(tlast, '0') then
                  v.discard      := (others => '0');
                  v.master.tLast := '0';
               elsif allBits(tlast, '1') then
                  v.discard      := (others => '0');
                  v.master.tLast := '1';
                  v.state        := SOF_S;
               else
                  v.discard      := not tlast;
                  v.master.tLast := '1';
                  ssiSetUserEofe(MASTER_AXI_CONFIG_G, v.master, '1');
                  v.state        := ERR_S;
               end if;
            end if;
         when ERR_S =>
            for i in 0 to LANES_G-1 loop
               if r.discard(i) = '1' then
                  tready (i)   := '1';  -- sink
                  v.discard(i) := not sAxisMasters(i).tLast;
               end if;
               if v.discard = 0 then
                  v.state := SOF_S;
               end if;
            end loop;
      end case;

      --  start of packet is first tValid after tLast acknowledged
      for i in 0 to LANES_G-1 loop
         v.slaves(i).tReady := tready(i);
         if sAxisMasters(i).tValid = '1' and v.slaves(i).tReady = '1' then
            v.first (i) := sAxisMasters(i).tLast;
         end if;
      end loop;

      -- Outputs
      sAxisSlaves <= v.slaves;
      mAxisMaster <= r.master;

      -- Synchronous Reset
      if (RST_ASYNC_G = false and axisRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (axisClk, axisRst) is
   begin
      if (RST_ASYNC_G) and (axisRst = '1') then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(axisClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
