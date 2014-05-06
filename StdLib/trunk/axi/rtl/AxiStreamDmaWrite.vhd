-------------------------------------------------------------------------------
-- Title      : AXI Stream DMA Write
-- Project    : General Purpose Core
-------------------------------------------------------------------------------
-- File       : AxiStreamDmaWrite.vhd
-- Author     : Ryan Herbst, rherbst@slac.stanford.edu
-- Created    : 2014-04-25
-- Last update: 2014-05-05
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-- Block to transfer a single AXI Stream frame into memory using an AXI
-- interface.
-------------------------------------------------------------------------------
-- Copyright (c) 2014 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 04/25/2014: created.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.ArbiterPkg.all;
use work.AxiStreamPkg.all;
use work.AxiPkg.all;

entity AxiStreamDmaWrite is
   generic (
      TPD_G            : time                := 1 ns;
      SLAVE_READY_EN_G : boolean             := false;
      AXIS_CONFIG_G    : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C;
      AXI_CONFIG_G     : AxiConfigType       := AXI_CONFIG_INIT_C;
      AXI_BURST_G      : slv(1 downto 0)     := "01";
      AXI_CACHE_G      : slv(3 downto 0)     := "1111"
   );
   port (

      -- Clock/Reset
      axiClk          : in  sl;
      axiRst          : in  sl;

      -- DMA Control Interface (dmaClk)
      dmaReq          : in  sl;
      dmaAddr         : in  slv(31 downto 0);
      dmaMaxSize      : in  slv(31 downto 0);
      dmaAck          : out sl;
      dmaSize         : out slv(31 downto 0);
      dmaOverflow     : out sl;
      dmaWriteErr     : out sl;

      -- Streaming Interface (dmaClk) (assume external FIFO)
      axisMaster     : in  AxiStreamMasterType;
      axisSlave      : out AxiStreamSlaveType;

      -- AXI Interface
      axiWriteMaster : out AxiWriteMasterType;
      axiWriteSlave  : in  AxiWriteSlaveType;
      axiWriteCtrl   : in  AxiCtrlType
   );
end AxiStreamDmaWrite;

architecture structure of AxiStreamDmaWrite is

   constant DATA_BYTES_C : integer := ite(AXIS_CONFIG_G.TDATA_BYTES_C < AXI_CONFIG_G.DATA_BYTES_C,
                                          AXIS_CONFIG_G.TDATA_BYTES_C,
                                          AXI_CONFIG_G.DATA_BYTES_C);

   type StateType is (S_IDLE_C, S_FIRST_C, S_NEXT_C, S_DATA_C, S_LAST_C, S_DUMP_C, S_WAIT_C, S_DONE_C);

   type RegType is record
      state    : StateType;
      address  : slv(31 downto 0);
      maxSize  : slv(31 downto 0);
      shift    : slv(3  downto 0);
      shiftEn  : sl;
      overflow : sl;
      respErr  : sl;
      reqCount : slv(31 downto 0);
      ackCount : slv(31 downto 0);
      done     : sl;
      ack      : sl;
      size     : slv(31 downto 0);
      master   : AxiWriteMasterType;
      slave    : AxiStreamSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state    => S_IDLE_C,
      address  => (others=>'0'),
      maxSize  => (others=>'0'),
      shift    => (others=>'0'),
      shiftEn  => '0',
      overflow => '0',
      respErr  => '0',
      reqCount => (others=>'0'),
      ackCount => (others=>'0'),
      done     => '0',
      ack      => '0',
      size     => (others=>'0'),
      master   => AXI_WRITE_MASTER_INIT_C,
      slave    => AXI_STREAM_SLAVE_INIT_C
      );

   signal r             : RegType := REG_INIT_C;
   signal rin           : RegType;
   signal selReady      : sl;
   signal selPause      : sl;
   signal intAxisMaster : AxiStreamMasterType;
   signal intAxisSlave  : AxiStreamSlaveType;

begin

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

   -- Determine handshaking mode, needs to be generic
   selReady <= axiWriteSlave.wready when SLAVE_READY_EN_G else '1';
   selPause <= '0'                  when SLAVE_READY_EN_G else axiWriteCtrl.pause;

   comb : process (axiRst, r, intAxisMaster, axiWriteSlave, dmaReq, dmaAddr, dmaMaxSize, selReady, selPause ) is
      variable v     : RegType;
      variable bytes : slv(3 downto 0);
   begin
      v := r;

      -- Init
      v.slave.tReady   := '0';
      v.master.awvalid := '0';
      v.master.bready  := '1';
      v.shiftEn        := '0';

      -- Count number of bytes in return data
      bytes := onesCount(intAxisMaster.tKeep);

      -- Count acks
      if axiWriteSlave.bvalid = '1' then
         v.ackCount := r.ackCount + 1;

         if axiWriteSlave.bresp /= "00" then
            v.respErr := '1';
         end if;
      end if;

      -- State machine
      case r.state is

         -- IDLE
         when S_IDLE_C =>
            v.maxSize  := dmaMaxSize;
            v.address  := dmaAddr(31 downto 3) & "000";
            v.shift    := '0' & dmaAddr(2 downto 0);
            v.reqCount := (others=>'0');
            v.ackCount := (others=>'0');
            v.done     := '0';
            v.ack      := '0';
            v.size     := (others=>'0');
            v.overflow := '0';
            v.respErr  := '0';

            -- Start 
            if dmaReq = '1' then
               v.shiftEn  := '1';
               v.state    := S_FIRST_C;
            end if;

         -- First
         when S_FIRST_C =>

            -- Determine transfer size to align all transfers to 128 byte boundaries
            -- This initial alignment will ensure that we never cross a 4k boundary
            v.master.awaddr   := r.address;
            v.master.awlen    := x"F" - r.address(6 downto 3);

            -- There is enough room in the FIFO for a burst and address is ready
            if selPause = '0' and axiWriteSlave.awready = '1' then
               v.master.awvalid := '1';
               v.reqCount       := r.reqCount + 1;
               v.state          := S_DATA_C;
            end if;

         -- Next Write
         when S_NEXT_C =>
            v.master.awaddr := r.address;
            v.master.awlen  := x"F";

            -- There is enough room in the FIFO for a burst and address is ready
            if selPause = '0' and axiWriteSlave.awready = '1' then
               v.master.awvalid := '1';
               v.reqCount       := r.reqCount + 1;
               v.state          := S_DATA_C;
            end if;
             
         -- Move Data
         when S_DATA_C =>

            -- Assert ready when incoming is ready and we are not done
            v.slave.tReady := selReady and (not r.done);

            -- Advance pipeline when incoming data is valid and outbound is ready
            -- or we have not yet asserted valid
            if intAxisMaster.tValid = '1' and (selReady = '1' or r.master.wvalid = '0') then
               v.master.wdata((DATA_BYTES_C*8)-1 downto 0) := intAxisMaster.tData((DATA_BYTES_C*8)-1 downto 0);
               v.master.wvalid := intAxisMaster.tValid;

               -- Address and size increment
               v.address := r.address + 8;
               v.size    := r.size + bytes;

               -- Last in packet
               if intAxisMaster.tLast = '1' then
                  v.done := '1';
               end if;

               -- Last in transfer
               if r.master.awlen = 0 then
                  v.master.wlast := '1';
                  v.state        := S_LAST_C;
               else
                  v.master.wlast := '0';
                  v.master.awlen := r.master.awlen - 1;
               end if;

               -- Init strobe
               v.master.wstrb(DATA_BYTES_C-1 downto 0) := intAxisMaster.tKeep(DATA_BYTES_C-1 downto 0);

               -- Detect overflow
               if r.overFlow = '1' or bytes > r.maxSize then
                  v.overFlow     := '1';
                  v.master.wstrb := (others=>'0');
               else
                  v.maxSize := r.maxSize - bytes;
               end if;

               -- Done
               if r.done = '1' then
                  v.master.wstrb := (others=>'0');
               end if;
            end if;

         -- Last Trasfer Of A Burst Data
         when S_LAST_C =>
            if selReady = '1' then
               if r.done = '1' then
                  v.state := S_WAIT_C;
               elsif r.overFlow = '1' or r.respErr = '1' then
                  v.state := S_DUMP_C;
               else
                  v.state := S_NEXT_C;
               end if;
               v.master.wvalid := '0';
            end if;

         -- Dump remaining data
         when S_DUMP_C =>
            v.slave.tReady := '1';

            if intAxisMaster.tLast = '1' then
               v.state := S_WAIT_C;
            end if;

         -- Wait for acks
         when S_WAIT_C =>
            if r.ackCount >= r.reqCount then
               v.state := S_DONE_C;
               v.ack   := '1';
            end if;

         -- Done
         when S_DONE_C =>
            if dmaReq = '0' then
               v.ack   := '0';
               v.state := S_IDLE_C;
            end if;

         when others =>
            v.state := S_IDLE_C;
      end case;

      if (axiRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Constants
      v.master.awsize  := conv_std_logic_vector(AXI_CONFIG_G.DATA_BYTES_C-1,3);
      v.master.awburst := AXI_BURST_G;
      v.master.awcache := AXI_CACHE_G;
      v.master.awlock  := "00";   -- Unused
      v.master.awprot  := "000";  -- Unused
      v.master.awid    := (others=>'0');
      v.master.wid     := (others=>'0');

      rin <= v;

      dmaAck         <= r.ack;
      dmaSize        <= r.size;
      dmaOverflow    <= r.overFlow;
      dmaWriteErr    <= r.respErr;
      intAxisSlave   <= v.slave;
      axiWriteMaster <= r.master;

   end process comb;

   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end structure;
