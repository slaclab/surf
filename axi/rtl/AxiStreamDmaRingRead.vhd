-------------------------------------------------------------------------------
-- File       : AxiStreamDmaRingRead.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-09-29
-- Last update: 2016-08-02
-------------------------------------------------------------------------------
-- Description: AXI Stream to DMA Ring Buffer Read Module
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
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.AxiLitePkg.all;
use work.AxiLiteMasterPkg.all;
use work.AxiPkg.all;
use work.AxiDmaPkg.all;
use work.AxiStreamDmaRingPkg.all;

entity AxiStreamDmaRingRead is

   generic (
      TPD_G                 : time                     := 1 ns;
      BUFFERS_G             : natural range 2 to 64    := 64;
      BURST_SIZE_BYTES_G    : natural range 4 to 2**17 := 4096;
      SSI_OUTPUT_G          : boolean                  := false;
      AXIL_BASE_ADDR_G      : slv(31 downto 0)         := (others => '0');
      AXI_STREAM_READY_EN_G : boolean                  := true;
      AXI_STREAM_CONFIG_G   : AxiStreamConfigType      := ssiAxiStreamConfig(8);
      AXI_READ_CONFIG_G     : AxiConfigType            := axiConfig(32, 8, 1, 8));
   port (
      -- AXI-Lite Interface for local registers 
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : out AxiLiteReadMasterType;
      axilReadSlave   : in  AxiLiteReadSlaveType;
      axilWriteMaster : out AxiLiteWriteMasterType;
      axilWriteSlave  : in  AxiLiteWriteSlaveType;

      -- Status stream
      statusClk    : in  sl;
      statusRst    : in  sl;
      statusMaster : in  AxiStreamMasterType;
      statusSlave  : out AxiStreamSlaveType := AXI_STREAM_SLAVE_FORCE_C;

      -- DMA Stream
--       dataClk    : in  sl;
--       dataRst    : in  sl;
      dataMaster : out AxiStreamMasterType;
      dataSlave  : in  AxiStreamSlaveType;
      dataCtrl   : in  AxiStreamCtrlType := AXI_STREAM_CTRL_UNUSED_C;

      -- AXI4 Interface for RAM      
      axiClk        : in  sl;
      axiRst        : in  sl;
      axiReadMaster : out AxiReadMasterType;
      axiReadSlave  : in  AxiReadSlaveType);

end entity AxiStreamDmaRingRead;

architecture rtl of AxiStreamDmaRingRead is

   constant DMA_ADDR_LOW_C : integer := log2(BURST_SIZE_BYTES_G);

   type StateType is (
      START_LOW_S,
      START_HIGH_S,
      END_LOW_S,
      END_HIGH_S,
      MODE_S,
      DMA_REQ_S,
      CLEAR_HIGH_S,
      CLEAR_LOW_S);

   type RegType is record
      startAddr      : slv(63 downto 0);
      endAddr        : slv(63 downto 0);
      mode           : slv(31 downto 0);
      state          : StateType;
      axilReq        : AxiLiteMasterReqType;
      dmaReq         : AxiReadDmaReqType;
      intStatusSlave : AxiStreamSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      startAddr      => (others => '0'),
      endAddr        => (others => '0'),
      mode           => (others => '0'),
      state          => START_LOW_S,
      axilReq        => AXI_LITE_MASTER_REQ_INIT_C,
      dmaReq         => AXI_READ_DMA_REQ_INIT_C,
      intStatusSlave => AXI_STREAM_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal intStatusMaster : AxiStreamMasterType;

   signal axilAck : AxiLiteMasterAckType;
   signal dmaAck  : AxiReadDmaAckType;


   -- axiClk signals
   signal dmaReqAxi : AxiReadDmaReqType;
   signal dmaAckAxi : AxiReadDmaAckType;


begin
   -- Assert that stream config has enough tdest bits for the number of buffers being tracked


   -- Axi Lite Bus master
   U_AxiLiteMaster_1 : entity work.AxiLiteMaster
      generic map (
         TPD_G => TPD_G)
      port map (
         axilClk         => axilClk,          -- [in]
         axilRst         => axilRst,          -- [in]
         req             => r.axilReq,        -- [in]
         ack             => axilAck,          -- [out]
         axilWriteMaster => axilWriteMaster,  -- [out]
         axilWriteSlave  => axilWriteSlave,   -- [in]
         axilReadMaster  => axilReadMaster,   -- [out]
         axilReadSlave   => axilReadSlave);   -- [in]

   -- DMA Write block
   U_AxiStreamDmaRead_1 : entity work.AxiStreamDmaRead
      generic map (
         TPD_G           => TPD_G,
         AXIS_READY_EN_G => AXI_STREAM_READY_EN_G,
         AXIS_CONFIG_G   => AXI_STREAM_CONFIG_G,
         AXI_CONFIG_G    => AXI_READ_CONFIG_G,
         AXI_BURST_G     => "01",         -- INCR
         AXI_CACHE_G     => "0011")       -- Cacheable
      port map (
         axiClk        => axiClk,         -- [in]
         axiRst        => axiRst,         -- [in]
         dmaReq        => dmaReqAxi,      -- [in]
         dmaAck        => dmaAckAxi,      -- [out]
         axisMaster    => dataMaster,     -- [out]
         axisSlave     => dataSlave,      -- [in]
         axisCtrl      => dataCtrl,       --[in]
         axiReadMaster => axiReadMaster,  -- [out]
         axiReadSlave  => axiReadSlave);  -- [in]

   -- Main logic runs on AXI-Lite clk, which may be different from the DMA AXI clk
   -- Synchronize the request/ack bus if necessary
   U_Synchronizer_Req : entity work.Synchronizer
      generic map (
         TPD_G         => TPD_G,
         STAGES_G      => 4,
         BYPASS_SYNC_G => false)
      port map (
         clk     => axiClk,              -- [in]
         rst     => axiRst,              -- [in]
         dataIn  => r.dmaReq.request,    -- [in]
         dataOut => dmaReqAxi.request);  -- [out]

   U_SynchronizerFifo_ReqData : entity work.SynchronizerVector
      generic map (
         TPD_G         => TPD_G,
         BYPASS_SYNC_G => false,
         STAGES_G      => 2,
         WIDTH_G       => 128)
      port map (
         clk                     => axiClk,  -- [in]
         rst                     => axiRst,  -- [in]
         dataIn(63 downto 0)     => r.dmaReq.address,
         dataIn(95 downto 64)    => r.dmaReq.size,
         dataIn(103 downto 96)   => r.dmaReq.firstUser,
         dataIn(111 downto 104)  => r.dmaReq.lastUser,
         dataIn(119 downto 112)  => r.dmaReq.dest,
         dataIn(127 downto 120)  => r.dmaReq.id,
         dataOut(63 downto 0)    => dmaReqAxi.address,
         dataOut(95 downto 64)   => dmaReqAxi.size,
         dataOut(103 downto 96)  => dmaReqAxi.firstUser,
         dataOut(111 downto 104) => dmaReqAxi.lastUser,
         dataOut(119 downto 112) => dmaReqAxi.dest,
         dataOut(127 downto 120) => dmaReqAxi.id);

   U_Synchronizer_Ack : entity work.Synchronizer
      generic map (
         TPD_G         => TPD_G,
         STAGES_G      => 4,
         BYPASS_SYNC_G => false)
      port map (
         clk     => axilClk,            -- [in]
         rst     => axilRst,            -- [in]
         dataIn  => dmaAckAxi.done,     -- [in]
         dataOut => dmaAck.done);       -- [out]

   U_SynchronizerFifo_Ack : entity work.SynchronizerVector
      generic map (
         TPD_G         => TPD_G,
         BYPASS_SYNC_G => false,
         STAGES_G      => 2,
         WIDTH_G       => 3)
      port map (
         clk                 => axilClk,               -- [in]
         rst                 => axilRst,               -- [in]
         dataIn(0)           => dmaAckAxi.readError,   -- [in]
         dataIn(2 downto 1)  => dmaAckAxi.errorValue,  -- [in]
         dataOut(0)          => dmaAck.readError,      -- [out]
         dataOut(2 downto 1) => dmaAck.errorValue);    -- [out]

   U_AxiStreamFifo_Status : entity work.AxiStreamFifo
      generic map (
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => 1,
         SLAVE_READY_EN_G    => true,
         VALID_THOLD_G       => 1,
         BRAM_EN_G           => false,
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => false,
         FIFO_ADDR_WIDTH_G   => 6,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => 15,
         SLAVE_AXI_CONFIG_G  => DMA_RING_STATUS_CONFIG_C,
         MASTER_AXI_CONFIG_G => DMA_RING_STATUS_CONFIG_C)
      port map (
         sAxisClk    => statusClk,          -- [in]
         sAxisRst    => statusRst,          -- [in]
         sAxisMaster => statusMaster,       -- [in]
         sAxisSlave  => statusSlave,        -- [out]
         mAxisClk    => axilClk,            -- [in]
         mAxisRst    => axilRst,            -- [in]
         mAxisMaster => intStatusMaster,    -- [out]
         mAxisSlave  => r.intStatusSlave);  -- [in]

   comb : process (axilAck, axilRst, dmaAck, intStatusMaster, r) is
      variable v   : RegType;
      variable buf : slv(5 downto 0);
   begin
      v := r;

      buf := intStatusMaster.tData(5 downto 0);

      v.intStatusSlave.tReady := '0';

      -- Automatically issue new read requests when a status message is ready
      v.axilReq.rnw := '1';
      if (axilAck.done = '0' and r.intStatusSlave.tReady = '0') then
         v.axilReq.request := intStatusMaster.tValid;
      end if;

      case r.state is
         when START_LOW_S =>
            v.axilReq.address := getBufferAddr(AXIL_BASE_ADDR_G, START_AXIL_C, buf, '0');

            if (r.axilReq.request = '1' and axilAck.done = '1') then
               v.axilReq.request        := '0';
               v.startAddr(31 downto 0) := axilAck.rdData;
               v.state                  := START_HIGH_S;
            end if;

         when START_HIGH_S =>
            v.axilReq.address := getBufferAddr(AXIL_BASE_ADDR_G, START_AXIL_C, buf, '1');

            if (r.axilReq.request = '1' and axilAck.done = '1') then
               v.axilReq.request         := '0';
               v.startAddr(63 downto 32) := axilAck.rdData;
               v.state                   := END_LOW_S;
            end if;

         when END_LOW_S =>
            v.axilReq.address := getBufferAddr(AXIL_BASE_ADDR_G, END_AXIL_C, buf, '0');

            if (r.axilReq.request = '1' and axilAck.done = '1') then
               v.axilReq.request      := '0';
               v.endAddr(31 downto 0) := axilAck.rdData;
               v.state                := END_HIGH_S;
            end if;

         when END_HIGH_S =>
            v.axilReq.address := getBufferAddr(AXIL_BASE_ADDR_G, END_AXIL_C, buf, '1');

            if (r.axilReq.request = '1' and axilAck.done = '1') then
               v.axilReq.request       := '0';
               v.endAddr(63 downto 32) := axilAck.rdData;
               v.state                 := DMA_REQ_S;
            end if;

         when DMA_REQ_S =>
            v.axilReq.request := '0';

            v.dmaReq.request                            := '1';
            v.dmaReq.address                            := r.startAddr;
            -- Optimization. Start address will always be on a BURST_SIZE boundary
            v.dmaReq.address(DMA_ADDR_LOW_C-1 downto 0) := (others => '0');
            v.dmaReq.size                               := resize(r.endAddr-r.startAddr, 32);
            v.dmaReq.dest                               := resize(buf, 8);
            v.dmaReq.firstUser                          := ite(SSI_OUTPUT_G, X"02", X"00");
            if (dmaAck.done = '1') then
               v.dmaReq.request        := '0';
               v.state                 := MODE_S;
            end if;

         when MODE_S =>
            v.axilReq.address := getBufferAddr(AXIL_BASE_ADDR_G, MODE_AXIL_C, buf, '0');
            v.axilReq.request := '1';
            v.axilReq.rnw     := '1';
            if (r.axilReq.request = '1' and axilAck.done = '1') then
               v.axilReq.request := '0';
               v.mode            := axilAck.rdData;
               v.state           := CLEAR_HIGH_S;
            end if;

         when CLEAR_HIGH_S =>
            -- Clear the buffer after reading it out
            v.axilReq.address        := getBufferAddr(AXIL_BASE_ADDR_G, MODE_AXIL_C, buf, '0');
            v.axilReq.wrData         := r.mode;
            v.axilReq.wrData(INIT_C) := '1';
            v.axilReq.request        := '1';
            v.axilReq.rnw            := '0';
            if (r.axilReq.request = '1' and axilAck.done = '1') then
               v.axilReq.request := '0';
               v.state           := CLEAR_LOW_S;
            end if;

         when CLEAR_LOW_S =>
            v.axilReq.address        := getBufferAddr(AXIL_BASE_ADDR_G, MODE_AXIL_C, buf, '0');
            v.axilReq.wrData         := r.mode;
            v.axilReq.wrData(INIT_C) := '0';
            v.axilReq.request        := '1';
            v.axilReq.rnw            := '0';
            if (r.axilReq.request = '1' and axilAck.done = '1') then
               v.axilReq.request := '0';
               v.intStatusSlave.tready := '1';               
               v.state           := START_LOW_S;
            end if;


      end case;

      ----------------------------------------------------------------------------------------------
      -- Reset and output assignment
      ----------------------------------------------------------------------------------------------
      if (axilRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;


   end process comb;

   seq : process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;

