-------------------------------------------------------------------------------
-- File       : AxiStreamDmaV2Read.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-02-02
-- Last update: 2017-02-02
-------------------------------------------------------------------------------
-- Description:
-- Block to transfer a single AXI Stream frame from memory using an AXI
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

entity AxiStreamDmaV2Read is
   generic (
      TPD_G           : time                    := 1 ns;
      AXIS_READY_EN_G : boolean                 := false;
      AXIS_CONFIG_G   : AxiStreamConfigType     := AXI_STREAM_CONFIG_INIT_C;
      AXI_CONFIG_G    : AxiConfigType           := AXI_CONFIG_INIT_C;
      PIPE_STAGES_G   : natural                 := 1;
      BURST_BYTES_G   : integer range 1 to 4096 := 4096;
      PEND_THRESH_G   : natural                 := 0);  -- In units of bytes
   port (
      -- Clock/Reset
      axiClk          : in  sl;
      axiRst          : in  sl;
      -- DMA Control Interface 
      dmaRdDescReq    : in  AxiReadDmaDescReqType;
      dmaRdDescAck    : out sl;
      dmaRdDescRet    : out AxiReadDmaDescRetType;
      dmaRdDescRetAck : in  sl;
      -- Config and status
      dmaRdIdle       : out sl;
      axiCache        : in  slv(3 downto 0);
      -- Streaming Interface 
      axisMaster      : out AxiStreamMasterType;
      axisSlave       : in  AxiStreamSlaveType;
      axisCtrl        : in  AxiStreamCtrlType;
      -- AXI Interface
      axiReadMaster   : out AxiReadMasterType;
      axiReadSlave    : in  AxiReadSlaveType);
end AxiStreamDmaV2Read;

architecture rtl of AxiStreamDmaV2Read is

   constant DATA_BYTES_C : integer         := AXIS_CONFIG_G.TDATA_BYTES_C;
   constant ADDR_LSB_C   : integer         := bitSize(DATA_BYTES_C-1);
   constant ARLEN_C      : slv(7 downto 0) := getAxiLen(AXI_CONFIG_G, BURST_BYTES_G);

   type ReqStateType is (
      IDLE_S,
      ADDR_S);

   type StateType is (
      IDLE_S,
      MOVE_S,
      DONE_S,
      BLOWOFF_S);      

   type RegType is record
      idle         : sl;
      --pendBytes    : slv(31 downto 0);
      size         : slv(31 downto 0); -- Decrementing counter used in data collection engine
      reqSize      : slv(31 downto 0); -- Decrementing counter used in request engine
      reqCnt       : slv(31 downto 0); -- Total bytes requested
      ackCnt       : slv(31 downto 0); -- Total bytes received
      dmaRdDescReq : AxiReadDmaDescReqType;
      dmaRdDescAck : sl;
      dmaRdDescRet : AxiReadDmaDescRetType;
      first        : sl;
      leftovers    : sl;
      rMaster      : AxiReadMasterType;
      sMaster      : AxiStreamMasterType;
      reqState     : ReqStateType;
      state        : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      idle         => '0',
      --pendBytes    => (others => '0'),
      size         => (others => '0'),
      reqSize      => (others => '0'),
      reqCnt       => (others => '0'),
      ackCnt       => (others => '0'),
      dmaRdDescReq => AXI_READ_DMA_DESC_REQ_INIT_C,
      dmaRdDescAck => '0',
      dmaRdDescRet => AXI_READ_DMA_DESC_RET_INIT_C,
      first        => '0',
      leftovers    => '0',
      rMaster      => axiReadMasterInit(AXI_CONFIG_G, "01", "0000"),
      sMaster      => axiStreamMasterInit(AXIS_CONFIG_G),
      reqState     => IDLE_S,
      state        => IDLE_S);

   signal r          : RegType := REG_INIT_C;
   signal rin        : RegType;
   signal pause      : sl;
   signal sSlave     : AxiStreamSlaveType;
   signal mSlave     : AxiStreamSlaveType;

   attribute dont_touch      : string;
   attribute dont_touch of r : signal is "TRUE";

begin

   assert AXIS_CONFIG_G.TDATA_BYTES_C = AXI_CONFIG_G.DATA_BYTES_C
      report "AXIS (" & integer'image(AXIS_CONFIG_G.TDATA_BYTES_C) & ") and AXI ("
      & integer'image(AXI_CONFIG_G.DATA_BYTES_C) & ") must have equal data widths" severity failure;

   pause <= '0' when (AXIS_READY_EN_G) else axisCtrl.pause;

   comb : process (axiReadSlave, axiRst, dmaRdDescReq, dmaRdDescRetAck,  pause, r, sSlave, axiCache) is
      variable v        : RegType;
      variable reqLen   : natural;
      variable pendBytes: natural;
      variable pending  : boolean;
   begin
      -- Latch the current value   
      v := r;

      -- AXI Cache Setting
      v.rMaster.arcache := axiCache;

      -- Reset strobing Signals
      v.rMaster.rready := '0';
      if (axiReadSlave.arready = '1') then
         v.rMaster.arvalid := '0';
      end if;
      if (sSlave.tReady = '1') then
         v.sMaster.tValid := '0';
         v.sMaster.tLast  := '0';
         v.sMaster.tUser  := (others => '0');
         v.sMaster.tKeep  := (others => '1');
         v.sMaster.tStrb  := (others => '1');
      end if;

      -- Calculate the pending bytes
      --v.pendBytes := r.reqCnt - r.ackCnt;
      pendBytes := conv_integer(r.reqCnt - r.ackCnt);

      -- Update variables
      reqLen  := 0;
      pending := true;

      -- Check for the threshold = zero case
      if (PEND_THRESH_G = 0) then
         --if (r.pendBytes = 0) then
         if (pendBytes = 0) then
            pending := false;
         end if;
      else
         --if (r.pendBytes < PEND_THRESH_G) then
         if (pendBytes < PEND_THRESH_G) then
            pending := false;
         end if;
      end if;

      -- Track read status
      if (axiReadSlave.rvalid = '1') and (axiReadSlave.rresp /= 0) and (axiReadSlave.rlast = '1') then
         -- Error Detected
         v.dmaRdDescRet.result(1 downto 0) := axiReadSlave.rresp;
      end if;

      -- Clear descriptor handshake
      if dmaRdDescRetAck = '1' then
         v.dmaRdDescRet.valid := '0';
      end if;
      v.dmaRdDescAck := '0';

      -- Memory Request State machine
      case r.reqState is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Update the variables
            v.dmaRdDescReq := dmaRdDescReq;
            -- Init return
            v.dmaRdDescRet.valid  := '0';
            v.dmaRdDescRet.buffId := dmaRdDescReq.buffId;
            v.dmaRdDescRet.result := (others=>'0');
            -- Force address alignment
            v.dmaRdDescReq.address(ADDR_LSB_C-1 downto 0) := (others => '0');
            -- Reset the counters
            v.reqCnt := (others => '0');
            v.ackCnt := (others => '0');
            -- Check for DMA request 
            if dmaRdDescReq.valid = '1' then
               v.dmaRdDescAck := '1';
               -- Set the flags
               v.first := '1';
               -- Latch the value
               v.size          := dmaRdDescReq.size;
               v.reqSize       := dmaRdDescReq.size;
               v.sMaster.tDest := dmaRdDescReq.dest;
               v.sMaster.tId   := dmaRdDescReq.id;
               -- Next state
               v.reqState      := ADDR_S;
            end if;
         ----------------------------------------------------------------------
         when ADDR_S =>
            -- Check if ready to make memory request
            if (r.rMaster.arvalid = '0') then
               -- Set the memory address 
               v.rMaster.araddr(AXI_CONFIG_G.ADDR_WIDTH_C-1 downto 0) := r.dmaRdDescReq.address(AXI_CONFIG_G.ADDR_WIDTH_C-1 downto 0);
               -- Determine transfer size to align address to transfer size boundaries
               -- This will ensure that we never cross a 4k boundary
               if (ARLEN_C > 0) then
                  -- Set the burst length
                  v.rMaster.arlen := ARLEN_C - r.dmaRdDescReq.address(ADDR_LSB_C+AXI_CONFIG_G.LEN_BITS_C-1 downto ADDR_LSB_C);
                  -- Limit read burst size
                  if (r.reqSize(31 downto ADDR_LSB_C) < v.rMaster.arlen) then
                     v.rMaster.arlen := resize(r.reqSize(ADDR_LSB_C+AXI_CONFIG_G.LEN_BITS_C-1 downto ADDR_LSB_C)-1, 8);
                  end if;
               end if;
               -- Check for the following:
               --    1) There is enough room in the FIFO for a burst 
               --    2) pending flag
               --    3) Last transaction already completed
               if (pause = '0') and (pending = false) and (r.reqCnt < r.dmaRdDescReq.size) then
                  -- Set the flag
                  v.rMaster.arvalid := '1';
                  -- Update the request size
                  reqLen    := DATA_BYTES_C*(conv_integer(v.rMaster.arlen) + 1);
                  v.reqCnt  := r.reqCnt + reqLen;
                  v.reqSize := r.reqSize - reqLen;
                  -- Update next address
                  v.dmaRdDescReq.address                        := r.dmaRdDescReq.address + reqLen;
                  v.dmaRdDescReq.address(ADDR_LSB_C-1 downto 0) := (others => '0');
                  -- Next state
                  v.state := MOVE_S;
               end if;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Data Collection State machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Blowoff any out-of-phase data (should never happen)
            v.rMaster.rready := '1';
         ----------------------------------------------------------------------
         when MOVE_S =>

            -- Flow control
            if (v.sMaster.tValid = '0') then
               v.rMaster.rready := '1';
            end if;

            -- Check if ready to move data
            if (v.sMaster.tValid = '0') and (axiReadSlave.rvalid = '1') then
               -- Move the data
               v.sMaster.tValid                             := '1';
               v.sMaster.tData((DATA_BYTES_C*8)-1 downto 0) := axiReadSlave.rdata((DATA_BYTES_C*8)-1 downto 0);
               -- Check the flag
               if r.first = '1' then
                  -- Reset the flag
                  v.first := '0';
                  -- Set the tUser for the first byte transferred
                  axiStreamSetUserField(
                     AXIS_CONFIG_G,
                     v.sMaster,
                     r.dmaRdDescReq.firstUser(AXIS_CONFIG_G.TUSER_BITS_C-1 downto 0),0);
               end if;
               -- Check the read size
               if (DATA_BYTES_C > r.size) then
                  -- Bottom out at 0
                  v.size   := (others => '0');
                  -- Top out at dma.size
                  v.ackCnt := r.dmaRdDescReq.size;
               else
                  -- Decrement the counter
                  v.size   := r.size - DATA_BYTES_C;
                  -- Increment the counter
                  v.ackCnt := r.ackCnt + DATA_BYTES_C;
               end if;
               -- Check for completion 
               if (v.size = 0) then
                  -- Terminate the frame
                  v.sMaster.tLast := not r.dmaRdDescReq.continue;
                  v.sMaster.tKeep := genTKeep(conv_integer(r.size(4 downto 0)));
                  v.sMaster.tStrb := genTKeep(conv_integer(r.size(4 downto 0)));
                  -- Set last user field
                  axiStreamSetUserField (AXIS_CONFIG_G, v.sMaster, r.dmaRdDescReq.lastUser(AXIS_CONFIG_G.TUSER_BITS_C-1 downto 0));
                  -- Set the flags
                  v.dmaRdDescRet.valid := '1';
                  v.leftovers   := not(axiReadSlave.rlast);
                  -- Next state
                  v.state := DONE_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when DONE_S =>
            -- Check for ACK completion 
            if (r.dmaRdDescRet.valid = '0')then
               -- Reset the flag
               v.leftovers := '0';
               -- Check if no leftover memory request data
               if r.leftovers = '0' then
                  -- Next states
                  v.reqState := IDLE_S;
                  v.state    := IDLE_S;
               else
                  -- Next state
                  v.state := BLOWOFF_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when BLOWOFF_S =>
            -- Blowoff the data 
            v.rMaster.rready := '1';
            -- Check for last transfer
            if (axiReadSlave.rvalid = '1') and (axiReadSlave.rlast = '1') then
               -- Next states
               v.reqState := IDLE_S;
               v.state    := IDLE_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Forward the state of the state machine
      if v.state = IDLE_S then
         -- Set the flag
         v.idle := '1';
      else
         -- Reset the flag
         v.idle := '0';
      end if;

      -- Reset      
      if (axiRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle      
      rin <= v;

      -- Outputs         
      dmaRdIdle            <= r.idle;
      dmaRdDescAck         <= r.dmaRdDescAck;
      dmaRdDescRet         <= r.dmaRdDescRet;
      axiReadMaster        <= r.rMaster;
      axiReadMaster.rready <= v.rMaster.rready;

   end process comb;

   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_Pipeline : entity work.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
         PIPE_STAGES_G => PIPE_STAGES_G)
      port map (
         axisClk     => axiClk,
         axisRst     => axiRst,
         sAxisMaster => r.sMaster,
         sAxisSlave  => sSlave,
         mAxisMaster => axisMaster,
         mAxisSlave  => mSlave);

   mSlave <= axisSlave when(AXIS_READY_EN_G) else AXI_STREAM_SLAVE_FORCE_C;
   
end rtl;
