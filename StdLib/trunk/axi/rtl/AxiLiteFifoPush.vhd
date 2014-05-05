-------------------------------------------------------------------------------
-- Title         : AXI Lite FIFO Write Module
-- File          : AxiLiteFifoPush.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 09/03/2013
-------------------------------------------------------------------------------
-- Description:
-- Supports writing of general purpose FIFOs from the AxiLite bus.
-- 16 address locations per FIFO.
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

entity AxiLiteFifoPush is
   generic (
      TPD_G              : time                  := 1 ns;
      WRITE_FIFO_COUNT_G : positive              := 1;
      GEN_SYNC_FIFO_G    : boolean               := false;
      BRAM_EN_G          : boolean               := true;
      ALTERA_SYN_G       : boolean               := false;
      ALTERA_RAM_G       : string                := "M9K";
      USE_BUILT_IN_G     : boolean               := false;
      XIL_DEVICE_G       : string                := "7SERIES";
      ADDR_WIDTH_G       : integer range 4 to 48 := 4
   );
   port (

      -- AXI Interface
      axiClk             : in  sl;
      axiClkRst          : in  sl;
      axiReadMaster      : in  AxiLiteReadMasterType := AXI_LITE_READ_MASTER_INIT_C;
      axiReadSlave       : out AxiLiteReadSlaveType;
      axiWriteMaster     : in  AxiLiteWriteMasterType;
      axiWriteSlave      : out AxiLiteWriteSlaveType;

      -- FIFO Write Interface
      fifoClk            : in  slv(WRITE_FIFO_COUNT_G-1 downto 0);
      fifoValid          : out slv(WRITE_FIFO_COUNT_G-1 downto 0);
      fifoDout           : out Slv36Array(WRITE_FIFO_COUNT_G-1 downto 0);
      fifoRead           : in  slv(WRITE_FIFO_COUNT_G-1 downto 0)
   );
end AxiLiteFifoPush;

architecture structure of AxiLiteFifoPush is

   constant FIFO_SIZE_C  : integer := bitSize(WRITE_FIFO_COUNT_G-1);
   constant FIFO_COUNT_C : integer := 2**FIFO_SIZE_C;

   -- Local Signals
   signal fifoFull   : slv(FIFO_COUNT_C-1 downto 0);
   signal fifoAFull  : slv(FIFO_COUNT_C-1 downto 0);
   signal fifoDin    : Slv(35 downto 0);
   signal fifoWrite  : slv(FIFO_COUNT_C-1 downto 0);

   type RegType is record
      fifoWrite     : slv(FIFO_COUNT_C-1 downto 0);
      fifoDin       : slv(35 downto 0);
      axiReadSlave  : AxiLiteReadSlaveType;
      axiWriteSlave : AxiLiteWriteSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      fifoWrite     => (others => '0'),
      fifoDin       => (others => '0'),
      axiReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axiWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin


   -----------------------------------------
   -- FIFOs
   -----------------------------------------
   U_GenFifo : for i in 0 to WRITE_FIFO_COUNT_G generate
      U_FIfo : entity work.FifoCascade 
         generic map (
            TPD_G              => TPD_G,
            CASCADE_SIZE_G     => 1,
            LAST_STAGE_ASYNC_G => true,
            RST_POLARITY_G     => '1',
            RST_ASYNC_G        => true,
            GEN_SYNC_FIFO_G    => GEN_SYNC_FIFO_G,
            BRAM_EN_G          => BRAM_EN_G,
            FWFT_EN_G          => true,
            USE_DSP48_G        => "no",
            ALTERA_SYN_G       => ALTERA_SYN_G,
            ALTERA_RAM_G       => ALTERA_RAM_G,
            USE_BUILT_IN_G     => USE_BUILT_IN_G,
            XIL_DEVICE_G       => XIL_DEVICE_G,
            SYNC_STAGES_G      => 3,
            DATA_WIDTH_G       => 32,
            ADDR_WIDTH_G       => ADDR_WIDTH_G,
            INIT_G             => "0",
            FULL_THRES_G       => 1,
            EMPTY_THRES_G      => 1
         ) port map (
            rst           => axiClkRst,
            wr_clk        => axiClk,
            wr_en         => fifoWrite(i),
            din           => fifoDin,
            wr_data_count => open,
            wr_ack        => open,
            overflow      => open,
            prog_full     => open,
            almost_full   => fifoAFull(i),
            full          => fifoFull(i),
            not_full      => open,
            rd_clk        => fifoClk(i),
            rd_en         => fifoRead(i),
            dout          => fifoDout(i),
            rd_data_count => open,
            valid         => fifoValid(i),
            underflow     => open,
            prog_empty    => open,
            almost_empty  => open,
            empty         => open
      );
   end generate;

   U_AlignGen : if WRITE_FIFO_COUNT_G /= FIFO_COUNT_C generate
      fifoAFull(FIFO_COUNT_C-1 downto WRITE_FIFO_COUNT_G) <= (others=>'0');
      fifoFull(FIFO_COUNT_C-1 downto WRITE_FIFO_COUNT_G)  <= (others=>'0');
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
   process (r, axiClkRst, axiReadMaster, axiWriteMaster, fifoFull, fifoAFull ) is
      variable v         : RegType;
      variable axiStatus : AxiLiteStatusType;
   begin
      v := r;

      v.fifoWrite := (others=>'0');

      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);

      -- Write
      if (axiStatus.writeEnable = '1') then
         v.fifoDin(31 downto  0) := axiWriteMaster.wdata;
         v.fifoDin(35 downto 32) := axiWriteMaster.awaddr(5 downto 2);

         v.fifoWrite(conv_integer(axiReadMaster.araddr(FIFO_SIZE_C+4 downto 5))) := '1';

         axiSlaveWriteResponse(v.axiWriteSlave);
      end if;

      -- Read
      if (axiStatus.readEnable = '1') then

         v.axiReadSlave.rdata    := (others=>'0');
         v.axiReadSlave.rdata(0) := fifoFull(conv_integer(axiReadMaster.araddr(FIFO_SIZE_C+4 downto 5)));
         v.axiReadSlave.rdata(1) := fifoAFull(conv_integer(axiReadMaster.araddr(FIFO_SIZE_C+4 downto 5)));

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
      fifoDin       <= r.fifoDin;
      fifoWrite     <= r.fifoWrite;
      
   end process;

end architecture structure;

