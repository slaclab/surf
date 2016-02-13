-------------------------------------------------------------------------------
-- Title      : AXI PCIe Core
-------------------------------------------------------------------------------
-- File       : AxiPcieDma.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-02-12
-- Last update: 2016-02-12
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2016 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.AxiPciePkg.all;

entity AxiPcieDma is
   generic (
      TPD_G            : time                   := 1 ns;
      DMA_SIZE_G       : positive range 1 to 16 := 1;
      AXI_ERROR_RESP_G : slv(1 downto 0)        := AXI_RESP_DECERR_C;
      AXI_CONFIG_G     : AxiConfigType          := AXI_CONFIG_INIT_C;
      AXIS_CONFIG_G    : AxiStreamConfigArray);
   port (
      -- Clock and reset
      axiClk          : in  sl;
      axiRst          : in  sl;
      -- AXI4 Interfaces
      axiReadMaster   : out AxiReadMasterType;
      axiReadSlave    : in  AxiReadSlaveType;
      axiWriteMaster  : out AxiWriteMasterType;
      axiWriteSlave   : in  AxiWriteSlaveType;
      -- AXI4-Lite Interfaces
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      -- Interrupts
      interrupt       : out slv(DMA_SIZE_G-1 downto 0);
      -- DMA Interfaces
      dmaClk          : in  slv(DMA_SIZE_G-1 downto 0);
      dmaRst          : in  slv(DMA_SIZE_G-1 downto 0);
      dmaObMasters    : out AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
      dmaObSlaves     : in  AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
      dmaIbMasters    : in  AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
      dmaIbSlaves     : out AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0));   
end AxiPcieDma;

architecture mapping of AxiPcieDma is

   function DmaAxiLiteConfig return AxiLiteCrossbarMasterConfigArray is
      variable retConf : AxiLiteCrossbarMasterConfigArray((2*DMA_SIZE_G)-1 downto 0);
      variable addr    : slv(31 downto 0);
   begin
      addr := x"00000000";
      for i in (2*DMA_SIZE_G)-1 downto 0 loop
         addr(14 downto 10)      := toSlv(i, 5);
         retConf(i).baseAddr     := addr;
         retConf(i).addrBits     := 10;
         retConf(i).connectivity := x"FFFF";
      end loop;
      return retConf;
   end function;

   signal locReadMasters : AxiReadMasterArray(DMA_SIZE_G-1 downto 0);
   signal locReadSlaves  : AxiReadSlaveArray(DMA_SIZE_G-1 downto 0);
   signal axiReadMasters : AxiReadMasterArray(DMA_SIZE_G-1 downto 0);
   signal axiReadSlaves  : AxiReadSlaveArray(DMA_SIZE_G-1 downto 0);

   signal locWriteMasters : AxiWriteMasterArray(DMA_SIZE_G-1 downto 0);
   signal locWriteSlaves  : AxiWriteSlaveArray(DMA_SIZE_G-1 downto 0);
   signal locWriteCtrl    : AxiCtrlArray(DMA_SIZE_G-1 downto 0);
   signal axiWriteMasters : AxiWriteMasterArray(DMA_SIZE_G-1 downto 0);
   signal axiWriteSlaves  : AxiWriteSlaveArray(DMA_SIZE_G-1 downto 0);

   signal sAxisMasters : AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
   signal sAxisSlaves  : AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);

   signal mAxisMasters : AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
   signal mAxisSlaves  : AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
   signal mAxisCtrl    : AxiStreamCtrlArray(DMA_SIZE_G-1 downto 0);

   signal axilReadMasters  : AxiLiteReadMasterArray((2*DMA_SIZE_G)-1 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray((2*DMA_SIZE_G)-1 downto 0);
   signal axilWriteMasters : AxiLiteWriteMasterArray((2*DMA_SIZE_G)-1 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray((2*DMA_SIZE_G)-1 downto 0);
   
begin

   --------------------
   -- AXI Read Path MUX
   --------------------
   U_AxiReadPathMux : entity work.AxiReadPathMux
      generic map (
         TPD_G        => TPD_G,
         NUM_SLAVES_G => DMA_SIZE_G) 
      port map (
         -- Clock and reset
         axiClk          => axiClk,
         axiRst          => axiRst,
         -- Slaves
         sAxiReadMasters => axiReadMasters,
         sAxiReadSlaves  => axiReadSlaves,
         -- Master
         mAxiReadMaster  => axiReadMaster,
         mAxiReadSlave   => axiReadSlave);   

   -----------------------
   -- AXI Write Path DEMUX
   -----------------------
   U_AxiWritePathMux : entity work.AxiWritePathMux
      generic map (
         TPD_G        => TPD_G,
         NUM_SLAVES_G => DMA_SIZE_G) 
      port map (
         -- Clock and reset
         axiClk           => axiClk,
         axiRst           => axiRst,
         -- Slaves
         sAxiWriteMasters => axiWriteMasters,
         sAxiWriteSlaves  => axiWriteSlaves,
         -- Master
         mAxiWriteMaster  => axiWriteMaster,
         mAxiWriteSlave   => axiWriteSlave);            

   --------------------
   -- AXI-Lite Crossbar
   --------------------
   U_AxiLiteCrossbar : entity work.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => (2*DMA_SIZE_G),
         DEC_ERROR_RESP_G   => AXI_ERROR_RESP_G,
         MASTERS_CONFIG_G   => DmaAxiLiteConfig) 
      port map (
         axiClk              => axiClk,
         axiClkRst           => axiRst,
         sAxiWriteMasters(0) => axilWriteMaster,
         sAxiWriteSlaves(0)  => axilWriteSlave,
         sAxiReadMasters(0)  => axilReadMaster,
         sAxiReadSlaves(0)   => axilReadSlave,
         mAxiWriteMasters    => axilWriteMasters,
         mAxiWriteSlaves     => axilWriteSlaves,
         mAxiReadMasters     => axilReadMasters,
         mAxiReadSlaves      => axilReadSlaves);         

   ---------------
   -- DMA Channels
   ---------------
   U_DmaChanGen : for i in DMA_SIZE_G-1 downto 0 generate

      -----------
      -- DMA Core
      -----------
      U_AxiStreamDma : entity work.AxiStreamDma
         generic map (
            TPD_G             => TPD_G,
            -- AXI_ERROR_RESP_G  => AXI_ERROR_RESP_G,-- not implemented yet
            FREE_ADDR_WIDTH_G => 12,           -- 4096 entries
            AXIL_COUNT_G      => 2,
            AXIL_BASE_ADDR_G  => x"00000000", 
            AXI_READY_EN_G    => false,
            AXIS_READY_EN_G   => false,
            AXIS_CONFIG_G     => PCIE_AXIS_CONFIG_C,
            AXI_CONFIG_G      => AXI_CONFIG_G,
            AXI_BURST_G       => "01",         -- INCR 
            AXI_CACHE_G       => "0000")       -- Device Non-bufferable 
         port map (
            axiClk          => axiClk,
            axiRst          => axiRst,
            axilReadMaster  => axilReadMasters((i*2)+1 downto i*2),
            axilReadSlave   => axilReadSlaves((i*2)+1 downto i*2),
            axilWriteMaster => axilWriteMasters((i*2)+1 downto i*2),
            axilWriteSlave  => axilWriteSlaves((i*2)+1 downto i*2),
            interrupt       => interrupt(i),
            sAxisMaster     => sAxisMasters(i),
            sAxisSlave      => sAxisSlaves(i),
            mAxisMaster     => mAxisMasters(i),
            mAxisSlave      => mAxisSlaves(i),
            mAxisCtrl       => mAxisCtrl(i),
            axiReadMaster   => locReadMasters(i),
            axiReadSlave    => locReadSlaves(i),
            axiWriteMaster  => locWriteMasters(i),
            axiWriteSlave   => locWriteSlaves(i),
            axiWriteCtrl    => locWriteCtrl(i));

      --------------------------
      -- Inbound AXI Stream FIFO
      --------------------------
      U_IbFifo : entity work.AxiStreamFifo
         generic map (
            TPD_G               => TPD_G,
            PIPE_STAGES_G       => 1,
            SLAVE_READY_EN_G    => true,
            VALID_THOLD_G       => 1,
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
            SLAVE_AXI_CONFIG_G  => AXIS_CONFIG_G(i),
            MASTER_AXI_CONFIG_G => PCIE_AXIS_CONFIG_C) 
         port map (
            sAxisClk        => dmaClk(i),
            sAxisRst        => dmaRst(i),
            sAxisMaster     => dmaIbMasters(i),
            sAxisSlave      => dmaIbSlaves(i),
            sAxisCtrl       => open,
            fifoPauseThresh => (others => '1'),
            mAxisClk        => axiClk,
            mAxisRst        => axiRst,
            mAxisMaster     => sAxisMasters(i),
            mAxisSlave      => sAxisSlaves(i));

      ---------------------------
      -- Outbound AXI Stream FIFO
      ---------------------------
      U_ObFifo : entity work.AxiStreamFifo
         generic map (
            TPD_G               => TPD_G,
            PIPE_STAGES_G       => 1,
            SLAVE_READY_EN_G    => false,
            VALID_THOLD_G       => 1,
            BRAM_EN_G           => true,
            XIL_DEVICE_G        => "7SERIES",
            USE_BUILT_IN_G      => false,
            GEN_SYNC_FIFO_G     => false,
            ALTERA_SYN_G        => false,
            ALTERA_RAM_G        => "M9K",
            CASCADE_SIZE_G      => 1,
            FIFO_ADDR_WIDTH_G   => 9,
            FIFO_FIXED_THRESH_G => true,
            FIFO_PAUSE_THRESH_G => 475,
            SLAVE_AXI_CONFIG_G  => PCIE_AXIS_CONFIG_C,
            MASTER_AXI_CONFIG_G => AXIS_CONFIG_G(i)) 
         port map (
            sAxisClk        => axiClk,
            sAxisRst        => axiRst,
            sAxisMaster     => mAxisMasters(i),
            sAxisSlave      => mAxisSlaves(i),
            sAxisCtrl       => mAxisCtrl(i),
            fifoPauseThresh => (others => '1'),
            mAxisClk        => dmaClk(i),
            mAxisRst        => dmaRst(i),
            mAxisMaster     => dmaObMasters(i),
            mAxisSlave      => dmaObSlaves(i));

      ---------------------
      -- Read Path AXI FIFO
      ---------------------
      U_AxiReadPathFifo : entity work.AxiReadPathFifo
         generic map (
            TPD_G                  => TPD_G,
            XIL_DEVICE_G           => "7SERIES",
            USE_BUILT_IN_G         => false,
            GEN_SYNC_FIFO_G        => true,
            ALTERA_SYN_G           => false,
            ALTERA_RAM_G           => "M9K",
            ADDR_LSB_G             => 3,
            ID_FIXED_EN_G          => true,
            SIZE_FIXED_EN_G        => true,
            BURST_FIXED_EN_G       => true,
            LEN_FIXED_EN_G         => false,
            LOCK_FIXED_EN_G        => true,
            PROT_FIXED_EN_G        => true,
            CACHE_FIXED_EN_G       => true,
            ADDR_BRAM_EN_G         => false,
            ADDR_CASCADE_SIZE_G    => 1,
            ADDR_FIFO_ADDR_WIDTH_G => 4,
            DATA_BRAM_EN_G         => false,
            DATA_CASCADE_SIZE_G    => 1,
            DATA_FIFO_ADDR_WIDTH_G => 4,
            AXI_CONFIG_G           => AXI_CONFIG_G) 
         port map (
            sAxiClk        => axiClk,
            sAxiRst        => axiRst,
            sAxiReadMaster => locReadMasters(i),
            sAxiReadSlave  => locReadSlaves(i),
            mAxiClk        => axiClk,
            mAxiRst        => axiRst,
            mAxiReadMaster => axiReadMasters(i),
            mAxiReadSlave  => axiReadSlaves(i));

      ----------------------
      -- Write Path AXI FIFO
      ----------------------
      U_AxiWritePathFifo : entity work.AxiWritePathFifo
         generic map (
            TPD_G                    => TPD_G,
            XIL_DEVICE_G             => "7SERIES",
            USE_BUILT_IN_G           => false,
            GEN_SYNC_FIFO_G          => true,
            ALTERA_SYN_G             => false,
            ALTERA_RAM_G             => "M9K",
            ADDR_LSB_G               => 3,
            ID_FIXED_EN_G            => true,
            SIZE_FIXED_EN_G          => true,
            BURST_FIXED_EN_G         => true,
            LEN_FIXED_EN_G           => false,
            LOCK_FIXED_EN_G          => true,
            PROT_FIXED_EN_G          => true,
            CACHE_FIXED_EN_G         => true,
            ADDR_BRAM_EN_G           => true,
            ADDR_CASCADE_SIZE_G      => 1,
            ADDR_FIFO_ADDR_WIDTH_G   => 9,
            DATA_BRAM_EN_G           => true,
            DATA_CASCADE_SIZE_G      => 1,
            DATA_FIFO_ADDR_WIDTH_G   => 9,
            DATA_FIFO_PAUSE_THRESH_G => 456,
            RESP_BRAM_EN_G           => false,
            RESP_CASCADE_SIZE_G      => 1,
            RESP_FIFO_ADDR_WIDTH_G   => 4,
            AXI_CONFIG_G             => AXI_CONFIG_G) 
         port map (
            sAxiClk         => axiClk,
            sAxiRst         => axiRst,
            sAxiWriteMaster => locWriteMasters(i),
            sAxiWriteSlave  => locWriteSlaves(i),
            sAxiCtrl        => locWriteCtrl(i),
            mAxiClk         => axiClk,
            mAxiRst         => axiRst,
            mAxiWriteMaster => axiWriteMasters(i),
            mAxiWriteSlave  => axiWriteSlaves(i));

   end generate;

end mapping;
