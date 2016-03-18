-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : BsaBufferControl.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-09-29
-- Last update: 2016-03-18
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.AxiLitePkg.all;
use work.AxiPkg.all;
use work.AxiDmaPkg.all;
use work.AxiStreamDmaRingPkg.all;


entity AxiStreamDmaRingWrite is

   generic (
      TPD_G                      : time                    := 1 ns;
      BUFFERS_G                  : natural range 2 to 64   := 64;
      BURST_SIZE_BYTES_G         : natural range 4 to 4096 := 4096;
      TRIGGER_USER_BIT_G         : natural range 0 to 7    := 0;
      AXIL_AXI_ASYNC_G           : boolean                 := true;
      AXIL_BASE_ADDR_G           : slv(31 downto 0)        := (others => '0');
      DATA_AXI_STREAM_CONFIG_G   : AxiStreamConfigType     := ssiAxiStreamConfig(8);
      STATUS_AXI_STREAM_CONFIG_G : AxiStreamConfigType     := ssiAxiStreamConfig(2);
      AXI_WRITE_CONFIG_G         : AxiConfigType           := axiConfig(32, 8, 1, 8));
   port (
      -- AXI-Lite Interface for local registers 
      axilClk          : in  sl;
      axilRst          : in  sl;
      axilReadMaster   : in  AxiLiteReadMasterType;
      axilReadSlave    : out AxiLiteReadSlaveType;
      axilWriteMaster  : in  AxiLiteWriteMasterType;
      axilWriteSlave   : out AxiLiteWriteSlaveType;
      -- Low level buffer control
      bufferClear      : in  slv(log2(BUFFERS_G)-1 downto 0) := (others => '0');
      bufferClearEn    : in  sl                              := '0';
      -- Status stream
      axisStatusClk    : in  sl;
      axisStatusRst    : in  sl;
      axisStatusMaster : out AxiStreamMasterType;
      axisStatusSlave  : in  AxiStreamSlaveType              := AXI_STREAM_SLAVE_FORCE_C;
      -- Axi Stream interface to be buffered
      axiClk           : in  sl;
      axiRst           : in  sl;
      axisDataMaster   : in  AxiStreamMasterType;
      axisDataSlave    : out AxiStreamSlaveType;
      -- AXI4 Interface for RAM
      axiWriteMaster   : out AxiWriteMasterType;
      axiWriteSlave    : in  AxiWriteSlaveType);

end entity AxiStreamDmaRingWrite;

architecture rtl of AxiStreamDmaRingWrite is

   -- Ram contents represent AXI address shifted by 2
   constant RAM_DATA_WIDTH_C : integer := AXI_WRITE_CONFIG_G.ADDR_WIDTH_C;
   constant RAM_ADDR_WIDTH_C : integer := log2(BUFFERS_G);

   constant AXIL_RAM_ADDR_WIDTH_C : integer := RAM_ADDR_WIDTH_C + log2((RAM_DATA_WIDTH_C-1)/4);


   constant AXIL_CONFIG_C : AxiLiteCrossbarMasterConfigArray := (
      LOCAL_AXIL_C    => (
         baseAddr     => AXIL_BASE_ADDR_G,
         addrBits     => 8,
         connectivity => X"FFFF"),
      START_AXIL_C    => (
         baseAddr     => getBufferAddr(AXIL_BASE_ADDR_G, START_AXIL_C),
         addrBits     => AXIL_RAM_ADDR_WIDTH_C,
         connectivity => X"FFFF"),
      END_AXIL_C      => (
         baseAddr     => getBufferAddr(AXIL_BASE_ADDR_G, END_AXIL_C),
         addrBits     => AXIL_RAM_ADDR_WIDTH_C,
         connectivity => X"FFFF"),
      FIRST_AXIL_C    => (
         baseAddr     => getBufferAddr(AXIL_BASE_ADDR_G, FIRST_AXIL_C),
         addrBits     => AXIL_RAM_ADDR_WIDTH_C,
         connectivity => X"FFFF"),
      NEXT_AXIL_C     => (
         baseAddr     => getBufferAddr(AXIL_BASE_ADDR_G, NEXT_AXIL_C),
         addrBits     => AXIL_RAM_ADDR_WIDTH_C,
         connectivity => X"FFFF"),
      TRIG_AXIL_C     => (
         baseAddr     => getBufferAddr(AXIL_BASE_ADDR_G, TRIG_AXIL_C),
         addrBits     => AXIL_RAM_ADDR_WIDTH_C,
         connectivity => X"FFFF"),
      MODE_AXIL_C     => (
         baseAddr     => getBufferAddr(AXIL_BASE_ADDR_G, MODE_AXIL_C),
         addrBits     => RAM_ADDR_WIDTH_C+2,
         connectivity => X"FFFF"),
      STATUS_AXIL_C   => (
         baseAddr     => getBufferAddr(AXIL_BASE_ADDR_G, STATUS_AXIL_C),
         addrBits     => RAM_ADDR_WIDTH_C+2,
         connectivity => X"FFFF"));


   signal locAxilWriteMasters : AxiLiteWriteMasterArray(AXIL_MASTERS_C-1 downto 0);
   signal locAxilWriteSlaves  : AxiLiteWriteSlaveArray(AXIL_MASTERS_C-1 downto 0);
   signal locAxilReadMasters  : AxiLiteReadMasterArray(AXIL_MASTERS_C-1 downto 0);
   signal locAxilReadSlaves   : AxiLiteReadSlaveArray(AXIL_MASTERS_C-1 downto 0);

   constant AXIS_STATUS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 1,
      TDEST_BITS_C  => 0,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_FIXED_C,  --ite(BSA_STREAM_BYTE_WIDTH_G = 4, TKEEP_FIXED_C, TKEEP_COMP_C),
      TUSER_BITS_C  => 1,
      TUSER_MODE_C  => TUSER_NONE_C);

   type StateType is (WAIT_TVALID_S, ASSERT_ADDR_S, LATCH_POINTERS_S, WAIT_DMA_DONE_S);

   type RegType is record
      wrRamAddr        : slv(RAM_ADDR_WIDTH_C-1 downto 0);
      rdRamAddr        : slv(RAM_ADDR_WIDTH_C-1 downto 0);
      activeBuffer     : slv(RAM_ADDR_WIDTH_C-1 downto 0);
      initBufferEn     : sl;
      ramWe            : sl;
      firstAddr        : slv(RAM_DATA_WIDTH_C-1 downto 0);
      nextAddr         : slv(RAM_DATA_WIDTH_C-1 downto 0);
      startAddr        : slv(RAM_DATA_WIDTH_C-1 downto 0);
      endAddr          : slv(RAM_DATA_WIDTH_C-1 downto 0);
      trigAddr         : slv(RAM_DATA_WIDTH_C-1 downto 0);
      mode             : slv(31 downto 0);
      status           : slv(31 downto 0);
      state            : StateType;
      dmaReq           : AxiWriteDmaReqType;
      trigger          : sl;
      axisStatusMaster : AxiStreamMasterType;
      axilWriteSlave   : AxiLiteWriteSlaveType;
      axilReadSlave    : AxiLiteReadSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      wrRamAddr        => (others => '0'),
      rdRamAddr        => (others => '0'),
      activeBuffer     => (others => '0'),
      initBufferEn     => '0',
      ramWe            => '0',
      firstAddr        => (others => '0'),
      nextAddr         => (others => '0'),
      startAddr        => (others => '0'),
      endAddr          => (others => '0'),
      trigAddr         => (others => '0'),
      mode             => (others => '0'),
      status           => (others => '0'),
      state            => WAIT_TVALID_S,
      dmaReq           => AXI_WRITE_DMA_REQ_INIT_C,
      trigger          => '0',
      axisStatusMaster => axiStreamMasterInit(AXIS_STATUS_CONFIG_C),
      axilWriteSlave   => AXI_LITE_WRITE_SLAVE_INIT_C,
      axilReadSlave    => AXI_LITE_READ_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal dmaAck        : AxiWriteDmaAckType;
   signal startRamDout  : slv(RAM_DATA_WIDTH_C-1 downto 0);
   signal endRamDout    : slv(RAM_DATA_WIDTH_C-1 downto 0);
   signal firstRamDout  : slv(RAM_DATA_WIDTH_C-1 downto 0);
   signal nextRamDout   : slv(RAM_DATA_WIDTH_C-1 downto 0);
   signal trigRamDout   : slv(RAM_DATA_WIDTH_C-1 downto 0);
   signal modeRamDout   : slv(31 downto 0);
   signal statusRamDout : slv(31 downto 0);

   signal modeWrStrobe : sl;
   signal modeWrAddr   : slv(RAM_ADDR_WIDTH_C-1 downto 0);
   signal modeWrData   : slv(31 downto 0);

   -- axiClk signals
   signal dmaReqAxi : AxiWriteDmaReqType;
   signal dmaAckAxi : AxiWriteDmaAckType;

begin
   -- Assert that stream config has enough tdest bits for the number of buffers being tracked

   -- Crossbar
   U_AxiLiteCrossbar_1 : entity work.AxiLiteCrossbar
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
   U_AxiDualPortRam_Start : entity work.AxiDualPortRam
      generic map (
         TPD_G        => TPD_G,
         BRAM_EN_G    => false,
         REG_EN_G     => false,
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
   U_AxiDualPortRam_End : entity work.AxiDualPortRam
      generic map (
         TPD_G        => TPD_G,
         BRAM_EN_G    => false,
         REG_EN_G     => false,
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

   -- First Addresses. System writeable
   U_AxiDualPortRam_First : entity work.AxiDualPortRam
      generic map (
         TPD_G        => TPD_G,
         BRAM_EN_G    => false,
         REG_EN_G     => false,
         AXI_WR_EN_G  => false,
         SYS_WR_EN_G  => true,
         ADDR_WIDTH_G => RAM_ADDR_WIDTH_C,
         DATA_WIDTH_G => RAM_DATA_WIDTH_C)
      port map (
         axiClk         => axilClk,
         axiRst         => axilRst,
         axiReadMaster  => locAxilReadMasters(FIRST_AXIL_C),
         axiReadSlave   => locAxilReadSlaves(FIRST_AXIL_C),
         axiWriteMaster => locAxilWriteMasters(FIRST_AXIL_C),
         axiWriteSlave  => locAxilWriteSlaves(FIRST_AXIL_C),
         clk            => axiClk,
         rst            => axiRst,
         we             => r.ramWe,
         addr           => r.wrRamAddr,
         din            => r.firstAddr,
         dout           => firstRamDout);

   -- Next Addresses. System writeable
   U_AxiDualPortRam_Next : entity work.AxiDualPortRam
      generic map (
         TPD_G        => TPD_G,
         BRAM_EN_G    => false,
         REG_EN_G     => false,
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

   U_AxiDualPortRam_Trigr : entity work.AxiDualPortRam
      generic map (
         TPD_G        => TPD_G,
         BRAM_EN_G    => false,
         REG_EN_G     => false,
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


   U_AxiDualPortRam_Mode : entity work.AxiDualPortRam
      generic map (
         TPD_G        => TPD_G,
         BRAM_EN_G    => false,
         REG_EN_G     => false,
         AXI_WR_EN_G  => true,
         SYS_WR_EN_G  => false,
         COMMON_CLK_G => not AXIL_AXI_ASYNC_G,
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
         axiWrStrobe    => modeWrStrobe,
         axiWrAddr      => modeWrAddr,
         axiWrData      => modeWrData);

   -- Change this to Config (32 bits wide)
   U_AxiDualPortRam_Status : entity work.AxiDualPortRam
      generic map (
         TPD_G        => TPD_G,
         BRAM_EN_G    => false,
         REG_EN_G     => false,
         AXI_WR_EN_G  => false,
         SYS_WR_EN_G  => true,
         ADDR_WIDTH_G => RAM_ADDR_WIDTH_C,
         DATA_WIDTH_G => 32)
      port map (
         axiClk         => axilClk,
         axiRst         => axilRst,
         axiReadMaster  => locAxilReadMasters(STATUS_AXIL_C),
         axiReadSlave   => locAxilReadSlaves(STATUS_AXIL_C),
         axiWriteMaster => locAxilWriteMasters(STATUS_AXIL_C),
         axiWriteSlave  => locAxilWriteSlaves(STATUS_AXIL_C),
         clk            => axiClk,
         rst            => axiRst,
         we             => r.ramWe,
         addr           => r.wrRamAddr,
         din            => r.status,
         dout           => statusRamDout);



   -- DMA Write block
   U_AxiStreamDmaWrite_1 : entity work.AxiStreamDmaWrite
      generic map (
         TPD_G             => TPD_G,
         AXI_READY_EN_G    => true,
         AXIS_CONFIG_G     => DATA_AXI_STREAM_CONFIG_G,
         AXI_CONFIG_G      => AXI_WRITE_CONFIG_G,
         AXI_BURST_G       => "01",         -- INCR
         AXI_CACHE_G       => "0011",       -- Cacheable
         ACK_WAIT_BVALID_G => false)        -- Don't wait for BVALID before acking
      port map (
         axiClk         => axiClk,          -- [in]
         axiRst         => axiRst,          -- [in]
         dmaReq         => dmaReqAxi,       -- [in]
         dmaAck         => dmaAckAxi,       -- [out]
         axisMaster     => axisDataMaster,  -- [in]
         axisSlave      => axisDataSlave,   -- [out]
         axiWriteMaster => axiWriteMaster,  -- [out]
         axiWriteSlave  => axiWriteSlave);  -- [in]

   -- Main logic runs on AXI-Lite clk, which may be different from the DMA AXI clk
   -- Synchronize the request/ack bus if necessary
   U_Synchronizer_Req : entity work.Synchronizer
      generic map (
         TPD_G         => TPD_G,
         STAGES_G      => 4,
         BYPASS_SYNC_G => not AXIL_AXI_ASYNC_G)
      port map (
         clk     => axiClk,              -- [in]
         rst     => axiRst,              -- [in]
         dataIn  => r.dmaReq.request,    -- [in]
         dataOut => dmaReqAxi.request);  -- [out]

   U_SynchronizerFifo_ReqData : entity work.SynchronizerVector
      generic map (
         TPD_G         => TPD_G,
         BYPASS_SYNC_G => not AXIL_AXI_ASYNC_G,
         STAGES_G      => 2,
         WIDTH_G       => 97)
      port map (
         clk                   => axiClk,              -- [in]
         rst                   => axiRst,              -- [in]
         dataIn(0)             => r.dmaReq.drop,
         dataIn(64 downto 1)   => r.dmaReq.address,
         dataIn(96 downto 65)  => r.dmaReq.maxSize,
         dataOut(0)            => dmaReqAxi.drop,
         dataOut(64 downto 1)  => dmaReqAxi.address,
         dataOut(96 downto 65) => dmaReqAxi.maxSize);  -- [out]

   U_Synchronizer_Ack : entity work.Synchronizer
      generic map (
         TPD_G         => TPD_G,
         STAGES_G      => 4,
         BYPASS_SYNC_G => not AXIL_AXI_ASYNC_G)
      port map (
         clk     => axilClk,            -- [in]
         rst     => axilRst,            -- [in]
         dataIn  => dmaAckAxi.done,     -- [in]
         dataOut => dmaAck.done);       -- [out]

   U_SynchronizerFifo_Ack : entity work.SynchronizerVector
      generic map (
         TPD_G         => TPD_G,
         BYPASS_SYNC_G => not AXIL_AXI_ASYNC_G,
         STAGES_G      => 2,
         WIDTH_G       => 68)
      port map (
         clk                  => axilClk,  -- [in]
         rst                  => axilRst,  -- [in]
         dataIn(31 downto 0)  => dmaAckAxi.size,
         dataIn(32)           => dmaAckAxi.overflow,
         dataIn(33)           => dmaAckAxi.writeError,
         dataIn(35 downto 34) => dmaAckAxi.errorValue,
         dataIn(43 downto 36) => dmaAckAxi.firstUser,
         dataIn(51 downto 44) => dmaAckAxi.lastUser,
         dataIn(59 downto 52) => dmaAckAxi.dest,
         dataIn(67 downto 60) => dmaAckAxi.id,

         dataOut(31 downto 0)  => dmaAck.size,
         dataOut(32)           => dmaAck.overflow,
         dataOut(33)           => dmaAck.writeError,
         dataOut(35 downto 34) => dmaAck.errorValue,
         dataOut(43 downto 36) => dmaAck.firstUser,
         dataOut(51 downto 44) => dmaAck.lastUser,
         dataOut(59 downto 52) => dmaAck.dest,
         dataOut(67 downto 60) => dmaAck.id);

   U_AxiStreamFifo_MSG : entity work.AxiStreamFifo
      generic map (
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => 1,
         SLAVE_READY_EN_G    => false,
         VALID_THOLD_G       => 1,
         BRAM_EN_G           => false,
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => false,
         FIFO_ADDR_WIDTH_G   => 4,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => 15,
         SLAVE_AXI_CONFIG_G  => AXIS_STATUS_CONFIG_C,
         MASTER_AXI_CONFIG_G => AXIS_STATUS_CONFIG_C)
      port map (
         sAxisClk    => axilClk,             -- [in]
         sAxisRst    => axilRst,             -- [in]
         sAxisMaster => r.axisStatusMaster,  -- [in]
         sAxisSlave  => open,                -- [out]
         mAxisClk    => axisStatusClk,       -- [in]
         mAxisRst    => axisStatusRst,       -- [in]
         mAxisMaster => axisStatusMaster,    -- [out]
         mAxisSlave  => axisStatusSlave);    -- [in]

   comb : process (axilRst, axisDataMaster, bufferClear, bufferClearEn, dmaAck, endRamDout,
                   firstRamDout, nextRamDout, locAxilReadMasters, locAxilWriteMasters, modeRamDout,
                   modeWrAddr, modeWrData, modeWrStrobe, r, startRamDout, statusRamDout, trigRamDout) is
      variable v            : RegType;
      variable axilEndpoint : AxiLiteEndpointType;
   begin
      v := r;

      v.ramWe          := '0';
      v.dmaReq.maxSize := toSlv(BURST_SIZE_BYTES_G, 32);
      v.initBufferEn   := '0';

      -- If last txn of frame, check for trigger condition and latch it in a register
      if (axisDataMaster.tValid = '1' and axisDataMaster.tLast = '1' and
          axiStreamGetUserBit(DATA_AXI_STREAM_CONFIG_G, axisDataMaster, TRIGGER_USER_BIT_G) = '1') then
         v.trigger := '1';
      end if;

      -- Don't send status message unless directed to below
      v.axisStatusMaster.tValid := '0';

      if (bufferClearEn = '1') then
         -- Override state machine in a buffer clear is being requested
         v.initBufferEn := '1';
         v.rdRamAddr    := bufferClear;
         v.state        := ASSERT_ADDR_S;
      elsif(modeWrStrobe = '1' and modeWrData(INIT_C) = '1') then
         v.initBufferEn := '1';
         v.rdRamAddr    := modeWrAddr;
         v.state        := ASSERT_ADDR_S;
      end if;

      if (r.initBufferEn = '1') then
         v.status(DONE_C)      := '0';
         v.status(FULL_C)      := '0';
         v.status(EMPTY_C)     := '1';
         v.status(TRIGGERED_C) := '0';
         v.status(FST_C)       := (others => '0');
         v.wrRamAddr           := r.rdRamAddr;
         v.firstAddr           := startRamDout;
         v.nextAddr            := startRamDout;
         v.trigAddr            := (others => '1');
         v.ramWe               := '1';
      end if;


      case (r.state) is
         when WAIT_TVALID_S =>
            -- Only final burst before readout can be short, so no need to worry about next
            -- burst wrapping awkwardly. Whole thing will be reset after readout.
            -- Don't do anything if in the middle of a buffer address clear
            if (axisDataMaster.tvalid = '1' and v.initBufferEn = '0' and dmaAck.done = '0') then
               v.activeBuffer := axisDataMaster.tdest(RAM_ADDR_WIDTH_C-1 downto 0);
               v.state        := ASSERT_ADDR_S;
            elsif (v.initBufferEn = '1') then
               -- Stay in this state if bufferes need to be cleared
               v.state := WAIT_TVALID_S;
            end if;

         when ASSERT_ADDR_S =>
            -- State holds here as long buffers are being initialized
            if (v.initBufferEn = '0' and r.initBufferEn = '0') then
               v.rdRamAddr := r.activeBuffer;
               v.wrRamAddr := r.activeBuffer;
               v.state     := LATCH_POINTERS_S;
            end if;

         when LATCH_POINTERS_S =>
            -- Latch pointers
            -- Might go back to ASSERT_ADDR_S if bufferClearEn is high
            -- But everything this state asserts is still valid
            v.startAddr := startRamDout;   -- Address of start of buffer
            v.endAddr   := endRamDout;     -- Address of end of buffer
            v.firstAddr := firstRamDout;   -- Address of first frame in buffer
            v.nextAddr  := nextRamDout;    -- Address of next frame in buffer
            v.trigAddr  := trigRamDout;    -- Start address of frame where trigger was seen
            v.mode      := modeRamDout;    -- Number of frames since trigger seen
            v.status    := statusRamDout;  -- Number of frames to log after trigger seen


            -- Assert a new request.
            -- Direct that frame be dropped if buffer is done with trigger sequence
            v.dmaReq.address(AXI_WRITE_CONFIG_G.ADDR_WIDTH_C-1 downto 0) := nextRamDout;
            v.dmaReq.request                                             := '1';
            v.dmaReq.drop                                                := v.status(DONE_C);
            v.state                                                      := WAIT_DMA_DONE_S;

         when WAIT_DMA_DONE_S =>
            -- Must check that buffer not being cleared so as not to step on the addresses
            if (dmaAck.done = '1' and v.initBufferEn = '0') then

               v.dmaReq.request  := '0';
               v.ramWe           := '1';
               v.status(EMPTY_C) := '0';

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
               v.trigger := '0';
               if (r.trigger = '1') then
                  v.trigAddr            := r.nextAddr;
                  v.status(TRIGGERED_C) := '1';
               end if;

               -- If the buffer is full, increment the first addr too
               if (r.status(FULL_C) = '1') then  --v.nextAddr = r.firstAddr
                  v.firstAddr := r.firstAddr + dmaAck.size;
               end if;

               -- Increment FramesSinceTrigger when necessary
               if (v.status(TRIGGERED_C) = '1' and r.status(DONE_C) = '0') then
                  v.status(FST_C) := r.status(FST_C) + 1;
                  if (r.mode(FAT_C) = r.status(FST_C) and r.mode(DONE_WHEN_FULL_C) = '0') then
                     v.status(DONE_C) := '1';
                     v.status(FST_C)  := r.status(FST_C);
                  end if;

                  -- Output status message when done
                  if (v.status(DONE_C) = '1' and r.dmaReq.drop = '0') then
                     v.axisStatusMaster.tValid            := '1';
                     v.axisStatusMaster.tLast             := '1';
                     v.axisStatusMaster.tData(7 downto 0) := resize(r.rdRamAddr, 8);
                  end if;
               end if;
               v.state := WAIT_TVALID_S;

            end if;


      end case;

      ----------------------------------------------------------------------------------------------
      -- AXI-Lite bus for register access
      ----------------------------------------------------------------------------------------------
      axiSlaveWaitTxn(axilEndpoint, locAxilWriteMasters(0), locAxilReadMasters(0), v.axilWriteSlave, v.axilReadSlave);

--       axiSlaveRegisterR(axilEndpoint, X"00", 0, r.bufferDone(31 downto 0));
--       axiSlaveRegisterR(axilEndpoint, X"04", 0, r.bufferDone(63 downto 32));
--       axiSlaveRegisterR(axilEndpoint, X"08", 0, r.bufferFull(31 downto 0));
--       axiSlaveRegisterR(axilEndpoint, X"0C", 0, r.bufferFull(63 downto 32));
--       axiSlaveRegisterR(axilEndpoint, X"10", 0, r.bufferEmpty(31 downto 0));
--       axiSlaveRegisterR(axilEndpoint, X"14", 0, r.bufferEmpty(63 downto 32));

--       v.axilBufferClearEn := '0';       -- AutoReset
--       axiSlaveRegister(axilEndpoint, BUFFER_CLEAR_OFFSET_C, 0, v.axilBufferClear);
--       axiSlaveRegister(axilEndpoint, BUFFER_CLEAR_OFFSET_C, 31, v.axilBufferClearEn);

--       axiSlaveRegister(axilEndpoint, X"1C", 0, v.doneWhenFull);
--       axiSlaveRegister(axilEndpoint, X"1C", 0, v.doneMsgEn);
--       axiSlaveRegister(axilEndpoint, X"1C", 1, v.fullMsgEn);
--       axiSlaveRegister(axilEndpoint, X"1C", 2, v.emptyMsgEn);

      axiSlaveDefault(axilEndpoint, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_OK_C);


      ----------------------------------------------------------------------------------------------
      -- Reset and output assignment
      ----------------------------------------------------------------------------------------------
      if (axilRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      locAxilReadSlaves(0)  <= r.axilReadSlave;
      locAxilWriteSlaves(0) <= r.axilWriteSlave;

   end process comb;

   seq : process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;

