-------------------------------------------------------------------------------
-- File       : AxiStreamBatcherEventBuilder.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper on AxiStreamBatcher for multi-AXI stream event building 
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

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

entity AxiStreamBatcherEventBuilder is
   generic (
      TPD_G : time := 1 ns;

      -- Number of Inbound AXIS stream SLAVES
      NUM_SLAVES_G : positive := 2;

      -- In INDEXED mode, the output TDEST is set based on the selected slave index
      -- In ROUTED mode, TDEST is set according to the TDEST_ROUTES_G table
      MODE_G : string := "INDEXED";

      -- In ROUTED mode, an array mapping how TDEST should be assigned for each slave port
      -- Each TDEST bit can be set to '0', '1' or '-' for passthrough from slave TDEST.
      TDEST_ROUTES_G : Slv8Array := (0 => "--------");

      -- In INDEXED mode, assign slave index to TDEST at this bit offset
      TDEST_LOW_G : integer range 0 to 7 := 0;

      AXIS_CONFIG_G        : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C;
      INPUT_PIPE_STAGES_G  : natural             := 0;
      OUTPUT_PIPE_STAGES_G : natural             := 0);
   port (
      -- Clock and Reset
      axisClk      : in  sl;
      axisRst      : in  sl;
      -- AXIS Interfaces
      sAxisMasters : in  AxiStreamMasterArray(NUM_SLAVES_G-1 downto 0);
      sAxisSlaves  : out AxiStreamSlaveArray(NUM_SLAVES_G-1 downto 0);
      mAxisMaster  : out AxiStreamMasterType;
      mAxisSlave   : in  AxiStreamSlaveType);
end entity AxiStreamBatcherEventBuilder;

architecture rtl of AxiStreamBatcherEventBuilder is

   constant DEST_SIZE_C : integer := bitSize(NUM_SLAVES_G-1);

   type StateType is (
      IDLE_S,
      ARB_S,
      MOVE_S);

   type RegType is record
      ready        : sl;
      subFrameMask : slv(NUM_SLAVES_G-1 downto 0);
      maxSubFrames : slv(15 downto 0);
      accept       : slv(NUM_SLAVES_G-1 downto 0);
      index        : natural range 0 to NUM_SLAVES_G-1;
      rxSlaves     : AxiStreamSlaveArray(NUM_SLAVES_G-1 downto 0);
      txMaster     : AxiStreamMasterType;
      state        : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      ready        => '0',
      subFrameMask => (others => '0'),
      maxSubFrames => toSlv(NUM_SLAVES_G, 16),
      accept       => (others => '0'),
      index        => 0,
      rxSlaves     => (others => AXI_STREAM_SLAVE_INIT_C),
      txMaster     => AXI_STREAM_MASTER_INIT_C,
      state        => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal sAxisMastersTmp : AxiStreamMasterArray(NUM_SLAVES_G-1 downto 0);
   signal rxMasters       : AxiStreamMasterArray(NUM_SLAVES_G-1 downto 0);
   signal rxSlaves        : AxiStreamSlaveArray(NUM_SLAVES_G-1 downto 0);
   signal txMaster        : AxiStreamMasterType;
   signal txSlave         : AxiStreamSlaveType;

   signal batcherIdle : sl;

begin

   -------------------------
   -- Override Inbound TDEST
   -------------------------
   TDEST_REMAP : process (sAxisMasters) is
      variable tmp : AxiStreamMasterArray(NUM_SLAVES_G-1 downto 0);
      variable i   : natural;
      variable j   : natural;
   begin
      tmp := sAxisMasters;
      for i in NUM_SLAVES_G-1 downto 0 loop
         if MODE_G = "ROUTED" then
            for j in 7 downto 0 loop
               if (TDEST_ROUTES_G(i)(j) = '1') then
                  tmp(i).tDest(j) := '1';
               elsif(TDEST_ROUTES_G(i)(j) = '0') then
                  tmp(i).tDest(j) := '0';
               else
                  tmp(i).tDest(j) := sAxisMasters(i).tDest(j);
               end if;
            end loop;
         else
            tmp(i).tDest(7 downto TDEST_LOW_G)                         := (others => '0');
            tmp(i).tDest(DEST_SIZE_C+TDEST_LOW_G-1 downto TDEST_LOW_G) := toSlv(i, DEST_SIZE_C);
         end if;
      end loop;
      sAxisMastersTmp <= tmp;
   end process;

   -----------------
   -- Input pipeline
   -----------------
   GEN_VEC :
   for i in (NUM_SLAVES_G-1) downto 0 generate
      U_Input : entity work.AxiStreamPipeline
         generic map (
            TPD_G         => TPD_G,
            PIPE_STAGES_G => INPUT_PIPE_STAGES_G)
         port map (
            axisClk     => axisClk,
            axisRst     => axisRst,
            sAxisMaster => sAxisMastersTmp(i),
            sAxisSlave  => sAxisSlaves(i),
            mAxisMaster => rxMasters(i),
            mAxisSlave  => rxSlaves(i));
   end generate GEN_VEC;

   comb : process (axisRst, batcherIdle, r, rxMasters, txSlave) is
      variable v : RegType;
      variable i : natural;

      procedure procQueue is
      begin
         -- Check if move selected channel
         if (v.accept(r.index) = '1') then  -- Using variable instead of register in-case in the IDLE_S state
            -- Next state
            v.state := MOVE_S;
         else
            -- Check for last sample
            if (r.index = NUM_SLAVES_G-1) then
               -- Reset the counter
               v.index := 0;
               -- Reset the flag
               v.ready := '0';
               -- Next state
               v.state := IDLE_S;
            else
               -- Increment the counter
               v.index := r.index + 1;
               -- Next state
               v.state := ARB_S;
            end if;
         end if;
      end procedure procQueue;

   begin
      -- Latch the current value
      v := r;

      -- Reset the flow control strobes
      for i in (NUM_SLAVES_G-1) downto 0 loop
         v.rxSlaves(i).tReady := '0';
      end loop;
      if (txSlave.tReady = '1') then
         v.txMaster.tValid := '0';
      end if;

      -- Loop through RX channels
      v.ready := '1';
      for i in (NUM_SLAVES_G-1) downto 0 loop
         -- Check if no data
         if (rxMasters(i).tValid = '0') then
            -- Reset the flag
            v.ready := '0';
         else
            -- Check for NULL frame
            if (rxMasters(i).tLast = '1') and (rxMasters(i).tKeep(AXIS_CONFIG_G.TDATA_BYTES_C-1 downto 0) = 0) then
               -- NULL frame detected
               v.subFrameMask(i) := '0';
            else
               -- Normal frame detected
               v.subFrameMask(i) := '1';
            end if;
         end if;
      end loop;

      -- Main state machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check if ready to move data
            if (batcherIdle = '1') and (r.ready = '1') then
               -- Set the sub-frame count
               v.maxSubFrames := resize(onesCount(r.subFrameMask), 16);
               -- Set the accept masks
               v.accept       := r.subFrameMask;
               -- Loop through RX channels
               for i in (NUM_SLAVES_G-1) downto 0 loop
                  -- Check for NULL frame
                  if (r.subFrameMask(i) = '0') then
                     -- Drop the NULL frame
                     v.rxSlaves(i).tReady := '1';
                  end if;
               end loop;
               -- Process the queue
               procQueue;
            end if;
         ----------------------------------------------------------------------
         when ARB_S =>
            -- Process the queue
            procQueue;
         ----------------------------------------------------------------------
         when MOVE_S =>
            -- Check if ready to move data
            if (rxMasters(r.index).tValid = '1') and (v.txMaster.tValid = '0') then
               -- Move the data
               v.rxSlaves(r.index).tReady := '1';
               v.txMaster                 := rxMasters(r.index);
               -- Check for the last transfer
               if (rxMasters(r.index).tLast = '1') then
                  -- Check for last channel
                  if (r.index = NUM_SLAVES_G-1) then
                     -- Reset the counter
                     v.index := 0;
                     -- Reset the flag
                     v.ready := '0';
                     -- Next state
                     v.state := IDLE_S;
                  else
                     -- Increment the counter
                     v.index := r.index + 1;
                     -- Next state
                     v.state := ARB_S;
                  end if;
               end if;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Outputs
      rxSlaves <= v.rxSlaves;
      txMaster <= r.txMaster;

      -- Reset
      if (axisRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (axisClk) is
   begin
      if (rising_edge(axisClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   ------------------
   -- AxiStreamBatcher
   ------------------
   U_AxiStreamBatcher : entity work.AxiStreamBatcher
      generic map (
         TPD_G                        => TPD_G,
         MAX_NUMBER_SUB_FRAMES_G      => NUM_SLAVES_G,
         SUPER_FRAME_BYTE_THRESHOLD_G => 0,  -- 0 = bypass super threshold check
         MAX_CLK_GAP_G                => 0,  -- 0 = bypass MAX clock GAP 
         AXIS_CONFIG_G                => AXIS_CONFIG_G,
         INPUT_PIPE_STAGES_G          => 1,  -- Break apart the long combinatorial tReady chain
         OUTPUT_PIPE_STAGES_G         => OUTPUT_PIPE_STAGES_G)
      port map (
         -- Clock and Reset
         axisClk      => axisClk,
         axisRst      => axisRst,
         -- External Control Interface
         maxSubFrames => r.maxSubFrames,
         idle         => batcherIdle,
         -- AXIS Interfaces
         sAxisMaster  => txMaster,
         sAxisSlave   => txSlave,
         mAxisMaster  => mAxisMaster,
         mAxisSlave   => mAxisSlave);

end rtl;
