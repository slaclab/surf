-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for RoCEv2AxiStreamRdmaCore.
--
--   Flattens the VHDL record ports (AXI-Stream, RoCEv2 workReq/dmaReadReq/
--   dmaReadResp/workComp, AXI-Lite) into plain std_logic/std_logic_vector ports
--   so a cocotb testbench can drive/observe every channel. The bench emulates the
--   surf RoCEv2 engine side, so it wraps the host-logic CORE (whose work/DMA/comp
--   records are ports); the full RoCEv2AxiStreamRdma embeds the engine and exposes
--   only the UDP datapath. The DUT is wired single-clock (roceClk = clk) at the
--   default 32-byte RoCEv2 stream width. The AXI-Lite shim mirrors RoceConfiguratorWrapper.
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
use surf.SsiPkg.all;
use surf.AxiLitePkg.all;
use surf.RoCEv2Pkg.all;

entity RoCEv2AxiStreamRdmaCoreWrapper is
   generic (
      TPD_G : time := 1 ns);
   port (
      clk                       : in  sl;
      rst                       : in  sl;
      -- Inbound payload stream (TB AxiStreamSource drives; 32-byte beats)
      S_AXIS_TVALID             : in  sl;
      S_AXIS_TDATA              : in  slv(255 downto 0);
      S_AXIS_TKEEP              : in  slv(31 downto 0);
      S_AXIS_TLAST              : in  sl;
      S_AXIS_TREADY             : out sl;
      -- workReq (module -> engine); TB observes + drives ready
      M_WORKREQ_VALID           : out sl;
      M_WORKREQ_READY           : in  sl;
      M_WORKREQ_ID              : out slv(63 downto 0);
      M_WORKREQ_OPCODE          : out slv(3 downto 0);
      M_WORKREQ_FLAGS           : out slv(4 downto 0);
      M_WORKREQ_RADDR           : out slv(63 downto 0);
      M_WORKREQ_RKEY            : out slv(31 downto 0);
      M_WORKREQ_LEN             : out slv(31 downto 0);
      M_WORKREQ_SQPN            : out slv(23 downto 0);
      M_WORKREQ_IMMDT           : out slv(32 downto 0);
      -- dmaReadReq (engine -> module); TB drives valid+fields, observes ready
      S_DMAREADREQ_VALID        : in  sl;
      S_DMAREADREQ_READY        : out sl;
      S_DMAREADREQ_INITIATOR    : in  slv(3 downto 0);
      S_DMAREADREQ_SQPN         : in  slv(23 downto 0);
      S_DMAREADREQ_WRID         : in  slv(63 downto 0);
      S_DMAREADREQ_STARTADDR    : in  slv(63 downto 0);
      S_DMAREADREQ_LEN          : in  slv(12 downto 0);
      S_DMAREADREQ_MRIDX        : in  sl;
      -- dmaReadResp (module -> engine); TB observes valid+data, drives ready
      M_DMAREADRESP_VALID       : out sl;
      M_DMAREADRESP_READY       : in  sl;
      M_DMAREADRESP_DATASTREAM  : out slv(289 downto 0);
      M_DMAREADRESP_ISRESPERR   : out sl;
      M_DMAREADRESP_WRID        : out slv(63 downto 0);
      M_DMAREADRESP_SQPN        : out slv(23 downto 0);
      M_DMAREADRESP_INITIATOR   : out slv(3 downto 0);
      -- workComp (engine -> module); TB drives valid+status, observes ready
      S_WORKCOMP_VALID          : in  sl;
      S_WORKCOMP_READY          : out sl;
      S_WORKCOMP_STATUS         : in  slv(4 downto 0);
      S_WORKCOMP_ID             : in  slv(63 downto 0);
      -- AXI-Lite (cocotbext-axi AxiLiteMaster drives the AXI4-Lite bus)
      S_AXIL_AWADDR             : in  slv(31 downto 0);
      S_AXIL_AWPROT             : in  slv(2 downto 0);
      S_AXIL_AWVALID            : in  sl;
      S_AXIL_AWREADY            : out sl;
      S_AXIL_WDATA              : in  slv(31 downto 0);
      S_AXIL_WSTRB              : in  slv(3 downto 0);
      S_AXIL_WVALID             : in  sl;
      S_AXIL_WREADY             : out sl;
      S_AXIL_BRESP              : out slv(1 downto 0);
      S_AXIL_BVALID             : out sl;
      S_AXIL_BREADY             : in  sl;
      S_AXIL_ARADDR             : in  slv(31 downto 0);
      S_AXIL_ARPROT             : in  slv(2 downto 0);
      S_AXIL_ARVALID            : in  sl;
      S_AXIL_ARREADY            : out sl;
      S_AXIL_RDATA              : out slv(31 downto 0);
      S_AXIL_RRESP              : out slv(1 downto 0);
      S_AXIL_RVALID             : out sl;
      S_AXIL_RREADY             : in  sl);
end entity RoCEv2AxiStreamRdmaCoreWrapper;

architecture rtl of RoCEv2AxiStreamRdmaCoreWrapper is

   signal axilClk         : sl;
   signal axilRst         : sl;
   signal axilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal axilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;

   signal sAxisMaster       : AxiStreamMasterType        := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave        : AxiStreamSlaveType         := AXI_STREAM_SLAVE_INIT_C;
   signal dmaReadReqMaster  : RoCEv2DmaReadReqMasterType   := ROCE_DMA_READ_REQ_MASTER_INIT_C;
   signal dmaReadReqSlave   : RoCEv2DmaReadReqSlaveType    := ROCE_DMA_READ_REQ_SLAVE_INIT_C;
   signal dmaReadRespMaster : RoCEv2DmaReadRespMasterType  := ROCE_DMA_READ_RESP_MASTER_INIT_C;
   signal dmaReadRespSlave  : RoCEv2DmaReadRespSlaveType   := ROCE_DMA_READ_RESP_SLAVE_INIT_C;
   signal workReqMaster     : RoCEv2WorkReqMasterType      := ROCE_WORK_REQ_MASTER_INIT_C;
   signal workReqSlave      : RoCEv2WorkReqSlaveType       := ROCE_WORK_REQ_SLAVE_INIT_C;
   signal workCompMaster    : RoCEv2WorkCompMasterType     := ROCE_WORK_COMP_MASTER_INIT_C;
   signal workCompSlave     : RoCEv2WorkCompSlaveType      := ROCE_WORK_COMP_SLAVE_INIT_C;

begin

   ----------------------------------------------------------------------------
   -- AXI-Lite shim (flat AXI4-Lite <-> AxiLite record)
   ----------------------------------------------------------------------------
   U_ShimLayer : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         FREQ_HZ       => 156250000,
         ADDR_WIDTH    => 32)
      port map (
         S_AXI_ACLK      => clk,
         S_AXI_ARESETN   => not rst,
         S_AXI_AWADDR    => S_AXIL_AWADDR,
         S_AXI_AWPROT    => S_AXIL_AWPROT,
         S_AXI_AWVALID   => S_AXIL_AWVALID,
         S_AXI_AWREADY   => S_AXIL_AWREADY,
         S_AXI_WDATA     => S_AXIL_WDATA,
         S_AXI_WSTRB     => S_AXIL_WSTRB,
         S_AXI_WVALID    => S_AXIL_WVALID,
         S_AXI_WREADY    => S_AXIL_WREADY,
         S_AXI_BRESP     => S_AXIL_BRESP,
         S_AXI_BVALID    => S_AXIL_BVALID,
         S_AXI_BREADY    => S_AXIL_BREADY,
         S_AXI_ARADDR    => S_AXIL_ARADDR,
         S_AXI_ARPROT    => S_AXIL_ARPROT,
         S_AXI_ARVALID   => S_AXIL_ARVALID,
         S_AXI_ARREADY   => S_AXIL_ARREADY,
         S_AXI_RDATA     => S_AXIL_RDATA,
         S_AXI_RRESP     => S_AXIL_RRESP,
         S_AXI_RVALID    => S_AXIL_RVALID,
         S_AXI_RREADY    => S_AXIL_RREADY,
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

   ----------------------------------------------------------------------------
   -- Record <-> flat packing
   ----------------------------------------------------------------------------
   -- Slave payload stream (TB drives)
   sAxisComb : process (S_AXIS_TVALID, S_AXIS_TDATA, S_AXIS_TKEEP, S_AXIS_TLAST) is
      variable v : AxiStreamMasterType;
   begin
      v                     := AXI_STREAM_MASTER_INIT_C;
      v.tValid              := S_AXIS_TVALID;
      v.tData(255 downto 0) := S_AXIS_TDATA;
      v.tKeep(31 downto 0)  := S_AXIS_TKEEP;
      v.tLast               := S_AXIS_TLAST;
      sAxisMaster           <= v;
   end process sAxisComb;
   S_AXIS_TREADY <= sAxisSlave.tReady;

   -- workReq (module -> engine)
   M_WORKREQ_VALID  <= workReqMaster.valid;
   M_WORKREQ_ID     <= workReqMaster.id;
   M_WORKREQ_OPCODE <= workReqMaster.opCode;
   M_WORKREQ_FLAGS  <= workReqMaster.flags;
   M_WORKREQ_RADDR  <= workReqMaster.rAddr;
   M_WORKREQ_RKEY   <= workReqMaster.rKey;
   M_WORKREQ_LEN    <= workReqMaster.len;
   M_WORKREQ_SQPN   <= workReqMaster.sQpn;
   M_WORKREQ_IMMDT  <= workReqMaster.immDt;
   workReqSlave.ready <= M_WORKREQ_READY;

   -- dmaReadReq (engine -> module; TB drives)
   dmaReadReqComb : process (S_DMAREADREQ_VALID, S_DMAREADREQ_INITIATOR, S_DMAREADREQ_SQPN,
                             S_DMAREADREQ_WRID, S_DMAREADREQ_STARTADDR, S_DMAREADREQ_LEN,
                             S_DMAREADREQ_MRIDX) is
      variable v : RoCEv2DmaReadReqMasterType;
   begin
      v           := ROCE_DMA_READ_REQ_MASTER_INIT_C;
      v.valid     := S_DMAREADREQ_VALID;
      v.initiator := S_DMAREADREQ_INITIATOR;
      v.sQpn      := S_DMAREADREQ_SQPN;
      v.wrId      := S_DMAREADREQ_WRID;
      v.startAddr := S_DMAREADREQ_STARTADDR;
      v.len       := S_DMAREADREQ_LEN;
      v.mrIdx     := S_DMAREADREQ_MRIDX;
      dmaReadReqMaster <= v;
   end process dmaReadReqComb;
   S_DMAREADREQ_READY <= dmaReadReqSlave.ready;

   -- dmaReadResp (module -> engine)
   M_DMAREADRESP_VALID      <= dmaReadRespMaster.valid;
   M_DMAREADRESP_DATASTREAM <= dmaReadRespMaster.dataStream;
   M_DMAREADRESP_ISRESPERR  <= dmaReadRespMaster.isRespErr;
   M_DMAREADRESP_WRID       <= dmaReadRespMaster.wrId;
   M_DMAREADRESP_SQPN       <= dmaReadRespMaster.sQpn;
   M_DMAREADRESP_INITIATOR  <= dmaReadRespMaster.initiator;
   dmaReadRespSlave.ready   <= M_DMAREADRESP_READY;

   -- workComp (engine -> module; TB drives)
   workCompComb : process (S_WORKCOMP_VALID, S_WORKCOMP_STATUS, S_WORKCOMP_ID) is
      variable v : RoCEv2WorkCompMasterType;
   begin
      v        := ROCE_WORK_COMP_MASTER_INIT_C;
      v.valid  := S_WORKCOMP_VALID;
      v.status := S_WORKCOMP_STATUS;
      v.id     := S_WORKCOMP_ID;
      workCompMaster <= v;
   end process workCompComb;
   S_WORKCOMP_READY <= workCompSlave.ready;

   ----------------------------------------------------------------------------
   -- DUT: the host-logic core (single-clock: roceClk = clk). The bench drives the
   -- work/DMA/comp records directly, emulating the engine side.
   ----------------------------------------------------------------------------
   U_DUT : entity surf.RoCEv2AxiStreamRdmaCore
      generic map (
         TPD_G         => TPD_G,
         AXIS_CONFIG_G => ssiAxiStreamConfig(dataBytes => TDATA_ROCE_NUM_BYTES_C, tKeepMode => TKEEP_NORMAL_C, tDestBits => 0))
      port map (
         roceClk           => clk,
         roceRst           => rst,
         sAxisMaster       => sAxisMaster,
         sAxisSlave        => sAxisSlave,
         workReqMaster     => workReqMaster,
         workReqSlave      => workReqSlave,
         workCompMaster    => workCompMaster,
         workCompSlave     => workCompSlave,
         dmaReadReqMaster  => dmaReadReqMaster,
         dmaReadReqSlave   => dmaReadReqSlave,
         dmaReadRespMaster => dmaReadRespMaster,
         dmaReadRespSlave  => dmaReadRespSlave,
         axilReadMaster    => axilReadMaster,
         axilReadSlave     => axilReadSlave,
         axilWriteMaster   => axilWriteMaster,
         axilWriteSlave    => axilWriteSlave);

end architecture rtl;
