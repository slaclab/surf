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

   component Pgp3GtyUsIpFec
      port (
         tx_clk                           : in  std_logic;
         tx_resetn                        : in  std_logic;
         rx_clk                           : in  std_logic;
         rx_resetn                        : in  std_logic;
         consortium_25g                   : in  std_logic;
         tx_pcs_data                      : in  std_logic_vector(65 downto 0);
         rx_pcs_data                      : out std_logic_vector(65 downto 0);
         rx_serdes_data                   : in  std_logic_vector(65 downto 0);
         tx_serdes_data                   : out std_logic_vector(65 downto 0);
         tx_cwm_flag                      : in  std_logic;
         rx_cwm_flag                      : out std_logic;
         fec_bypass_correction_enable     : in  std_logic;
         fec_bypass_indication_enable     : in  std_logic;
         fec_enable                       : in  std_logic;
         fec_ieee_error_indication_enable : in  std_logic;
         rx_hi_ser                        : out std_logic;
         rx_corrected_cw_inc              : out std_logic;
         rx_uncorrected_cw_inc            : out std_logic;
         rx_cw_inc                        : out std_logic;
         rx_symbol_error_count_inc        : out std_logic_vector(2 downto 0);
         tx_align_status                  : out std_logic;
         rx_align_status                  : out std_logic;
         rx_ts_1588_in                    : in  std_logic_vector(79 downto 0);
         rx_ts_1588_out                   : out std_logic_vector(79 downto 0)
         );
   end component;

   constant TPD_C : time := 3 ns;

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

   signal txFecCw  : sl := '0';
   signal txData   : slv(63 downto 0);
   signal txHeader : slv(1 downto 0);

   signal rxFecCw  : sl := '0';
   signal rxData   : slv(63 downto 0);
   signal rxHeader : slv(1 downto 0);

   signal fecTxCw         : sl               := '0';
   signal fecTxPcsData    : slv(65 downto 0) := (others => '0');
   signal fecTxSerdesData : slv(65 downto 0) := (others => '0');

   signal fecRxCw         : sl               := '0';
   signal fecRxPcsData    : slv(65 downto 0) := (others => '0');
   signal fecRxSerdesData : slv(65 downto 0) := (others => '0');

   signal txDataInt   : slv(63 downto 0) := (others => '0');
   signal txHeaderInt : slv(1 downto 0)  := (others => '0');

   signal rxDataInt   : slv(63 downto 0) := (others => '0');
   signal rxHeaderInt : slv(1 downto 0)  := (others => '0');

   signal fecTxAligned     : sl              := '0';
   signal fecRxAligned     : sl              := '0';
   signal fecRxCorrected   : sl              := '0';
   signal fecRxUnCorrected : sl              := '0';
   signal fecRxCwInc       : sl              := '0';
   signal fecRxErrCnt      : slv(2 downto 0) := (others => '0');

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
         TPD_G            => TPD_C,
         NUM_VC_G         => 1,
         HIGH_BANDWIDTH_G => true,
         PGP_FEC_ENABLE_G => true,
         EN_PGP_MON_G     => false)
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

   U_FEC : Pgp3GtyUsIpFec
      port map (
         -- Clocks and resets
         tx_clk                           => pgpClk,
         tx_resetn                        => pgpRstL,
         rx_clk                           => pgpClk,
         rx_resetn                        => pgpRstL,
         -- PCS Interface Data
         tx_pcs_data                      => fecTxPcsData,
         rx_pcs_data                      => fecRxPcsData,
         -- PMA Interface Data
         tx_serdes_data                   => fecTxSerdesData,
         -- rx_serdes_data                   => fecRxSerdesData,
         rx_serdes_data                   => fecTxSerdesData,
         -- Broadside control and status bus
         fec_bypass_correction_enable     => '1',
         fec_bypass_indication_enable     => '0',
         fec_enable                       => '1',
         fec_ieee_error_indication_enable => '0',
         consortium_25g                   => '0',
         -- hi_ser
         rx_hi_ser                        => open,
         -- alignment status
         tx_align_status                  => fecTxAligned,
         rx_align_status                  => fecRxAligned,
         -- correction flags
         rx_corrected_cw_inc              => fecRxCorrected,
         rx_uncorrected_cw_inc            => fecRxUnCorrected,
         rx_cw_inc                        => fecRxCwInc,
         rx_symbol_error_count_inc        => fecRxErrCnt,
         -- alginment flags to and from the XXVMAC
         tx_cwm_flag                      => fecTxCw,
         rx_cwm_flag                      => fecRxCw,
         rx_ts_1588_in                    => x"00000000000000000000",
         rx_ts_1588_out                   => open);

   process(pgpClk)
   begin
      if rising_edge(pgpClk) then

         fecTxCw                   <= txFecCw;
         fecTxPcsData(65 downto 2) <= txData;

         fecTxPcsData(1 downto 0) <= bitReverse(txHeader);

         txDataInt   <= bitReverse(fecTxSerdesData(65 downto 2));
         txHeaderInt <= bitReverse(fecTxSerdesData(1 downto 0));

      end if;
   end process;

   rxDataInt   <= txDataInt;
   rxHeaderInt <= txHeaderInt;

   process(pgpClk)
   begin
      if rising_edge(pgpClk) then

         fecRxSerdesData(65 downto 2) <= bitReverse(rxDataInt)   after TPD_C;
         fecRxSerdesData(1 downto 0)  <= bitReverse(rxHeaderInt) after TPD_C;

         rxFecCw  <= fecRxCw                              after TPD_C;
         rxData   <= fecRxPcsData(65 downto 2)            after TPD_C;
         rxHeader <= bitReverse(fecRxPcsData(1 downto 0)) after TPD_C;


         -- rxFecCw  <= txFecCw  after TPD_C;
         -- rxData   <= txData   after TPD_C;
         -- rxHeader <= txHeader after TPD_C;         

      end if;
   end process;

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
