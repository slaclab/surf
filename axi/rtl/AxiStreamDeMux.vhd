-------------------------------------------------------------------------------
-- File       : AxiStreamDeMux.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-25
-- Last update: 2017-04-07
-------------------------------------------------------------------------------
-- Description:
-- Block to connect a single incoming AXI stream to multiple outgoing AXI
-- streams based upon the incoming tDest value.
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
use ieee.NUMERIC_STD.all;
use work.StdRtlPkg.all;
use work.ArbiterPkg.all;
use work.AxiStreamPkg.all;

entity AxiStreamDeMux is
   generic (
      TPD_G          : time                  := 1 ns;
      NUM_MASTERS_G  : integer range 1 to 32 := 12;
      MODE_G         : string                := "INDEXED";          -- Or "ROUTED"
      TDEST_ROUTES_G : slv8Array             := (0 => "--------");  -- Only used in ROUTED mode
      PIPE_STAGES_G  : integer range 0 to 16 := 0;
      TDEST_HIGH_G   : integer range 0 to 7  := 7;
      TDEST_LOW_G    : integer range 0 to 7  := 0);
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
end AxiStreamDeMux;

architecture structure of AxiStreamDeMux is

   type RegType is record
      slave   : AxiStreamSlaveType;
      masters : AxiStreamMasterArray(NUM_MASTERS_G-1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      slave   => AXI_STREAM_SLAVE_INIT_C,
      masters => (others => AXI_STREAM_MASTER_INIT_C));

   signal pipeAxisMasters : AxiStreamMasterArray(NUM_MASTERS_G-1 downto 0);
   signal pipeAxisSlaves  : AxiStreamSlaveArray(NUM_MASTERS_G-1 downto 0);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   assert (MODE_G /= "INDEXED" or (TDEST_HIGH_G - TDEST_LOW_G + 1 >= log2(NUM_MASTERS_G)))
      report "In INDEXED mode, TDest range " & integer'image(TDEST_HIGH_G) & " downto " & integer'image(TDEST_LOW_G) &
      " is too small for NUM_MASTERS_G=" & integer'image(NUM_MASTERS_G)
      severity error;

   assert (MODE_G /= "ROUTED" or (TDEST_ROUTES_G'length = NUM_MASTERS_G))
      report "In ROUTED mode, length of TDEST_ROUTES_G: " & integer'image(TDEST_ROUTES_G'length) &
      " must equal NUM_MASTERS_G: " & integer'image(NUM_MASTERS_G)
      severity error;

   comb : process (axisRst, pipeAxisSlaves, r, sAxisMaster) is
      variable v   : RegType;
      variable idx : natural;
      variable i   : natural;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals
      v.slave.tReady := '0';

      -- Update tValid register
      for i in 0 to NUM_MASTERS_G-1 loop
         if pipeAxisSlaves(i).tReady = '1' then
            v.masters(i).tValid := '0';
         end if;
      end loop;

      -- Decode destination
      if (MODE_G = "INDEXED") then
         -- TDEST indicates the output port
         idx := to_integer(unsigned(sAxisMaster.tDest(TDEST_HIGH_G downto TDEST_LOW_G)));
      elsif (MODE_G = "ROUTED") then
         -- Output port determined by TDEST_ROUTES_G
         -- Set to invalid idx first, if non match then frame will be dumped
         idx := NUM_MASTERS_G;
         -- Search for a matching MASK in ascending order of mask array
         for i in 0 to NUM_MASTERS_G-1 loop
            if (std_match(sAxisMaster.tDest, TDEST_ROUTES_G(i))) then
               idx := i;
            end if;
         end loop;
      end if;

      -- Check for invalid destination
      if idx >= NUM_MASTERS_G then
         -- Blow off the data
         v.slave.tReady := '1';
      -- Check if ready to move data
      elsif (v.masters(idx).tValid = '0') and (sAxisMaster.tValid = '1') then
         -- Accept the data
         v.slave.tReady := '1';
         -- Move the data
         v.masters(idx) := sAxisMaster;
      end if;

      -- Reset
      if (axisRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      sAxisSlave      <= v.slave;
      pipeAxisMasters <= r.masters;

   end process comb;

   GEN_VEC :
   for i in (NUM_MASTERS_G-1) downto 0 generate
      
      U_Pipeline : entity work.AxiStreamPipeline
         generic map (
            TPD_G         => TPD_G,
            PIPE_STAGES_G => PIPE_STAGES_G)
         port map (
            axisClk     => axisClk,
            axisRst     => axisRst,
            sAxisMaster => pipeAxisMasters(i),
            sAxisSlave  => pipeAxisSlaves(i),
            mAxisMaster => mAxisMasters(i),
            mAxisSlave  => mAxisSlaves(i));   

   end generate GEN_VEC;

   seq : process (axisClk) is
   begin
      if (rising_edge(axisClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end structure;

