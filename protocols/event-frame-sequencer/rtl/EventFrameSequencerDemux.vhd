-------------------------------------------------------------------------------
-- Title      : Event Frame Sequencer Protocol: https://confluence.slac.stanford.edu/x/hCRXI
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Event Frame Sequencer DEUX
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

entity EventFrameSequencerDemux is
   generic (
      TPD_G                : time     := 1 ns;
      NUM_MASTERS_G        : positive := 2;
      AXIS_CONFIG_G        : AxiStreamConfigType;
      INPUT_PIPE_STAGES_G  : natural  := 0;
      OUTPUT_PIPE_STAGES_G : natural  := 0);
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
      sAxisMaster     : in  AxiStreamMasterType;
      sAxisSlave      : out AxiStreamSlaveType;
      mAxisMasters    : out AxiStreamMasterArray(NUM_MASTERS_G-1 downto 0);
      mAxisSlaves     : in  AxiStreamSlaveArray(NUM_MASTERS_G-1 downto 0));
end entity EventFrameSequencerDemux;

architecture rtl of EventFrameSequencerDemux is

   constant LOG2_WIDTH_C : slv(3 downto 0) := toSlv(log2(AXIS_CONFIG_G.TDATA_BYTES_C), 4);

   type StateType is (
      IDLE_S,
      MOVE_S);

   type RegType is record
      softRst        : sl;
      hardRst        : sl;
      blowoffReg     : sl;
      blowoff        : sl;
      cntRst         : sl;
      sof            : sl;
      frameCnt       : slv(7 downto 0);
      numFrames      : slv(7 downto 0);
      seqCnt         : slv(7 downto 0);
      dataCnt        : Slv32Array(NUM_MASTERS_G-1 downto 0);
      dropCnt        : slv(31 downto 0);
      hdrError       : slv(7 downto 0);
      index          : natural range 0 to NUM_MASTERS_G-1;
      tUserFirst     : slv(7 downto 0);
      tDest          : slv(7 downto 0);
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
      rxSlave        : AxiStreamSlaveType;
      txMasters      : AxiStreamMasterArray(NUM_MASTERS_G-1 downto 0);
      state          : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      softRst        => '0',
      hardRst        => '0',
      blowoffReg     => '0',
      blowoff        => '0',
      cntRst         => '0',
      sof            => '1',
      frameCnt       => (others => '0'),
      numFrames      => (others => '0'),
      seqCnt         => (others => '0'),
      dataCnt        => (others => (others => '0')),
      dropCnt        => (others => '0'),
      hdrError       => (others => '0'),
      index          => 0,
      tUserFirst     => (others => '0'),
      tDest          => (others => '0'),
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      rxSlave        => AXI_STREAM_SLAVE_INIT_C,
      txMasters      => (others => AXI_STREAM_MASTER_INIT_C),
      state          => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal rxMaster  : AxiStreamMasterType;
   signal rxSlave   : AxiStreamSlaveType;
   signal txMasters : AxiStreamMasterArray(NUM_MASTERS_G-1 downto 0);
   signal txSlaves  : AxiStreamSlaveArray(NUM_MASTERS_G-1 downto 0);

begin

   assert (AXIS_CONFIG_G.TDATA_BYTES_C >= 8)
      report "AXIS_CONFIG_G.TDATA_BYTES_C must be >= 8" severity error;

   -----------------
   -- Input pipeline
   -----------------
   U_Input : entity surf.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
         PIPE_STAGES_G => INPUT_PIPE_STAGES_G)
      port map (
         axisClk     => axisClk,
         axisRst     => axisRst,
         sAxisMaster => sAxisMaster,
         sAxisSlave  => sAxisSlave,
         mAxisMaster => rxMaster,
         mAxisSlave  => rxSlave);

   comb : process (axilReadMaster, axilWriteMaster, axisRst, blowoffExt, r,
                   rxMaster, txSlaves) is
      variable v      : RegType;
      variable axilEp : AxiLiteEndPointType;
      variable dbg    : slv(7 downto 0);
      variable sofDet : sl;
   begin
      -- Latch the current value
      v := r;

      -- Update the local variable
      dbg := (others => '0');
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
         v.blowoffReg := r.blowoffReg;

         -- Preserve the state of AXI-Lite
         v.axilWriteSlave := r.axilWriteSlave;
         v.axilReadSlave  := r.axilReadSlave;

      end if;

      -- Determine the transaction type
      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      -- Map the registers
      for i in (NUM_MASTERS_G-1) downto 0 loop
         axiSlaveRegisterR(axilEp, toSlv(4*i + 0, 12), 0, r.dataCnt(i));
      end loop;
      axiSlaveRegisterR(axilEp, x"FBC", 0, r.seqCnt);
      axiSlaveRegisterR(axilEp, x"FC0", 0, r.dropCnt);
      axiSlaveRegisterR(axilEp, x"FF4", 0, toSlv(NUM_MASTERS_G, 8));
      axiSlaveRegisterR(axilEp, x"FF4", 8, dbg);
      axiSlaveRegisterR(axilEp, X"FF4", 16, blowoffExt);
      axiSlaveRegisterR(axilEp, x"FF4", 24, r.hdrError);
      axiSlaveRegister (axilEp, x"FF8", 0, v.blowoffReg);
      axiSlaveRegister (axilEp, x"FFC", 0, v.cntRst);
      axiSlaveRegister (axilEp, x"FFC", 2, v.hardRst);
      axiSlaveRegister (axilEp, x"FFC", 3, v.softRst);

      -- Closeout the transaction
      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);

      -- Combine the external and internal blowoff together
      v.blowoff := v.blowoffReg or blowoffExt;

      -- Check for any change to blowoff 1->0 transition
      if (r.blowoff = '1') and (v.blowoff = '0') then
         -- Perform a soft-reset
         v.softRst := '1';
      end if;

      ----------------------------------------------------------------------
      -- Check for valid SOF
      sofDet := ssiGetUserSof(AXIS_CONFIG_G, rxMaster);
      if (rxMaster.tValid = '1') and (sofDet = '1') then

         -- Reset the flag
         v.hdrError := (others => '0');

         -- Check for EOF
         if (rxMaster.tLast = '1') then
            v.hdrError(0) := '1';
         end if;

         -- Check for valid version field
         if (rxMaster.tData(3 downto 0) /= x"1") then
            v.hdrError(1) := '1';
         end if;

         -- Check for valid log2(TDATA_BYTES_C)
         if (rxMaster.tData(7 downto 4) /= LOG2_WIDTH_C) then
            v.hdrError(2) := '1';
         end if;

         -- Check for valid event frame index
         if (rxMaster.tData(15 downto 8) /= r.seqCnt) then
            v.hdrError(3) := '1';
         end if;

         -- Check for valid number of streams (zero inclusive)
         if (rxMaster.tData(39 downto 32) /= NUM_MASTERS_G) then
            v.hdrError(4) := '1';
         end if;

         -- Check that index in valid range
         if (rxMaster.tData(47 downto 40) >= NUM_MASTERS_G) then
            v.hdrError(5) := '1';
         end if;

         -- Check for valid event frame index
         if (rxMaster.tData(55 downto 48) /= r.frameCnt) then
            v.hdrError(6) := '1';
         end if;

      end if;
      ----------------------------------------------------------------------

      -- AXIS flow control
      v.rxSlave.tReady := r.blowoff;
      for i in (NUM_MASTERS_G-1) downto 0 loop
         if (txSlaves(i).tReady = '1') then
            v.txMasters(i).tValid := '0';
         end if;
      end loop;

      -- State machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Arm the flag
            v.sof := '1';

            -- Check for blowoff flag
            if (r.blowoff = '1') then

               -- Reset the flags
               v.frameCnt := (others => '0');
               v.seqCnt   := (others => '0');

            elsif (rxMaster.tValid = '1') then

               -- Accept the data
               v.rxSlave.tReady := '1';

               -- Check for valid header and SOF
               if (v.hdrError = 0) and (sofDet = '1') then

                  -- Save the meta-data
                  v.index      := conv_integer(rxMaster.tData(47 downto 40));
                  v.numFrames  := rxMaster.tData(63 downto 56);
                  v.tUserFirst := rxMaster.tData(23 downto 16);
                  v.tDest      := rxMaster.tData(31 downto 24);

                  -- Next state
                  v.state := MOVE_S;

               -- Check for the EOF of the dropped frame
               elsif (rxMaster.tLast = '1') then

                  -- Increment the counter
                  v.dropCnt := r.dropCnt + 1;

                  -- Reset the flags
                  v.frameCnt := (others => '0');
                  v.seqCnt   := (others => '0');

               end if;

            end if;
         ----------------------------------------------------------------------
         when MOVE_S =>
            if (rxMaster.tValid = '1') and (v.txMasters(r.index).tValid = '0') then

               -- Move the data
               v.rxSlave.tReady     := '1';
               v.txMasters(r.index) := rxMaster;

               -- Update the TDEST field
               v.txMasters(r.index).tDest := r.tDest;

               -- Check if sending the TUSER_FIRST
               if (r.sof = '1') then

                  -- Reset the flag
                  v.sof := '0';

                  -- Update the tUser for 1st byte
                  v.txMasters(r.index).tUser(7 downto 0) := r.tUserFirst;

               end if;

               -- Check for the last transfer
               if (rxMaster.tLast = '1') then

                  -- Next state
                  v.state := IDLE_S;

               end if;

            end if;
      ----------------------------------------------------------------------
      end case;

      -- Check for state transitioning from MOVE_S to IDLE_S
      if (r.state = MOVE_S) and (v.state = IDLE_S) then

         -- Increment counters
         v.frameCnt         := r.frameCnt + 1;
         v.dataCnt(r.index) := r.dataCnt(r.index) + 1;

         -- Check if reseting frame counters
         if (r.numFrames = r.frameCnt) then

            -- Increment counter
            v.seqCnt := r.seqCnt + 1;

            -- Reset the counter
            v.frameCnt := (others => '0');

         end if;

      end if;

      -- Check if reseting status counters
      if (r.cntRst = '1') then
         v.dataCnt := (others => (others => '0'));
         v.dropCnt := (others => '0');
      end if;

      -- Outputs
      rxSlave        <= v.rxSlave;
      txMasters      <= r.txMasters;
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
   GEN_VEC :
   for i in (NUM_MASTERS_G-1) downto 0 generate
      U_Output : entity surf.AxiStreamPipeline
         generic map (
            TPD_G         => TPD_G,
            PIPE_STAGES_G => OUTPUT_PIPE_STAGES_G)
         port map (
            -- Clock and Reset
            axisClk     => axisClk,
            axisRst     => axisRst,
            -- AXIS Interfaces
            sAxisMaster => txMasters(i),
            sAxisSlave  => txSlaves(i),
            mAxisMaster => mAxisMasters(i),
            mAxisSlave  => mAxisSlaves(i));
   end generate GEN_VEC;

end rtl;
