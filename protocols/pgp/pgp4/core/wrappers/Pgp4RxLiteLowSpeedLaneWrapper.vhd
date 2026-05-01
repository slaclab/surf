-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for surf.Pgp4RxLiteLowSpeedLane
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.Pgp4Pkg.all;

entity Pgp4RxLiteLowSpeedLaneWrapper is
   port (
      clk     : in  sl;
      rst     : in  sl;
      txValid : in  sl;
      txReady : out sl;
      txData  : in  slv(63 downto 0);
      txSof   : in  sl;
      txEof   : in  sl;
      txEofe  : in  sl;
      locked  : out sl;
      bitSlip : out sl;
      dlyLoad : out sl;
      dlyCfg  : out slv(8 downto 0);
      rxValid : out sl;
      rxLast  : out sl;
      rxData  : out slv(63 downto 0);
      rxDest  : out slv(7 downto 0);
      rxUser  : out slv(15 downto 0));
end entity Pgp4RxLiteLowSpeedLaneWrapper;

architecture rtl of Pgp4RxLiteLowSpeedLaneWrapper is

   signal pgpTxIn     : Pgp4TxInType        := PGP4_TX_IN_INIT_C;
   signal pgpTxMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal pgpTxSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal phyTxValid  : sl;
   signal phyTxData   : slv(63 downto 0);
   signal phyTxHeader : slv(1 downto 0);
   signal serWord     : slv(65 downto 0);
   signal deserData   : slv(7 downto 0);
   signal rxMaster    : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;

begin

   txReady <= pgpTxSlave.tReady;

   pgpTxIn.disable     <= '0';
   pgpTxIn.flowCntlDis <= '1';
   pgpTxIn.resetTx     <= '0';
   pgpTxIn.skpInterval <= (others => '0');
   pgpTxIn.opCodeEn    <= '0';
   pgpTxIn.opCodeData  <= (others => '0');
   pgpTxIn.locData     <= (others => '0');

   pgpTxMaster.tValid             <= txValid;
   pgpTxMaster.tData(63 downto 0) <= txData;
   pgpTxMaster.tKeep(7 downto 0)  <= X"FF";
   pgpTxMaster.tStrb(7 downto 0)  <= X"FF";
   pgpTxMaster.tLast              <= txEof;
   pgpTxMaster.tUser(1)           <= txSof;
   pgpTxMaster.tUser(14)          <= txEofe;

   serWord(63 downto 0)  <= phyTxData;
   serWord(65 downto 64) <= phyTxHeader;

   rxValid <= rxMaster.tValid;
   rxLast  <= rxMaster.tLast;
   rxData  <= rxMaster.tData(63 downto 0);
   rxDest  <= rxMaster.tDest(7 downto 0);
   rxUser  <= rxMaster.tUser(15 downto 0);

   U_TX : entity surf.Pgp4TxLite
      generic map (
         NUM_VC_G         => 1,
         PGP_COMMON_CLK_G => true,
         SKIP_EN_G        => false,
         FLOW_CTRL_EN_G   => false)
      port map (
         pgpTxClk        => clk,
         pgpTxRst        => rst,
         pgpTxIn         => pgpTxIn,
         pgpTxOut        => open,
         pgpTxActive     => '1',
         pgpTxMasters(0) => pgpTxMaster,
         pgpTxSlaves(0)  => pgpTxSlave,
         phyTxActive     => '1',
         phyTxReady      => '1',
         phyTxValid      => phyTxValid,
         phyTxStart      => open,
         phyTxData       => phyTxData,
         phyTxHeader     => phyTxHeader);

   U_Serializer : entity surf.Gearbox
      generic map (
         SLAVE_WIDTH_G  => 66,
         MASTER_WIDTH_G => 8)
      port map (
         clk         => clk,
         rst         => rst,
         slaveData   => serWord,
         slaveValid  => phyTxValid,
         slaveReady  => open,
         masterData  => deserData,
         masterValid => open,
         masterReady => '1');

   U_DUT : entity surf.Pgp4RxLiteLowSpeedLane
      generic map (
         SIMULATION_G       => true,
         STATUS_CNT_WIDTH_G => 8,
         ERROR_CNT_WIDTH_G  => 4,
         AXIL_CLK_FREQ_G    => 100.0E+6)
      port map (
         deserClk        => clk,
         deserRst        => rst,
         deserData       => deserData,
         dlyLoad         => dlyLoad,
         dlyCfg          => dlyCfg,
         enUsrDlyCfg     => '1',
         usrDlyCfg       => (others => '0'),
         minEyeWidth     => x"01",
         lockingCntCfg   => x"00_0004",
         bypFirstBerDet  => '1',
         polarity        => '0',
         bitOrder        => (others => '0'),
         errorDet        => open,
         bitSlip         => bitSlip,
         eyeWidth        => open,
         locked          => locked,
         pgpRxMaster     => rxMaster,
         axilClk         => clk,
         axilRst         => rst,
         axilReadMaster  => AXI_LITE_READ_MASTER_INIT_C,
         axilReadSlave   => open,
         axilWriteMaster => AXI_LITE_WRITE_MASTER_INIT_C,
         axilWriteSlave  => open);

end architecture rtl;
