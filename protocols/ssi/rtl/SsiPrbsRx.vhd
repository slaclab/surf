-------------------------------------------------------------------------------
-- File       : SsiPrbsRx.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-02
-- Last update: 2017-08-22
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

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

entity SsiPrbsRx is
   generic (
      -- General Configurations
      TPD_G                      : time                       := 1 ns;
      STATUS_CNT_WIDTH_G         : natural range 1 to 32      := 32;
      AXI_ERROR_RESP_G           : slv(1 downto 0)            := AXI_RESP_SLVERR_C;
      -- FIFO configurations
      SLAVE_READY_EN_G           : boolean                    := false;
      BRAM_EN_G                  : boolean                    := true;
      XIL_DEVICE_G               : string                     := "7SERIES";
      USE_BUILT_IN_G             : boolean                    := false;
      GEN_SYNC_FIFO_G            : boolean                    := false;
      ALTERA_SYN_G               : boolean                    := false;
      ALTERA_RAM_G               : string                     := "M9K";
      CASCADE_SIZE_G             : natural range 1 to (2**24) := 1;
      FIFO_ADDR_WIDTH_G          : natural range 4 to 48      := 9;
      FIFO_PAUSE_THRESH_G        : natural range 1 to (2**24) := 2**8;
      -- PRBS Config
      PRBS_SEED_SIZE_G           : natural range 8 to 128     := 32;
      PRBS_TAPS_G                : NaturalArray               := (0 => 31, 1 => 6, 2 => 2, 3 => 1);
      -- AXI Stream IO Config
      SLAVE_AXI_STREAM_CONFIG_G  : AxiStreamConfigType        := ssiAxiStreamConfig(4);
      SLAVE_AXI_PIPE_STAGES_G    : natural range 0 to 16      := 0;
      MASTER_AXI_STREAM_CONFIG_G : AxiStreamConfigType        := ssiAxiStreamConfig(4);
      MASTER_AXI_PIPE_STAGES_G   : natural range 0 to 16      := 0);
   port (
      -- Streaming RX Data Interface (sAxisClk domain) 
      sAxisClk        : in  sl;
      sAxisRst        : in  sl                     := '0';
      sAxisMaster     : in  AxiStreamMasterType;
      sAxisSlave      : out AxiStreamSlaveType;
      sAxisCtrl       : out AxiStreamCtrlType;
      -- Optional: Streaming TX Data Interface (mAxisClk domain)
      mAxisClk        : in  sl;         -- Note: a clock must always be applied to this port
      mAxisRst        : in  sl                     := '0';
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
      errbitCnt       : out slv(31 downto 0);
      packetRate      : out slv(31 downto 0);
      packetLength    : out slv(31 downto 0));
end SsiPrbsRx;

architecture rtl of SsiPrbsRx is

   constant MAX_CNT_C                : slv(31 downto 0)    := (others => '1');
   constant PRBS_BYTES_C             : natural             := wordCount(PRBS_SEED_SIZE_G, 8);
   constant SLAVE_PRBS_SSI_CONFIG_C  : AxiStreamConfigType := ssiAxiStreamConfig(PRBS_BYTES_C, TKEEP_COMP_C);
   constant MASTER_PRBS_SSI_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(PRBS_BYTES_C, TKEEP_COMP_C);

   type StateType is (
      IDLE_S,
      LENGTH_S,
      DATA_S,
      BIT_ERR_S,
      SEND_RESULT_S);

   type RegType is record
      busy            : sl;
      packetLength    : slv(31 downto 0);
      errorDet        : sl;
      eof             : sl;
      eofe            : sl;
      errLength       : sl;
      updatedResults  : sl;
      errMissedPacket : sl;
      errDataBus      : sl;
      errWordStrb     : sl;
      errBitStrb      : sl;
      txCnt           : slv(3 downto 0);
      bitPntr         : slv(log2(PRBS_SEED_SIZE_G)-1 downto 0);
      errorBits       : slv(PRBS_SEED_SIZE_G-1 downto 0);
      errWordCnt      : slv(31 downto 0);
      errbitCnt       : slv(31 downto 0);
      eventCnt        : slv(PRBS_SEED_SIZE_G-1 downto 0);
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
      eof             => '0',
      eofe            => '0',
      errLength       => '0',
      updatedResults  => '0',
      errMissedPacket => '0',
      errDataBus      => '0',
      errWordStrb     => '0',
      errBitStrb      => '0',
      txCnt           => (others => '0'),
      bitPntr         => (others => '0'),
      errorBits       => (others => '0'),
      errWordCnt      => (others => '0'),
      errbitCnt       => (others => '0'),
      eventCnt        => toSlv(1, PRBS_SEED_SIZE_G),
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

   signal txAxisMaster,
      rxAxisMaster : AxiStreamMasterType;

   signal txAxisSlave,
      rxAxisSlave : AxiStreamSlaveType;

   signal axisCtrl : AxiStreamCtrlArray(0 to 1);

   constant STATUS_SIZE_C : positive := 10;

   type LocRegType is record
      cntRst        : sl;
      dummy         : slv(31 downto 0);
      rollOverEn    : slv(STATUS_SIZE_C-1 downto 0);
      axiReadSlave  : AxiLiteReadSlaveType;
      axiWriteSlave : AxiLiteWriteSlaveType;
   end record;

   constant LOC_REG_INIT_C : LocRegType := (
      '1',
      (others => '0'),
      (others => '0'),
      AXI_LITE_READ_SLAVE_INIT_C,
      AXI_LITE_WRITE_SLAVE_INIT_C);

   signal rAxiLite   : LocRegType := LOC_REG_INIT_C;
   signal rinAxiLite : LocRegType;

   signal errBitStrbSync,
      errWordStrbSync,
      errDataBusSync,
      errEofeSync,
      errLengthSync,
      errMissedPacketSync : sl;

   signal overflow,
      pause : slv(1 downto 0);

   signal cntOut : SlVectorArray(STATUS_SIZE_C-1 downto 0, STATUS_CNT_WIDTH_G-1 downto 0);

   signal packetLengthSync,
      packetRateSync,
      errbitCntSync,
      errWordCntSync : slv(31 downto 0);

   signal pause1Cnt,
      overflow1Cnt,
      pause0Cnt,
      overflow0Cnt,
      errBitStrbCnt,
      errWordStrbCnt,
      errDataBusCnt,
      errEofeCnt,
      errLengthCnt,
      errMissedPacketCnt : slv(STATUS_CNT_WIDTH_G-1 downto 0);

begin

--   assert (PRBS_SEED_SIZE_G mod 8 = 0) report "PRBS_SEED_SIZE_G must be a multiple of 8" severity failure;

   sAxisCtrl <= axisCtrl(0);

   AxiStreamFifo_Rx : entity work.AxiStreamFifoV2
      generic map(
         -- General Configurations
         TPD_G               => TPD_G,
         INT_PIPE_STAGES_G   => SLAVE_AXI_PIPE_STAGES_G,
         PIPE_STAGES_G       => SLAVE_AXI_PIPE_STAGES_G,
         SLAVE_READY_EN_G    => SLAVE_READY_EN_G,
         -- FIFO configurations
         BRAM_EN_G           => BRAM_EN_G,
         XIL_DEVICE_G        => XIL_DEVICE_G,
         USE_BUILT_IN_G      => USE_BUILT_IN_G,
         GEN_SYNC_FIFO_G     => true,
         ALTERA_SYN_G        => ALTERA_SYN_G,
         ALTERA_RAM_G        => ALTERA_RAM_G,
         CASCADE_SIZE_G      => CASCADE_SIZE_G,
         FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_G,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => FIFO_PAUSE_THRESH_G,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => SLAVE_AXI_STREAM_CONFIG_G,
         MASTER_AXI_CONFIG_G => SLAVE_PRBS_SSI_CONFIG_C)
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


   comb : process (r, rxAxisMaster, sAxisRst, txAxisSlave) is
      variable i : integer;
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Set the AXIS configurations
      v.txAxisMaster.tKeep := (others => '0');
      v.txAxisMaster.tStrb := (others => '0');
      for i in 0 to MASTER_PRBS_SSI_CONFIG_C.TDATA_BYTES_C-1 loop
         v.txAxisMaster.tKeep(i) := '1';
         v.txAxisMaster.tStrb(i) := '1';
      end loop;

      -- Reset strobe signals
      v.updatedResults      := '0';
      v.txAxisMaster.tValid := '0';
      v.txAxisMaster.tLast  := '0';
      v.txAxisMaster.tUser  := (others => '0');
      v.errWordStrb         := '0';
      v.errBitStrb          := '0';

      -- Check for roll over
      if r.stopTime /= r.startTime then
         -- Increment the rate counter
         v.stopTime := r.stopTime + 1;
      end if;

      case (r.state) is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Reset the flags
            v.busy               := '0';
            v.errorDet           := '0';
            -- Ready to receive data
            v.rxAxisSlave.tReady := '1';
            -- Check for a FIFO read
            if (rxAxisMaster.tvalid = '1') and (r.rxAxisSlave.tReady = '1') then
               -- Calculate the time between this packet and the previous one
               if (r.stopTime = r.startTime) then
                  v.stopTime := r.stopTime + 1;
               end if;
               v.packetRate      := r.stopTime - r.startTime;
               v.startTime       := r.stopTime;
               -- Reset the error counters
               v.errWordCnt      := (others => '0');
               v.errbitCnt       := (others => '0');
               v.errMissedPacket := '0';
               v.errLength       := '0';
               v.errDataBus      := '0';
               v.eof             := '0';
               v.eofe            := '0';
               -- Check if we have missed a packet 
               if rxAxisMaster.tData(PRBS_SEED_SIZE_G-1 downto 0) /= r.eventCnt then
                  -- Set the error flags
                  v.errMissedPacket := '1';
                  v.errorDet        := '1';
               end if;
               -- Align the event counter to the next packet
               v.eventCnt   := rxAxisMaster.tData(PRBS_SEED_SIZE_G-1 downto 0) + 1;
               -- Latch the SEED for the randomization
               v.randomData := rxAxisMaster.tData(PRBS_SEED_SIZE_G-1 downto 0);
               -- Check for a data bus error
--               for i in 4 to AXI_STREAM_CONFIG_G.TDATA_BYTES_C-1 loop
--                  if anyBits(rxAxisMaster.tData(i*8+7 downto i*8), '1') then
--                     v.errDataBus := '1';
--                     v.errorDet   := '1';
--                  end if;
--               end loop;
               -- Set the busy flag
               v.busy       := '1';
               -- Increment the counter
               v.dataCnt    := r.dataCnt + 1;
               -- Next State
               v.state      := LENGTH_S;
            end if;
         ----------------------------------------------------------------------
         when LENGTH_S =>
            -- Check for a FIFO read
            if (rxAxisMaster.tvalid = '1') and (r.rxAxisSlave.tReady = '1') then
               -- Calculate the next data word
               v.randomData   := lfsrShift(r.randomData, PRBS_TAPS_G);
               -- Latch the packetLength value
               v.packetLength := rxAxisMaster.tData(31 downto 0);
               -- Check for a data bus error
               for i in 4 to SLAVE_PRBS_SSI_CONFIG_C.TDATA_BYTES_C-1 loop
                  if not allBits(rxAxisMaster.tData(i*8+7 downto i*8), '0') then
                     v.errDataBus := '1';
                     v.errorDet   := '1';
                  end if;
               end loop;
               -- Increment the counter
               v.dataCnt := r.dataCnt + 1;
               -- Next State
               v.state   := DATA_S;
            end if;
         ----------------------------------------------------------------------
         when DATA_S =>
            -- Check for a FIFO read
            if (rxAxisMaster.tvalid = '1') and (r.rxAxisSlave.tReady = '1') then
               -- Check for a data bus error
--               for i in 0 to (AXI_STREAM_CONFIG_G.TDATA_BYTES_C/4)-1 loop
--                  if rxAxisMaster.tData(31 downto 0) /= rxAxisMaster.tData(i*32+31 downto i*32) then
--                     v.errDataBus := '1';
--                     v.errorDet   := '1';
--                  end if;
--               end loop;
               -- Calculate the next data word
               v.randomData := lfsrShift(r.randomData, PRBS_TAPS_G);
               -- Check for end of frame
               if rxAxisMaster.tLast = '1' then
                  -- Set the local eof flag
                  v.eof  := '1';
                  -- Latch the packets eofe flag
                  v.eofe := ssiGetUserEofe(SLAVE_PRBS_SSI_CONFIG_C, rxAxisMaster);
                  -- Check for EOFE
                  if v.eofe = '1' then
                     v.errorDet := '1';
                  end if;
                  -- Check the data packet length
                  if r.dataCnt /= r.packetLength then
                     -- Wrong length detected
                     v.errLength := '1';
                  end if;
                  -- Reset the counter
                  v.dataCnt            := (others => '0');
                  -- Stop reading the FIFO
                  v.rxAxisSlave.tReady := '0';
                  -- Next State
                  v.state              := SEND_RESULT_S;
               elsif r.dataCnt /= MAX_CNT_C then
                  -- Increment the counter
                  v.dataCnt := r.dataCnt + 1;
               end if;
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
                  -- Latch the bits with error
                  v.errorBits          := (r.randomData xor rxAxisMaster.tData(PRBS_SEED_SIZE_G-1 downto 0));
                  -- Stop reading the FIFO
                  v.rxAxisSlave.tReady := '0';
                  -- Next State
                  v.state              := BIT_ERR_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when BIT_ERR_S =>
            -- Increment the counter
            v.bitPntr := r.bitPntr + 1;
            -- Check for an error bit
            if r.errorBits(conv_integer(r.bitPntr)) = '1' then
               -- Check for roll over
               if r.errbitCnt /= MAX_CNT_C then
                  -- Error strobe
                  v.errBitStrb := '1';
                  v.errorDet   := '1';
                  -- Increment the bit error counter
                  v.errbitCnt  := r.errbitCnt + 1;
               end if;
            end if;
            -- Check the bit pointer
            if r.bitPntr = PRBS_SEED_SIZE_G-1 then
               -- Reset the counter
               v.bitPntr := (others => '0');
               -- Check if there was an eof flag
               if r.eof = '1' then
                  -- Next State
                  v.state := SEND_RESULT_S;
               else
                  -- Ready for more data
                  v.rxAxisSlave.tReady := '1';
                  -- Next State
                  v.state              := DATA_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when SEND_RESULT_S =>
            -- Check the upstream buffer status
            if txAxisSlave.tReady = '1' then
               -- Sending Data 
               v.txAxisMaster.tValid := '1';
               -- Increment the data counter
               v.txCnt               := r.txCnt + 1;
               -- Send data w.r.t. the counter
               case (r.txCnt) is
                  when x"0" =>
                     -- Update strobe for the results
                     v.updatedResults                   := '1';
                     -- Write the data to the TX virtual channel
                     v.txAxisMaster.tData(31 downto 16) := x"FFFF";  -- static pattern for software alignment
                     v.txAxisMaster.tData(15 downto 0)  := (others => '0');
                  when x"1" =>
                     v.txAxisMaster.tData(31 downto 0) := r.packetLength;
                  when x"2" =>
                     v.txAxisMaster.tData(31 downto 0) := r.packetRate;
                  when x"3" =>
                     v.txAxisMaster.tData(31 downto 0) := r.errWordCnt;
                  when x"4" =>
                     v.txAxisMaster.tData(31 downto 0) := r.errbitCnt;
                  when others =>
                     -- Reset the counter
                     v.txCnt                           := (others => '0');
                     -- Send the last word
                     v.txAxisMaster.tLast              := '1';
                     v.txAxisMaster.tData(31 downto 4) := (others => '0');
                     v.txAxisMaster.tData(3)           := r.errDataBus;
                     v.txAxisMaster.tData(2)           := r.eofe;
                     v.txAxisMaster.tData(1)           := r.errLength;
                     v.txAxisMaster.tData(0)           := r.errMissedPacket;
                     -- Ready to receive data
                     v.rxAxisSlave.tReady              := '1';
                     -- Reset the busy flag
                     v.busy                            := '0';
                     -- Next State
                     v.state                           := IDLE_S;
               end case;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (sAxisRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      rxAxisSlave     <= r.rxAxisSlave;
      txAxisMaster    <= r.txAxisMaster;
      updatedResults  <= r.updatedResults;
      errMissedPacket <= r.errMissedPacket;
      errLength       <= r.errLength;
      errDataBus      <= r.errDataBus;
      errEofe         <= r.eofe;
      errWordCnt      <= r.errWordCnt;
      errbitCnt       <= r.errbitCnt;
      packetRate      <= r.packetRate;
      busy            <= r.busy;
      packetLength    <= r.packetLength;
      errorDet        <= r.errorDet;

   end process comb;

   seq : process (sAxisClk) is
   begin
      if rising_edge(sAxisClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   AxiStreamFifo_Tx : entity work.AxiStreamFifoV2
      generic map(
         -- General Configurations
         TPD_G               => TPD_G,
         INT_PIPE_STAGES_G   => MASTER_AXI_PIPE_STAGES_G,
         PIPE_STAGES_G       => MASTER_AXI_PIPE_STAGES_G,
         -- FIFO configurations
         BRAM_EN_G           => BRAM_EN_G,
         XIL_DEVICE_G        => XIL_DEVICE_G,
         USE_BUILT_IN_G      => USE_BUILT_IN_G,
         GEN_SYNC_FIFO_G     => GEN_SYNC_FIFO_G,
         ALTERA_SYN_G        => ALTERA_SYN_G,
         ALTERA_RAM_G        => ALTERA_RAM_G,
         CASCADE_SIZE_G      => CASCADE_SIZE_G,
         FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_G,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => FIFO_PAUSE_THRESH_G,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => MASTER_PRBS_SSI_CONFIG_C,
         MASTER_AXI_CONFIG_G => MASTER_AXI_STREAM_CONFIG_G)
      port map (
         -- Slave Port
         sAxisClk    => sAxisClk,
         sAxisRst    => sAxisRst,
         sAxisMaster => txAxisMaster,
         sAxisSlave  => txAxisSlave,
         sAxisCtrl   => axisCtrl(1),
         -- Master Port
         mAxisClk    => mAxisClk,
         mAxisRst    => mAxisRst,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);

   SyncFifo_Inst : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 128)
      port map (
         wr_en               => r.updatedResults,
         wr_clk              => sAxisClk,
         din(31 downto 0)    => r.packetLength,
         din(63 downto 32)   => r.packetRate,
         din(95 downto 64)   => r.errbitCnt,
         din(127 downto 96)  => r.errWordCnt,
         rd_clk              => axiClk,
         dout(31 downto 0)   => packetLengthSync,
         dout(63 downto 32)  => packetRateSync,
         dout(95 downto 64)  => errbitCntSync,
         dout(127 downto 96) => errWordCntSync);

   SyncStatusVec_Inst : entity work.SyncStatusVector
      generic map (
         TPD_G          => TPD_G,
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
         statusIn(5)  => r.errBitStrb,
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
   errBitStrbCnt      <= muxSlVectorArray(cntOut, 5);
   errWordStrbCnt     <= muxSlVectorArray(cntOut, 4);
   errDataBusCnt      <= muxSlVectorArray(cntOut, 3);
   errEofeCnt         <= muxSlVectorArray(cntOut, 2);
   errLengthCnt       <= muxSlVectorArray(cntOut, 1);
   errMissedPacketCnt <= muxSlVectorArray(cntOut, 0);

   -------------------------------
   -- Configuration Register
   -------------------------------  
   combAxiLite : process (axiReadMaster, axiRst, axiWriteMaster, errBitStrbCnt, errBitStrbSync,
                          errDataBusCnt, errDataBusSync, errEofeCnt, errEofeSync, errLengthCnt,
                          errLengthSync, errMissedPacketCnt, errMissedPacketSync, errWordCntSync,
                          errWordStrbCnt, errWordStrbSync, errbitCntSync, overflow, overflow0Cnt,
                          overflow1Cnt, packetLengthSync, packetRateSync, pause, pause0Cnt,
                          pause1Cnt, rAxiLite) is
      variable v            : LocRegType;
      variable axiStatus    : AxiLiteStatusType;
      variable axiWriteResp : slv(1 downto 0);
      variable axiReadResp  : slv(1 downto 0);
   begin
      -- Latch the current value
      v := rAxiLite;

      -- Determine the transaction type
      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);

      -- Reset strobe signals
      v.cntRst := '0';

      if (axiStatus.writeEnable = '1') then
         -- Check for an out of 32 bit aligned address
         axiWriteResp := ite(axiWriteMaster.awaddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_ERROR_RESP_G);
         -- Decode address and perform write
         case (axiWriteMaster.awaddr(9 downto 2)) is
            when X"0A" =>
               v.dummy := axiWriteMaster.wdata;
            when x"F0" =>
               v.rollOverEn := axiWriteMaster.wdata(STATUS_SIZE_C-1 downto 0);
            when x"FF" =>
               v.cntRst := '1';
            when others =>
               axiWriteResp := AXI_ERROR_RESP_G;
         end case;
         -- Send AXI response
         axiSlaveWriteResponse(v.axiWriteSlave, axiWriteResp);
      end if;

      if (axiStatus.readEnable = '1') then
         -- Check for an out of 32 bit aligned address
         axiReadResp          := ite(axiReadMaster.araddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_ERROR_RESP_G);
         -- Decode address and assign read data
         v.axiReadSlave.rdata := (others => '0');
         case (axiReadMaster.araddr(9 downto 2)) is
            when x"00" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := errMissedPacketCnt;
            when x"01" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := errLengthCnt;
            when x"02" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := errEofeCnt;
            when x"03" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := errDataBusCnt;
            when x"04" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := errWordStrbCnt;
            when x"05" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := errBitStrbCnt;
            when x"06" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := overflow0Cnt;
            when x"07" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := pause0Cnt;
            when x"08" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := overflow1Cnt;
            when x"09" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := pause1Cnt;
            when X"0A" =>
               v.axiReadSlave.rdata := rAxiLite.dummy;
            when x"70" =>
               v.axiReadSlave.rdata(0) := errMissedPacketSync;
               v.axiReadSlave.rdata(1) := errLengthSync;
               v.axiReadSlave.rdata(2) := errEofeSync;
               v.axiReadSlave.rdata(3) := errDataBusSync;
               v.axiReadSlave.rdata(4) := errWordStrbSync;
               v.axiReadSlave.rdata(5) := errBitStrbSync;
               v.axiReadSlave.rdata(6) := overflow(0);
               v.axiReadSlave.rdata(7) := pause(0);
               v.axiReadSlave.rdata(8) := overflow(1);
               v.axiReadSlave.rdata(9) := pause(1);
            when x"71" =>
               v.axiReadSlave.rdata := packetLengthSync;
            when x"72" =>
               v.axiReadSlave.rdata := packetRateSync;
            when x"73" =>
               v.axiReadSlave.rdata := errbitCntSync;
            when x"74" =>
               v.axiReadSlave.rdata := errWordCntSync;
            when x"F0" =>
               v.axiReadSlave.rdata(STATUS_SIZE_C-1 downto 0) := rAxiLite.rollOverEn;
            when X"F1" =>
               v.axiReadSlave.rdata := toSlv(PRBS_SEED_SIZE_G, 32);
            when others =>
               axiReadResp := AXI_ERROR_RESP_G;
         end case;
         -- Send Axi Response
         axiSlaveReadResponse(v.axiReadSlave, axiReadResp);
      end if;

      -- Synchronous Reset
      if axiRst = '1' then
         v := LOC_REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rinAxiLite <= v;

      -- Outputs
      axiReadSlave  <= rAxiLite.axiReadSlave;
      axiWriteSlave <= rAxiLite.axiWriteSlave;

   end process combAxiLite;

   seqAxiLite : process (axiClk) is
   begin
      if rising_edge(axiClk) then
         rAxiLite <= rinAxiLite after TPD_G;
      end if;
   end process seqAxiLite;

end rtl;
