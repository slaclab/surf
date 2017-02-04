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
      READ_AWIDTH_G     : integer range 4 to 12  := 12;
      WRITE_AWIDTH_G    : integer range 4 to 12  := 12;
      AXIL_BASE_ADDR_G  : slv(31 downto 0)       := x"00000000";
      AXI_ERROR_RESP_G  : slv(1 downto 0)        := AXI_RESP_OK_C;
      AXI_READY_EN_G    : boolean                := false;
      --AXIS_READY_EN_G   : boolean              := false;
      --AXIS_CONFIG_G     : AxiStreamConfigType  := AXI_STREAM_CONFIG_INIT_C;
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

   type StateType is ( IDLE_S, RD_RET_S, WR_REQ_S, WR_RET_S );

   type RegType is record
      state      : StateType;
      dmaWrDescReq : AxiWriteDmaDescReqType;
      dmaWrDescAck : AxiWriteDmaDescAckType;
      dmaWrDescRet : AxiWriteDmaDescRetType;
      dmaRdDescReq : AxiReadDmaDescReqType;
      dmaRdDescAck : sl;
      dmaRdDescRet : AxiReadDmaDescRetType;

   end record RegType;

   constant REG_INIT_C : RegType := (
      state        => IDLE_S,
      dmaWrDescReq => AXI_WRITE_DMA_DESC_REQ_INIT_C,
      dmaWrDescAck => AXI_WRITE_DMA_DESC_ACK_INIT_C,
      dmaWrDescRet => AXI_WRITE_DMA_DESC_RET_INIT_C,
      dmaRdDescReq => AXI_READ_DMA_DESC_REQ_INIT_C,
      dmaRdDescAck => '0',
      dmaRdDescRet => AXI_READ_DMA_DESC_RET_INIT_C
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

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
         READ_AWIDTH_G         => READ_AWIDTH_G,
         WRITE_AWIDTH_G        => WRITE_AWIDTH_G)
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
   mAxisMaster        <= AXI_STREAM_MASTER_INIT_C;
   axiReadMaster(1)   <= AXI_READ_MASTER_INIT_C;
   axiWriteMaster(1)  <= AXI_WRITE_MASTER_INIT_C;


   comb : process (axiRst, dmaWrDescAck, dmaWrDescRetAck, dmaRdDescReq, dmaRdDescRetAck, r) is
      variable v : RegType;
   begin

      -- Latch the current value
      v := r;

      v.dmaRdDescAck := '0';

      if dmaRdDescRetAck = '1' then
         v.dmaRdDescRet.valid  := '0';
      end if;
      if dmaWrDescRetAck = '1' then
         v.dmaWrDescRet.valid  := '0';
      end if;

      -- State machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            v.dmaWrDescReq := AXI_WRITE_DMA_DESC_REQ_INIT_C;
            v.dmaWrDescAck := AXI_WRITE_DMA_DESC_ACK_INIT_C;
            v.dmaWrDescRet := AXI_WRITE_DMA_DESC_RET_INIT_C;
            v.dmaRdDescReq := AXI_READ_DMA_DESC_REQ_INIT_C;
            v.dmaRdDescRet := AXI_READ_DMA_DESC_RET_INIT_C;

            if dmaRdDescReq.valid = '1' and v.dmaRdDescRet.valid = '0' and v.dmaWrDescRet.valid = '0' then
               v.dmaRdDescAck := '1';
               v.dmaRdDescReq := dmaRdDescReq;
               v.state := RD_RET_S;
            end if;

         ----------------------------------------------------------------------
         when RD_RET_S =>
            v.dmaRdDescRet.valid  := '1';
            v.dmaRdDescRet.buffId := r.dmaRdDescReq.buffId;
            v.dmaRdDescRet.result := (others=>'0');

            v.dmaWrDescRet.firstUser := r.dmaRdDescReq.firstUser;
            v.dmaWrDescRet.lastUser  := r.dmaRdDescReq.lastUser;
            v.dmaWrDescRet.size      := r.dmaRdDescReq.size;
            v.dmaWrDescRet.continue  := r.dmaRdDescReq.continue;
            v.dmaWrDescRet.dest      := r.dmaRdDescReq.dest;
            v.dmaWrDescRet.result    := "000";

            v.dmaWrDescReq.valid := '1';
            v.dmaWrDescReq.dest  := x"00";

            v.state := WR_REQ_S;

         ----------------------------------------------------------------------
         when WR_REQ_S =>
            if dmaWrDescAck.valid = '1' then
               v.dmaWrDescReq.valid  := '0';
               v.dmaWrDescRet.valid  := '1';
               v.dmaWrDescRet.buffId := dmaWrDescAck.buffId;
               v.state := IDLE_S;
            end if;

         when others =>
            v.state := IDLE_S;

      end case;

      -- Outputs
      dmaWrDescReq <= r.dmaWrDescReq;
      dmaWrDescRet <= r.dmaWrDescRet;
      dmaRdDescAck <= r.dmaRdDescAck;
      dmaRdDescRet <= r.dmaRdDescRet;

   end process comb;

   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
end structure;

