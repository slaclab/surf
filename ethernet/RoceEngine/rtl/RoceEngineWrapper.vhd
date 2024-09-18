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
use surf.RocePkg.all;

entity RoceEngineWrapper is
   generic (
      TPD_G             : time    := 1 ns;
      EXT_ROCE_CONFIG_G : boolean := false);
   port (
      clk                 : in  sl;
      rst                 : in  sl;
      -- Work Requests and Comps
      workReqMaster       : in  RoceWorkReqMasterType;
      workReqSlave        : out RoceWorkReqSlaveType;
      workCompMaster      : out RoceWorkCompMasterType;
      workCompSlave       : in  RoceWorkCompSlaveType;
      -- Interface to UDP Engine
      obUdpMaster         : in  AxiStreamMasterType;
      obUdpSlave          : out AxiStreamSlaveType;
      ibUdpMaster         : out AxiStreamMasterType;
      ibUdpSlave          : in  AxiStreamSlaveType;
      -- MetaData Config Bus
      sAxisMetaDataMaster : in  AxiStreamMasterType;
      sAxisMetaDataSlave  : out AxiStreamSlaveType;
      mAxisMetaDataMaster : out AxiStreamMasterType;
      mAxisMetaDataSlave  : in  AxiStreamSlaveType;
      -- AXI-Lite Interface
      axilReadMaster      : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave       : out AxiLiteReadSlaveType;
      axilWriteMaster     : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave      : out AxiLiteWriteSlaveType;
      -- DMA Interface
      dmaReadRespMaster   : in  RoceDmaReadRespMasterType;
      dmaReadRespSlave    : out RoceDmaReadRespSlaveType;
      dmaReadReqMaster    : out RoceDmaReadReqMasterType;
      dmaReadReqSlave     : in  RoceDmaReadReqSlaveType);
end RoceEngineWrapper;

architecture mapping of RoceEngineWrapper is

   component mkAxiSTransportLayer is
      port (
         CLK                        : in  std_logic;
         RST_N                      : in  std_logic;
         s_work_req_valid           : in  std_logic;
         s_work_req_id              : in  std_logic_vector(63 downto 0);
         s_work_req_op_code         : in  std_logic_vector(3 downto 0);
         s_work_req_flags           : in  std_logic_vector(4 downto 0);
         s_work_req_raddr           : in  std_logic_vector(63 downto 0);
         s_work_req_rkey            : in  std_logic_vector(31 downto 0);
         s_work_req_len             : in  std_logic_vector(31 downto 0);
         s_work_req_laddr           : in  std_logic_vector(63 downto 0);
         s_work_req_lkey            : in  std_logic_vector(31 downto 0);
         s_work_req_sqpn            : in  std_logic_vector(23 downto 0);
         s_work_req_solicited       : in  std_logic;
         s_work_req_comp            : in  std_logic_vector(64 downto 0);
         s_work_req_swap            : in  std_logic_vector(64 downto 0);
         s_work_req_imm_dt          : in  std_logic_vector(32 downto 0);
         s_work_req_rkey_to_inv     : in  std_logic_vector(32 downto 0);
         s_work_req_srqn            : in  std_logic_vector(24 downto 0);
         s_work_req_dqpn            : in  std_logic_vector(24 downto 0);
         s_work_req_qkey            : in  std_logic_vector(32 downto 0);
         s_work_req_ready           : out std_logic;
         s_data_stream_tvalid       : in  std_logic;
         s_data_stream_tdata        : in  std_logic_vector(255 downto 0);
         s_data_stream_tkeep        : in  std_logic_vector(31 downto 0);
         s_data_stream_tfirst       : in  std_logic;
         s_data_stream_tlast        : in  std_logic;
         s_data_stream_tready       : out std_logic;
         m_data_stream_tvalid       : out std_logic;
         m_data_stream_tdata        : out std_logic_vector(255 downto 0);
         m_data_stream_tkeep        : out std_logic_vector(31 downto 0);
         m_data_stream_tfirst       : out std_logic;
         m_data_stream_tlast        : out std_logic;
         m_data_stream_tready       : in  std_logic;
         m_work_comp_sq_valid       : out std_logic;
         m_work_comp_sq_id          : out std_logic_vector(63 downto 0);
         m_work_comp_sq_op_code     : out std_logic_vector(7 downto 0);
         m_work_comp_sq_flags       : out std_logic_vector(6 downto 0);
         m_work_comp_sq_status      : out std_logic_vector(4 downto 0);
         m_work_comp_sq_len         : out std_logic_vector(31 downto 0);
         m_work_comp_sq_pkey        : out std_logic_vector(15 downto 0);
         m_work_comp_sq_qpn         : out std_logic_vector(23 downto 0);
         m_work_comp_sq_imm_dt      : out std_logic_vector(32 downto 0);
         m_work_comp_sq_rkey_to_inv : out std_logic_vector(32 downto 0);
         m_work_comp_sq_ready       : in  std_logic;
         s_meta_data_tvalid         : in  std_logic;
         s_meta_data_tdata          : in  std_logic_vector(302 downto 0);
         s_meta_data_tready         : out std_logic;
         m_meta_data_tvalid         : out std_logic;
         m_meta_data_tdata          : out std_logic_vector(275 downto 0);
         m_meta_data_tready         : in  std_logic;
         m_dma_read_valid           : out std_logic;
         m_dma_read_initiator       : out std_logic_vector(3 downto 0);
         m_dma_read_sqpn            : out std_logic_vector(23 downto 0);
         m_dma_read_wr_id           : out std_logic_vector(63 downto 0);
         m_dma_read_start_addr      : out std_logic_vector(63 downto 0);
         m_dma_read_len             : out std_logic_vector(12 downto 0);
         m_dma_read_mr_idx          : out std_logic;
         m_dma_read_ready           : in  std_logic;
         s_dma_read_valid           : in  std_logic;
         s_dma_read_initiator       : in  std_logic_vector(3 downto 0);
         s_dma_read_sqpn            : in  std_logic_vector(23 downto 0);
         s_dma_read_wr_id           : in  std_logic_vector(63 downto 0);
         s_dma_read_is_resp_err     : in  std_logic;
         s_dma_read_data_stream     : in  std_logic_vector(289 downto 0);
         s_dma_read_ready           : out std_logic);
   end component mkAxiSTransportLayer;

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

   signal s_axisMetaDataReqMaster     : AxiStreamMasterType;
   signal s_axisMetaDataReqSlave      : AxiStreamSlaveType;
   signal s_axisMetaDataRespMaster    : AxiStreamMasterType;
   signal s_axisMetaDataRespSlave     : AxiStreamSlaveType;
   signal s_axisMetaDataReqMasterMux  : AxiStreamMasterType;
   signal s_axisMetaDataReqSlaveMux   : AxiStreamSlaveType;
   signal s_axisMetaDataRespMasterMux : AxiStreamMasterType;
   signal s_axisMetaDataRespSlaveMux  : AxiStreamSlaveType;

begin

   roceRstN <= not rst;

   -----------------------------------------------------------------------------
   -- Adjust Roce/SURF interface
   -----------------------------------------------------------------------------
   AxiStreamResize_Inst : entity surf.RoceResizeAndSwap
      generic map (
         SLAVE_AXI_CONFIG_G  => SURF_DATA_STREAM_CONFIG_C,
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
         MASTER_AXI_CONFIG_G => SURF_DATA_STREAM_CONFIG_C,
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
   mkAxiSTransportLayer_1 : mkAxiSTransportLayer
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
         s_meta_data_tvalid         => s_axisMetaDataReqMasterMux.tValid,
         s_meta_data_tdata          => s_axisMetaDataReqMasterMux.tData(302 downto 0),
         s_meta_data_tready         => s_axisMetaDataReqSlaveMux.tReady,
         m_meta_data_tvalid         => s_axisMetaDataRespMasterMux.tValid,
         m_meta_data_tdata          => s_axisMetaDataRespMasterMux.tData(275 downto 0),
         m_meta_data_tready         => s_axisMetaDataRespSlaveMux.tReady,
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
         s_dma_read_ready           => dmaReadRespSlave.ready);

   -----------------------------------------------------------------------------
   -- RoCE Metadata Configurator
   -----------------------------------------------------------------------------
   ROCE_EXT_CONFIG_GEN : if EXT_ROCE_CONFIG_G generate
      s_axisMetaDataReqMaster <= AXI_STREAM_MASTER_INIT_C;
      s_axisMetaDataRespSlave <= AXI_STREAM_SLAVE_FORCE_C;
      axilReadSlave           <= AXI_LITE_READ_SLAVE_EMPTY_DECERR_C;
      axilWriteSlave          <= AXI_LITE_WRITE_SLAVE_EMPTY_DECERR_C;
   end generate ROCE_EXT_CONFIG_GEN;

   ROCE_INT_CONFIG_GEN : if not EXT_ROCE_CONFIG_G generate
      RoceConfigurator_1 : entity surf.RoceConfigurator
         generic map (
            TPD_G => TPD_G)
         port map (
            clk                       => clk,
            rst                       => rst,
            mAxisMetaDataReqMaster_o  => s_axisMetaDataReqMaster,
            mAxisMetaDataReqSlave_i   => s_axisMetaDataReqSlave,
            sAxisMetaDataRespMaster_i => s_axisMetaDataRespMaster,
            sAxisMetaDataRespSlave_o  => s_axisMetaDataRespSlave,
            axilReadMaster            => axilReadMaster,
            axilReadSlave             => axilReadSlave,
            axilWriteMaster           => axilWriteMaster,
            axilWriteSlave            => axilWriteSlave);
   end generate ROCE_INT_CONFIG_GEN;

   -----------------------------------------------------------------------------
   -- Axi-Stream Metadata source selection
   -----------------------------------------------------------------------------
   metaSel : process (mAxisMetaDataSlave, sAxisMetaDataMaster,
                      s_axisMetaDataReqMaster, s_axisMetaDataReqSlaveMux,
                      s_axisMetaDataRespMasterMux, s_axisMetaDataRespSlave) is
   begin  -- process metadata_source_select
      if EXT_ROCE_CONFIG_G then
         s_axisMetaDataReqMasterMux <= sAxisMetaDataMaster;
         sAxisMetaDataSlave         <= s_axisMetaDataReqSlaveMux;
         mAxisMetaDataMaster        <= s_axisMetaDataRespMasterMux;
         s_axisMetaDataRespSlaveMux <= mAxisMetaDataSlave;
      else
         s_axisMetaDataReqMasterMux <= s_axisMetaDataReqMaster;
         s_axisMetaDataReqSlave     <= s_axisMetaDataReqSlaveMux;
         s_axisMetaDataRespMaster   <= s_axisMetaDataRespMasterMux;
         s_axisMetaDataRespSlaveMux <= s_axisMetaDataRespSlave;
      end if;
   end process metaSel;

end mapping;
