-------------------------------------------------------------------------------
-- File       : AxiStreamDmaV2.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-02-02
-- Last update: 2017-02-02
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
      TPD_G             : time                    := 1 ns;
      DESC_AWIDTH_G     : integer range 4 to 12   := 12;
      AXIL_BASE_ADDR_G  : slv(31 downto 0)        := x"00000000";
      AXI_ERROR_RESP_G  : slv(1 downto 0)         := AXI_RESP_OK_C;
      AXI_READY_EN_G    : boolean                 := false;
      AXIS_READY_EN_G   : boolean                 := false;
      AXIS_CONFIG_G     : AxiStreamConfigType     := AXI_STREAM_CONFIG_INIT_C;
      AXI_DESC_CONFIG_G : AxiConfigType           := AXI_CONFIG_INIT_C;
      AXI_DMA_CONFIG_G  : AxiConfigType           := AXI_CONFIG_INIT_C;
      CHAN_COUNT_G      : integer range 1 to 16   := 1;
      BURST_BYTES_G     : integer range 1 to 4096 := 4096;
      RD_PIPE_STAGES_G  : natural                 := 1;
      RD_PEND_THRESH_G  : natural                 := 0);  -- In units of bytes
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
      online          : out slv(CHAN_COUNT_G-1 downto 0);
      acknowledge     : out slv(CHAN_COUNT_G-1 downto 0);
      -- AXI Stream Interface 
      sAxisMaster     : in  AxiStreamMasterArray(CHAN_COUNT_G-1 downto 0);
      sAxisSlave      : out AxiStreamSlaveArray(CHAN_COUNT_G-1 downto 0);
      mAxisMaster     : out AxiStreamMasterArray(CHAN_COUNT_G-1 downto 0);
      mAxisSlave      : in  AxiStreamSlaveArray(CHAN_COUNT_G-1 downto 0);
      mAxisCtrl       : in  AxiStreamCtrlArray(CHAN_COUNT_G-1 downto 0);
      -- AXI Interfaces, 0 = Desc, 1-CHAN_COUNT_G = DMA
      axiReadMaster   : out AxiReadMasterArray(CHAN_COUNT_G downto 0);
      axiReadSlave    : in  AxiReadSlaveArray(CHAN_COUNT_G downto 0);
      axiWriteMaster  : out AxiWriteMasterArray(CHAN_COUNT_G downto 0);
      axiWriteSlave   : in  AxiWriteSlaveArray(CHAN_COUNT_G downto 0);
      axiWriteCtrl    : in  AxiCtrlArray(CHAN_COUNT_G downto 0));
end AxiStreamDmaV2;

architecture structure of AxiStreamDmaV2 is

   signal dmaWrDescReq      : AxiWriteDmaDescReqArray(CHAN_COUNT_G-1 downto 0);
   signal dmaWrDescAck      : AxiWriteDmaDescAckArray(CHAN_COUNT_G-1 downto 0);
   signal dmaWrDescRet      : AxiWriteDmaDescRetArray(CHAN_COUNT_G-1 downto 0);
   signal dmaWrDescRetAck   : slv(CHAN_COUNT_G-1 downto 0);

   signal dmaRdDescReq      : AxiReadDmaDescReqArray(CHAN_COUNT_G-1 downto 0);
   signal dmaRdDescAck      : slv(CHAN_COUNT_G-1 downto 0);
   signal dmaRdDescRet      : AxiReadDmaDescRetArray(CHAN_COUNT_G-1 downto 0);
   signal dmaRdDescRetAck   : slv(CHAN_COUNT_G-1 downto 0);

   signal axiCache : slv(3 downto 0);

begin

   U_DmaDesc: entity work.AxiStreamDmaV2Desc
      generic map (
         TPD_G                 => TPD_G,
         CHAN_COUNT_G          => CHAN_COUNT_G,
         AXIL_BASE_ADDR_G      => AXIL_BASE_ADDR_G,
         AXI_ERROR_RESP_G      => AXI_ERROR_RESP_G,
         AXI_READY_EN_G        => AXI_READY_EN_G,
         AXI_CONFIG_G          => AXI_DESC_CONFIG_G,
         DESC_AWIDTH_G         => DESC_AWIDTH_G,
         ACK_WAIT_BVALID_G     => true)
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
         dmaWrDescReq       => dmaWrDescReq,
         dmaWrDescAck       => dmaWrDescAck,
         dmaWrDescRet       => dmaWrDescRet,
         dmaWrDescRetAck    => dmaWrDescRetAck,
         dmaRdDescReq       => dmaRdDescReq,
         dmaRdDescAck       => dmaRdDescAck,
         dmaRdDescRet       => dmaRdDescRet,
         dmaRdDescRetAck    => dmaRdDescRetAck,
         axiCache           => axiCache,
         axiWriteMaster     => axiWriteMaster(0),
         axiWriteSlave      => axiWriteSlave(0),
         axiWriteCtrl       => axiWriteCtrl(0));

   -- Read channel 0 unused.
   axiReadMaster(0) <= AXI_READ_MASTER_INIT_C;

   U_ChanGen: for i in 0 to CHAN_COUNT_G-1 generate

      U_DmaRead: entity work.AxiStreamDmaV2Read 
         generic map (
            TPD_G           => TPD_G,
            AXIS_READY_EN_G => AXIS_READY_EN_G,
            AXIS_CONFIG_G   => AXIS_CONFIG_G,
            AXI_CONFIG_G    => AXI_DMA_CONFIG_G,
            PIPE_STAGES_G   => RD_PIPE_STAGES_G,
            BURST_BYTES_G   => BURST_BYTES_G,
            PEND_THRESH_G   => RD_PEND_THRESH_G)
         port map (
            axiClk             => axiClk,
            axiRst             => axiRst,
            dmaRdDescReq       => dmaRdDescReq(i),
            dmaRdDescAck       => dmaRdDescAck(i),
            dmaRdDescRet       => dmaRdDescRet(i),
            dmaRdDescRetAck    => dmaRdDescRetAck(i),
            dmaRdIdle          => open,
            axiCache           => axiCache,
            -- Streaming Interface 
            axisMaster      => mAxisMaster(i),
            axisSlave       => mAxisSlave(i),
            axisCtrl        => mAxisCtrl(i),
            axiReadMaster   => axiReadMaster(i+1),
            axiReadSlave    => axiReadSlave(i+1));

      U_DmaWrite: entity work.AxiStreamDmaV2Write
         generic map (
            TPD_G             => TPD_G,
            AXI_READY_EN_G    => AXI_READY_EN_G,
            AXIS_CONFIG_G     => AXIS_CONFIG_G,
            AXI_CONFIG_G      => AXI_DMA_CONFIG_G,
            BURST_BYTES_G     => BURST_BYTES_G,
            ACK_WAIT_BVALID_G => true)
         port map (
            axiClk           => axiClk,
            axiRst           => axiRst,
            dmaWrDescReq     => dmaWrDescReq(i),
            dmaWrDescAck     => dmaWrDescAck(i),
            dmaWrDescRet     => dmaWrDescRet(i),
            dmaWrDescRetAck  => dmaWrDescRetAck(i),
            dmaWrIdle        => open,
            axiCache         => axiCache,
            axisMaster       => sAxisMaster(i),
            axisSlave        => sAxisSlave(i),
            axiWriteMaster   => axiWriteMaster(i+1),
            axiWriteSlave    => axiWriteSlave(i+1),
            axiWriteCtrl     => axiWriteCtrl(i+1));
   end generate;

end structure;

