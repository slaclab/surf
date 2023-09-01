-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Firmware module that AxiStreamConcat multiple AXI stream frames
--              together.  It will ignore TKEEP and the format of the frame.
-------------------------------------------------------------------------------
-- Note: This module is similiar to "AxiStreamBatcher.vhd" but does NOT
--       have the following features
--          1) No super header
--          2) No tail footer
--          3) Only supports TKEEP_FIXED_C
--       Because of these limitations, it is important to encode the user
--       metadata into payload.  Use AxiStreamBatcher instead if you need
--       a generalized batcher
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
use surf.SsiPkg.all;

entity AxiStreamConcat is
   generic (
      TPD_G                        : time     := 1 ns;
      MAX_NUMBER_SUB_FRAMES_G      : positive := 32;   -- Units of sub-frames
      SUPER_FRAME_BYTE_THRESHOLD_G : natural  := 8192;  -- Units of bytes
      MAX_CLK_GAP_G                : natural  := 256;  -- Units of clock cycles
      AXIS_CONFIG_G                : AxiStreamConfigType;
      INPUT_PIPE_STAGES_G          : natural  := 0;
      OUTPUT_PIPE_STAGES_G         : natural  := 1);
   port (
      -- Clock and Reset
      axisClk                 : in  sl;
      axisRst                 : in  sl;
      -- External Control Interface
      forceTerm               : in  sl               := '0';
      superFrameByteThreshold : in  slv(31 downto 0) := toSlv(SUPER_FRAME_BYTE_THRESHOLD_G, 32);
      maxSubFrames            : in  slv(15 downto 0) := toSlv(MAX_NUMBER_SUB_FRAMES_G, 16);
      maxClkGap               : in  slv(31 downto 0) := toSlv(MAX_CLK_GAP_G, 32);
      idle                    : out sl;
      -- AXIS Interfaces
      sAxisMaster             : in  AxiStreamMasterType;
      sAxisSlave              : out AxiStreamSlaveType;
      mAxisMaster             : out AxiStreamMasterType;
      mAxisSlave              : in  AxiStreamSlaveType);
end entity AxiStreamConcat;

architecture rtl of AxiStreamConcat is

   constant AXIS_WORD_SIZE_C : positive := AXIS_CONFIG_G.TDATA_BYTES_C;  -- Units of bytes

   constant WIDTH_C : slv(3 downto 0) := toSlv(log2(AXIS_WORD_SIZE_C/2), 4);

   type StateType is (
      IDLE_S,
      SUB_FRAME_S,
      EOF_CHECK_S,
      GAP_S);

   type RegType is record
      superFrameByteThreshold    : slv(31 downto 0);
      superByteCnt               : slv(31 downto 0);
      subByteCnt                 : slv(31 downto 0);
      maxSubFrames               : slv(15 downto 0);
      subFrameCnt                : slv(15 downto 0);
      maxClkGap                  : slv(31 downto 0);
      clkGapCnt                  : slv(31 downto 0);
      superFrameByteThresholdDet : sl;
      maxSubFramesDet            : sl;
      forceTerm                  : sl;
      sof                        : sl;
      seqCnt                     : slv(7 downto 0);
      tDest                      : slv(7 downto 0);
      tUserFirst                 : slv(7 downto 0);
      tUserLast                  : slv(7 downto 0);
      chunkCnt                   : natural range 0 to 3;
      rxSlave                    : AxiStreamSlaveType;
      txMaster                   : AxiStreamMasterType;
      state                      : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      superFrameByteThreshold    => toSlv(SUPER_FRAME_BYTE_THRESHOLD_G, 32),
      superByteCnt               => toSlv(AXIS_WORD_SIZE_C, 32),
      subByteCnt                 => (others => '0'),
      maxSubFrames               => toSlv(MAX_NUMBER_SUB_FRAMES_G, 16),
      subFrameCnt                => (others => '0'),
      maxClkGap                  => toSlv(MAX_CLK_GAP_G, 32),
      clkGapCnt                  => (others => '0'),
      superFrameByteThresholdDet => '0',
      maxSubFramesDet            => '0',
      forceTerm                  => '0',
      sof                        => '1',
      seqCnt                     => (others => '0'),
      tDest                      => (others => '0'),
      tUserFirst                 => (others => '0'),
      tUserLast                  => (others => '0'),
      chunkCnt                   => 1,
      rxSlave                    => AXI_STREAM_SLAVE_INIT_C,
      txMaster                   => AXI_STREAM_MASTER_INIT_C,
      state                      => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal rxMaster : AxiStreamMasterType;
   signal rxSlave  : AxiStreamSlaveType;
   signal txMaster : AxiStreamMasterType;
   signal txSlave  : AxiStreamSlaveType;

begin

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

   comb : process (axisRst, forceTerm, maxClkGap, maxSubFrames, r, rxMaster,
                   superFrameByteThreshold, txSlave) is
      variable v : RegType;

      procedure doEofCheck is
      begin
         -- Check for end of super-frame condition
         if (v.superFrameByteThresholdDet = '1') or (v.maxSubFramesDet = '1') or (v.forceTerm = '1') then
            -- Move the outbound data
            v.txMaster.tValid := '1';
            -- Terminate the super-frame
            v.txMaster.tLast  := '1';
            -- Set EOFE
            ssiSetUserEofe(AXIS_CONFIG_G, v.txMaster, v.forceTerm);
            -- Next state
            v.state           := IDLE_S;
         -- Check if new data to move or bypassing clock gap
         elsif (rxMaster.tValid = '1') or (r.maxClkGap = 0) then
            -- Move the outbound data
            v.txMaster.tValid := '1';
            -- Next state
            v.state           := SUB_FRAME_S;
         else
            -- Next state
            v.state := GAP_S;
         end if;
      end procedure doEofCheck;

   begin
      -- Latch the current value
      v := r;

      -- Reset the strobes
      v.rxSlave.tReady := r.forceTerm;
      if (txSlave.tReady = '1') then
         v.txMaster.tValid := '0';
         v.txMaster.tLast  := '0';
         v.txMaster.tUser  := (others => '0');
      end if;

      -- Check for max. super frame
      if(r.superByteCnt = r.superFrameByteThreshold) and (r.superFrameByteThreshold /= 0) then
         -- Set the flag
         v.superFrameByteThresholdDet := '1';
      end if;

      -- Check for max. super frame
      if(r.subFrameCnt = r.maxSubFrames) then
         -- Set the flag
         v.maxSubFramesDet := '1';
      end if;

      -- Register the value
      v.forceTerm := forceTerm;

      -- Main state machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Reset the flag
            v.superFrameByteThresholdDet                                    := '0';
            v.maxSubFramesDet                                               := '0';
            v.sof                                                           := '0';
            -- Sample external signals
            v.superFrameByteThreshold                                       := superFrameByteThreshold;
            v.maxSubFrames                                                  := maxSubFrames;
            v.maxClkGap                                                     := maxClkGap;
            -- Floor the superFrameByteThreshold to nearest word increment
            -- This is done to remove the ">" operator
            v.superFrameByteThreshold(bitSize(AXIS_WORD_SIZE_C)-1 downto 0) := (others => '0');
            -- Check for zero byte superFrameByteThreshold case and not using a zero value external threshold
            if (v.superFrameByteThreshold = 0) and (superFrameByteThreshold /= 0) then
               -- Prevent zero case
               v.superFrameByteThreshold := toSlv(AXIS_WORD_SIZE_C, 32);
            end if;
            -- Check for zero maxSubFrames case
            if (v.maxSubFrames = 0) then
               -- Prevent zero case
               v.maxSubFrames := toSlv(1, 16);
            end if;
            -- Check if ready to move data
            if (rxMaster.tValid = '1') and (r.forceTerm = '0') then
               -- Next state
               v.state := SUB_FRAME_S;
            end if;
            -- Reset the counters
            v.subFrameCnt  := (others => '0');
            v.superByteCnt := (others => '0');
         ----------------------------------------------------------------------
         when SUB_FRAME_S =>
            -- Check if ready to move data
            if (rxMaster.tValid = '1') and (v.txMaster.tValid = '0') then
               -- Accept the inbound data
               v.rxSlave.tReady  := '1';
               -- Move the outbound data
               v.txMaster.tValid := '1';
               v.txMaster.tData  := rxMaster.tData;
               -- Check SOF
               if (r.sof = '1') then
                  -- Set the SOF bit
                  ssiSetUserSof(AXIS_CONFIG_G, v.txMaster, '1');
                  -- Clear the flag
                  v.sof := '0';
               end if;
               -- Check if first transaction
               if (r.subByteCnt = 0) then
                  -- Sample the first transaction
                  v.tUserFirst(AXIS_CONFIG_G.TUSER_BITS_C-1 downto 0) := axiStreamGetUserField(AXIS_CONFIG_G, rxMaster, 0);
                  -- Increment the sub-frame counter
                  v.subFrameCnt                                       := r.subFrameCnt + 1;
               end if;
               -- Check for last transaction in sub-frame
               if (rxMaster.tLast = '1') then
                  -- Hold off on the write
                  v.txMaster.tValid                                  := '0';
                  -- Increment the sub-frame byte counter
                  v.subByteCnt                                       := r.subByteCnt + getTKeep(rxMaster.tKeep, AXIS_CONFIG_G);
                  -- Sample the meta data
                  v.tUserLast(AXIS_CONFIG_G.TUSER_BITS_C-1 downto 0) := axiStreamGetUserField(AXIS_CONFIG_G, rxMaster);
                  v.tDest(AXIS_CONFIG_G.TDEST_BITS_C-1 downto 0)     := rxMaster.tDest(AXIS_CONFIG_G.TDEST_BITS_C-1 downto 0);
                  -- Next state
                  v.state                                            := EOF_CHECK_S;
               else
                  -- Increment the sub-frame byte counter
                  v.subByteCnt := r.subByteCnt + AXIS_WORD_SIZE_C;
               end if;
               -- Increment the super-frame byte counter
               v.superByteCnt := r.superByteCnt + AXIS_WORD_SIZE_C;
            end if;
         ----------------------------------------------------------------------
         when EOF_CHECK_S =>
            -- Reset the counter
            v.subByteCnt   := (others => '0');
            -- Check for EOF (TLAST)
            doEofCheck;
            -- Preset chunk counter
            v.chunkCnt     := 1;
            -- Increment the super-frame byte counter
            v.superByteCnt := r.superByteCnt + AXIS_WORD_SIZE_C;
         ----------------------------------------------------------------------
         when GAP_S =>
            -- Check for new sub-frame
            if (rxMaster.tValid = '1') then
               -- Reset the counter
               v.clkGapCnt       := (others => '0');
               -- Move the data
               v.txMaster.tValid := '1';
               -- Next state
               v.state           := SUB_FRAME_S;
            -- Check for the clock gap event
            elsif (r.clkGapCnt = r.maxClkGap) then
               -- Check if ready to move data
               if (v.txMaster.tValid = '0') then
                  -- Reset the counter
                  v.clkGapCnt       := (others => '0');
                  -- Move the outbound data
                  v.txMaster.tValid := '1';
                  -- Terminate the super-frame
                  v.txMaster.tLast  := '1';
                  -- Next state
                  v.state           := IDLE_S;
               end if;
            else
               -- Increment the counter
               v.clkGapCnt := r.clkGapCnt + 1;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Check for force termination
      if (r.forceTerm = '1') and (r.state /= IDLE_S) then
         doEofCheck;
      end if;

      -- Always the same outbound AXIS stream width
      v.txMaster.tKeep := genTKeep(AXIS_WORD_SIZE_C);
      v.txMaster.tStrb := genTKeep(AXIS_WORD_SIZE_C);

      -- Outputs
      rxSlave  <= v.rxSlave;
      txMaster <= r.txMaster;
      if (r.state = IDLE_S) then
         idle <= '1';
      else
         idle <= '0';
      end if;

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
         axisClk     => axisClk,
         axisRst     => axisRst,
         sAxisMaster => txMaster,
         sAxisSlave  => txSlave,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);

end rtl;
