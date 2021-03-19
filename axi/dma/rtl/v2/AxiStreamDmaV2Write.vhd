-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- Block to transfer a single AXI Stream frame into memory using an AXI
-- interface. Version 2 supports interleaved frames.
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
use surf.AxiPkg.all;
use surf.AxiDmaPkg.all;

entity AxiStreamDmaV2Write is
   generic (
      TPD_G             : time                    := 1 ns;
      AXI_READY_EN_G    : boolean                 := false;
      AXIS_CONFIG_G     : AxiStreamConfigType;
      AXI_CONFIG_G      : AxiConfigType;
      PIPE_STAGES_G     : natural                 := 1;
      BURST_BYTES_G     : integer range 1 to 4096 := 4096;
      ACK_WAIT_BVALID_G : boolean                 := true);
   port (
      -- Clock/Reset
      axiClk          : in  sl;
      axiRst          : in  sl;
      -- DMA write descriptor request, ack and return
      dmaWrDescReq    : out AxiWriteDmaDescReqType;
      dmaWrDescAck    : in  AxiWriteDmaDescAckType;
      dmaWrDescRet    : out AxiWriteDmaDescRetType;
      dmaWrDescRetAck : in  sl;
      -- Config and status
      dmaWrIdle       : out sl;
      axiCache        : in  slv(3 downto 0);
      -- Streaming Interface
      axisMaster      : in  AxiStreamMasterType;
      axisSlave       : out AxiStreamSlaveType;
      -- AXI Interface
      axiWriteMaster  : out AxiWriteMasterType;
      axiWriteSlave   : in  AxiWriteSlaveType;
      axiWriteCtrl    : in  AxiCtrlType := AXI_CTRL_UNUSED_C);
end AxiStreamDmaV2Write;

architecture rtl of AxiStreamDmaV2Write is

   constant DATA_BYTES_C      : integer := AXIS_CONFIG_G.TDATA_BYTES_C;
   constant ADDR_LSB_C        : integer := bitSize(DATA_BYTES_C-1);
   constant FIFO_ADDR_WIDTH_C : natural := (AXI_CONFIG_G.LEN_BITS_C+1);

   type StateType is (
      RESET_S,
      INIT_S,
      IDLE_S,
      REQ_S,
      ADDR_S,
      MOVE_S,
      PAD_S,
      META_S,
      RETURN_S,
      DUMP_S);

   type RegType is record
      dmaWrDescReq  : AxiWriteDmaDescReqType;
      dmaWrTrack    : AxiWriteDmaTrackType;
      dmaWrDescRet  : AxiWriteDmaDescRetType;
      result        : slv(1  downto 0);
      reqCount      : slv(31 downto 0);
      ackCount      : slv(31 downto 0);
      stCount       : slv(15 downto 0);
      awlen         : slv(AXI_CONFIG_G.LEN_BITS_C-1 downto 0);
      axiLen        : AxiLenType;
      wMaster       : AxiWriteMasterType;
      slave         : AxiStreamSlaveType;
      state         : StateType;
      lastUser      : slv(7 downto 0);
      continue      : sl;
      dmaWrIdle     : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      dmaWrDescReq  => AXI_WRITE_DMA_DESC_REQ_INIT_C,
      dmaWrTrack    => AXI_WRITE_DMA_TRACK_INIT_C,
      dmaWrDescRet  => AXI_WRITE_DMA_DESC_RET_INIT_C,
      result        => (others => '0'),
      reqCount      => (others => '0'),
      ackCount      => (others => '0'),
      stCount       => (others => '0'),
      awlen         => (others => '0'),
      axiLen        => AXI_LEN_INIT_C,
      wMaster       => axiWriteMasterInit(AXI_CONFIG_G, '1', "01", "0000"),
      slave         => AXI_STREAM_SLAVE_INIT_C,
      state         => RESET_S,
      lastUser      => (others=>'0'),
      continue      => '0',
      dmaWrIdle     => '0');

   signal r             : RegType := REG_INIT_C;
   signal rin           : RegType;
   signal pause         : sl;
   signal intAxisMaster : AxiStreamMasterType;
   signal intAxisSlave  : AxiStreamSlaveType;
   signal trackDin      : slv(AXI_WRITE_DMA_TRACK_SIZE_C-1 downto 0);
   signal trackDout     : slv(AXI_WRITE_DMA_TRACK_SIZE_C-1 downto 0);
   signal trackData     : AxiWriteDmaTrackType;

   -- attribute dont_touch      : string;
   -- attribute dont_touch of r : signal is "true";

begin

   assert AXIS_CONFIG_G.TDATA_BYTES_C = AXI_CONFIG_G.DATA_BYTES_C
      report "AXIS (" & integer'image(AXIS_CONFIG_G.TDATA_BYTES_C) & ") and AXI ("
      & integer'image(AXI_CONFIG_G.DATA_BYTES_C) & ") must have equal data widths" severity failure;

   U_Pipeline : entity surf.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
         PIPE_STAGES_G => PIPE_STAGES_G)
      port map (
         axisClk     => axiClk,
         axisRst     => axiRst,
         sAxisMaster => axisMaster,
         sAxisSlave  => axisSlave,
         mAxisMaster => intAxisMaster,
         mAxisSlave  => intAxisSlave);

   -- Pause when enabled
   pause <= '0' when (AXI_READY_EN_G) else axiWriteCtrl.pause;

   -- State machine
   comb : process (axiRst, axiWriteSlave, dmaWrDescAck, dmaWrDescRetAck,
                   intAxisMaster, trackData, pause, r, axiCache) is
      variable v       : RegType;
      variable bytes   : natural;
   begin
      -- Latch the current value
      v := r;

      -- Clear stream slave
      v.slave.tReady := '0';

      -- Cache setting
      v.wMaster.awcache := axiCache;

      -- Reset AXI Signals
      if (axiWriteSlave.awready = '1') or (AXI_READY_EN_G = false) then
         v.wMaster.awvalid := '0';
      end if;
      if (axiWriteSlave.wready = '1') or (AXI_READY_EN_G = false) then
         v.wMaster.wvalid := '0';
         v.wMaster.wlast  := '0';
      end if;

      -- Wait for memory bus response
      if (axiWriteSlave.bvalid = '1') and (ACK_WAIT_BVALID_G = true) then
         -- Increment the counter
         v.ackCount := r.ackCount + 1;
         -- Check for error response
         if (axiWriteSlave.bresp /= "00") and (r.result = 0) then
            -- Latch the response value
            v.result := axiWriteSlave.bresp;
         end if;
      end if;

      -- Descriptor handshaking
      if dmaWrDescRetAck = '1' then
         v.dmaWrDescRet.valid := '0';
      end if;
      if dmaWrDescAck.valid = '1' then
         v.dmaWrDescReq.valid := '0';
      end if;

      -- Count number of bytes in return data
      if (AXIS_CONFIG_G.TKEEP_MODE_C = TKEEP_COUNT_C) then
         bytes := conv_integer(intAxisMaster.tKeep(bitSize(AXI_STREAM_MAX_TKEEP_WIDTH_C)-1 downto 0));
      else
         bytes := getTKeep(intAxisMaster.tKeep(DATA_BYTES_C-1 downto 0),AXIS_CONFIG_G);
      end if;

      -- State machine
      case r.state is
         ----------------------------------------------------------------------
         when RESET_S =>
            v := REG_INIT_C;
            if r.stCount = 100 then
               v.state := INIT_S;
            else
               v.stCount := r.stCount + 1;
            end if;
         ----------------------------------------------------------------------
         when INIT_S =>
            v.dmaWrTrack.dest := r.dmaWrTrack.dest + 1;
            if r.dmaWrTrack.dest = 255 then
               v.state           := IDLE_S;
            end if;
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Set write dma request data
            v.dmaWrDescReq.dest := intAxisMaster.tDest;
            v.dmaWrDescReq.id   := intAxisMaster.tId;

            if intAxisMaster.tValid = '1' then
               -- Current destination matches incoming frame
               if r.dmaWrTrack.dest = intAxisMaster.tDest then

                  -- Frame is still in progress
                  if r.dmaWrTrack.inUse = '1' then
                     if r.dmaWrTrack.dropEn = '1' then
                           -- Next state
                        v.state := DUMP_S;
                     else
                        -- Next state
                        v.state := ADDR_S;
                     end if;

                  -- New frame with same destination, new descriptor
                  else
                     v.dmaWrDescReq.valid := '1';
                     v.state := REQ_S;
                  end if;

               -- Wait for mem selection to match incoming frame
               elsif trackData.dest = intAxisMaster.tDest then
                  -- Set tracking data
                  v.dmaWrTrack := trackData;

                  -- Is entry valid or do we need a new buffer
                  if trackData.inUse = '1' then
                     if trackData.dropEn = '1' then
                        -- Next state
                        v.state := DUMP_S;
                     else
                        -- Next state
                        v.state := ADDR_S;
                     end if;
                  else
                     -- Request a new descriptor
                     v.dmaWrDescReq.valid := '1';
                     -- Next state
                     v.state := REQ_S;
                  end if;
               end if;
            end if;
         ----------------------------------------------------------------------
         when REQ_S =>
            -- Wait for response and latch fields
            if dmaWrDescAck.valid = '1' then
               v.dmaWrTrack.inUse      := '1';
               v.dmaWrTrack.size       := (others=>'0');
               v.dmaWrTrack.firstUser  := (others=>'0');
               v.dmaWrTrack.contEn     := dmaWrDescAck.contEn;
               v.dmaWrTrack.dropEn     := dmaWrDescAck.dropEn;
               v.dmaWrTrack.buffId     := dmaWrDescAck.buffId;
               v.dmaWrTrack.overflow   := '0';
               v.dmaWrTrack.metaEnable := dmaWrDescAck.metaEnable;
               v.dmaWrTrack.metaAddr   := dmaWrDescAck.metaAddr;
               v.dmaWrTrack.address    := dmaWrDescAck.address;
               v.dmaWrTrack.maxSize    := dmaWrDescAck.maxSize;

               -- Descriptor return calls for dumping frame?
               if dmaWrDescAck.dropEn = '1' then
                  -- Next state
                  v.state := DUMP_S;
               else
                  -- Next state
                  v.state := ADDR_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when ADDR_S =>
            -- Reset counter, continue and last user
            v.stCount  := (others=>'0');
            v.continue := '0';
            v.lastUser := (others=>'0');
            -- Determine transfer size aligned to 4k boundaries
            getAxiLenProc(AXI_CONFIG_G,BURST_BYTES_G,r.dmaWrTrack.maxSize,r.dmaWrTrack.address,r.axiLen,v.axiLen);
            -- Address can be sent
            if (v.wMaster.awvalid = '0') and (v.axiLen.valid = "11") then
               -- Set the memory address
               v.wMaster.awaddr(AXI_CONFIG_G.ADDR_WIDTH_C-1 downto 0) :=
                  r.dmaWrTrack.address(AXI_CONFIG_G.ADDR_WIDTH_C-1 downto 0);
               -- Latch AXI awlen value
               v.wMaster.awlen := v.axiLen.value;
               v.awlen         := v.axiLen.value(AXI_CONFIG_G.LEN_BITS_C-1 downto 0);
               -- Check if enough room
               if pause = '0' then
                  -- Set the flag
                  v.wMaster.awvalid := '1';
                  v.axiLen.valid    := "00";
                  -- Increment the counter
                  v.reqCount := r.reqCount + 1;
                  -- Next state
                  v.state := MOVE_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when MOVE_S =>
            -- Incoming valid data
            if intAxisMaster.tValid = '1' then
               v.stCount := (others=>'0');
               -- Destination has changed, complete current write
               if intAxisMaster.tDest /= r.dmaWrTrack.dest then
                  v.state := PAD_S;
               -- Overflow detect
               elsif (r.dmaWrTrack.maxSize(31 downto 5) = 0) then -- Assumes max AXIS.TDATA width of 128-bits
                  -- Multi-descriptor DMA is supported
                  if r.dmaWrTrack.contEn = '1' then
                     v.continue := '1';
                     v.dmaWrTrack.inUse := '0';
                  else
                     v.dmaWrTrack.overflow := '1';
                     v.dmaWrTrack.dropEn := '1';
                  end if;
                  -- Pad current write, dump of incoming frame will occur
                  -- after state machine returns to idle due to dropEn being set.
                  -- Return will follow pad with inUse = '0'
                  v.state := PAD_S;
               -- We are able to push more data
               elsif v.wMaster.wvalid = '0' then
                  -- Accept the data
                  v.slave.tReady := '1';
                  -- Move the data
                  v.wMaster.wvalid := '1';
                  v.wMaster.wdata((DATA_BYTES_C*8)-1 downto 0) := intAxisMaster.tData((DATA_BYTES_C*8)-1 downto 0);
                  -- Set byte write strobes
                  if (AXIS_CONFIG_G.TKEEP_MODE_C = TKEEP_COUNT_C) then
                     v.wMaster.wstrb(AXI_STREAM_MAX_TKEEP_WIDTH_C-1 downto 0) := genTKeep(bytes);
                  else
                     v.wMaster.wstrb(DATA_BYTES_C-1 downto 0)                 := intAxisMaster.tKeep(DATA_BYTES_C-1 downto 0);
                  end if;
                  -- Address and size increment
                  v.dmaWrTrack.address := r.dmaWrTrack.address + DATA_BYTES_C;
                  -- Force address alignment
                  if (DATA_BYTES_C > 1) then
                     v.dmaWrTrack.address(ADDR_LSB_C-1 downto 0) := (others => '0');
                  end if;
                  -- Increment the byte counter
                  v.dmaWrTrack.size    := r.dmaWrTrack.size + bytes;
                  v.dmaWrTrack.maxSize := r.dmaWrTrack.maxSize - bytes;
                  -- First word
                  if r.dmaWrTrack.size = 0 then
                     -- Latch the tDest/tId/tUser values
                     v.dmaWrTrack.id := intAxisMaster.tId;
                     v.dmaWrTrack.firstUser(AXIS_CONFIG_G.TUSER_BITS_C-1 downto 0) :=
                        axiStreamGetUserField(AXIS_CONFIG_G, intAxisMaster, 0);
                  end if;
                  -- -- Check for last AXIS word
                  if intAxisMaster.tLast = '1' then
                     -- Latch the tUser value
                     v.lastUser(AXIS_CONFIG_G.TUSER_BITS_C-1 downto 0) :=
                        axiStreamGetUserField(AXIS_CONFIG_G, intAxisMaster);
                     v.dmaWrTrack.inUse := '0';
                     -- Pad write if transaction is not done, return will following PAD because inUse = 0
                     if r.awlen = 0 then
                        if r.dmaWrTrack.metaEnable = '1' then
                           v.state := META_S;
                        else
                           v.state := RETURN_S;
                        end if;
                     else
                        v.state := PAD_S;
                     end if;
                  end if;
                  -- Check for last AXI transfer
                  if r.awlen = 0 then
                     -- Set the flag
                     v.wMaster.wlast := '1';
                     -- If next state has not already been updated go to idle
                     if v.state = MOVE_S then
                        v.state := IDLE_S;
                     end if;
                  else
                     -- Decrement the transaction counter
                     v.awlen := r.awlen - 1;
                  end if;
               end if;
            -- Timeout on stalled writes to avoid locking AXI crossbar
            elsif r.stCount = 100 then
               v.state := PAD_S;
            else
               v.stCount := r.stCount + 1;
            end if;
         ----------------------------------------------------------------------
         when PAD_S =>
            v.stCount := (others=>'0');
            -- We are able to push more data
            if v.wMaster.wvalid = '0' then
               v.wMaster.wvalid := '1';
               v.wMaster.wstrb := (others=>'0');
               -- Check for last AXI transfer
               if r.awlen = 0 then
                  -- Set the flag
                  v.wMaster.wlast := '1';
                  -- Frame is done. Go to return. Otherwise go to idle.
                  if r.dmaWrTrack.inUse = '0' then
                     if r.dmaWrTrack.metaEnable = '1' then
                        v.state := META_S;
                     else
                        v.state := RETURN_S;
                     end if;
                  else
                     v.state := IDLE_S;
                  end if;
               else
                  -- Decrement the counter
                  v.awlen := r.awlen - 1;
               end if;
            end if;
         ----------------------------------------------------------------------
         when META_S =>

            -- Wair for existing transactions to complete
            if v.wMaster.wvalid = '0' and v.wMaster.awvalid = '0' then

               -- Init
               v.wMaster := axiWriteMasterInit(AXI_CONFIG_G, '1', "01", "0000");

               -- Write address channel
               v.wMaster.awaddr := r.dmaWrTrack.metaAddr;
               v.wMaster.awlen  := x"00";  -- Single transaction

               -- Write data channel
               v.wMaster.wlast := '1';

               -- Descriptor data, 64-bits
               v.wMaster.wdata(63 downto 32)   := r.dmaWrTrack.size;
               v.wMaster.wdata(31 downto 24)   := r.dmaWrTrack.firstUser;
               v.wMaster.wdata(23 downto 16)   := r.lastUser;
               v.wMaster.wdata(15 downto 4)    := (others => '0');
               v.wMaster.wdata(3)              := r.continue;
               v.wMaster.wdata(2)              := '0';
               v.wMaster.wdata(1 downto 0)     := r.result;

               v.wMaster.wstrb := resize(x"FF", 128);

               v.wMaster.awvalid := '1';
               v.wMaster.wvalid  := '1';
               v.state           := RETURN_S;
            end if;
         ----------------------------------------------------------------------
         when RETURN_S =>
            -- Previous return was acked
            if v.dmaWrDescRet.valid = '0' then
               -- Setup return record
               v.dmaWrDescRet.buffId    := r.dmaWrTrack.buffId;
               v.dmaWrDescRet.firstUser := r.dmaWrTrack.firstUser;
               v.dmaWrDescRet.size      := r.dmaWrTrack.size;
               v.dmaWrDescRet.dest      := r.dmaWrTrack.dest;
               v.dmaWrDescRet.id        := r.dmaWrTrack.id;
               v.dmaWrDescRet.lastUser  := r.lastUser;
               v.dmaWrDescRet.continue  := r.continue;
               v.dmaWrDescRet.result(2) := r.dmaWrTrack.overflow;
               v.dmaWrDescRet.result(1 downto 0) := r.result;
               -- Init record
               v.dmaWrTrack.inUse := '0';
               -- Wait for all transactions to complete before returning descriptor
               if (r.ackCount = r.reqCount) or (ACK_WAIT_BVALID_G = false) then
                  v.dmaWrDescRet.valid := '1';
                  v.state := IDLE_S;
               -- Check for ACK timeout
               elsif (r.stCount = x"FFFF") then
                  -- Set the flags
                  v.dmaWrDescRet.result(1 downto 0) := "11";
                  v.dmaWrDescRet.valid := '1';
                  v.reqCount := (others => '0');
                  v.ackCount := (others => '0');
                  v.state    := IDLE_S;
               else
                  -- Increment the counter
                  v.stCount := r.stCount + 1;
               end if;
            else
               v.stCount := (others=>'0');
            end if;
         ----------------------------------------------------------------------
         when DUMP_S =>
            -- Incoming valid data
            if intAxisMaster.tValid = '1' then
               -- Destination has changed, complete current write
               if intAxisMaster.tDest /= r.dmaWrTrack.dest then
                  v.state := IDLE_S;
               else
                  -- Accept the data
                  v.slave.tReady := '1';
                  -- -- Check for last AXIS word
                  if intAxisMaster.tLast = '1' then
                     v.dmaWrTrack.inUse := '0';
                     v.state := RETURN_S;
                  end if;
               end if;
            end if;
      ----------------------------------------------------------------------
         when others =>
            v.state := RESET_S;
      end case;

      -- Forward the state of the state machine
      if (v.state = IDLE_S) then
         v.dmaWrIdle := '1';
      else
         v.dmaWrIdle := '0';
      end if;

      -- Combinatorial outputs before the reset
      intAxisSlave <= v.slave;

      -- Reset
      if (axiRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Registered Outputs
      axiWriteMaster <= r.wMaster;
      dmaWrDescReq   <= r.dmaWrDescReq;
      dmaWrDescRet   <= r.dmaWrDescRet;
      dmaWrIdle      <= r.dmaWrIdle;

   end process comb;

   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   --------------------------
   -- Tracking RAM
   --------------------------
   U_TrackRam: entity surf.DualPortRam
      generic map (
         TPD_G          => TPD_G,
         MEMORY_TYPE_G  => "block",
         REG_EN_G       => true,
         DOA_REG_G      => true,
         DOB_REG_G      => true, -- 2 cycle read latency
         MODE_G         => "write-first",
         DATA_WIDTH_G   => AXI_WRITE_DMA_TRACK_SIZE_C,
         ADDR_WIDTH_G   => 8)
      port map (
         clka    => axiClk,
         wea     => '1',
         rsta    => axiRst,
         addra   => r.dmaWrTrack.dest,
         dina    => trackDin,
         clkb    => axiClk,
         rstb    => axiRst,
         addrb   => intAxisMaster.tDest,
         doutb   => trackDout);

   trackDin  <= toSlv(r.dmaWrTrack);
   trackData <= toAxiWriteDmaTrack(trackDout);

end rtl;
