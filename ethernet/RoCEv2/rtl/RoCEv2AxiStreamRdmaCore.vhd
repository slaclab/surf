-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: RoCEv2 AXI-Stream RDMA host-logic core.
--
--   The RoCEv2 host interface for an RDMA-SEND-with-immediate datapath with
--   NATIVE FW<->NIC flow control (no software credit register in the real-time
--   path). Five cooperating blocks plus a register file:
--
--     * FIFO        : store-and-forward buffering of the inbound PRBS payload
--                     (whole tLast-delimited packets) in the roceClk domain.
--     * FILL        : copy each complete packet from the FIFO into an addressable
--                     REPLAY RAM slot (a bounded ring). Gated on a free slot.
--     * SERVE       : on each engine DMA-read, REPLAY the addressed slot (indexed
--                     by wr_id) into the 290-bit RoceDmaReadResp. READ-ONLY, so a
--                     blue-rdma RNR/timeout RETRY (which re-issues the DMA read for
--                     the same wr_id) re-reads identical bytes -- the property the
--                     old one-shot streaming source lacked.
--     * DISPATCH    : issue one RDMA-SEND-with-immediate work request per filled
--                     slot while DispatchEnable=1 (id = the slot's monotonic count).
--     * COMPLETION  : count success/unsuccess work completions AND free the oldest
--                     slot (freePtr++) per completion. RC completions are in-order;
--                     with infinite rnr_retry a SEND completes only once the host
--                     had a posted recv-WR, so freeing is intrinsically host-
--                     consume-paced. "No free slot -> FILL stalls -> FIFO fills ->
--                     PRBS source backpressured" is the FW-internal, ACK-driven,
--                     SW-free flow-control loop.
--     * REG FILE    : ONE AXI-Lite slave exposing the register map (offset 0x000).
--
--   The work/DMA/comp records are exposed as ports so this core can be verified in
--   isolation (the RoCEv2Engine is instantiated by the RoCEv2AxiStreamRdma wrapper
--   that connects them to the UDP datapath).
-------------------------------------------------------------------------------
-- This file is part of 'Simple-10GbE-RUDP-KCU105-Example'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'Simple-10GbE-RUDP-KCU105-Example', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

-- numeric_std ONLY: do NOT add ieee.std_logic_unsigned or ieee.std_logic_arith.
-- All arithmetic uses explicit numeric_std unsigned()/to_unsigned() conversions.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;
use surf.AxiLitePkg.all;
use surf.RoCEv2Pkg.all;

entity RoCEv2AxiStreamRdmaCore is
   generic (
      TPD_G                   : time               := 1 ns;       -- simulation propagation delay
      RST_ASYNC_G             : boolean            := false;      -- true = asynchronous reset
      AXIS_CONFIG_G           : AxiStreamConfigType;              -- inbound payload stream config
      RING_SLOTS_G            : positive           := 16;         -- replay-ring SEND slots; power of 2, >= SQ depth (see sizing constants)
      ROCE_CLK_FREQ_G         : real               := 156.25E+6;  -- roceClk freq (Hz) for AxiStreamMon counters
      DISPATCH_COUNTER_BITS_G : positive           := 24);        -- monotonic pointer / counter width
   port (
      roceClk           : in  sl;
      roceRst           : in  sl;
      -- Inbound AXI-Stream payload
      sAxisMaster       : in  AxiStreamMasterType;
      sAxisSlave        : out AxiStreamSlaveType;
      -- Work Requests (module -> engine)
      workReqMaster     : out RoCEv2WorkReqMasterType;
      workReqSlave      : in  RoCEv2WorkReqSlaveType;
      -- Work Completions (engine -> module)
      workCompMaster    : in  RoCEv2WorkCompMasterType;
      workCompSlave     : out RoCEv2WorkCompSlaveType;
      -- DMA read request (engine -> module)
      dmaReadReqMaster  : in  RoCEv2DmaReadReqMasterType;
      dmaReadReqSlave   : out RoCEv2DmaReadReqSlaveType;
      -- DMA read response (module -> engine)
      dmaReadRespMaster : out RoCEv2DmaReadRespMasterType;
      dmaReadRespSlave  : in  RoCEv2DmaReadRespSlaveType;
      -- AXI-Lite slave (single merged register file)
      axilReadMaster    : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave     : out AxiLiteReadSlaveType;
      axilWriteMaster   : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave    : out AxiLiteWriteSlaveType);
end entity RoCEv2AxiStreamRdmaCore;

architecture rtl of RoCEv2AxiStreamRdmaCore is

   -- Internal 32-byte RoCEv2 SSI config (FIFO master / FILL drain side).
   constant AXIS_CONFIG_C : AxiStreamConfigType :=
      ssiAxiStreamConfig(
         dataBytes => TDATA_ROCE_NUM_BYTES_C,
         tKeepMode => TKEEP_NORMAL_C,
         tDestBits => 0);

   ----------------------------------------------------------------------------
   -- Replay-ring sizing constants.
   --
   -- The per-SEND payload cap is a HARDWARE fact, not a software knob: each SEND
   -- must fit one replay slot (whole-slot replay re-reads it intact on an RNR/
   -- timeout retry), and the slot is one PMTU = MAX_BEATS_C*32 = 4096 bytes. So
   -- MAX_BEATS_C is a constant (not a generic) -- an instantiator must not be able
   -- to pick a value that crosses into multi-packet SENDs or overruns the engine's
   -- 13-bit DMA-read len field (see the assert below). The actual SEND length is
   -- measured per packet from the inbound tLast (FILL.slotLen), so software never
   -- programs it.
   ----------------------------------------------------------------------------
   constant MAX_BEATS_C       : positive := 128;  -- 32-byte beats per replay slot
   constant MAX_FRAME_BYTES_C : positive := MAX_BEATS_C*32;  -- per-SEND byte cap (one PMTU)
   constant SLOT_BITS_C       : positive := log2(RING_SLOTS_G);  -- slot index width
   constant BEAT_BITS_C       : positive := log2(MAX_BEATS_C);  -- beat index width
   constant RAM_ADDR_W_C      : positive := SLOT_BITS_C + BEAT_BITS_C;
   constant RAM_DATA_W_C      : positive := 256 + 32;        -- tData & tKeep
   constant PTR_W_C           : positive := DISPATCH_COUNTER_BITS_G;  -- monotonic ptr width
   -- Drained-byte accumulator width: len is 13-bit (<=8191); 14 bits holds the
   -- accumulated count without overflow when a final 32-byte beat is added.
   constant REP_BYTE_CNT_W_C  : positive := 14;

   -- Per-slot last-beat-index (beats-1) and error flag, written by FILL, read by SERVE.
   type SlotIdxArray is array (0 to RING_SLOTS_G-1) of slv(BEAT_BITS_C-1 downto 0);

   -- Per-slot SEND byte length, measured from the inbound tLast by FILL and consumed
   -- by DISPATCH (workReq.len). This is what makes the SEND length dynamic: software
   -- never programs it; the FW frames each packet from the stream.
   type SlotLenArray is array (0 to RING_SLOTS_G-1) of slv(REP_BYTE_CNT_W_C-1 downto 0);

   ----------------------------------------------------------------------------
   -- Block REG/COMPLETION record: AXI-Lite config + completion counters + the
   -- freePtr (slot-reclaim pointer advanced one-per-completion).
   ----------------------------------------------------------------------------
   type CompStateType is (ST0_IDLE, ST1_RECEIVED);

   type RegType is record
      -- Dispatch control
      dispatchEnable   : sl;
      rKey             : slv(31 downto 0);
      lKey             : slv(31 downto 0);
      sQpn             : slv(23 downto 0);
      dQpn             : slv(24 downto 0);
      rAddr            : slv(63 downto 0);
      addrWrapCount    : slv(31 downto 0);
      -- Completion control / status
      resetCounters    : sl;
      successCounter   : slv(DISPATCH_COUNTER_BITS_G-1 downto 0);
      unsuccessCounter : slv(DISPATCH_COUNTER_BITS_G-1 downto 0);
      compState        : CompStateType;
      status           : slv(4 downto 0);
      workCompSlave    : RoCEv2WorkCompSlaveType;
      -- Slot-reclaim pointer (oldest un-freed slot). Advanced one-per-completion.
      freePtr          : slv(PTR_W_C-1 downto 0);
      -- AXI-Lite slave outputs
      axilReadSlave    : AxiLiteReadSlaveType;
      axilWriteSlave   : AxiLiteWriteSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      dispatchEnable   => '0',
      rKey             => (others => '0'),
      lKey             => (others => '0'),
      sQpn             => (others => '0'),
      dQpn             => (others => '0'),
      rAddr            => (others => '0'),
      addrWrapCount    => (others => '0'),
      resetCounters    => '0',
      successCounter   => (others => '0'),
      unsuccessCounter => (others => '0'),
      compState        => ST0_IDLE,
      status           => (others => '0'),
      workCompSlave    => ROCE_WORK_COMP_SLAVE_INIT_C,
      freePtr          => (others => '0'),
      axilReadSlave    => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave   => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- Inbound FIFO drain interface.
   signal fifoMaster   : AxiStreamMasterType;
   signal fifoSlave    : AxiStreamSlaveType;
   signal fifoRst      : sl;
   -- FIFO slave (entity boundary) before the disarm-drain override.
   signal fifoSAxisSlave : AxiStreamSlaveType;

   -- AxiStreamMon status outputs (roceClk domain; statusClk = axisClk = roceClk).
   signal monFrameCnt     : slv(63 downto 0);
   signal monFrameSize    : slv(31 downto 0);
   signal monFrameSizeMax : slv(31 downto 0);
   signal monFrameSizeMin : slv(31 downto 0);
   signal monFrameRate    : slv(31 downto 0);
   signal monFrameRateMax : slv(31 downto 0);
   signal monFrameRateMin : slv(31 downto 0);
   signal monBandwidth    : slv(63 downto 0);
   signal monBandwidthMax : slv(63 downto 0);
   signal monBandwidthMin : slv(63 downto 0);
   -- AxiStreamMon reset: roceRst OR a ResetCounters write, so ResetCounters clears
   -- the monitor statistics (frameCnt + all min/max) alongside the FW counters.
   signal monRst          : sl;

   ----------------------------------------------------------------------------
   -- FILL FSM record: drains a complete packet from the FIFO into a replay-RAM
   -- slot, records its last-beat-index + length, then advances fillPtr. An OVER-CAP
   -- packet (> MAX_FRAME_BYTES_C, no tLast within the slot) is DROPPED in F_DROP:
   -- its tail is flushed and the slot is NOT published (fillPtr unchanged), so no
   -- errored SEND is dispatched -- an isRespErr SEND would put the blue-rdma SQ into
   -- its ERROR state, which only a QP reset (SW) clears. Dropping keeps the SQ healthy
   -- so the datapath self-heals once the frame size returns to <= the cap.
   ----------------------------------------------------------------------------
   type FillStateType is (F_IDLE, F_DRAIN, F_DROP, F_DONE);

   type FillRegType is record
      state         : FillStateType;
      fillPtr       : slv(PTR_W_C-1 downto 0);
      beatIdx       : unsigned(BEAT_BITS_C-1 downto 0);
      drainedBytes  : unsigned(REP_BYTE_CNT_W_C-1 downto 0);
      slotErrAcc    : sl;
      -- count of over-cap packets dropped (reset by ResetCounters), exposed RO
      oversizeCount : slv(DISPATCH_COUNTER_BITS_G-1 downto 0);
      -- registered replay-RAM write port (port A)
      wea           : sl;
      addra         : slv(RAM_ADDR_W_C-1 downto 0);
      dina          : slv(RAM_DATA_W_C-1 downto 0);
      -- per-slot metadata (lastIdx/slotErr read by SERVE; slotLen read by DISPATCH)
      lastIdx       : SlotIdxArray;
      slotLen       : SlotLenArray;
      slotErr       : slv(RING_SLOTS_G-1 downto 0);
      fifoSlave     : AxiStreamSlaveType;
   end record FillRegType;

   constant FILL_INIT_C : FillRegType := (
      state         => F_IDLE,
      fillPtr       => (others => '0'),
      beatIdx       => (others => '0'),
      drainedBytes  => (others => '0'),
      slotErrAcc    => '0',
      oversizeCount => (others => '0'),
      wea           => '0',
      addra         => (others => '0'),
      dina          => (others => '0'),
      lastIdx       => (others => (others => '0')),
      slotLen       => (others => (others => '0')),
      slotErr       => (others => '0'),
      fifoSlave     => AXI_STREAM_SLAVE_FORCE_C);  -- drop data when dispatchEnable=0

   signal fillR   : FillRegType := FILL_INIT_C;
   signal fillRin : FillRegType;

   ----------------------------------------------------------------------------
   -- SERVE FSM record: replays the wr_id-addressed slot into the DMA-read resp.
   ----------------------------------------------------------------------------
   type ServeStateType is (S_IDLE, S_READ, S_PRES);

   type ServeRegType is record
      state             : ServeStateType;
      slot              : unsigned(SLOT_BITS_C-1 downto 0);
      idx               : unsigned(BEAT_BITS_C-1 downto 0);
      lastIdx           : unsigned(BEAT_BITS_C-1 downto 0);
      slotErrLatched    : sl;
      reqInit           : slv(3 downto 0);
      reqSqpn           : slv(23 downto 0);
      reqWrId           : slv(63 downto 0);
      -- Diagnostic: count of DMA-read requests accepted (one per SEND TRANSMISSION,
      -- original or retransmit). Compared to SuccessCounter (one per COMPLETION) it
      -- exposes retransmits: dmaReadCnt ~= 2*successCounter => each SEND emitted twice.
      dmaReadCnt        : slv(DISPATCH_COUNTER_BITS_G-1 downto 0);
      dmaReadReqSlave   : RoCEv2DmaReadReqSlaveType;
      dmaReadRespMaster : RoCEv2DmaReadRespMasterType;
   end record ServeRegType;

   constant SERVE_INIT_C : ServeRegType := (
      state             => S_IDLE,
      slot              => (others => '0'),
      idx               => (others => '0'),
      lastIdx           => (others => '0'),
      slotErrLatched    => '0',
      reqInit           => (others => '0'),
      reqSqpn           => (others => '0'),
      reqWrId           => (others => '0'),
      dmaReadCnt        => (others => '0'),
      dmaReadReqSlave   => ROCE_DMA_READ_REQ_SLAVE_INIT_C,
      dmaReadRespMaster => ROCE_DMA_READ_RESP_MASTER_INIT_C);

   signal servR   : ServeRegType := SERVE_INIT_C;
   signal servRin : ServeRegType;

   -- Replay RAM read port (port B).
   signal ramAddrb : slv(RAM_ADDR_W_C-1 downto 0) := (others => '0');
   signal ramDoutb : slv(RAM_DATA_W_C-1 downto 0);

   ----------------------------------------------------------------------------
   -- DISPATCH FSM record: issues one SEND-with-immediate per filled slot.
   ----------------------------------------------------------------------------
   type DispStateType is (ST0_IDLE, ST1_SENDING);

   type DispRegType is record
      state     : DispStateType;
      sendPtr   : slv(PTR_W_C-1 downto 0);
      addrCount : slv(DISPATCH_COUNTER_BITS_G-1 downto 0);
      txMaster  : RoCEv2WorkReqMasterType;
   end record DispRegType;

   constant DISP_INIT_C : DispRegType := (
      state     => ST0_IDLE,
      sendPtr   => (others => '0'),
      addrCount => (others => '0'),
      txMaster  => ROCE_WORK_REQ_MASTER_INIT_C);

   signal dispR   : DispRegType := DISP_INIT_C;
   signal dispRin : DispRegType;

begin  -- architecture rtl

   -- RING_SLOTS_G must be a power of 2 so slot = monotonic-ptr mod N is just the
   -- low SLOT_BITS_C bits (and >= the SQ pending depth so the ring retains every
   -- un-ACKed slot for retransmission).
   assert (RING_SLOTS_G = 2**SLOT_BITS_C)
      report "RoCEv2AxiStreamRdmaCore: RING_SLOTS_G must be a power of 2"
      severity failure;

   -- A slot holds one whole SEND payload, served intact on every (re)transmission.
   -- The engine's DMA-read len field is 13 bits, so the slot capacity (the per-SEND
   -- byte cap) must fit it. Compile-time guard on the constants -- if MAX_BEATS_C is
   -- ever raised past this, the SEND would be multi-packet (whole-slot-from-0 replay
   -- of a partial-PSN retransmit is unproven) AND/OR overrun the len field.
   assert (MAX_FRAME_BYTES_C <= 2**13-1)
      report "RoCEv2AxiStreamRdmaCore: MAX_BEATS_C*32 exceeds the engine 13-bit DMA-read len cap"
      severity failure;

   ----------------------------------------------------------------------------
   -- Inbound store-and-forward FIFO (whole-packet buffering). Master side
   -- asserts tValid only on a COMPLETE tLast-delimited packet. Flushed whenever
   -- DispatchEnable=0 so no stale/partial packet survives a stop/restart.
   ----------------------------------------------------------------------------
   fifoRst <= roceRst or (not r.dispatchEnable);

   U_RepackFifo : entity surf.AxiStreamFifoV2
      generic map (
         TPD_G               => TPD_G,
         GEN_SYNC_FIFO_G     => true,
         VALID_THOLD_G       => 0,      -- store-and-forward (whole packet)
         INT_WIDTH_SELECT_G  => "CUSTOM",
         INT_DATA_WIDTH_G    => TDATA_ROCE_NUM_BYTES_C,  -- 32-byte RoCEv2 internal width
         FIFO_ADDR_WIDTH_G   => 9,
         SLAVE_AXI_CONFIG_G  => AXIS_CONFIG_G,
         MASTER_AXI_CONFIG_G => AXIS_CONFIG_C)
      port map (
         sAxisClk    => roceClk,
         sAxisRst    => fifoRst,
         sAxisMaster => sAxisMaster,
         sAxisSlave  => fifoSAxisSlave,
         mAxisClk    => roceClk,
         mAxisRst    => fifoRst,
         mAxisMaster => fifoMaster,
         mAxisSlave  => fifoSlave);

   -- When disarmed (dispatchEnable=0) the FIFO is held in reset and would deassert
   -- tReady, STALLING the upstream pipeline. Force tReady high instead so upstream
   -- beats DRAIN (and are dropped by the reset FIFO) rather than back-pressuring a
   -- stalled source. Armed => normal FIFO backpressure.
   sAxisSlave <= AXI_STREAM_SLAVE_FORCE_C when (r.dispatchEnable = '0') else fifoSAxisSlave;

   ----------------------------------------------------------------------------
   -- AxiStreamMon: monitor the FIFO drain stream (fifoMaster/fifoSlave) - frame
   -- count/size/rate/bandwidth of the PRBS packets drained into the replay ring.
   -- Single clock (statusClk = axisClk = roceClk => COMMON_CLK_G=true); the status
   -- outputs are exposed read-only on the merged AXI-Lite map (regComb, 0x200+).
   -- A ResetCounters write (0x108) clears the monitor stats with the FW counters.
   ----------------------------------------------------------------------------
   monRst <= roceRst or r.resetCounters;

   U_AxiStreamMon : entity surf.AxiStreamMon
      generic map (
         TPD_G           => TPD_G,
         RST_ASYNC_G     => RST_ASYNC_G,
         COMMON_CLK_G    => true,
         AXIS_CLK_FREQ_G => ROCE_CLK_FREQ_G,
         AXIS_CONFIG_G   => AXIS_CONFIG_C)
      port map (
         -- Monitored AXIS stream (FIFO drain into FILL)
         axisClk      => roceClk,
         axisRst      => monRst,
         axisMaster   => fifoMaster,
         axisSlave    => fifoSlave,
         -- Status readout (same clock domain)
         statusClk    => roceClk,
         statusRst    => monRst,
         frameCnt     => monFrameCnt,
         frameSize    => monFrameSize,
         frameSizeMax => monFrameSizeMax,
         frameSizeMin => monFrameSizeMin,
         frameRate    => monFrameRate,
         frameRateMax => monFrameRateMax,
         frameRateMin => monFrameRateMin,
         bandwidth    => monBandwidth,
         bandwidthMax => monBandwidthMax,
         bandwidthMin => monBandwidthMin);

   ----------------------------------------------------------------------------
   -- Replay RAM: one beat per entry = {tData[255:0], tKeep[31:0]}. Port A write
   -- (FILL), port B read (SERVE). 1-cycle registered read (DOB_REG_G=false).
   -- Addressed by slot*MAX_BEATS_C + beat (SLOT_BITS_C+BEAT_BITS_C concatenation).
   ----------------------------------------------------------------------------
   U_ReplayRam : entity surf.SimpleDualPortRam
      generic map (
         TPD_G         => TPD_G,
         RST_ASYNC_G   => RST_ASYNC_G,
         MEMORY_TYPE_G => "block",
         DOB_REG_G     => false,
         DATA_WIDTH_G  => RAM_DATA_W_C,
         ADDR_WIDTH_G  => RAM_ADDR_W_C)
      port map (
         -- Port A (write, FILL)
         clka  => roceClk,
         wea   => fillR.wea,
         addra => fillR.addra,
         dina  => fillR.dina,
         -- Port B (read, SERVE)
         clkb  => roceClk,
         addrb => ramAddrb,
         doutb => ramDoutb);

   -- SERVE drives the read address combinationally from its registered slot/idx,
   -- so doutb reflects {slot,idx} one cycle later (consumed in S_PRES).
   ramAddrb <= std_logic_vector(servR.slot) & std_logic_vector(servR.idx);

   ----------------------------------------------------------------------------
   -- Merged AXI-Lite register file + COMPLETION FSM (single driver of the
   -- success/unsuccess counters AND freePtr).
   --
   --   Offset  Bits    Access  Name              Field
   --   0x00    [0]     RW      DispatchEnable    dispatchEnable (level; arms auto-dispatch)
   --   0x04    [31:0]  RO      MaxSize           MAX_FRAME_BYTES_C (FW-constant per-SEND byte cap)
   --   0x08    [31:0]  RW      RKey              rKey   (unused by SEND; legacy RETH)
   --   0x0C    [31:0]  RW      LKey              lKey
   --   0x10    [23:0]  RW      SQpn              sQpn
   --   0x14    [24:0]  RW      DQpn              dQpn   (UD field; unused by RC SEND)
   --   0x18    [63:0]  RW      RemAddr           rAddr  (unused by SEND; legacy RETH)
   --   0x20    [31:0]  RW      AddrWrapCount     addrWrapCount  (wraps the immDt slot field)
   --   0x100   [N:0]   RO      SuccessCounter    successCounter
   --   0x104   [N:0]   RO      UnsuccessCounter  unsuccessCounter
   --   0x108   [0]     RW      ResetCounters     resetCounters
   --   0x10C   [N:0]   RO      OversizeCount     fillR.oversizeCount (over-cap frames dropped)
   --   AxiStreamMon status (RO) of the FIFO drain stream (fifoMaster/fifoSlave):
   --   0x200   [63:0]  RO      MonFrameCnt       monFrameCnt    (0x200/0x204)
   --   0x208   [31:0]  RO      MonFrameRate      monFrameRate    (Hz)
   --   0x20C   [31:0]  RO      MonFrameRateMax   monFrameRateMax (Hz)
   --   0x210   [31:0]  RO      MonFrameRateMin   monFrameRateMin (Hz)
   --   0x214   [63:0]  RO      MonBandwidth      monBandwidth    (Byte/s, 0x214/0x218)
   --   0x21C   [63:0]  RO      MonBandwidthMax   monBandwidthMax (Byte/s, 0x21C/0x220)
   --   0x224   [63:0]  RO      MonBandwidthMin   monBandwidthMin (Byte/s, 0x224/0x228)
   --   0x22C   [31:0]  RO      MonFrameSize      monFrameSize    (Byte)
   --   0x230   [31:0]  RO      MonFrameSizeMax   monFrameSizeMax (Byte)
   --   0x234   [31:0]  RO      MonFrameSizeMin   monFrameSizeMin (Byte)
   ----------------------------------------------------------------------------
   regComb : process (axilReadMaster, axilWriteMaster, fillR, monBandwidth,
                      monBandwidthMax, monBandwidthMin, monFrameCnt,
                      monFrameRate, monFrameRateMax, monFrameRateMin,
                      monFrameSize, monFrameSizeMax, monFrameSizeMin, r, servR,
                      workCompMaster) is
      variable v      : RegType;
      variable regCon : AxiLiteEndPointType;
   begin
      v := r;

      axiSlaveWaitTxn(regCon, axilWriteMaster, axilReadMaster,
                      v.axilWriteSlave, v.axilReadSlave);

      axiSlaveRegister (regCon, x"000", 0, v.dispatchEnable);
      axiSlaveRegisterR(regCon, x"004", 0, toSlv(MAX_FRAME_BYTES_C, 32));  -- RO: FW-constant per-SEND cap
      axiSlaveRegister (regCon, x"008", 0, v.rKey);
      axiSlaveRegister (regCon, x"00C", 0, v.lKey);
      axiSlaveRegister (regCon, x"010", 0, v.sQpn);
      axiSlaveRegister (regCon, x"014", 0, v.dQpn);
      axiSlaveRegister (regCon, x"018", 0, v.rAddr);  -- 64-bit: occupies 0x18/0x1C
      axiSlaveRegister (regCon, x"020", 0, v.addrWrapCount);

      axiSlaveRegisterR(regCon, x"100", 0, r.successCounter);
      axiSlaveRegisterR(regCon, x"104", 0, r.unsuccessCounter);
      axiSlaveRegister (regCon, x"108", 0, v.resetCounters);
      axiSlaveRegisterR(regCon, x"10C", 0, fillR.oversizeCount);  -- RO: over-cap frames dropped
      axiSlaveRegisterR(regCon, x"110", 0, servR.dmaReadCnt);  -- RO: SEND transmissions (incl. retransmits)

      -- AxiStreamMon throughput status (RO) of the FIFO drain stream.
      axiSlaveRegisterR(regCon, x"200", 0, monFrameCnt);  -- 64-bit: 0x200/0x204
      axiSlaveRegisterR(regCon, x"208", 0, monFrameRate);
      axiSlaveRegisterR(regCon, x"20C", 0, monFrameRateMax);
      axiSlaveRegisterR(regCon, x"210", 0, monFrameRateMin);
      axiSlaveRegisterR(regCon, x"214", 0, monBandwidth);  -- 64-bit: 0x214/0x218
      axiSlaveRegisterR(regCon, x"21C", 0, monBandwidthMax);  -- 64-bit: 0x21C/0x220
      axiSlaveRegisterR(regCon, x"224", 0, monBandwidthMin);  -- 64-bit: 0x224/0x228
      axiSlaveRegisterR(regCon, x"22C", 0, monFrameSize);
      axiSlaveRegisterR(regCon, x"230", 0, monFrameSizeMax);
      axiSlaveRegisterR(regCon, x"234", 0, monFrameSizeMin);

      axiSlaveDefault(regCon, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);

      axilWriteSlave <= r.axilWriteSlave;
      axilReadSlave  <= r.axilReadSlave;

      ------------------------------------------------------------------------
      -- COMPLETION FSM: count success/unsuccess AND free the oldest slot.
      -- status "00000" = success. RC completions are in-order, so freePtr++ per
      -- completion releases slots oldest-first (matches the dispatch order).
      ------------------------------------------------------------------------
      v.workCompSlave.ready := '0';

      if r.resetCounters = '1' then
         v.successCounter   := (others => '0');
         v.unsuccessCounter := (others => '0');
      end if;

      case r.compState is
         when ST0_IDLE =>
            if workCompMaster.valid = '1' then
               v.workCompSlave.ready := '1';
               v.status              := workCompMaster.status;
               v.compState           := ST1_RECEIVED;
            end if;
         when ST1_RECEIVED =>
            if r.status = "00000" then
               v.successCounter := std_logic_vector(unsigned(r.successCounter) + 1);
            else
               v.unsuccessCounter := std_logic_vector(unsigned(r.unsuccessCounter) + 1);
            end if;
            -- Free the oldest in-flight slot (ACK-paced flow control).
            v.freePtr   := std_logic_vector(unsigned(r.freePtr) + 1);
            v.compState := ST0_IDLE;
         when others =>
            v.compState := ST0_IDLE;
      end case;

      -- Clean re-arm: clearing DispatchEnable zeroes the completion FSM + freePtr
      -- (paired with FILL/DISPATCH self-reset) so a stop/restart starts coherent.
      if r.dispatchEnable = '0' then
         v.compState        := ST0_IDLE;
         v.freePtr          := (others => '0');
         v.successCounter   := (others => '0');
         v.unsuccessCounter := (others => '0');
      end if;

      workCompSlave <= v.workCompSlave;

      rin <= v;
   end process regComb;

   seq : process (roceClk, roceRst) is
   begin
      if (RST_ASYNC_G) and (roceRst = '1') then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(roceClk) then
         if (RST_ASYNC_G = false) and (roceRst = '1') then
            r <= REG_INIT_C after TPD_G;
         else
            r <= rin after TPD_G;
         end if;
      end if;
   end process seq;

   ----------------------------------------------------------------------------
   -- FILL FSM: drain one complete FIFO packet into replay-RAM slot fillPtr, then
   -- advance fillPtr. Gated on a FREE slot: occupancy = fillPtr - freePtr < N.
   -- Stalling here (ring full) backpressures the PRBS source via the FIFO.
   ----------------------------------------------------------------------------
   fillComb : process (fifoMaster, fillR, r) is
      variable v         : FillRegType;
      variable slotInt   : integer range 0 to RING_SLOTS_G-1;
      variable occupancy : unsigned(PTR_W_C-1 downto 0);
      variable beatBytes : unsigned(REP_BYTE_CNT_W_C-1 downto 0);
      variable fullBeat  : boolean;
   begin
      v := fillR;

      v.wea              := '0';
      v.fifoSlave.tReady := '0';

      slotInt   := to_integer(unsigned(fillR.fillPtr(SLOT_BITS_C-1 downto 0)));
      occupancy := unsigned(fillR.fillPtr) - unsigned(r.freePtr);
      beatBytes := to_unsigned(getTKeep(fifoMaster.tKeep, AXIS_CONFIG_C), REP_BYTE_CNT_W_C);
      fullBeat  := (fifoMaster.tKeep(31 downto 0) = x"FFFFFFFF");

      case fillR.state is

         when F_IDLE =>
            v.beatIdx      := (others => '0');
            v.drainedBytes := (others => '0');
            v.slotErrAcc   := '0';
            -- Start only when armed, a whole packet is buffered, and a slot is free.
            if (r.dispatchEnable = '1') and (fifoMaster.tValid = '1') and
               (occupancy < to_unsigned(RING_SLOTS_G, PTR_W_C)) then
               v.state := F_DRAIN;
            end if;

         when F_DRAIN =>
            if fifoMaster.tValid = '1' then
               -- Consume the beat and register its write into the slot.
               v.fifoSlave.tReady := '1';
               v.wea              := '1';
               v.addra            := fillR.fillPtr(SLOT_BITS_C-1 downto 0) &
                          std_logic_vector(fillR.beatIdx);
               v.dina         := fifoMaster.tData(255 downto 0) & fifoMaster.tKeep(31 downto 0);
               v.drainedBytes := fillR.drainedBytes + resize(beatBytes, REP_BYTE_CNT_W_C);
               -- A partial (non-full) beat BEFORE tLast is genuine misframing -> flag it.
               -- The FINAL beat is allowed to be partial (a frame need not be a 32-byte
               -- multiple): SERVE bitReverses byteEn so the partial beat's valid bytes,
               -- which endianSwap moves to the high lanes, are marked correctly.
               if (not fullBeat) and (fifoMaster.tLast = '0') then
                  v.slotErrAcc := '1';
               end if;

               if fifoMaster.tLast = '1' then
                  -- Normal termination: the inbound tLast frames the packet. Record the
                  -- MEASURED byte length (bytes drained so far + this final beat) and the
                  -- last-beat index, then commit in F_DONE. DISPATCH uses this slotLen as
                  -- the SEND length -- no software-programmed size is involved.
                  v.lastIdx(slotInt) := std_logic_vector(fillR.beatIdx);
                  v.slotLen(slotInt) := std_logic_vector(
                     fillR.drainedBytes + resize(beatBytes, REP_BYTE_CNT_W_C));
                  v.slotErr(slotInt) := fillR.slotErrAcc or
                                        ssiGetUserEofe(AXIS_CONFIG_C, fifoMaster);
                  v.state := F_DONE;
               elsif fillR.beatIdx = to_unsigned(MAX_BEATS_C-1, BEAT_BITS_C) then
                  -- Over-cap: the packet hit the per-SEND cap (MAX_FRAME_BYTES_C) with no
                  -- tLast (PacketLength > the FW cap). DROP it -- count it and flush the
                  -- tail in F_DROP WITHOUT publishing the slot. Dispatching it with
                  -- isRespErr would put the blue-rdma SQ into its ERROR state (only a QP
                  -- reset clears it); dropping keeps the SQ healthy so the datapath
                  -- self-heals once the frame size returns to <= the cap.
                  v.oversizeCount := std_logic_vector(unsigned(fillR.oversizeCount) + 1);
                  v.state         := F_DROP;
               else
                  v.beatIdx := fillR.beatIdx + 1;
               end if;
            end if;

         when F_DROP =>
            -- Consume (without storing) the tail of an OVER-CAP packet until tLast, then
            -- return to F_IDLE WITHOUT publishing the slot (fillPtr unchanged). The
            -- partially-written slot is discarded and reused by the next packet; no SEND
            -- is dispatched for it, so the SQ is never poisoned and the path self-heals.
            if fifoMaster.tValid = '1' then
               v.fifoSlave.tReady := '1';
               if fifoMaster.tLast = '1' then
                  v.state := F_IDLE;
               end if;
            end if;

         when F_DONE =>
            -- The last beat's registered RAM write commits this cycle; only NOW
            -- publish the slot (fillPtr++) so SERVE can never read a half-written slot.
            v.fillPtr := std_logic_vector(unsigned(fillR.fillPtr) + 1);
            v.state   := F_IDLE;

         when others =>
            v := FILL_INIT_C;

      end case;

      -- Clean re-arm on disarm.
      if r.dispatchEnable = '0' then
         v := FILL_INIT_C;
      end if;

      -- ResetCounters (0x108) also clears the oversize-drop counter, mirroring the
      -- FW Success/Unsuccess counters cleared in regComb.
      if r.resetCounters = '1' then
         v.oversizeCount := (others => '0');
      end if;

      fifoSlave <= v.fifoSlave;

      fillRin <= v;
   end process fillComb;

   fillSeq : process (roceClk, roceRst) is
   begin
      if (RST_ASYNC_G) and (roceRst = '1') then
         fillR <= FILL_INIT_C after TPD_G;
      elsif rising_edge(roceClk) then
         if (RST_ASYNC_G = false) and (roceRst = '1') then
            fillR <= FILL_INIT_C after TPD_G;
         else
            fillR <= fillRin after TPD_G;
         end if;
      end if;
   end process fillSeq;

   ----------------------------------------------------------------------------
   -- SERVE FSM: on each engine DMA-read, REPLAY the wr_id-addressed slot. The
   -- slot = wrId mod N (low SLOT_BITS_C bits of the WR id the dispatcher stamped).
   -- READ-ONLY: a blue-rdma RNR/timeout retry re-issues the DMA read for the same
   -- wr_id and re-reads identical bytes. 2 cycles/beat (>= line-rate at roceClk).
   ----------------------------------------------------------------------------
   serveComb : process (dmaReadReqMaster, dmaReadRespSlave, fillR, r, ramDoutb,
                        servR) is
      variable v       : ServeRegType;
      variable slotInt : integer range 0 to RING_SLOTS_G-1;
      variable isFirst : sl;
      variable isLast  : sl;
   begin
      v := servR;

      v.dmaReadReqSlave.ready := '0';

      -- De-assert the response valid once the engine has accepted the beat.
      if dmaReadRespSlave.ready = '1' then
         v.dmaReadRespMaster.valid := '0';
      end if;

      slotInt := to_integer(unsigned(dmaReadReqMaster.wrId(SLOT_BITS_C-1 downto 0)));

      case servR.state is

         when S_IDLE =>
            if dmaReadReqMaster.valid = '1' then
               -- Accept the request and latch its echo fields + the addressed slot.
               v.dmaReadReqSlave.ready := '1';
               v.reqInit               := dmaReadReqMaster.initiator;
               v.reqSqpn               := dmaReadReqMaster.sQpn;
               v.reqWrId               := dmaReadReqMaster.wrId;
               v.slot                  := unsigned(dmaReadReqMaster.wrId(SLOT_BITS_C-1 downto 0));
               v.idx                   := (others => '0');
               v.lastIdx               := unsigned(fillR.lastIdx(slotInt));
               v.slotErrLatched        := fillR.slotErr(slotInt);
               -- Diagnostic: one DMA-read accepted == one SEND transmission (incl. retransmit).
               v.dmaReadCnt            := std_logic_vector(unsigned(servR.dmaReadCnt) + 1);
               v.state                 := S_READ;
            end if;

         when S_READ =>
            -- Address (slot&idx) is driven combinationally; doutb is valid next
            -- cycle (S_PRES). One settle cycle per beat.
            v.state := S_PRES;

         when S_PRES =>
            -- Present the current beat when the response slot is free.
            if v.dmaReadRespMaster.valid = '0' then
               isFirst := ite(servR.idx = 0, '1', '0');
               isLast  := ite(servR.idx = servR.lastIdx, '1', '0');

               -- 290-bit pack: endianSwap(data) & byteEn & isFirst & isLast.
               -- endianSwap reverses the 32 byte lanes, so a partial final beat's valid
               -- bytes (stored in the low lanes) move to the high lanes. bitReverse the
               -- byteEn (tKeep) so the valid-byte marks track the swapped data. Full beats
               -- (tKeep = x"FFFFFFFF") are unchanged by bitReverse, so this is a no-op for
               -- every 32-byte-multiple frame and only fixes the partial-final-beat case.
               v.dmaReadRespMaster.dataStream :=
                  endianSwap(ramDoutb(RAM_DATA_W_C-1 downto 32)) &
                  bitReverse(ramDoutb(31 downto 0)) &
                  isFirst &
                  isLast;
               v.dmaReadRespMaster.initiator := servR.reqInit;
               v.dmaReadRespMaster.sQpn      := servR.reqSqpn;
               v.dmaReadRespMaster.wrId      := servR.reqWrId;
               -- Flag the stored error only on the last beat.
               v.dmaReadRespMaster.isRespErr := isLast and servR.slotErrLatched;
               v.dmaReadRespMaster.valid     := '1';

               if isLast = '1' then
                  v.state := S_IDLE;
               else
                  v.idx   := servR.idx + 1;
                  v.state := S_READ;
               end if;
            end if;

         when others =>
            v := SERVE_INIT_C;

      end case;

      -- Clean re-arm on disarm (drop any in-flight replay).
      if r.dispatchEnable = '0' then
         v := SERVE_INIT_C;
      end if;

      -- ResetCounters (0x108) zeroes the diagnostic DMA-read count alongside the
      -- FW Success/Unsuccess counters, without disturbing an in-flight replay.
      if r.resetCounters = '1' then
         v.dmaReadCnt := (others => '0');
      end if;

      dmaReadReqSlave   <= servR.dmaReadReqSlave;
      dmaReadRespMaster <= servR.dmaReadRespMaster;

      servRin <= v;
   end process serveComb;

   serveSeq : process (roceClk, roceRst) is
   begin
      if (RST_ASYNC_G) and (roceRst = '1') then
         servR <= SERVE_INIT_C after TPD_G;
      elsif rising_edge(roceClk) then
         if (RST_ASYNC_G = false) and (roceRst = '1') then
            servR <= SERVE_INIT_C after TPD_G;
         else
            servR <= servRin after TPD_G;
         end if;
      end if;
   end process serveSeq;

   ----------------------------------------------------------------------------
   -- DISPATCH FSM: issue one RDMA-SEND-with-immediate per FILLED, unsent slot
   -- (sendPtr /= fillPtr) while armed. The WR id = sendPtr, so SERVE recovers the
   -- slot as wrId mod N. No lockstep drain-wait: SERVE is decoupled and the
   -- engine's SQ depth bounds in-flight via workReqSlave.ready backpressure.
   --
   -- Flow control is native FW<->NIC: SEND is two-sided, so a full host recv queue
   -- makes the NIC RNR-NAK; the blue-rdma SQ stalls/retries (rnr_retry=7) and
   -- deasserts workReqSlave.ready -> dispatch holds -> FILL fills the ring -> FIFO
   -- backpressures the PRBS source. No software credit register is in the loop.
   ----------------------------------------------------------------------------
   dispComb : process (dispR, fillR, r, workReqSlave) is
      variable v         : DispRegType;
      variable idPadding : slv(63 downto DISPATCH_COUNTER_BITS_G) := (others => '0');
      variable nextAddr  : unsigned(DISPATCH_COUNTER_BITS_G-1 downto 0);
      variable sendSlot  : integer range 0 to RING_SLOTS_G-1;
   begin
      -- Slot being dispatched = sendPtr mod N (low SLOT_BITS_C bits). FILL committed
      -- this slot's metadata (slotLen/lastIdx) before fillPtr ran past sendPtr, so the
      -- per-slot length read below is valid whenever a filled, unsent slot exists.
      sendSlot := to_integer(unsigned(dispR.sendPtr(SLOT_BITS_C-1 downto 0)));
      v        := dispR;

      -- De-assert the work-request valid once the engine has accepted it.
      if workReqSlave.ready = '1' then
         v.txMaster.valid := '0';
      end if;

      case dispR.state is

         when ST0_IDLE =>
            -- A filled, unsent slot exists when fillPtr has run ahead of sendPtr.
            if (r.dispatchEnable = '1') and (fillR.fillPtr /= dispR.sendPtr) then
               v.state := ST1_SENDING;
            end if;

         when ST1_SENDING =>
            if v.txMaster.valid = '0' then
               -- WR id = the slot's monotonic count; SERVE uses wrId mod N as the slot.
               v.txMaster.id     := idPadding & dispR.sendPtr;
               v.txMaster.opCode := x"3";  -- IBV_WR_SEND_WITH_IMM (two-sided)
               v.txMaster.flags  := "00010";  -- IBV_SEND_SIGNALED (generates SQ completion)
               -- SEND has no RETH and the local payload is located by wr_id, not by
               -- address, so rAddr/rKey/lAddr are all 0 (no MR bounds check on the
               -- outbound payload read). This is what makes the NIC RNR-NAK on a full
               -- RQ and gives native FW<->NIC backpressure.
               v.txMaster.rAddr  := (others => '0');
               v.txMaster.rKey   := (others => '0');
               -- SEND length is the per-slot byte count FILL measured from tLast (dynamic;
               -- software never programs it). Bounded by MAX_FRAME_BYTES_C (one PMTU).
               v.txMaster.len := std_logic_vector(resize(unsigned(fillR.slotLen(sendSlot)),
                                                         v.txMaster.len'length));
               v.txMaster.lAddr     := (others => '0');
               v.txMaster.lKey      := r.lKey;
               v.txMaster.sQpn      := r.sQpn;
               v.txMaster.solicited := '0';
               v.txMaster.comp      := (others => '0');
               v.txMaster.swap      := (others => '0');
               -- Immediate: bits[7:0]=rogue stream channel (1); bits[8+]=free-running
               -- addrCount (diagnostic only -- the host locates the payload by the
               -- consumed recv-WR id, not this stamp).
               v.txMaster.immDt :=
                  std_logic_vector(resize(unsigned(dispR.addrCount),
                                          v.txMaster.immDt'length - 8)) & x"01";
               v.txMaster.rKeyToInv := (others => '0');
               v.txMaster.srqn      := (others => '0');
               v.txMaster.dQpn      := r.dQpn;
               v.txMaster.qKey      := (others => '0');
               v.txMaster.valid     := '1';

               -- Advance the diagnostic addrCount, wrapping at addrWrapCount.
               nextAddr := unsigned(dispR.addrCount) + 1;
               if nextAddr >= unsigned(r.addrWrapCount(DISPATCH_COUNTER_BITS_G-1 downto 0)) then
                  v.addrCount := (others => '0');
               else
                  v.addrCount := std_logic_vector(nextAddr);
               end if;

               -- Advance the slot/id counter and re-arm.
               v.sendPtr := std_logic_vector(unsigned(dispR.sendPtr) + 1);
               v.state   := ST0_IDLE;
            end if;

         when others =>
            v := DISP_INIT_C;

      end case;

      -- Clean re-arm on disarm.
      if r.dispatchEnable = '0' then
         v := DISP_INIT_C;
      end if;

      workReqMaster <= dispR.txMaster;

      dispRin <= v;
   end process dispComb;

   dispSeq : process (roceClk, roceRst) is
   begin
      if (RST_ASYNC_G) and (roceRst = '1') then
         dispR <= DISP_INIT_C after TPD_G;
      elsif rising_edge(roceClk) then
         if (RST_ASYNC_G = false) and (roceRst = '1') then
            dispR <= DISP_INIT_C after TPD_G;
         else
            dispR <= dispRin after TPD_G;
         end if;
      end if;
   end process dispSeq;

end architecture rtl;
