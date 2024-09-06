-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- Removes bytes from end of a AXI stream frame
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

entity AxiStreamTrailerRemove is
   generic (
      TPD_G         : time    := 1 ns;
      RST_ASYNC_G   : boolean := false;
      PIPE_STAGES_G : natural := 0;
      BYTES_TO_RM_G : integer := 4;
      AXI_CONFIG_G  : AxiStreamConfigType);
   port (
      -- Clock and Reset
      axisClk     : in  sl;
      axisRst     : in  sl;
      -- Inbound AXI Stream
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;
      -- Inbound AXI Stream
      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType);
end entity AxiStreamTrailerRemove;

architecture rtl of AxiStreamTrailerRemove is

   constant BYTES_C : positive := AXI_CONFIG_G.TDATA_BYTES_C;

   type RegType is record
      obMaster     : AxiStreamMasterType;
      ibSlave      : AxiStreamSlaveType;
      regularTLast : boolean;
   end record RegType;

   constant REG_INIT_C : RegType := (
      obMaster     => axiStreamMasterInit(AXI_CONFIG_G),
      ibSlave      => AXI_STREAM_SLAVE_INIT_C,
      regularTLast => true);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal pipeAxisMaster   : AxiStreamMasterType;
   signal pipeAxisSlave    : AxiStreamSlaveType;
   signal axisMasterToPipe : AxiStreamMasterType;
   signal axisSlaveToPipe  : AxiStreamSlaveType;
   signal axisMasterPipe   : AxiStreamMasterType;
   signal axisSlavePipe    : AxiStreamSlaveType;

begin

   -- Make sure data widths are appropriate
   assert (BYTES_C >= BYTES_TO_RM_G)
      report "Axi-Stream data widths must be greater or equal than trailer" severity failure;

   -- Connect Pipe
   axisMasterToPipe <= sAxisMaster;

   -- Generate a delayed copy of incoming stream
   AxiStreamPipeline_2 : entity surf.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
         RST_ASYNC_G   => RST_ASYNC_G,
         -- SIDE_BAND_WIDTH_G => SIDE_BAND_WIDTH_G,
         PIPE_STAGES_G => 1)
      port map (
         axisClk     => axisClk,
         axisRst     => axisRst,
         sAxisMaster => axisMasterToPipe,
         -- sSideBand   => sSideBand,
         sAxisSlave  => axisSlaveToPipe,
         mAxisMaster => axisMasterPipe,
         -- mSideBand   => mSideBand,
         mAxisSlave  => axisSlavePipe);

   comb : process (axisMasterPipe, axisRst, axisSlaveToPipe, pipeAxisSlave, r,
                   sAxisMaster) is
      variable v     : RegType;
      variable ibM   : AxiStreamMasterType;
      variable count : integer range 0 to AXI_CONFIG_G.TDATA_BYTES_C;
      variable toRm  : integer range 0 to BYTES_TO_RM_G;
   begin  -- process comb
      v := r;

      -- Init ready
      v.ibSlave.tReady := '0';

      -- Choose ready source and clear valid
      if (pipeAxisSlave.tReady = '1') then
         v.obMaster.tValid := '0';
      end if;

      -- Accept input data
      if v.obMaster.tValid = '0' and axisSlaveToPipe.tReady = '1' then
         -- Get inbound data
         ibM              := axisMasterPipe;
         v.ibSlave.tReady := '1';

         if ibM.tValid = '1' and r.regularTLast then
            v.obMaster := ibM;
            if sAxisMaster.tLast = '1' then
               count    := getTKeep(sAxisMaster.tKeep, AXI_CONFIG_G);
               if count <= BYTES_TO_RM_G then
                  v.regularTLast                              := false;
                  toRm                                        := BYTES_TO_RM_G - count;
                  v.obMaster.tLast                            := '1';
                  count                                       := getTKeep(ibM.tKeep, AXI_CONFIG_G);
                  v.obMaster.tKeep                            := (others => '0');
                  v.obMaster.tKeep((count - toRm)-1 downto 0) := (others => '1');
               end if;
            end if;
            if ibM.tLast = '1' then
               count                                                := getTKeep(ibM.tKeep, AXI_CONFIG_G);
               v.obMaster.tKeep                                     := (others => '0');
               v.obMaster.tKeep((count - BYTES_TO_RM_G)-1 downto 0) := (others => '1');
            end if;
         end if;
      end if;

      -- Outputs
      sAxisSlave     <= v.ibSlave;
      axisSlavePipe  <= pipeAxisSlave;
      pipeAxisMaster <= r.obMaster;

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
         PIPE_STAGES_G => PIPE_STAGES_G)
      port map (
         axisClk     => axisClk,
         axisRst     => axisRst,
         sAxisMaster => pipeAxisMaster,
         sAxisSlave  => pipeAxisSlave,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);

end architecture rtl;
