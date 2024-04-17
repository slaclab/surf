-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- Block to connect a single incoming AXI stream to multiple outgoing AXI
-- streams
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

entity AxiStreamRepeater is
   generic (
      TPD_G                : time     := 1 ns;
      RST_ASYNC_G          : boolean  := false;
      NUM_MASTERS_G        : positive := 2;
      INCR_AXIS_ID_G       : boolean  := false;  -- true = overwrites the TID with a counter that increments after each TLAST (help with frame alignment down stream)
      INPUT_PIPE_STAGES_G  : natural  := 0;
      OUTPUT_PIPE_STAGES_G : natural  := 0);
   port (
      -- Clock and reset
      axisClk      : in  sl;
      axisRst      : in  sl;
      -- Slave
      sAxisMaster  : in  AxiStreamMasterType;
      sAxisSlave   : out AxiStreamSlaveType;
      -- Masters
      mAxisMasters : out AxiStreamMasterArray(NUM_MASTERS_G-1 downto 0);
      mAxisSlaves  : in  AxiStreamSlaveArray(NUM_MASTERS_G-1 downto 0));
end AxiStreamRepeater;

architecture structure of AxiStreamRepeater is

   type RegType is record
      tId     : slv(7 downto 0);
      slave   : AxiStreamSlaveType;
      masters : AxiStreamMasterArray(NUM_MASTERS_G-1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      tId     => (others => '0'),
      slave   => AXI_STREAM_SLAVE_INIT_C,
      masters => (others => AXI_STREAM_MASTER_INIT_C));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal inputAxisMaster   : AxiStreamMasterType;
   signal inputAxisSlave    : AxiStreamSlaveType;
   signal outputAxisMasters : AxiStreamMasterArray(NUM_MASTERS_G-1 downto 0);
   signal outputAxisSlaves  : AxiStreamSlaveArray(NUM_MASTERS_G-1 downto 0);

begin

   -----------------
   -- Input pipeline
   -----------------
   U_Input : entity surf.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
         RST_ASYNC_G   => RST_ASYNC_G,
         PIPE_STAGES_G => INPUT_PIPE_STAGES_G)
      port map (
         axisClk     => axisClk,
         axisRst     => axisRst,
         sAxisMaster => sAxisMaster,
         sAxisSlave  => sAxisSlave,
         mAxisMaster => inputAxisMaster,
         mAxisSlave  => inputAxisSlave);

   comb : process (axisRst, inputAxisMaster, outputAxisSlaves, r) is
      variable v      : RegType;
      variable i      : natural;
      variable tValid : sl;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals
      v.slave.tReady := '0';
      tValid         := '0';

      -- Loop through the output lanes
      for i in (NUM_MASTERS_G-1) downto 0 loop

         -- Check if the data was accepted
         if outputAxisSlaves(i).tReady = '1' then
            -- Reset the flag
            v.masters(i).tValid := '0';
         end if;

         -- Check if the flag was not reset
         if (v.masters(i).tValid = '1') then
            -- Not ready to move data
            tValid := '1';
         end if;

      end loop;

      -- Check if ready to move data
      if (inputAxisMaster.tValid = '1') and (tValid = '0') then

         -- Accept the data
         v.slave.tReady := '1';

         -- Loop through the output lanes
         for i in (NUM_MASTERS_G-1) downto 0 loop

            -- Move the data
            v.masters(i) := inputAxisMaster;

            -- Checking if overriding TID
            if(INCR_AXIS_ID_G)then
               v.masters(i).tId := r.tId;
            end if;

         end loop;

         -- Check for the end of the frame
         if (inputAxisMaster.tLast = '1') then
            -- Increment the counter
            v.tId := r.tId + 1;
         end if;

      end if;

      -- Outputs
      inputAxisSlave    <= v.slave;
      outputAxisMasters <= r.masters;

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

   ------------------
   -- Output pipeline
   ------------------
   GEN_VEC :
   for i in (NUM_MASTERS_G-1) downto 0 generate

      U_Output : entity surf.AxiStreamPipeline
         generic map (
            TPD_G         => TPD_G,
            RST_ASYNC_G   => RST_ASYNC_G,
            PIPE_STAGES_G => OUTPUT_PIPE_STAGES_G)
         port map (
            axisClk     => axisClk,
            axisRst     => axisRst,
            sAxisMaster => outputAxisMasters(i),
            sAxisSlave  => outputAxisSlaves(i),
            mAxisMaster => mAxisMasters(i),
            mAxisSlave  => mAxisSlaves(i));

   end generate GEN_VEC;

end structure;
