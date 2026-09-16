-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: RoCEv2 Configuration
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;
use surf.SsiPkg.all;
use surf.RoCEv2Pkg.all;

entity RoCEv2Engine is
   generic (
      TPD_G          : time := 1 ns;   -- simulation propagation delay
      RST_POLARITY_G : sl   := '1');   -- '1' = active-HIGH reset, '0' = active-LOW
   port (
      clk               : in  sl;
      rst               : in  sl;
      -- Work Requests and Comps
      workReqMaster     : in  RoCEv2WorkReqMasterType;
      workReqSlave      : out RoCEv2WorkReqSlaveType;
      workCompMaster    : out RoCEv2WorkCompMasterType;
      workCompSlave     : in  RoCEv2WorkCompSlaveType;
      -- Interface to UDP Engine
      obUdpMaster       : in  AxiStreamMasterType;
      obUdpSlave        : out AxiStreamSlaveType;
      ibUdpMaster       : out AxiStreamMasterType;
      ibUdpSlave        : in  AxiStreamSlaveType;
      -- AXI-Lite Interface
      axilReadMaster    : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave     : out AxiLiteReadSlaveType;
      axilWriteMaster   : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave    : out AxiLiteWriteSlaveType;
      -- DMA Interface
      dmaReadRespMaster : in  RoCEv2DmaReadRespMasterType;
      dmaReadRespSlave  : out RoCEv2DmaReadRespSlaveType;
      dmaReadReqMaster  : out RoCEv2DmaReadReqMasterType;
      dmaReadReqSlave   : in  RoCEv2DmaReadReqSlaveType;
      -- CNP
      cnp_received      : out sl);
end RoCEv2Engine;

architecture mapping of RoCEv2Engine is


   signal roceRstN               : sl;
   signal obUdpRoceMaster_tValid : sl;
   signal obUdpRoceMaster_tData  : slv(255 downto 0);
   signal obUdpRoceMaster_tKeep  : slv(31 downto 0);
   signal obUdpRoceMaster_tFirst : sl;
   signal obUdpRoceMaster_tLast  : sl;
   signal obUdpRoceMaster_tUser  : slv(1 downto 0);
   signal obUdpRoceSlave_tReady  : sl;
   signal ibUdpRoceMaster_tValid : sl;
   signal ibUdpRoceMaster_tData  : slv(255 downto 0);
   signal ibUdpRoceMaster_tKeep  : slv(31 downto 0);
   signal ibUdpRoceMaster_tFirst : sl;
   signal ibUdpRoceMaster_tLast  : sl;
   signal ibUdpRoceMaster_tUser  : slv(1 downto 0);
   signal ibUdpRoceSlave_tReady  : sl;

   signal obUdpRoceMaster : AxiStreamMasterType;
   signal obUdpRoceSlave  : AxiStreamSlaveType;
   signal ibUdpRoceMaster : AxiStreamMasterType;
   signal ibUdpRoceSlave  : AxiStreamSlaveType;

   signal s_axisMetaDataReqMaster  : AxiStreamMasterType;
   signal s_axisMetaDataReqSlave   : AxiStreamSlaveType;
   signal s_axisMetaDataRespMaster : AxiStreamMasterType;
   signal s_axisMetaDataRespSlave  : AxiStreamSlaveType;

   signal s_cnp_received : sl;
   signal s_softRst      : sl;

begin

   -- Transport-core reset = hard 'rst' OR the configurator-generated softRst
   -- (active high). The softRst clears stale QP/PSN state on a software
   -- reconnect without disturbing the rest of the engine or the RUDP/UDP link.
   roceRstN     <= not (rst or s_softRst) when (RST_POLARITY_G = '1') else
                   (rst and not s_softRst);
   cnp_received <= s_cnp_received;

   -----------------------------------------------------------------------------
   -- Adjust Roce/SURF interface
   -----------------------------------------------------------------------------
   AxiStreamResize_Inst : entity surf.RoceResizeAndSwap
      generic map (
         SLAVE_AXI_CONFIG_G  => ROCEV2_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => BLUE_DATA_STREAM_CONFIG_C,
         SWAP_ENDIAN_G       => true,
         LITTLE_ENDIAN_G     => false)
      port map (
         axisClk     => clk,
         axisRst     => rst,
         sAxisMaster => obUdpMaster,
         sAxisSlave  => obUdpSlave,
         mAxisMaster => obUdpRoceMaster,
         mAxisSlave  => obUdpRoceSlave);

   AxiStreamResize_1 : entity surf.RoceResizeAndSwap
      generic map (
         SLAVE_AXI_CONFIG_G  => BLUE_DATA_STREAM_CONFIG_C,
         MASTER_AXI_CONFIG_G => ROCEV2_AXIS_CONFIG_C,
         SWAP_ENDIAN_G       => true,
         LITTLE_ENDIAN_G     => false)
      port map (
         axisClk     => clk,
         axisRst     => rst,
         sAxisMaster => ibUdpRoceMaster,
         sAxisSlave  => ibUdpRoceSlave,
         mAxisMaster => ibUdpMaster,
         mAxisSlave  => ibUdpSlave);

   -----------------------------------------------------------------------------
   -- IP Integrator
   -----------------------------------------------------------------------------
   MasterAxiStreamIpIntegrator_Inst : entity surf.MasterAxiStreamIpIntegrator
      generic map (
         TDATA_NUM_BYTES => TDATA_ROCE_NUM_BYTES_C)
      port map (
         M_AXIS_ACLK    => clk,
         M_AXIS_ARESETN => roceRstN,
         M_AXIS_TVALID  => obUdpRoceMaster_tValid,
         M_AXIS_TDATA   => obUdpRoceMaster_tData,
         M_AXIS_TKEEP   => obUdpRoceMaster_tKeep,
         M_AXIS_TLAST   => obUdpRoceMaster_tLast,
         M_AXIS_TUSER   => obUdpRoceMaster_tUser,
         M_AXIS_TREADY  => obUdpRoceSlave_tReady,
         axisMaster     => obUdpRoceMaster,
         axisSlave      => obUdpRoceSlave);

   SlaveAxiStreamIpIntegrator_Inst : entity surf.SlaveAxiStreamIpIntegrator
      generic map (
         TDATA_NUM_BYTES => TDATA_ROCE_NUM_BYTES_C)
      port map (
         S_AXIS_ACLK    => clk,
         S_AXIS_ARESETN => roceRstN,
         S_AXIS_TVALID  => ibUdpRoceMaster_tValid,
         S_AXIS_TDATA   => ibUdpRoceMaster_tData,
         S_AXIS_TKEEP   => ibUdpRoceMaster_tKeep,
         S_AXIS_TLAST   => ibUdpRoceMaster_tLast,
         S_AXIS_TUSER   => ibUdpRoceMaster_tUser,
         S_AXIS_TREADY  => ibUdpRoceSlave_tReady,
         axisMaster     => ibUdpRoceMaster,
         axisSlave      => ibUdpRoceSlave);

   obUdpRoceMaster_tFirst <= obUdpRoceMaster_tUser(1);
   ibUdpRoceMaster_tUser  <= ibUdpRoceMaster_tFirst & '0';

   -----------------------------------------------------------------------------
   -- RoCE engine wrapper
   -----------------------------------------------------------------------------
   mkAxiSTransportLayer_1 : entity surf.mkAxiSTransportLayer
      port map (
         CLK                        => clk,
         RST_N                      => roceRstN,
         s_work_req_valid           => workReqMaster.valid,
         s_work_req_id              => workReqMaster.id,
         s_work_req_op_code         => workReqMaster.opCode,
         s_work_req_flags           => workReqMaster.flags,
         s_work_req_raddr           => workReqMaster.rAddr,
         s_work_req_rkey            => workReqMaster.rKey,
         s_work_req_len             => workReqMaster.len,
         s_work_req_laddr           => workReqMaster.lAddr,
         s_work_req_lkey            => workReqMaster.lKey,
         s_work_req_sqpn            => workReqMaster.sQpn,
         s_work_req_solicited       => workReqMaster.solicited,
         s_work_req_comp            => workReqMaster.comp,
         s_work_req_swap            => workReqMaster.swap,
         s_work_req_imm_dt          => workReqMaster.immDt,
         s_work_req_rkey_to_inv     => workReqMaster.rkeyToInv,
         s_work_req_srqn            => workReqMaster.srqn,
         s_work_req_dqpn            => workReqMaster.dQpn,
         s_work_req_qkey            => workReqMaster.qKey,
         s_work_req_ready           => workReqSlave.ready,
         s_data_stream_tvalid       => obUdpRoceMaster_tValid,
         s_data_stream_tdata        => obUdpRoceMaster_tData,
         s_data_stream_tkeep        => obUdpRoceMaster_tKeep,
         s_data_stream_tfirst       => obUdpRoceMaster_tFirst,
         s_data_stream_tlast        => obUdpRoceMaster_tLast,
         s_data_stream_tready       => obUdpRoceSlave_tReady,
         m_data_stream_tvalid       => ibUdpRoceMaster_tValid,
         m_data_stream_tdata        => ibUdpRoceMaster_tData,
         m_data_stream_tkeep        => ibUdpRoceMaster_tKeep,
         m_data_stream_tfirst       => ibUdpRoceMaster_tFirst,
         m_data_stream_tlast        => ibUdpRoceMaster_tLast,
         m_data_stream_tready       => ibUdpRoceSlave_tReady,
         m_work_comp_sq_valid       => workCompMaster.valid,
         m_work_comp_sq_id          => workCompMaster.id,
         m_work_comp_sq_op_code     => workCompMaster.opCode,
         m_work_comp_sq_flags       => workCompMaster.flags,
         m_work_comp_sq_status      => workCompMaster.status,
         m_work_comp_sq_len         => workCompMaster.len,
         m_work_comp_sq_pkey        => workCompMaster.pKey,
         m_work_comp_sq_qpn         => workCompMaster.qpn,
         m_work_comp_sq_imm_dt      => workCompMaster.immDt,
         m_work_comp_sq_rkey_to_inv => workCompMaster.rkeyToInv,
         m_work_comp_sq_ready       => workCompSlave.ready,
         s_meta_data_tvalid         => s_axisMetaDataReqMaster.tValid,
         s_meta_data_tdata          => s_axisMetaDataReqMaster.tData(302 downto 0),
         s_meta_data_tready         => s_axisMetaDataReqSlave.tReady,
         m_meta_data_tvalid         => s_axisMetaDataRespMaster.tValid,
         m_meta_data_tdata          => s_axisMetaDataRespMaster.tData(275 downto 0),
         m_meta_data_tready         => s_axisMetaDataRespSlave.tReady,
         m_dma_read_valid           => dmaReadReqMaster.valid,
         m_dma_read_initiator       => dmaReadReqMaster.initiator,
         m_dma_read_sqpn            => dmaReadReqMaster.sQpn,
         m_dma_read_wr_id           => dmaReadReqMaster.wrId,
         m_dma_read_start_addr      => dmaReadReqMaster.startAddr,
         m_dma_read_len             => dmaReadReqMaster.len,
         m_dma_read_mr_idx          => dmaReadReqMaster.mrIdx,
         m_dma_read_ready           => dmaReadReqSlave.ready,
         s_dma_read_valid           => dmaReadRespMaster.valid,
         s_dma_read_initiator       => dmaReadRespMaster.initiator,
         s_dma_read_sqpn            => dmaReadRespMaster.sQpn,
         s_dma_read_wr_id           => dmaReadRespMaster.wrId,
         s_dma_read_is_resp_err     => dmaReadRespMaster.isRespErr,
         s_dma_read_data_stream     => dmaReadRespMaster.dataStream,
         s_dma_read_ready           => dmaReadRespSlave.ready,
         cnp_received               => s_cnp_received);

   -----------------------------------------------------------------------------
   -- RoCE Metadata Configurator
   -----------------------------------------------------------------------------
   RoceConfigurator_1 : entity surf.RoceConfigurator
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G)
      port map (
         clk                     => clk,
         rst                     => rst,
         mAxisMetaDataReqMaster  => s_axisMetaDataReqMaster,
         mAxisMetaDataReqSlave   => s_axisMetaDataReqSlave,
         sAxisMetaDataRespMaster => s_axisMetaDataRespMaster,
         sAxisMetaDataRespSlave  => s_axisMetaDataRespSlave,
         axilReadMaster          => axilReadMaster,
         axilReadSlave           => axilReadSlave,
         axilWriteMaster         => axilWriteMaster,
         axilWriteSlave          => axilWriteSlave,
         softRst                 => s_softRst);

end mapping;
