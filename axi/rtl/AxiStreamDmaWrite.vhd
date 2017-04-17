-------------------------------------------------------------------------------
-- File       : AxiStreamDmaWrite.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-25
-- Last update: 2016-12-02
-------------------------------------------------------------------------------
-- Description:
-- Block to transfer a single AXI Stream frame into memory using an AXI
-- interface.
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
use work.AxiPkg.all;
use work.AxiDmaPkg.all;

entity AxiStreamDmaWrite is
   generic (
      TPD_G             : time                := 1 ns;
      AXI_READY_EN_G    : boolean             := false;
      AXIS_CONFIG_G     : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C;
      AXI_CONFIG_G      : AxiConfigType       := AXI_CONFIG_INIT_C;
      AXI_BURST_G       : slv(1 downto 0)     := "01";
      AXI_CACHE_G       : slv(3 downto 0)     := "1111";
      SW_CACHE_EN_G     : boolean             := false;
      ACK_WAIT_BVALID_G : boolean             := true;
      PIPE_STAGES_G     : natural             := 1;
      BYP_SHIFT_G       : boolean             := false;
      BYP_CACHE_G       : boolean             := false);
   port (
      -- Clock/Reset
      axiClk         : in  sl;
      axiRst         : in  sl;
      -- DMA Control Interface
      dmaReq         : in  AxiWriteDmaReqType;
      dmaAck         : out AxiWriteDmaAckType;
      swCache        : in  slv(3 downto 0) := "0000";
      -- Streaming Interface 
      axisMaster     : in  AxiStreamMasterType;
      axisSlave      : out AxiStreamSlaveType;
      -- AXI Interface
      axiWriteMaster : out AxiWriteMasterType;
      axiWriteSlave  : in  AxiWriteSlaveType;
      axiWriteCtrl   : in  AxiCtrlType := AXI_CTRL_UNUSED_C);
end AxiStreamDmaWrite;

architecture rtl of AxiStreamDmaWrite is

   constant DATA_BYTES_C      : integer         := AXIS_CONFIG_G.TDATA_BYTES_C;
   constant ADDR_LSB_C        : integer         := bitSize(DATA_BYTES_C-1);
   constant AWLEN_C           : slv(7 downto 0) := getAxiLen(AXI_CONFIG_G, 4096);
   constant FIFO_ADDR_WIDTH_C : natural         := (AXI_CONFIG_G.LEN_BITS_C+1);

   type StateType is (
      IDLE_S,
      FIRST_S,
      NEXT_S,
      MOVE_S,
      DUMP_S,
      WAIT_S,
      DONE_S);

   type RegType is record
      dmaReq    : AxiWriteDmaReqType;
      dmaAck    : AxiWriteDmaAckType;
      threshold : slv(FIFO_ADDR_WIDTH_C-1 downto 0);
      shift     : slv(3 downto 0);
      shiftEn   : sl;
      first     : sl;
      last      : sl;
      reqCount  : slv(31 downto 0);
      ackCount  : slv(31 downto 0);
      stCount   : slv(15 downto 0);
      awlen     : slv(AXI_CONFIG_G.LEN_BITS_C-1 downto 0);
      wMaster   : AxiWriteMasterType;
      slave     : AxiStreamSlaveType;
      state     : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      dmaReq    => AXI_WRITE_DMA_REQ_INIT_C,
      dmaAck    => AXI_WRITE_DMA_ACK_INIT_C,
      threshold => (others => '1'),
      shift     => (others => '0'),
      shiftEn   => '0',
      first     => '0',
      last      => '0',
      reqCount  => (others => '0'),
      ackCount  => (others => '0'),
      stCount   => (others => '0'),
      awlen     => (others => '0'),
      wMaster   => axiWriteMasterInit(AXI_CONFIG_G, '1', AXI_BURST_G, AXI_CACHE_G),
      slave     => AXI_STREAM_SLAVE_INIT_C,
      state     => IDLE_S);

   signal r             : RegType := REG_INIT_C;
   signal rin           : RegType;
   signal pause         : sl;
   signal shiftMaster   : AxiStreamMasterType;
   signal shiftSlave    : AxiStreamSlaveType;
   signal cache         : AxiStreamCtrlType;
   signal intAxisMaster : AxiStreamMasterType;
   signal intAxisSlave  : AxiStreamSlaveType;
   signal wrEn          : sl;
   signal rdEn          : sl;
   signal lastDet       : sl;

   -- attribute dont_touch      : string;
   -- attribute dont_touch of r : signal is "true";
   
begin

   assert AXIS_CONFIG_G.TDATA_BYTES_C = AXI_CONFIG_G.DATA_BYTES_C
      report "AXIS (" & integer'image(AXIS_CONFIG_G.TDATA_BYTES_C) & ") and AXI ("
      & integer'image(AXI_CONFIG_G.DATA_BYTES_C) & ") must have equal data widths" severity failure;

   pause <= '0' when (AXI_READY_EN_G) else axiWriteCtrl.pause;

   U_AxiStreamShift : entity work.AxiStreamShift
      generic map (
         TPD_G         => TPD_G,
         PIPE_STAGES_G => PIPE_STAGES_G,
         AXIS_CONFIG_G => AXIS_CONFIG_G,
         BYP_SHIFT_G   => BYP_SHIFT_G) 
      port map (
         axisClk     => axiClk,
         axisRst     => axiRst,
         axiStart    => r.shiftEn,
         axiShiftDir => '0',
         axiShiftCnt => r.shift,
         sAxisMaster => axisMaster,
         sAxisSlave  => axisSlave,
         mAxisMaster => shiftMaster,
         mAxisSlave  => shiftSlave);

   GEN_CACHE : if (BYP_CACHE_G = false) generate
      
      U_Cache : entity work.AxiStreamFifoV2
         generic map (
            TPD_G               => TPD_G,
            INT_PIPE_STAGES_G   => PIPE_STAGES_G,
            PIPE_STAGES_G       => PIPE_STAGES_G,
            SLAVE_READY_EN_G    => true,
            VALID_THOLD_G       => 1,
            BRAM_EN_G           => true,
            GEN_SYNC_FIFO_G     => true,
            CASCADE_SIZE_G      => 1,
            FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_C,
            FIFO_FIXED_THRESH_G => false,  -- Using r.threshold
            SLAVE_AXI_CONFIG_G  => AXIS_CONFIG_G,
            MASTER_AXI_CONFIG_G => AXIS_CONFIG_G) 
         port map (
            -- Slave Port
            sAxisClk        => axiClk,
            sAxisRst        => axiRst,
            sAxisMaster     => shiftMaster,
            sAxisSlave      => shiftSlave,
            sAxisCtrl       => cache,
            -- FIFO Port
            fifoPauseThresh => r.threshold,
            -- Master Port
            mAxisClk        => axiClk,
            mAxisRst        => axiRst,
            mAxisMaster     => intAxisMaster,
            mAxisSlave      => intAxisSlave);    

      wrEn <= shiftMaster.tValid and shiftMaster.tLast and shiftSlave.tReady;
      rdEn <= intAxisMaster.tValid and intAxisMaster.tLast and intAxisSlave.tReady;

      U_Last : entity work.FifoSync
         generic map (
            TPD_G        => TPD_G,
            BYP_RAM_G    => true,
            FWFT_EN_G    => true,
            ADDR_WIDTH_G => FIFO_ADDR_WIDTH_C)
         port map (
            clk   => axiClk,
            rst   => axiRst,
            wr_en => wrEn,
            rd_en => rdEn,
            din   => (others => '0'),
            valid => lastDet);            

   end generate;

   BYP_CACHE : if (BYP_CACHE_G = true) generate

      intAxisMaster  <= shiftMaster;
      shiftSlave     <= intAxisSlave;
      cache.pause    <= '1';
      cache.overflow <= '0';
      cache.idle     <= '0';
      lastDet        <= '0';
      
   end generate;

   comb : process (axiRst, axiWriteSlave, cache, dmaReq, intAxisMaster, lastDet, pause, r, swCache) is
      variable v       : RegType;
      variable bytes   : natural;
      variable ibValid : sl;
   begin
      -- Latch the current value
      v := r;

      -- Set cache value if enabled in software
      if SW_CACHE_EN_G then
         v.wMaster.awcache := swCache;
      end if;

      -- Reset strobing Signals
      ibValid        := '0';
      v.slave.tReady := '0';
      v.shiftEn      := '0';
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
         if (axiWriteSlave.bresp /= "00") then
            -- Set the flag
            v.dmaAck.writeError := '1';
            -- Latch the response value
            v.dmaAck.errorValue := axiWriteSlave.bresp;
         end if;
      end if;

      -- Check for handshaking
      if (dmaReq.request = '0') and (r.dmaAck.done = '1') then
         -- Reset the flags
         v.dmaAck.done := '0';
      end if;

      -- Count number of bytes in return data
      bytes := getTKeep(intAxisMaster.tKeep(DATA_BYTES_C-1 downto 0));

      -- Check the AXI stream data cache
      if (lastDet = '1') or (cache.pause = '1') then
         ibValid := '1';
      end if;

      -- State machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Update the variables
            v.dmaReq    := dmaReq;
            -- Reset the counters and threshold
            v.reqCount  := (others => '0');
            v.ackCount  := (others => '0');
            v.shift     := (others => '0');
            v.stCount   := (others => '0');
            v.threshold := (others => '1');
            -- Align shift and address to transfer size
            if (DATA_BYTES_C /= 1) then
               v.dmaReq.address(ADDR_LSB_C-1 downto 0) := (others => '0');
               v.shift(ADDR_LSB_C-1 downto 0)          := dmaReq.address(ADDR_LSB_C-1 downto 0);
            end if;
            -- Check for DMA request 
            if (dmaReq.request = '1') then
               -- Reset the flags and counters
               v.dmaAck.size       := (others => '0');
               v.dmaAck.overflow   := '0';
               v.dmaAck.writeError := '0';
               v.dmaAck.errorValue := (others => '0');
               -- Set the flags
               v.shiftEn           := '1';
               v.last              := '0';
               v.first             := '0';
               -- Check if we are dumping AXIS frames
               if (dmaReq.drop = '1') then
                  -- Next state
                  v.state := DUMP_S;
               else
                  -- Next state
                  v.state := FIRST_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when FIRST_S =>
            -- Check if ready to make memory request
            if (v.wMaster.awvalid = '0') then
               -- Set the memory address
               v.wMaster.awaddr(AXI_CONFIG_G.ADDR_WIDTH_C-1 downto 0) := r.dmaReq.address(AXI_CONFIG_G.ADDR_WIDTH_C-1 downto 0);
               -- Determine transfer size to align address to AXI_BURST_BYTES_G boundaries
               -- This initial alignment will ensure that we never cross a 4k boundary
               if (AWLEN_C > 0) then
                  -- Set the burst length
                  v.wMaster.awlen := AWLEN_C - r.dmaReq.address(ADDR_LSB_C+AXI_CONFIG_G.LEN_BITS_C-1 downto ADDR_LSB_C);
                  -- Limit write burst size
                  if r.dmaReq.maxSize(31 downto ADDR_LSB_C) < v.wMaster.awlen then
                     v.wMaster.awlen := resize(r.dmaReq.maxSize(ADDR_LSB_C+AXI_CONFIG_G.LEN_BITS_C-1 downto ADDR_LSB_C)-1, 8);
                  end if;
               end if;
               -- Latch AXI awlen value
               v.awlen     := v.wMaster.awlen(AXI_CONFIG_G.LEN_BITS_C-1 downto 0);
               -- Update the threshold
               v.threshold := '0' & v.awlen;
               v.threshold := v.threshold + 1;
               -- DMA request has dropped. Abort. This is needed to disable engine while it
               -- is still waiting for an inbound frame.
               if dmaReq.request = '0' then
                  -- Next state
                  v.state := IDLE_S;
               -- Check if enough room and data to move
               elsif (pause = '0') and (ibValid = '1') then
                  -- Set the flag
                  v.wMaster.awvalid := '1';
                  -- Increment the counter
                  v.reqCount        := r.reqCount + 1;
                  -- Next state
                  v.state           := MOVE_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when NEXT_S =>
            -- Check if ready to make memory request
            if (v.wMaster.awvalid = '0') then
               -- Set the memory address         
               v.wMaster.awaddr(AXI_CONFIG_G.ADDR_WIDTH_C-1 downto 0) := r.dmaReq.address(AXI_CONFIG_G.ADDR_WIDTH_C-1 downto 0);
               -- Bursts after the FIRST are garunteed to be aligned.
               v.wMaster.awlen                                        := AWLEN_C;
               if r.dmaReq.maxSize(31 downto ADDR_LSB_C) < v.wMaster.awlen then
                  v.wMaster.awlen := resize(r.dmaReq.maxSize(ADDR_LSB_C+AXI_CONFIG_G.LEN_BITS_C-1 downto ADDR_LSB_C)-1, 8);
               end if;
               -- Latch AXI awlen value
               v.awlen     := v.wMaster.awlen(AXI_CONFIG_G.LEN_BITS_C-1 downto 0);
               -- Update the threshold
               v.threshold := '0' & v.awlen;
               v.threshold := v.threshold + 1;
               -- DMA request has dropped. Abort. This is needed to disable engine while it
               -- is still waiting for an inbound frame.
               if dmaReq.request = '0' then
                  -- Next state
                  v.state := IDLE_S;
               -- Check if enough room and data to move
               elsif (pause = '0') and (ibValid = '1') then
                  -- Set the flag
                  v.wMaster.awvalid := '1';
                  -- Increment the counter
                  v.reqCount        := r.reqCount + 1;
                  -- Next state
                  v.state           := MOVE_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when MOVE_S =>
            -- Reset the threshold
            v.threshold := (others => '1');
            -- Check if ready to move data
            if (v.wMaster.wvalid = '0') and ((intAxisMaster.tValid = '1') or (r.last = '1')) then
               -- Accept the data
               v.slave.tReady                               := not(r.last);
               -- Move the data
               v.wMaster.wvalid                             := '1';
               v.wMaster.wdata((DATA_BYTES_C*8)-1 downto 0) := intAxisMaster.tData((DATA_BYTES_C*8)-1 downto 0);
               -- Address and size increment
               v.dmaReq.address                             := r.dmaReq.address + DATA_BYTES_C;
               v.dmaReq.address(ADDR_LSB_C-1 downto 0)      := (others => '0');
               -- Check if tLast not registered yet
               if (r.last = '0') then
                  -- Increment the byte counter
                  v.dmaAck.size := r.dmaAck.size + bytes;
               end if;
               -- -- Check for first AXIS word
               if (r.first = '0') then
                  -- Set the flag
                  v.first                                                   := '1';
                  -- Latch the tDest/tId/tUser values
                  v.dmaAck.dest                                             := intAxisMaster.tDest;
                  v.dmaAck.id                                               := intAxisMaster.tId;
                  v.dmaAck.firstUser(AXIS_CONFIG_G.TUSER_BITS_C-1 downto 0) := axiStreamGetUserField(AXIS_CONFIG_G, intAxisMaster, conv_integer(r.shift));
               end if;
               -- -- Check for last AXIS word
               if (intAxisMaster.tLast = '1') and (r.last = '0') then
                  -- Set the flag
                  v.last                                                   := '1';
                  -- Latch the tUser value
                  v.dmaAck.lastUser(AXIS_CONFIG_G.TUSER_BITS_C-1 downto 0) := axiStreamGetUserField(AXIS_CONFIG_G, intAxisMaster);
               end if;
               -- Check if done
               if (r.last = '1') then
                  -- Reset byte write strobes
                  v.wMaster.wstrb := (others => '0');
               -- Check the read size
               elsif (bytes > r.dmaReq.maxSize) then
                  -- Set the error flag
                  v.dmaAck.overflow := '1';
                  -- Reset byte write strobes
                  v.wMaster.wstrb   := (others => '0');
               else
                  -- Decrement the counter
                  v.dmaReq.maxSize                         := r.dmaReq.maxSize - bytes;
                  -- Set byte write strobes
                  v.wMaster.wstrb(DATA_BYTES_C-1 downto 0) := intAxisMaster.tKeep(DATA_BYTES_C-1 downto 0);
               end if;
               -- Check for last AXI transfer
               if (AWLEN_C = 0) or (r.awlen = 0) then
                  -- Set the flag
                  v.wMaster.wlast := '1';
                  -- Check if AXIS is completed
                  if (v.last = '1') then
                     -- Next state
                     v.state := WAIT_S;
                  -- Check the error flags
                  elsif (v.dmaAck.overflow = '1') or (v.dmaAck.writeError = '1') then
                     -- Next state
                     v.state := DUMP_S;
                  -- Continue to the next memory request transaction
                  else
                     -- Next state
                     v.state := NEXT_S;
                  end if;
               else
                  -- Decrement the counter
                  v.awlen := r.awlen - 1;
               end if;
            end if;
         ----------------------------------------------------------------------
         when DUMP_S =>
            -- Blowoff data 
            v.slave.tReady := '1';
            -- Check for data
            if (intAxisMaster.tValid = '1') then
               -- Check for first AXIS word
               if (r.first = '0') then
                  -- Set the flag
                  v.first                                                   := '1';
                  -- Latch the tDest/tId/tUser values
                  v.dmaAck.dest                                             := intAxisMaster.tDest;
                  v.dmaAck.id                                               := intAxisMaster.tId;
                  v.dmaAck.firstUser(AXIS_CONFIG_G.TUSER_BITS_C-1 downto 0) := axiStreamGetUserField(AXIS_CONFIG_G, intAxisMaster, conv_integer(r.shift));
               end if;
               -- Check for last AXIS word
               if (intAxisMaster.tLast = '1') then
                  -- Latch the tUser value
                  v.dmaAck.lastUser(AXIS_CONFIG_G.TUSER_BITS_C-1 downto 0) := axiStreamGetUserField(AXIS_CONFIG_G, intAxisMaster);
                  -- Next state
                  v.state                                                  := WAIT_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when WAIT_S =>
            -- Check if ACK counter caught up with REQ counter
            if (r.ackCount >= r.reqCount) or (ACK_WAIT_BVALID_G = false) then
               -- Set the flag
               v.dmaAck.done := '1';
               -- Next state
               v.state       := DONE_S;
            -- Check for ACK timeout   
            elsif (r.stCount = x"FFFF") then
               -- Set the flags
               v.dmaAck.done       := '1';
               v.dmaAck.writeError := '1';
               -- Next state
               v.state             := DONE_S;
            else
               -- Increment the counter
               v.stCount := r.stCount + 1;
            end if;
         ----------------------------------------------------------------------
         when DONE_S =>
            -- Check for ACK completion 
            if (r.dmaAck.done = '0') then
               -- Next state
               v.state := IDLE_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Forward the state of the state machine
      if (v.state = IDLE_S) then
         -- Set the flag
         v.dmaAck.idle := '1';
      else
         -- Reset the flag
         v.dmaAck.idle := '0';
      end if;

      -- Reset      
      if (axiRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle      
      rin <= v;

      -- Outputs   
      dmaAck         <= r.dmaAck;
      intAxisSlave   <= v.slave;
      axiWriteMaster <= r.wMaster;
      
   end process comb;

   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
