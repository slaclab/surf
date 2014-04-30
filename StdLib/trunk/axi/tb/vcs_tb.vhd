LIBRARY ieee;
USE work.ALL;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
Library unisim;
use unisim.vcomponents.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.Pgp2bPkg.all;

entity vcs_tb is end vcs_tb;

-- Define architecture
architecture vcs_tb of vcs_tb is

   signal pgpClk            : sl;
   signal pgpClkRst         : sl;
   signal axiClk            : sl;
   signal axiClkRst         : sl;
   signal pgpTxMasters      : AxiStreamMasterArray(3 downto 0);
   signal pgpTxSlaves       : AxiStreamSlaveArray(3 downto 0);
   signal pgpRxMasters      : AxiStreamMasterArray(3 downto 0);
   signal pgpRxSlaves       : AxiStreamSlaveArray(3 downto 0);
   signal axiWriteMaster    : AxiLiteWriteMasterType;
   signal axiWriteSlave     : AxiLiteWriteSlaveType;
   signal axiReadMaster     : AxiLiteReadMasterType;
   signal axiReadSlave      : AxiLiteReadSlaveType;
   signal writeRegister     : Slv32Array(1 downto 0);
   signal readRegister      : Slv32Array(1 downto 0);
   signal cmdMaster         : CmdMasterType;
   signal pgpRxCtrl         : AxiStreamCtrlArray(3 downto 0);

begin

   process begin
      pgpClk <= '1';
      wait for 5 ns;
      pgpClk <= '0';
      wait for 5 ns;
   end process;

   process begin
      pgpClkRst <= '1';
      wait for (50 ns);
      pgpClkRst <= '0';
      wait;
   end process;

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


   U_PgpSimMode : entity work.PgpSimModel
      generic map (
         TPD_G             => 1 ns
      ) port map ( 
         pgpTxClk          => pgpClk,
         pgpTxClkRst       => pgpClkRst,
         pgpTxIn           => PGP_TX_IN_INIT_C,
         pgpTxOut          => open,
         pgpTxMasters      => pgpTxMasters,
         pgpTxSlaves       => pgpTxSlaves,
         pgpRxClk          => pgpClk,
         pgpRxClkRst       => pgpClkRst,
         pgpRxIn           => PGP_RX_IN_INIT_C,
         pgpRxOut          => open,
         pgpRxMasters      => pgpRxMasters,
         pgpRxMasterMuxed  => open,
         pgpRxCtrl         => pgpRxCtrl
      );

   pgpTxMasters(0)          <= AXI_STREAM_MASTER_INIT_C;
   pgpTxMasters(3 downto 2) <= (others=>AXI_STREAM_MASTER_INIT_C);
   pgpRxSlaves(3 downto 2)  <= (others=>AXI_STREAM_SLAVE_INIT_C);
   pgpRxCtrl(3 downto 2)    <= (others=>AXI_STREAM_CTRL_INIT_C);


   U_AxiLiteMaster : entity work.SsiAxiLiteMaster 
      generic map (
         TPD_G               => 1 ns,
         XIL_DEVICE_G        => "7SERIES",
         USE_BUILT_IN_G      => true,
         ALTERA_SYN_G        => false,
         ALTERA_RAM_G        => "M9K",
         BRAM_EN_G           => true,
         GEN_SYNC_FIFO_G     => false,
         CASCADE_SIZE_G      => 1,
         FIFO_ADDR_WIDTH_G   => 9,
         FIFO_PAUSE_THRES_G  => 255,
         AXI_STREAM_CONFIG_G => SSI_PGP_CONFIG_G
      ) port map (
         sAxisClk             => pgpClk,
         sAxisRst             => pgpClkRst,
         sAxisMaster          => pgpRxMasters(1),
         sAxisSlave           => open,
         sAxisCtrl            => pgpRxCtrl(1),
         mAxisClk             => pgpClk,
         mAxisRst             => pgpClkRst,
         mAxisMaster          => pgpTxMasters(1),
         mAxisSlave           => pgpTxSlaves(1),
         axiLiteClk           => axiClk,
         axiLiteRst           => axiClkRst,
         mAxiLiteWriteMaster  => axiWriteMaster,
         mAxiLiteWriteSlave   => axiWriteSlave,
         mAxiLiteReadMaster   => axiReadMaster,
         mAxiLiteReadSlave    => axiReadSlave
      );

   U_AxiLiteEmpty : entity work.AxiLiteEmpty 
      generic map (
         TPD_G           => 1 ns,
         NUM_WRITE_REG_G => 2,
         NUM_READ_REG_G  => 2
      ) port map (
         axiClk         => axiClk,
         axiClkRst      => axiClkRst,
         axiReadMaster  => axiReadMaster,
         axiReadSlave   => axiReadSlave,
         axiWriteMaster => axiWriteMaster,
         axiWriteSlave  => axiWriteSlave,
         writeRegister  => writeRegister,
         readRegister   => readRegister
      );

      readRegister(0) <= x"deadbeef";
      readRegister(1) <= x"44444444";

   U_CmdMaster : entity work.SsiCmdMaster 
      generic map (
         TPD_G               => 1 ns,
         XIL_DEVICE_G        => "7SERIES",
         USE_BUILT_IN_G      => true,
         ALTERA_SYN_G        => false,
         ALTERA_RAM_G        => "M9K",
         BRAM_EN_G           => true,
         GEN_SYNC_FIFO_G     => false,
         CASCADE_SIZE_G      => 1,
         FIFO_ADDR_WIDTH_G   => 9,
         FIFO_PAUSE_THRES_G  => 255,
         AXI_STREAM_CONFIG_G => SSI_PGP_CONFIG_G
      ) port map (
         axisClk       => pgpClk,
         axisRst       => pgpClkRst,
         sAxisMaster   => pgpRxMasters(0),
         sAxisSlave    => open,
         sAxisCtrl     => pgpRxCtrl(0),
         cmdClk        => axiClk,
         cmdClkRst     => axiClkRst,
         cmdMaster     => cmdMaster
      );

end vcs_tb;

