-------------------------------------------------------------------------------
-- Title      : SSI Protocol: https://confluence.slac.stanford.edu/x/0oyfD
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:   This module generates
--                PseudoRandom Binary Sequence (PRBS) on Virtual Channel Lane.
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

entity SsiPrbsRx is
   generic (
      -- General Configurations
      TPD_G                     : time                     := 1 ns;
      RST_ASYNC_G               : boolean                  := false;
      STATUS_CNT_WIDTH_G        : natural range 1 to 32    := 32;
      -- FIFO configurations
      SLAVE_READY_EN_G          : boolean                  := true;
      GEN_SYNC_FIFO_G           : boolean                  := false;
      CASCADE_SIZE_G            : positive                 := 1;
      FIFO_ADDR_WIDTH_G         : positive                 := 9;
      FIFO_PAUSE_THRESH_G       : positive                 := 2**8;
      SYNTH_MODE_G              : string                   := "inferred";
      MEMORY_TYPE_G             : string                   := "block";
      FIFO_INT_WIDTH_SELECT_G   : string                   := "WIDE";
      -- PRBS Config
      PRBS_SEED_SIZE_G          : positive range 32 to 512 := 32;
      PRBS_TAPS_G               : NaturalArray             := (0 => 31, 1 => 6, 2 => 2, 3 => 1);
      -- AXI Stream IO Config
      SLAVE_AXI_STREAM_CONFIG_G : AxiStreamConfigType;
      SLAVE_AXI_PIPE_STAGES_G   : natural                  := 0);
   port (
      -- Streaming RX Data Interface (sAxisClk domain)
      sAxisClk        : in  sl;
      sAxisRst        : in  sl                     := '0';
      sAxisMaster     : in  AxiStreamMasterType;
      sAxisSlave      : out AxiStreamSlaveType;
      sAxisCtrl       : out AxiStreamCtrlType;
      -- Optional: TX Data Interface with EOFE tagging (sAxisClk domain)
      mAxisMaster     : out AxiStreamMasterType;
      mAxisSlave      : in  AxiStreamSlaveType     := AXI_STREAM_SLAVE_FORCE_C;
      -- Optional: AXI-Lite Register Interface (axiClk domain)
      axiClk          : in  sl                     := '0';
      axiRst          : in  sl                     := '0';
      axiReadMaster   : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axiReadSlave    : out AxiLiteReadSlaveType;
      axiWriteMaster  : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axiWriteSlave   : out AxiLiteWriteSlaveType;
      -- Error Detection Signals (sAxisClk domain)
      updatedResults  : out sl;
      errorDet        : out sl;         -- '1' if any error detected
      busy            : out sl;
      errMissedPacket : out sl;
      errLength       : out sl;
      errDataBus      : out sl;
      errEofe         : out sl;
      errWordCnt      : out slv(31 downto 0);
      packetRate      : out slv(31 downto 0);
      packetLength    : out slv(31 downto 0));
end SsiPrbsRx;

architecture rtl of SsiPrbsRx is

   constant MAX_CNT_C        : slv(31 downto 0) := (others => '1');
   constant EVENT_CNT_SIZE_C : integer          := minimum(PRBS_SEED_SIZE_G, 32);
   constant PRBS_BYTES_C     : natural          := wordCount(PRBS_SEED_SIZE_G, 8);
   constant PRBS_SSI_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => PRBS_BYTES_C,
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 8,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 8,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   type StateType is (
      IDLE_S,
      LENGTH_S,
      DATA_S);

   type RegType is record
      busy            : sl;
      packetLength    : slv(31 downto 0);
      errorDet        : sl;
      eofe            : sl;
      errLength       : sl;
      updatedResults  : sl;
      errMissedPacket : sl;
      errDataBus      : sl;
      errWordStrb     : sl;
      txCnt           : slv(3 downto 0);
      bitPntr         : slv(log2(PRBS_SEED_SIZE_G)-1 downto 0);
      errorBits       : slv(PRBS_SEED_SIZE_G-1 downto 0);
      errWordCnt      : slv(31 downto 0);
      eventCnt        : slv(EVENT_CNT_SIZE_C-1 downto 0);
      randomData      : slv(PRBS_SEED_SIZE_G-1 downto 0);
      dataCnt         : slv(31 downto 0);
      stopTime        : slv(31 downto 0);
      startTime       : slv(31 downto 0);
      packetRate      : slv(31 downto 0);
      rxAxisSlave     : AxiStreamSlaveType;
      txAxisMaster    : AxiStreamMasterType;
      state           : StateType;
   end record;

   constant REG_INIT_C : RegType := (
      busy            => '1',
      packetLength    => toSlv(2, 32),
      errorDet        => '0',
      eofe            => '0',
      errLength       => '0',
      updatedResults  => '0',
      errMissedPacket => '0',
      errDataBus      => '0',
      errWordStrb     => '0',
      txCnt           => (others => '0'),
      bitPntr         => (others => '0'),
      errorBits       => (others => '0'),
      errWordCnt      => (others => '0'),
      eventCnt        => toSlv(1, EVENT_CNT_SIZE_C),
      randomData      => (others => '0'),
      dataCnt         => (others => '0'),
      stopTime        => (others => '0'),
      startTime       => (others => '1'),
      packetRate      => (others => '1'),
      rxAxisSlave     => AXI_STREAM_SLAVE_INIT_C,
      txAxisMaster    => AXI_STREAM_MASTER_INIT_C,
      state           => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal rxAxisMaster : AxiStreamMasterType;
   signal rxAxisSlave  : AxiStreamSlaveType;

   signal txAxisMaster : AxiStreamMasterType;
   signal txAxisSlave  : AxiStreamSlaveType;

   signal bypCheck : sl;

   signal axisCtrl : AxiStreamCtrlArray(1 downto 0) := (others => AXI_STREAM_CTRL_UNUSED_C);

   constant STATUS_SIZE_C : positive := 10;

   type LocRegType is record
      cntRst        : sl;
      bypCheck      : sl;
      dummy         : slv(31 downto 0);
      rollOverEn    : slv(STATUS_SIZE_C-1 downto 0);
      axiReadSlave  : AxiLiteReadSlaveType;
      axiWriteSlave : AxiLiteWriteSlaveType;
   end record;

   constant LOC_REG_INIT_C : LocRegType := (
      cntRst        => '1',
      bypCheck      => '0',
      dummy         => (others => '0'),
      rollOverEn    => (others => '0'),
      axiReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axiWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal rAxiLite   : LocRegType := LOC_REG_INIT_C;
   signal rinAxiLite : LocRegType;

   signal errBitStrbSync      : sl;
   signal errWordStrbSync     : sl;
   signal errDataBusSync      : sl;
   signal errEofeSync         : sl;
   signal errLengthSync       : sl;
   signal errMissedPacketSync : sl;

   signal overflow : slv(1 downto 0);
   signal pause    : slv(1 downto 0);

   signal cntOut : SlVectorArray(STATUS_SIZE_C-1 downto 0, STATUS_CNT_WIDTH_G-1 downto 0);

   signal packetLengthSync : slv(31 downto 0);
   signal packetRateSync   : slv(31 downto 0);
   signal errWordCntSync   : slv(31 downto 0);

   signal pause1Cnt          : slv(STATUS_CNT_WIDTH_G-1 downto 0);
   signal overflow1Cnt       : slv(STATUS_CNT_WIDTH_G-1 downto 0);
   signal pause0Cnt          : slv(STATUS_CNT_WIDTH_G-1 downto 0);
   signal overflow0Cnt       : slv(STATUS_CNT_WIDTH_G-1 downto 0);
   signal errWordStrbCnt     : slv(STATUS_CNT_WIDTH_G-1 downto 0);
   signal errDataBusCnt      : slv(STATUS_CNT_WIDTH_G-1 downto 0);
   signal errEofeCnt         : slv(STATUS_CNT_WIDTH_G-1 downto 0);
   signal errLengthCnt       : slv(STATUS_CNT_WIDTH_G-1 downto 0);
   signal errMissedPacketCnt : slv(STATUS_CNT_WIDTH_G-1 downto 0);

begin

   assert ((PRBS_SEED_SIZE_G = 32) or (PRBS_SEED_SIZE_G = 64) or (PRBS_SEED_SIZE_G = 128) or (PRBS_SEED_SIZE_G = 256) or (PRBS_SEED_SIZE_G = 512)) report "PRBS_SEED_SIZE_G must be either [32,64,128,256,512]" severity failure;

   sAxisCtrl <= axisCtrl(0);

   AxiStreamFifo_Rx : entity surf.AxiStreamFifoV2
      generic map(
         -- General Configurations
         TPD_G               => TPD_G,
         RST_ASYNC_G         => RST_ASYNC_G,
         INT_PIPE_STAGES_G   => SLAVE_AXI_PIPE_STAGES_G,
         PIPE_STAGES_G       => SLAVE_AXI_PIPE_STAGES_G,
         SLAVE_READY_EN_G    => SLAVE_READY_EN_G,
         -- FIFO configurations
         GEN_SYNC_FIFO_G     => true,
         CASCADE_SIZE_G      => CASCADE_SIZE_G,
         FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_G,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => FIFO_PAUSE_THRESH_G,
         SYNTH_MODE_G        => SYNTH_MODE_G,
         MEMORY_TYPE_G       => MEMORY_TYPE_G,
         INT_WIDTH_SELECT_G  => FIFO_INT_WIDTH_SELECT_G,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => SLAVE_AXI_STREAM_CONFIG_G,
         MASTER_AXI_CONFIG_G => PRBS_SSI_CONFIG_C)
      port map (
         -- Slave Port
         sAxisClk    => sAxisClk,
         sAxisRst    => sAxisRst,
         sAxisMaster => sAxisMaster,
         sAxisSlave  => sAxisSlave,
         sAxisCtrl   => axisCtrl(0),
         -- Master Port
         mAxisClk    => sAxisClk,
         mAxisRst    => sAxisRst,
         mAxisMaster => rxAxisMaster,
         mAxisSlave  => rxAxisSlave);

   U_Tx : entity surf.AxiStreamGearbox
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         RST_ASYNC_G         => RST_ASYNC_G,
         PIPE_STAGES_G       => SLAVE_AXI_PIPE_STAGES_G,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => PRBS_SSI_CONFIG_C,
         MASTER_AXI_CONFIG_G => SLAVE_AXI_STREAM_CONFIG_G)
      port map (
         -- Clock and reset
         axisClk     => sAxisClk,
         axisRst     => sAxisRst,
         -- Slave Port
         sAxisMaster => txAxisMaster,
         sAxisSlave  => txAxisSlave,
         -- Master Port
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);

   U_bypCheck : entity surf.Synchronizer
      generic map (
         TPD_G       => TPD_G,
         RST_ASYNC_G => RST_ASYNC_G)
      port map (
         clk     => sAxisClk,
         dataIn  => rAxiLite.bypCheck,
         dataOut => bypCheck);

   comb : process (bypCheck, r, rxAxisMaster, sAxisRst, txAxisSlave) is
      variable i : integer;
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobe signals
      v.updatedResults := '0';
      v.errWordStrb    := '0';

      -- AXI Stream Flow Control
      v.rxAxisSlave.tReady := '0';
      if (txAxisSlave.tReady = '1') then
         v.txAxisMaster.tValid := '0';
      end if;

      -- Check for roll over
      if r.stopTime /= r.startTime then
         -- Increment the rate counter
         v.stopTime := r.stopTime + 1;
      end if;

      case (r.state) is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Reset the flags
            v.busy     := '0';
            v.errorDet := '0';

            -- Check for a FIFO read and able to move data
            if (rxAxisMaster.tvalid = '1') and (v.txAxisMaster.tValid = '0') then

               -- Ready to receive data
               v.rxAxisSlave.tReady := '1';

               -- Move the data
               v.txAxisMaster := rxAxisMaster;

               -- Check for start of frame
               if (ssiGetUserSof(PRBS_SSI_CONFIG_C, rxAxisMaster) = '1') and (bypCheck = '0') then

                  -- Check for EOF
                  if (rxAxisMaster.tLast = '1') then

                     -- Set the error flags
                     v.errorDet  := '1';
                     v.errLength := '1';

                     -- Update strobe for the results
                     v.updatedResults := '1';

                     -- Set the EOFE flag
                     ssiSetUserEofe(PRBS_SSI_CONFIG_C, v.txAxisMaster, '1');

                  else

                     -- Calculate the time between this packet and the previous one
                     if (r.stopTime = r.startTime) then
                        v.stopTime := r.stopTime + 1;
                     end if;
                     v.packetRate := r.stopTime - r.startTime;
                     v.startTime  := r.stopTime;

                     -- Reset the error counters
                     v.errWordCnt      := (others => '0');
                     v.errMissedPacket := '0';
                     v.errLength       := '0';
                     v.errDataBus      := '0';
                     v.eofe            := '0';

                     -- Check if we have missed a packet
                     if (rxAxisMaster.tData(EVENT_CNT_SIZE_C-1 downto 0) /= r.eventCnt) then
                        -- Set the error flags
                        v.errMissedPacket := '1';
                        v.errorDet        := '1';
                     end if;

                     -- Align the event counter to the next packet
                     v.eventCnt := rxAxisMaster.tData(EVENT_CNT_SIZE_C-1 downto 0) + 1;

                     -- Latch the SEED for the randomization
                     v.randomData                              := (others => '0');
                     v.randomData(EVENT_CNT_SIZE_C-1 downto 0) := rxAxisMaster.tData(EVENT_CNT_SIZE_C-1 downto 0);

                     -- Set the busy flag
                     v.busy := '1';

                     -- Increment the counter
                     v.dataCnt := r.dataCnt + 1;

                     -- Next State
                     v.state := LENGTH_S;

                  end if;

               end if;
            end if;
         ----------------------------------------------------------------------
         when LENGTH_S =>
            -- Check for a FIFO read and able to move data
            if (rxAxisMaster.tvalid = '1') and (v.txAxisMaster.tValid = '0') then

               -- Ready to receive data
               v.rxAxisSlave.tReady := '1';

               -- Move the data
               v.txAxisMaster := rxAxisMaster;

               -- Calculate the next data word
               v.randomData := lfsrShift(r.randomData, PRBS_TAPS_G);

               -- Latch the packetLength value
               v.packetLength := rxAxisMaster.tData(31 downto 0);

               -- Check for a data bus error
               for i in 4 to PRBS_SSI_CONFIG_C.TDATA_BYTES_C-1 loop
                  if not allBits(rxAxisMaster.tData(i*8+7 downto i*8), '0') then
                     v.errDataBus := '1';
                     v.errorDet   := '1';
                  end if;
               end loop;

               -- Increment the counter
               v.dataCnt := r.dataCnt + 1;

               -- Check for EOF
               if (rxAxisMaster.tLast = '1') then

                  -- Set the error flags
                  v.errorDet  := '1';
                  v.errLength := '1';

                  -- Set the EOFE flag
                  ssiSetUserEofe(PRBS_SSI_CONFIG_C, v.txAxisMaster, '1');

                  -- Reset the counter
                  v.dataCnt := (others => '0');

                  -- Update strobe for the results
                  v.updatedResults := '1';

                  -- Next State
                  v.state := IDLE_S;

               else
                  -- Next State
                  v.state := DATA_S;
               end if;

            end if;
         ----------------------------------------------------------------------
         when DATA_S =>
            -- Check for a FIFO read and able to move data
            if (rxAxisMaster.tvalid = '1') and (v.txAxisMaster.tValid = '0') then

               -- Ready to receive data
               v.rxAxisSlave.tReady := '1';

               -- Move the data
               v.txAxisMaster := rxAxisMaster;

               -- Calculate the next data word
               v.randomData := lfsrShift(r.randomData, PRBS_TAPS_G);

               -- Compare the data word to calculated data word
               if r.randomData /= rxAxisMaster.tData(PRBS_SEED_SIZE_G-1 downto 0) then
                  -- Check for roll over
                  if r.errWordCnt /= MAX_CNT_C then
                     -- Error strobe
                     v.errWordStrb := '1';
                     v.errorDet    := '1';
                     -- Increment the word error counter
                     v.errWordCnt  := r.errWordCnt + 1;
                  end if;
               end if;

               -- Check for end of frame
               if rxAxisMaster.tLast = '1' then

                  -- Latch the packets eofe flag
                  v.eofe := ssiGetUserEofe(PRBS_SSI_CONFIG_C, rxAxisMaster);

                  -- Check for EOFE
                  if v.eofe = '1' then
                     v.errorDet := '1';
                  end if;

                  -- Check the data packet length
                  if r.dataCnt /= r.packetLength then
                     -- Wrong length detected
                     v.errLength := '1';
                     v.errorDet  := '1';
                  end if;

                  -- Set the EOFE flag based on any error detected
                  ssiSetUserEofe(PRBS_SSI_CONFIG_C, v.txAxisMaster, v.errorDet);

                  -- Reset the counter
                  v.dataCnt := (others => '0');

                  -- Update strobe for the results
                  v.updatedResults := '1';

                  -- Next State
                  v.state := IDLE_S;

               -- Increment if not maximum count
               elsif r.dataCnt /= MAX_CNT_C then
                  -- Increment the counter
                  v.dataCnt := r.dataCnt + 1;
               end if;

            end if;
      ----------------------------------------------------------------------
      end case;

      -- Outputs
      rxAxisSlave     <= v.rxAxisSlave;
      txAxisMaster    <= r.txAxisMaster;
      updatedResults  <= r.updatedResults;
      errMissedPacket <= r.errMissedPacket;
      errLength       <= r.errLength;
      errDataBus      <= r.errDataBus;
      errEofe         <= r.eofe;
      errWordCnt      <= r.errWordCnt;
      packetRate      <= r.packetRate;
      busy            <= r.busy;
      packetLength    <= r.packetLength;
      errorDet        <= r.errorDet;

      -- Reset
      if (RST_ASYNC_G = false and sAxisRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (sAxisClk, sAxisRst) is
   begin
      if (RST_ASYNC_G) and (sAxisRst = '1') then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(sAxisClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   SyncFifo_Inst : entity surf.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         RST_ASYNC_G  => RST_ASYNC_G,
         DATA_WIDTH_G => 96)
      port map (
         wr_en              => r.updatedResults,
         wr_clk             => sAxisClk,
         din(31 downto 0)   => r.packetLength,
         din(63 downto 32)  => r.packetRate,
         din(95 downto 64)  => r.errWordCnt,
         rd_clk             => axiClk,
         dout(31 downto 0)  => packetLengthSync,
         dout(63 downto 32) => packetRateSync,
         dout(95 downto 64) => errWordCntSync);

   SyncStatusVec_Inst : entity surf.SyncStatusVector
      generic map (
         TPD_G          => TPD_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         OUT_POLARITY_G => '1',
         CNT_RST_EDGE_G => false,
         COMMON_CLK_G   => false,
         CNT_WIDTH_G    => STATUS_CNT_WIDTH_G,
         WIDTH_G        => STATUS_SIZE_C)
      port map (
         -- Input Status bit Signals (wrClk domain)
         statusIn(9)  => axisCtrl(1).pause,
         statusIn(8)  => axisCtrl(1).overflow,
         statusIn(7)  => axisCtrl(0).pause,
         statusIn(6)  => axisCtrl(0).overflow,
         statusIn(5)  => '0',           -- Legacy
         statusIn(4)  => r.errWordStrb,
         statusIn(3)  => r.errDataBus,
         statusIn(2)  => r.eofe,
         statusIn(1)  => r.errLength,
         statusIn(0)  => r.errMissedPacket,
         -- Output Status bit Signals (rdClk domain)
         statusOut(9) => pause(1),
         statusOut(8) => overflow(1),
         statusOut(7) => pause(0),
         statusOut(6) => overflow(0),
         statusOut(5) => errBitStrbSync,
         statusOut(4) => errWordStrbSync,
         statusOut(3) => errDataBusSync,
         statusOut(2) => errEofeSync,
         statusOut(1) => errLengthSync,
         statusOut(0) => errMissedPacketSync,
         -- Status Bit Counters Signals (rdClk domain)
         cntRstIn     => rAxiLite.cntRst,
         rollOverEnIn => rAxiLite.rollOverEn,
         cntOut       => cntOut,
         -- Clocks and Reset Ports
         wrClk        => sAxisClk,
         rdClk        => axiClk);

   pause1Cnt          <= muxSlVectorArray(cntOut, 9);
   overflow1Cnt       <= muxSlVectorArray(cntOut, 8);
   pause0Cnt          <= muxSlVectorArray(cntOut, 7);
   overflow0Cnt       <= muxSlVectorArray(cntOut, 6);
   -- errBitStrbCnt      <= muxSlVectorArray(cntOut, 5);
   errWordStrbCnt     <= muxSlVectorArray(cntOut, 4);
   errDataBusCnt      <= muxSlVectorArray(cntOut, 3);
   errEofeCnt         <= muxSlVectorArray(cntOut, 2);
   errLengthCnt       <= muxSlVectorArray(cntOut, 1);
   errMissedPacketCnt <= muxSlVectorArray(cntOut, 0);

   -------------------------------
   -- Configuration Register
   -------------------------------
   combAxiLite : process (axiReadMaster, axiRst, axiWriteMaster, errDataBusCnt,
                          errDataBusSync, errEofeCnt, errEofeSync,
                          errLengthCnt, errLengthSync, errMissedPacketCnt,
                          errMissedPacketSync, errWordCntSync, errWordStrbCnt,
                          errWordStrbSync, overflow, overflow0Cnt,
                          overflow1Cnt, packetLengthSync, packetRateSync,
                          pause, pause0Cnt, pause1Cnt, rAxiLite) is
      variable v      : LocRegType;
      variable axilEp : AxiLiteEndpointType;
   begin
      -- Latch the current value
      v := rAxiLite;

      -- Reset strobe signals
      v.cntRst := '0';

      -- Determine the transaction type
      axiSlaveWaitTxn(axilEp, axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave);

      axiSlaveRegisterR(axilEp, X"00", 0, errMissedPacketCnt);
      axiSlaveRegisterR(axilEp, X"04", 0, errLengthCnt);
      axiSlaveRegisterR(axilEp, X"08", 0, errEofeCnt);
      axiSlaveRegisterR(axilEp, X"0C", 0, errDataBusCnt);
      axiSlaveRegisterR(axilEp, X"10", 0, errWordStrbCnt);
      axiSlaveRegisterR(axilEp, X"14", 0, X"00000000");  -- legacy errBitStrbCnt
      axiSlaveRegisterR(axilEp, X"18", 0, overflow0Cnt);
      axiSlaveRegisterR(axilEp, X"1C", 0, pause0Cnt);
      axiSlaveRegisterR(axilEp, X"20", 0, overflow1Cnt);
      axiSlaveRegisterR(axilEp, X"24", 0, pause1Cnt);
      axiSlaveRegister(axilEp, X"28", 0, v.dummy);
      axiSlaveRegisterR(axilEp, X"70", 0, errMissedPacketSync);
      axiSlaveRegisterR(axilEp, X"70", 1, errLengthSync);
      axiSlaveRegisterR(axilEp, X"70", 2, errEofeSync);
      axiSlaveRegisterR(axilEp, X"70", 3, errDataBusSync);
      axiSlaveRegisterR(axilEp, X"70", 4, errWordStrbSync);
      axiSlaveRegisterR(axilEp, X"70", 5, '0');          -- legacy errBitStrbSync
      axiSlaveRegisterR(axilEp, X"70", 6, overflow(0));
      axiSlaveRegisterR(axilEp, X"70", 7, pause(0));
      axiSlaveRegisterR(axilEp, X"70", 8, overflow(1));
      axiSlaveRegisterR(axilEp, X"70", 9, pause(1));
      axiSlaveRegisterR(axilEp, X"74", 0, packetLengthSync);
      axiSlaveRegisterR(axilEp, X"78", 0, packetRateSync);
      axiSlaveRegisterR(axilEp, X"7C", 0, X"00000000");  -- legacy errBitCntSync
      axiSlaveRegisterR(axilEp, X"80", 0, errWordCntSync);
      axiSlaveRegister(axilEp, X"F0", 0, v.rollOverEn);
      axiSlaveRegister(axilEp, X"F4", 0, v.bypCheck);
      axiSlaveRegisterR(axilEp, X"F8", 0, toSlv(PRBS_SEED_SIZE_G, 32));
      axiWrDetect(axilEp, X"FC", v.cntRst);

      axiSlaveDefault(axilEp, v.axiWriteSlave, v.axiReadSlave, AXI_RESP_DECERR_C);

      -- Synchronous Reset
      if (RST_ASYNC_G = false and axiRst = '1') then
         v := LOC_REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rinAxiLite <= v;

      -- Outputs
      axiReadSlave  <= rAxiLite.axiReadSlave;
      axiWriteSlave <= rAxiLite.axiWriteSlave;

   end process combAxiLite;

   seqAxiLite : process (axiClk, axiRst) is
   begin
      if (RST_ASYNC_G) and (axiRst = '1') then
         rAxiLite <= LOC_REG_INIT_C after TPD_G;
      elsif rising_edge(axiClk) then
         rAxiLite <= rinAxiLite after TPD_G;
      end if;
   end process seqAxiLite;

end rtl;
