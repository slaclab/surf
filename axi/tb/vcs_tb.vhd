-------------------------------------------------------------------------------
-- File       : vcs_tb.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-05-02
-- Last update: 2016-09-06
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for VCS module
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
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.SsiCmdMasterPkg.all;
use work.Pgp2bPkg.all;
use work.I2cPkg.all;

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
   signal cmdMaster         : SsiCmdMasterType;
   signal pgpRxCtrl         : AxiStreamCtrlArray(3 downto 0);
   signal i2cRegMasterIn    : I2cRegMasterInType;
   signal i2cRegMasterOut   : I2cRegMasterOutType;
   signal i2ci              : i2c_in_type;
   signal i2co              : i2c_out_type;

   constant I2C_CONFIG_ENTRY_C : I2cAxiLiteDevType := (
      i2cAddress => "0000100111",
      i2cTenbit  => '0',
      dataSize   => 8,
      endianness => '0'
   );

   constant I2C_CONFIG_C : I2cAxiLiteDevArray(0 downto 0) := (
      0 => I2C_CONFIG_ENTRY_C
   );

   constant PGP_LANE_CNT_C   : integer := 1;

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
         TPD_G             => 1 ns,
         LANE_CNT_G        => PGP_LANE_CNT_C
      ) port map ( 
         pgpTxClk          => pgpClk,
         pgpTxClkRst       => pgpClkRst,
         pgpTxIn           => PGP2B_TX_IN_INIT_C,
         pgpTxOut          => open,
         pgpTxMasters      => pgpTxMasters,
         pgpTxSlaves       => pgpTxSlaves,
         pgpRxClk          => pgpClk,
         pgpRxClkRst       => pgpClkRst,
         pgpRxIn           => PGP2B_RX_IN_INIT_C,
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
         USE_BUILT_IN_G      => false,
         ALTERA_SYN_G        => false,
         ALTERA_RAM_G        => "M9K",
         BRAM_EN_G           => true,
         GEN_SYNC_FIFO_G     => false,
         FIFO_ADDR_WIDTH_G   => 9,
         FIFO_PAUSE_THRESH_G => 255,
         AXI_STREAM_CONFIG_G => SSI_PGP2B_CONFIG_C
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


--   U_I2c : entity work.I2cRegMasterAxiBridge
--      generic map (
--         TPD_G               => 1 ns,
--         I2C_REG_ADDR_SIZE_G => 8,
--         DEVICE_MAP_G        => I2C_CONFIG_C,
--         EN_USER_REG_G       => false,
--         NUM_WRITE_REG_G     => 1,
--         NUM_READ_REG_G      => 1,
--         AXI_ERROR_RESP_G    => AXI_RESP_SLVERR_C
--      ) port map (
--         axiClk           => axiClk,
--         axiRst           => axiClkRst,
--         axiReadMaster    => axiReadMaster,
--         axiReadSlave     => axiReadSlave,
--         axiWriteMaster   => axiWriteMaster,
--         axiWriteSlave    => axiWriteSlave,
--         i2cRegMasterIn   => i2cRegMasterIn,
--         i2cRegMasterOut  => i2cRegMasterOut 
--      );
--
--   U_I2cMaster : entity work.I2cRegMaster 
--      generic map (
--         TPD_G                => 1 ns,
--         OUTPUT_EN_POLARITY_G => 1,
--         FILTER_G             => 8,
--         PRESCALE_G           => 62
--      ) port map (
--         clk    => axiClk,
--         srst   => axiClkRst,
--         regIn  => i2cRegMasterIn,
--         regOut => i2cRegMasterOut,
--         i2ci   => i2ci,
--         i2co   => i2co
--   );

   i2ci.scl <= i2co.scl when i2co.scloen = '1' else '1';
   i2ci.sda <= i2co.sda when i2co.sdaoen = '1' else '1';

   U_CmdMaster : entity work.SsiCmdMaster 
      generic map (
         TPD_G               => 1 ns,
         XIL_DEVICE_G        => "7SERIES",
         USE_BUILT_IN_G      => false,
         ALTERA_SYN_G        => false,
         ALTERA_RAM_G        => "M9K",
         BRAM_EN_G           => true,
         GEN_SYNC_FIFO_G     => false,
         FIFO_ADDR_WIDTH_G   => 9,
         FIFO_PAUSE_THRESH_G => 255,
         AXI_STREAM_CONFIG_G => SSI_PGP2B_CONFIG_C
      ) port map (
         axisClk       => pgpClk,
         axisRst       => pgpClkRst,
         sAxisMaster   => pgpRxMasters(0),
         sAxisSlave    => open,
         sAxisCtrl     => pgpRxCtrl(0),
         cmdClk        => axiClk,
         cmdRst        => axiClkRst,
         cmdMaster     => cmdMaster
      );

end vcs_tb;

