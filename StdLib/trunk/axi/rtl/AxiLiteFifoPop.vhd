-------------------------------------------------------------------------------
-- Title         : AXI Lite FIFO Read Module
-- File          : AxiLiteFifoPop.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 09/03/2013
-------------------------------------------------------------------------------
-- Description:
-- Supports reading of general purpose FIFOs from the AxiLite bus.
-- One address location per FIFO.
-------------------------------------------------------------------------------
-- Copyright (c) 2013 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 04/02/2013: created.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

entity AxiLiteFifoPop is
   generic (
      TPD_G              : time                       := 1 ns;
      POP_FIFO_COUNT_G   : positive                   := 1;
      POP_SYNC_FIFO_G    : boolean                    := false;
      POP_BRAM_EN_G      : boolean                    := true;
      POP_ADDR_WIDTH_G   : integer range 4 to 48      := 4;
      POP_FULL_THRES_G   : integer range 1 to (2**24) := 1;
      LOOP_FIFO_EN_G     : boolean                    := false;
      LOOP_FIFO_COUNT_G  : positive                   := 1;
      LOOP_BRAM_EN_G     : boolean                    := true;
      LOOP_ADDR_WIDTH_G  : integer range 4 to 48      := 4;
      RANGE_LSB_G        : integer range 0 to 31      := 8;
      VALID_POSITION_G   : integer range 0 to 31      := 0;
      VALID_POLARITY_G   : sl                         := '0';
      ALTERA_SYN_G       : boolean                    := false;
      ALTERA_RAM_G       : string                     := "M9K";
      USE_BUILT_IN_G     : boolean                    := false;
      XIL_DEVICE_G       : string                     := "7SERIES"
   );
   port (

      -- AXI Interface (axiClk)
      axiClk             : in  sl;
      axiClkRst          : in  sl;
      axiReadMaster      : in  AxiLiteReadMasterType;
      axiReadSlave       : out AxiLiteReadSlaveType;
      axiWriteMaster     : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axiWriteSlave      : out AxiLiteWriteSlaveType;
      popFifoValid       : out slv(POP_FIFO_COUNT_G-1 downto 0);
      popFifoAEmpty      : out slv(POP_FIFO_COUNT_G-1 downto 0);
      loopFifoValid      : out slv(LOOP_FIFO_COUNT_G-1 downto 0);
      loopFifoAEmpty     : out slv(LOOP_FIFO_COUNT_G-1 downto 0);
      loopFifoAFull      : out slv(LOOP_FIFO_COUNT_G-1 downto 0);

      -- POP FIFO Write Interface (popFifoClk)
      popFifoClk         : in  slv(POP_FIFO_COUNT_G-1 downto 0);
      popFifoRst         : in  slv(POP_FIFO_COUNT_G-1 downto 0);
      popFifoWrite       : in  slv(POP_FIFO_COUNT_G-1 downto 0);
      popFifoDin         : in  Slv32Array(POP_FIFO_COUNT_G-1 downto 0);
      popFifoFull        : out slv(POP_FIFO_COUNT_G-1 downto 0);
      popFifoAFull       : out slv(POP_FIFO_COUNT_G-1 downto 0);
      popFifoPFull       : out slv(POP_FIFO_COUNT_G-1 downto 0)
   );
end AxiLiteFifoPop;

architecture structure of AxiLiteFifoPop is

   constant POP_SIZE_C    : integer := bitSize(POP_FIFO_COUNT_G-1);
   constant POP_COUNT_C   : integer := 2**POP_SIZE_C;
   constant LOOP_SIZE_C   : integer := bitSize(LOOP_FIFO_COUNT_G-1);
   constant LOOP_COUNT_C  : integer := 2**LOOP_SIZE_C;

   -- Local Signals
   signal ipopFifoValid  : slv(POP_COUNT_C-1 downto 0);
   signal ipopFifoDout   : Slv32Array(POP_COUNT_C-1 downto 0);
   signal ipopFifoRead   : slv(POP_COUNT_C-1 downto 0);
   signal iloopFifoDin   : slv(31 downto 0);
   signal iloopFifoWrite : Slv(LOOP_COUNT_C-1 downto 0);
   signal iloopFifoValid : slv(LOOP_COUNT_C-1 downto 0);
   signal iloopFifoDout  : Slv32Array(LOOP_COUNT_C-1 downto 0);
   signal iloopFifoRead  : slv(LOOP_COUNT_C-1 downto 0);

   type RegType is record
      loopFifoDin   : slv(31 downto 0);
      loopFifoWrite : Slv(LOOP_COUNT_C-1 downto 0);
      loopFifoRead  : slv(LOOP_COUNT_C-1 downto 0);
      popFifoRead   : slv(POP_COUNT_C-1 downto 0);
      axiReadSlave  : AxiLiteReadSlaveType;
      axiWriteSlave : AxiLiteWriteSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      loopFifoDin   => (others => '0'),
      loopFifoWrite => (others => '0'),
      loopFifoRead  => (others => '0'),
      popFifoRead   => (others => '0'),
      axiReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axiWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   assert RANGE_LSB_G > (POP_SIZE_C +2)
      report "RANGE_LSB_G is too small for POP_FIFO_COUNT_G" severity failure;

   assert RANGE_LSB_G > (LOOP_SIZE_C +2)
      report "RANGE_LSB_G is too small for LOOP_FIFO_COUNT_G" severity failure;

   -----------------------------------------
   -- pop FIFOs
   -----------------------------------------
   U_ReadFifo : for i in 0 to POP_FIFO_COUNT_G-1 generate
      U_FIfo : entity work.FifoCascade 
         generic map (
            TPD_G              => TPD_G,
            CASCADE_SIZE_G     => 1,
            LAST_STAGE_ASYNC_G => true,
            RST_POLARITY_G     => '1',
            RST_ASYNC_G        => true,
            GEN_SYNC_FIFO_G    => POP_SYNC_FIFO_G,
            BRAM_EN_G          => POP_BRAM_EN_G,
            FWFT_EN_G          => true,
            USE_DSP48_G        => "no",
            ALTERA_SYN_G       => ALTERA_SYN_G,
            ALTERA_RAM_G       => ALTERA_RAM_G,
            USE_BUILT_IN_G     => USE_BUILT_IN_G,
            XIL_DEVICE_G       => XIL_DEVICE_G,
            SYNC_STAGES_G      => 3,
            DATA_WIDTH_G       => 32,
            ADDR_WIDTH_G       => POP_ADDR_WIDTH_G,
            INIT_G             => "0",
            FULL_THRES_G       => POP_FULL_THRES_G,
            EMPTY_THRES_G      => 1
         ) port map (
            rst           => popFifoRst(i),
            wr_clk        => popFifoClk(i),
            wr_en         => popFifoWrite(i),
            din           => popFifoDin(i),
            wr_data_count => open,
            wr_ack        => open,
            overflow      => open,
            prog_full     => popFifoPFull(i),
            almost_full   => popFifoAFull(i),
            full          => popFifoFull(i),
            not_full      => open,
            rd_clk        => axiClk,
            rd_en         => ipopFifoRead(i),
            dout          => ipopFifoDout(i),
            rd_data_count => open,
            valid         => ipopFifoValid(i),
            underflow     => open,
            prog_empty    => open,
            almost_empty  => popFifoAEmpty(i),
            empty         => open
      );

      popFifoValid(i) <= ipopFifoValid(i);
   end generate;

   U_ReadUnused : if POP_FIFO_COUNT_G /= POP_COUNT_C generate
      ipopFifoValid(POP_COUNT_C-1 downto POP_FIFO_COUNT_G) <= (others=>'0');
      ipopFifoDout(POP_COUNT_C-1 downto POP_FIFO_COUNT_G)  <= (others=>(others=>'0'));
   end generate;


   -----------------------------------------
   -- Loop FIFOs
   -----------------------------------------
   U_LoopFifoEn : if LOOP_FIFO_EN_G generate
      U_LoopFifo : for i in 0 to LOOP_FIFO_COUNT_G-1 generate
         U_FIfo : entity work.FifoCascade 
            generic map (
               TPD_G              => TPD_G,
               CASCADE_SIZE_G     => 1,
               LAST_STAGE_ASYNC_G => true,
               RST_POLARITY_G     => '1',
               RST_ASYNC_G        => true,
               GEN_SYNC_FIFO_G    => true,
               BRAM_EN_G          => LOOP_BRAM_EN_G,
               FWFT_EN_G          => true,
               USE_DSP48_G        => "no",
               ALTERA_SYN_G       => ALTERA_SYN_G,
               ALTERA_RAM_G       => ALTERA_RAM_G,
               USE_BUILT_IN_G     => USE_BUILT_IN_G,
               XIL_DEVICE_G       => XIL_DEVICE_G,
               SYNC_STAGES_G      => 3,
               DATA_WIDTH_G       => 32,
               ADDR_WIDTH_G       => LOOP_ADDR_WIDTH_G,
               INIT_G             => "0",
               FULL_THRES_G       => 1,
               EMPTY_THRES_G      => 1
            ) port map (
               rst           => axiClkRst,
               wr_clk        => axiClk,
               wr_en         => iloopFifoWrite(i),
               din           => iloopFifoDin,
               wr_data_count => open,
               wr_ack        => open,
               overflow      => open,
               prog_full     => open,
               almost_full   => loopFifoAFull(i),
               full          => open,
               not_full      => open,
               rd_clk        => axiClk,
               rd_en         => iloopFifoRead(i),
               dout          => iloopFifoDout(i),
               rd_data_count => open,
               valid         => iloopFifoValid(i),
               underflow     => open,
               prog_empty    => open,
               almost_empty  => loopFifoAEmpty(i),
               empty         => open
         );
         loopFifoValid(i) <= iloopFifoValid(i);

      end generate;
   end generate;

   U_LoopDis : if LOOP_FIFO_EN_G = false generate
      loopFifoAFull(LOOP_FIFO_COUNT_G-1 downto 0)  <= (others=>'0');
      iloopFifoDout(LOOP_FIFO_COUNT_G-1 downto 0)  <= (others=>(others=>'0'));
      iloopFifoValid(LOOP_FIFO_COUNT_G-1 downto 0) <= (others=>'0');
      loopFifoValid(LOOP_FIFO_COUNT_G-1 downto 0)  <= (others=>'0');
      loopFifoAEmpty(LOOP_FIFO_COUNT_G-1 downto 0) <= (others=>'0');
   end generate;

   U_LoopUnused : if LOOP_FIFO_COUNT_G /= LOOP_COUNT_C generate
      iloopFifoValid(LOOP_COUNT_C-1 downto LOOP_FIFO_COUNT_G) <= (others=>'0');
      iloopFifoDout(LOOP_COUNT_C-1 downto LOOP_FIFO_COUNT_G)  <= (others=>(others=>'0'));
   end generate;


   -----------------------------------------
   -- AXI Lite
   -----------------------------------------

   -- Sync
   process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process;

   -- Async
   process (r, axiClkRst, axiReadMaster, axiWriteMaster, ipopFifoDout, ipopFifoValid, iloopFifoDout, iloopFifoValid ) is
      variable v         : RegType;
      variable axiStatus : AxiLiteStatusType;
   begin
      v := r;

      v.popFifoRead   := (others=>'0');
      v.loopFifoRead  := (others=>'0');
      v.loopFifoWrite := (others=>'0');

      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);

      -- Write
      if (axiStatus.writeEnable = '1') then

         if axiWriteMaster.awaddr(RANGE_LSB_G) = '1' then 
            v.loopFifoDin := axiWriteMaster.wdata;

            v.loopFifoWrite(conv_integer(axiWriteMaster.awaddr(LOOP_SIZE_C+1 downto 2))) := '1';

         end if;

         axiSlaveWriteResponse(v.axiWriteSlave);
      end if;

      -- Read
      if (axiStatus.readEnable = '1') then


         if axiReadMaster.araddr(RANGE_LSB_G) = '0' then 

            v.axiReadSlave.rdata := ipopFifoDout(conv_integer(axiReadMaster.araddr(POP_SIZE_C+1 downto 2)));

            v.axiReadSlave.rdata(VALID_POSITION_G) := 
               VALID_POLARITY_G xor (not ipopFifoValid(conv_integer(axiReadMaster.araddr(POP_SIZE_C+1 downto 2))));

            v.popFifoRead(conv_integer(axiReadMaster.araddr(POP_SIZE_C+1 downto 2))) :=
               ipopFifoValid(conv_integer(axiReadMaster.araddr(POP_SIZE_C+1 downto 2)));

         else

            v.axiReadSlave.rdata := iloopFifoDout(conv_integer(axiReadMaster.araddr(LOOP_SIZE_C+1 downto 2)));

            v.axiReadSlave.rdata(VALID_POSITION_G) := 
               VALID_POLARITY_G xor (not iloopFifoValid(conv_integer(axiReadMaster.araddr(LOOP_SIZE_C+1 downto 2))));

            v.loopFifoRead(conv_integer(axiReadMaster.araddr(LOOP_SIZE_C+1 downto 2))) := 
               iloopFifoValid(conv_integer(axiReadMaster.araddr(LOOP_SIZE_C+1 downto 2)));

         end if;

         -- Send Axi Response
         axiSlaveReadResponse(v.axiReadSlave);

      end if;

      -- Reset
      if (axiClkRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Next register assignment
      rin <= v;

      -- Outputs
      axiReadSlave   <= r.axiReadSlave;
      axiWriteSlave  <= r.axiWriteSlave;
      ipopFifoRead   <= r.popFifoRead;
      iloopFifoDin   <= r.loopFifoDin;
      iloopFifoWrite <= r.loopFifoWrite;
      iloopFifoRead  <= r.loopFifoRead;
      
   end process;

end architecture structure;

