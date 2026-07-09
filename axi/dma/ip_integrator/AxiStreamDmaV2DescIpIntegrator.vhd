-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: IP Integrator Wrapper for surf.AxiStreamDmaV2Desc
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
use surf.AxiPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiDmaPkg.all;

entity AxiStreamDmaV2DescIpIntegrator is
   generic (
      TPD_G : time := 1 ns);
   port (
      axiClk                 : in  sl;
      axiRst                 : in  sl;
      interrupt              : out sl;
      online                 : out sl;
      acknowledge            : out sl;
      axiRdCache             : out slv(3 downto 0);
      axiWrCache             : out slv(3 downto 0);
      buffGrpPause           : out slv(7 downto 0);
      dmaWrDescReqValid      : in  sl;
      dmaWrDescReqId         : in  slv(7 downto 0);
      dmaWrDescReqDest       : in  slv(7 downto 0);
      dmaWrDescAckValid      : out sl;
      dmaWrDescAckAddress    : out slv(63 downto 0);
      dmaWrDescAckMetaEnable : out sl;
      dmaWrDescAckMetaAddr   : out slv(63 downto 0);
      dmaWrDescAckDropEn     : out sl;
      dmaWrDescAckMaxSize    : out slv(31 downto 0);
      dmaWrDescAckContEn     : out sl;
      dmaWrDescAckBuffId     : out slv(31 downto 0);
      dmaWrDescAckTimeout    : out slv(31 downto 0);
      dmaWrDescRetValid      : in  sl;
      dmaWrDescRetBuffId     : in  slv(31 downto 0);
      dmaWrDescRetFirstUser  : in  slv(7 downto 0);
      dmaWrDescRetLastUser   : in  slv(7 downto 0);
      dmaWrDescRetSize       : in  slv(31 downto 0);
      dmaWrDescRetContinue   : in  sl;
      dmaWrDescRetResult     : in  slv(3 downto 0);
      dmaWrDescRetDest       : in  slv(7 downto 0);
      dmaWrDescRetId         : in  slv(7 downto 0);
      dmaWrDescRetAck        : out sl;
      dmaRdDescReqValid      : out sl;
      dmaRdDescReqAddress    : out slv(63 downto 0);
      dmaRdDescReqBuffId     : out slv(31 downto 0);
      dmaRdDescReqFirstUser  : out slv(7 downto 0);
      dmaRdDescReqLastUser   : out slv(7 downto 0);
      dmaRdDescReqSize       : out slv(31 downto 0);
      dmaRdDescReqContinue   : out sl;
      dmaRdDescReqId         : out slv(7 downto 0);
      dmaRdDescReqDest       : out slv(7 downto 0);
      dmaRdDescAck           : in  sl;
      dmaRdDescRetValid      : in  sl;
      dmaRdDescRetBuffId     : in  slv(31 downto 0);
      dmaRdDescRetResult     : in  slv(2 downto 0);
      dmaRdDescRetAck        : out sl;
      S_AXI_AWADDR           : in  slv(11 downto 0);
      S_AXI_AWPROT           : in  slv(2 downto 0);
      S_AXI_AWVALID          : in  sl;
      S_AXI_AWREADY          : out sl;
      S_AXI_WDATA            : in  slv(31 downto 0);
      S_AXI_WSTRB            : in  slv(3 downto 0);
      S_AXI_WVALID           : in  sl;
      S_AXI_WREADY           : out sl;
      S_AXI_BRESP            : out slv(1 downto 0);
      S_AXI_BVALID           : out sl;
      S_AXI_BREADY           : in  sl;
      S_AXI_ARADDR           : in  slv(11 downto 0);
      S_AXI_ARPROT           : in  slv(2 downto 0);
      S_AXI_ARVALID          : in  sl;
      S_AXI_ARREADY          : out sl;
      S_AXI_RDATA            : out slv(31 downto 0);
      S_AXI_RRESP            : out slv(1 downto 0);
      S_AXI_RVALID           : out sl;
      S_AXI_RREADY           : in  sl;
      M_AXI_AWID             : out slv(7 downto 0);
      M_AXI_AWADDR           : out slv(15 downto 0);
      M_AXI_AWLEN            : out slv(7 downto 0);
      M_AXI_AWSIZE           : out slv(2 downto 0);
      M_AXI_AWBURST          : out slv(1 downto 0);
      M_AXI_AWLOCK           : out sl;
      M_AXI_AWCACHE          : out slv(3 downto 0);
      M_AXI_AWPROT           : out slv(2 downto 0);
      M_AXI_AWREGION         : out slv(3 downto 0);
      M_AXI_AWQOS            : out slv(3 downto 0);
      M_AXI_AWVALID          : out sl;
      M_AXI_AWREADY          : in  sl;
      M_AXI_WID              : out slv(7 downto 0);
      M_AXI_WDATA            : out slv(127 downto 0);
      M_AXI_WSTRB            : out slv(15 downto 0);
      M_AXI_WLAST            : out sl;
      M_AXI_WVALID           : out sl;
      M_AXI_WREADY           : in  sl;
      M_AXI_BID              : in  slv(7 downto 0);
      M_AXI_BRESP            : in  slv(1 downto 0);
      M_AXI_BVALID           : in  sl;
      M_AXI_BREADY           : out sl);
end entity AxiStreamDmaV2DescIpIntegrator;

architecture rtl of AxiStreamDmaV2DescIpIntegrator is

   constant AXI_CONFIG_C : AxiConfigType := axiConfig(
      ADDR_WIDTH_C => 16,
      DATA_BYTES_C => 8,
      ID_BITS_C    => 8,
      LEN_BITS_C   => 8);

   signal axiResetN          : sl                     := '1';
   signal mAxiAwLock         : slv(1 downto 0)        := (others => '0');
   signal axilReadMaster     : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave      : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal axilWriteMaster    : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave     : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;
   signal onlineVec          : slv(0 downto 0);
   signal acknowledgeVec     : slv(0 downto 0);
   signal dmaWrDescReq       : AxiWriteDmaDescReqArray(0 downto 0);
   signal dmaWrDescAck       : AxiWriteDmaDescAckArray(0 downto 0);
   signal dmaWrDescRet       : AxiWriteDmaDescRetArray(0 downto 0);
   signal dmaWrDescRetAckVec : slv(0 downto 0);
   signal dmaRdDescReq       : AxiReadDmaDescReqArray(0 downto 0);
   signal dmaRdDescAckVec    : slv(0 downto 0);
   signal dmaRdDescRet       : AxiReadDmaDescRetArray(0 downto 0);
   signal dmaRdDescRetAckVec : slv(0 downto 0);
   signal axiWriteMasters    : AxiWriteMasterArray(0 downto 0);
   signal axiWriteSlaves     : AxiWriteSlaveArray(0 downto 0);

begin

   ---------------------------------------------------------------------------
   -- Flatten the single exposed descriptor-engine lane
   ---------------------------------------------------------------------------
   axiResetN    <= not axiRst;
   M_AXI_AWLOCK <= mAxiAwLock(0);

   dmaWrDescReq(0).valid     <= dmaWrDescReqValid;
   dmaWrDescReq(0).id        <= dmaWrDescReqId;
   dmaWrDescReq(0).dest      <= dmaWrDescReqDest;
   dmaWrDescRet(0).valid     <= dmaWrDescRetValid;
   dmaWrDescRet(0).buffId    <= dmaWrDescRetBuffId;
   dmaWrDescRet(0).firstUser <= dmaWrDescRetFirstUser;
   dmaWrDescRet(0).lastUser  <= dmaWrDescRetLastUser;
   dmaWrDescRet(0).size      <= dmaWrDescRetSize;
   dmaWrDescRet(0).continue  <= dmaWrDescRetContinue;
   dmaWrDescRet(0).result    <= dmaWrDescRetResult;
   dmaWrDescRet(0).dest      <= dmaWrDescRetDest;
   dmaWrDescRet(0).id        <= dmaWrDescRetId;
   dmaRdDescAckVec(0)        <= dmaRdDescAck;
   dmaRdDescRet(0).valid     <= dmaRdDescRetValid;
   dmaRdDescRet(0).buffId    <= dmaRdDescRetBuffId;
   dmaRdDescRet(0).result    <= dmaRdDescRetResult;

   dmaWrDescAckValid      <= dmaWrDescAck(0).valid;
   dmaWrDescAckAddress    <= dmaWrDescAck(0).address;
   dmaWrDescAckMetaEnable <= dmaWrDescAck(0).metaEnable;
   dmaWrDescAckMetaAddr   <= dmaWrDescAck(0).metaAddr;
   dmaWrDescAckDropEn     <= dmaWrDescAck(0).dropEn;
   dmaWrDescAckMaxSize    <= dmaWrDescAck(0).maxSize;
   dmaWrDescAckContEn     <= dmaWrDescAck(0).contEn;
   dmaWrDescAckBuffId     <= dmaWrDescAck(0).buffId;
   dmaWrDescAckTimeout    <= dmaWrDescAck(0).timeout;
   dmaWrDescRetAck        <= dmaWrDescRetAckVec(0);
   dmaRdDescReqValid      <= dmaRdDescReq(0).valid;
   dmaRdDescReqAddress    <= dmaRdDescReq(0).address;
   dmaRdDescReqBuffId     <= dmaRdDescReq(0).buffId;
   dmaRdDescReqFirstUser  <= dmaRdDescReq(0).firstUser;
   dmaRdDescReqLastUser   <= dmaRdDescReq(0).lastUser;
   dmaRdDescReqSize       <= dmaRdDescReq(0).size;
   dmaRdDescReqContinue   <= dmaRdDescReq(0).continue;
   dmaRdDescReqId         <= dmaRdDescReq(0).id;
   dmaRdDescReqDest       <= dmaRdDescReq(0).dest;
   dmaRdDescRetAck        <= dmaRdDescRetAckVec(0);
   online                 <= onlineVec(0);
   acknowledge            <= acknowledgeVec(0);

   ---------------------------------------------------------------------------
   -- AXI-Lite and AXI shims
   ---------------------------------------------------------------------------
   U_AXIL : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         HAS_PROT      => 1,
         HAS_WSTRB     => 1,
         ADDR_WIDTH    => 12)
      port map (
         S_AXI_ACLK      => axiClk,
         S_AXI_ARESETN   => axiResetN,
         S_AXI_AWADDR    => S_AXI_AWADDR,
         S_AXI_AWPROT    => S_AXI_AWPROT,
         S_AXI_AWVALID   => S_AXI_AWVALID,
         S_AXI_AWREADY   => S_AXI_AWREADY,
         S_AXI_WDATA     => S_AXI_WDATA,
         S_AXI_WSTRB     => S_AXI_WSTRB,
         S_AXI_WVALID    => S_AXI_WVALID,
         S_AXI_WREADY    => S_AXI_WREADY,
         S_AXI_BRESP     => S_AXI_BRESP,
         S_AXI_BVALID    => S_AXI_BVALID,
         S_AXI_BREADY    => S_AXI_BREADY,
         S_AXI_ARADDR    => S_AXI_ARADDR,
         S_AXI_ARPROT    => S_AXI_ARPROT,
         S_AXI_ARVALID   => S_AXI_ARVALID,
         S_AXI_ARREADY   => S_AXI_ARREADY,
         S_AXI_RDATA     => S_AXI_RDATA,
         S_AXI_RRESP     => S_AXI_RRESP,
         S_AXI_RVALID    => S_AXI_RVALID,
         S_AXI_RREADY    => S_AXI_RREADY,
         axilClk         => open,
         axilRst         => open,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

   U_M_AXI : entity surf.MasterAxiIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         ID_WIDTH      => 8,
         ADDR_WIDTH    => 16,
         DATA_WIDTH    => 128)
      port map (
         M_AXI_ACLK     => axiClk,
         M_AXI_ARESETN  => axiResetN,
         M_AXI_AWID     => M_AXI_AWID,
         M_AXI_AWADDR   => M_AXI_AWADDR,
         M_AXI_AWLEN    => M_AXI_AWLEN,
         M_AXI_AWSIZE   => M_AXI_AWSIZE,
         M_AXI_AWBURST  => M_AXI_AWBURST,
         M_AXI_AWLOCK   => mAxiAwLock,
         M_AXI_AWCACHE  => M_AXI_AWCACHE,
         M_AXI_AWPROT   => M_AXI_AWPROT,
         M_AXI_AWREGION => M_AXI_AWREGION,
         M_AXI_AWQOS    => M_AXI_AWQOS,
         M_AXI_AWVALID  => M_AXI_AWVALID,
         M_AXI_AWREADY  => M_AXI_AWREADY,
         M_AXI_WID      => M_AXI_WID,
         M_AXI_WDATA    => M_AXI_WDATA,
         M_AXI_WSTRB    => M_AXI_WSTRB,
         M_AXI_WLAST    => M_AXI_WLAST,
         M_AXI_WVALID   => M_AXI_WVALID,
         M_AXI_WREADY   => M_AXI_WREADY,
         M_AXI_BID      => M_AXI_BID,
         M_AXI_BRESP    => M_AXI_BRESP,
         M_AXI_BVALID   => M_AXI_BVALID,
         M_AXI_BREADY   => M_AXI_BREADY,
         M_AXI_ARID     => open,
         M_AXI_ARADDR   => open,
         M_AXI_ARLEN    => open,
         M_AXI_ARSIZE   => open,
         M_AXI_ARBURST  => open,
         M_AXI_ARLOCK   => open,
         M_AXI_ARCACHE  => open,
         M_AXI_ARPROT   => open,
         M_AXI_ARREGION => open,
         M_AXI_ARQOS    => open,
         M_AXI_ARVALID  => open,
         M_AXI_ARREADY  => '0',
         M_AXI_RID      => (others => '0'),
         M_AXI_RDATA    => (others => '0'),
         M_AXI_RRESP    => (others => '0'),
         M_AXI_RLAST    => '0',
         M_AXI_RVALID   => '0',
         M_AXI_RREADY   => open,
         axiClk         => open,
         axiRst         => open,
         axiReadMaster  => AXI_READ_MASTER_INIT_C,
         axiReadSlave   => open,
         axiWriteMaster => axiWriteMasters(0),
         axiWriteSlave  => axiWriteSlaves(0));

   ---------------------------------------------------------------------------
   -- DUT
   ---------------------------------------------------------------------------
   U_DUT : entity surf.AxiStreamDmaV2Desc
      generic map (
         TPD_G        => TPD_G,
         CHAN_COUNT_G => 1,
         AXI_CONFIG_G => AXI_CONFIG_C)
      port map (
         axiClk          => axiClk,
         axiRst          => axiRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave,
         interrupt       => interrupt,
         online          => onlineVec,
         acknowledge     => acknowledgeVec,
         dmaWrDescReq    => dmaWrDescReq,
         dmaWrDescAck    => dmaWrDescAck,
         dmaWrDescRet    => dmaWrDescRet,
         dmaWrDescRetAck => dmaWrDescRetAckVec,
         dmaRdDescReq    => dmaRdDescReq,
         dmaRdDescAck    => dmaRdDescAckVec,
         dmaRdDescRet    => dmaRdDescRet,
         dmaRdDescRetAck => dmaRdDescRetAckVec,
         axiRdCache      => axiRdCache,
         axiWrCache      => axiWrCache,
         axiWriteMasters => axiWriteMasters,
         axiWriteSlaves  => axiWriteSlaves,
         buffGrpPause    => buffGrpPause);

end architecture rtl;
