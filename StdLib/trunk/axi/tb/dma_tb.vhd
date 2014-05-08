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
      TKEEP_MODE_C  => TKEEP_NORMAL_C,
      TUSER_BITS_C  => 8,
      TUSER_MODE_C  => TUSER_NORMAL_C
   );

   constant AXI_CONFIG_C : AxiConfigType := (
      DATA_BYTES_C => 8,
      ID_BITS_C    => 8
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
         AXI_BASE_ADDR_G  => x"00000",
         AXI_READY_EN_G   => true,
         AXIS_READY_EN_G  => false,
         AXIS_CONFIG_G    => AXIS_CONFIG_C,   
         AXI_CONFIG_G     => AXI_CONFIG_C,
         AXI_BURST_G      => "01",
         AXI_CACHE_G      => "1111"
      ) port map (
         axiClk              => axiClk,
         axiRst              => axiClkRst,
         axilReadMaster      => axilReadMaster,
         axilReadSlave       => axilReadSlave,
         axilWriteMaster     => axilWriteMaster,
         axilWriteSlave      => axilWriteSlave,
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
         axiWriteCtrl        => AXI_CTRL_UNUSED_C
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

   U_AxiSlaveSim: entity work.AxiSimSlaveWrap 
      generic map (
         TPD_G      => 1 ns,
         SLAVE_ID_G => 2
      ) port map (
         axiClk             => axiClk,
         slvAxiReadMaster   => slvAxiReadMaster,
         slvAxiReadSlave    => slvAxiReadSlave,
         slvAxiWriteMaster  => slvAxiWriteMaster,
         slvAxiWriteSlave   => slvAxiWriteSlave
      );

end dma_tb;

