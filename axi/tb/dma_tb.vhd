-------------------------------------------------------------------------------
-- File       : dma_tb.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-05-02
-- Last update: 2016-09-06
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for DMA engine
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
------------------------------------------------------------------------------

LIBRARY ieee;
USE work.ALL;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
Library unisim;
use unisim.vcomponents.all;

use work.StdRtlPkg.all;
use work.AxiPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;

entity dma_tb is end dma_tb;

-- Define architecture
architecture dma_tb of dma_tb is

   signal axiClk            : sl;
   signal axiClkRst         : sl;
   signal mstAxiReadMaster  : AxiReadMasterType;
   signal mstAxiReadSlave   : AxiReadSlaveType;
   signal mstAxiWriteMaster : AxiWriteMasterType;
   signal mstAxiWriteSlave  : AxiWriteSlaveType;
   signal axilReadMaster    : AxiLiteReadMasterType;
   signal axilReadSlave     : AxiLiteReadSlaveType;
   signal axilWriteMaster   : AxiLiteWriteMasterType;
   signal axilWriteSlave    : AxiLiteWriteSlaveType;
   signal slvAxiReadMaster  : AxiReadMasterType;
   signal slvAxiReadSlave   : AxiReadSlaveType;
   signal slvAxiWriteMaster : AxiWriteMasterType;
   signal slvAxiWriteSlave  : AxiWriteSlaveType;
   signal slvAxiWriteCtrl   : AxiCtrlType;
   signal simAxiReadMaster  : AxiReadMasterType;
   signal simAxiReadSlave   : AxiReadSlaveType;
   signal simAxiWriteMaster : AxiWriteMasterType;
   signal simAxiWriteSlave  : AxiWriteSlaveType;
   signal sAxisMaster       : AxiStreamMasterType;
   signal sAxisSlave        : AxiStreamSlaveType;
   signal sAxisCtrl         : AxiStreamCtrlType;
   signal mAxisMaster       : AxiStreamMasterType;
   signal mAxisSlave        : AxiStreamSlaveType;
   signal interrupt         : sl;

   constant AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 8,
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 8,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C
   );

   constant AXI_CONFIG_C : AxiConfigType := (
      ADDR_WIDTH_C => 32,
      DATA_BYTES_C => 8,
      ID_BITS_C    => 8,
      LEN_BITS_C => 4
   );

begin

   process begin
      axiClk <= '1';
      wait for 8 ns;
      axiClk <= '0';
      wait for 8 ns;
   end process;

   process begin
      axiClkRst <= '1';
      wait for (80 ns);
      axiClkRst <= '0';
      wait;
   end process;

   U_AxiMasterSim: entity work.AxiSimMasterWrap 
      generic map (
         TPD_G       => 1 ns,
         MASTER_ID_G => 1
      ) port map (
         axiClk             => axiClk,
         mstAxiReadMaster   => mstAxiReadMaster,
         mstAxiReadSlave    => mstAxiReadSlave,
         mstAxiWriteMaster  => mstAxiWriteMaster,
         mstAxiWriteSlave   => mstAxiWriteSlave 
      );

   U_AxiToAxiLite : entity work.AxiToAxiLite
      generic map (
         TPD_G => 1 ns
      ) port map (
         axiClk              => axiClk,
         axiClkRst           => axiClkRst,
         axiReadMaster       => mstAxiReadMaster,
         axiReadSlave        => mstAxiReadSlave,
         axiWriteMaster      => mstAxiWriteMaster,
         axiWriteSlave       => mstAxiWriteSlave,
         axilReadMaster      => axilReadMaster,
         axilReadSlave       => axilReadSlave,
         axilWriteMaster     => axilWriteMaster,
         axilWriteSlave      => axilWriteSlave
      );

   U_AxiStremDma : entity work.AxiStreamDma
      generic map (
         TPD_G            => 1 ns,
         AXIL_COUNT_G     => 1,
         AXIL_BASE_ADDR_G => x"00000000",
         AXI_READY_EN_G   => true,
         AXIS_READY_EN_G  => false,
         AXIS_CONFIG_G    => AXIS_CONFIG_C,   
         AXI_CONFIG_G     => AXI_CONFIG_C,
         AXI_BURST_G      => "01",
         AXI_CACHE_G      => "1111"
      ) port map (
         axiClk              => axiClk,
         axiRst              => axiClkRst,
         axilReadMaster(0)   => axilReadMaster,
         axilReadSlave(0)    => axilReadSlave,
         axilWriteMaster(0)  => axilWriteMaster,
         axilWriteSlave(0)   => axilWriteSlave,
         interrupt           => interrupt,
         sAxisMaster         => mAxisMaster,
         sAxisSlave          => mAxisSlave,
         mAxisMaster         => sAxisMaster,
         mAxisSlave          => sAxisSlave,
         mAxisCtrl           => sAxisCtrl,
         axiReadMaster       => slvAxiReadMaster,
         axiReadSlave        => slvAxiReadSlave,
         axiWriteMaster      => slvAxiWriteMaster,
         axiWriteSlave       => slvAxiWriteSlave,
         axiWriteCtrl        => slvAxiWriteCtrl
      );

   U_Fifo : entity work.AxiStreamFifo 
      generic map (
         TPD_G               => 1 ns,
         BRAM_EN_G           => true,
         XIL_DEVICE_G        => "7SERIES",
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => false,
         ALTERA_SYN_G        => false,
         ALTERA_RAM_G        => "M9K",
         CASCADE_SIZE_G      => 1,
         FIFO_ADDR_WIDTH_G   => 9,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => 500,
         SLAVE_AXI_CONFIG_G  => AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => AXIS_CONFIG_C
      ) port map (
         sAxisClk        => axiClk,
         sAxisRst        => axiClkRst,
         sAxisMaster     => sAxisMaster,
         sAxisSlave      => sAxisSlave,
         sAxisCtrl       => sAxisCtrl,
         fifoPauseThresh => (others => '1'),
         mAxisClk        => axiClk,
         mAxisRst        => axiClkRst,
         mAxisMaster     => mAxisMaster,
         mAxisSlave      => mAxisSlave
      );


   U_AxiWritePathFifo: entity work.AxiWritePathFifo 
      generic map (
         TPD_G                    => 1 ns,
         XIL_DEVICE_G             => "7SERIES",
         USE_BUILT_IN_G           => false,
         GEN_SYNC_FIFO_G          => false,
         ALTERA_SYN_G             => false,
         ALTERA_RAM_G             => "M9K",
         ADDR_LSB_G               => 0,
         ID_FIXED_EN_G            => false,
         SIZE_FIXED_EN_G          => false,
         BURST_FIXED_EN_G         => false,
         LEN_FIXED_EN_G           => false,
         LOCK_FIXED_EN_G          => false,
         PROT_FIXED_EN_G          => false,
         CACHE_FIXED_EN_G         => false,
         ADDR_BRAM_EN_G           => true,
         ADDR_CASCADE_SIZE_G      => 1,
         ADDR_FIFO_ADDR_WIDTH_G   => 9,
         DATA_BRAM_EN_G           => true,
         DATA_CASCADE_SIZE_G      => 1,
         DATA_FIFO_ADDR_WIDTH_G   => 9,
         DATA_FIFO_PAUSE_THRESH_G => 400,
         RESP_BRAM_EN_G           =>true,
         RESP_CASCADE_SIZE_G      => 1,
         RESP_FIFO_ADDR_WIDTH_G   => 9,
         AXI_CONFIG_G             => AXI_CONFIG_C
      ) port map (
         sAxiClk         => axiClk,
         sAxiRst         => axiClkRst,
         sAxiWriteMaster => slvAxiWriteMaster,
         sAxiWriteSlave  => slvAxiWriteSlave,
         sAxiCtrl        => slvAxiWriteCtrl,
         mAxiClk         => axiClk,
         mAxiRst         => axiClkRst,
         mAxiWriteMaster => simAxiWriteMaster,
         mAxiWriteSlave  => simAxiWriteSlave
      );

   --simAxiWriteMaster <= slvAxiWriteMaster;
   --slvAxiWriteSlave  <= simAxiWriteSlave;
   --slvAxiWriteCtrl   <= AXI_CTRL_UNUSED_C;



   U_AxiReadPathFifo: entity work.AxiReadPathFifo 
      generic map (
         TPD_G                    => 1 ns,
         XIL_DEVICE_G             => "7SERIES",
         USE_BUILT_IN_G           => false,
         GEN_SYNC_FIFO_G          => false,
         ALTERA_SYN_G             => false,
         ALTERA_RAM_G             => "M9K",
         ADDR_LSB_G               => 0,
         ID_FIXED_EN_G            => false,
         SIZE_FIXED_EN_G          => false,
         BURST_FIXED_EN_G         => false,
         LEN_FIXED_EN_G           => false,
         LOCK_FIXED_EN_G          => false,
         PROT_FIXED_EN_G          => false,
         CACHE_FIXED_EN_G         => false,
         ADDR_BRAM_EN_G           => true,
         ADDR_CASCADE_SIZE_G      => 1,
         ADDR_FIFO_ADDR_WIDTH_G   => 9,
         DATA_BRAM_EN_G           => true,
         DATA_CASCADE_SIZE_G      => 1,
         DATA_FIFO_ADDR_WIDTH_G   => 9,
         AXI_CONFIG_G             => AXI_CONFIG_C
      ) port map (
         sAxiClk        => axiClk,
         sAxiRst        => axiClkRst,
         sAxiReadMaster => slvAxiReadMaster,
         sAxiReadSlave  => slvAxiReadSlave,
         mAxiClk        => axiClk,
         mAxiRst        => axiClkRst,
         mAxiReadMaster => simAxiReadMaster,
         mAxiReadSlave  => simAxiReadSlave
      );

   U_AxiSlaveSim: entity work.AxiSimSlaveWrap 
      generic map (
         TPD_G      => 1 ns,
         SLAVE_ID_G => 2
      ) port map (
         axiClk             => axiClk,
         slvAxiReadMaster   => simAxiReadMaster,
         slvAxiReadSlave    => simAxiReadSlave,
         slvAxiWriteMaster  => simAxiWriteMaster,
         slvAxiWriteSlave   => simAxiWriteSlave
      );

end dma_tb;

