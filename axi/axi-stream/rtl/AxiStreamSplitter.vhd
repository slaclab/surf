------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: splits a "wide" AXI stream bus into multiple "narrower" buses
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

entity AxiStreamSplitter is
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
      -- Slave Port
      sAxisMaster  : in  AxiStreamMasterType;
      sAxisSlave   : out AxiStreamSlaveType;
      -- Master Ports
      mAxisMasters : out AxiStreamMasterArray(LANES_G-1 downto 0);
      mAxisSlaves  : in  AxiStreamSlaveArray (LANES_G-1 downto 0));
end AxiStreamSplitter;

architecture rtl of AxiStreamSplitter is

   constant SEQ_C : slv(15 downto 8) := x"55";

   type RegType is record
      masters : AxiStreamMasterArray(LANES_G-1 downto 0);
      nready  : slv (LANES_G-1 downto 0);
      tSeq    : slv (7 downto 0);
      first   : sl;
      slave   : AxiStreamSlaveType;
   end record;

   constant REG_INIT_C : RegType := (
      masters => (others => axiStreamMasterInit(MASTER_AXI_CONFIG_G)),
      nready  => (others => '0'),
      tSeq    => (others => '0'),
      first   => '1',
      slave   => AXI_STREAM_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   assert (SLAVE_AXI_CONFIG_G.TDATA_BYTES_C = LANES_G*MASTER_AXI_CONFIG_G.TDATA_BYTES_C)
      report "SLAVE_AXI_CONFIG_G.TDATA_BYTES_C must be LANES_G*MASTER_AXI_CONFIG_G.TDATA_BYTES_C" severity failure;

   comb : process (axisRst, mAxisSlaves, r, sAxisMaster) is
      variable v    : RegType;
      variable m, n : integer;
   begin
      -- Latch the current value
      v := r;

      -- AXI stream flow control
      v.slave.tReady := '0';
      if v.nready /= 0 then
         for i in 0 to LANES_G-1 loop
            if mAxisSlaves(i).tReady = '1' then
               v.nready (i)        := '0';
               v.masters(i).tValid := '0';
            end if;
         end loop;
      end if;

      if v.nready = 0 then
         if sAxisMaster.tValid = '1' then

            if (r.first = '1') then

               --  Insert user sequence# for maintaining alignment of interleaved streams
               v.first := '0';
               for i in 0 to LANES_G-1 loop
                  axiStreamSetUserBit(MASTER_AXI_CONFIG_G, v.masters(i), SSI_SOF_C, '1', 0);
                  v.nready (i)                     := '1';
                  v.masters(i).tValid              := '1';
                  v.masters(i).tLast               := '0';
                  v.masters(i).tData(SEQ_C'range)  := SEQ_C;
                  v.masters(i).tData(r.tSeq'range) := r.tSeq;
                  v.masters(i).tKeep               := genTKeep(MASTER_AXI_CONFIG_G.TDATA_BYTES_C);
                  v.masters(i).tDest               := sAxisMaster.tDest;
                  v.tSeq                           := r.tSeq+1;
               end loop;

            else

               v.slave.tReady := '1';
               v.first        := sAxisMaster.tLast;
               for i in 0 to LANES_G-1 loop
                  v.nready (i)        := '1';
                  v.masters(i).tValid := '1';
                  v.masters(i).tLast  := sAxisMaster.tLast;

                  -- set user bits
                  axiStreamSetUserBit(MASTER_AXI_CONFIG_G, v.masters(i), SSI_SOF_C, '0', 0);
                  if sAxisMaster.tLast = '1' then
                     axiStreamSetUserBit(MASTER_AXI_CONFIG_G, v.masters(i), SSI_EOFE_C, '0', 0);
                  end if;

                  -- distribute data
                  for j in 0 to MASTER_AXI_CONFIG_G.TDATA_BYTES_C-1 loop
                     m                                := 8*j;
                     n                                := 8*(LANES_G*j+i);
                     v.masters(i).tData(m+7 downto m) := sAxisMaster.tData(n+7 downto n);
                     v.masters(i).tKeep(j)            := sAxisMaster.tKeep(LANES_G*j+i);
                  end loop;
               end loop;
            end if;
         end if;
      end if;

      -- Outputs
      sAxisSlave   <= v.slave;
      mAxisMasters <= r.masters;

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
