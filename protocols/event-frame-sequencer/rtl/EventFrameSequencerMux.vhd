-------------------------------------------------------------------------------
-- Title      : Event Frame Sequencer Protocol: https://confluence.slac.stanford.edu/x/hCRXI
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Event Frame Sequencer MUX
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
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

entity EventFrameSequencerMux is
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

      -- Set the TDEST to detect for transition frame
      TRANS_TDEST_G : slv(7 downto 0) := x"FF";

      AXIS_CONFIG_G        : AxiStreamConfigType;
      INPUT_PIPE_STAGES_G  : natural := 0;
      OUTPUT_PIPE_STAGES_G : natural := 0);
   port (
      -- Clock and Reset
      axisClk         : in  sl;
      axisRst         : in  sl;
      -- Misc
      blowoffExt      : in  sl                     := '0';
      -- AXI-Lite Interface
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      -- AXIS Interfaces
      sAxisMasters    : in  AxiStreamMasterArray(NUM_SLAVES_G-1 downto 0);
      sAxisSlaves     : out AxiStreamSlaveArray(NUM_SLAVES_G-1 downto 0);
      mAxisMaster     : out AxiStreamMasterType;
      mAxisSlave      : in  AxiStreamSlaveType);
end entity EventFrameSequencerMux;

architecture rtl of EventFrameSequencerMux is

   constant LOG2_WIDTH_C : slv(3 downto 0) := toSlv(log2(AXIS_CONFIG_G.TDATA_BYTES_C), 4);

   constant DEST_SIZE_C : integer := bitSize(NUM_SLAVES_G-1);

   type StateType is (
      IDLE_S,
      MOVE_S);

   type RegType is record
      softRst        : sl;
      hardRst        : sl;
      blowoffReg     : sl;
      blowoff        : sl;
      cntRst         : sl;
      ready          : sl;
      sof            : sl;
      frameCnt       : slv(7 downto 0);
      numFrames      : slv(7 downto 0);
      seqCnt         : slv(7 downto 0);
      bypass         : slv(NUM_SLAVES_G-1 downto 0);
      dataCnt        : Slv32Array(NUM_SLAVES_G-1 downto 0);
      transCnt       : slv(31 downto 0);
      accept         : slv(NUM_SLAVES_G-1 downto 0);
      transDet       : slv(NUM_SLAVES_G-1 downto 0);
      skipCh         : slv(NUM_SLAVES_G-1 downto 0);
      index          : natural range 0 to NUM_SLAVES_G-1;
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
      rxSlaves       : AxiStreamSlaveArray(NUM_SLAVES_G-1 downto 0);
      txMaster       : AxiStreamMasterType;
      state          : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      softRst        => '0',
      hardRst        => '0',
      blowoffReg     => '0',
      blowoff        => '0',
      cntRst         => '0',
      ready          => '0',
      sof            => '1',
      frameCnt       => (others => '0'),
      numFrames      => (others => '0'),
      seqCnt         => (others => '0'),
      bypass         => (others => '0'),
      dataCnt        => (others => (others => '0')),
      transCnt       => (others => '0'),
      accept         => (others => '0'),
      transDet       => (others => '0'),
      skipCh         => (others => '0'),
      index          => 0,
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      rxSlaves       => (others => AXI_STREAM_SLAVE_INIT_C),
      txMaster       => AXI_STREAM_MASTER_INIT_C,
      state          => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal sAxisMastersTmp : AxiStreamMasterArray(NUM_SLAVES_G-1 downto 0);
   signal rxMasters       : AxiStreamMasterArray(NUM_SLAVES_G-1 downto 0);
   signal rxSlaves        : AxiStreamSlaveArray(NUM_SLAVES_G-1 downto 0);
   signal txMaster        : AxiStreamMasterType;
   signal txSlave         : AxiStreamSlaveType;

begin

   assert (AXIS_CONFIG_G.TDATA_BYTES_C >= 8)
      report "AXIS_CONFIG_G.TDATA_BYTES_C must be >= 8" severity failure;

   assert (isPowerOf2(AXIS_CONFIG_G.TDATA_BYTES_C) = true)
      report "AXIS_CONFIG_G.TDATA_BYTES_C must be power of 2" severity failure;

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
      U_Input : entity surf.AxiStreamPipeline
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

   comb : process (axilReadMaster, axilWriteMaster, axisRst, blowoffExt, r,
                   rxMasters, txSlave) is
      variable v      : RegType;
      variable axilEp : AxiLiteEndPointType;
      variable i      : natural;
      variable dbg    : slv(7 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Update the local variable
      dbg := x"00";
      if (v.state = IDLE_S) then
         dbg(0) := '0';
      else
         dbg(0) := '1';
      end if;

      -- Reset strobes
      v.cntRst  := '0';
      v.hardRst := '0';
      v.softRst := '0';

      -- Check for hard reset or soft reset
      if (r.hardRst = '1') or (r.softRst = '1') then
         -- Reset the register
         v := REG_INIT_C;

         -- Preserve the resister configurations
         v.bypass     := r.bypass;
         v.blowoffReg := r.blowoffReg;

         -- Preserve the state of AXI-Lite
         v.axilWriteSlave := r.axilWriteSlave;
         v.axilReadSlave  := r.axilReadSlave;

      end if;

      -- Determine the transaction type
      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      -- Map the registers
      for i in (NUM_SLAVES_G-1) downto 0 loop
         axiSlaveRegisterR(axilEp, toSlv(4*i + 0, 12), 0, r.dataCnt(i));
      end loop;
      axiSlaveRegisterR(axilEp, x"FBC", 0, r.seqCnt);
      axiSlaveRegisterR(axilEp, x"FC0", 0, r.transCnt);
      axiSlaveRegisterR(axilEp, x"FC4", 0, TRANS_TDEST_G);
      axiSlaveRegister (axilEp, x"FD0", 0, v.bypass);
      axiSlaveRegisterR(axilEp, x"FF4", 0, toSlv(NUM_SLAVES_G, 8));
      axiSlaveRegisterR(axilEp, x"FF4", 8, dbg);
      axiSlaveRegisterR(axilEp, X"FF4", 16, blowoffExt);
      axiSlaveRegister (axilEp, x"FF8", 0, v.blowoffReg);
      axiSlaveRegister (axilEp, x"FFC", 0, v.cntRst);
      axiSlaveRegister (axilEp, x"FFC", 2, v.hardRst);
      axiSlaveRegister (axilEp, x"FFC", 3, v.softRst);

      -- Closeout the transaction
      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);

      -- Combine the external and internal blowoff together
      v.blowoff := v.blowoffReg or blowoffExt;

      -- Check for any change to bypass or blowoff 1->0 transition
      if (r.bypass /= v.bypass) or ((r.blowoff = '1') and (v.blowoff = '0')) then
         -- Perform a soft-reset
         v.softRst := '1';
      end if;

      -- Reset the flow control strobes
      for i in (NUM_SLAVES_G-1) downto 0 loop
         v.rxSlaves(i).tReady := r.bypass(i);
      end loop;
      if (txSlave.tReady = '1') then
         v.txMaster.tValid := '0';
      end if;

      -- State machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Arm the flag
            v.ready := '1';
            v.sof   := '1';

            -- Loop through RX channels
            for i in (NUM_SLAVES_G-1) downto 0 loop

               -- Check if no data and not bypassing
               if (rxMasters(i).tValid = '0') and (r.bypass(i) = '0') then
                  -- Reset the flags
                  v.ready       := '0';
                  v.accept(i)   := '0';
                  v.transDet(i) := '0';
               else
                  -- Check if not a transition TDEST
                  if (rxMasters(i).tDest /= TRANS_TDEST_G) then
                     -- Normal frame detected
                     v.accept(i)   := not(r.bypass(i));
                     v.transDet(i) := '0';

                  -- Else a transitions TDEST
                  else
                     -- Transitions frame detected
                     v.accept(i)   := '0';
                     v.transDet(i) := not(r.bypass(i));

                  end if;

               end if;
            end loop;


            -- Check if transition detected
            if (v.transDet /= 0) then
               -- Set the flag
               v.ready := '1';
            end if;

            -- Check if ready to move data and not blowing off the data
            if (r.ready = '1') and (r.blowoff = '0') then

               -- Check for transition
               if (r.transDet /= 0) then

                  -- Increment transition counter
                  v.transCnt := r.transCnt + 1;

                  -- Set the number of event frame (zero inclusive)
                  v.numFrames := x"00";

                  -- Re-write the accept mask
                  v.accept := r.transDet;
                  v.skipCh := not(r.transDet);

               else

                  for i in (NUM_SLAVES_G-1) downto 0 loop

                     -- Increment data counter
                     if (r.accept(i) = '1') then
                        v.dataCnt(i) := r.dataCnt(i) + 1;
                     end if;

                  end loop;

                  -- Set the number of event frame (zero inclusive)
                  v.numFrames := resize(onesCount(r.accept), 8) - 1;

               end if;

               -- Next state
               v.state := MOVE_S;

            -- Check for blowoff flag
            elsif (r.blowoff = '1') then

               -- Blow off the inbound data
               for i in (NUM_SLAVES_G-1) downto 0 loop
                  v.rxSlaves(i).tReady := '1';
               end loop;

               -- Reset the flags
               v.ready    := '0';
               v.accept   := (others => '0');
               v.transDet := (others => '0');
               v.skipCh   := (others => '0');
               v.seqCnt   := (others => '0');

            end if;
         ----------------------------------------------------------------------
         when MOVE_S =>
            -- Check for skip channel or bypass on the channel
            if (r.skipCh(r.index) = '1') or (r.bypass(r.index) = '1') then

               -- Check for last channel
               if (r.index = NUM_SLAVES_G-1) then
                  -- Next state
                  v.state := IDLE_S;
               else
                  -- Increment the counter
                  v.index := r.index + 1;
               end if;

            -- Check if ready to move data
            elsif (rxMasters(r.index).tValid = '1') and (v.txMaster.tValid = '0') then

               -- Move the data
               v.rxSlaves(r.index).tReady := not(r.sof);
               v.txMaster                 := rxMasters(r.index);

               -- Only forward the accepted frames
               v.txMaster.tValid := r.accept(r.index);

               -- Check if sending the Event Frame Sequence Header
               if (r.sof = '1') then

                  -- Reset the flag
                  v.sof := '0';

                  -- Update the meta-data for a HEADER
                  v.txMaster.tLast := '0';
                  v.txMaster.tKeep := (others => '1');
                  v.txMaster.tUser := (others => '0');

                  -- Set SOF flag
                  ssiSetUserSof(AXIS_CONFIG_G, v.txMaster, '1');

                  -- HEADER context
                  v.txMaster.tData(3 downto 0)   := x"1";      -- Version Field
                  v.txMaster.tData(7 downto 4)   := LOG2_WIDTH_C;  -- log2(TDATA_BYTES_C)
                  v.txMaster.tData(15 downto 8)  := r.seqCnt;  -- Sequence Counter
                  v.txMaster.tData(23 downto 16) := rxMasters(r.index).tUser(7 downto 0);  -- TUSER_FIRST
                  v.txMaster.tData(31 downto 24) := rxMasters(r.index).tDest;  -- TDEST
                  v.txMaster.tData(39 downto 32) := toSlv(NUM_SLAVES_G, 8);  -- Number of streams
                  v.txMaster.tData(47 downto 40) := toSlv(r.index, 8);  -- MUX Index
                  v.txMaster.tData(55 downto 48) := r.frameCnt;  -- Event frame count
                  v.txMaster.tData(63 downto 56) := r.numFrames;  -- Event frame Size (zero inclusive)

               -- Check for the last transfer
               elsif (rxMasters(r.index).tLast = '1') then

                  -- Rearm the flag
                  v.sof := '1';

                  -- Increment frame counter
                  if (r.accept(r.index) = '1') then
                     v.frameCnt := r.frameCnt + 1;
                  end if;

                  -- Check for last channel
                  if (r.index = NUM_SLAVES_G-1) then
                     -- Next state
                     v.state := IDLE_S;
                  else
                     -- Increment the counter
                     v.index := r.index + 1;
                  end if;

               end if;

            end if;
      ----------------------------------------------------------------------
      end case;

      -- Mask off the TDEST/TID (encoded in header)
      v.txMaster.tDest := x"00";
      v.txMaster.tId   := x"00";

      -- Check for state transitioning from MOVE_S to IDLE_S
      if (r.state = MOVE_S) and (v.state = IDLE_S) then

         -- Reset the index pointer
         v.index := 0;

         -- Reset the flags
         v.ready    := '0';
         v.accept   := (others => '0');
         v.transDet := (others => '0');
         v.skipCh   := (others => '0');

         -- Reset the counter
         v.frameCnt := (others => '0');

         -- Increment frame counter
         v.seqCnt := r.seqCnt + 1;

      end if;

      -- Check if reseting counters
      if (r.cntRst = '1') then
         v.dataCnt  := (others => (others => '0'));
         v.transCnt := (others => '0');
      end if;

      -- Outputs
      rxSlaves       <= v.rxSlaves;
      txMaster       <= r.txMaster;
      axilWriteSlave <= r.axilWriteSlave;
      axilReadSlave  <= r.axilReadSlave;

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
   -- Output pipeline
   ------------------
   U_Output : entity surf.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
         PIPE_STAGES_G => OUTPUT_PIPE_STAGES_G)
      port map (
         -- Clock and Reset
         axisClk     => axisClk,
         axisRst     => axisRst,
         -- AXIS Interfaces
         sAxisMaster => txMaster,
         sAxisSlave  => txSlave,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);

end rtl;
