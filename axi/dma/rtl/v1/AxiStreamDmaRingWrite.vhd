-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: AXI Stream to DMA Ring Buffer Write Module
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
use surf.AxiLitePkg.all;
use surf.AxiPkg.all;
use surf.AxiDmaPkg.all;
use surf.AxiStreamDmaRingPkg.all;

entity AxiStreamDmaRingWrite is
   generic (
      TPD_G                : time                     := 1 ns;
      BUFFERS_G            : natural range 2 to 64    := 64;
      BURST_SIZE_BYTES_G   : natural range 4 to 2**17 := 4096;
      ENABLE_UNALIGN_G     : boolean                  := false;
      TRIGGER_USER_BIT_G   : natural range 0 to 7     := 2;
      AXIL_BASE_ADDR_G     : slv(31 downto 0)         := (others => '0');
      DATA_AXIS_CONFIG_G   : AxiStreamConfigType;
      STATUS_AXIS_CONFIG_G : AxiStreamConfigType;
      AXI_WRITE_CONFIG_G   : AxiConfigType;
      FORCE_WRAP_ALIGN_G   : boolean                  := false;  -- Force dma to end at endAddr
      BYP_SHIFT_G          : boolean                  := true;  -- Bypass both because we do not want them to back-pressure
      BYP_CACHE_G          : boolean                  := true); -- Bypass both because we do not want them to back-pressure
   port (
      -- AXI-Lite Interface for local registers
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;

      -- Status stream
      axisStatusClk    : in  sl;
      axisStatusRst    : in  sl;
      axisStatusMaster : out AxiStreamMasterType;
      axisStatusSlave  : in  AxiStreamSlaveType := AXI_STREAM_SLAVE_FORCE_C;

      -- AXI (DDR) clock domain
      axiClk          : in  sl;
      axiRst          : in  sl;
      -- Axi Stream data to be buffered
      axisDataMaster  : in  AxiStreamMasterType;
      axisDataSlave   : out AxiStreamSlaveType;
      -- Low level buffer control
      bufferClear     : in  slv(log2(BUFFERS_G)-1 downto 0) := (others => '0');
      bufferClearEn   : in  sl                              := '0';
      bufferEnabled   : out slv(BUFFERS_G-1 downto 0);
      bufferEmpty     : out slv(BUFFERS_G-1 downto 0);
      bufferFull      : out slv(BUFFERS_G-1 downto 0);
      bufferDone      : out slv(BUFFERS_G-1 downto 0);
      bufferTriggered : out slv(BUFFERS_G-1 downto 0);
      bufferError     : out slv(BUFFERS_G-1 downto 0);

      -- AXI4 Interface for RAM
      axiWriteMaster : out AxiWriteMasterType;
      axiWriteSlave  : in  AxiWriteSlaveType);

end entity AxiStreamDmaRingWrite;

architecture rtl of AxiStreamDmaRingWrite is

   -- Ram contents represent AXI address shifted by 2
   constant RAM_DATA_WIDTH_C : integer := AXI_WRITE_CONFIG_G.ADDR_WIDTH_C;
   constant RAM_ADDR_WIDTH_C : integer := log2(BUFFERS_G);

   constant AXIL_RAM_ADDR_WIDTH_C : integer := RAM_ADDR_WIDTH_C + log2((RAM_DATA_WIDTH_C-1)/4);

   constant DMA_ADDR_LOW_C : integer := log2(BURST_SIZE_BYTES_G);

   -- Create burst size constant for status
   -- 0 = burst size 4
   -- 1 = burst size 8
   -- 15 = burst size 131072
   constant BURST_SIZE_SLV_C : slv(3 downto 0) := toSlv(DMA_ADDR_LOW_C-2, 4);

   function statusRamInit
      return slv is
      variable ret : slv(31 downto 0) := (others => '0');
   begin
      ret(EMPTY_C)      := '1';
      ret(FULL_C)       := '0';
      ret(DONE_C)       := '1';
      ret(TRIGGERED_C)  := '0';
      ret(ERROR_C)      := '0';
      ret(BURST_SIZE_C) := BURST_SIZE_SLV_C;
      ret(FST_C)        := (others => '0');
      return ret;
   end function statusRamInit;

   function statusRamClear
      return slv is
      variable ret : slv(31 downto 0) := (others => '0');
   begin
      ret(EMPTY_C)      := '1';
      ret(FULL_C)       := '0';
      ret(DONE_C)       := '0';
      ret(TRIGGERED_C)  := '0';
      ret(ERROR_C)      := '0';
      ret(BURST_SIZE_C) := BURST_SIZE_SLV_C;
      ret(FST_C)        := (others => '0');
      return ret;
   end function statusRamClear;

   constant STATUS_RAM_INIT_C : slv(31 downto 0) := statusRamInit;

   constant AXIL_CONFIG_C : AxiLiteCrossbarMasterConfigArray := (
      START_AXIL_C    => (
         baseAddr     => getBufferAddr(AXIL_BASE_ADDR_G, START_AXIL_C, 0),
         addrBits     => AXIL_RAM_ADDR_WIDTH_C,
         connectivity => X"FFFF"),
      END_AXIL_C      => (
         baseAddr     => getBufferAddr(AXIL_BASE_ADDR_G, END_AXIL_C, 0),
         addrBits     => AXIL_RAM_ADDR_WIDTH_C,
         connectivity => X"FFFF"),
      NEXT_AXIL_C     => (
         baseAddr     => getBufferAddr(AXIL_BASE_ADDR_G, NEXT_AXIL_C, 0),
         addrBits     => AXIL_RAM_ADDR_WIDTH_C,
         connectivity => X"FFFF"),
      TRIG_AXIL_C     => (
         baseAddr     => getBufferAddr(AXIL_BASE_ADDR_G, TRIG_AXIL_C, 0),
         addrBits     => AXIL_RAM_ADDR_WIDTH_C,
         connectivity => X"FFFF"),
      MODE_AXIL_C     => (
         baseAddr     => getBufferAddr(AXIL_BASE_ADDR_G, MODE_AXIL_C, 0),
         addrBits     => RAM_ADDR_WIDTH_C+2,
         connectivity => X"FFFF"),
      STATUS_AXIL_C   => (
         baseAddr     => getBufferAddr(AXIL_BASE_ADDR_G, STATUS_AXIL_C, 0),
         addrBits     => RAM_ADDR_WIDTH_C+2,
         connectivity => X"FFFF"));


   signal locAxilWriteMasters : AxiLiteWriteMasterArray(AXIL_MASTERS_C-1 downto 0);
   signal locAxilWriteSlaves  : AxiLiteWriteSlaveArray(AXIL_MASTERS_C-1 downto 0);
   signal locAxilReadMasters  : AxiLiteReadMasterArray(AXIL_MASTERS_C-1 downto 0);
   signal locAxilReadSlaves   : AxiLiteReadSlaveArray(AXIL_MASTERS_C-1 downto 0);

   constant INT_STATUS_AXIS_CONFIG_C : AxiStreamConfigType :=
      ssiAxiStreamConfig(1, TKEEP_FIXED_C, TUSER_FIRST_LAST_C, 4);
--       (
--       TSTRB_EN_C    => false,
--       TDATA_BYTES_C => 1,
--       TDEST_BITS_C  => 4,
--       TID_BITS_C    => 0,
--       TKEEP_MODE_C  => TKEEP_FIXED_C,  --ite(BSA_STREAM_BYTE_WIDTH_G = 4, TKEEP_FIXED_C, TKEEP_COMP_C),
--       TUSER_BITS_C  => 2,
--       TUSER_MODE_C  => TUSER_NONE_C);

   type StateType is (WAIT_TVALID_S, ASSERT_ADDR_S, LATCH_POINTERS_S, WAIT_DMA_DONE_S);

   type RegType is record
      wrRamAddr        : slv(RAM_ADDR_WIDTH_C-1 downto 0);
      rdRamAddr        : slv(RAM_ADDR_WIDTH_C-1 downto 0);
      activeBuffer     : slv(RAM_ADDR_WIDTH_C-1 downto 0);
      ramWe            : sl;
      statusClearEn    : sl;
      statusClearAddr  : slv(RAM_ADDR_WIDTH_C-1 downto 0);
      nextAddr         : slv(RAM_DATA_WIDTH_C-1 downto 0);
      startAddr        : slv(RAM_DATA_WIDTH_C-1 downto 0);
      endAddr          : slv(RAM_DATA_WIDTH_C-1 downto 0);
      trigAddr         : slv(RAM_DATA_WIDTH_C-1 downto 0);
      mode             : slv(31 downto 0);
      status           : slv(31 downto 0);
      state            : StateType;
      dmaReq           : AxiWriteDmaReqType;
      trigger          : sl;
      softTrigger      : slv(2**RAM_ADDR_WIDTH_C-1 downto 0);
      eofe             : sl;
      bufferEnabled    : slv(BUFFERS_G-1 downto 0);
      bufferEmpty      : slv(BUFFERS_G-1 downto 0);
      bufferFull       : slv(BUFFERS_G-1 downto 0);
      bufferDone       : slv(BUFFERS_G-1 downto 0);
      bufferTriggered  : slv(BUFFERS_G-1 downto 0);
      bufferError      : slv(BUFFERS_G-1 downto 0);
      bufferClear      : slv(BUFFERS_G-1 downto 0);
      axisStatusMaster : AxiStreamMasterType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      wrRamAddr        => (others => '0'),
      rdRamAddr        => (others => '0'),
      activeBuffer     => (others => '0'),
      ramWe            => '0',
      statusClearEn    => '0',
      statusClearAddr  => (others => '0'),
      nextAddr         => (others => '0'),
      startAddr        => (others => '0'),
      endAddr          => (others => '0'),
      trigAddr         => (others => '0'),
      mode             => (others => '0'),
      status           => (others => '0'),
      state            => WAIT_TVALID_S,
      dmaReq           => (
         request       => '0',
         drop          => '0',
         address       => (others => '0'),
         maxSize       => toSlv(BURST_SIZE_BYTES_G, 32),
         prot          => (others=>'0')),
      trigger          => '0',
      softTrigger      => (others => '0'),
      eofe             => '0',
      bufferEnabled    => (others => '0'),
      bufferEmpty      => (others => '1'),
      bufferFull       => (others => '0'),
      bufferDone       => (others => '1'),
      bufferTriggered  => (others => '0'),
      bufferError      => (others => '0'),
      bufferClear      => (others => '0'),
      axisStatusMaster => axiStreamMasterInit(INT_STATUS_AXIS_CONFIG_C) );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal dmaAck        : AxiWriteDmaAckType;
   signal startRamDout  : slv(RAM_DATA_WIDTH_C-1 downto 0);
   signal endRamDout    : slv(RAM_DATA_WIDTH_C-1 downto 0);
   signal nextRamDout   : slv(RAM_DATA_WIDTH_C-1 downto 0);
   signal trigRamDout   : slv(RAM_DATA_WIDTH_C-1 downto 0);
   signal modeRamDout   : slv(31 downto 0);
   signal statusRamDout : slv(31 downto 0);

   signal modeWrValid  : sl;
   signal modeWrStrobe : slv(3 downto 0);
   signal modeWrAddr   : slv(RAM_ADDR_WIDTH_C-1 downto 0);
   signal modeWrData   : slv(31 downto 0);

   signal statusWe     : sl;
   signal statusAddr   : slv(RAM_ADDR_WIDTH_C-1 downto 0);
   signal statusDin    : slv(31 downto 0);

begin

   -- Assert that stream config has enough tdest bits for the number of buffers being tracked
   -- Assert that BURST_SIZE_BYTES_G is a power of 2

   -- Crossbar
   U_AxiLiteCrossbar_1 : entity surf.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => AXIL_MASTERS_C,
         DEC_ERROR_RESP_G   => AXI_RESP_DECERR_C,
         MASTERS_CONFIG_G   => AXIL_CONFIG_C,
         DEBUG_G            => true)
      port map (
         axiClk              => axilClk,              -- [in]
         axiClkRst           => axilRst,              -- [in]
         sAxiWriteMasters(0) => axilWriteMaster,      -- [in]
         sAxiWriteSlaves(0)  => axilWriteSlave,       -- [out]
         sAxiReadMasters(0)  => axilReadMaster,       -- [in]
         sAxiReadSlaves(0)   => axilReadSlave,        -- [out]
         mAxiWriteMasters    => locAxilWriteMasters,  -- [out]
         mAxiWriteSlaves     => locAxilWriteSlaves,   -- [in]
         mAxiReadMasters     => locAxilReadMasters,   -- [out]
         mAxiReadSlaves      => locAxilReadSlaves);   -- [in]

   -------------------------------------------------------------------------------------------------
   -- AXI RAMs store buffer information
   -------------------------------------------------------------------------------------------------
   -- Start Addresses. AXIL writeable
   U_AxiDualPortRam_Start : entity surf.AxiDualPortRam
      generic map (
         TPD_G        => TPD_G,
         SYNTH_MODE_G => "inferred",
         MEMORY_TYPE_G=> "distributed",
         READ_LATENCY_G => 0,
         AXI_WR_EN_G  => true,
         SYS_WR_EN_G  => false,
         ADDR_WIDTH_G => RAM_ADDR_WIDTH_C,
         DATA_WIDTH_G => RAM_DATA_WIDTH_C)
      port map (
         axiClk         => axilClk,
         axiRst         => axilRst,
         axiReadMaster  => locAxilReadMasters(START_AXIL_C),
         axiReadSlave   => locAxilReadSlaves(START_AXIL_C),
         axiWriteMaster => locAxilWriteMasters(START_AXIL_C),
         axiWriteSlave  => locAxilWriteSlaves(START_AXIL_C),
         clk            => axiClk,
         rst            => axiRst,
         addr           => r.rdRamAddr,
         dout           => startRamDout);

   -- End Addresses. AXIL writeable
   U_AxiDualPortRam_End : entity surf.AxiDualPortRam
      generic map (
         TPD_G        => TPD_G,
         SYNTH_MODE_G => "inferred",
         MEMORY_TYPE_G=> "distributed",
         READ_LATENCY_G => 0,
         AXI_WR_EN_G  => true,
         SYS_WR_EN_G  => false,
         ADDR_WIDTH_G => RAM_ADDR_WIDTH_C,
         DATA_WIDTH_G => RAM_DATA_WIDTH_C)
      port map (
         axiClk         => axilClk,
         axiRst         => axilRst,
         axiReadMaster  => locAxilReadMasters(END_AXIL_C),
         axiReadSlave   => locAxilReadSlaves(END_AXIL_C),
         axiWriteMaster => locAxilWriteMasters(END_AXIL_C),
         axiWriteSlave  => locAxilWriteSlaves(END_AXIL_C),
         clk            => axiClk,
         rst            => axiRst,
         addr           => r.rdRamAddr,
         dout           => endRamDout);


   -- Next Addresses. System writeable
   U_AxiDualPortRam_Next : entity surf.AxiDualPortRam
      generic map (
         TPD_G        => TPD_G,
         SYNTH_MODE_G => "inferred",
         MEMORY_TYPE_G=> "distributed",
         READ_LATENCY_G => 0,
         AXI_WR_EN_G  => false,
         SYS_WR_EN_G  => true,
         ADDR_WIDTH_G => RAM_ADDR_WIDTH_C,
         DATA_WIDTH_G => RAM_DATA_WIDTH_C)
      port map (
         axiClk         => axilClk,
         axiRst         => axilRst,
         axiReadMaster  => locAxilReadMasters(NEXT_AXIL_C),
         axiReadSlave   => locAxilReadSlaves(NEXT_AXIL_C),
         axiWriteMaster => locAxilWriteMasters(NEXT_AXIL_C),
         axiWriteSlave  => locAxilWriteSlaves(NEXT_AXIL_C),
         clk            => axiClk,
         rst            => axiRst,
         we             => r.ramWe,
         addr           => r.wrRamAddr,
         din            => r.nextAddr,
         dout           => nextRamDout);

   U_AxiDualPortRam_Trigger : entity surf.AxiDualPortRam
      generic map (
         TPD_G        => TPD_G,
         SYNTH_MODE_G => "inferred",
         MEMORY_TYPE_G=> "distributed",
         READ_LATENCY_G => 0,
         AXI_WR_EN_G  => false,
         SYS_WR_EN_G  => true,
         ADDR_WIDTH_G => RAM_ADDR_WIDTH_C,
         DATA_WIDTH_G => RAM_DATA_WIDTH_C)
      port map (
         axiClk         => axilClk,
         axiRst         => axilRst,
         axiReadMaster  => locAxilReadMasters(TRIG_AXIL_C),
         axiReadSlave   => locAxilReadSlaves(TRIG_AXIL_C),
         axiWriteMaster => locAxilWriteMasters(TRIG_AXIL_C),
         axiWriteSlave  => locAxilWriteSlaves(TRIG_AXIL_C),
         clk            => axiClk,
         rst            => axiRst,
         we             => r.ramWe,
         addr           => r.wrRamAddr,
         din            => r.trigAddr,
         dout           => trigRamDout);


   U_AxiDualPortRam_Mode : entity surf.AxiDualPortRam
      generic map (
         TPD_G        => TPD_G,
         SYNTH_MODE_G => "inferred",
         MEMORY_TYPE_G=> "distributed",
         READ_LATENCY_G => 0,
         AXI_WR_EN_G  => true,
         SYS_WR_EN_G  => false,
         COMMON_CLK_G => false,
         ADDR_WIDTH_G => RAM_ADDR_WIDTH_C,
         DATA_WIDTH_G => 32)
      port map (
         axiClk         => axilClk,
         axiRst         => axilRst,
         axiReadMaster  => locAxilReadMasters(MODE_AXIL_C),
         axiReadSlave   => locAxilReadSlaves(MODE_AXIL_C),
         axiWriteMaster => locAxilWriteMasters(MODE_AXIL_C),
         axiWriteSlave  => locAxilWriteSlaves(MODE_AXIL_C),
         clk            => axiClk,
         rst            => axiRst,
         addr           => r.rdRamAddr,
         dout           => modeRamDout,
         axiWrValid     => modeWrValid,
         axiWrStrobe    => modeWrStrobe,
         axiWrAddr      => modeWrAddr,
         axiWrData      => modeWrData);

   U_AxiDualPortRam_Status : entity surf.AxiDualPortRam
      generic map (
         TPD_G        => TPD_G,
         SYNTH_MODE_G => "inferred",
         MEMORY_TYPE_G=> "distributed",
         READ_LATENCY_G => 0,
         AXI_WR_EN_G  => false,
         SYS_WR_EN_G  => true,
         ADDR_WIDTH_G => RAM_ADDR_WIDTH_C,
         DATA_WIDTH_G => 32,
         INIT_G       => STATUS_RAM_INIT_C)
      port map (
         axiClk         => axilClk,
         axiRst         => axilRst,
         axiReadMaster  => locAxilReadMasters(STATUS_AXIL_C),
         axiReadSlave   => locAxilReadSlaves(STATUS_AXIL_C),
         axiWriteMaster => locAxilWriteMasters(STATUS_AXIL_C),
         axiWriteSlave  => locAxilWriteSlaves(STATUS_AXIL_C),
         clk            => axiClk,
         rst            => axiRst,
         we             => statusWe,   -- r.ramWe,
         addr           => statusAddr, -- r.wrRamAddr,
         din            => statusDin,  -- r.status,
         dout           => statusRamDout);

   --  Priority is to write the status from the state machine
   statusWe   <= r.statusClearEn or r.ramWe;
   statusAddr <= r.statusClearAddr when (r.statusClearEn = '1' and r.ramWe = '0') else r.wrRamAddr;
   statusDin  <= statusRamClear    when (r.statusClearEn = '1' and r.ramWe = '0') else r.status;

   -- DMA Write block
   U_AxiStreamDmaWrite_1 : entity surf.AxiStreamDmaWrite
      generic map (
         TPD_G             => TPD_G,
         AXI_READY_EN_G    => true,
         AXIS_CONFIG_G     => DATA_AXIS_CONFIG_G,
         AXI_CONFIG_G      => AXI_WRITE_CONFIG_G,
         AXI_BURST_G       => "01",         -- INCR
         AXI_CACHE_G       => "0011",       -- Cacheable
         ACK_WAIT_BVALID_G => false,
         BYP_SHIFT_G       => BYP_SHIFT_G,  -- Bypass both because we do not want them to back-pressure
         BYP_CACHE_G       => BYP_CACHE_G)  -- Bypass both because we do not want them to back-pressure
      port map (
         axiClk         => axiClk,          -- [in]
         axiRst         => axiRst,          -- [in]
         dmaReq         => r.dmaReq,        -- [in]
         dmaAck         => dmaAck,          -- [out]
         axisMaster     => axisDataMaster,  -- [in]
         axisSlave      => axisDataSlave,   -- [out]
         axiWriteMaster => axiWriteMaster,  -- [out]
         axiWriteSlave  => axiWriteSlave);  -- [in]

   -- Pass status message through a small fifo to convert to statusClk
   -- And convert width
   U_AxiStreamFifo_MSG : entity surf.AxiStreamFifoV2
      generic map (
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => 1,
         SLAVE_READY_EN_G    => false,
         VALID_THOLD_G       => 1,
         MEMORY_TYPE_G       => "distributed",
         GEN_SYNC_FIFO_G     => false,
         FIFO_ADDR_WIDTH_G   => 4,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => 15,
         SLAVE_AXI_CONFIG_G  => INT_STATUS_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => STATUS_AXIS_CONFIG_G)
      port map (
         sAxisClk    => axiClk,              -- [in]
         sAxisRst    => axiRst,              -- [in]
         sAxisMaster => r.axisStatusMaster,  -- [in]
         sAxisSlave  => open,                -- [out]
         mAxisClk    => axisStatusClk,       -- [in]
         mAxisRst    => axisStatusRst,       -- [in]
         mAxisMaster => axisStatusMaster,    -- [out]
         mAxisSlave  => axisStatusSlave);    -- [in]

   -------------------------------------------------------------------------------------------------
   -- Main logic
   -------------------------------------------------------------------------------------------------
   comb : process (axiRst, axisDataMaster, bufferClear, bufferClearEn, dmaAck, endRamDout,
                   modeRamDout, modeWrAddr, modeWrData, modeWrStrobe, modeWrValid, nextRamDout, r,
                   startRamDout, statusRamDout, trigRamDout) is
      variable v            : RegType;
      variable axilEndpoint : AxiLiteEndpointType;
      variable endRamSize   : integer;
   begin
      v := r;

      -- These registers default to zero
      v.ramWe                   := '0';
      v.statusClearEn           := '0';
      v.axisStatusMaster.tValid := '0';

      -- If last txn of frame, check for trigger condition and EOFE and latch them in registers.
      if (axisDataMaster.tValid = '1' and axisDataMaster.tLast = '1') then
         if(axiStreamGetUserBit(DATA_AXIS_CONFIG_G, axisDataMaster, TRIGGER_USER_BIT_G) = '1') then
            v.trigger := '1';
         end if;
         if (axiStreamGetUserBit(DATA_AXIS_CONFIG_G, axisDataMaster, SSI_EOFE_C) = '1') then
            v.eofe := '1';
         end if;
      end if;

      -- Check for software trigger.
      if (modeWrValid = '1' and modeWrStrobe(SOFT_TRIGGER_C/8) = '1' and modeWrData(SOFT_TRIGGER_C) = '1') then
         v.softTrigger := r.softTrigger or decode(modeWrAddr);
      end if;

      --
      --  Handle clear requests
      --    Update the status ram promptly
      --    Queue the pointer updates until the WAIT_FOR_TVALID
      --
      if (bufferClearEn = '1') then
         v.statusClearEn    := '1';
         v.statusClearAddr  := bufferClear;
         v.bufferClear(conv_integer(bufferClear)) := '1';
      elsif(modeWrValid = '1' and modeWrData(INIT_C) = '1' and modeWrStrobe(INIT_C/8) = '1') then
         v.statusClearEn    := '1';
         v.statusClearAddr  := modeWrAddr;
         v.bufferClear(conv_integer(modeWrAddr)) := '1';
      end if;

      -- ramWe takes precedence over statusClearEn
      if (r.statusClearEn = '1' and r.ramWe = '1') then
         v.statusClearEn := '1';
      end if;


      case (r.state) is
         when WAIT_TVALID_S =>
            -- Only final burst before readout can be short, so no need to worry about next
            -- burst wrapping awkwardly. Whole thing will be reset after readout.
            if (axisDataMaster.tvalid = '1' and dmaAck.done = '0') then
               v.activeBuffer := axisDataMaster.tdest(RAM_ADDR_WIDTH_C-1 downto 0);
               v.state        := ASSERT_ADDR_S;
            end if;

         when ASSERT_ADDR_S =>
            v.rdRamAddr := r.activeBuffer;
            v.wrRamAddr := r.activeBuffer;
            --  Cannot proceed to the next state if statusRamDout doesn't
            --  reflect the active buffer
            if r.statusClearEn = '0' then
               v.state     := LATCH_POINTERS_S;
            end if;

         when LATCH_POINTERS_S =>
            -- Latch pointers
            v.startAddr := startRamDout;   -- Address of start of buffer
            v.endAddr   := endRamDout;     -- Address of end of buffer
            v.nextAddr  := nextRamDout;    -- Address of next frame in buffer
            v.trigAddr  := trigRamDout;    -- Start address of frame where trigger was seen
            v.mode      := modeRamDout;    -- Number of frames since trigger seen
            v.status    := statusRamDout;  -- Number of frames to log after trigger seen

            if r.bufferClear(conv_integer(r.activeBuffer)) = '1' then
               v.bufferClear(conv_integer(r.activeBuffer)) := '0';
               v.trigAddr   := (others=>'1');
               v.nextAddr   := startRamDout;
               v.ramWe      := '1';
            end if;

            -- Assert a new request.
            -- Direct that frame be dropped if buffer is done with trigger sequence
            -- Writes always start on a BURST_SIZE_BYTES_G boundary, so can drive low dmaReq.address
            -- bits to zero for optimization.
            v.dmaReq.address(AXI_WRITE_CONFIG_G.ADDR_WIDTH_C-1 downto 0) := v.nextAddr;
            endRamSize := conv_integer(endRamDout - v.nextAddr);
            if FORCE_WRAP_ALIGN_G and endRamSize < BURST_SIZE_BYTES_G then
              v.dmaReq.maxSize := toSlv(endRamSize, 32);
            else
              v.dmaReq.maxSize := toSlv(BURST_SIZE_BYTES_G, 32);
            end if;
            if not ENABLE_UNALIGN_G then
              v.dmaReq.address(DMA_ADDR_LOW_C-1 downto 0)                  := (others => '0');
              v.dmaReq.drop                                                := v.status(DONE_C);
            else
              --  status(DONE_C) indicates a push, but maybe more than one
              v.dmaReq.drop                                                := '0';
            end if;
            v.dmaReq.request                                             := '1';
            v.state                                                      := WAIT_DMA_DONE_S;

         when WAIT_DMA_DONE_S =>
            -- Wait until DMA transaction is done.
            if (dmaAck.done = '1') then

               v.dmaReq.request  := '0';  -- Deassert dma request
               v.status(EMPTY_C) := '0';  -- Update empty status
               v.ramWe           := '1';  -- write new values into register ram

               -- Increment address of last burst in buffer.
               -- Wrap back to start when it hits the end of the buffer.
               v.nextAddr := r.nextAddr + dmaAck.size;  --(BURST_SIZE_BYTES_G); --
               if (v.nextAddr = r.endAddr) then
                  v.status(FULL_C) := '1';
                  if (r.mode(DONE_WHEN_FULL_C) = '1') then
                     v.status(DONE_C) := '1';
                  end if;
                  v.nextAddr := r.startAddr;
               end if;

               -- Record trigger position if a trigger was seen on current frame
               v.trigger                                   := '0';
               v.softTrigger(conv_integer(r.activeBuffer)) := '0';
               if ((r.trigger = '1' or r.softTrigger(conv_integer(r.activeBuffer)) = '1') and r.status(TRIGGERED_C) = '0') then
                  v.trigAddr            := r.nextAddr;
                  v.status(TRIGGERED_C) := '1';
               end if;

               -- Check for EOFE
               v.eofe := '0';
               if (r.eofe = '1') then
                  v.status(ERROR_C) := '1';
                  v.status(DONE_C)  := '1';
               end if;


               -- Increment FramesSinceTrigger when necessary
               if (v.status(TRIGGERED_C) = '1' and r.status(DONE_C) = '0') then
                  v.status(FST_C) := r.status(FST_C) + 1;
                  if (r.mode(FAT_C) = r.status(FST_C) and r.mode(DONE_WHEN_FULL_C) = '0') then
                     v.status(DONE_C) := '1';
                     v.status(FST_C)  := r.status(FST_C);
                  end if;
               end if;

               -- Output status message when done
               if (v.status(DONE_C) = '1' and r.dmaReq.drop = '0') then
                  v.axisStatusMaster.tValid            := '1';
                  v.axisStatusMaster.tLast             := '1';
                  v.axisStatusMaster.tData(7 downto 0) := resize(r.rdRamAddr, 8);
                  v.axisStatusMaster.tDest(3 downto 0) := r.mode(STATUS_TDEST_C);
                  ssiSetUserSof(INT_STATUS_AXIS_CONFIG_C, v.axisStatusMaster, '1');
               end if;

               v.state := WAIT_TVALID_S;

            end if;

      end case;

      -- Assign status outputs
      if (r.ramWe = '1') then
         v.bufferEmpty(conv_integer(r.wrRamAddr))     := r.status(EMPTY_C);
         v.bufferFull(conv_integer(r.wrRamAddr))      := r.status(FULL_C);
         v.bufferDone(conv_integer(r.wrRamAddr))      := r.status(DONE_C);
         v.bufferTriggered(conv_integer(r.wrRamAddr)) := r.status(TRIGGERED_C);
         v.bufferError(conv_integer(r.wrRamAddr))     := r.status(ERROR_C);
      elsif (r.statusClearEn = '1') then
         v.bufferEmpty(conv_integer(r.statusClearAddr))     := statusRamClear(EMPTY_C);
         v.bufferFull(conv_integer(r.statusClearAddr))      := statusRamClear(FULL_C);
         v.bufferDone(conv_integer(r.statusClearAddr))      := statusRamClear(DONE_C);
         v.bufferTriggered(conv_integer(r.statusClearAddr)) := statusRamClear(TRIGGERED_C);
         v.bufferError(conv_integer(r.statusClearAddr))     := statusRamClear(ERROR_C);
      end if;

      if(modeWrValid = '1' and modeWrStrobe(ENABLED_C/8) = '1') then
         v.bufferEnabled(conv_integer(modeWrAddr)) := modeWrData(ENABLED_C);
      end if;

      ----------------------------------------------------------------------------------------------
      -- Reset and output assignment
      ----------------------------------------------------------------------------------------------
      if (axiRst = '1') then
         v := REG_INIT_C;
      end if;

      rin             <= v;
      bufferEnabled   <= r.bufferEnabled;
      bufferEmpty     <= r.bufferEmpty;
      bufferFull      <= r.bufferFull;
      bufferDone      <= r.bufferDone;
      bufferTriggered <= r.bufferTriggered;
      bufferError     <= r.bufferError;

   end process comb;

   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;

