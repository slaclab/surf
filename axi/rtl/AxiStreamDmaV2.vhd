-------------------------------------------------------------------------------
-- Title      : AXI Stream DMA Controller, Version 2
-- Project    : General Purpose Core
-------------------------------------------------------------------------------
-- File       : AxiStreamDmaV2.vhd
-- Created    : 2017-02-02
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-- Generic AXI Stream DMA block for frame at a time transfers.
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.AxiLitePkg.all;
use work.AxiPkg.all;
use work.AxiDmaPkg.all;

entity AxiStreamDmaV2 is
   generic (
      TPD_G             : time                   := 1 ns;
      DESC_AWIDTH_G     : integer range 4 to 12  := 12;
      AXIL_BASE_ADDR_G  : slv(31 downto 0)       := x"00000000";
      AXI_ERROR_RESP_G  : slv(1 downto 0)        := AXI_RESP_OK_C;
      AXI_READY_EN_G    : boolean                := false;
      AXIS_READY_EN_G   : boolean                := false;
      AXIS_CONFIG_G     : AxiStreamConfigType    := AXI_STREAM_CONFIG_INIT_C;
      AXI_DESC_CONFIG_G : AxiConfigType          := AXI_CONFIG_INIT_C;
      AXI_DESC_BURST_G  : slv(1 downto 0)        := "01";
      AXI_DESC_CACHE_G  : slv(3 downto 0)        := "1111";
      AXI_DMA_CONFIG_G  : AxiConfigType          := AXI_CONFIG_INIT_C;
      AXI_DMA_BURST_G   : slv(1 downto 0)        := "01";
      AXI_DMA_CACHE_G   : slv(3 downto 0)        := "1111");
   port (
      -- Clock/Reset
      axiClk          : in  sl;
      axiRst          : in  sl;
      -- Register Access & Interrupt
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      interrupt       : out sl;
      online          : out sl;
      acknowledge     : out sl;
      -- AXI Stream Interface 
      sAxisMaster     : in  AxiStreamMasterType;
      sAxisSlave      : out AxiStreamSlaveType;
      mAxisMaster     : out AxiStreamMasterType;
      mAxisSlave      : in  AxiStreamSlaveType;
      mAxisCtrl       : in  AxiStreamCtrlType;
      -- AXI Interfaces, 0 = Desc, 1 = DMA
      axiReadMaster   : out AxiReadMasterArray(1 downto 0);
      axiReadSlave    : in  AxiReadSlaveArray(1 downto 0);
      axiWriteMaster  : out AxiWriteMasterArray(1 downto 0);
      axiWriteSlave   : in  AxiWriteSlaveArray(1 downto 0);
      axiWriteCtrl    : in  AxiCtrlArray(1 downto 0));
end AxiStreamDmaV2;

architecture structure of AxiStreamDmaV2 is

   signal dmaWrDescReq      : AxiWriteDmaDescReqType;
   signal dmaWrDescAck      : AxiWriteDmaDescAckType;
   signal dmaWrDescRet      : AxiWriteDmaDescRetType;
   signal dmaWrDescRetAck   : sl;

   signal dmaRdDescReq      : AxiReadDmaDescReqType;
   signal dmaRdDescAck      : sl;
   signal dmaRdDescRet      : AxiReadDmaDescRetType;
   signal dmaRdDescRetAck   : sl;

begin

   U_DmaDesc: entity work.AxiStreamDmaV2Desc
      generic map (
         TPD_G                 => TPD_G,
         CHAN_COUNT_G          => 1,
         AXIL_BASE_ADDR_G      => AXIL_BASE_ADDR_G,
         AXI_READY_EN_G        => AXI_READY_EN_G,
         AXI_CONFIG_G          => AXI_DESC_CONFIG_G,
         AXI_BURST_G           => AXI_DESC_BURST_G,
         AXI_CACHE_G           => AXI_DESC_CACHE_G,
         DESC_AWIDTH_G         => DESC_AWIDTH_G)
      port map (
         -- Clock/Reset
         axiClk             => axiClk,
         axiRst             => axiRst,
         axilReadMaster     => axilReadMaster,
         axilReadSlave      => axilReadSlave,
         axilWriteMaster    => axilWriteMaster,
         axilWriteSlave     => axilWriteSlave,
         interrupt          => interrupt,
         online             => online,
         acknowledge        => acknowledge,
         dmaWrDescReq(0)    => dmaWrDescReq,
         dmaWrDescAck(0)    => dmaWrDescAck,
         dmaWrDescRet(0)    => dmaWrDescRet,
         dmaWrDescRetAck(0) => dmaWrDescRetAck,
         dmaRdDescReq(0)    => dmaRdDescReq,
         dmaRdDescAck(0)    => dmaRdDescAck,
         dmaRdDescRet(0)    => dmaRdDescRet,
         dmaRdDescRetAck(0) => dmaRdDescRetAck,
         axiWriteMaster     => axiWriteMaster(0),
         axiWriteSlave      => axiWriteSlave(0),
         axiWriteCtrl       => axiWriteCtrl(0));

   sAxisSlave         <= AXI_STREAM_SLAVE_INIT_C;
   axiWriteMaster(1)  <= AXI_WRITE_MASTER_INIT_C;

   U_DmaRead: entity work.AxiStreamDmaV2Read 
      generic map (
         TPD_G           => TPD_G,
         AXIS_READY_EN_G => AXIS_READY_EN_G,
         AXIS_CONFIG_G   => AXIS_CONFIG_G,
         AXI_CONFIG_G    => AXI_DMA_CONFIG_G,
         AXI_BURST_G     => AXI_DMA_BURST_G,
         AXI_CACHE_G     => AXI_DMA_CACHE_G,
         PIPE_STAGES_G   => 1,
         PEND_THRESH_G   => 0)
      port map (
         axiClk             => axiClk,
         axiRst             => axiRst,
         dmaRdDescReq       => dmaRdDescReq,
         dmaRdDescAck       => dmaRdDescAck,
         dmaRdDescRet       => dmaRdDescRet,
         dmaRdDescRetAck    => dmaRdDescRetAck,
         dmaRdIdle          => open,
         -- Streaming Interface 
         axisMaster      => mAxisMaster,
         axisSlave       => mAxisSlave,
         axisCtrl        => mAxisCtrl,
         axiReadMaster   => axiReadMaster(1),
         axiReadSlave    => axiReadSlave(1));

   dmaWrDescReq <= AXI_WRITE_DMA_DESC_REQ_INIT_C;
   dmaWrDescRet <= AXI_WRITE_DMA_DESC_RET_INIT_C;

end structure;

