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
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

entity AxiLiteFifoPop is
   generic (
      TPD_G              : time                  := 1 ns;
      READ_FIFO_COUNT_G  : positive              := 1;
      LOOP_FIFO_COUNT_G  : integer               := 0;
      VALID_POSITION_G   : integer range 0 to 31 := 0;
      VALID_POLARITY_G   : sl                    := '0';
      GEN_SYNC_FIFO_G    : boolean               := false;
      READ_BRAM_EN_G     : boolean               := true;
      LOOP_BRAM_EN_G     : boolean               := true;
      ALTERA_SYN_G       : boolean               := false;
      ALTERA_RAM_G       : string                := "M9K";
      USE_BUILT_IN_G     : boolean               := false;
      XIL_DEVICE_G       : string                := "7SERIES";
      READ_ADDR_WIDTH_G  : integer range 4 to 48 := 4;
      LOOP_ADDR_WIDTH_G  : integer range 4 to 48 := 4
   );
   port (

      -- AXI Interface
      axiClk             : in  sl;
      axiClkRst          : in  sl;
      axiReadMaster      : in  AxiLiteReadMasterType;
      axiReadSlave       : out AxiLiteReadSlaveType;
      axiWriteMaster     : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axiWriteSlave      : out AxiLiteWriteSlaveType;
      fifoValid          : out slv(READ_FIFO_COUNT_G-1 downto 0);

      -- FIFO Write Interface
      fifoClk            : in  slv(READ_FIFO_COUNT_G-1 downto 0);
      fifoWrite          : in  slv(READ_FIFO_COUNT_G-1 downto 0);
      fifoDin            : in  Slv32Array(READ_FIFO_COUNT_G-1 downto 0);
      fifoFull           : out slv(READ_FIFO_COUNT_G-1 downto 0);
      fifoAFull          : out slv(READ_FIFO_COUNT_G-1 downto 0)
   );
end AxiLiteFifoPop;

architecture structure of AxiLiteFifoPop is

   constant READ_SIZE_C  : integer := bitSize(READ_FIFO_COUNT_G-1);
   constant READ_COUNT_C : integer := 2**READ_SIZE_C;
   constant LOOP_SIZE_C  : integer := bitSize(LOOP_FIFO_COUNT_G-1);
   constant LOOP_COUNT_C : integer := 2**LOOP_SIZE_C;
   constant RANGE_BIT_C  : integer := ite(READ_SIZE_C > LOOP_SIZE_C,READ_SIZE_C+2,LOOP_SIZE_C+2);

   -- Local Signals
   signal readFifoValid : slv(READ_COUNT_C-1 downto 0);
   signal readFifoDout  : Slv32Array(READ_COUNT_C-1 downto 0);
   signal readFifoRead  : slv(READ_COUNT_C-1 downto 0);
   signal loopFifoDin   : slv(31 downto 0);
   signal loopFifoWrite : Slv(LOOP_COUNT_C-1 downto 0);
   signal loopFifoValid : slv(LOOP_COUNT_C-1 downto 0);
   signal loopFifoDout  : Slv32Array(LOOP_COUNT_C-1 downto 0);
   signal loopFifoRead  : slv(LOOP_COUNT_C-1 downto 0);

   type RegType is record
      loopFifoDin   : slv(31 downto 0);
      loopFifoWrite : Slv(LOOP_COUNT_C-1 downto 0);
      loopFifoRead  : slv(LOOP_COUNT_C-1 downto 0);
      readFifoRead  : slv(READ_COUNT_C-1 downto 0);
      readFifoValid : slv(READ_COUNT_C-1 downto 0);
      axiReadSlave  : AxiLiteReadSlaveType;
      axiWriteSlave : AxiLiteWriteSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      loopFifoDin   => (others => '0'),
      loopFifoWrite => (others => '0'),
      loopFifoRead  => (others => '0'),
      readFifoRead  => (others => '0'),
      readFifoValid => (others => '0'),
      axiReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axiWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin


   -----------------------------------------
   -- Read FIFOs
   -----------------------------------------
   U_ReadFifo : for i in 0 to READ_FIFO_COUNT_G-1 generate
      U_FIfo : entity work.FifoCascade 
         generic map (
            TPD_G              => TPD_G,
            CASCADE_SIZE_G     => 1,
            LAST_STAGE_ASYNC_G => true,
            RST_POLARITY_G     => '1',
            RST_ASYNC_G        => true,
            GEN_SYNC_FIFO_G    => GEN_SYNC_FIFO_G,
            BRAM_EN_G          => READ_BRAM_EN_G,
            FWFT_EN_G          => true,
            USE_DSP48_G        => "no",
            ALTERA_SYN_G       => ALTERA_SYN_G,
            ALTERA_RAM_G       => ALTERA_RAM_G,
            USE_BUILT_IN_G     => USE_BUILT_IN_G,
            XIL_DEVICE_G       => XIL_DEVICE_G,
            SYNC_STAGES_G      => 3,
            DATA_WIDTH_G       => 32,
            ADDR_WIDTH_G       => READ_ADDR_WIDTH_G,
            INIT_G             => "0",
            FULL_THRES_G       => 1,
            EMPTY_THRES_G      => 1
         ) port map (
            rst           => axiClkRst,
            wr_clk        => fifoClk(i),
            wr_en         => fifoWrite(i),
            din           => fifoDin(i),
            wr_data_count => open,
            wr_ack        => open,
            overflow      => open,
            prog_full     => open,
            almost_full   => fifoAFull(i),
            full          => fifoFull(i),
            not_full      => open,
            rd_clk        => axiClk,
            rd_en         => readFifoRead(i),
            dout          => readFifoDout(i),
            rd_data_count => open,
            valid         => readFifoValid(i),
            underflow     => open,
            prog_empty    => open,
            almost_empty  => open,
            empty         => open
      );
   end generate;

   U_ReadUnused : if READ_FIFO_COUNT_G /= READ_COUNT_C generate
      readFifoValid(READ_COUNT_C-1 downto READ_FIFO_COUNT_G) <= (others=>'0');
      readFifoDout(READ_COUNT_C-1 downto READ_FIFO_COUNT_G)  <= (others=>(others=>'0'));
   end generate;


   -----------------------------------------
   -- Loop FIFOs
   -----------------------------------------
   U_LoopFifo : for i in 0 to LOOP_FIFO_COUNT_G-1 generate
      U_FIfo : entity work.FifoCascade 
         generic map (
            TPD_G              => TPD_G,
            CASCADE_SIZE_G     => 1,
            LAST_STAGE_ASYNC_G => true,
            RST_POLARITY_G     => '1',
            RST_ASYNC_G        => true,
            GEN_SYNC_FIFO_G    => GEN_SYNC_FIFO_G,
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
            wr_en         => loopFifoWrite(i),
            din           => loopFifoDin,
            wr_data_count => open,
            wr_ack        => open,
            overflow      => open,
            prog_full     => open,
            almost_full   => open,
            full          => open,
            not_full      => open,
            rd_clk        => axiClk,
            rd_en         => loopFifoRead(i),
            dout          => loopFifoDout(i),
            rd_data_count => open,
            valid         => loopFifoValid(i),
            underflow     => open,
            prog_empty    => open,
            almost_empty  => open,
            empty         => open
      );
   end generate;

   U_LoopUnused : if LOOP_FIFO_COUNT_G /= LOOP_COUNT_C generate
      loopFifoValid(LOOP_COUNT_C-1 downto LOOP_FIFO_COUNT_G) <= (others=>'0');
      loopFifoDout(LOOP_COUNT_C-1 downto LOOP_FIFO_COUNT_G)  <= (others=>(others=>'0'));
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
   process (r, axiClkRst, axiReadMaster, axiWriteMaster, readFifoDout, readFifoValid, loopFifoDout, loopFifoValid ) is
      variable v         : RegType;
      variable axiStatus : AxiLiteStatusType;
   begin
      v := r;

      v.readFifoRead  := (others=>'0');
      v.loopFifoRead  := (others=>'0');
      v.loopFifoWrite := (others=>'0');
      v.readFifoValid := readFifoValid;

      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);

      -- Write
      if (axiStatus.writeEnable = '1') then

         if axiWriteMaster.awaddr(RANGE_BIT_C) = '1' then 
            v.loopFifoDin := axiWriteMaster.wdata;

            v.loopFifoWrite(conv_integer(axiWriteMaster.awaddr(LOOP_SIZE_C+1 downto 2))) := '1';

         end if;

         axiSlaveWriteResponse(v.axiWriteSlave);
      end if;

      -- Read
      if (axiStatus.readEnable = '1') then


         if axiReadMaster.araddr(RANGE_BIT_C) = '0' then 

            v.axiReadSlave.rdata := readFifoDout(conv_integer(axiReadMaster.araddr(READ_SIZE_C+1 downto 2)));

            v.axiReadSlave.rdata(VALID_POSITION_G) := 
               VALID_POLARITY_G xor (not readFifoValid(conv_integer(axiReadMaster.araddr(READ_SIZE_C+1 downto 2))));

            v.readFifoRead(conv_integer(axiReadMaster.araddr(READ_SIZE_C+1 downto 2))) := '1';

         else

            v.axiReadSlave.rdata := loopFifoDout(conv_integer(axiReadMaster.araddr(LOOP_SIZE_C+1 downto 2)));

            v.axiReadSlave.rdata(VALID_POSITION_G) := 
               VALID_POLARITY_G xor (not loopFifoValid(conv_integer(axiReadMaster.araddr(LOOP_SIZE_C+1 downto 2))));

            v.loopFifoRead(conv_integer(axiReadMaster.araddr(LOOP_SIZE_C+1 downto 2))) := '1';

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
      axiReadSlave  <= r.axiReadSlave;
      axiWriteSlave <= r.axiWriteSlave;
      readFifoRead  <= v.readFifoRead;
      fifoValid     <= r.readFifoValid;
      
   end process;

end architecture structure;

