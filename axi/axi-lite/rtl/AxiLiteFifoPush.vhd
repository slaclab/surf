-------------------------------------------------------------------------------
-- File       : AxiLiteFifoPush.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-04-02
-- Last update: 2016-04-26
-------------------------------------------------------------------------------
-- Description:
-- Supports writing of general purpose FIFOs from the AxiLite bus.
-- 16 address locations per FIFO.
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
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

entity AxiLiteFifoPush is
   generic (
      TPD_G              : time                  := 1 ns;
      PUSH_FIFO_COUNT_G  : positive              := 1;
      PUSH_SYNC_FIFO_G   : boolean               := false;
      PUSH_BRAM_EN_G     : boolean               := false;
      PUSH_ADDR_WIDTH_G  : integer range 4 to 48 := 4;
      ALTERA_SYN_G       : boolean               := false;
      ALTERA_RAM_G       : string                := "M9K";
      USE_BUILT_IN_G     : boolean               := false;
      XIL_DEVICE_G       : string                := "7SERIES"
   );
   port (

      -- AXI Interface (axiClk)
      axiClk             : in  sl;
      axiClkRst          : in  sl;
      axiReadMaster      : in  AxiLiteReadMasterType := AXI_LITE_READ_MASTER_INIT_C;
      axiReadSlave       : out AxiLiteReadSlaveType;
      axiWriteMaster     : in  AxiLiteWriteMasterType;
      axiWriteSlave      : out AxiLiteWriteSlaveType;
      pushFifoAFull      : out slv(PUSH_FIFO_COUNT_G-1 downto 0);

      -- Push FIFO Read Interface (pushFifoClk)
      pushFifoClk        : in  slv(PUSH_FIFO_COUNT_G-1 downto 0);
      pushFifoRst        : in  slv(PUSH_FIFO_COUNT_G-1 downto 0);
      pushFifoValid      : out slv(PUSH_FIFO_COUNT_G-1 downto 0);
      pushFifoDout       : out Slv36Array(PUSH_FIFO_COUNT_G-1 downto 0);
      pushFifoRead       : in  slv(PUSH_FIFO_COUNT_G-1 downto 0)
   );
end AxiLiteFifoPush;

architecture structure of AxiLiteFifoPush is

   constant PUSH_SIZE_C  : integer := bitSize(PUSH_FIFO_COUNT_G-1);
   constant PUSH_COUNT_C : integer := 2**PUSH_SIZE_C;

   -- Local Signals
   signal ipushFifoFull  : slv(PUSH_COUNT_C-1 downto 0);
   signal ipushFifoAFull : slv(PUSH_COUNT_C-1 downto 0);
   signal ipushFifoDin   : Slv(35 downto 0);
   signal ipushFifoWrite : slv(PUSH_COUNT_C-1 downto 0);

   type RegType is record
      pushFifoWrite     : slv(PUSH_COUNT_C-1 downto 0);
      pushFifoDin       : slv(35 downto 0);
      axiReadSlave      : AxiLiteReadSlaveType;
      axiWriteSlave     : AxiLiteWriteSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      pushFifoWrite     => (others => '0'),
      pushFifoDin       => (others => '0'),
      axiReadSlave      => AXI_LITE_READ_SLAVE_INIT_C,
      axiWriteSlave     => AXI_LITE_WRITE_SLAVE_INIT_C
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin


   -----------------------------------------
   -- FIFOs
   -----------------------------------------
   U_GenFifo : for i in 0 to PUSH_FIFO_COUNT_G-1 generate
      U_FIfo : entity work.FifoCascade 
         generic map (
            TPD_G              => TPD_G,
            CASCADE_SIZE_G     => 1,
            LAST_STAGE_ASYNC_G => true,
            RST_POLARITY_G     => '1',
            RST_ASYNC_G        => true,
            GEN_SYNC_FIFO_G    => PUSH_SYNC_FIFO_G,
            BRAM_EN_G          => PUSH_BRAM_EN_G,
            FWFT_EN_G          => true,
            USE_DSP48_G        => "no",
            ALTERA_SYN_G       => ALTERA_SYN_G,
            ALTERA_RAM_G       => ALTERA_RAM_G,
            USE_BUILT_IN_G     => USE_BUILT_IN_G,
            XIL_DEVICE_G       => XIL_DEVICE_G,
            SYNC_STAGES_G      => 3,
            DATA_WIDTH_G       => 36,
            ADDR_WIDTH_G       => PUSH_ADDR_WIDTH_G,
            INIT_G             => "0",
            FULL_THRES_G       => 1,
            EMPTY_THRES_G      => 1
         ) port map (
            rst           => pushFifoRst(i),
            wr_clk        => axiClk,
            wr_en         => ipushFifoWrite(i),
            din           => ipushFifoDin,
            wr_data_count => open,
            wr_ack        => open,
            overflow      => open,
            prog_full     => open,
            almost_full   => ipushFifoAFull(i),
            full          => ipushFifoFull(i),
            not_full      => open,
            rd_clk        => pushFifoClk(i),
            rd_en         => pushFifoRead(i),
            dout          => pushFifoDout(i),
            rd_data_count => open,
            valid         => pushFifoValid(i),
            underflow     => open,
            prog_empty    => open,
            almost_empty  => open,
            empty         => open
      );

      pushFifoAFull(i) <= ipushFifoAFull(i);
   end generate;

   U_AlignGen : if PUSH_FIFO_COUNT_G /= PUSH_COUNT_C generate
      ipushFifoAFull(PUSH_COUNT_C-1 downto PUSH_FIFO_COUNT_G) <= (others=>'0');
      ipushFifoFull(PUSH_COUNT_C-1 downto PUSH_FIFO_COUNT_G)  <= (others=>'0');
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
   process (r, axiClkRst, axiReadMaster, axiWriteMaster, ipushFifoFull, ipushFifoAFull ) is
      variable v         : RegType;
      variable axiStatus : AxiLiteStatusType;
   begin
      v := r;

      v.pushFifoWrite := (others=>'0');

      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);

      -- Write
      if (axiStatus.writeEnable = '1') then
         v.pushFifoDin(31 downto  0) := axiWriteMaster.wdata;
         v.pushFifoDin(35 downto 32) := axiWriteMaster.awaddr(5 downto 2);

         v.pushFifoWrite(conv_integer(axiWriteMaster.awaddr(PUSH_SIZE_C+5 downto 6))) := '1';

         axiSlaveWriteResponse(v.axiWriteSlave);
      end if;

      -- Read
      if (axiStatus.readEnable = '1') then

         v.axiReadSlave.rdata    := (others=>'0');
         v.axiReadSlave.rdata(0) := ipushFifoFull(conv_integer(axiReadMaster.araddr(PUSH_SIZE_C+5 downto 6)));
         v.axiReadSlave.rdata(1) := ipushFifoAFull(conv_integer(axiReadMaster.araddr(PUSH_SIZE_C+5 downto 6)));

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
      ipushFifoDin   <= r.pushFifoDin;
      ipushFifoWrite <= r.pushFifoWrite;
      
   end process;

end architecture structure;

