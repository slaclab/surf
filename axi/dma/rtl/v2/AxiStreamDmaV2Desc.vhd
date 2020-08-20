-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
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


library surf;
use surf.StdRtlPkg.all;
use surf.AxiPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiDmaPkg.all;
use surf.ArbiterPkg.all;

entity AxiStreamDmaV2Desc is
   generic (
      TPD_G : time := 1 ns;

      -- Number of read & write DMA engines to support for each descriptor engine
      CHAN_COUNT_G : integer range 1 to 16 := 1;

      -- Base address of descriptor registers & FIFOs
      AXIL_BASE_ADDR_G : slv(31 downto 0) := x"00000000";

      -- Configuration of AXI bus, must be 64 bits (or wider)
      AXI_CONFIG_G : AxiConfigType;

      -- Number of descriptor entries in write FIFO and return ring buffers
      DESC_AWIDTH_G : integer range 4 to 32 := 12;

      -- Choose between one-clock arbitration for return descriptors or count and check selection
      DESC_ARB_G : boolean := true;

      -- Choose between infeered or xpm generated descriptor FIFOs
      DESC_SYNTH_MODE_G : string := "inferred";

      -- Choose the type of resources for the descriptor FIFOs when DESC_SYNTH_MODE_G="xpm"
      DESC_MEMORY_TYPE_G : string := "block");
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
      axiRdCache      : out slv(3 downto 0);
      axiWrCache      : out slv(3 downto 0);
      -- AXI Interface
      axiWriteMasters : out AxiWriteMasterArray(CHAN_COUNT_G-1 downto 0);
      axiWriteSlaves  : in  AxiWriteSlaveArray(CHAN_COUNT_G-1 downto 0);

      -- Buffer Group Pause
      buffGrpPause : out slv(7 downto 0));

end AxiStreamDmaV2Desc;

architecture rtl of AxiStreamDmaV2Desc is

   constant AXI_DESC_CONFIG_C : AxiConfigType := (
      ADDR_WIDTH_C => AXI_CONFIG_G.ADDR_WIDTH_C,
      DATA_BYTES_C => 16,               -- Force 128b descriptor
      ID_BITS_C    => AXI_CONFIG_G.ID_BITS_C,
      LEN_BITS_C   => AXI_CONFIG_G.LEN_BITS_C);

   constant CHAN_SIZE_C : integer := bitSize(CHAN_COUNT_G-1);
   constant RET_COUNT_C : integer := CHAN_COUNT_G*2;
   constant RET_SIZE_C  : integer := bitSize(RET_COUNT_C-1);

   constant RD_FIFO_CNT_C  : integer := 4;
   constant RD_FIFO_BITS_C : integer := RD_FIFO_CNT_C * 32;

   constant WR_FIFO_CNT_C  : integer := 2;
   constant WR_FIFO_BITS_C : integer := WR_FIFO_CNT_C * 32;

   type DescStateType is (
      IDLE_S,
      WRITE_S,
      READ_S,
      WAIT_S);

   type RegType is record

      -- Write descriptor interface
      dmaWrDescAck    : AxiWriteDmaDescAckArray(CHAN_COUNT_G-1 downto 0);
      dmaWrDescRetAck : slv(CHAN_COUNT_G-1 downto 0);

      -- Read descriptor interface
      dmaRdDescReq    : AxiReadDmaDescReqArray(CHAN_COUNT_G-1 downto 0);
      dmaRdDescRetAck : slv(CHAN_COUNT_G-1 downto 0);

      -- AXI-Lite Register Access
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;

      -- AXI4 Descriptor
      axiWriteMaster : AxiWriteMasterType;

      -- Configuration
      wrBaseAddr  : slv(63 downto 0);   -- For wr ring buffer
      rdBaseAddr  : slv(63 downto 0);   -- For rd ring buffer
      maxSize     : slv(31 downto 0);
      contEn      : sl;
      dropEn      : sl;
      enable      : sl;
      forceInt    : sl;
      intEnable   : sl;
      online      : slv(CHAN_COUNT_G-1 downto 0);
      acknowledge : slv(CHAN_COUNT_G-1 downto 0);
      fifoReset   : sl;
      intSwAckReq : sl;
      intAckCount : slv(31 downto 0);
      descWrCache : slv(3 downto 0);
      buffRdCache : slv(3 downto 0);
      buffWrCache : slv(3 downto 0);
      enableCnt   : slv(7 downto 0);
      idBuffThold : Slv32Array(7 downto 0);

      -- FIFOs
      fifoDin        : slv(31 downto 0);
      wrFifoWr       : slv(WR_FIFO_CNT_C-1 downto 0);
      rdFifoWr       : slv(RD_FIFO_CNT_C-1 downto 0);
      addrFifoSel    : sl;
      wrFifoRd       : sl;
      wrFifoValidDly : slv(1 downto 0);
      wrAddrValid    : sl;
      rdFifoRd       : sl;
      rdFifoValidDly : slv(1 downto 0);
      rdAddrValid    : sl;

      -- Write Desc Request
      wrReqValid  : sl;
      wrReqCnt    : natural range 0 to CHAN_COUNT_G-1;
      wrReqNum    : slv(CHAN_SIZE_C-1 downto 0);
      wrReqAcks   : slv(CHAN_COUNT_G-1 downto 0);
      wrReqMissed : slv(31 downto 0);

      -- Desc Return
      descRetList : slv(RET_COUNT_C-1 downto 0);
      descState   : DescStateType;
      descRetCnt  : natural range 0 to RET_COUNT_C-1;
      descRetNum  : slv(RET_SIZE_C-1 downto 0);
      descRetAcks : slv(RET_COUNT_C-1 downto 0);
      wrIndex     : slv(DESC_AWIDTH_G-1 downto 0);
      wrMemAddr   : slv(63 downto 0);
      rdIndex     : slv(DESC_AWIDTH_G-1 downto 0);
      rdMemAddr   : slv(63 downto 0);
      intReqEn    : sl;
      intReqCount : slv(31 downto 0);
      interrupt   : sl;

      intHoldoff      : slv(15 downto 0);
      intHoldoffCount : slv(15 downto 0);

      idBuffCount : Slv32Array(7 downto 0);

      idBuffInc : slv(7 downto 0);
      idBuffDec : slv(7 downto 0);

      buffGrpPause : slv(7 downto 0);

   end record RegType;

   constant REG_INIT_C : RegType := (
      -- Write descriptor interface
      dmaWrDescAck    => (others => AXI_WRITE_DMA_DESC_ACK_INIT_C),
      dmaWrDescRetAck => (others => '0'),
      -- Read descriptor interface
      dmaRdDescReq    => (others => AXI_READ_DMA_DESC_REQ_INIT_C),
      dmaRdDescRetAck => (others => '0'),
      -- AXI-Lite Register Access
      axilReadSlave   => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave  => AXI_LITE_WRITE_SLAVE_INIT_C,
      -- AXI4 Descriptor
      axiWriteMaster  => axiWriteMasterInit(AXI_DESC_CONFIG_C, '1', "01", "0000"),
      -- Configuration
      wrBaseAddr      => (others => '0'),
      rdBaseAddr      => (others => '0'),
      maxSize         => (others => '0'),
      contEn          => '0',
      dropEn          => '0',
      enable          => '0',
      forceInt        => '0',
      intEnable       => '0',
      online          => (others => '0'),
      acknowledge     => (others => '0'),
      fifoReset       => '1',
      intSwAckReq     => '0',
      intAckCount     => (others => '0'),
      descWrCache     => (others => '0'),
      buffRdCache     => (others => '0'),
      buffWrCache     => (others => '0'),
      enableCnt       => (others => '0'),
      idBuffThold     => (others => (others => '0')),
      -- FIFOs
      fifoDin         => (others => '0'),
      wrFifoWr        => (others => '0'),
      rdFifoWr        => (others => '0'),
      addrFifoSel     => '0',
      wrFifoRd        => '0',
      wrFifoValidDly  => (others => '0'),
      wrAddrValid     => '0',
      rdFifoRd        => '0',
      rdFifoValidDly  => (others => '0'),
      rdAddrValid     => '0',
      -- Write Desc Request
      wrReqValid      => '0',
      wrReqCnt        => 0,
      wrReqNum        => (others => '0'),
      wrReqAcks       => (others => '0'),
      wrReqMissed     => (others => '0'),
      -- Desc Return
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
      interrupt       => '0',
      intHoldoff      => toSlv(10000, 16),  -- ~20 kHz
      intHoldoffCount => (others => '0'),
      idBuffCount     => (others => (others => '0')),
      idBuffInc       => (others => '0'),
      idBuffDec       => (others => '0'),
      buffGrpPause    => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal rdFifoValid : slv(RD_FIFO_CNT_C-1 downto 0);
   signal rdFifoDout  : slv(RD_FIFO_BITS_C-1 downto 0);

   signal wrFifoValid : slv(WR_FIFO_CNT_C-1 downto 0);
   signal wrFifoDout  : slv(WR_FIFO_BITS_C-1 downto 0);

   signal intSwAckEn   : sl;
   signal intCompValid : sl;
   signal intDiffValid : sl;
   signal invalidCount : sl;
   signal diffCnt      : slv(31 downto 0);

   signal holdoffCompare : sl;
   signal idBuffCompare  : slv(7 downto 0);

   -- attribute dont_touch                 : string;
   -- attribute dont_touch of r            : signal is "true";
   -- attribute dont_touch of intSwAckEn   : signal is "true";
   -- attribute dont_touch of invalidCount : signal is "true";
   -- attribute dont_touch of diffCnt      : signal is "true";

begin

   -----------------------------------------
   -- Write Free List FIFOs
   -----------------------------------------
   U_DescGen : for i in 0 to WR_FIFO_CNT_C-1 generate
      U_DescFifo : entity surf.Fifo
         generic map (
            TPD_G           => TPD_G,
            GEN_SYNC_FIFO_G => true,
            FWFT_EN_G       => true,
            DATA_WIDTH_G    => 32,
            ADDR_WIDTH_G    => DESC_AWIDTH_G,
            SYNTH_MODE_G    => DESC_SYNTH_MODE_G,
            MEMORY_TYPE_G   => DESC_MEMORY_TYPE_G)
         port map (
            rst    => r.fifoReset,
            wr_clk => axiClk,
            wr_en  => r.wrFifoWr(i),
            din    => r.fifoDin,
            rd_clk => axiClk,
            rd_en  => r.wrFifoRd,
            dout   => wrFifoDout((i*32)+31 downto i*32),
            valid  => wrFifoValid(i));
   end generate;

   -----------------------------------------
   -- Read Transaction FIFOs
   -----------------------------------------
   U_RdFifoGen : for i in 0 to RD_FIFO_CNT_C-1 generate
      U_RdFifo : entity surf.Fifo
         generic map (
            TPD_G           => TPD_G,
            GEN_SYNC_FIFO_G => true,
            FWFT_EN_G       => true,
            DATA_WIDTH_G    => 32,
            ADDR_WIDTH_G    => DESC_AWIDTH_G,
            SYNTH_MODE_G    => DESC_SYNTH_MODE_G,
            MEMORY_TYPE_G   => DESC_MEMORY_TYPE_G)
         port map (
            rst    => r.fifoReset,
            wr_clk => axiClk,
            wr_en  => r.rdFifoWr(i),
            din    => r.fifoDin,
            rd_clk => axiClk,
            rd_en  => r.rdFifoRd,
            dout   => rdFifoDout((i*32)+31 downto i*32),
            valid  => rdFifoValid(i));
   end generate;

   -----------------------------------------
   -- Interrupt ACK Counter
   -----------------------------------------

   -- Check for invalid count
   U_invalidCount : entity surf.DspComparator
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 32)
      port map (
         clk     => axiClk,
         ibValid => r.intSwAckReq,
         ain     => r.intReqCount,
         bin     => r.intAckCount,
         obValid => intCompValid,
         ls      => invalidCount);  --  (a <  b) <--> r.intAckCount > r.intReqCount

   U_diffCnt : entity surf.DspAddSub
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 32)
      port map (
         clk     => axiClk,
         ibValid => r.intSwAckReq,
         ain     => r.intReqCount,
         bin     => r.intAckCount,
         add     => '0',                -- '0' = subtract
         obValid => intDiffValid,       -- sync'd up with U_DspComparator
         pOut    => diffCnt);      -- a - b <--> r.intReqCount - r.intAckCount

   -- Both DSPs are done
   intSwAckEn <= intDiffValid and intCompValid;

   U_holdoffCompare : entity surf.DspComparator
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 16)
      port map (
         clk  => axiClk,
         ain  => r.intHoldoffCount,
         bin  => r.intHoldoff,
         gtEq => holdoffCompare);  --  (a >= b) <--> r.intHoldoffCount >= r.intHoldoff

   U_Pause : for i in 0 to 7 generate
      U_DspComparator : entity surf.DspComparator
         generic map (
            TPD_G   => TPD_G,
            WIDTH_G => 32)
         port map (
            clk  => axiClk,
            ain  => r.idBuffCount(i),
            bin  => r.idBuffThold(i),
            gtEq => idBuffCompare(i));  --  (a >= b) <--> r.idBuffCount(i) >= r.idBuffThold(i)
   end generate;

   -----------------------------------------
   -- Control Logic
   -----------------------------------------

   comb : process (axiRst, axiWriteSlaves, axilReadMaster, axilWriteMaster,
                   diffCnt, dmaRdDescAck, dmaRdDescRet, dmaWrDescReq,
                   dmaWrDescRet, holdoffCompare, idBuffCompare, intSwAckEn,
                   invalidCount, r, rdFifoDout, rdFifoValid, wrFifoDout,
                   wrFifoValid) is
      variable v            : RegType;
      variable wrReqList    : slv(CHAN_COUNT_G-1 downto 0);
      variable descRetValid : sl;
      variable descIndex    : natural;
      variable dmaRdReq     : AxiReadDmaDescReqType;
      variable rdIndex      : natural;
      variable regCon       : AxiLiteEndPointType;
      variable idIncrement  : slv(7 downto 0);
      variable idDecrement  : slv(7 downto 0);
   begin

      -- Latch the current value
      v := r;

      -- Clear one shot signals
      v.rdFifoWr    := (others => '0');
      v.rdFifoRd    := '0';
      v.wrFifoWr    := (others => '0');
      v.wrFifoRd    := '0';
      v.acknowledge := (others => '0');
      v.idBuffInc   := (others => '0');
      v.idBuffDec   := (others => '0');

      ----------------------------------------------------------
      -- Register access
      ----------------------------------------------------------

      -- Start transaction block
      axiSlaveWaitTxn(regCon, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      axiSlaveRegister(regCon, x"000", 0, v.enable);
      axiSlaveRegisterR(regCon, x"000", 8, r.enableCnt);  -- Count the number of times enable transitions from 0->1
      axiSlaveRegisterR(regCon, x"000", 16, '1');  -- Legacy DESC_128_EN_C constant (always 0x1 now)
      axiSlaveRegisterR(regCon, x"000", 24, toSlv(4, 8));  -- Version Number for aes-stream-driver to case on
      axiSlaveRegister(regCon, x"004", 0, v.intEnable);
      axiSlaveRegister(regCon, x"008", 0, v.contEn);
      axiSlaveRegister(regCon, x"00C", 0, v.dropEn);
      axiSlaveRegister(regCon, x"010", 0, v.wrBaseAddr(31 downto 0));
      axiSlaveRegister(regCon, x"014", 0, v.wrBaseAddr(63 downto 32));
      axiSlaveRegister(regCon, x"018", 0, v.rdBaseAddr(31 downto 0));
      axiSlaveRegister(regCon, x"01C", 0, v.rdBaseAddr(63 downto 32));
      axiSlaveRegister(regCon, x"020", 0, v.fifoReset);
      axiSlaveRegister(regCon, x"028", 0, v.maxSize);
      axiSlaveRegister(regCon, x"02C", 0, v.online);
      axiSlaveRegister(regCon, x"030", 0, v.acknowledge);

      axiSlaveRegisterR(regCon, x"034", 0, toSlv(CHAN_COUNT_G, 8));
      axiSlaveRegisterR(regCon, x"034", 8, toSlv(AXI_CONFIG_G.ADDR_WIDTH_C, 8));
      axiSlaveRegisterR(regCon, x"034", 16, toSlv(AXI_CONFIG_G.DATA_BYTES_C, 8));
      axiSlaveRegisterR(regCon, x"038", 0, toSlv(DESC_AWIDTH_G, 8));
      axiSlaveRegister(regCon, x"03C", 0, v.descWrCache);
      axiSlaveRegister(regCon, x"03C", 8, v.buffWrCache);
      axiSlaveRegister(regCon, x"03C", 12, v.buffRdCache);

      axiSlaveRegister(regCon, x"040", 0, v.fifoDin);
      axiWrDetect(regCon, x"040", v.rdFifoWr(0));

      axiSlaveRegister(regCon, x"044", 0, v.fifoDin);
      axiWrDetect(regCon, x"044", v.rdFifoWr(1));

      axiSlaveRegister(regCon, x"048", 0, v.fifoDin);
      axiWrDetect(regCon, x"048", v.wrFifoWr(0));

      axiSlaveRegister(regCon, x"04C", 0, v.intAckCount(15 downto 0));
      axiSlaveRegister(regCon, x"04C", 17, v.intEnable);
      axiWrDetect(regCon, x"04C", v.intSwAckReq);

      axiSlaveRegisterR(regCon, x"050", 0, r.intReqCount);
      axiSlaveRegisterR(regCon, x"054", 0, r.wrIndex);
      axiSlaveRegisterR(regCon, x"058", 0, r.rdIndex);

      axiSlaveRegisterR(regCon, x"05C", 0, r.wrReqMissed);

      axiSlaveRegister(regCon, x"060", 0, v.fifoDin);
      axiWrDetect(regCon, x"060", v.rdFifoWr(2));

      axiSlaveRegister(regCon, x"064", 0, v.fifoDin);
      axiWrDetect(regCon, x"064", v.rdFifoWr(3));

      axiSlaveRegister(regCon, x"070", 0, v.fifoDin);
      axiWrDetect(regCon, x"070", v.wrFifoWr(1));

      axiSlaveRegister(regCon, x"080", 0, v.forceInt);

      axiSlaveRegister(regCon, x"084", 0, v.intHoldoff);

      for i in 0 to 7 loop
         axiSlaveRegister(regCon, toSlv(144 + i*4, 12), 0, v.idBuffThold(i));  -- 0x090 - 0xAC
         axiSlaveRegisterR(regCon, toSlv(176 + i*4, 12), 0, r.idBuffCount(i));  -- 0x0B0 - 0xCC
         axiWrDetect(regCon, toSlv(176 + i*4, 12), v.idBuffDec(i));  -- 0x0B0 - 0xCC
      end loop;

      -- End transaction block
      axiSlaveDefault(regCon, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);

      ----------------------------------------------------------
      -- Address FIFO Control
      ----------------------------------------------------------

      -- Alternate between read and write FIFOs to common address pool
      v.addrFifoSel := not(r.addrFifoSel);

      -- Write pipeline
      if r.wrFifoRd = '1' then
         v.wrFifoValidDly := (others => '0');
         v.wrAddrValid    := '0';
      else
         v.wrFifoValidDly := (uAnd(wrFifoValid) and (not r.addrFifoSel)) & r.wrFifoValidDly(1);
         if r.wrFifoValidDly(0) = '1' then
            v.wrAddrValid := '1';
         end if;
      end if;

      -- Read pipeline
      if r.rdFifoRd = '1' then
         v.rdFifoValidDly := (others => '0');
         v.rdAddrValid    := '0';
      else
         v.rdFifoValidDly := (uAnd(rdFifoValid) and r.addrFifoSel) & r.rdFifoValidDly(1);
         if r.rdFifoValidDly(0) = '1' then
            v.rdAddrValid := '1';
         end if;
      end if;

      ----------------------------------------------------------
      -- Write Descriptor Requests (A.K.A "Arbitration" logic)
      ----------------------------------------------------------

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

         if wrReqList /= 0 and uAnd(wrFifoValid) = '0' then
            v.wrReqMissed := r.wrReqMissed + 1;
         end if;

      -- Valid arbitration result
      else
         for i in 0 to CHAN_COUNT_G-1 loop

            v.dmaWrDescAck(i).address(63 downto 40) := (others => '0');
            v.dmaWrDescAck(i).address(39 downto 4)  := wrFifoDout(63 downto 28);
            v.dmaWrDescAck(i).address(3 downto 0)   := (others => '0');

            v.dmaWrDescAck(i).dropEn  := r.dropEn;
            v.dmaWrDescAck(i).contEn  := r.contEn;
            v.dmaWrDescAck(i).maxSize := r.maxSize;

            v.dmaWrDescAck(i).buffId(27 downto 0) := wrFifoDout(27 downto 0);

         end loop;

         v.dmaWrDescAck(conv_integer(r.wrReqNum)).valid := '1';
         v.wrFifoRd                                     := '1';
         v.wrReqValid                                   := '0';

         v.idBuffInc(conv_integer(dmaWrDescReq(conv_integer(r.wrReqNum)).id(2 downto 0))) := '1';

      end if;

      ----------------------------------------------------------
      -- Read/Write Descriptor Returns
      ----------------------------------------------------------

      if CHAN_COUNT_G > 1 then
         descIndex := conv_integer(r.descRetNum(RET_SIZE_C-1 downto 1));
      else
         descIndex := 0;
      end if;

      -- Clear acks
      v.dmaWrDescRetAck := (others => '0');
      v.dmaRdDescRetAck := (others => '0');

      -- Axi Cache
      v.axiWriteMaster.awcache := r.descWrCache;

      -- Reset strobing Signals
      if (axiWriteSlaves(descIndex).awready = '1') then
         v.axiWriteMaster.awvalid := '0';
      end if;
      if (axiWriteSlaves(descIndex).wready = '1') then
         v.axiWriteMaster.wvalid := '0';
         v.axiWriteMaster.wlast  := '0';
      end if;

      -- Generate descriptor ring addresses
      v.wrMemAddr := r.wrBaseAddr + (r.wrIndex & "0000");
      v.rdMemAddr := r.rdBaseAddr + (r.rdIndex & "0000");

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
            if r.enable = '1' then
               if (DESC_ARB_G = true) then
                  arbitrate(v.descRetList, r.descRetNum, v.descRetNum, descRetValid, v.descRetAcks);
               else

                  -- Check the counter
                  if (r.descRetCnt = (RET_COUNT_C-1)) then
                     -- Reset the counter
                     v.descRetCnt := 0;
                  else
                     -- Increment the counter
                     v.descRetCnt := r.descRetCnt + 1;
                  end if;

                  -- Check for valid
                  if (v.descRetList(r.descRetCnt) = '1') then
                     descRetValid := '1';
                     v.descRetNum := toSlv(r.descRetCnt, RET_SIZE_C);
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

            -- Write address channel
            v.axiWriteMaster.awaddr := r.wrMemAddr;
            v.axiWriteMaster.awlen  := x"00";  -- Single transaction

            -- Write data channel
            v.axiWriteMaster.wlast := '1';

            -- Descriptor data, 128-bits
            v.axiWriteMaster.wdata(127)            := '1';
            v.axiWriteMaster.wdata(126 downto 108) := (others => '0');
            v.axiWriteMaster.wdata(107 downto 104) := toSlv(descIndex, 4);  -- Channel
            v.axiWriteMaster.wdata(103 downto 96)  := dmaWrDescRet(descIndex).dest;
            v.axiWriteMaster.wdata(95 downto 64)   := dmaWrDescRet(descIndex).size;
            v.axiWriteMaster.wdata(63 downto 32)   := dmaWrDescRet(descIndex).buffId;
            v.axiWriteMaster.wdata(31 downto 24)   := dmaWrDescRet(descIndex).firstUser;
            v.axiWriteMaster.wdata(23 downto 16)   := dmaWrDescRet(descIndex).lastUser;
            v.axiWriteMaster.wdata(15 downto 8)    := dmaWrDescRet(descIndex).id;
            v.axiWriteMaster.wdata(7 downto 4)     := (others => '0');
            v.axiWriteMaster.wdata(3)              := dmaWrDescRet(descIndex).continue;
            v.axiWriteMaster.wdata(2 downto 0)     := dmaWrDescRet(descIndex).result;

            v.axiWriteMaster.wstrb := resize(x"FFFF", 128);

            v.axiWriteMaster.awvalid := '1';
            v.axiWriteMaster.wvalid  := '1';
            v.wrIndex                := r.wrIndex + 1;
            v.descState              := WAIT_S;

            v.dmaWrDescRetAck(descIndex) := '1';

         ----------------------------------------------------------------------
         when READ_S =>
            if CHAN_COUNT_G > 1 then
               descIndex := conv_integer(r.descRetNum(RET_SIZE_C-1 downto 1));
            else
               descIndex := 0;
            end if;

            -- Write address channel
            v.axiWriteMaster.awaddr := r.rdMemAddr;
            v.axiWriteMaster.awlen  := x"00";  -- Single transaction

            -- Write data channel
            v.axiWriteMaster.wlast := '1';

            -- Descriptor data, 128-bits
            v.axiWriteMaster.wdata(127)           := '1';
            v.axiWriteMaster.wdata(126 downto 64) := (others => '0');
            v.axiWriteMaster.wdata(63 downto 32)  := dmaRdDescRet(descIndex).buffId;
            v.axiWriteMaster.wdata(31 downto 3)   := (others => '0');
            v.axiWriteMaster.wdata(2 downto 0)    := dmaRdDescRet(descIndex).result;

            v.axiWriteMaster.wstrb := resize(x"FFFF", 128);

            v.axiWriteMaster.awvalid := '1';
            v.axiWriteMaster.wvalid  := '1';
            v.rdIndex                := r.rdIndex + 1;
            v.descState              := WAIT_S;

            v.dmaRdDescRetAck(descIndex) := '1';

         ----------------------------------------------------------------------
         when WAIT_S =>
            if v.axiWriteMaster.awvalid = '0' and v.axiWriteMaster.wvalid = '0' then
               v.intReqEn  := '1';
               v.descState := IDLE_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Copy the lowest words to the entire bus (refer to  "section 9.3 Narrow transfers" of the AMBA spec)
      for i in 7 downto 1 loop
         v.axiWriteMaster.wdata((128*i)+127 downto (128*i)) := v.axiWriteMaster.wdata(127 downto 0);
      end loop;

      -- Drive interrupt, avoid false firings during ack
      if ((r.intReqCount /= 0 and holdoffCompare = '1') or r.forceInt = '1') and r.intSwAckReq = '0' then
         v.interrupt := r.intEnable;
      else
         v.interrupt := '0';
      end if;

      -- Ack request from software
      if r.intSwAckReq = '1' then
         v.forceInt := '0';

         -- DSPs are done
         if intSwAckEn = '1' then
            v.intSwAckReq := '0';

            -- Just in case
            if invalidCount = '1' then    -- r.intAckCount > r.intReqCount
               v.intReqCount := (others => '0');
            else
               v.intReqCount := diffCnt;  -- r.intReqCount - r.intAckCount
            end if;
         end if;

      -- Firmware posted an entry
      elsif r.intReqEn = '1' then
         v.intReqCount := r.intReqCount + 1;
         v.intReqEn    := '0';
      end if;

      -- Check if we need to reset IRQ holdoff counter
      if r.intSwAckReq = '1' then
         v.intHoldoffCount := (others => '0');

      -- Check if not max value
      elsif r.intHoldoffCount /= x"FFFF" then
         v.intHoldoffCount := r.intHoldoffCount + 1;
      end if;

      ----------------------------------------------------------
      -- Read Descriptor Requests
      ----------------------------------------------------------

      -- Clear requests
      for i in 0 to CHAN_COUNT_G-1 loop
         if dmaRdDescAck(i) = '1' then
            v.dmaRdDescReq(i).valid := '0';
         end if;
      end loop;

      dmaRdReq       := AXI_READ_DMA_DESC_REQ_INIT_C;
      dmaRdReq.valid := r.rdAddrValid;

      -- Format request, 128-bits
      dmaRdReq.address(63 downto 40) := (others => '0');
      dmaRdReq.address(39 downto 4)  := rdFifoDout(127 downto 92);
      dmaRdReq.address(3 downto 0)   := (others => '0');
      dmaRdReq.buffId(27 downto 0)   := rdFifoDout(91 downto 64);
      dmaRdReq.size                  := rdFifoDout(63 downto 32);
      dmaRdReq.firstUser             := rdFifoDout(31 downto 24);
      dmaRdReq.lastUser              := rdFifoDout(23 downto 16);
      dmaRdReq.dest                  := rdFifoDout(15 downto 8);
      dmaRdReq.continue              := rdFifoDout(3);

      rdIndex := conv_integer(rdFifoDout(7 downto 4));

      -- Pull next entry if we are not waiting for ack on given channel
      if r.rdFifoRd = '0' and dmaRdReq.valid = '1' and v.dmaRdDescReq(rdIndex).valid = '0' then
         v.dmaRdDescReq(rdIndex) := dmaRdReq;
         v.rdFifoRd              := '1';
      end if;

      ----------------------------------------------------------
      -- Buffer Group Tracking
      ----------------------------------------------------------
      for i in 0 to 7 loop

         if r.idBuffInc(i) = '1' and r.idBuffDec(i) = '0' then
            v.idBuffCount(i) := r.idBuffCount(i) + 1;

         elsif r.idBuffInc(i) = '0' and r.idBuffDec(i) = '1' then
            v.idBuffCount(i) := r.idBuffCount(i) - 1;

         end if;

         if r.idBuffThold(i) /= 0 then
            v.buffGrpPause(i) := idBuffCompare(i);  -- r.idBuffCount(i) > r.idBuffThold(i)
         else
            v.buffGrpPause(i) := '0';
         end if;

      end loop;

      ----------------------------------------------------------
      -- Check if disabled
      ----------------------------------------------------------
      if r.enable = '0' then
         v.wrIndex         := (others => '0');
         v.rdIndex         := (others => '0');
         v.wrReqMissed     := (others => '0');
         v.idBuffCount     := (others => (others => '0'));
         v.intHoldoffCount := (others => '0');
         v.intReqEn        := '0';
         v.intReqCount     := (others => '0');
         v.interrupt       := '0';
         v.forceInt        := '0';
      end if;

      if (r.enable = '0') and (v.enable = '1') and (r.enableCnt /= x"FF") then
         v.enableCnt := r.enableCnt + 1;
      end if;

      ----------------------------------------------------------
      -- Outputs
      ----------------------------------------------------------

      axilReadSlave  <= r.axilReadSlave;
      axilWriteSlave <= r.axilWriteSlave;

      buffGrpPause <= r.buffGrpPause;

      online          <= r.online;
      interrupt       <= r.interrupt;
      acknowledge     <= r.acknowledge;
      dmaWrDescAck    <= r.dmaWrDescAck;
      dmaWrDescRetAck <= r.dmaWrDescRetAck;
      dmaRdDescReq    <= r.dmaRdDescReq;
      dmaRdDescRetAck <= r.dmaRdDescRetAck;
      axiRdCache      <= r.buffRdCache;
      axiWrCache      <= r.buffWrCache;

      axiWriteMasters <= (others => r.axiWriteMaster);

      -- Only assert one master
      for i in 0 to CHAN_COUNT_G-1 loop
         if descIndex /= i then
            axiWriteMasters(i).awvalid <= '0';
            axiWriteMasters(i).wvalid  <= '0';
         end if;
      end loop;

      ----------------------------------------------------------
      -- Reset
      ----------------------------------------------------------
      if (axiRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
