-------------------------------------------------------------------------------
-- Title      : PGPv4: https://confluence.slac.stanford.edu/x/1dzgEQ
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation PGPv4 + FEC Testbed
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;
use surf.Pgp4Pkg.all;


entity Pgp4FecTb is

end entity Pgp4FecTb;

architecture testbed of Pgp4FecTb is

   constant TPD_C : time := 1 ns;

   constant PGP_CLK_PERIOD_C : time := 4 ns;
   constant LOC_CLK_PERIOD_C : time := 4 ns;

   constant TX_PACKET_LENGTH_C : slv(31 downto 0) := toSlv(128, 32);
   constant NUMBER_PACKET_C    : slv(31 downto 0) := x"000000FF";

   constant PRBS_SEED_SIZE_C : positive := 8*PGP4_AXIS_CONFIG_C.TDATA_BYTES_C;

   signal pgpTxIn     : Pgp4TxInType        := PGP4_TX_IN_INIT_C;
   signal pgpTxOut    : Pgp4TxOutType;
   signal pgpTxMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal pgpTxSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

   signal pgpRxIn     : Pgp4RxInType        := PGP4_RX_IN_INIT_C;
   signal pgpRxOut    : Pgp4RxOutType;
   signal pgpRxMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal pgpRxCtrl   : AxiStreamCtrlType   := AXI_STREAM_CTRL_INIT_C;

   signal rxMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal rxSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

   signal passed     : sl := '0';
   signal failed     : sl := '0';
   signal frameRxErr : sl := '0';
   signal updated    : sl := '0';
   signal errorDet   : sl := '0';
   signal cnt        : slv(31 downto 0);

   signal pgpClk  : sl := '0';
   signal pgpRst  : sl := '1';
   signal pgpRstL : sl := '0';

   signal locClk : sl := '0';
   signal locRst : sl := '1';

   signal txFecCw     : sl := '0';
   signal txHeader    : slv(1 downto 0);
   signal txData      : slv(63 downto 0);
   signal txFecLock   : sl := '0';
   signal txFecInjErr : sl := '0';

   signal loopbackHeader : slv(1 downto 0);
   signal loopbackData   : slv(63 downto 0);

   signal rxFecCw       : sl              := '0';
   signal rxHeader      : slv(1 downto 0);
   signal rxData        : slv(63 downto 0);
   signal rxFecLock     : sl              := '0';
   signal rxFecCorInc   : sl              := '0';
   signal rxFecUnCorInc : sl              := '0';
   signal rxFecCwInc    : sl              := '0';
   signal rxFecErrCnt   : slv(2 downto 0) := (others => '0');

begin

   U_pgpClkRst : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => PGP_CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1 us)     -- Hold reset for this long)
      port map (
         clkP => pgpClk,
         rst  => pgpRst,
         rstL => pgpRstL);

   U_locClkRst : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => LOC_CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1 us)     -- Hold reset for this long)
      port map (
         clkP => locClk,
         rst  => locRst);

   U_SsiPrbsTx : entity surf.SsiPrbsTx
      generic map (
         TPD_G                      => TPD_C,
         PRBS_SEED_SIZE_G           => PRBS_SEED_SIZE_C,
         AXI_EN_G                   => '0',
         MASTER_AXI_STREAM_CONFIG_G => PGP4_AXIS_CONFIG_C)
      port map (
         -- Master Port (mAxisClk)
         mAxisClk    => pgpClk,
         mAxisRst    => pgpRst,
         mAxisMaster => pgpTxMaster,
         mAxisSlave  => pgpTxSlave,
         -- Trigger Signal (locClk domain)
         locClk      => pgpClk,
         locRst      => pgpRst,



         -- trig         => pgpRxOut.linkReady,
         trig => '0',


         packetLength => TX_PACKET_LENGTH_C);

   U_DUT : entity surf.Pgp4Core
      generic map (
         TPD_G             => TPD_C,
         NUM_VC_G          => 1,
         PGP_FEC_ENABLE_G  => true,
         RX_CRC_PIPELINE_G => 1,
         EN_PGP_MON_G      => false)
      port map (
         -- Tx User interface
         pgpTxClk        => pgpClk,
         pgpTxRst        => pgpRst,
         pgpTxIn         => pgpTxIn,
         pgpTxOut        => pgpTxOut,
         pgpTxMasters(0) => pgpTxMaster,
         pgpTxSlaves(0)  => pgpTxSlave,
         -- Tx PHY interface
         phyTxActive     => '1',
         phyTxReady      => '1',
         phyTxValid      => open,
         phyTxData       => txData,
         phyTxHeader     => txHeader,
         phyTxFecCw      => txFecCw,
         -- Rx User interface
         pgpRxClk        => pgpClk,
         pgpRxRst        => pgpRst,
         pgpRxIn         => pgpRxIn,
         pgpRxOut        => pgpRxOut,
         pgpRxMasters(0) => pgpRxMaster,
         pgpRxCtrl(0)    => pgpRxCtrl,
         -- Rx PHY interface
         phyRxClk        => pgpClk,
         phyRxRst        => pgpRst,
         phyRxActive     => '1',
         phyRxStartSeq   => '0',
         phyRxValid      => '1',
         phyRxFecCw      => rxFecCw,
         phyRxData       => rxData,
         phyRxHeader     => rxHeader);

   U_FEC : entity surf.Pgp4GtyUsIpFecWrapper
      generic map (
         TPD_G => TPD_C)
      port map (
         -- TX Interface
         txClk         => pgpClk,
         txRstL        => pgpRstL,
         txFecCw       => txFecCw,
         txHeaderIn    => txHeader,
         txDataIn      => txData,
         txHeaderOut   => loopbackHeader,
         txDataOut     => loopbackData,
         txFecInjErr   => txFecInjErr,
         txFecLock     => txFecLock,
         -- RX Interface
         rxClk         => pgpClk,
         rxRstL        => pgpRstL,
         rxFecCw       => rxFecCw,
         rxHeaderIn    => loopbackHeader,
         rxDataIn      => loopbackData,
         rxHeaderOut   => rxHeader,
         rxDataOut     => rxData,
         rxFecLock     => rxFecLock,
         rxFecCorInc   => rxFecCorInc,
         rxFecUnCorInc => rxFecUnCorInc,
         rxFecCwInc    => rxFecCwInc,
         rxFecErrCnt   => rxFecErrCnt);

   U_Rx_Fifo : entity surf.PgpRxVcFifo
      generic map (
         TPD_G               => TPD_C,
         GEN_SYNC_FIFO_G     => false,
         FIFO_ADDR_WIDTH_G   => 9,
         FIFO_PAUSE_THRESH_G => 128,
         PHY_AXI_CONFIG_G    => PGP4_AXIS_CONFIG_C,
         APP_AXI_CONFIG_G    => PGP4_AXIS_CONFIG_C)
      port map (
         -- Slave Port
         pgpClk      => pgpClk,
         pgpRst      => pgpRst,
         rxlinkReady => pgpRxOut.linkReady,
         pgpRxMaster => pgpRxMaster,
         pgpRxCtrl   => pgpRxCtrl,
         -- Master Port
         axisClk     => locClk,
         axisRst     => locRst,
         axisMaster  => rxMaster,
         axisSlave   => rxSlave);

   U_SsiPrbsRx : entity surf.SsiPrbsRx
      generic map (
         TPD_G                     => TPD_C,
         PRBS_SEED_SIZE_G          => PRBS_SEED_SIZE_C,
         SLAVE_READY_EN_G          => true,
         SLAVE_AXI_STREAM_CONFIG_G => PGP4_AXIS_CONFIG_C)
      port map (
         -- Streaming RX Data Interface (sAxisClk domain)
         sAxisClk       => locClk,
         sAxisRst       => locRst,
         sAxisMaster    => rxMaster,
         sAxisSlave     => rxSlave,
         -- Error Detection Signals (sAxisClk domain)
         updatedResults => updated,
         errorDet       => errorDet);

   U_frameRxErr : entity surf.SynchronizerOneShot
      generic map (
         TPD_G => TPD_C)
      port map (
         clk     => locClk,
         dataIn  => pgpRxOut.frameRxErr,
         dataOut => frameRxErr);

   process(locClk)
   begin
      if rising_edge(locClk) then
         if locRst = '1' then
            cnt    <= (others => '0') after TPD_C;
            passed <= '0'             after TPD_C;
            failed <= '0'             after TPD_C;
         elsif frameRxErr = '1' then
            failed <= '1' after TPD_C;
         elsif updated = '1' then
            -- Check for packet error
            if errorDet = '1' then
               failed <= '1' after TPD_C;
            end if;
            -- Check the counter
            if cnt = NUMBER_PACKET_C then
               passed <= '1' after TPD_C;
            else
               -- Increment the counter
               cnt <= cnt + 1 after TPD_C;
            end if;
         end if;
      end if;
   end process;

   process(failed, passed)
   begin
      if failed = '1' then
         assert false
            report "Simulation Failed!" severity failure;
      end if;
      if passed = '1' then
         assert false
            report "Simulation Passed!" severity note;
      end if;
   end process;

end testbed;
