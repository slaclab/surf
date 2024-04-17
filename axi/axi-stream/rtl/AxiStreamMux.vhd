-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
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

library surf;
use surf.StdRtlPkg.all;
use surf.ArbiterPkg.all;
use surf.AxiStreamPkg.all;

entity AxiStreamMux is
   generic (
      TPD_G                : time                    := 1 ns;
      RST_ASYNC_G          : boolean                 := false;
      PIPE_STAGES_G        : integer range 0 to 16   := 0;
      NUM_SLAVES_G         : integer range 1 to 256  := 4;
      -- In INDEXED mode, the output TDEST is set based on the selected slave index (default)
      -- In ROUTED mode, TDEST is set according to the TDEST_ROUTES_G table
      -- In PASSTHROUGH mode, TDEST is passed through from the slave untouched
      MODE_G               : string                  := "INDEXED";  -- Note: Planning to rename "MODE_G" to "TDEST_MODE_G" in a future MAJOR release of SURF
      -- In ROUTED mode, an array mapping how TDEST should be assigned for each slave port
      -- Each TDEST bit can be set to '0', '1' or '-' for passthrough from slave TDEST.
      TDEST_ROUTES_G       : Slv8Array               := (0 => "--------");
      -- In INDEXED mode, the output TID is set based on the selected slave index
      -- In ROUTED mode, TID is set according to the TID_ROUTES_G table
      -- In PASSTHROUGH mode, TID is passed through from the slave untouched (default)
      TID_MODE_G           : string                  := "PASSTHROUGH";
      -- In ROUTED mode, an array mapping how TID should be assigned for each slave port
      TID_ROUTES_G         : Slv8Array               := (0 => "--------");
      -- Assign a priority for each input stream index.
      -- Higher priority streams will be selected over those with lower priority of both are active.
      -- Format is (index => priority)
      -- Leave unchanged for equal priority round-robbin
      PRIORITY_G           : IntegerArray            := (0 => 0);
      -- In INDEXED mode, assign slave index to TDEST at this bit offset
      TDEST_LOW_G          : integer range 0 to 7    := 0;
      -- Set to true if interleaving dests
      ILEAVE_EN_G          : boolean                 := false;
      -- Rearbitrate when tValid drops on selected channel, ignored when ILEAVE_EN_G=false
      ILEAVE_ON_NOTVALID_G : boolean                 := false;
      -- Max number of transactions between arbitrations, 0 = unlimited, ignored when ILEAVE_EN_G=false
      ILEAVE_REARB_G       : natural range 0 to 4095 := 0;
      -- One cycle gap in stream between during re-arbitration.
      -- Set true for better timing, false for higher throughput.
      REARB_DELAY_G        : boolean                 := true;
      -- Block selected slave txns arriving on same cycle as rearbitrate or disableSel from going through,
      -- creating 1 cycle gap. This might be needed logically but decreases throughput.
      FORCED_REARB_HOLD_G  : boolean                 := false);

   port (
      -- Clock and reset
      axisClk      : in  sl;
      axisRst      : in  sl;
      -- Slaves
      disableSel   : in  slv(NUM_SLAVES_G-1 downto 0) := (others => '0');
      rearbitrate  : in  sl                           := '0';
      ileaveRearb  : in  slv(11 downto 0)             := toSlv(ILEAVE_REARB_G, 12);
      sAxisMasters : in  AxiStreamMasterArray(NUM_SLAVES_G-1 downto 0);
      sAxisSlaves  : out AxiStreamSlaveArray(NUM_SLAVES_G-1 downto 0);

      -- Master
      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType);
end AxiStreamMux;

architecture rtl of AxiStreamMux is

   constant DEST_SIZE_C : integer := bitSize(NUM_SLAVES_G-1);
   constant ARB_BITS_C  : integer := 2**DEST_SIZE_C;

   type RegType is record
      acks   : slv(ARB_BITS_C-1 downto 0);
      ackNum : slv(DEST_SIZE_C-1 downto 0);
      valid  : sl;
      arbCnt : slv(11 downto 0);
      slaves : AxiStreamSlaveArray(NUM_SLAVES_G-1 downto 0);
      master : AxiStreamMasterType;
   end record RegType;

   constant REG_INIT_C : RegType := (
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

   signal intDisableSel : slv(NUM_SLAVES_G-1 downto 0);

begin

   assert ((MODE_G = "PASSTHROUGH") or (MODE_G = "INDEXED") or (MODE_G = "ROUTED"))
      report "MODE_G must be either [PASSTHROUGH,INDEXED,ROUTED]"
      severity error;

   assert ((MODE_G = "INDEXED") and (7 - TDEST_LOW_G + 1 >= log2(NUM_SLAVES_G))) or (MODE_G /= "INDEXED")
      report "In INDEXED mode, TDest range 7 downto " & integer'image(TDEST_LOW_G) &
      " is too small for NUM_SLAVES_G=" & integer'image(NUM_SLAVES_G)
      severity error;

   assert ((MODE_G = "ROUTED") and (TDEST_ROUTES_G'length = NUM_SLAVES_G)) or (MODE_G /= "ROUTED")
      report "In ROUTED mode, length of TDEST_ROUTES_G: " & integer'image(TDEST_ROUTES_G'length) &
      " must equal NUM_SLAVES_G: " & integer'image(NUM_SLAVES_G)
      severity error;

   assert ((TID_MODE_G = "PASSTHROUGH") or (TID_MODE_G = "INDEXED") or (TID_MODE_G = "ROUTED"))
      report "TID_MODE_G must be either [PASSTHROUGH,INDEXED,ROUTED]"
      severity error;

   assert ((TID_MODE_G = "ROUTED") and (TID_ROUTES_G'length = NUM_SLAVES_G)) or (TID_MODE_G /= "ROUTED")
      report "In ROUTED mode, length of TID_ROUTES_G: " & integer'image(TID_ROUTES_G'length) &
      " must equal NUM_SLAVES_G: " & integer'image(NUM_SLAVES_G)
      severity error;

   -- Override TDESTS and TIDs according to the routing tables
   ROUTE_TABLE_REMAP : process (sAxisMasters) is
      variable tmp : AxiStreamMasterArray(NUM_SLAVES_G-1 downto 0);
      variable i   : natural;
      variable j   : natural;
   begin
      -- Latch the current value
      tmp := sAxisMasters;

      -- Check for TDEST routing
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

      -- Check for TID routing
      if TID_MODE_G = "ROUTED" then
         for i in NUM_SLAVES_G-1 downto 0 loop
            for j in 7 downto 0 loop
               if (TID_ROUTES_G(i)(j) = '1') then
                  tmp(i).tId(j) := '1';
               elsif(TID_ROUTES_G(i)(j) = '0') then
                  tmp(i).tId(j) := '0';
               else
                  tmp(i).tId(j) := sAxisMasters(i).tId(j);
               end if;
            end loop;
         end loop;
      end if;

      -- Outputs
      sAxisMastersTmp <= tmp;

   end process;

   -- When in INDEXED priority mode, tvalid on a given slave side index disables selection
   -- for all channels with higer index
   PRIORITY_CONTROL : process (disableSel, sAxisMasters) is
      variable tmp : slv(NUM_SLAVES_G-1 downto 0);
   begin
      tmp := disableSel;

      for ch in NUM_SLAVES_G-1 downto 0 loop
         if (sAxisMasters(ch).tValid = '1') then
            if (ch < PRIORITY_G'length) then
               for sel in PRIORITY_G'range loop
                  if (PRIORITY_G(ch) > PRIORITY_G(sel)) then
                     tmp(sel) := '1';
                  end if;
               end loop;
            end if;
         end if;
      end loop;

      intDisableSel <= tmp;

   end process PRIORITY_CONTROL;

   comb : process (axisRst, ileaveRearb, intDisableSel, pipeAxisSlave, r, rearbitrate,
                   sAxisMastersTmp) is
      variable v        : RegType;
      variable requests : slv(ARB_BITS_C-1 downto 0);
      variable selData  : AxiStreamMasterType;
      variable i        : natural;
   begin
      -- Latch the current value
      v := r;

      -----------------------------------------------------------------------

      -- AXI Stream Flow Control
      for i in 0 to (NUM_SLAVES_G-1) loop
         v.slaves(i).tReady := '0';
      end loop;
      if pipeAxisSlave.tReady = '1' then
         v.master.tValid := '0';
      end if;

      -----------------------------------------------------------------------

      -- Select source
      if NUM_SLAVES_G = 1 then
         selData := sAxisMastersTmp(0);
      else
         selData := sAxisMastersTmp(conv_integer(r.ackNum));
      end if;

      -----------------------------------------------------------------------

      -- In INDEXED mode, assign the slave index to TDEST at offset of TDEST_LOW_G
      if MODE_G = "INDEXED" then
         selData.tDest(7 downto TDEST_LOW_G)                         := (others => '0');
         selData.tDest(DEST_SIZE_C+TDEST_LOW_G-1 downto TDEST_LOW_G) := r.ackNum;
      end if;

      -- In INDEXED mode, assign slave index to TID
      if (TID_MODE_G = "INDEXED") then
         selData.tId := resize(r.ackNum, 8);
      end if;

      -----------------------------------------------------------------------

      -- NOTE: MODE_G = "PASSTHROUGH and TID_MODE_G = "PASSTHROUGH" are degenerate cases.
      -- In the absence of "ROUTED" or "INDEXED", TDEST and TID are assigned
      -- directly from the slave input to the output master.

      -----------------------------------------------------------------------

      -- Format requests
      requests := (others => '0');
      for i in 0 to (NUM_SLAVES_G-1) loop
         requests(i) := sAxisMastersTmp(i).tValid and not intDisableSel(i);
      end loop;

      if (r.valid = '1') then
         -- RE-arbitrate on gaps if configured to do so
         -- Also allow disableSel and rearbitrate to work at any time
         if (ILEAVE_EN_G) then
            if ((ILEAVE_ON_NOTVALID_G and selData.tValid = '0') or
                (rearbitrate = '1' or intDisableSel(conv_integer(r.ackNum)) = '1')) then
               v.valid := '0';
            end if;
         end if;

         -- Check if able to move data
         -- Optionally hold  txns that arrive on same cycle as arbitrate or disableSel(r.ackNum)
         if ((v.master.tValid = '0') and (selData.tValid = '1') and
             (FORCED_REARB_HOLD_G = false or v.valid = '1')) then

            -- Accept the data from slave
            v.slaves(conv_integer(r.ackNum)).tReady := '1';

            -- Assign data to output
            v.master := selData;

            -- Increment the txn count
            v.arbCnt := r.arbCnt + 1;

            -- Check for tLast
            if selData.tLast = '1' then
               v.valid := '0';

            -- Rearbitrate after ILEAVE_REARB_G txns
            elsif (ILEAVE_EN_G) and (ileaveRearb /= 0) and (r.arbCnt = ileaveRearb-1) then
               v.valid := '0';
            end if;
         end if;
      end if;

      -- v.valid = 0 indicates re-arbitration, so reset arbCnt
      if (v.valid = '0') then
         v.arbCnt := (others => '0');
      end if;

      -- Arbitrate between requesters
      if ((v.valid = '0' and REARB_DELAY_G = false) or r.valid = '0') then
         v.arbCnt := (others => '0');
         arbitrate(requests, r.ackNum, v.ackNum, v.valid, v.acks);
      end if;

      -- Combinatorial outputs before the reset
      sAxisSlaves <= v.slaves;

      -- Reset
      if (RST_ASYNC_G = false and axisRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Assign variable back to signal
      rin <= v;

      -- Registered Outputs
      pipeAxisMaster <= r.master;

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

end rtl;
