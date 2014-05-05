-------------------------------------------------------------------------------
-- Title         : AXI Lite Empty End Point
-- File          : AxiLiteAsync.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 03/10/2014
-------------------------------------------------------------------------------
-- Description:
-- Asynchronous bridge for AXI Lite bus. Allows AXI transactions to cross 
-- a clock boundary.
-------------------------------------------------------------------------------
-- Copyright (c) 2014 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 03/10/2014: created.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

entity AxiLiteAsync is
   generic (
      TPD_G            : time    := 1 ns;
      NUM_ADDR_BITS_G  : natural := 32
   );
   port (

      -- Slave Port
      sAxiClk                   : in  sl;
      sAxiClkRst                : in  sl;
      sAxiReadMaster            : in  AxiLiteReadMasterType;
      sAxiReadSlave             : out AxiLiteReadSlaveType;
      sAxiWriteMaster           : in  AxiLiteWriteMasterType;
      sAxiWriteSlave            : out AxiLiteWriteSlaveType;

      -- Master Port
      mAxiClk                   : in  sl;
      mAxiClkRst                : in  sl;
      mAxiReadMaster            : out AxiLiteReadMasterType;
      mAxiReadSlave             : in  AxiLiteReadSlaveType;
      mAxiWriteMaster           : out AxiLiteWriteMasterType;
      mAxiWriteSlave            : in  AxiLiteWriteSlaveType
   );
end AxiLiteAsync;

architecture STRUCTURE of AxiLiteAsync is

   signal readSlaveToMastDin   : slv(NUM_ADDR_BITS_G+2 downto 0);
   signal readSlaveToMastDout  : slv(NUM_ADDR_BITS_G+2 downto 0);
   signal readSlaveToMastFull  : sl;
   signal readSlaveToMastValid : sl;
   signal readSlaveToMastRead  : sl;
   signal readSlaveToMastWrite : sl;

   signal readMastToSlaveDin   : slv(33 downto 0);
   signal readMastToSlaveDout  : slv(33 downto 0);
   signal readMastToSlaveFull  : sl;
   signal readMastToSlaveValid : sl;
   signal readMastToSlaveRead  : sl;
   signal readMastToSlaveWrite : sl;

   signal writeAddrSlaveToMastDin   : slv(NUM_ADDR_BITS_G+2 downto 0);
   signal writeAddrSlaveToMastDout  : slv(NUM_ADDR_BITS_G+2 downto 0);
   signal writeAddrSlaveToMastFull  : sl;
   signal writeAddrSlaveToMastValid : sl;
   signal writeAddrSlaveToMastRead  : sl;
   signal writeAddrSlaveToMastWrite : sl;

   signal writeDataSlaveToMastDin   : slv(35 downto 0);
   signal writeDataSlaveToMastDout  : slv(35 downto 0);
   signal writeDataSlaveToMastFull  : sl;
   signal writeDataSlaveToMastValid : sl;
   signal writeDataSlaveToMastRead  : sl;
   signal writeDataSlaveToMastWrite : sl;

   signal writeMastToSlaveDin   : slv(1 downto 0);
   signal writeMastToSlaveDout  : slv(1 downto 0);
   signal writeMastToSlaveFull  : sl;
   signal writeMastToSlaveValid : sl;
   signal writeMastToSlaveRead  : sl;
   signal writeMastToSlaveWrite : sl;

begin

   ------------------------------------
   -- Read: Slave to Master
   ------------------------------------

   -- Read Slave To Master FIFO
   U_ReadSlaveToMastFifo : entity work.FifoASync
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => '1',
         BRAM_EN_G      => false,  -- Use Dist Ram
         FWFT_EN_G      => true,
         USE_DSP48_G    => "no",
         ALTERA_SYN_G   => false,
         ALTERA_RAM_G   => "M9K",
         SYNC_STAGES_G  => 3,
         DATA_WIDTH_G   => NUM_ADDR_BITS_G+3,
         ADDR_WIDTH_G   => 4,
         INIT_G         => "0",
         FULL_THRES_G   => 15,
         EMPTY_THRES_G  => 1
      ) port map (
         rst                => sAxiClkRst,
         wr_clk             => sAxiClk,
         wr_en              => readSlaveToMastWrite,
         din                => readSlaveTomastDin,
         wr_data_count      => open,
         wr_ack             => open,
         overflow           => open,
         prog_full          => open,
         almost_full        => open,
         full               => readSlaveToMastFull,
         not_full           => open,
         rd_clk             => mAxiClk,
         rd_en              => readSlaveToMastRead,
         dout               => readSlaveTomastDout,
         rd_data_count      => open,
         valid              => readSlaveToMastValid,
         underflow          => open,
         prog_empty         => open,
         almost_empty       => open,
         empty              => open
      );

   -- Data In
   readSlaveToMastDin(2 downto 0)                 <= sAxiReadMaster.arprot;
   readSlaveToMastDin(NUM_ADDR_BITS_G+2 downto 3) <= sAxiReadMaster.araddr(NUM_ADDR_BITS_G-1 downto 0);

   -- Write control and ready generation
   sAxiReadSlave.arready <= not readSlaveToMastFull;
   readSlaveToMastWrite  <= sAxiReadMaster.arvalid and (not readSlaveToMastFull);

   -- Data Out
   mAxiReadMaster.arprot <= readSlaveToMastDout(2 downto 0);

   process (readSlaveToMastDout ) begin
      mAxiReadMaster.araddr <= (others=>'0');
      mAxiReadMaster.araddr <= readSlaveToMastDout(NUM_ADDR_BITS_G+2 downto 3);
   end process;

   -- Read control and valid
   mAxiReadMaster.arvalid <= readSlaveToMastValid;
   readSlaveToMastRead    <= mAxiReadSlave.arready;


   ------------------------------------
   -- Read: Master To Slave
   ------------------------------------

   -- Read Master To Slave FIFO
   U_ReadMastToSlaveFifo : entity work.FifoASync
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => '1',
         BRAM_EN_G      => false,  -- Use Dist Ram
         FWFT_EN_G      => true,
         USE_DSP48_G    => "no",
         ALTERA_SYN_G   => false,
         ALTERA_RAM_G   => "M9K",
         SYNC_STAGES_G  => 3,
         DATA_WIDTH_G   => 34,
         ADDR_WIDTH_G   => 4,
         INIT_G         => "0",
         FULL_THRES_G   => 15,
         EMPTY_THRES_G  => 1
      ) port map (
         rst                => sAxiClkRst,
         wr_clk             => mAxiClk,
         wr_en              => readMastToSlaveWrite,
         din                => readMastToSlaveDin,
         wr_data_count      => open,
         wr_ack             => open,
         overflow           => open,
         prog_full          => open,
         almost_full        => open,
         full               => readMastToSlaveFull,
         not_full           => open,
         rd_clk             => sAxiClk,
         rd_en              => readMastToSlaveRead,
         dout               => readMastToSlaveDout,
         rd_data_count      => open,
         valid              => readMastToSlaveValid,
         underflow          => open,
         prog_empty         => open,
         almost_empty       => open,
         empty              => open
      );

   -- Data In
   readMastToSlaveDin(1  downto 0) <= mAxiReadSlave.rresp;
   readMastToSlaveDin(33 downto 2) <= mAxiReadSlave.rdata;

   -- Write control and ready generation
   mAxiReadMaster.rready <= not readMastToSlaveFull;
   readMastToSlaveWrite  <= mAxiReadSlave.rvalid and (not readMastToSlaveFull);

   -- Data Out
   sAxiReadSlave.rresp <= readMastToSlaveDout(1  downto 0);
   sAxiReadSlave.rdata <= readMastToSlaveDout(33 downto 2);

   -- Read control and valid
   sAxiReadSlave.rvalid <= readMastToSlaveValid;
   readMastToSlaveRead  <= sAxiReadMaster.rready;


   ------------------------------------
   -- Write Addr : Slave To Master
   ------------------------------------

   -- Write Addr Master To Slave FIFO
   U_WriteAddrSlaveToMastFifo : entity work.FifoASync
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => '1',
         BRAM_EN_G      => false,  -- Use Dist Ram
         FWFT_EN_G      => true,
         USE_DSP48_G    => "no",
         ALTERA_SYN_G   => false,
         ALTERA_RAM_G   => "M9K",
         SYNC_STAGES_G  => 3,
         DATA_WIDTH_G   => NUM_ADDR_BITS_G+3,
         ADDR_WIDTH_G   => 4,
         INIT_G         => "0",
         FULL_THRES_G   => 15,
         EMPTY_THRES_G  => 1
      ) port map (
         rst                => sAxiClkRst,
         wr_clk             => sAxiClk,
         wr_en              => writeAddrSlaveToMastWrite,
         din                => writeAddrSlaveToMastDin,
         wr_data_count      => open,
         wr_ack             => open,
         overflow           => open,
         prog_full          => open,
         almost_full        => open,
         full               => writeAddrSlaveToMastFull,
         not_full           => open,
         rd_clk             => mAxiClk,
         rd_en              => writeAddrSlaveToMastRead,
         dout               => writeAddrSlaveToMastDout,
         rd_data_count      => open,
         valid              => writeAddrSlaveToMastValid,
         underflow          => open,
         prog_empty         => open,
         almost_empty       => open,
         empty              => open
      );

   -- Data In
   writeAddrSlaveToMastDin(2  downto 0)                <= sAxiWriteMaster.awprot;
   writeAddrSlaveToMastDin(NUM_ADDR_BITS_G+2 downto 3) <= sAxiWriteMaster.awaddr(NUM_ADDR_BITS_G-1 downto 0);

   -- Write control and ready generation
   sAxiWriteSlave.awready    <= not writeAddrSlaveToMastFull;
   writeAddrSlaveToMastWrite <= sAxiWriteMaster.awvalid and (not writeAddrSlaveToMastFull);

   -- Data Out
   mAxiWriteMaster.awprot <= writeAddrSlaveToMastDout(2 downto 0);

   process (writeAddrSlaveToMastDout ) begin
      mAxiWriteMaster.awaddr <= (others=>'0');
      mAxiWriteMaster.awaddr <= writeAddrSlaveToMastDout(NUM_ADDR_BITS_G+2 downto 3);
   end process;

   -- Read control and valid
   mAxiWriteMaster.awvalid  <= writeAddrSlaveToMastValid;
   writeAddrSlaveToMastRead <= mAxiWriteSlave.awready;


   ------------------------------------
   -- Write Data : Slave to Master
   ------------------------------------

   -- Write Data Slave To Master FIFO
   U_WriteDataSlaveToMastFifo : entity work.FifoASync
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => '1',
         BRAM_EN_G      => false,  -- Use Dist Ram
         FWFT_EN_G      => true,
         USE_DSP48_G    => "no",
         ALTERA_SYN_G   => false,
         ALTERA_RAM_G   => "M9K",
         SYNC_STAGES_G  => 3,
         DATA_WIDTH_G   => 36,
         ADDR_WIDTH_G   => 4,
         INIT_G         => "0",
         FULL_THRES_G   => 15,
         EMPTY_THRES_G  => 1
      ) port map (
         rst                => sAxiClkRst,
         wr_clk             => sAxiClk,
         wr_en              => writeDataSlaveToMastWrite,
         din                => writeDataSlaveTomastDin,
         wr_data_count      => open,
         wr_ack             => open,
         overflow           => open,
         prog_full          => open,
         almost_full        => open,
         full               => writeDataSlaveToMastFull,
         not_full           => open,
         rd_clk             => mAxiClk,
         rd_en              => writeDataSlaveToMastRead,
         dout               => writeDataSlaveTomastDout,
         rd_data_count      => open,
         valid              => writeDataSlaveToMastValid,
         underflow          => open,
         prog_empty         => open,
         almost_empty       => open,
         empty              => open
      );

   -- Data In
   writeDataSlaveToMastDin(3  downto 0) <= sAxiWriteMaster.wstrb;
   writeDataSlaveToMastDin(35 downto 4) <= sAxiWriteMaster.wdata;

   -- Write control and ready generation
   sAxiWriteSlave.wready     <= not writeDataSlaveToMastFull;
   writeDataSlaveToMastWrite <= sAxiWriteMaster.wvalid and (not writeDataSlaveToMastFull);

   -- Data Out
   mAxiWriteMaster.wstrb <= writeDataSlaveToMastDout(3  downto 0);
   mAxiWriteMaster.wdata <= writeDataSlaveToMastDout(35 downto 4);

   -- Read control and valid
   mAxiWriteMaster.wvalid   <= writeDataSlaveToMastValid;
   writeDataSlaveToMastRead <= mAxiWriteSlave.wready;


   ------------------------------------
   -- Write: Status Master To Slave
   ------------------------------------

   -- Write Status Master To Slave FIFO
   U_WriteMastToSlaveFifo : entity work.FifoASync
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => '1',
         BRAM_EN_G      => false,  -- Use Dist Ram
         FWFT_EN_G      => true,
         USE_DSP48_G    => "no",
         ALTERA_SYN_G   => false,
         ALTERA_RAM_G   => "M9K",
         SYNC_STAGES_G  => 3,
         DATA_WIDTH_G   => 2,
         ADDR_WIDTH_G   => 4,
         INIT_G         => "0",
         FULL_THRES_G   => 15,
         EMPTY_THRES_G  => 1
      ) port map (
         rst                => sAxiClkRst,
         wr_clk             => mAxiClk,
         wr_en              => writeMastToSlaveWrite,
         din                => writeMastToSlaveDin,
         wr_data_count      => open,
         wr_ack             => open,
         overflow           => open,
         prog_full          => open,
         almost_full        => open,
         full               => writeMastToSlaveFull,
         not_full           => open,
         rd_clk             => sAxiClk,
         rd_en              => writeMastToSlaveRead,
         dout               => writeMastToSlaveDout,
         rd_data_count      => open,
         valid              => writeMastToSlaveValid,
         underflow          => open,
         prog_empty         => open,
         almost_empty       => open,
         empty              => open
      );

   -- Data In
   writeMastToSlaveDin <= mAxiWriteSlave.bresp;

   -- Write control and ready generation
   mAxiWriteMaster.bready <= not writeMastToSlaveFull;
   writeMastToSlaveWrite  <= mAxiWriteSlave.bvalid and (not writeMastToSlaveFull);

   -- Data Out
   sAxiWriteSlave.bresp <= writeMastToSlaveDout;

   -- Read control and valid
   sAxiWriteSlave.bvalid <= writeMastToSlaveValid;
   writeMastToSlaveRead  <= sAxiWriteMaster.bready;

end architecture STRUCTURE;

