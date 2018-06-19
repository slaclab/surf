-------------------------------------------------------------------------------
-- File       : RoguePgp3Sim.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2018-06-19
-- Last update: 2018-06-19
-------------------------------------------------------------------------------
-- Description: Wrapper on RogueStreamSim to simulate a PGPv3
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.Pgp3Pkg.all;

library unisim;
use unisim.vcomponents.all;

entity RoguePgp3Sim is
   generic (
      TPD_G       : time                   := 1 ns;
      USER_ID_G   : integer range 0 to 100 := 1;
      NUM_VC_EN_G : integer range 1 to 16  := 4);
   port (
      -- GT Ports
      pgpClkP         : in  sl;
      pgpClkN         : in  sl;
      pgpRxP          : in  sl;
      pgpRxN          : in  sl;
      pgpTxP          : out sl                     := '0';
      pgpTxN          : out sl                     := '1';
      -- PGP Clock and Reset
      pgpClk          : out sl;
      pgpRst          : out sl;
      -- TX Interface (pgpClk domain)
      pgpTxIn         : in  Pgp3TxInType           := PGP3_TX_IN_INIT_C;
      pgpTxOut        : out Pgp3TxOutType;
      pgpTxMasters    : in  AxiStreamMasterArray(NUM_VC_EN_G-1 downto 0);
      pgpTxSlaves     : out AxiStreamSlaveArray(NUM_VC_EN_G-1 downto 0);
      -- RX Interface (pgpClk domain)
      pgpRxIn         : in  Pgp3RxInType           := PGP3_RX_IN_INIT_C;
      pgpRxOut        : out Pgp3RxOutType;
      pgpRxMasters    : out AxiStreamMasterArray(NUM_VC_EN_G-1 downto 0);
      pgpRxSlaves     : in  AxiStreamSlaveArray(NUM_VC_EN_G-1 downto 0);
      -- AXI-Lite Register Interface (axilClk domain)
      axilClk         : in  sl                     := '0';  -- Stable Clock
      axilRst         : in  sl                     := '0';
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_EMPTY_OK_C;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_EMPTY_OK_C);
end entity RoguePgp3Sim;

architecture sim of RoguePgp3Sim is

   signal clk : sl := '0';
   signal rst : sl := '1';

   txOut : Pgp3TxOutType := PGP3_TX_OUT_INIT_C;
   rxOut : Pgp3RxOutType := PGP3_RX_OUT_INIT_C;

begin

   pgpClk   <= clk;
   pgpRst   <= rst;
   pgpTxOut <= txOut;
   pgpRxOut <= rxOut;

   U_IBUFDS : IBUFDS
      port map (
         I  => pgpClkP,
         IB => pgpClkN,
         O  => clk);

   PwrUpRst_Inst : entity work.PwrUpRst
      generic map (
         TPD_G          => TPD_G,
         IN_POLARITY_G  => '1',
         OUT_POLARITY_G => '1',
         DURATION_G     => 50)
      port map (
         clk    => clk,
         rstOut => rst);

   GEN_VEC : for i in NUM_VC_EN_G-1 downto 0 generate
      U_PGP_VC : entity work.RogueStreamSimWrap
         generic map (
            TPD_G               => TPD_G,
            DEST_ID_G           => i,
            USER_ID_G           => USER_ID_G,
            COMMON_MASTER_CLK_G => true,
            COMMON_SLAVE_CLK_G  => true,
            AXIS_CONFIG_G       => PGP3_AXIS_CONFIG_C)
         port map (
            clk         => clk,              -- [in]
            rst         => rst,              -- [in]
            sAxisClk    => clk,              -- [in]
            sAxisRst    => rst,              -- [in]
            sAxisMaster => pgpTxMasters(i),  -- [in]
            sAxisSlave  => pgpTxSlaves(i),   -- [out]
            mAxisClk    => clk,              -- [in]
            mAxisRst    => rst,              -- [in]
            mAxisMaster => pgpRxMasters(i),  -- [out]
            mAxisSlave  => pgpRxSlaves(i));  -- [in]
   end generate GEN_VEC;

   txOut.phyTxActive <= '1';
   txOut.linkReady   <= '1';

   rxOut.phyTxActive    <= '1';
   rxOut.linkReady      <= '1';
   rxOut.remRxLinkReady <= '1';

end sim;
