-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- Append transactions from a stream to transactions from another.
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
use ieee.std_logic_arith.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;

entity AxiStreamTrailerAppend is
   generic (
      TPD_G                     : time    := 1 ns;
      RST_ASYNC_G               : boolean := false;
      PIPE_STAGES_G             : natural := 0;
      TRAILER_AXI_CONFIG_G      : AxiStreamConfigType;
      MASTER_SLAVE_AXI_CONFIG_G : AxiStreamConfigType);
   port (
      -- Clock and Reset
      axisClk            : in  sl;
      axisRst            : in  sl;
      -- Slave port
      sAxisMaster        : in  AxiStreamMasterType;
      sAxisSlave         : out AxiStreamSlaveType;
      -- Trailer data
      sAxisTrailerMaster : in  AxiStreamMasterType;
      sAxisTrailerSlave  : out AxiStreamSlaveType;
      -- Master port
      mAxisMaster        : out AxiStreamMasterType;
      mAxisSlave         : in  AxiStreamSlaveType);
end entity AxiStreamTrailerAppend;

architecture rtl of AxiStreamTrailerAppend is

   type RegType is record
      obMaster : AxiStreamMasterType;
      ibSlaves : AxiStreamSlaveArray(1 downto 0);
      sel      : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      obMaster => axiStreamMasterInit(MASTER_SLAVE_AXI_CONFIG_G),
      ibSlaves => (others => AXI_STREAM_SLAVE_INIT_C),
      sel      => '0'
      );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal pipeAxisMaster : AxiStreamMasterType;
   signal pipeAxisSlave  : AxiStreamSlaveType;

begin  -- architecture rtl

   -- Make sure data widths are appropriate
   assert (MASTER_SLAVE_AXI_CONFIG_G.TDATA_BYTES_C >= TRAILER_AXI_CONFIG_G.TDATA_BYTES_C)
      report "Trailer data widths must be less or equal than axi-stream" severity failure;

   comb : process (axisRst, pipeAxisSlave, r, sAxisMaster, sAxisTrailerMaster) is
      variable v   : RegType;
      variable ibM : AxiStreamMasterType;
   begin  -- process comb
      v := r;

      -- Init ready
      for i in 0 to 1 loop
         v.ibSlaves(i).tReady := '0';
      end loop;  -- i

      -- Choose ready source and clear valid
      if (pipeAxisSlave.tReady = '1') then
         v.obMaster.tValid := '0';
      end if;

      if v.obMaster.tValid = '0' then
         -- Get inbound data
         if r.sel = '0' then
            ibM                  := sAxisMaster;
            v.ibSlaves(0).tReady := '1';
            v.ibSlaves(1).tReady := '0';
         else
            ibM                  := sAxisTrailerMaster;
            v.ibSlaves(1).tReady := '1';
            v.ibSlaves(0).tReady := '0';
         end if;

         -- Mirror data until tLast
         if ibM.tValid = '1' then
            v.obMaster := ibM;
            if ibM.tLast = '1' then
               v.sel := not r.sel;
               if r.sel = '0' then
                  v.obMaster.tLast := '0';
               else
                  -- tKeep workaround
                  v.obMaster.tKeep(v.obMaster.tKeep'length-1 downto 0)            := (others => '0');
                  v.obMaster.tKeep(TRAILER_AXI_CONFIG_G.TDATA_BYTES_C-1 downto 0) := (others => '1');
               end if;
            end if;
         end if;

      end if;

      -- Outputs
      sAxisSlave        <= v.ibSlaves(0);
      sAxisTrailerSlave <= v.ibSlaves(1);
      pipeAxisMaster    <= r.obMaster;

      -- Reset
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

   -- Optional output pipeline registers to ease timing
   AxiStreamPipeline_1 : entity surf.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
         RST_ASYNC_G   => RST_ASYNC_G,
         -- SIDE_BAND_WIDTH_G => SIDE_BAND_WIDTH_G,
         PIPE_STAGES_G => PIPE_STAGES_G)
      port map (
         axisClk     => axisClk,
         axisRst     => axisRst,
         sAxisMaster => pipeAxisMaster,
         -- sSideBand   => pipeSideBand,
         sAxisSlave  => pipeAxisSlave,
         mAxisMaster => mAxisMaster,
         -- mSideBand   => mSideBand,
         mAxisSlave  => mAxisSlave);

end architecture rtl;
