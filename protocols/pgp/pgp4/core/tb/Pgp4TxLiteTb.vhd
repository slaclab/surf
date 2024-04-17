-------------------------------------------------------------------------------
-- Title      : PGPv4: https://confluence.slac.stanford.edu/x/1dzgEQ
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Pgp4Lite Testbed
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

entity Pgp4TxLiteTb is

end entity Pgp4TxLiteTb;

architecture testbed of Pgp4TxLiteTb is

   constant TPD_C : time := 1 ns;

   constant PGP_CLK_PERIOD_C : time := 7 ns;
   constant LOC_CLK_PERIOD_C : time := 11 ns;

   constant TX_PACKET_LENGTH_C : slv(31 downto 0) := toSlv(256, 32);
   constant NUMBER_PACKET_C    : slv(31 downto 0) := x"000000FF";

   constant PRBS_SEED_SIZE_C : positive := 8*PGP4_AXIS_CONFIG_C.TDATA_BYTES_C;

   signal pgpTxIn : Pgp4TxInType := (
      disable     => '0',               -- TX is enabled
      flowCntlDis => '1',  -- Disable PGPv4 pause flow control from RX side
      resetTx     => '0',               -- Not resetting TX
      skpInterval => (others => '0'),  -- No skips (assumes clock source synchronous system)
      opCodeEn    => '0',               -- OP-code mode not being implemented
      opCodeData  => (others => '0'),
      locData     => (others => '0'));  -- sideband locData not being implemented
   signal pgpRxOut : Pgp4RxOutType;

   signal pgpTxMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal pgpTxSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

   signal phyData   : slv(63 downto 0);
   signal phyHeader : slv(1 downto 0);

   signal pgpRxMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;

   signal passed   : sl := '0';
   signal failed   : sl := '0';
   signal updated  : sl := '0';
   signal errorDet : sl := '0';
   signal cnt      : slv(31 downto 0);

   signal pgpClk : sl := '0';
   signal pgpRst : sl := '1';

   signal locClk : sl := '0';
   signal locRst : sl := '1';

begin

   U_pgpClkRst : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => PGP_CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1 us)     -- Hold reset for this long)
      port map (
         clkP => pgpClk,
         rst  => pgpRst);

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
         mAxisClk     => pgpClk,
         mAxisRst     => pgpRst,
         mAxisMaster  => pgpTxMaster,
         mAxisSlave   => pgpTxSlave,
         -- Trigger Signal (locClk domain)
         locClk       => locClk,
         locRst       => locRst,
         trig         => pgpRxOut.linkReady,
         packetLength => TX_PACKET_LENGTH_C);

   U_Pgp4TxLite : entity surf.Pgp4TxLite
      generic map (
         TPD_G          => TPD_C,
         NUM_VC_G       => 1,
         SKIP_EN_G      => false,
         FLOW_CTRL_EN_G => false)
      port map (
         -- Transmit interface
         pgpTxClk        => pgpClk,
         pgpTxRst        => pgpRst,
         pgpTxIn         => pgpTxIn,
         pgpTxOut        => open,
         pgpTxActive     => '1',
         pgpTxMasters(0) => pgpTxMaster,
         pgpTxSlaves(0)  => pgpTxSlave,
         -- PHY interface
         phyTxActive     => '1',
         phyTxReady      => '1',
         phyTxData       => phyData,
         phyTxHeader     => phyHeader);

   U_Pgp4Rx : entity surf.Pgp4Rx
      generic map (
         TPD_G    => TPD_C,
         NUM_VC_G => 1)
      port map (
         -- User Transmit interface
         pgpRxClk        => pgpClk,
         pgpRxRst        => pgpRst,
         pgpRxMasters(0) => pgpRxMaster,
         pgpRxCtrl(0)    => AXI_STREAM_CTRL_UNUSED_C,
         pgpRxIn         => PGP4_RX_IN_INIT_C,
         pgpRxOut        => pgpRxOut,
         -- Phy interface
         phyRxClk        => pgpClk,
         phyRxRst        => pgpRst,
         phyRxActive     => '1',
         phyRxStartSeq   => '0',
         phyRxValid      => '1',
         phyRxData       => phyData,
         phyRxHeader     => phyHeader);

   U_SsiPrbsRx : entity surf.SsiPrbsRx
      generic map (
         TPD_G                     => TPD_C,
         PRBS_SEED_SIZE_G          => PRBS_SEED_SIZE_C,
         SLAVE_READY_EN_G          => false,
         SLAVE_AXI_STREAM_CONFIG_G => PGP4_AXIS_CONFIG_C)
      port map (
         -- Streaming RX Data Interface (sAxisClk domain)
         sAxisClk       => pgpClk,
         sAxisRst       => pgpRst,
         sAxisMaster    => pgpRxMaster,
         -- Error Detection Signals (sAxisClk domain)
         updatedResults => updated,
         errorDet       => errorDet);

   process(pgpClk)
   begin
      if rising_edge(pgpClk) then
         if pgpRst = '1' then
            cnt    <= (others => '0') after TPD_C;
            passed <= '0'             after TPD_C;
            failed <= '0'             after TPD_C;
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
            report "Simulation Passed!" severity failure;
      end if;
   end process;

end testbed;
