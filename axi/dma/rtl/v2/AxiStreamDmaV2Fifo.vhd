-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- Generic AXI Stream FIFO that supports TDEST interleaving
-- using an AXI4 memory for the buffering of the AXI stream frames
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiPkg.all;
use surf.AxiDmaPkg.all;

entity AxiStreamDmaV2Fifo is
   generic (
      TPD_G              : time                     := 1 ns;
      COMMON_CLK_G       : boolean                  := false;  -- true if axilClk=axiClk
      -- FIFO Configuration
      BUFF_FRAME_WIDTH_G : positive                 := 20;  -- Buffer Frame size (units of address bits)
      AXI_BUFFER_WIDTH_G : positive                 := 30;  -- Total AXI Memory for FIFO buffering (units of address bits)
      SYNTH_MODE_G       : string                   := "inferred";
      MEMORY_TYPE_G      : string                   := "block";
      -- AXI Stream Configurations
      AXIS_CONFIG_G      : AxiStreamConfigType;
      -- AXI4 Configurations
      AXI_BASE_ADDR_G    : slv(63 downto 0)         := x"0000_0000_0000_0000";  -- Memory Base Address Offset
      AXI_CONFIG_G       : AxiConfigType;
      AXI_BURST_G        : slv(1 downto 0)          := "01";
      AXI_CACHE_G        : slv(3 downto 0)          := "1111";
      BURST_BYTES_G      : positive range 1 to 4096 := 4096;
      RD_PEND_THRESH_G   : positive                 := 1);  -- In units of bytes
   port (
      -- AXI4 Interface (axiClk domain)
      axiClk          : in  sl;
      axiRst          : in  sl;
      axiReady        : in  sl;
      axiReadMaster   : out AxiReadMasterType;
      axiReadSlave    : in  AxiReadSlaveType;
      axiWriteMaster  : out AxiWriteMasterType;
      axiWriteSlave   : in  AxiWriteSlaveType;
      -- AXI Stream Interface (axiClk domain)
      sAxisMaster     : in  AxiStreamMasterType;
      sAxisSlave      : out AxiStreamSlaveType;  -- tReady flow control only
      sAxisCtrl       : out AxiStreamCtrlType;   -- Only used to signal pause
      mAxisMaster     : out AxiStreamMasterType;
      mAxisSlave      : in  AxiStreamSlaveType;
      -- Optional: AXI-Lite Interface (axilClk domain)
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end AxiStreamDmaV2Fifo;

architecture rtl of AxiStreamDmaV2Fifo is

   constant ADDR_WIDTH_C     : positive := AXI_BUFFER_WIDTH_G-BUFF_FRAME_WIDTH_G;
   constant RD_QUEUE_WIDTH_C : positive := ADDR_WIDTH_C+1+(BUFF_FRAME_WIDTH_G+1)+(2*AXIS_CONFIG_G.TUSER_BITS_C)+AXIS_CONFIG_G.TDEST_BITS_C+AXIS_CONFIG_G.TID_BITS_C;

   -- Using a local version (instead of AxiDmaPkg generalized functions) that's better logic optimized for this module
   function localToSlv (r : AxiReadDmaDescReqType) return slv is
      variable retValue : slv(RD_QUEUE_WIDTH_C-1 downto 0) := (others => '0');
      variable i        : integer                          := 0;
   begin
      assignSlv(i, retValue, r.buffId(ADDR_WIDTH_C-1 downto 0));
      assignSlv(i, retValue, r.continue);
      assignSlv(i, retValue, r.size(BUFF_FRAME_WIDTH_G downto 0));

      -- Check for none-zero TDEST bits
      if (AXIS_CONFIG_G.TUSER_BITS_C /= 0) then
         assignSlv(i, retValue, r.firstUser(AXIS_CONFIG_G.TUSER_BITS_C-1 downto 0));
         assignSlv(i, retValue, r.lastUser(AXIS_CONFIG_G.TUSER_BITS_C-1 downto 0));
      end if;

      -- Check for none-zero TDEST bits
      if (AXIS_CONFIG_G.TDEST_BITS_C /= 0) then
         assignSlv(i, retValue, r.dest(AXIS_CONFIG_G.TDEST_BITS_C-1 downto 0));
      end if;

      -- Check for none-zero TID bits
      if (AXIS_CONFIG_G.TID_BITS_C /= 0) then
         assignSlv(i, retValue, r.id(AXIS_CONFIG_G.TID_BITS_C-1 downto 0));
      end if;

      return(retValue);
   end function;

   function localToAxiReadDmaDescReq (din : slv; valid : sl) return AxiReadDmaDescReqType is
      variable desc : AxiReadDmaDescReqType := AXI_READ_DMA_DESC_REQ_INIT_C;
      variable i    : integer               := 0;
   begin
      desc.valid := valid;
      assignRecord(i, din, desc.buffId(ADDR_WIDTH_C-1 downto 0));
      assignRecord(i, din, desc.continue);
      assignRecord(i, din, desc.size(BUFF_FRAME_WIDTH_G downto 0));

      -- Check for none-zero TDEST bits
      if (AXIS_CONFIG_G.TUSER_BITS_C /= 0) then
         assignRecord(i, din, desc.firstUser(AXIS_CONFIG_G.TUSER_BITS_C-1 downto 0));
         assignRecord(i, din, desc.lastUser(AXIS_CONFIG_G.TUSER_BITS_C-1 downto 0));
      end if;

      -- Check for none-zero TDEST bits
      if (AXIS_CONFIG_G.TDEST_BITS_C /= 0) then
         assignRecord(i, din, desc.dest(AXIS_CONFIG_G.TDEST_BITS_C-1 downto 0));
      end if;

      -- Check for none-zero TID bits
      if (AXIS_CONFIG_G.TID_BITS_C /= 0) then
         assignRecord(i, din, desc.id(AXIS_CONFIG_G.TID_BITS_C-1 downto 0));
      end if;

      -- Set base address offset
      desc.address := AXI_BASE_ADDR_G;

      -- Update the address with respect to buffer index
      desc.address(AXI_BUFFER_WIDTH_G-1 downto BUFF_FRAME_WIDTH_G) := desc.buffId(ADDR_WIDTH_C-1 downto 0);

      return(desc);
   end function;

   type stateType is (
      RESET_S,
      INIT_S,
      IDLE_S);

   type RegType is record
      reset           : sl;
      rstCnt          : sl;
      wrIndexValid    : sl;
      wrIndexReady    : sl;
      wrIndex         : slv(ADDR_WIDTH_C-1 downto 0);
      dmaWrDescAck    : AxiWriteDmaDescAckType;
      dmaWrDescRetAck : sl;
      rdQueueValid    : sl;
      rdQueueReady    : sl;
      rdQueueData     : slv(RD_QUEUE_WIDTH_C-1 downto 0);
      dmaRdDescReq    : AxiReadDmaDescReqType;
      dmaRdDescRetAck : sl;
      sAxisCtrl       : AxiStreamCtrlType;
      pauseThresh     : slv(ADDR_WIDTH_C-1 downto 0);
      pauseCnt        : slv(15 downto 0);
      regReadSlave    : AxiLiteReadSlaveType;
      regWriteSlave   : AxiLiteWriteSlaveType;
      txnLatecy       : Slv8Array(3 downto 0);
      state           : StateType;
   end record;
   constant REG_INIT_C : RegType := (
      reset           => '1',
      rstCnt          => '0',
      wrIndexValid    => '0',
      wrIndexReady    => '0',
      wrIndex         => (others => '1'),
      dmaWrDescAck    => AXI_WRITE_DMA_DESC_ACK_INIT_C,
      dmaWrDescRetAck => '0',
      rdQueueValid    => '0',
      rdQueueReady    => '0',
      rdQueueData     => (others => '0'),
      dmaRdDescReq    => AXI_READ_DMA_DESC_REQ_INIT_C,
      dmaRdDescRetAck => '0',
      sAxisCtrl       => AXI_STREAM_CTRL_INIT_C,
      pauseThresh     => toSlv(2**(ADDR_WIDTH_C-1), ADDR_WIDTH_C),  -- Default: 50% buffers in queue
      pauseCnt        => (others => '0'),
      regReadSlave    => AXI_LITE_READ_SLAVE_INIT_C,
      regWriteSlave   => AXI_LITE_WRITE_SLAVE_INIT_C,
      txnLatecy       => (others => (others => '0')),
      state           => RESET_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal dmaWrDescReq    : AxiWriteDmaDescReqType;
   signal dmaWrDescAck    : AxiWriteDmaDescAckType;
   signal dmaWrDescRet    : AxiWriteDmaDescRetType;
   signal dmaWrDescRetAck : sl;

   signal dmaRdDescReq    : AxiReadDmaDescReqType;
   signal dmaRdDescAck    : sl;
   signal dmaRdDescRet    : AxiReadDmaDescRetType;
   signal dmaRdDescRetAck : sl;
   signal dmaRdIdle       : sl;

   signal wrBuffCnt    : slv(ADDR_WIDTH_C-1 downto 0);
   signal wrIndex      : slv(ADDR_WIDTH_C-1 downto 0);
   signal wrIndexValid : sl;
   signal wrIndexReady : sl;

   signal rdBuffCnt    : slv(ADDR_WIDTH_C-1 downto 0);
   signal rdQueueData  : slv(RD_QUEUE_WIDTH_C-1 downto 0);
   signal rdQueueValid : sl;
   signal rdQueueReady : sl;

   signal regReadMaster  : AxiLiteReadMasterType;
   signal regReadSlave   : AxiLiteReadSlaveType  := AXI_LITE_READ_SLAVE_EMPTY_DECERR_C;
   signal regWriteMaster : AxiLiteWriteMasterType;
   signal regWriteSlave  : AxiLiteWriteSlaveType := AXI_LITE_WRITE_SLAVE_EMPTY_DECERR_C;

begin

   assert (isPowerOf2(BURST_BYTES_G) = true)
      report "BURST_BYTES_G must be power of 2" severity failure;

   ---------------------
   -- Inbound Controller
   ---------------------
   U_IbDma : entity surf.AxiStreamDmaV2Write
      generic map (
         TPD_G          => TPD_G,
         AXI_READY_EN_G => true,
         AXIS_CONFIG_G  => AXIS_CONFIG_G,
         AXI_CONFIG_G   => AXI_CONFIG_G,
         BURST_BYTES_G  => BURST_BYTES_G)
      port map (
         -- Clock/Reset
         axiClk          => axiClk,
         axiRst          => r.reset,
         -- DMA write descriptor request, ack and return
         dmaWrDescReq    => dmaWrDescReq,
         dmaWrDescAck    => dmaWrDescAck,
         dmaWrDescRet    => dmaWrDescRet,
         dmaWrDescRetAck => dmaWrDescRetAck,
         -- Config and status
         axiCache        => AXI_CACHE_G,
         -- Streaming Interface
         axisMaster      => sAxisMaster,
         axisSlave       => sAxisSlave,
         -- AXI Interface
         axiWriteMaster  => axiWriteMaster,
         axiWriteSlave   => axiWriteSlave);

   ----------------------
   -- Outbound Controller
   ----------------------
   U_ObDma : entity surf.AxiStreamDmaV2Read
      generic map (
         TPD_G           => TPD_G,
         AXIS_READY_EN_G => true,
         AXIS_CONFIG_G   => AXIS_CONFIG_G,
         AXI_CONFIG_G    => AXI_CONFIG_G,
         BURST_BYTES_G   => BURST_BYTES_G,
         PEND_THRESH_G   => RD_PEND_THRESH_G)
      port map (
         -- Clock/Reset
         axiClk          => axiClk,
         axiRst          => r.reset,
         -- DMA Control Interface
         dmaRdDescReq    => dmaRdDescReq,
         dmaRdDescAck    => dmaRdDescAck,
         dmaRdDescRet    => dmaRdDescRet,
         dmaRdDescRetAck => dmaRdDescRetAck,
         -- Config and status
         dmaRdIdle       => dmaRdIdle,
         axiCache        => AXI_CACHE_G,
         -- Streaming Interface
         axisMaster      => mAxisMaster,
         axisSlave       => mAxisSlave,
         axisCtrl        => AXI_STREAM_CTRL_UNUSED_C,
         -- AXI Interface
         axiReadMaster   => axiReadMaster,
         axiReadSlave    => axiReadSlave);

   --------------
   -- Write Queue
   --------------
   U_WriteQueue : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         FWFT_EN_G       => true,
         GEN_SYNC_FIFO_G => true,
         SYNTH_MODE_G    => SYNTH_MODE_G,
         MEMORY_TYPE_G   => MEMORY_TYPE_G,
         DATA_WIDTH_G    => ADDR_WIDTH_C,
         ADDR_WIDTH_G    => ADDR_WIDTH_C)
      port map (
         rst           => r.reset,
         -- Write Interface
         wr_clk        => axiClk,
         wr_en         => r.wrIndexValid,
         din           => r.wrIndex,
         -- Read Interface
         rd_clk        => axiClk,
         rd_data_count => wrBuffCnt,
         valid         => wrIndexValid,
         rd_en         => wrIndexReady,
         dout          => wrIndex);

   -------------
   -- Read Queue
   -------------
   U_ReadQueue : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         FWFT_EN_G       => true,
         GEN_SYNC_FIFO_G => true,
         SYNTH_MODE_G    => SYNTH_MODE_G,
         MEMORY_TYPE_G   => MEMORY_TYPE_G,
         DATA_WIDTH_G    => RD_QUEUE_WIDTH_C,
         ADDR_WIDTH_G    => ADDR_WIDTH_C)
      port map (
         rst           => r.reset,
         -- Write Interface
         wr_clk        => axiClk,
         wr_en         => r.rdQueueValid,
         din           => r.rdQueueData,
         -- Read Interface
         rd_clk        => axiClk,
         rd_data_count => rdBuffCnt,
         valid         => rdQueueValid,
         rd_en         => rdQueueReady,
         dout          => rdQueueData);

   U_AxiLiteAsync : entity surf.AxiLiteAsync
      generic map (
         TPD_G           => TPD_G,
         COMMON_CLK_G    => COMMON_CLK_G,
         NUM_ADDR_BITS_G => 8)
      port map (
         -- Slave Interface
         sAxiClk         => axilClk,
         sAxiClkRst      => axilRst,
         sAxiReadMaster  => axilReadMaster,
         sAxiReadSlave   => axilReadSlave,
         sAxiWriteMaster => axilWriteMaster,
         sAxiWriteSlave  => axilWriteSlave,
         -- Master Interface
         mAxiClk         => axiClk,
         mAxiClkRst      => r.reset,
         mAxiReadMaster  => regReadMaster,
         mAxiReadSlave   => regReadSlave,
         mAxiWriteMaster => regWriteMaster,
         mAxiWriteSlave  => regWriteSlave);

   comb : process (axiReady, axiRst, dmaRdDescRet, dmaRdIdle, dmaWrDescReq,
                   dmaWrDescRet, r, rdBuffCnt, rdQueueData, rdQueueValid,
                   regReadMaster, regWriteMaster, wrBuffCnt, wrIndex,
                   wrIndexValid) is
      variable v        : RegType;
      variable varRdReq : AxiReadDmaDescReqType;
      variable axilEp   : AxiLiteEndPointType;
   begin
      -- Latch the current value
      v := r;

      -- Init() variables
      varRdReq := AXI_READ_DMA_DESC_REQ_INIT_C;

      -- Reset flags
      v.reset              := '0';
      v.rstCnt             := '0';
      v.wrIndexValid       := '0';
      v.wrIndexReady       := '0';
      v.dmaWrDescAck.valid := '0';
      v.dmaWrDescRetAck    := '0';
      v.rdQueueValid       := '0';
      v.rdQueueReady       := '0';
      v.dmaRdDescReq.valid := '0';
      v.dmaRdDescRetAck    := '0';

      -- Update the shift registers
      for i in 3 downto 0 loop
         v.txnLatecy(i) := r.txnLatecy(i)(6 downto 0) & '0';
      end loop;

      -- State machine
      case r.state is
         ----------------------------------------------------------------------
         when RESET_S =>
            -- Wait for reset to de-assert
            if (r.reset = '0') then
               -- Next State
               v.state := INIT_S;
            end if;
         ----------------------------------------------------------------------
         when INIT_S =>
            -- Initialize the Write queue
            v.wrIndexValid := '1';

            -- Increment the counter
            v.wrIndex := r.wrIndex + 1;

            -- Check the counter
            if v.wrIndex = (2**ADDR_WIDTH_C)-1 then
               -- Next State
               v.state := IDLE_S;
            end if;
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check for next DMA write REQ and write queue not empty
            if (wrIndexValid = '1') and (dmaWrDescReq.valid = '1') and (r.txnLatecy(0) = 0) then

               -- Acknowledge the request
               v.txnLatecy(0)(0)    := '1';
               v.wrIndexReady       := '1';
               v.dmaWrDescAck.valid := '1';

               -- Set base address offset
               v.dmaWrDescAck.address := AXI_BASE_ADDR_G;

               -- Update the address with respect to buffer index
               v.dmaWrDescAck.address(AXI_BUFFER_WIDTH_G-1 downto BUFF_FRAME_WIDTH_G) := wrIndex;

               -- Set the max buffer size
               v.dmaWrDescAck.maxSize := toSlv(2**BUFF_FRAME_WIDTH_G, 32);

               -- Enable continuous mode
               v.dmaWrDescAck.contEn := '1';

               -- Set the buffer ID
               v.dmaWrDescAck.buffId(ADDR_WIDTH_C-1 downto 0) := wrIndex;

            end if;
      --------------------------------------------------------------------------------
      end case;

      -- Check for return index
      if (dmaWrDescRet.valid = '1') and (r.txnLatecy(1) = 0) then

         -- Acknowledge the request
         v.txnLatecy(1)(0) := '1';
         v.dmaWrDescRetAck := '1';

         -- Create a DMA Read Descriptor Request
         varRdReq.buffId    := dmaWrDescRet.buffId;
         varRdReq.firstUser := dmaWrDescRet.firstUser;
         varRdReq.lastUser  := dmaWrDescRet.lastUser;
         varRdReq.size      := dmaWrDescRet.size;
         varRdReq.continue  := dmaWrDescRet.continue;
         varRdReq.dest      := dmaWrDescRet.dest;
         varRdReq.id        := dmaWrDescRet.id;

         -- Convert request into a SLV and write it into the Read Queue
         v.rdQueueValid := '1';
         v.rdQueueData  := localToSlv(varRdReq);

      end if;

      -- Check if new read in the queue and DMA Read is idle
      if (rdQueueValid = '1') and (dmaRdIdle = '1') and (r.txnLatecy(2) = 0) then

         -- Acknowledge the request
         v.txnLatecy(2)(0) := '1';
         v.rdQueueReady    := '1';

         -- Set the read descriptor request
         v.dmaRdDescReq := localToAxiReadDmaDescReq(rdQueueData, '1');

      end if;

      -- Check for read descriptor return
      if (dmaRdDescRet.valid = '1') and (r.txnLatecy(3) = 0) then

         -- Acknowledge the request
         v.txnLatecy(3)(0) := '1';
         v.dmaRdDescRetAck := '1';

         -- Return buffer to write queue
         v.wrIndexValid := '1';
         v.wrIndex      := dmaRdDescRet.buffId(ADDR_WIDTH_C-1 downto 0);

      end if;

      --------------------------------------------------------------------------------

      -- Determine the transaction type
      axiSlaveWaitTxn(axilEp, regWriteMaster, regReadMaster, v.regWriteSlave, v.regReadSlave);

      -- Map the read registers
      axiSlaveRegisterR(axilEp, x"00", 0, toSlv(1, 4));  -- Version 1

      axiSlaveRegisterR(axilEp, x"04", 8, AXI_BASE_ADDR_G);

      axiSlaveRegisterR(axilEp, x"0C", 0, AXI_CACHE_G);
      axiSlaveRegisterR(axilEp, x"0C", 8, AXI_BURST_G);

      axiSlaveRegisterR(axilEp, x"10", 0, toSlv(AXI_CONFIG_G.LEN_BITS_C, 8));
      axiSlaveRegisterR(axilEp, x"10", 8, toSlv(AXI_CONFIG_G.ID_BITS_C, 8));
      axiSlaveRegisterR(axilEp, x"10", 16, toSlv(AXI_CONFIG_G.DATA_BYTES_C, 8));
      axiSlaveRegisterR(axilEp, x"10", 24, toSlv(AXI_CONFIG_G.ADDR_WIDTH_C, 8));

      axiSlaveRegisterR(axilEp, x"14", 0, toSlv(AXIS_CONFIG_G.TDEST_BITS_C, 8));
      axiSlaveRegisterR(axilEp, x"14", 8, toSlv(AXIS_CONFIG_G.TID_BITS_C, 8));
      axiSlaveRegisterR(axilEp, x"14", 16, toSlv(AXIS_CONFIG_G.TUSER_BITS_C, 8));
      axiSlaveRegisterR(axilEp, x"14", 24, toSlv(AXIS_CONFIG_G.TDATA_BYTES_C, 8));

      axiSlaveRegisterR(axilEp, x"18", 0, toSlv(BUFF_FRAME_WIDTH_G, 8));
      axiSlaveRegisterR(axilEp, x"18", 8, toSlv(AXI_BUFFER_WIDTH_G, 8));
      axiSlaveRegisterR(axilEp, x"18", 16, toSlv(BURST_BYTES_G, 16));

      axiSlaveRegisterR(axilEp, x"1C", 0, rdBuffCnt);
      axiSlaveRegisterR(axilEp, x"1C", 16, wrBuffCnt);

      axiSlaveRegisterR(axilEp, x"20", 0, r.pauseCnt);
      axiSlaveRegisterR(axilEp, x"20", 16, r.sAxisCtrl.pause);

      axiSlaveRegister (axilEp, x"24", 0, v.pauseThresh);

      axiSlaveRegister (axilEp, x"FC", 0, v.rstCnt);

      -- Closeout the transaction
      axiSlaveDefault(axilEp, v.regWriteSlave, v.regReadSlave, AXI_RESP_DECERR_C);

      --------------------------------------------------------------------------------

      -- Check if write buffer count is below threshold
      if (wrBuffCnt <= r.pauseThresh) then
         v.sAxisCtrl.pause := '1';
      else
         v.sAxisCtrl.pause := '0';
      end if;

      -- Check for pause event
      if (r.sAxisCtrl.pause = '0') and (v.sAxisCtrl.pause = '1') and (r.pauseCnt /= x"FFFF") then
         v.pauseCnt := r.pauseCnt + 1;
      end if;

      -- Check if we need to reset status counters
      if (r.rstCnt = '1') then
         v.pauseCnt := (others => '0');
      end if;

      --------------------------------------------------------------------------------

      -- Outputs
      regWriteSlave   <= r.regWriteSlave;
      regReadSlave    <= r.regReadSlave;
      wrIndexReady    <= r.wrIndexReady;
      dmaWrDescAck    <= r.dmaWrDescAck;
      dmaWrDescRetAck <= r.dmaWrDescRetAck;
      rdQueueReady    <= r.rdQueueReady;
      dmaRdDescReq    <= r.dmaRdDescReq;
      dmaRdDescRetAck <= r.dmaRdDescRetAck;
      sAxisCtrl       <= r.sAxisCtrl;

      -- Reset or AXI Memory interface not ready
      if (axiRst = '1') or (axiReady = '0') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (axiClk) is
   begin
      if rising_edge(axiClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
