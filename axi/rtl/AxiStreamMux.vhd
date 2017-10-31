-------------------------------------------------------------------------------
-- File       : AxiStreamMux.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-25
-- Last update: 2017-10-31
-------------------------------------------------------------------------------
-- Description:
-- Block to connect multiple incoming AXI streams into a single encoded
-- outbound stream. The destination field is updated accordingly.
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.ArbiterPkg.all;
use work.AxiStreamPkg.all;

entity AxiStreamMux is
   generic (
      TPD_G                : time                  := 1 ns;
      NUM_SLAVES_G         : integer range 1 to 32 := 4;
      MODE_G               : string                := "INDEXED";  -- Or "ROUTED"
      TDEST_ROUTES_G       : Slv8Array             := (0 => "--------");  -- Only used in ROUTED mode
      PIPE_STAGES_G        : integer range 0 to 16 := 0;
      TDEST_LOW_G          : integer range 0 to 7  := 0;   -- LSB of updated tdest for INDEX
      ILEAVE_EN_G          : boolean               := false;  -- Set to true if interleaving dests, arbitrate on gaps
      ILEAVE_ON_NOTVALID_G : boolean               := false;  -- Rearbitrate when tValid drops on selected channel
      ILEAVE_REARB_G       : natural               := 0);  -- Max number of transactions between arbitrations, 0 = unlimited
   port (
      -- Clock and reset
      axisClk      : in  sl;
      axisRst      : in  sl;
      -- Slaves
      disableSel   : in  slv(NUM_SLAVES_G-1 downto 0) := (others => '0');
      rearbitrate  : in  sl                           := '0';
      sAxisMasters : in  AxiStreamMasterArray(NUM_SLAVES_G-1 downto 0);
      sAxisSlaves  : out AxiStreamSlaveArray(NUM_SLAVES_G-1 downto 0);

      -- Master
      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType);
end AxiStreamMux;

architecture structure of AxiStreamMux is

   constant DEST_SIZE_C : integer := bitSize(NUM_SLAVES_G-1);
   constant ARB_BITS_C  : integer := 2**DEST_SIZE_C;
   constant ACNT_SIZE_G : integer := bitSize(ILEAVE_REARB_G);

   type StateType is (
      IDLE_S,
      MOVE_S);

   type RegType is record
      state  : StateType;
      acks   : slv(ARB_BITS_C-1 downto 0);
      ackNum : slv(DEST_SIZE_C-1 downto 0);
      valid  : sl;
      arbCnt : slv(ACNT_SIZE_G-1 downto 0);
      slaves : AxiStreamSlaveArray(NUM_SLAVES_G-1 downto 0);
      master : AxiStreamMasterType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state  => IDLE_S,
      acks   => (others => '0'),
      ackNum => toSlv(NUM_SLAVES_G-1, DEST_SIZE_C),
      valid  => '0',
      arbCnt => (others => '0'),
      slaves => (others => AXI_STREAM_SLAVE_INIT_C),
      master => AXI_STREAM_MASTER_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal sAxisMastersTmp : AxiStreamMasterArray(NUM_SLAVES_G-1 downto 0);
   signal pipeAxisMaster  : AxiStreamMasterType;
   signal pipeAxisSlave   : AxiStreamSlaveType;

begin

   assert (MODE_G /= "INDEXED" or (7 - TDEST_LOW_G + 1 >= log2(NUM_SLAVES_G)))
      report "In INDEXED mode, TDest range 7 downto " & integer'image(TDEST_LOW_G) &
      " is too small for NUM_SLAVES_G=" & integer'image(NUM_SLAVES_G)
      severity error;

   assert (MODE_G /= "ROUTED" or (TDEST_ROUTES_G'length = NUM_SLAVES_G))
      report "In ROUTED mode, length of TDEST_ROUTES_G: " & integer'image(TDEST_ROUTES_G'length) &
      " must equal NUM_SLAVES_G: " & integer'image(NUM_SLAVES_G)
      severity error;

   -- Override tdests according to the routing table
   TDEST_REMAP : process (sAxisMasters) is
      variable tmp : AxiStreamMasterArray(NUM_SLAVES_G-1 downto 0);
      variable i   : natural;
      variable j   : natural;
   begin
      tmp := sAxisMasters;
      if MODE_G = "ROUTED" then
         for i in NUM_SLAVES_G-1 downto 0 loop
            for j in 7 downto 0 loop
               if (TDEST_ROUTES_G(i)(j) = '1') then
                  tmp(i).tDest(j) := '1';
               elsif(TDEST_ROUTES_G(i)(j) = '0') then
                  tmp(i).tDest(j) := '0';
               else
                  tmp(i).tDest(j) := sAxisMasters(i).tDest(j);
               end if;
            end loop;
         end loop;
      end if;
      sAxisMastersTmp <= tmp;
   end process;

   comb : process (axisRst, disableSel, pipeAxisSlave, r, rearbitrate, sAxisMastersTmp) is
      variable v        : RegType;
      variable requests : slv(ARB_BITS_C-1 downto 0);
      variable selData  : AxiStreamMasterType;
      variable i        : natural;
   begin
      -- Latch the current value   
      v := r;

      -- Reset the flags
      for i in 0 to (NUM_SLAVES_G-1) loop
         v.slaves(i).tReady := '0';
      end loop;
      if pipeAxisSlave.tReady = '1' then
         v.master.tValid := '0';
      end if;

      -- Select source
      if NUM_SLAVES_G = 1 then
         selData := sAxisMastersTmp(0);
      else
         selData := sAxisMastersTmp(conv_integer(r.ackNum));
      end if;

      if MODE_G = "INDEXED" then
         selData.tDest(7 downto TDEST_LOW_G)                         := (others => '0');
         selData.tDest(DEST_SIZE_C+TDEST_LOW_G-1 downto TDEST_LOW_G) := r.ackNum;
      end if;

      -- Format requests
      requests := (others => '0');
      for i in 0 to (NUM_SLAVES_G-1) loop
         requests(i) := sAxisMastersTmp(i).tValid and not disableSel(i);
      end loop;

      -- State machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Arbitrate between requesters
            if r.valid = '0' then
               arbitrate(requests, r.ackNum, v.ackNum, v.valid, v.acks);
            else
               -- Reset the Arbitration flag
               v.valid := '0';
               -- Check if need to move data
               if (v.master.tValid = '0') and (selData.tValid = '1') then
                  -- Accept the data
                  v.slaves(conv_integer(r.ackNum)).tReady := '1';
                  -- Move the AXIS data
                  v.master                                := selData;
                  -- Check for no-tLast
                  if selData.tLast = '0' then
                     -- Next state
                     v.state := MOVE_S;
                  end if;
               else
                  -- Next state
                  v.state := MOVE_S;
               end if;
            end if;
            v.arbCnt := (others => '0');
         ----------------------------------------------------------------------
         when MOVE_S =>
            -- Check if need to move data
            if (v.master.tValid = '0') and (selData.tValid = '1') then
               -- Accept the data
               v.slaves(conv_integer(r.ackNum)).tReady := '1';
               -- Move the AXIS data
               v.master                                := selData;
               v.arbCnt                                := r.arbCnt + 1;
               -- Check for tLast
               if selData.tLast = '1' then
                  -- Next state
                  v.state := IDLE_S;


               elsif (ILEAVE_EN_G) then
                  if ((ILEAVE_REARB_G /= 0) and (r.arbCnt = ILEAVE_REARB_G-2)) or
                     rearbitrate = '1' or
                     disableSel(conv_integer(r.ackNum)) = '1' then
                     -- rearbitrate after ILEAVE_REARB_G txns
                     -- Or upon manual rearbitration input
                     -- Or selected channel being disabled                  
                     v.state := IDLE_S;
                  end if;
               end if;

            -- RE-arbitrate on gaps if interleaving frames
            elsif (v.master.tValid = '0') and (selData.tValid = '0') and
               (ILEAVE_EN_G and ILEAVE_ON_NOTVALID_G) then
               v.state := IDLE_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (axisRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs  
      sAxisSlaves    <= v.slaves;
      pipeAxisMaster <= r.master;

   end process comb;

   AxiStreamPipeline_1 : entity work.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
         PIPE_STAGES_G => PIPE_STAGES_G)
      port map (
         axisClk     => axisClk,
         axisRst     => axisRst,
         sAxisMaster => pipeAxisMaster,
         sAxisSlave  => pipeAxisSlave,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);

   seq : process (axisClk) is
   begin
      if (rising_edge(axisClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end structure;
