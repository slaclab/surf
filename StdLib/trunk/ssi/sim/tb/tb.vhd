LIBRARY ieee;
USE work.ALL;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
Library unisim;
use unisim.vcomponents.all;

use work.ArmRceG3Pkg.all;
use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.Vc64Pkg.all;
use work.Pgp2bPkg.all;

entity tb is end tb;

-- Define architecture
architecture tb of tb is

   signal pgpClk            : sl;
   signal pgpClkRst         : sl;
   signal axiClk            : sl;
   signal axiClkRst         : sl;
   signal pgpTxVcData       : Vc64DataArray(3 downto 0);
   signal pgpTxVcCtrl       : Vc64CtrlArray(3 downto 0);
   signal pgpRxVcDataCommon : Vc64DataType;
   signal pgpRxVcData       : Vc64DataArray(3 downto 0);
   signal pgpRxVcCtrl       : Vc64CtrlArray(3 downto 0);
   signal axiWriteMaster    : AxiLiteWriteMasterType;
   signal axiWriteSlave     : AxiLiteWriteSlaveType;
   signal axiReadMaster     : AxiLiteReadMasterType;
   signal axiReadSlave      : AxiLiteReadSlaveType;
   signal writeRegister     : Slv32Array(1 downto 0);
   signal readRegister      : Slv32Array(1 downto 0);
   signal cmdMasterOut      : Vc64CmdMasterOutType;

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


   U_Vc64SimLinkPgp : entity work.Vc64SimLinkPgp 
      generic map (
         TPD_G             => 1 ns,
         LANE_CNT_G        => 1
      ) port map ( 
         pgpTxClk          => pgpClk,
         pgpTxClkRst       => pgpClkRst,
         pgpTxIn           => PGP_TX_IN_INIT_C,
         pgpTxOut          => open,
         pgpTxVcData       => pgpTxVcData,
         pgpTxVcCtrl       => pgpTxVcCtrl,
         pgpRxClk          => pgpClk,
         pgpRxClkRst       => pgpClkRst,
         pgpRxIn           => PGP_RX_IN_INIT_C,
         pgpRxOut          => open,
         pgpRxVcData       => pgpRxVcDataCommon,
         pgpRxVcCtrl       => pgpRxVcCtrl
      );


   process ( pgpRxVcDataCommon ) begin
      pgpRxVcData <= Vc64DeMux(pgpRxVcDataCommon,4);
   end process;

   pgpTxVcData(0)          <= VC64_DATA_INIT_C;
   pgpTxVcData(3 downto 2) <= (others=>VC64_DATA_INIT_C);
   pgpRxVcCtrl(3 downto 2) <= (others=>VC64_CTRL_FORCE_C);

   U_Vc64AxiMaster : entity work.Vc64AxiMaster
      generic map (
         TPD_G              => 1 ns,
         XIL_DEVICE_G       => "7SERIES",
         USE_BUILT_IN_G     => true,
         ALTERA_SYN_G       => false,
         ALTERA_RAM_G       => "M9K",
         BRAM_EN_G          => true,
         GEN_SYNC_FIFO_G    => false,
         FIFO_SYNC_STAGES_G => 3,
         FIFO_ADDR_WIDTH_G  => 9,
         FIFO_AFULL_THRES_G => 255,
         LITTLE_ENDIAN_G    => true,
         VC_WIDTH_G         => 16
      ) port map (
         vcRxData        => pgpRxVcData(1),
         vcRxCtrl        => pgpRxVcCtrl(1),
         vcRxClk         => pgpClk,
         vcRxRst         => pgpClkRst,
         vcTxData        => pgpTxVcData(1),
         vcTxCtrl        => pgpTxVcCtrl(1),
         vcTxClk         => pgpClk,
         vcTxRst         => pgpClkRst,
         axiClk          => axiClk,
         axiClkRst       => axiClkRst,
         axiWriteMaster  => axiWriteMaster,
         axiWriteSlave   => axiWriteSlave,
         axiReadMaster   => axiReadMaster,
         axiReadSlave    => axiReadSlave
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

   U_Vc64CmdMaster : entity work.Vc64CmdMaster
      generic map (
         TPD_G              => 1 ns,
         XIL_DEVICE_G       => "7SERIES",
         USE_BUILT_IN_G     => true,
         ALTERA_SYN_G       => false,
         ALTERA_RAM_G       => "M9K",
         BRAM_EN_G          => true,
         GEN_SYNC_FIFO_G    => false,
         FIFO_SYNC_STAGES_G => 3,
         FIFO_ADDR_WIDTH_G  => 9,
         FIFO_AFULL_THRES_G => 255,
         LITTLE_ENDIAN_G    => true,
         VC_WIDTH_G         => 16
      ) port map (
         vcRxData        => pgpRxVcData(0),
         vcRxCtrl        => pgpRxVcCtrl(0),
         vcRxClk         => pgpClk,
         vcRxRst         => pgpClkRst,
         cmdClk          => axiClk,
         cmdClkRst       => axiClkRst,
         cmdMasterOut    => cmdMasterOut
      );

end tb;

