-------------------------------------------------------------------------------
-- File       : AxiStreamDma.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-25
-- Last update: 2016-10-27
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

entity AxiStreamDma is
   generic (
      TPD_G             : time                 := 1 ns;
      FREE_ADDR_WIDTH_G : integer              := 9;
      AXIL_COUNT_G      : integer range 1 to 2 := 1;
      AXIL_BASE_ADDR_G  : slv(31 downto 0)     := x"00000000";
      AXI_READY_EN_G    : boolean              := false;
      AXIS_READY_EN_G   : boolean              := false;
      AXIS_CONFIG_G     : AxiStreamConfigType  := AXI_STREAM_CONFIG_INIT_C;
      AXI_CONFIG_G      : AxiConfigType        := AXI_CONFIG_INIT_C;
      AXI_BURST_G       : slv(1 downto 0)      := "01";
      AXI_CACHE_G       : slv(3 downto 0)      := "1111";
      PEND_THRESH_G     : natural              := 0;
      BYP_SHIFT_G       : boolean              := false);
   port (
      -- Clock/Reset
      axiClk          : in  sl;
      axiRst          : in  sl;
      -- Register Access & Interrupt
      axilReadMaster  : in  AxiLiteReadMasterArray(AXIL_COUNT_G-1 downto 0);
      axilReadSlave   : out AxiLiteReadSlaveArray(AXIL_COUNT_G-1 downto 0);
      axilWriteMaster : in  AxiLiteWriteMasterArray(AXIL_COUNT_G-1 downto 0);
      axilWriteSlave  : out AxiLiteWriteSlaveArray(AXIL_COUNT_G-1 downto 0);
      interrupt       : out sl;
      online          : out sl;
      acknowledge     : out sl;
      -- AXI Stream Interface 
      sAxisMaster     : in  AxiStreamMasterType;
      sAxisSlave      : out AxiStreamSlaveType;
      mAxisMaster     : out AxiStreamMasterType;
      mAxisSlave      : in  AxiStreamSlaveType;
      mAxisCtrl       : in  AxiStreamCtrlType;
      -- AXI Interface
      axiReadMaster   : out AxiReadMasterType;
      axiReadSlave    : in  AxiReadSlaveType;
      axiWriteMaster  : out AxiWriteMasterType;
      axiWriteSlave   : in  AxiWriteSlaveType;
      axiWriteCtrl    : in  AxiCtrlType);
end AxiStreamDma;

architecture structure of AxiStreamDma is

   constant PUSH_ADDR_WIDTH_C : integer := FREE_ADDR_WIDTH_G;
   constant POP_ADDR_WIDTH_C  : integer := FREE_ADDR_WIDTH_G;

   constant POP_FIFO_PFULL_C : integer := (2**POP_ADDR_WIDTH_C) - 10;

   constant POP_FIFO_COUNT_C  : integer := 2;
   constant PUSH_FIFO_COUNT_C : integer := 2;

   constant IB_FIFO_C : integer := 0;
   constant OB_FIFO_C : integer := 1;

   constant CROSSBAR_CONN_C : slv(15 downto 0) := x"FFFF";

   constant LOC_INDEX_C     : natural          := 0;
   constant LOC_BASE_ADDR_C : slv(31 downto 0) := AXIL_BASE_ADDR_G(31 downto 12) & x"000";
   constant LOC_NUM_BITS_C  : natural          := 10;

   constant FIFO_INDEX_C     : natural          := 1;
   constant FIFO_BASE_ADDR_C : slv(31 downto 0) := AXIL_BASE_ADDR_G(31 downto 12) & x"400";
   constant FIFO_NUM_BITS_C  : natural          := 10;

   constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(1 downto 0) := (
      LOC_INDEX_C     => (
         baseAddr     => LOC_BASE_ADDR_C,
         addrBits     => LOC_NUM_BITS_C,
         connectivity => CROSSBAR_CONN_C),
      FIFO_INDEX_C    => (
         baseAddr     => FIFO_BASE_ADDR_C,
         addrBits     => FIFO_NUM_BITS_C,
         connectivity => CROSSBAR_CONN_C));

   type StateType is (
      IDLE_S,
      WAIT_S,
      FIFO_0_S,
      FIFO_1_S);

   type RegType is record
      maxRxSize     : slv(23 downto 0);
      interrupt     : sl;
      intEnable     : sl;
      intAck        : sl;
      acknowledge   : sl;
      online        : sl;
      rxEnable      : sl;
      txEnable      : sl;
      fifoClear     : sl;
      swCache       : slv(3 downto 0);
      axiReadSlave  : AxiLiteReadSlaveType;
      axiWriteSlave : AxiLiteWriteSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      maxRxSize     => (others => '0'),
      interrupt     => '0',
      intEnable     => '0',
      intAck        => '0',
      acknowledge   => '0',
      online        => '0',
      rxEnable      => '0',
      txEnable      => '0',
      fifoClear     => '1',
      swCache       => AXI_CACHE_G,
      axiReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axiWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   type IbType is record
      state        : StateType;
      intPending   : sl;
      ibReq        : AxiWriteDmaReqType;
      popFifoWrite : sl;
      popFifoDin   : slv(31 downto 0);
      pushFifoRead : sl;
   end record IbType;

   constant IB_INIT_C : IbType := (
      state        => IDLE_S,
      intPending   => '0',
      ibReq        => AXI_WRITE_DMA_REQ_INIT_C,
      popFifoWrite => '0',
      popFifoDin   => (others => '0'),
      pushFifoRead => '0');

   signal ib   : IbType := IB_INIT_C;
   signal ibin : IbType;

   type ObType is record
      state        : StateType;
      intPending   : sl;
      obReq        : AxiReadDmaReqType;
      popFifoWrite : sl;
      popFifoDin   : slv(31 downto 0);
      pushFifoRead : sl;
   end record ObType;

   constant OB_INIT_C : ObType := (
      state        => IDLE_S,
      intPending   => '0',
      obReq        => AXI_READ_DMA_REQ_INIT_C,
      popFifoWrite => '0',
      popFifoDin   => (others => '0'),
      pushFifoRead => '0');

   signal ob   : ObType := OB_INIT_C;
   signal obin : ObType;

   signal intReadMasters  : AxiLiteReadMasterArray(1 downto 0);
   signal intReadSlaves   : AxiLiteReadSlaveArray(1 downto 0);
   signal intWriteMasters : AxiLiteWriteMasterArray(1 downto 0);
   signal intWriteSlaves  : AxiLiteWriteSlaveArray(1 downto 0);

   signal popFifoClk    : slv(POP_FIFO_COUNT_C-1 downto 0);
   signal popFifoRst    : slv(POP_FIFO_COUNT_C-1 downto 0);
   signal popFifoValid  : slv(POP_FIFO_COUNT_C-1 downto 0);
   signal popFifoWrite  : slv(POP_FIFO_COUNT_C-1 downto 0);
   signal popFifoPFull  : slv(POP_FIFO_COUNT_C-1 downto 0);
   signal popFifoDin    : Slv32Array(POP_FIFO_COUNT_C-1 downto 0);
   signal pushFifoClk   : slv(POP_FIFO_COUNT_C-1 downto 0);
   signal pushFifoRst   : slv(POP_FIFO_COUNT_C-1 downto 0);
   signal pushFifoValid : slv(PUSH_FIFO_COUNT_C-1 downto 0);
   signal pushFifoDout  : Slv36Array(PUSH_FIFO_COUNT_C-1 downto 0);
   signal pushFifoRead  : slv(PUSH_FIFO_COUNT_C-1 downto 0);

   signal obAck : AxiReadDmaAckType;
   signal obReq : AxiReadDmaReqType;
   signal ibAck : AxiWriteDmaAckType;
   signal ibReq : AxiWriteDmaReqType;

   -- attribute dont_touch          : string;
   -- attribute dont_touch of ob    : signal is "true";
   -- attribute dont_touch of obAck : signal is "true";
   -- attribute dont_touch of obReq : signal is "true";
   -- attribute dont_touch of ib    : signal is "true";
   -- attribute dont_touch of ibAck : signal is "true";
   -- attribute dont_touch of ibReq : signal is "true";
   
begin

   process (axiClk) is
   begin
      if rising_edge(axiClk) then
         r  <= rin  after TPD_G;
         ib <= ibin after TPD_G;
         ob <= obin after TPD_G;
      end if;
   end process;

   U_CrossEnGen : if AXIL_COUNT_G = 1 generate
      U_AxiCrossbar : entity work.AxiLiteCrossbar
         generic map (
            TPD_G              => TPD_G,
            NUM_SLAVE_SLOTS_G  => 1,
            NUM_MASTER_SLOTS_G => 2,
            DEC_ERROR_RESP_G   => AXI_RESP_OK_C,
            MASTERS_CONFIG_G   => AXI_CROSSBAR_MASTERS_CONFIG_C) 
         port map (
            axiClk           => axiClk,
            axiClkRst        => axiRst,
            sAxiWriteMasters => axilWriteMaster,
            sAxiWriteSlaves  => axilWriteSlave,
            sAxiReadMasters  => axilReadMaster,
            sAxiReadSlaves   => axilReadSlave,
            mAxiWriteMasters => intWriteMasters,
            mAxiWriteSlaves  => intWriteSlaves,
            mAxiReadMasters  => intReadMasters,
            mAxiReadSlaves   => intReadSlaves);
   end generate;

   U_CrossDisGen : if AXIL_COUNT_G = 2 generate
      intWriteMasters <= axilWriteMaster;
      axilWriteSlave  <= intWriteSlaves;
      intReadMasters  <= axilReadMaster;
      axilReadSlave   <= intReadSlaves;
   end generate;

   U_SwFifos : entity work.AxiLiteFifoPushPop
      generic map (
         TPD_G             => TPD_G,
         POP_FIFO_COUNT_G  => 2,
         POP_SYNC_FIFO_G   => true,
         POP_BRAM_EN_G     => true,
         POP_ADDR_WIDTH_G  => POP_ADDR_WIDTH_C,
         POP_FULL_THRES_G  => POP_FIFO_PFULL_C,
         LOOP_FIFO_EN_G    => false,
         LOOP_FIFO_COUNT_G => 1,
         LOOP_BRAM_EN_G    => false,
         LOOP_ADDR_WIDTH_G => 9,
         PUSH_FIFO_COUNT_G => 2,
         PUSH_SYNC_FIFO_G  => true,
         PUSH_BRAM_EN_G    => true,
         PUSH_ADDR_WIDTH_G => PUSH_ADDR_WIDTH_C,
         RANGE_LSB_G       => 8,
         VALID_POSITION_G  => 31,
         VALID_POLARITY_G  => '1',
         ALTERA_SYN_G      => false,
         ALTERA_RAM_G      => "M9K",
         USE_BUILT_IN_G    => false,
         XIL_DEVICE_G      => "7SERIES") 
      port map (
         axiClk         => axiClk,
         axiClkRst      => axiRst,
         axiReadMaster  => intReadMasters(1),
         axiReadSlave   => intReadSlaves(1),
         axiWriteMaster => intWriteMasters(1),
         axiWriteSlave  => intWriteSlaves(1),
         popFifoValid   => popFifoValid,
         popFifoClk     => popFifoClk,
         popFifoRst     => popFifoRst,
         popFifoWrite   => popFifoWrite,
         popFifoDin     => popFifoDin,
         popFifoFull    => open,
         popFifoAFull   => open,
         popFifoPFull   => popFifoPFull,
         pushFifoClk    => pushFifoClk,
         pushFifoRst    => pushFifoRst,
         pushFifoValid  => pushFifoValid,
         pushFifoDout   => pushFifoDout,
         pushFifoRead   => pushFifoRead);

   U_ClkRstGen : for i in 0 to 1 generate
      popFifoClk(i)  <= axiClk;
      popFifoRst(i)  <= r.fifoClear;
      pushFifoClk(i) <= axiClk;
      pushFifoRst(i) <= r.fifoClear;
   end generate;

   -------------------------------------
   -- Local Register Space
   -------------------------------------
   process (axiRst, ib, intReadMasters, intWriteMasters, ob, popFifoValid, r) is
      variable v         : RegType;
      variable axiStatus : AxiLiteStatusType;
   begin
      v := r;

      v.intAck := '0';

      axiSlaveWaitTxn(intWriteMasters(0), intReadMasters(0), v.axiWriteSlave, v.axiReadSlave, axiStatus);

      -- Write
      if (axiStatus.writeEnable = '1') then

         case intWriteMasters(0).awaddr(7 downto 0) is
            when x"00" =>
               v.rxEnable := intWriteMasters(0).wdata(0);
            when x"04" =>
               v.txEnable := intWriteMasters(0).wdata(0);
            when x"08" =>
               v.fifoClear := intWriteMasters(0).wdata(0);
            when x"0C" =>
               v.intEnable := intWriteMasters(0).wdata(0);
            when x"14" =>
               v.maxRxSize := intWriteMasters(0).wdata(23 downto 0);
            when x"18" =>
               v.online      := intWriteMasters(0).wdata(0);
               v.acknowledge := intWriteMasters(0).wdata(1);
            when x"1C" =>
               v.intAck := intWriteMasters(0).wdata(0);
            when x"20" =>
               v.swCache := intWriteMasters(0).wdata(3 downto 0);
            when others =>
               null;
         end case;

         axiSlaveWriteResponse(v.axiWriteSlave);
      end if;

      -- Read
      if (axiStatus.readEnable = '1') then
         v.axiReadSlave.rdata := (others => '0');

         case intReadMasters(0).araddr(7 downto 0) is
            when x"00" =>
               v.axiReadSlave.rdata(0) := r.rxEnable;
            when x"04" =>
               v.axiReadSlave.rdata(0) := r.txEnable;
            when x"08" =>
               v.axiReadSlave.rdata(0) := r.fifoClear;
            when x"0C" =>
               v.axiReadSlave.rdata(0) := r.intEnable;
            when x"10" =>
               v.axiReadSlave.rdata(0) := popFifoValid(IB_FIFO_C);
               v.axiReadSlave.rdata(1) := popFifoValid(OB_FIFO_C);
            when x"14" =>
               v.axiReadSlave.rdata(23 downto 0) := r.maxRxSize;
            when x"18" =>
               v.axiReadSlave.rdata(0) := r.online;
               v.axiReadSlave.rdata(1) := r.acknowledge;
            when x"1C" =>
               v.axiReadSlave.rdata(0) := ib.intPending;
               v.axiReadSlave.rdata(1) := ob.intPending;
            when x"20" =>
               v.axiReadSlave.rdata(3 downto 0) := r.swCache;
            when others =>
               null;
         end case;

         -- Send Axi Response
         axiSlaveReadResponse(v.axiReadSlave);

      end if;

      v.interrupt := (ib.intPending or ob.intPending) and r.intEnable;

      -- Reset
      if (axiRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Next register assignment
      rin <= v;

      -- Outputs
      interrupt         <= r.interrupt;
      acknowledge       <= r.acknowledge;
      online            <= r.online;
      intReadSlaves(0)  <= r.axiReadSlave;
      intWriteSlaves(0) <= r.axiWriteSlave;
      
   end process;

   -------------------------------------
   -- Inbound Controller
   -------------------------------------
   U_IbDma : entity work.AxiStreamDmaWrite
      generic map (
         TPD_G          => TPD_G,
         AXI_READY_EN_G => AXI_READY_EN_G,
         AXIS_CONFIG_G  => AXIS_CONFIG_G,
         AXI_CONFIG_G   => AXI_CONFIG_G,
         AXI_BURST_G    => AXI_BURST_G,
         AXI_CACHE_G    => AXI_CACHE_G,
         SW_CACHE_EN_G  => true,
         BYP_SHIFT_G    => BYP_SHIFT_G) 
      port map (
         axiClk         => axiClk,
         axiRst         => axiRst,
         dmaReq         => ibReq,
         dmaAck         => ibAck,
         swCache        => r.swCache,
         axisMaster     => sAxisMaster,
         axisSlave      => sAxisSlave,
         axiWriteMaster => axiWriteMaster,
         axiWriteSlave  => axiWriteSlave,
         axiWriteCtrl   => axiWriteCtrl);

   process (axiRst, ib, ibAck, popFifoPFull, pushFifoDout, pushFifoValid, r) is
      variable v : IbType;
   begin
      v := ib;

      v.pushFifoRead := '0';
      v.popFifoWrite := '0';

      case ib.state is

         when IDLE_S =>
            v.ibReq.address := pushFifoDout(IB_FIFO_C)(31 downto 0);
            v.ibReq.maxSize := x"00" & r.maxRxSize;

            if pushFifoValid(IB_FIFO_C) = '1' and popFifoPFull(IB_FIFO_C) = '0' then
               v.ibReq.request := '1';
               v.pushFifoRead  := '1';
               v.state         := WAIT_S;
            end if;

         when WAIT_S =>
            v.popFifoDin := "1" & ib.ibReq.address(30 downto 0);

            if ibAck.done = '1' then
               v.popFifoWrite := '1';
               v.state        := FIFO_0_S;
            end if;

         when FIFO_0_S =>
            v.popFifoDin(31 downto 24) := x"E0";
            v.popFifoDin(23 downto 0)  := ibAck.size(23 downto 0);
            v.popFifoWrite             := '1';
            v.state                    := FIFO_1_S;

         when FIFO_1_S =>
            v.popFifoDin(31 downto 26) := x"F" & "00";
            v.popFifoDin(25)           := ibAck.overflow;
            v.popFifoDin(24)           := ibAck.writeError;
            v.popFifoDin(23 downto 16) := ibAck.lastUser;
            v.popFifoDin(15 downto 8)  := ibAck.firstUser;
            v.popFifoDin(7 downto 0)   := ibAck.dest;
            v.popFifoWrite             := '1';
            v.ibReq.request            := '0';
            v.intPending               := '1';
            v.state                    := IDLE_S;

      end case;

      -- Interrupt Ack
      if r.intAck = '1' then
         v.intPending := '0';
      end if;

      -- Reset
      if axiRst = '1' or r.rxEnable = '0' then
         v := IB_INIT_C;
      end if;

      -- Next register assignment
      ibin <= v;

      -- Outputs
      ibReq                   <= ib.ibReq;
      popFifoWrite(IB_FIFO_C) <= ib.popFifoWrite;
      popFifoDin(IB_FIFO_C)   <= ib.popFifoDin;
      pushFifoRead(IB_FIFO_C) <= ib.pushFifoRead;

   end process;

   -------------------------------------
   -- Outbound Controller
   -------------------------------------
   U_ObDma : entity work.AxiStreamDmaRead
      generic map (
         TPD_G           => TPD_G,
         AXIS_READY_EN_G => AXIS_READY_EN_G,
         AXIS_CONFIG_G   => AXIS_CONFIG_G,
         AXI_CONFIG_G    => AXI_CONFIG_G,
         AXI_BURST_G     => AXI_BURST_G,
         AXI_CACHE_G     => AXI_CACHE_G,
         SW_CACHE_EN_G   => true,
         PEND_THRESH_G   => PEND_THRESH_G,
         BYP_SHIFT_G     => BYP_SHIFT_G) 
      port map (
         axiClk        => axiClk,
         axiRst        => axiRst,
         dmaReq        => obReq,
         dmaAck        => obAck,
         swCache       => r.swCache,
         axisMaster    => mAxisMaster,
         axisSlave     => mAxisSlave,
         axisCtrl      => mAxisCtrl,
         axiReadMaster => axiReadMaster,
         axiReadSlave  => axiReadSlave);

   process (axiRst, ob, obAck, pushFifoDout, pushFifoValid, r) is
      variable v : ObType;
   begin
      v := ob;

      v.pushFifoRead := '0';
      v.popFifoWrite := '0';

      case ob.state is

         when IDLE_S =>
            v.obReq.address := pushFifoDout(OB_FIFO_C)(31 downto 0);

            if pushFifoValid(OB_FIFO_C) = '1' then
               v.pushFifoRead := '1';

               if pushFifoDout(OB_FIFO_C)(35 downto 32) = 3 then
                  v.popFifoDin   := "1" & pushFifoDout(OB_FIFO_C)(30 downto 0);
                  v.popFifoWrite := '1';

               elsif pushFifoDout(OB_FIFO_C)(35 downto 32) = 0 then
                  v.state := FIFO_0_S;
               end if;
            end if;

         when FIFO_0_S =>
            v.obReq.size := x"00" & pushFifoDout(OB_FIFO_C)(23 downto 0);

            if pushFifoValid(OB_FIFO_C) = '1' then
               v.pushFifoRead := '1';

               if pushFifoDout(OB_FIFO_C)(35 downto 32) /= 1 then
                  v.state := IDLE_S;
               else
                  v.state := FIFO_1_S;
               end if;
            end if;

         when FIFO_1_S =>
            v.obReq.lastUser  := pushFifoDout(OB_FIFO_C)(23 downto 16);
            v.obReq.firstUser := pushFifoDout(OB_FIFO_C)(15 downto 8);
            v.obReq.dest      := pushFifoDout(OB_FIFO_C)(7 downto 0);
            v.obReq.id        := (others => '0');

            if pushFifoValid(OB_FIFO_C) = '1' then
               v.pushFifoRead := '1';

               if pushFifoDout(OB_FIFO_C)(35 downto 32) /= 2 then
                  v.state := IDLE_S;
               else
                  v.obReq.request := '1';
                  v.state         := WAIT_S;
               end if;
            end if;

         when WAIT_S =>
            if obAck.done = '1' then
               v.obReq.request := '0';
               v.popFifoDin    := "1" & ob.obReq.address(30 downto 0);
               v.popFifoWrite  := '1';
               v.intPending    := '1';
               v.state         := IDLE_S;
            end if;

      end case;

      -- Interrupt Ack
      if r.intAck = '1' then
         v.intPending := '0';
      end if;

      -- Reset
      if axiRst = '1' or r.txEnable = '0' then
         v := OB_INIT_C;
      end if;

      -- Next register assignment
      obin <= v;

      -- Outputs
      obReq                   <= ob.obReq;
      popFifoWrite(OB_FIFO_C) <= ob.popFifoWrite;
      popFifoDin(OB_FIFO_C)   <= ob.popFifoDin;
      pushFifoRead(OB_FIFO_C) <= v.pushFifoRead;

   end process;
   
end structure;
