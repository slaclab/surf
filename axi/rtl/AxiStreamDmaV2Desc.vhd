-------------------------------------------------------------------------------
-- File       : AxiStreamDmaV2Desc.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-02-02
-- Last update: 2017-09-15
-------------------------------------------------------------------------------
-- Description:
-- Descriptor manager for AXI DMA read and write engines.
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
use ieee.NUMERIC_STD.all;

use work.StdRtlPkg.all;
use work.AxiPkg.all;
use work.AxiLitePkg.all;
use work.AxiDmaPkg.all;
use work.ArbiterPkg.all;

entity AxiStreamDmaV2Desc is
   generic (
      TPD_G             : time                  := 1 ns;
      CHAN_COUNT_G      : integer range 1 to 16 := 1;
      AXIL_BASE_ADDR_G  : slv(31 downto 0)      := x"00000000";
      AXI_ERROR_RESP_G  : slv(1 downto 0)       := AXI_RESP_OK_C;
      AXI_READY_EN_G    : boolean               := false;
      AXI_CONFIG_G      : AxiConfigType         := AXI_CONFIG_INIT_C;
      DESC_AWIDTH_G     : integer range 4 to 12 := 12;
      DESC_ARB_G        : boolean               := true;
      ACK_WAIT_BVALID_G : boolean               := true);
   port (
      -- Clock/Reset
      axiClk          : in  sl;
      axiRst          : in  sl;
      -- Local AXI Lite Bus
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      -- Additional signals
      interrupt       : out sl;
      online          : out slv(CHAN_COUNT_G-1 downto 0);
      acknowledge     : out slv(CHAN_COUNT_G-1 downto 0);
      -- DMA write descriptor request, ack and return
      dmaWrDescReq    : in  AxiWriteDmaDescReqArray(CHAN_COUNT_G-1 downto 0);
      dmaWrDescAck    : out AxiWriteDmaDescAckArray(CHAN_COUNT_G-1 downto 0);
      dmaWrDescRet    : in  AxiWriteDmaDescRetArray(CHAN_COUNT_G-1 downto 0);
      dmaWrDescRetAck : out slv(CHAN_COUNT_G-1 downto 0);
      -- DMA read descriptor request, ack and return
      dmaRdDescReq    : out AxiReadDmaDescReqArray(CHAN_COUNT_G-1 downto 0);
      dmaRdDescAck    : in  slv(CHAN_COUNT_G-1 downto 0);
      dmaRdDescRet    : in  AxiReadDmaDescRetArray(CHAN_COUNT_G-1 downto 0);
      dmaRdDescRetAck : out slv(CHAN_COUNT_G-1 downto 0);
      -- Config
      axiCache        : out slv(3 downto 0);
      -- AXI Interface
      axiWriteMaster  : out AxiWriteMasterType;
      axiWriteSlave   : in  AxiWriteSlaveType;
      axiWriteCtrl    : in  AxiCtrlType := AXI_CTRL_UNUSED_C);
end AxiStreamDmaV2Desc;

architecture rtl of AxiStreamDmaV2Desc is

   constant CROSSBAR_CONN_C : slv(15 downto 0) := x"FFFF";

   constant CB_COUNT_C : integer := 2;

   constant LOC_INDEX_C     : natural          := 0;
   constant LOC_BASE_ADDR_C : slv(31 downto 0) := AXIL_BASE_ADDR_G(31 downto 16) & x"0000";
   constant LOC_NUM_BITS_C  : natural          := 14;

   constant ADDR_INDEX_C     : natural          := 1;
   constant ADDR_BASE_ADDR_C : slv(31 downto 0) := AXIL_BASE_ADDR_G(31 downto 16) & x"4000";
   constant ADDR_NUM_BITS_C  : natural          := 14;

   constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(CB_COUNT_C-1 downto 0) := (
      LOC_INDEX_C     => (
         baseAddr     => LOC_BASE_ADDR_C,
         addrBits     => LOC_NUM_BITS_C,
         connectivity => CROSSBAR_CONN_C),
      ADDR_INDEX_C    => (
         baseAddr     => ADDR_BASE_ADDR_C,
         addrBits     => ADDR_NUM_BITS_C,
         connectivity => CROSSBAR_CONN_C));

   signal intReadMasters  : AxiLiteReadMasterArray(CB_COUNT_C-1 downto 0);
   signal intReadSlaves   : AxiLiteReadSlaveArray(CB_COUNT_C-1 downto 0);
   signal intWriteMasters : AxiLiteWriteMasterArray(CB_COUNT_C-1 downto 0);
   signal intWriteSlaves  : AxiLiteWriteSlaveArray(CB_COUNT_C-1 downto 0);

   type DescStateType is (IDLE_S, WRITE_S, READ_S, WAIT_S);

   constant CHAN_SIZE_C  : integer := bitSize(CHAN_COUNT_G-1);
   constant DESC_COUNT_C : integer := CHAN_COUNT_G*2;
   constant DESC_SIZE_C  : integer := bitSize(DESC_COUNT_C-1);

   type RegType is record

      -- Write descriptor interface
      dmaWrDescAck    : AxiWriteDmaDescAckArray(CHAN_COUNT_G-1 downto 0);
      dmaWrDescRetAck : slv(CHAN_COUNT_G-1 downto 0);

      -- Read descriptor interface
      dmaRdDescReq    : AxiReadDmaDescReqArray(CHAN_COUNT_G-1 downto 0);
      dmaRdDescRetAck : slv(CHAN_COUNT_G-1 downto 0);

      -- Axi-Lite
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;

      -- AXI
      axiWriteMaster : AxiWriteMasterType;

      -- Configuration
      buffBaseAddr : slv(63 downto 32);  -- For buffer entries
      wrBaseAddr   : slv(63 downto 0);   -- For wr ring buffer
      rdBaseAddr   : slv(63 downto 0);   -- For rd ring buffer
      maxSize      : slv(23 downto 0);
      contEn       : sl;
      dropEn       : sl;
      enable       : sl;
      intEnable    : sl;
      online       : slv(CHAN_COUNT_G-1 downto 0);
      acknowledge  : slv(CHAN_COUNT_G-1 downto 0);
      fifoReset    : sl;
      intAckEn     : sl;
      intAckCount  : slv(31 downto 0);
      descCache    : slv(3 downto 0);
      buffCache    : slv(3 downto 0);

      -- FIFOs
      fifoDin        : slv(31 downto 0);
      wrFifoWr       : sl;
      rdFifoWr       : slv(1 downto 0);
      addrFifoSel    : sl;
      wrFifoRd       : sl;
      wrFifoValidDly : slv(1 downto 0);
      wrAddr         : slv(31 downto 0);
      wrAddrValid    : sl;
      rdFifoRd       : sl;
      rdFifoValidDly : slv(1 downto 0);
      rdAddr         : slv(31 downto 0);
      rdAddrValid    : sl;

      -- Write Desc Request
      wrReqValid  : sl;
      wrReqCnt    : natural range 0 to CHAN_COUNT_G-1;
      wrReqNum    : slv(CHAN_SIZE_C-1 downto 0);
      wrReqAcks   : slv(CHAN_COUNT_G-1 downto 0);
      wrReqMissed : slv(31 downto 0);

      -- Desc Return
      descRetList : slv(DESC_COUNT_C-1 downto 0);
      descState   : DescStateType;
      descRetCnt  : natural range 0 to DESC_COUNT_C-1;
      descRetNum  : slv(DESC_SIZE_C-1 downto 0);
      descRetAcks : slv(DESC_COUNT_C-1 downto 0);
      wrIndex     : slv(DESC_AWIDTH_G-1 downto 0);
      wrMemAddr   : slv(63 downto 0);
      rdIndex     : slv(DESC_AWIDTH_G-1 downto 0);
      rdMemAddr   : slv(63 downto 0);
      intReqEn    : sl;
      intReqCount : slv(31 downto 0);
      interrupt   : sl;

   end record RegType;

   constant REG_INIT_C : RegType := (
      dmaWrDescAck    => (others => AXI_WRITE_DMA_DESC_ACK_INIT_C),
      dmaWrDescRetAck => (others => '0'),
      dmaRdDescReq    => (others => AXI_READ_DMA_DESC_REQ_INIT_C),
      dmaRdDescRetAck => (others => '0'),
      axilReadSlave   => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave  => AXI_LITE_WRITE_SLAVE_INIT_C,
      axiWriteMaster  => axiWriteMasterInit(AXI_CONFIG_G, '1', "01", "0000"),
      buffBaseAddr    => (others => '0'),
      wrBaseAddr      => (others => '0'),
      rdBaseAddr      => (others => '0'),
      maxSize         => (others => '0'),
      contEn          => '0',
      dropEn          => '0',
      enable          => '0',
      intEnable       => '0',
      online          => (others => '0'),
      acknowledge     => (others => '0'),
      fifoReset       => '1',
      intAckEn        => '0',
      intAckCount     => (others => '0'),
      descCache       => (others => '0'),
      buffCache       => (others => '0'),
      fifoDin         => (others => '0'),
      wrFifoWr        => '0',
      rdFifoWr        => (others => '0'),
      addrFifoSel     => '0',
      wrFifoRd        => '0',
      wrFifoValidDly  => (others => '0'),
      wrAddr          => (others => '0'),
      wrAddrValid     => '0',
      rdFifoRd        => '0',
      rdFifoValidDly  => (others => '0'),
      rdAddr          => (others => '0'),
      rdAddrValid     => '0',
      wrReqValid      => '0',
      wrReqCnt        => 0,
      wrReqNum        => (others => '0'),
      wrReqAcks       => (others => '0'),
      wrReqMissed     => (others => '0'),
      descRetList     => (others => '0'),
      descState       => IDLE_S,
      descRetCnt      => 0,
      descRetNum      => (others => '0'),
      descRetAcks     => (others => '0'),
      wrIndex         => (others => '0'),
      wrMemAddr       => (others => '0'),
      rdIndex         => (others => '0'),
      rdMemAddr       => (others => '0'),
      intReqEn        => '0',
      intReqCount     => (others => '0'),
      interrupt       => '0'
      );

   signal r            : RegType := REG_INIT_C;
   signal rin          : RegType;
   signal pause        : sl;
   signal rdFifoValid  : slv(1 downto 0);
   signal rdFifoDout   : slv(63 downto 0);
   signal wrFifoValid  : sl;
   signal wrFifoDout   : slv(15 downto 0);
   signal addrRamDout  : slv(31 downto 0);
   signal addrRamAddr  : slv(DESC_AWIDTH_G-1 downto 0);
   signal intAckEn     : sl;
   signal invalidCount : sl;
   signal diffCnt      : slv(31 downto 0);

   -- attribute dont_touch                 : string;
   -- attribute dont_touch of r            : signal is "true";
   -- attribute dont_touch of intAckEn     : signal is "true";
   -- attribute dont_touch of invalidCount : signal is "true";
   -- attribute dont_touch of diffCnt      : signal is "true";

begin

   -----------------------------------------
   -- Crossbar
   -----------------------------------------
   U_AxiCrossbar : entity work.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => CB_COUNT_C,
         DEC_ERROR_RESP_G   => AXI_ERROR_RESP_G,
         MASTERS_CONFIG_G   => AXI_CROSSBAR_MASTERS_CONFIG_C)
      port map (
         axiClk              => axiClk,
         axiClkRst           => axiRst,
         sAxiWriteMasters(0) => axilWriteMaster,
         sAxiWriteSlaves(0)  => axilWriteSlave,
         sAxiReadMasters(0)  => axilReadMaster,
         sAxiReadSlaves(0)   => axilReadSlave,
         mAxiWriteMasters    => intWriteMasters,
         mAxiWriteSlaves     => intWriteSlaves,
         mAxiReadMasters     => intReadMasters,
         mAxiReadSlaves      => intReadSlaves);

   -----------------------------------------
   -- Write Free List FIFO
   -----------------------------------------
   U_DescFifo : entity work.Fifo
      generic map (
         TPD_G           => TPD_G,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         DATA_WIDTH_G    => 16,
         ADDR_WIDTH_G    => DESC_AWIDTH_G)
      port map (
         rst    => r.fifoReset,
         wr_clk => axiClk,
         wr_en  => r.wrFifoWr,
         din    => r.fifoDin(15 downto 0),
         rd_clk => axiClk,
         rd_en  => r.wrFifoRd,
         dout   => wrFifoDout,
         valid  => wrFifoValid);

   -----------------------------------------
   -- Read Transaction FIFOs
   -----------------------------------------
   U_RdLowFifo : entity work.Fifo
      generic map (
         TPD_G           => TPD_G,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         DATA_WIDTH_G    => 32,
         ADDR_WIDTH_G    => DESC_AWIDTH_G)
      port map (
         rst    => r.fifoReset,
         wr_clk => axiClk,
         wr_en  => r.rdFifoWr(0),
         din    => r.fifoDin,
         rd_clk => axiClk,
         rd_en  => r.rdFifoRd,
         dout   => rdFifoDout(31 downto 0),
         valid  => rdFifoValid(0));

   U_RdHighFifo : entity work.Fifo
      generic map (
         TPD_G           => TPD_G,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         DATA_WIDTH_G    => 32,
         ADDR_WIDTH_G    => DESC_AWIDTH_G)
      port map (
         rst    => r.fifoReset,
         wr_clk => axiClk,
         wr_en  => r.rdFifoWr(1),
         din    => r.fifoDin,
         rd_clk => axiClk,
         rd_en  => r.rdFifoRd,
         dout   => rdFifoDout(63 downto 32),
         valid  => rdFifoValid(1));

   -----------------------------------------
   -- Address RAM
   -----------------------------------------
   U_AddrRam : entity work.AxiDualPortRam
      generic map (
         TPD_G        => TPD_G,
         REG_EN_G     => true,
         BRAM_EN_G    => true,
         COMMON_CLK_G => true,
         ADDR_WIDTH_G => DESC_AWIDTH_G,
         DATA_WIDTH_G => 32)
      port map (
         axiClk         => axiClk,
         axiRst         => axiRst,
         axiReadMaster  => intReadMasters(ADDR_INDEX_C),
         axiReadSlave   => intReadSlaves(ADDR_INDEX_C),
         axiWriteMaster => intWriteMasters(ADDR_INDEX_C),
         axiWriteSlave  => intWriteSlaves(ADDR_INDEX_C),
         clk            => axiClk,
         rst            => axiRst,
         addr           => addrRamAddr,
         dout           => addrRamDout);

   addrRamAddr <= wrFifoDout(DESC_AWIDTH_G-1 downto 0) when r.addrFifoSel = '0' else
                  rdFifoDout(DESC_AWIDTH_G+3 downto 4);

   -- Check for invalid count
   U_DspComparator : entity work.DspComparator
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 32)
      port map (
         clk     => axiClk,
         ibValid => r.intAckEn,
         ain     => r.intReqCount,
         bin     => r.intAckCount,
         obValid => intAckEn,
         ls      => invalidCount);  --  (a <  b) <--> r.intAckCount > r.intReqCount

   U_DspSub : entity work.DspAddSub
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 32)
      port map (
         clk     => axiClk,
         ibValid => r.intAckEn,
         ain     => r.intReqCount,
         bin     => r.intAckCount,
         add     => '0',                -- '0' = subtract
         obValid => open,               -- sync'd up with U_DspComparator
         pOut    => diffCnt);  -- a - b <--> r.intReqCount - r.intAckCount

   -----------------------------------------
   -- Control Logic
   -----------------------------------------

   -- Choose pause source
   pause <= '0' when (AXI_READY_EN_G) else axiWriteCtrl.pause;

   comb : process (addrRamDout, axiRst, axiWriteSlave, diffCnt, dmaRdDescAck,
                   dmaRdDescRet, dmaWrDescReq, dmaWrDescRet, intAckEn,
                   intReadMasters, intWriteMasters, invalidCount, pause, r,
                   rdFifoDout, rdFifoValid, wrFifoDout, wrFifoValid) is

      variable v            : RegType;
      variable wrReqList    : slv(CHAN_COUNT_G-1 downto 0);
      --variable descRetList  : slv(DESC_COUNT_C-1 downto 0);
      variable descRetValid : sl;
      variable descIndex    : natural;
      variable dmaRdReq     : AxiReadDmaDescReqType;
      variable rdIndex      : natural;
      variable regCon       : AxiLiteEndPointType;
   begin

      -- Latch the current value
      v := r;

      -- Clear one shot signals
      v.rdFifoWr    := "00";
      v.rdFifoRd    := '0';
      v.wrFifoWr    := '0';
      v.wrFifoRd    := '0';
      v.intAckEn    := '0';
      v.acknowledge := (others => '0');

      -----------------------------
      -- Register access
      -----------------------------

      -- Start transaction block
      axiSlaveWaitTxn(regCon, intWriteMasters(LOC_INDEX_C), intReadMasters(LOC_INDEX_C), v.axilWriteSlave, v.axilReadSlave);

      axiSlaveRegister(regCon, x"000", 0, v.enable);
      axiSlaveRegisterR(regCon, x"000", 24, toSlv(2, 8));  -- Version 2 = 2, Version1 = 0

      axiSlaveRegister(regCon, x"004", 0, v.intEnable);
      axiSlaveRegister(regCon, x"008", 0, v.contEn);
      axiSlaveRegister(regCon, x"00C", 0, v.dropEn);
      axiSlaveRegister(regCon, x"010", 0, v.wrBaseAddr(31 downto 0));
      axiSlaveRegister(regCon, x"014", 0, v.wrBaseAddr(63 downto 32));
      axiSlaveRegister(regCon, x"018", 0, v.rdBaseAddr(31 downto 0));
      axiSlaveRegister(regCon, x"01C", 0, v.rdBaseAddr(63 downto 32));
      axiSlaveRegister(regCon, x"020", 0, v.fifoReset);
      axiSlaveRegister(regCon, x"024", 0, v.buffBaseAddr(63 downto 32));
      axiSlaveRegister(regCon, x"028", 0, v.maxSize);
      axiSlaveRegister(regCon, x"02C", 0, v.online);
      axiSlaveRegister(regCon, x"030", 0, v.acknowledge);

      axiSlaveRegisterR(regCon, x"034", 0, toSlv(CHAN_COUNT_G, 8));
      axiSlaveRegisterR(regCon, x"038", 0, toSlv(DESC_AWIDTH_G, 8));
      axiSlaveRegister(regCon, x"03C", 0, v.descCache);
      axiSlaveRegister(regCon, x"03C", 8, v.buffCache);

      axiSlaveRegister(regCon, x"040", 0, v.fifoDin);
      axiWrDetect(regCon, x"040", v.rdFifoWr(0));

      axiSlaveRegister(regCon, x"044", 0, v.fifoDin);
      axiWrDetect(regCon, x"044", v.rdFifoWr(1));

      axiSlaveRegister(regCon, x"048", 0, v.fifoDin);
      axiWrDetect(regCon, x"048", v.wrFifoWr);

      axiSlaveRegister(regCon, x"04C", 0, v.intAckCount(15 downto 0));
      axiSlaveRegister(regCon, x"04C", 17, v.intEnable);
      axiWrDetect(regCon, x"04C", v.intAckEn);

      axiSlaveRegisterR(regCon, x"050", 0, r.intReqCount);
      axiSlaveRegisterR(regCon, x"054", 0, r.wrIndex);
      axiSlaveRegisterR(regCon, x"058", 0, r.rdIndex);

      axiSlaveRegisterR(regCon, x"05C", 0, r.wrReqMissed);

      -- End transaction block
      axiSlaveDefault(regCon, v.axilWriteSlave, v.axilReadSlave, AXI_ERROR_RESP_G);

      --------------------------------------
      -- Address FIFO Control
      --------------------------------------
      -- Alternate between read and write FIFOs to common address pool
      v.addrFifoSel := not(r.addrFifoSel);

      -- Write pipeline
      if r.wrFifoRd = '1' then
         v.wrFifoValidDly := (others => '0');
         v.wrAddr         := (others => '1');
         v.wrAddrValid    := '0';
      else
         v.wrFifoValidDly := (wrFifoValid and (not r.addrFifoSel)) & r.wrFifoValidDly(1);
         if r.wrFifoValidDly(0) = '1' then
            v.wrAddr      := addrRamDout;
            v.wrAddrValid := '1';
         end if;
      end if;

      -- Read pipeline
      if r.rdFifoRd = '1' then
         v.rdFifoValidDly := (others => '0');
         v.rdAddr         := (others => '1');
         v.rdAddrValid    := '0';
      else
         v.rdFifoValidDly := (rdFifoValid(0) and rdFifoValid(1) and r.addrFifoSel) & r.rdFifoValidDly(1);
         if r.rdFifoValidDly(0) = '1' then
            v.rdAddr      := addrRamDout;
            v.rdAddrValid := '1';
         end if;
      end if;

      --------------------------------------
      -- Write Descriptor Requests
      --------------------------------------

      -- Clear acks
      for i in 0 to CHAN_COUNT_G-1 loop
         v.dmaWrDescAck(i).valid := '0';
      end loop;

      -- Arbitrate
      if r.wrReqValid = '0' then

         -- Format requests
         wrReqList := (others => '0');
         for i in 0 to CHAN_COUNT_G-1 loop
            wrReqList(i) := dmaWrDescReq(i).valid;
         end loop;

         -- Arbitrate between requesters
         if r.enable = '1' and r.wrFifoRd = '0' and r.wrAddrValid = '1' then
            if (DESC_ARB_G = true) then
               arbitrate(wrReqList, r.wrReqNum, v.wrReqNum, v.wrReqValid, v.wrReqAcks);
            else
               -- Check the counter
               if (r.wrReqCnt = (CHAN_COUNT_G-1)) then
                  -- Reset the counter
                  v.wrReqCnt := 0;
               else
                  -- Increment the counter
                  v.wrReqCnt := r.wrReqCnt + 1;
               end if;
               -- Check for valid 
               if (wrReqList(r.wrReqCnt) = '1') then
                  v.wrReqValid := '1';
                  v.wrReqNum   := toSlv(r.wrReqCnt, CHAN_SIZE_C);
               else
                  v.wrReqValid := '0';
               end if;
            end if;
         end if;

         if r.enable = '0' then
            v.wrReqMissed := (others => '0');
         elsif wrReqList /= 0 and wrFifoValid = '0' then
            v.wrReqMissed := r.wrReqMissed + 1;
         end if;

      -- Valid arbitration result
      else
         for i in 0 to CHAN_COUNT_G-1 loop
            v.dmaWrDescAck(i).address              := r.buffBaseAddr & r.wrAddr;
            v.dmaWrDescAck(i).dropEn               := r.dropEn;
            v.dmaWrDescAck(i).contEn               := r.contEn;
            v.dmaWrDescAck(i).buffId(11 downto 0)  := wrFifoDout(11 downto 0);
            v.dmaWrDescAck(i).maxSize(23 downto 0) := r.maxSize;
         end loop;

         v.dmaWrDescAck(conv_integer(r.wrReqNum)).valid := '1';
         v.wrFifoRd                                     := '1';
         v.wrReqValid                                   := '0';

      end if;


      --------------------------------------
      -- Read/Write Descriptor Returns
      --------------------------------------

      -- Clear acks
      v.dmaWrDescRetAck := (others => '0');
      v.dmaRdDescRetAck := (others => '0');

      -- Axi Cache
      v.axiWriteMaster.awcache := r.descCache;

      -- Reset strobing Signals
      if (axiWriteSlave.awready = '1') or (AXI_READY_EN_G = false) then
         v.axiWriteMaster.awvalid := '0';
      end if;
      if (axiWriteSlave.wready = '1') or (AXI_READY_EN_G = false) then
         v.axiWriteMaster.wvalid := '0';
         v.axiWriteMaster.wlast  := '0';
      end if;

      -- Generate descriptor ring addresses
      v.wrMemAddr := r.wrBaseAddr + (r.wrIndex & "000");
      v.rdMemAddr := r.rdBaseAddr + (r.rdIndex & "000");

      -- State machine
      case r.descState is
         ----------------------------------------------------------------------
         when IDLE_S =>

            -- Format requests
            v.descRetList := (others => '0');
            for i in 0 to CHAN_COUNT_G-1 loop
               v.descRetList(i*2)   := dmaWrDescRet(i).valid;
               v.descRetList(i*2+1) := dmaRdDescRet(i).valid;
            end loop;

            -- Arbitrate between requesters
            if r.enable = '1' and pause = '0' then
               if (DESC_ARB_G = true) then
                  arbitrate(v.descRetList, r.descRetNum, v.descRetNum, descRetValid, v.descRetAcks);
               else
                  -- Check the counter
                  if (r.descRetCnt = (DESC_COUNT_C-1)) then
                     -- Reset the counter
                     v.descRetCnt := 0;
                  else
                     -- Increment the counter
                     v.descRetCnt := r.descRetCnt + 1;
                  end if;
                  -- Check for valid 
                  if (v.descRetList(r.descRetCnt) = '1') then
                     descRetValid := '1';
                     v.descRetNum := toSlv(r.descRetCnt, DESC_SIZE_C);
                  else
                     descRetValid := '0';
                  end if;
               end if;

               -- Valid request
               if descRetValid = '1' then
                  if v.descRetNum(0) = '1' then
                     v.descState := READ_S;
                  else
                     v.descState := WRITE_S;
                  end if;
               end if;
            end if;

         ----------------------------------------------------------------------
         when WRITE_S =>
            if CHAN_COUNT_G > 1 then
               descIndex := conv_integer(r.descRetNum(DESC_SIZE_C-1 downto 1));
            else
               descIndex := 0;
            end if;

            -- Write address channel
            v.axiWriteMaster.awaddr := r.wrMemAddr;
            v.axiWriteMaster.awlen  := x"00";  -- Single transaction

            -- Write data channel
            v.axiWriteMaster.wlast := '1';
            v.axiWriteMaster.wstrb := resize(x"FF", 128);

            -- Descriptor data
            v.axiWriteMaster.wdata(63 downto 56) := dmaWrDescRet(descIndex).dest;
            v.axiWriteMaster.wdata(55 downto 32) := dmaWrDescRet(descIndex).size(23 downto 0);
            v.axiWriteMaster.wdata(31 downto 24) := dmaWrDescRet(descIndex).firstUser;
            v.axiWriteMaster.wdata(23 downto 16) := dmaWrDescRet(descIndex).lastUser;
            v.axiWriteMaster.wdata(15 downto 4)  := dmaWrDescRet(descIndex).buffId(11 downto 0);
            v.axiWriteMaster.wdata(3)            := dmaWrDescRet(descIndex).continue;
            v.axiWriteMaster.wdata(2 downto 0)   := dmaWrDescRet(descIndex).result;

            -- Encoded channel into upper destination bits
            if CHAN_COUNT_G > 1 then
               v.axiWriteMaster.wdata(63 downto 64-CHAN_SIZE_C) := toSlv(descIndex, CHAN_SIZE_C);
            end if;

            v.axiWriteMaster.awvalid := '1';
            v.axiWriteMaster.wvalid  := '1';
            v.wrIndex                := r.wrIndex + 1;
            v.descState              := WAIT_S;

            v.dmaWrDescRetAck(descIndex) := '1';

         ----------------------------------------------------------------------
         when READ_S =>
            if CHAN_COUNT_G > 1 then
               descIndex := conv_integer(r.descRetNum(DESC_SIZE_C-1 downto 1));
            else
               descIndex := 0;
            end if;

            -- Write address channel
            v.axiWriteMaster.awaddr := r.rdMemAddr;
            v.axiWriteMaster.awlen  := x"00";  -- Single transaction

            -- Write data channel
            v.axiWriteMaster.wlast := '1';
            v.axiWriteMaster.wstrb := resize(x"FF", 128);

            -- Descriptor data
            v.axiWriteMaster.wdata(63 downto 32) := x"00000001";
            v.axiWriteMaster.wdata(31 downto 16) := (others => '0');
            v.axiWriteMaster.wdata(15 downto 4)  := dmaRdDescRet(descIndex).buffId(11 downto 0);
            v.axiWriteMaster.wdata(3)            := '0';
            v.axiWriteMaster.wdata(2 downto 0)   := dmaRdDescRet(descIndex).result;

            v.axiWriteMaster.awvalid := '1';
            v.axiWriteMaster.wvalid  := '1';
            v.rdIndex                := r.rdIndex + 1;
            v.descState              := WAIT_S;

            v.dmaRdDescRetAck(descIndex) := '1';

         ----------------------------------------------------------------------
         when WAIT_S =>
            if v.axiWriteMaster.awvalid = '0' and v.axiWriteMaster.wvalid = '0' and
               (axiWriteSlave.bvalid = '1' or ACK_WAIT_BVALID_G = false) then
               v.intReqEn  := '1';
               v.descState := IDLE_S;
            end if;

         when others =>
            v.descState := IDLE_S;

      end case;
      
      -- Copy the lowest 64-bit word to the entire bus (refer to  "section 9.3 Narrow transfers" of the AMBA spec)
      for i in 15 downto 1 loop
         v.axiWriteMaster.wdata((64*i)+63 downto (64*i)) := v.axiWriteMaster.wdata(63 downto 0);
      end loop;      

      -- Driver interrupt
      if r.intReqCount /= 0 then
         -- Prevent false interrupts during ACK from software
         if (r.intAckEn = '0') and (intAckEn = '0') then
            v.interrupt := r.intEnable;
         end if;
      else
         v.interrupt := '0';
      end if;

      -- Ack from software
      if intAckEn = '1' then
         v.interrupt := '0';

         -- Just in case
         if invalidCount = '1' then     -- r.intAckCount > r.intReqCount
            v.intReqCount := (others => '0');
         else
            v.intReqCount := diffCnt;   -- r.intReqCount - r.intAckCount
         end if;

      -- Firmware posted an entry
      elsif r.intReqEn = '1' then
         v.intReqCount := r.intReqCount + 1;
         v.intReqEn    := '0';
      end if;

      -- Engine disabled
      if r.enable = '0' then
         v.intReqEn    := '0';
         v.intReqCount := (others => '0');
         v.interrupt   := '0';
      end if;

      --------------------------------------
      -- Read Descriptor Requests
      --------------------------------------

      -- Clear requests
      for i in 0 to CHAN_COUNT_G-1 loop
         if dmaRdDescAck(i) = '1' then
            v.dmaRdDescReq(i).valid := '0';
         end if;
      end loop;

      -- Format request
      dmaRdReq                     := AXI_READ_DMA_DESC_REQ_INIT_C;
      dmaRdReq.valid               := r.rdAddrValid;
      dmaRdReq.address             := r.buffBaseAddr & r.rdAddr;
      dmaRdReq.dest                := rdFifoDout(63 downto 56);
      dmaRdReq.size(23 downto 0)   := rdFifoDout(55 downto 32);
      dmaRdReq.firstUser           := rdFifoDout(31 downto 24);
      dmaRdReq.lastUser            := rdFifoDout(23 downto 16);
      dmaRdReq.buffId(11 downto 0) := rdFifoDout(15 downto 4);
      dmaRdReq.continue            := rdFifoDout(3);

      -- Upper dest bits select channel
      if CHAN_COUNT_G > 1 then
         rdIndex                               := conv_integer(dmaRdReq.dest(7 downto 8-CHAN_SIZE_C));
         dmaRdReq.dest(7 downto 8-CHAN_SIZE_C) := (others => '0');
      else
         rdIndex := 0;
      end if;

      -- Pull next entry if we are not waiting for ack on given channel
      if r.rdFifoRd = '0' and dmaRdReq.valid = '1' and v.dmaRdDescReq(rdIndex).valid = '0' then
         v.dmaRdDescReq(rdIndex) := dmaRdReq;
         v.rdFifoRd              := '1';
      end if;

      --------------------------------------
      if r.enable = '0' then
         v.wrIndex := (others => '0');
         v.rdIndex := (others => '0');
      end if;

      -- Reset      
      if (axiRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle      
      rin <= v;

      -- Outputs   
      intReadSlaves(LOC_INDEX_C)  <= r.axilReadSlave;
      intWriteSlaves(LOC_INDEX_C) <= r.axilWriteSlave;

      online          <= r.online;
      interrupt       <= r.interrupt;
      acknowledge     <= r.acknowledge;
      dmaWrDescAck    <= r.dmaWrDescAck;
      dmaWrDescRetAck <= r.dmaWrDescRetAck;
      dmaRdDescReq    <= r.dmaRdDescReq;
      dmaRdDescRetAck <= r.dmaRdDescRetAck;
      axiWriteMaster  <= r.axiWriteMaster;
      axiCache        <= r.buffCache;

   end process comb;

   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;

