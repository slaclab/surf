-------------------------------------------------------------------------------
-- Title      : AXI Stream DMA Write
-- Project    : General Purpose Core
-------------------------------------------------------------------------------
-- File       : AxiStreamDmaWrite.vhd
-- Author     : Ryan Herbst, rherbst@slac.stanford.edu
-- Created    : 2014-04-25
-- Last update: 2016-05-04
-- Platform   : 
-- Standard   : VHDL'93/02
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
-- Modification history:
-- 04/25/2014: created.
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
      ACK_WAIT_BVALID_G : boolean             := true);
   port (

      -- Clock/Reset
      axiClk : in sl;
      axiRst : in sl;

      -- DMA Control Interface
      dmaReq : in  AxiWriteDmaReqType;
      dmaAck : out AxiWriteDmaAckType;

      -- Streaming Interface 
      axisMaster : in  AxiStreamMasterType;
      axisSlave  : out AxiStreamSlaveType;

      -- AXI Interface
      axiWriteMaster : out AxiWriteMasterType;
      axiWriteSlave  : in  AxiWriteSlaveType;
      axiWriteCtrl   : in  AxiCtrlType := AXI_CTRL_UNUSED_C
      );
end AxiStreamDmaWrite;

architecture structure of AxiStreamDmaWrite is

   constant DATA_BYTES_C : integer         := AXIS_CONFIG_G.TDATA_BYTES_C;
   constant ADDR_LSB_C   : integer         := bitSize(DATA_BYTES_C-1);
   constant AWLEN_C      : slv(7 downto 0) := getAxiLen(AXI_CONFIG_G, 4096);

   type StateType is (S_IDLE_C, S_FIRST_C, S_NEXT_C, S_DATA_C, S_LAST_C, S_DUMP_C, S_WAIT_C, S_DONE_C);

   type RegType is record
      state    : StateType;
      dmaReq   : AxiWriteDmaReqType;
      dmaAck   : AxiWriteDmaAckType;
      shift    : slv(3 downto 0);
      shiftEn  : sl;
      last     : sl;
      reqCount : slv(31 downto 0);
      ackCount : slv(31 downto 0);
      stCount  : slv(15 downto 0);
      wMaster  : AxiWriteMasterType;
      slave    : AxiStreamSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state    => S_IDLE_C,
      dmaReq   => AXI_WRITE_DMA_REQ_INIT_C,
      dmaAck   => AXI_WRITE_DMA_ACK_INIT_C,
      shift    => (others => '0'),
      shiftEn  => '0',
      last     => '0',
      reqCount => (others => '0'),
      ackCount => (others => '0'),
      stCount  => (others => '0'),
      wMaster  => axiWriteMasterInit(AXI_CONFIG_G, '1', AXI_BURST_G, AXI_CACHE_G),
      slave    => AXI_STREAM_SLAVE_INIT_C);

   signal r             : RegType := REG_INIT_C;
   signal rin           : RegType;
   signal selReady      : sl;
   signal selPause      : sl;
   signal intAxisMaster : AxiStreamMasterType;
   signal intAxisSlave  : AxiStreamSlaveType;

   signal wDataDebug : slv(AXI_CONFIG_G.DATA_BYTES_C*8-1 downto 0);

begin

   wDataDebug <= r.wMaster.wdata(AXI_CONFIG_G.DATA_BYTES_C*8-1 downto 0);

   assert AXIS_CONFIG_G.TDATA_BYTES_C = AXI_CONFIG_G.DATA_BYTES_C
      report "AXIS (" & integer'image(AXIS_CONFIG_G.TDATA_BYTES_C) & ") and AXI ("
      & integer'image(AXI_CONFIG_G.DATA_BYTES_C) & ") must have equal data widths" severity failure;

   -- Stream Shifter
   U_AxiStreamShift : entity work.AxiStreamShift
      generic map (
         TPD_G         => TPD_G,
         AXIS_CONFIG_G => AXIS_CONFIG_G
         ) port map (
            axisClk     => axiClk,
            axisRst     => axiRst,
            axiStart    => r.shiftEn,
            axiShiftDir => '0',
            axiShiftCnt => r.shift,
            sAxisMaster => axisMaster,
            sAxisSlave  => axisSlave,
            mAxisMaster => intAxisMaster,
            mAxisSlave  => intAxisSlave
            );

   -- Determine handshaking mode
   selReady <= axiWriteSlave.wready when AXI_READY_EN_G else '1';
   selPause <= '0'                  when AXI_READY_EN_G else axiWriteCtrl.pause;

   comb : process (axiRst, r, intAxisMaster, axiWriteSlave, dmaReq, selReady, selPause) is
      variable v     : RegType;
      variable bytes : natural;         --slv(bitSize(DATA_BYTES_C)-1 downto 0);
   begin
      v := r;

      -- Init
      v.slave.tReady    := '0';
      v.wMaster.awvalid := '0';
      v.shiftEn         := '0';

      -- Count number of bytes in return data
      bytes := getTKeep(intAxisMaster.tKeep(DATA_BYTES_C-1 downto 0));

      -- Count acks
      if axiWriteSlave.bvalid = '1' and ACK_WAIT_BVALID_G then
         v.ackCount := r.ackCount + 1;

         if axiWriteSlave.bresp /= "00" then
            v.dmaAck.writeError := '1';
            v.dmaAck.errorValue := axiWriteSlave.bresp;
         end if;
      end if;

      -- State machine
      case r.state is

         -- IDLE
         when S_IDLE_C =>
            v.wMaster  := axiWriteMasterInit(AXI_CONFIG_G, '1', AXI_BURST_G, AXI_CACHE_G);
            v.slave    := AXI_STREAM_SLAVE_INIT_C;
            v.reqCount := (others => '0');
            v.ackCount := (others => '0');
            v.shift    := (others => '0');
            v.last     := '0';
            v.dmaAck   := AXI_WRITE_DMA_ACK_INIT_C;
            v.dmaReq   := dmaReq;
            v.stCount  := (others => '0');

            -- Align shift and address to transfer size
            if DATA_BYTES_C /= 1 then
               v.dmaReq.address(ADDR_LSB_C-1 downto 0) := (others => '0');
               v.shift(ADDR_LSB_C-1 downto 0)          := dmaReq.address(ADDR_LSB_C-1 downto 0);
            end if;

            -- Start 
            if dmaReq.request = '1' then
               v.shiftEn := '1';

               if dmaReq.drop = '1' then
                  v.state := S_DUMP_C;
               else
                  v.state := S_FIRST_C;
               end if;
            end if;

         -- First
         when S_FIRST_C =>
            v.wMaster.awaddr(AXI_CONFIG_G.ADDR_WIDTH_C-1 downto 0) := r.dmaReq.address(AXI_CONFIG_G.ADDR_WIDTH_C-1 downto 0);

            -- Determine transfer size to align address to AXI_BURST_BYTES_G boundaries
            -- This initial alignment will ensure that we never cross a 4k boundary
            if (AWLEN_C > 0) then
               v.wMaster.awlen := AWLEN_C - r.dmaReq.address(ADDR_LSB_C+AXI_CONFIG_G.LEN_BITS_C-1 downto ADDR_LSB_C);

               -- Limit to maxSize
               if r.dmaReq.maxSize(31 downto ADDR_LSB_C) < v.wMaster.awlen then
                  v.wMaster.awlen := resize(r.dmaReq.maxSize(ADDR_LSB_C+AXI_CONFIG_G.LEN_BITS_C-1 downto ADDR_LSB_C)-1, 8);
               end if;
            end if;

            -- DMA request has dropped. Abort. This is needed to disable engine while it
            -- is still waiting for an inbound frame.
            if dmaReq.request = '0' then
               v.state := S_IDLE_C;

            -- There is enough room in the FIFO for a burst and address is ready
            elsif selPause = '0' and intAxisMaster.tValid = '1' then
               v.wMaster.awvalid := '1';
               v.reqCount        := r.reqCount + 1;
               v.state           := S_DATA_C;
            end if;

         -- Next Write
         when S_NEXT_C =>
            v.wMaster.awaddr(AXI_CONFIG_G.ADDR_WIDTH_C-1 downto 0) := r.dmaReq.address(AXI_CONFIG_G.ADDR_WIDTH_C-1 downto 0);

            -- Bursts after the FIRST are garunteed to be aligned.
            v.wMaster.awlen := AWLEN_C;
            if r.dmaReq.maxSize(31 downto ADDR_LSB_C) < v.wMaster.awlen then
               v.wMaster.awlen := resize(r.dmaReq.maxSize(ADDR_LSB_C+AXI_CONFIG_G.LEN_BITS_C-1 downto ADDR_LSB_C)-1, 8);
            end if;

            -- There is enough room in the FIFO for a burst
            if selPause = '0' then
               v.wMaster.awvalid := '1';
               v.reqCount        := r.reqCount + 1;
               v.state           := S_DATA_C;
            end if;

         -- Move Data
         when S_DATA_C =>
            v.wMaster.awvalid := r.wMaster.awvalid;
            if axiWriteSlave.awready = '1' then
               v.wMaster.awvalid := '0';
            end if;

            -- Ready and valid
            if selReady = '1' or r.wMaster.wvalid = '0' then
               v.wMaster.wvalid := intAxisMaster.tValid or r.last;
               v.slave.tReady   := (not r.last);
            else
               v.slave.tReady := '0';
            end if;

            -- Advance pipeline when incoming data is valid and outbound is ready
            -- or we have not yet asserted valid
            if (intAxisMaster.tValid = '1' or r.last = '1') and (selReady = '1' or r.wMaster.wvalid = '0') then
               v.wMaster.wdata((DATA_BYTES_C*8)-1 downto 0) := intAxisMaster.tData((DATA_BYTES_C*8)-1 downto 0);

               -- Address and size increment
               v.dmaReq.address := r.dmaReq.address + DATA_BYTES_C;
               v.dmaReq.address(ADDR_LSB_C-1 downto 0) := (others => '0');
               
               if r.last = '0' then
                  v.dmaAck.size := r.dmaAck.size + bytes;
               end if;

               -- First in packet
               if r.dmaAck.size = 0 then
                  v.dmaAck.dest := intAxisMaster.tDest;
                  v.dmaAck.id   := intAxisMaster.tId;
                  v.dmaAck.firstUser(AXIS_CONFIG_G.TUSER_BITS_C-1 downto 0) :=
                     axiStreamGetUserField(AXIS_CONFIG_G, intAxisMaster, conv_integer(r.shift));
               end if;

               -- Last in packet
               if intAxisMaster.tLast = '1' then
                  v.dmaAck.lastUser(AXIS_CONFIG_G.TUSER_BITS_C-1 downto 0) :=
                     axiStreamGetUserField(AXIS_CONFIG_G, intAxisMaster);
                  v.last := '1';
               end if;

               -- Last in transfer
               if AWLEN_C = 0 or r.wMaster.awlen(AXI_CONFIG_G.LEN_BITS_C-1 downto 0) = 0 then
                  v.wMaster.wlast := '1';
                  v.state         := S_LAST_C;
               else
                  v.wMaster.wlast := '0';
                  v.wMaster.awlen(AXI_CONFIG_G.LEN_BITS_C-1 downto 0)
                     := r.wMaster.awlen(AXI_CONFIG_G.LEN_BITS_C-1 downto 0) - 1;
               end if;

               -- Done
               if r.last = '1' then
                  v.wMaster.wstrb := (others => '0');

               -- Detect overflow
               elsif r.dmaAck.overflow = '1' or bytes > r.dmaReq.maxSize then
                  v.dmaAck.overflow := '1';
                  v.wMaster.wstrb   := (others => '0');
               else
                  v.dmaReq.maxSize                         := r.dmaReq.maxSize - bytes;
                  v.wMaster.wstrb(DATA_BYTES_C-1 downto 0) := intAxisMaster.tKeep(DATA_BYTES_C-1 downto 0);
               end if;
            end if;

         -- Last Trasfer Of A Burst Data
         when S_LAST_C =>
            -- Unlikely, but might still be waiting on address ack here
            v.wMaster.awvalid := r.wMaster.awvalid;
            if axiWriteSlave.awready = '1' then
               v.wMaster.awvalid := '0';
            end if;

            if (selReady = '1' and v.wMaster.awvalid = '0') then  
               if r.last = '1' then
                  v.state := S_WAIT_C;
               elsif r.dmaAck.overflow = '1' or r.dmaAck.writeError = '1' then
                  v.state := S_DUMP_C;
               else
                  v.state := S_NEXT_C;
               end if;
               v.wMaster.wvalid := '0';
            end if;

         -- Dump remaining data
         when S_DUMP_C =>
            v.slave.tReady := '1';

            if intAxisMaster.tLast = '1' and intAxisMaster.tValid = '1' then
               v.state := S_WAIT_C;
            end if;

         -- Wait for acks
         when S_WAIT_C =>
            if r.ackCount >= r.reqCount or not ACK_WAIT_BVALID_G then
               v.state       := S_DONE_C;
               v.dmaAck.done := '1';
            elsif r.stCount = x"FFFF" then
               v.state             := S_DONE_C;
               v.dmaAck.done       := '1';
               v.dmaAck.writeError := '1';
            else
               v.stCount := r.stCount + 1;
            end if;

         -- Done
         when S_DONE_C =>
            if dmaReq.request = '0' then
               v.dmaAck.done := '0';
               v.state       := S_IDLE_C;
            end if;

         when others =>
            v.state := S_IDLE_C;
      end case;

      if (axiRst = '1') then
         v := REG_INIT_C;
      end if;


      rin <= v;

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

end structure;
