-------------------------------------------------------------------------------
-- Title      : AxiStream BatcherV1 Protocol: https://confluence.slac.stanford.edu/x/th1SDg
-------------------------------------------------------------------------------
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


library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

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
end entity AxiStreamBatcherEventBuilder;

architecture rtl of AxiStreamBatcherEventBuilder is

   constant DEST_SIZE_C : integer := bitSize(NUM_SLAVES_G-1);

   type StateType is (
      IDLE_S,
      MOVE_S);

   type RegType is record
      softRst        : sl;
      hardRst        : sl;
      blowoffReg     : sl;
      blowoff        : sl;
      timerRst       : sl;
      cntRst         : sl;
      ready          : sl;
      maxSubFrames   : slv(15 downto 0);
      timer          : slv(31 downto 0);
      timeout        : slv(31 downto 0);
      bypass         : slv(NUM_SLAVES_G-1 downto 0);
      dataCnt        : Slv32Array(NUM_SLAVES_G-1 downto 0);
      nullCnt        : Slv32Array(NUM_SLAVES_G-1 downto 0);
      transCnt       : slv(31 downto 0);
      timeoutDropCnt : Slv32Array(NUM_SLAVES_G-1 downto 0);
      accept         : slv(NUM_SLAVES_G-1 downto 0);
      nullDet        : slv(NUM_SLAVES_G-1 downto 0);
      transDet       : slv(NUM_SLAVES_G-1 downto 0);
      timeoutDet     : slv(NUM_SLAVES_G-1 downto 0);
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
      timerRst       => '0',
      cntRst         => '0',
      ready          => '0',
      maxSubFrames   => toSlv(NUM_SLAVES_G, 16),
      timer          => (others => '0'),
      timeout        => (others => '0'),
      bypass         => (others => '0'),
      dataCnt        => (others => (others => '0')),
      nullCnt        => (others => (others => '0')),
      transCnt       => (others => '0'),
      timeoutDropCnt => (others => (others => '0')),
      accept         => (others => '0'),
      nullDet        => (others => '0'),
      transDet       => (others => '0'),
      timeoutDet     => (others => '0'),
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

   signal batcherIdle  : sl;
   signal timeoutEvent : sl;
   signal axisReset    : sl;

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

   U_DspComparator : entity surf.DspComparator
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 32)
      port map (
         clk  => axisClk,
         ain  => r.timer,
         bin  => r.timeout,
         gtEq => timeoutEvent);         -- greater than or equal to (a >= b)

   comb : process (axilReadMaster, axilWriteMaster, axisRst, batcherIdle,
                   blowoffExt, r, rxMasters, timeoutEvent, txSlave) is
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
      v.cntRst   := '0';
      v.timerRst := '0';
      v.hardRst  := '0';
      v.softRst  := '0';

      -- Check for hard reset or soft reset
      if (r.hardRst = '1') or (r.softRst = '1') then
         -- Reset the register
         v := REG_INIT_C;

         -- Preserve the resister configurations
         v.bypass     := r.bypass;
         v.timeout    := r.timeout;
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
         axiSlaveRegisterR(axilEp, toSlv(4*i + 256, 12), 0, r.nullCnt(i));
         axiSlaveRegisterR(axilEp, toSlv(4*i + 512, 12), 0, r.timeoutDropCnt(i));
      end loop;
      axiSlaveRegisterR(axilEp, x"FC0", 0, r.transCnt);
      axiSlaveRegisterR(axilEp, x"FC4", 0, TRANS_TDEST_G);
      axiSlaveRegister (axilEp, x"FD0", 0, v.bypass);
      axiSlaveRegister (axilEp, x"FF0", 0, v.timeout);
      axiSlaveRegisterR(axilEp, x"FF4", 0, toSlv(NUM_SLAVES_G, 8));
      axiSlaveRegisterR(axilEp, x"FF4", 8, dbg);
      axiSlaveRegisterR(axilEp, X"FF4", 16, blowoffExt);
      axiSlaveRegister (axilEp, x"FF8", 0, v.blowoffReg);
      axiSlaveRegister (axilEp, x"FFC", 0, v.cntRst);
      axiSlaveRegister (axilEp, x"FFC", 1, v.timerRst);
      axiSlaveRegister (axilEp, x"FFC", 2, v.hardRst);
      axiSlaveRegister (axilEp, x"FFC", 3, v.softRst);

      -- Closeout the transaction
      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);

      v.blowoff := v.blowoffReg or blowoffExt;

      -- Check for change in configuration
      if (r.timeout /= v.timeout) or (r.timerRst = '1') then
         -- Reset the timer
         v.timer := (others => '0');
      end if;

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

            -- Loop through RX channels
            for i in (NUM_SLAVES_G-1) downto 0 loop

               -- Check if no data and not bypassing
               if (rxMasters(i).tValid = '0') and (r.bypass(i) = '0') then
                  -- Reset the flags
                  v.ready       := '0';
                  v.accept(i)   := '0';
                  v.nullDet(i)  := '0';
                  v.transDet(i) := '0';
               else
                  ----------------------------------------------------------------------------------------------------
                  ----------------------------------------------------------------------------------------------------
                  ----------------------------------------------------------------------------------------------------
                  -- Check for NULL frame (defined as a single word transaction with EOFE asserted and byte count = 1)
                  ----------------------------------------------------------------------------------------------------
                  ----------------------------------------------------------------------------------------------------
                  ----------------------------------------------------------------------------------------------------
                  if (rxMasters(i).tLast = '1') and  -- TLAST asserted
                                    (ssiGetUserEofe(AXIS_CONFIG_G, rxMasters(i)) = '1') and  -- EOFE flag set
                                    (getTKeep(rxMasters(i).tKeep(AXIS_CONFIG_G.TDATA_BYTES_C-1 downto 0), AXIS_CONFIG_G) = 1) then  -- byte count = 1
                     -- NULL frame detected
                     v.accept(i)   := '0';
                     v.nullDet(i)  := not(r.bypass(i));
                     v.transDet(i) := '0';

                  -- Check if not a transition TDEST
                  elsif (rxMasters(i).tDest /= TRANS_TDEST_G) then
                     -- Normal frame detected
                     v.accept(i)   := not(r.bypass(i));
                     v.nullDet(i)  := '0';
                     v.transDet(i) := '0';

                  -- Else a transitions TDEST
                  else
                     -- Transitions frame detected
                     v.accept(i)   := '0';
                     v.nullDet(i)  := '0';
                     v.transDet(i) := not(r.bypass(i));

                  end if;

               end if;
            end loop;

            -- Check if using timer
            if (r.timeout /= 0) then
               -- Check if 1 of the channels are ready
               if (r.accept /= 0) then
                  -- Check for timeout
                  if (timeoutEvent = '1') then
                     -- Set the flag
                     v.ready := '1';
                  else
                     -- Increment the counter
                     v.timer := r.timer + 1;
                  end if;
               end if;
            end if;

            -- Check if transition detected
            if (v.transDet /= 0) then
               -- Set the flag
               v.ready := '1';
            end if;

            -- Check if ready to move data and not blowing off the data
            if (batcherIdle = '1') and (r.ready = '1') and (r.blowoff = '0') then

               -- Check for transition
               if (r.transDet /= 0) then

                  -- Increment transition counter
                  v.transCnt := r.transCnt + 1;

                  -- Set the sub-frame count
                  v.maxSubFrames := resize(onesCount(r.transDet), 16);

                  -- Re-write the accept/timeoutDet mask
                  v.accept     := r.transDet;
                  v.timeoutDet := not(r.transDet);

               else

                  for i in (NUM_SLAVES_G-1) downto 0 loop

                     -- Increment data counter
                     if (r.accept(i) = '1') then
                        v.dataCnt(i) := r.dataCnt(i) + 1;
                     end if;

                     -- Increment null counter
                     if (r.nullDet(i) = '1') then
                        v.nullCnt(i) := r.nullCnt(i) + 1;
                     end if;

                     -- Check if using timer
                     if (r.timeout /= 0) then

                        -- Check for timeout event with respect to a channel
                        if (r.accept(i) = '0') and (r.nullDet(i) = '0') then

                           -- Increment counter
                           v.timeoutDropCnt(i) := r.timeoutDropCnt(i) + 1;

                           -- Set the flag
                           v.timeoutDet(i) := '1';
                        end if;

                     end if;

                  end loop;

                  -- Set the sub-frame count
                  v.maxSubFrames := resize(onesCount(r.accept), 16);

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
               v.ready      := '0';
               v.accept     := (others => '0');
               v.nullDet    := (others => '0');
               v.transDet   := (others => '0');
               v.timer      := (others => '0');
               v.timeoutDet := (others => '0');

            end if;
         ----------------------------------------------------------------------
         when MOVE_S =>
            -- Check for timeout or bypass on the channel
            if (r.timeoutDet(r.index) = '1') or (r.bypass(r.index) = '1') then

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
               v.rxSlaves(r.index).tReady := '1';
               v.txMaster                 := rxMasters(r.index);

               -- Only forward the non-NULL frames
               v.txMaster.tValid := r.accept(r.index);

               -- Check for the last transfer
               if (rxMasters(r.index).tLast = '1') then
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

      -- Check for state transitioning from MOVE_S to IDLE_S
      if (r.state = MOVE_S) and (v.state = IDLE_S) then

         -- Reset the index pointer
         v.index := 0;

         -- Reset the flags
         v.ready      := '0';
         v.accept     := (others => '0');
         v.nullDet    := (others => '0');
         v.transDet   := (others => '0');
         v.timer      := (others => '0');
         v.timeoutDet := (others => '0');

      end if;

      -- Check if reseting counters
      if (r.cntRst = '1') then
         v.dataCnt        := (others => (others => '0'));
         v.nullCnt        := (others => (others => '0'));
         v.timeoutDropCnt := (others => (others => '0'));
         v.transCnt       := (others => '0');
      end if;

      -- Outputs
      rxSlaves       <= v.rxSlaves;
      txMaster       <= r.txMaster;
      axilWriteSlave <= r.axilWriteSlave;
      axilReadSlave  <= r.axilReadSlave;
      axisReset      <= axisRst or r.hardRst or r.softRst;

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
   U_AxiStreamBatcher : entity surf.AxiStreamBatcher
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
         axisRst      => axisReset,
         -- External Control Interface
         forceTerm    => r.blowoff,
         maxSubFrames => r.maxSubFrames,
         idle         => batcherIdle,
         -- AXIS Interfaces
         sAxisMaster  => txMaster,
         sAxisSlave   => txSlave,
         mAxisMaster  => mAxisMaster,
         mAxisSlave   => mAxisSlave);

end rtl;
