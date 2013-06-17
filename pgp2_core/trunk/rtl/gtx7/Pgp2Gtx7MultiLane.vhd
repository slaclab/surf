-------------------------------------------------------------------------------
-- Title			  : Pretty Good Protocol, V2, GTX7 Wrapper
-- Project		  : General Purpose Core
-------------------------------------------------------------------------------
-- File			  : Pgp2Gtx7MultiLane.vhd
-- Author		  : Larry Ruckman, ruckman@slac.stanford.edu
-- Created		  : 06/16/2013
-------------------------------------------------------------------------------
-- Description:
-- VHDL source file containing the PGP, GTX7 and CRC blocks.
-------------------------------------------------------------------------------
-- Copyright (c) 2013 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 06/16/2013: created.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.Pgp2CoreTypesPkg.all;
use work.StdRtlPkg.all;

library UNISIM;
use UNISIM.VCOMPONENTS.all;

entity Pgp2Gtx7MultiLane is
	generic (
		TPD_G						 : time						:= 1 ns;
		----------------------------------------------------------------------------------------------
		-- GT Settings
		----------------------------------------------------------------------------------------------
		-- Sim Generics
		SIM_GTRESET_SPEEDUP_G : string					:= "TRUE";
		SIM_VERSION_G			 : string					:= "4.0";
		STABLE_CLOCK_PERIOD_G : time						:= 6.4 ns;
		-- CPLL Settings
		CPLL_REFCLK_SEL_G		 : bit_vector				:= "001";
		CPLL_FBDIV_G			 : integer					:= 4;
		CPLL_FBDIV_45_G		 : integer					:= 5;
		CPLL_REFCLK_DIV_G		 : integer					:= 1;
		RXOUT_DIV_G				 : integer					:= 2;
		TXOUT_DIV_G				 : integer					:= 2;
		-- Configure PLL sources
		TX_PLL_G					 : string					:= "CPLL";
		RX_PLL_G					 : string					:= "QPLL";
		-- Configure Number of Lanes
		LANE_CNT_G				 : integer range 1 to 4 := 2;
		----------------------------------------------------------------------------------------------
		-- PGP Settings
		----------------------------------------------------------------------------------------------
		PayloadCntTop			 : integer					:= 7;		-- Top bit for payload counter
		EnShortCells			 : integer					:= 1;		-- Enable short non-EOF cells
		VcInterleave			 : integer					:= 1);	-- Interleave Frames
	port (
		-- GT Clocking
		stableClk		  : in  sl;										-- GT needs a stable clock to "boot up"
		gtCPllRefClk	  : in  sl;										-- Drives CPLL if used
		gtQPllRefClk	  : in  sl;										-- Signals from QPLL if used
		gtQPllClk		  : in  sl;
		gtQPllLock		  : in  sl;
		gtQPllRefClkLost : in  sl;
		gtQPllReset		  : out sl;
		-- Gt Serial IO
		gtTxP				  : out slv((LANE_CNT_G-1) downto 0);	-- GT Serial Transmit Positive
		gtTxN				  : out slv((LANE_CNT_G-1) downto 0);	-- GT Serial Transmit Negative
		gtRxP				  : in  slv((LANE_CNT_G-1) downto 0);	-- GT Serial Receive Positive
		gtRxN				  : in  slv((LANE_CNT_G-1) downto 0);	-- GT Serial Receive Negative
		-- Tx Clocking
		pgpTxReset		  : in  sl;
		pgpTxClk			  : in  sl;
		pgpTxMmcmReset	  : out sl;
		pgpTxMmcmLocked  : in  sl;
		-- Rx clocking
		pgpRxReset		  : in  sl;
		pgpRxClk			  : in  sl;
		pgpRxMmcmReset	  : out sl;
		pgpRxMmcmLocked  : in  sl;
		-- Non VC Rx Signals
		pgpRxIn			  : in  PgpRxInType;
		pgpRxOut			  : out PgpRxOutType;
		-- Non VC Tx Signals
		pgpTxIn			  : in  PgpTxInType;
		pgpTxOut			  : out PgpTxOutType;
		-- Frame Transmit Interface - Array of 4 VCs
		pgpTxVcQuadIn	  : in  PgpTxVcQuadInType;
		pgpTxVcQuadOut	  : out PgpTxVcQuadOutType;
		-- Frame Receive Interface - Array of 4 VCs
		pgpRxVcCommonOut : out PgpRxVcCommonOutType;
		pgpRxVcQuadOut	  : out PgpRxVcQuadOutType;
		-- GT loopback control
		loopback			  : in  slv(2 downto 0);
		-- Debug
		debug				  : out slv(63 downto 0));

end Pgp2Gtx7MultiLane;

-- Define architecture
architecture rtl of Pgp2Gtx7MultiLane is
	--------------------------------------------------------------------------------------------------
	-- Constants
	--------------------------------------------------------------------------------------------------
	constant RX_SYSCLK_SEL_C : slv := ite(RX_PLL_G = "CPLL", "00", "11");
	constant TX_SYSCLK_SEL_C : slv := ite(TX_PLL_G = "CPLL", "00", "11");

	--------------------------------------------------------------------------------------------------
	-- Types
	--------------------------------------------------------------------------------------------------
	type GtxType is record
		--CPLL Signals
		cPllLock			 : sl;
		cPllRefClkLost	 : sl;
		cPllReset		 : sl;
		rxPllLock		 : sl;
		rxPllRefClkLost : sl;
		rxPllReset		 : sl;
		txPllLock		 : sl;
		txPllRefClkLost : sl;
		txPllReset		 : sl;
		--RX Signals
		rxData			 : slv(63 downto 0);
		rxCharIsK		 : slv(7 downto 0);
		rxDispErr		 : slv(7 downto 0);
		rxDecErr			 : slv(7 downto 0);
		rxUserRdy		 : sl;
		rxResetDone		 : sl;
		rxDfeAgcHold	 : sl;
		rxDfeLfHold		 : sl;
		rxLpmHfHold		 : sl;
		rxLpmLfHold		 : sl;
		rxFsmResetDone	 : sl;
		gtRxReset		 : sl;
		--TX Signals
		txData			 : slv(63 downto 0);
		txCharIsK		 : slv(7 downto 0);
		txUserRdy		 : sl;
		txResetDone		 : sl;
		txFsmResetDone	 : sl;
		gtTxReset		 : sl;
		--Channel Bonding Signals
		rxChBondLevel	 : slv(2 downto 0);
		rxChBondIn		 : slv(4 downto 0);
		rxChBondOut		 : slv(4 downto 0);
	end record;

	type	 GtxTypeArray is array (natural range <>) of GtxType;
	--------------------------------------------------------------------------------------------------
	-- Signals
	--------------------------------------------------------------------------------------------------
	-- GTX Interface
	signal gtx : GtxTypeArray((LANE_CNT_G-1) downto 0);

	-- Gtx QPLL and CPLL
	signal gtGRefClk			: sl;
	signal gtNorthRefClk0	: sl;
	signal gtNorthRefClk1	: sl;
	signal gtRefClk0			: sl;
	signal gtRefClk1			: sl;
	signal gtSouthRefClk0	: sl;
	signal gtSouthRefClk1	: sl;
	signal gtx_qPllResetOut : slv((LANE_CNT_G-1) downto 0);

	-- PgpRx Signals
	signal gtx_pgpRxMmcmReset : slv((LANE_CNT_G-1) downto 0);
	signal gtx_gtRxResetDone  : slv((LANE_CNT_G-1) downto 0);
	signal gtRxUserReset		  : sl;
	signal gtRxResetDone		  : sl;
	signal phyRxLanesIn		  : PgpRxPhyLaneInArray((LANE_CNT_G-1) downto 0);
	signal phyRxLanesOut		  : PgpRxPhyLaneOutArray((LANE_CNT_G-1) downto 0);
	signal phyRxReady			  : sl;
	signal phyRxInit			  : sl;
	signal crcRxIn				  : PgpCrcInType;
	signal crcRxOut			  : slv(31 downto 0);

	-- CRC Rx IO (PgpRxPhy CRC IO must be adapted to V5 GT CRCs)
	signal crcRxWidthGtx7 : slv(2 downto 0);
	signal crcRxRstGtx7	 : sl;
	signal crcRxInGtx7	 : slv(31 downto 0);
	signal crcRxOutGtx7	 : slv(31 downto 0);

	-- PgpTx Signals
	signal gtx_pgpTxMmcmReset : slv((LANE_CNT_G-1) downto 0);
	signal gtx_gtTxResetDone  : slv((LANE_CNT_G-1) downto 0);
	signal gtTxResetDone		  : sl;
	signal phyTxLanesOut		  : PgpTxPhyLaneOutArray((LANE_CNT_G-1) downto 0);
	signal phyTxReady			  : sl;
	signal crcTxIn				  : PgpCrcInType;
	signal crcTxOut			  : slv(31 downto 0);

	-- CRC Tx IO (PgpTxPhy CRC IO must be adapted to K7 GT CRCs)
	signal crcTxWidthGtx7 : slv(2 downto 0);
	signal crcTxRstGtx7	 : sl;
	signal crcTxInGtx7	 : slv(31 downto 0);
	signal crcTxOutGtx7	 : slv(31 downto 0);

begin
	debug				<= (others => '0');
	gtQPllReset		<= uOr(gtx_qPllResetOut);
	pgpTxMmcmReset <= uOr(gtx_pgpTxMmcmReset);
	pgpRxMmcmReset <= uOr(gtx_pgpRxMmcmReset);
	gtTxResetDone	<= uAnd(gtx_gtTxResetDone);
	gtRxResetDone	<= uAnd(gtx_gtRxResetDone);

	-- PGP RX Block
	Pgp2RxWrapper_1 : entity work.Pgp2RxWrapper
		generic map (
			RxLaneCnt	  => LANE_CNT_G,
			EnShortCells  => EnShortCells,
			PayloadCntTop => PayloadCntTop)
		port map (
			pgpRxClk			  => pgpRxClk,
			pgpRxReset		  => pgpRxReset,
			pgpRxIn			  => pgpRxIn,
			pgpRxOut			  => pgpRxOut,
			pgpRxVcCommonOut => pgpRxVcCommonOut,
			pgpRxVcQuadOut	  => pgpRxVcQuadOut,
			phyRxLanesOut	  => phyRxLanesOut,
			phyRxLanesIn	  => phyRxLanesIn,
			phyRxReady		  => gtRxResetDone,
			phyRxInit		  => gtRxUserReset,
			crcRxIn			  => crcRxIn,
			crcRxOut			  => crcRxOut,
			debug				  => open);

	-- RX CRC BLock
	crcRxRstGtx7				  <= pgpRxReset or crcRxIn.init or not gtRxResetDone;
	crcRxInGtx7(31 downto 24) <= crcRxIn.crcIn(7 downto 0);
	crcRxInGtx7(23 downto 16) <= crcRxIn.crcIn(15 downto 8);
	CRC_RX_1xLANE : if LANE_CNT_G = 1 generate
		crcRxWidthGtx7				 <= "001";
		crcRxInGtx7(15 downto 0) <= (others => '0');
	end generate CRC_RX_1xLANE;
	CRC_RX_2xLANE : if LANE_CNT_G = 2 generate
		crcRxWidthGtx7				 <= "011";
		crcRxInGtx7(15 downto 8) <= crcRxIn.crcIn(23 downto 16);
		crcRxInGtx7(7 downto 0)	 <= crcRxIn.crcIn(31 downto 24);
	end generate CRC_RX_2xLANE;
	CRC_RX_3xLANE : if LANE_CNT_G = 3 generate
		crcRxWidthGtx7				 <= "011";
		crcRxInGtx7(15 downto 8) <= crcRxIn.crcIn(23 downto 16);
		crcRxInGtx7(7 downto 0)	 <= crcRxIn.crcIn(31 downto 24);
	end generate CRC_RX_3xLANE;
	CRC_RX_4xLANE : if LANE_CNT_G = 4 generate
		crcRxWidthGtx7				 <= "011";
		crcRxInGtx7(15 downto 8) <= crcRxIn.crcIn(23 downto 16);
		crcRxInGtx7(7 downto 0)	 <= crcRxIn.crcIn(31 downto 24);
	end generate CRC_RX_4xLANE;
	crcRxOut <= not crcRxOutGtx7;

	Rx_CRC : entity work.CRC32_V7
		generic map(
			CRC_INIT => x"FFFFFFFF")
		port map(
			CRCOUT		 => crcRxOutGtx7,
			CRCCLK		 => pgpRxClk,
			CRCDATAVALID => crcRxIn.valid,
			CRCDATAWIDTH => crcRxWidthGtx7,
			CRCIN			 => crcRxInGtx7,
			CRCRESET		 => crcRxRstGtx7);

	-- PGP TX Block
	Pgp2TxWrapper_1 : entity work.Pgp2TxWrapper
		generic map (
			TxLaneCnt	  => LANE_CNT_G,
			VcInterleave  => VcInterleave,
			PayloadCntTop => PayloadCntTop)
		port map (
			pgpTxClk			=> pgpTxClk,
			pgpTxReset		=> pgpTxReset,
			pgpTxIn			=> pgpTxIn,
			pgpTxOut			=> pgpTxOut,
			pgpTxVcQuadIn	=> pgpTxVcQuadIn,
			pgpTxVcQuadOut => pgpTxVcQuadOut,
			phyTxLanesOut	=> phyTxLanesOut,
			phyTxReady		=> gtTxResetDone,
			crcTxIn			=> crcTxIn,
			crcTxOut			=> crcTxOut,
			debug				=> open);

	-- TX CRC BLock
	crcTxRstGtx7				  <= pgpTxReset or crcTxIn.init;
	crcTxInGtx7(31 downto 24) <= crcTxIn.crcIn(7 downto 0);
	crcTxInGtx7(23 downto 16) <= crcTxIn.crcIn(15 downto 8);
	CRC_TX_1xLANE : if LANE_CNT_G = 1 generate
		crcTxWidthGtx7				 <= "001";
		crcTxInGtx7(15 downto 0) <= (others => '0');
	end generate CRC_TX_1xLANE;
	CRC_TX_2xLANE : if LANE_CNT_G = 2 generate
		crcTxWidthGtx7				 <= "011";
		crcTxInGtx7(15 downto 8) <= crcTxIn.crcIn(23 downto 16);
		crcTxInGtx7(7 downto 0)	 <= crcTxIn.crcIn(31 downto 24);
	end generate CRC_TX_2xLANE;
	CRC_TX_3xLANE : if LANE_CNT_G = 3 generate
		crcTxWidthGtx7				 <= "011";
		crcTxInGtx7(15 downto 8) <= crcTxIn.crcIn(23 downto 16);
		crcTxInGtx7(7 downto 0)	 <= crcTxIn.crcIn(31 downto 24);
	end generate CRC_TX_3xLANE;
	CRC_TX_4xLANE : if LANE_CNT_G = 4 generate
		crcTxWidthGtx7				 <= "011";
		crcTxInGtx7(15 downto 8) <= crcTxIn.crcIn(23 downto 16);
		crcTxInGtx7(7 downto 0)	 <= crcTxIn.crcIn(31 downto 24);
	end generate CRC_TX_4xLANE;
	crcTxOut <= not crcTxOutGtx7;

	Tx_CRC : entity work.CRC32_V7
		generic map(
			CRC_INIT => x"FFFFFFFF")
		port map(
			CRCOUT		 => crcTxOutGtx7,
			CRCCLK		 => pgpTxClk,
			CRCDATAVALID => crcTxIn.valid,
			CRCDATAWIDTH => crcTxWidthGtx7,
			CRCIN			 => crcTxInGtx7,
			CRCRESET		 => crcTxRstGtx7);

	--------------------------------------------------------------------------------------------------
	-- CPLL clock select. Only ever use 1 clock to drive cpll. Never switch clocks.
	--------------------------------------------------------------------------------------------------
	gtRefClk0		<= gtCPllRefClk when CPLL_REFCLK_SEL_G = "001" else '0';
	gtRefClk1		<= gtCPllRefClk when CPLL_REFCLK_SEL_G = "010" else '0';
	gtNorthRefClk0 <= gtCPllRefClk when CPLL_REFCLK_SEL_G = "011" else '0';
	gtNorthRefClk1 <= gtCPllRefClk when CPLL_REFCLK_SEL_G = "100" else '0';
	gtSouthRefClk0 <= gtCPllRefClk when CPLL_REFCLK_SEL_G = "101" else '0';
	gtSouthRefClk1 <= gtCPllRefClk when CPLL_REFCLK_SEL_G = "110" else '0';
	gtGRefClk		<= gtCPllRefClk when CPLL_REFCLK_SEL_G = "111" else '0';

	--------------------------------------------------------------------------------------------------
	-- Generate the GTX channels
	--------------------------------------------------------------------------------------------------
	GEN_GTXE2_CHANNEL :
	for i in (LANE_CNT_G-1) downto 0 generate
		--TX mapping
		gtx(i).txData(63 downto 16)  <= (others => '0');
		gtx(i).txData(15 downto 0)	  <= phyTxLanesOut(i).data;
		gtx(i).txCharIsK(7 downto 2) <= (others => '0');
		gtx(i).txCharIsK(1 downto 0) <= phyTxLanesOut(i).dataK;
		--RX mapping
		phyRxLanesIn(i).data			  <= gtx(i).rxData(15 downto 0);
		phyRxLanesIn(i).dataK		  <= gtx(i).rxCharIsK(1 downto 0);
		phyRxLanesIn(i).decErr		  <= gtx(i).rxDispErr(1 downto 0);
		phyRxLanesIn(i).dispErr		  <= gtx(i).rxDecErr(1 downto 0);
		-- TX PLL
		gtx(i).txPllLock				  <= gtx(i).cPllLock			when (TX_PLL_G = "CPLL") else gtQPllLock when (TX_PLL_G = "QPLL") else '0';
		gtx(i).txPllRefClkLost		  <= gtx(i).cPllRefClkLost when (TX_PLL_G = "CPLL") else gtQPllRefClkLost when (TX_PLL_G = "QPLL") else '0';
		-- RX PLL
		gtx(i).rxPllLock				  <= gtx(i).cPllLock			when (RX_PLL_G = "CPLL") else gtQPllLock when (RX_PLL_G = "QPLL") else '0';
		gtx(i).rxPllRefClkLost		  <= gtx(i).cPllRefClkLost when (RX_PLL_G = "CPLL") else gtQPllRefClkLost when (RX_PLL_G = "QPLL") else '0';
		-- PLL Resets
		gtx(i).cPllReset				  <= gtx(i).txPllReset		when (TX_PLL_G = "CPLL") else gtx(i).rxPllReset when (RX_PLL_G = "CPLL") else '0';
		gtx_qPllResetOut(i)			  <= gtx(i).txPllReset		when (TX_PLL_G = "QPLL") else gtx(i).rxPllReset when (RX_PLL_G = "QPLL") else '0';
		-- Channel Bonding
		gtx(i).rxChBondLevel			  <= conv_std_logic_vector((LANE_CNT_G-1-i), 3);
		Bond_Master : if (i = 0) generate
			gtx(i).rxChBondIn <= "00000";
		end generate Bond_Master;
		Bond_Slaves : if (i /= 0) generate
			gtx(i).rxChBondIn <= gtx(i-1).rxChBondOut;
		end generate Bond_Slaves;
		--------------------------------------------------------------------------------------------------
		-- Tx Reset Module
		--------------------------------------------------------------------------------------------------
		Gtx7TxRst_Inst : entity work.Gtx7TxRst
			generic map (
				TPD_G						  => TPD_G,
				GT_TYPE					  => "GTX",
				STABLE_CLOCK_PERIOD	  => integer(STABLE_CLOCK_PERIOD_G/1 ns),
				RETRY_COUNTER_BITWIDTH => 8)
			port map (
				STABLE_CLOCK		=> stableClk,
				TXUSERCLK			=> pgpTxClk,
				SOFT_RESET			=> pgpTxReset,
				PLLREFCLKLOST		=> gtx(i).txPllRefClkLost,
				PLLLOCK				=> gtx(i).txPllLock,
				TXRESETDONE			=> gtx(i).txResetDone,
				MMCM_LOCK			=> pgpTxMmcmLocked,
				GTTXRESET			=> gtx(i).gtTxReset,
				MMCM_RESET			=> gtx_pgpTxMmcmReset(i),
				PLL_RESET			=> gtx(i).txPllReset,
				TX_FSM_RESET_DONE => gtx(i).txFsmResetDone,
				TXUSERRDY			=> gtx(i).txUserRdy,
				RUN_PHALIGNMENT	=> open,
				RESET_PHALIGNMENT => open,
				PHALIGNMENT_DONE	=> '1',
				RETRY_COUNTER		=> open);

		--------------------------------------------------------------------------------------------------
		-- Synchronize rxFsmResetDone to rxUsrClk to use as reset for external logic.
		--------------------------------------------------------------------------------------------------
		RstSync_Tx : entity work.RstSync
			generic map (
				TPD_G				=> TPD_G,
				IN_POLARITY_G	=> '0',
				OUT_POLARITY_G => '0')
			port map (
				clk		=> pgpTxClk,
				asyncRst => gtx(i).txFsmResetDone,
				syncRst	=> gtx_gtTxResetDone(i));			

		--------------------------------------------------------------------------------------------------
		-- Rx Reset Module
		-- 1. Reset RX PLL,
		-- 2. Wait PLL Lock
		-- 3. Wait recclk_stable
		-- 4. Reset MMCM
		-- 5. Wait MMCM Lock
		-- 6. Assert gtRxUserRdy (gtRxUsrClk now usable)
		-- 7. Wait gtRxResetDone
		-- 8. Do phase alignment if necessary
		-- 9. Wait DATA_VALID (aligned) - 100 us
		--10. Wait 1 us, Set rxFsmResetDone. 
		--------------------------------------------------------------------------------------------------
		Gtx7RxRst_Inst : entity work.Gtx7RxRst
			generic map (
				TPD_G						  => TPD_G,
				EXAMPLE_SIMULATION	  => 0,
				GT_TYPE					  => "GTX",
				EQ_MODE					  => "DFE",
				STABLE_CLOCK_PERIOD	  => integer(STABLE_CLOCK_PERIOD_G/1 ns),
				RETRY_COUNTER_BITWIDTH => 8)
			port map (
				STABLE_CLOCK			  => stableClk,
				RXUSERCLK				  => pgpRxClk,
				SOFT_RESET				  => gtRxUserReset,
				PLLREFCLKLOST			  => gtx(i).rxPllRefClkLost,
				PLLLOCK					  => gtx(i).rxPllLock,
				RXRESETDONE				  => gtx(i).rxResetDone,
				MMCM_LOCK				  => pgpRxMmcmLocked,
				RECCLK_STABLE			  => '1',
				RECCLK_MONITOR_RESTART => '0',
				DATA_VALID				  => '1',
				TXUSERRDY				  => gtx(i).txUserRdy,
				GTRXRESET				  => gtx(i).gtRxReset,
				MMCM_RESET				  => gtx_pgpRxMmcmReset(i),
				PLL_RESET				  => gtx(i).rxPllReset,
				RX_FSM_RESET_DONE		  => gtx(i).rxFsmResetDone,
				RXUSERRDY				  => gtx(i).rxUserRdy,
				RUN_PHALIGNMENT		  => open,
				PHALIGNMENT_DONE		  => '1',
				RESET_PHALIGNMENT		  => open,
				RXDFEAGCHOLD			  => gtx(i).rxDfeAgcHold,
				RXDFELFHOLD				  => gtx(i).rxDfeLfHold,
				RXLPMLFHOLD				  => gtx(i).rxLpmLfHold,
				RXLPMHFHOLD				  => gtx(i).rxLpmHfHold,
				RETRY_COUNTER			  => open);

		--------------------------------------------------------------------------------------------------
		-- Synchronize rxFsmResetDone to rxUsrClk to use as reset for external logic.
		--------------------------------------------------------------------------------------------------
		RstSync_RxResetDone : entity work.RstSync
			generic map (
				TPD_G				=> TPD_G,
				IN_POLARITY_G	=> '0',
				OUT_POLARITY_G => '0')
			port map (
				clk		=> pgpRxClk,
				asyncRst => gtx(i).rxFsmResetDone,
				syncRst	=> gtx_gtRxResetDone(i));		 

		--------------------------------------------------------------------------------------------------
		-- GTX Instantiation
		--------------------------------------------------------------------------------------------------
		gtxe2_i : GTXE2_CHANNEL
			generic map(
				--_______________________ Simulation-Only Attributes ___________________
				SIM_RECEIVER_DETECT_PASS	  => ("TRUE"),
				SIM_RESET_SPEEDUP				  => (SIM_GTRESET_SPEEDUP_G),
				SIM_TX_EIDLE_DRIVE_LEVEL	  => ("X"),
				SIM_CPLLREFCLK_SEL			  => (CPLL_REFCLK_SEL_G),
				SIM_VERSION						  => (SIM_VERSION_G),
				------------------RX Byte and Word Alignment Attributes---------------
				ALIGN_COMMA_DOUBLE			  => ("FALSE"),
				ALIGN_COMMA_ENABLE			  => ("1111111111"),
				ALIGN_COMMA_WORD				  => (2),
				ALIGN_MCOMMA_DET				  => ("TRUE"),
				ALIGN_MCOMMA_VALUE			  => ("1010000011"),
				ALIGN_PCOMMA_DET				  => ("TRUE"),
				ALIGN_PCOMMA_VALUE			  => ("0101111100"),
				SHOW_REALIGN_COMMA			  => ("TRUE"),	 --maybe "FALSE"
				RXSLIDE_AUTO_WAIT				  => (7),
				RXSLIDE_MODE					  => ("OFF"),	 --maybe "AUTO"
				RX_SIG_VALID_DLY				  => (10),
				------------------RX 8B/10B Decoder Attributes---------------
				RX_DISPERR_SEQ_MATCH			  => ("TRUE"),
				DEC_MCOMMA_DETECT				  => ("TRUE"),
				DEC_PCOMMA_DETECT				  => ("TRUE"),
				DEC_VALID_COMMA_ONLY			  => ("FALSE"),
				------------------------RX Clock Correction Attributes----------------------
				CBCC_DATA_SOURCE_SEL			  => ("DECODED"),
				CLK_COR_SEQ_2_USE				  => ("FALSE"),
				CLK_COR_KEEP_IDLE				  => ("FALSE"),
				CLK_COR_MAX_LAT				  => (48),
				CLK_COR_MIN_LAT				  => (36),
				CLK_COR_PRECEDENCE			  => ("TRUE"),
				CLK_COR_REPEAT_WAIT			  => (0),
				CLK_COR_SEQ_LEN				  => (4),
				CLK_COR_SEQ_1_ENABLE			  => ("1111"),
				CLK_COR_SEQ_1_1				  => ("0110111100"),
				CLK_COR_SEQ_1_2				  => ("0100011100"),
				CLK_COR_SEQ_1_3				  => ("0100011100"),
				CLK_COR_SEQ_1_4				  => ("0100011100"),
				CLK_CORRECT_USE				  => ("TRUE"),
				CLK_COR_SEQ_2_ENABLE			  => ("0000"),
				CLK_COR_SEQ_2_1				  => ("0000000000"),
				CLK_COR_SEQ_2_2				  => ("0000000000"),
				CLK_COR_SEQ_2_3				  => ("0000000000"),
				CLK_COR_SEQ_2_4				  => ("0000000000"),
				------------------------RX Channel Bonding Attributes----------------------
				CHAN_BOND_KEEP_ALIGN			  => ("FALSE"),
				CHAN_BOND_MAX_SKEW			  => (10),
				CHAN_BOND_SEQ_LEN				  => (1),
				CHAN_BOND_SEQ_1_1				  => ("0110111100"),
				CHAN_BOND_SEQ_1_2				  => ("0111011100"),
				CHAN_BOND_SEQ_1_3				  => ("0111011100"),
				CHAN_BOND_SEQ_1_4				  => ("0111011100"),
				CHAN_BOND_SEQ_1_ENABLE		  => ("1111"),
				CHAN_BOND_SEQ_2_1				  => ("0000000000"),
				CHAN_BOND_SEQ_2_2				  => ("0000000000"),
				CHAN_BOND_SEQ_2_3				  => ("0000000000"),
				CHAN_BOND_SEQ_2_4				  => ("0000000000"),
				CHAN_BOND_SEQ_2_ENABLE		  => ("0000"),
				CHAN_BOND_SEQ_2_USE			  => ("FALSE"),
				FTS_DESKEW_SEQ_ENABLE		  => ("1111"),
				FTS_LANE_DESKEW_CFG			  => ("1111"),
				FTS_LANE_DESKEW_EN			  => ("FALSE"),
				---------------------------RX Margin Analysis Attributes----------------------------
				ES_CONTROL						  => ("000000"),
				ES_ERRDET_EN					  => ("FALSE"),
				ES_EYE_SCAN_EN					  => ("TRUE"),
				ES_HORZ_OFFSET					  => (x"000"),
				ES_PMA_CFG						  => ("0000000000"),
				ES_PRESCALE						  => ("00000"),
				ES_QUALIFIER					  => (x"00000000000000000000"),
				ES_QUAL_MASK					  => (x"00000000000000000000"),
				ES_SDATA_MASK					  => (x"00000000000000000000"),
				ES_VERT_OFFSET					  => ("000000000"),
				-------------------------FPGA RX Interface Attributes-------------------------
				RX_DATA_WIDTH					  => (20),
				---------------------------PMA Attributes----------------------------
				OUTREFCLK_SEL_INV				  => ("11"),
				PMA_RSV							  => x"00018480",
				PMA_RSV2							  => (x"2050"),
				PMA_RSV3							  => ("00"),
				PMA_RSV4							  => (x"00000000"),
				RX_BIAS_CFG						  => ("000000000100"),
				DMONITOR_CFG					  => (x"000A00"),
				RX_CM_SEL						  => ("11"),
				RX_CM_TRIM						  => ("010"),
				RX_DEBUG_CFG					  => ("000000000000"),
				RX_OS_CFG						  => ("0000010000000"),
				TERM_RCAL_CFG					  => ("10000"),
				TERM_RCAL_OVRD					  => ('0'),
				TST_RSV							  => (x"00000000"),
				RX_CLK25_DIV					  => (7),
				TX_CLK25_DIV					  => (7),
				UCODEER_CLR						  => ('0'),
				---------------------------PCI Express Attributes----------------------------
				PCS_PCIE_EN						  => ("FALSE"),
				---------------------------PCS Attributes----------------------------
				PCS_RSVD_ATTR					  => (x"000000000000"),
				-------------RX Buffer Attributes------------
				RXBUF_ADDR_MODE				  => ("FULL"),
				RXBUF_EIDLE_HI_CNT			  => ("1000"),
				RXBUF_EIDLE_LO_CNT			  => ("0000"),
				RXBUF_EN							  => ("TRUE"),
				RX_BUFFER_CFG					  => ("000000"),
				RXBUF_RESET_ON_CB_CHANGE	  => ("TRUE"),
				RXBUF_RESET_ON_COMMAALIGN	  => ("FALSE"),
				RXBUF_RESET_ON_EIDLE			  => ("FALSE"),
				RXBUF_RESET_ON_RATE_CHANGE	  => ("TRUE"),
				RXBUFRESET_TIME				  => ("00001"),
				RXBUF_THRESH_OVFLW			  => (61),
				RXBUF_THRESH_OVRD				  => ("FALSE"),
				RXBUF_THRESH_UNDFLW			  => (4),
				RXDLY_CFG						  => (x"001F"),
				RXDLY_LCFG						  => (x"030"),
				RXDLY_TAP_CFG					  => (x"0000"),
				RXPH_CFG							  => (x"000000"),
				RXPHDLY_CFG						  => (x"084020"),
				RXPH_MONITOR_SEL				  => ("00000"),
				RX_XCLK_SEL						  => ("RXREC"),
				RX_DDI_SEL						  => ("000000"),
				RX_DEFER_RESET_BUF_EN		  => ("TRUE"),
				-----------------------CDR Attributes-------------------------
				RXCDR_CFG						  => (x"03000023ff40200020"),
				RXCDR_FR_RESET_ON_EIDLE		  => ('0'),
				RXCDR_HOLD_DURING_EIDLE		  => ('0'),
				RXCDR_PH_RESET_ON_EIDLE		  => ('0'),
				RXCDR_LOCK_CFG					  => ("010101"),
				-------------------RX Initialization and Reset Attributes-------------------
				RXCDRFREQRESET_TIME			  => ("00001"),
				RXCDRPHRESET_TIME				  => ("00001"),
				RXISCANRESET_TIME				  => ("00001"),
				RXPCSRESET_TIME				  => ("00001"),
				RXPMARESET_TIME				  => ("00011"),
				-------------------RX OOB Signaling Attributes-------------------
				RXOOB_CFG						  => ("0000110"),
				-------------------------RX Gearbox Attributes---------------------------
				RXGEARBOX_EN					  => ("FALSE"),
				GEARBOX_MODE					  => ("000"),
				-------------------------PRBS Detection Attribute-----------------------
				RXPRBS_ERR_LOOPBACK			  => ('0'),
				-------------Power-Down Attributes----------
				PD_TRANS_TIME_FROM_P2		  => (x"03c"),
				PD_TRANS_TIME_NONE_P2		  => (x"19"),
				PD_TRANS_TIME_TO_P2			  => (x"64"),
				-------------RX OOB Signaling Attributes----------
				SAS_MAX_COM						  => (64),
				SAS_MIN_COM						  => (36),
				SATA_BURST_SEQ_LEN			  => ("1111"),
				SATA_BURST_VAL					  => ("100"),
				SATA_EIDLE_VAL					  => ("100"),
				SATA_MAX_BURST					  => (8),
				SATA_MAX_INIT					  => (21),
				SATA_MAX_WAKE					  => (7),
				SATA_MIN_BURST					  => (4),
				SATA_MIN_INIT					  => (12),
				SATA_MIN_WAKE					  => (4),
				-------------RX Fabric Clock Output Control Attributes----------
				TRANS_TIME_RATE				  => (x"0E"),
				--------------TX Buffer Attributes----------------
				TXBUF_EN							  => ("TRUE"),
				TXBUF_RESET_ON_RATE_CHANGE	  => ("TRUE"),
				TXDLY_CFG						  => (x"001F"),
				TXDLY_LCFG						  => (x"030"),
				TXDLY_TAP_CFG					  => (x"0000"),
				TXPH_CFG							  => (x"0780"),
				TXPHDLY_CFG						  => (x"084020"),
				TXPH_MONITOR_SEL				  => ("00000"),
				TX_XCLK_SEL						  => ("TXOUT"),
				-------------------------FPGA TX Interface Attributes-------------------------
				TX_DATA_WIDTH					  => (20),
				-------------------------TX Configurable Driver Attributes-------------------------
				TX_DEEMPH0						  => ("00000"),
				TX_DEEMPH1						  => ("00000"),
				TX_EIDLE_ASSERT_DELAY		  => ("110"),
				TX_EIDLE_DEASSERT_DELAY		  => ("100"),
				TX_LOOPBACK_DRIVE_HIZ		  => ("FALSE"),
				TX_MAINCURSOR_SEL				  => ('0'),
				TX_DRIVE_MODE					  => ("DIRECT"),
				TX_MARGIN_FULL_0				  => ("1001110"),
				TX_MARGIN_FULL_1				  => ("1001001"),
				TX_MARGIN_FULL_2				  => ("1000101"),
				TX_MARGIN_FULL_3				  => ("1000010"),
				TX_MARGIN_FULL_4				  => ("1000000"),
				TX_MARGIN_LOW_0				  => ("1000110"),
				TX_MARGIN_LOW_1				  => ("1000100"),
				TX_MARGIN_LOW_2				  => ("1000010"),
				TX_MARGIN_LOW_3				  => ("1000000"),
				TX_MARGIN_LOW_4				  => ("1000000"),
				-------------------------TX Gearbox Attributes--------------------------
				TXGEARBOX_EN					  => ("FALSE"),
				-------------------------TX Initialization and Reset Attributes--------------------------
				TXPCSRESET_TIME				  => ("00001"),
				TXPMARESET_TIME				  => ("00001"),
				-------------------------TX Receiver Detection Attributes--------------------------
				TX_RXDETECT_CFG				  => (x"1832"),
				TX_RXDETECT_REF				  => ("100"),
				----------------------------CPLL Attributes----------------------------
				CPLL_CFG							  => (x"BC07DC"),
				CPLL_FBDIV						  => (CPLL_FBDIV_G),
				CPLL_FBDIV_45					  => (CPLL_FBDIV_45_G),
				CPLL_INIT_CFG					  => (x"00001E"),
				CPLL_LOCK_CFG					  => (x"01E8"),
				CPLL_REFCLK_DIV				  => (CPLL_REFCLK_DIV_G),
				RXOUT_DIV						  => (RXOUT_DIV_G),
				TXOUT_DIV						  => (TXOUT_DIV_G),
				SATA_CPLL_CFG					  => ("VCO_3000MHZ"),
				--------------RX Initialization and Reset Attributes-------------
				RXDFELPMRESET_TIME			  => ("0001111"),
				--------------RX Equalizer Attributes-------------
				RXLPM_HF_CFG					  => ("00000011110000"),
				RXLPM_LF_CFG					  => ("00000011110000"),
				RX_DFE_GAIN_CFG				  => (x"020FEA"),
				RX_DFE_H2_CFG					  => ("000000000000"),
				RX_DFE_H3_CFG					  => ("000001000000"),
				RX_DFE_H4_CFG					  => ("00011110000"),
				RX_DFE_H5_CFG					  => ("00011100000"),
				RX_DFE_KL_CFG					  => ("0000011111110"),
				RX_DFE_LPM_CFG					  => (x"0954"),
				RX_DFE_LPM_HOLD_DURING_EIDLE => ('0'),
				RX_DFE_UT_CFG					  => ("10001111000000000"),
				RX_DFE_VP_CFG					  => ("00011111100000011"),
				-------------------------Power-Down Attributes-------------------------
				RX_CLKMUX_PD					  => ('1'),
				TX_CLKMUX_PD					  => ('1'),
				-------------------------FPGA RX Interface Attribute-------------------------
				RX_INT_DATAWIDTH				  => (0),
				-------------------------FPGA TX Interface Attribute-------------------------
				TX_INT_DATAWIDTH				  => (0),
				------------------TX Configurable Driver Attributes---------------
				TX_QPI_STATUS_EN				  => ('0'),
				-------------------------RX Equalizer Attributes--------------------------
				RX_DFE_KL_CFG2					  => (x"3010D90C"),
				RX_DFE_XYD_CFG					  => ("0000000000000"),
				-------------------------TX Configurable Driver Attributes--------------------------
				TX_PREDRIVER_MODE				  => ('0'))
			port map(
				--------------------------------- CPLL Ports -------------------------------
				CPLLFBCLKLOST	  => open,
				CPLLLOCK			  => gtx(i).cPllLock,
				CPLLLOCKDETCLK	  => stableClk,
				CPLLLOCKEN		  => '1',
				CPLLPD			  => '0',
				CPLLREFCLKLOST	  => gtx(i).cPllRefClkLost,
				CPLLREFCLKSEL	  => to_stdlogicvector(CPLL_REFCLK_SEL_G),
				CPLLRESET		  => gtx(i).cPllReset,
				GTRSVD			  => "0000000000000000",
				PCSRSVDIN		  => "0000000000000000",
				PCSRSVDIN2		  => "00000",
				PMARSVDIN		  => "00000",
				PMARSVDIN2		  => "00000",
				TSTIN				  => "11111111111111111111",
				TSTOUT			  => open,
				---------------------------------- Channel ---------------------------------
				CLKRSVD			  => "0000",
				-------------------------- Channel - Clocking Ports ------------------------
				GTGREFCLK		  => gtGRefClk,
				GTNORTHREFCLK0	  => gtNorthRefClk0,
				GTNORTHREFCLK1	  => gtNorthRefClk1,
				GTREFCLK0		  => gtRefClk0,
				GTREFCLK1		  => gtRefClk1,
				GTSOUTHREFCLK0	  => gtSouthRefClk0,
				GTSOUTHREFCLK1	  => gtSouthRefClk1,
				---------------------------- Channel - DRP Ports  --------------------------
				DRPADDR			  => (others => '0'),
				DRPCLK			  => '0',
				DRPDI				  => x"0000",
				DRPDO				  => open,
				DRPEN				  => '0',
				DRPRDY			  => open,
				DRPWE				  => '0',
				------------------------------- Clocking Ports -----------------------------
				GTREFCLKMONITOR  => open,
				QPLLCLK			  => gtQPllClk,
				QPLLREFCLK		  => gtQPllRefClk,
				RXSYSCLKSEL		  => RX_SYSCLK_SEL_C,
				TXSYSCLKSEL		  => TX_SYSCLK_SEL_C,
				--------------------------- Digital Monitor Ports --------------------------
				DMONITOROUT		  => open,
				----------------- FPGA TX Interface Datapath Configuration	----------------
				TX8B10BEN		  => '1',
				------------------------------- Loopback Ports -----------------------------
				LOOPBACK			  => loopback,
				----------------------------- PCI Express Ports ----------------------------
				PHYSTATUS		  => open,
				RXRATE			  => "000",
				RXVALID			  => open,
				------------------------------ Power-Down Ports ----------------------------
				RXPD				  => "00",
				TXPD				  => "00",
				-------------------------- RX 8B/10B Decoder Ports -------------------------
				SETERRSTATUS	  => '0',
				--------------------- RX Initialization and Reset Ports --------------------
				EYESCANRESET	  => '0',
				RXUSERRDY		  => gtx(i).rxUserRdy,
				-------------------------- RX Margin Analysis Ports ------------------------
				EYESCANDATAERROR => open,
				EYESCANMODE		  => '0',
				EYESCANTRIGGER	  => '0',
				------------------------- Receive Ports - CDR Ports ------------------------
				RXCDRFREQRESET	  => '0',
				RXCDRHOLD		  => '0',
				RXCDRLOCK		  => open,
				RXCDROVRDEN		  => '0',
				RXCDRRESET		  => '0',
				RXCDRRESETRSV	  => '0',
				------------------- Receive Ports - Clock Correction Ports -----------------
				RXCLKCORCNT		  => open,
				---------- Receive Ports - FPGA RX Interface Datapath Configuration --------
				RX8B10BEN		  => '1',
				------------------ Receive Ports - FPGA RX Interface Ports -----------------
				RXUSRCLK			  => pgpRxClk,
				RXUSRCLK2		  => pgpRxClk,
				------------------ Receive Ports - FPGA RX interface Ports -----------------
				RXDATA			  => gtx(i).rxData,
				------------------- Receive Ports - Pattern Checker Ports ------------------
				RXPRBSERR		  => open,
				RXPRBSSEL		  => "000",
				------------------- Receive Ports - Pattern Checker ports ------------------
				RXPRBSCNTRESET	  => '0',
				-------------------- Receive Ports - RX  Equalizer Ports -------------------
				RXDFEXYDEN		  => '0',
				RXDFEXYDHOLD	  => '0',
				RXDFEXYDOVRDEN	  => '0',
				------------------ Receive Ports - RX 8B/10B Decoder Ports -----------------
				RXDISPERR		  => gtx(i).rxDispErr,
				RXNOTINTABLE	  => gtx(i).rxDecErr,
				--------------------------- Receive Ports - RX AFE -------------------------
				GTXRXP			  => gtRxP(i),
				------------------------ Receive Ports - RX AFE Ports ----------------------
				GTXRXN			  => gtRxN(i),
				------------------- Receive Ports - RX Buffer Bypass Ports -----------------
				RXBUFRESET		  => '0',
				RXBUFSTATUS		  => open,
				RXDDIEN			  => '0',
				RXDLYBYPASS		  => '1',
				RXDLYEN			  => '0',
				RXDLYOVRDEN		  => '0',
				RXDLYSRESET		  => '0',
				RXDLYSRESETDONE  => open,
				RXPHALIGN		  => '0',
				RXPHALIGNDONE	  => open,
				RXPHALIGNEN		  => '0',
				RXPHDLYPD		  => '0',
				RXPHDLYRESET	  => '0',
				RXPHMONITOR		  => open,
				RXPHOVRDEN		  => '0',
				RXPHSLIPMONITOR  => open,
				RXSTATUS			  => open,
				-------------- Receive Ports - RX Byte and Word Alignment Ports ------------
				RXBYTEISALIGNED  => open,
				RXBYTEREALIGN	  => open,
				RXCOMMADET		  => open,
				RXCOMMADETEN	  => '1',
				RXMCOMMAALIGNEN  => '1',
				RXPCOMMAALIGNEN  => '1',
				------------------ Receive Ports - RX Channel Bonding Ports ----------------
				RXCHANBONDSEQ	  => open,
				RXCHBONDEN		  => '1',
				RXCHBONDLEVEL	  => gtx(i).rxChBondLevel,
				RXCHBONDMASTER	  => ite(i = 0, '1', '0'),
				RXCHBONDO		  => gtx(i).rxChBondOut,
				RXCHBONDSLAVE	  => ite(i = 0, '0', '1'),
				----------------- Receive Ports - RX Channel Bonding Ports	----------------
				RXCHANISALIGNED  => open,
				RXCHANREALIGN	  => open,
				--------------------- Receive Ports - RX Equalizer Ports -------------------
				RXDFEAGCHOLD	  => gtx(i).rxDfeAgcHold,
				RXDFEAGCOVRDEN	  => '0',
				RXDFECM1EN		  => '0',
				RXDFELFHOLD		  => '0',	 --wizard says '0' but maybe gtx(i).rxDfeLfHold
				RXDFELFOVRDEN	  => '1',
				RXDFELPMRESET	  => '0',
				RXDFETAP2HOLD	  => '0',
				RXDFETAP2OVRDEN  => '0',
				RXDFETAP3HOLD	  => '0',
				RXDFETAP3OVRDEN  => '0',
				RXDFETAP4HOLD	  => '0',
				RXDFETAP4OVRDEN  => '0',
				RXDFETAP5HOLD	  => '0',
				RXDFETAP5OVRDEN  => '0',
				RXDFEUTHOLD		  => '0',
				RXDFEUTOVRDEN	  => '0',
				RXDFEVPHOLD		  => '0',
				RXDFEVPOVRDEN	  => '0',
				RXDFEVSEN		  => '0',
				RXLPMLFKLOVRDEN  => '0',
				RXMONITOROUT	  => open,
				RXMONITORSEL	  => "00",
				RXOSHOLD			  => '0',
				RXOSOVRDEN		  => '0',
				--------------------- Receive Ports - RX Equilizer Ports -------------------
				RXLPMHFHOLD		  => '0',	 --wizard says '0' but maybe gtx(i).rxLpmHfHold
				RXLPMHFOVRDEN	  => '0',
				RXLPMLFHOLD		  => '0',	 --wizard says '0' but maybe gtx(i).rxLpmLfHold
				------------ Receive Ports - RX Fabric ClocK Output Control Ports ----------
				RXRATEDONE		  => open,
				--------------- Receive Ports - RX Fabric Output Control Ports -------------
				RXOUTCLK			  => open,
				RXOUTCLKFABRIC	  => open,
				RXOUTCLKPCS		  => open,
				RXOUTCLKSEL		  => "010",
				---------------------- Receive Ports - RX Gearbox Ports --------------------
				RXDATAVALID		  => open,
				RXHEADER			  => open,
				RXHEADERVALID	  => open,
				RXSTARTOFSEQ	  => open,
				--------------------- Receive Ports - RX Gearbox Ports  --------------------
				RXGEARBOXSLIP	  => '0',
				------------- Receive Ports - RX Initialization and Reset Ports ------------
				GTRXRESET		  => gtx(i).gtRxReset,
				RXOOBRESET		  => '0',
				RXPCSRESET		  => '0',
				RXPMARESET		  => '0',
				------------------ Receive Ports - RX Margin Analysis ports ----------------
				RXLPMEN			  => '0',
				------------------- Receive Ports - RX OOB Signaling ports -----------------
				RXCOMSASDET		  => open,
				RXCOMWAKEDET	  => open,
				------------------ Receive Ports - RX OOB Signaling ports  -----------------
				RXCOMINITDET	  => open,
				------------------ Receive Ports - RX OOB signalling Ports -----------------
				RXELECIDLE		  => open,
				RXELECIDLEMODE	  => "11",
				----------------- Receive Ports - RX Polarity Control Ports ----------------
				RXPOLARITY		  => phyRxLanesOut(i).polarity,
				---------------------- Receive Ports - RX gearbox ports --------------------
				RXSLIDE			  => '0',
				------------------- Receive Ports - RX8B/10B Decoder Ports -----------------
				RXCHARISCOMMA	  => open,
				RXCHARISK		  => gtx(i).rxCharIsK,
				------------------ Receive Ports - Rx Channel Bonding Ports ----------------
				RXCHBONDI		  => gtx(i).rxChBondIn,
				-------------- Receive Ports -RX Initialization and Reset Ports ------------
				RXRESETDONE		  => gtx(i).rxResetDone,
				-------------------------------- Rx AFE Ports ------------------------------
				RXQPIEN			  => '0',
				RXQPISENN		  => open,
				RXQPISENP		  => open,
				--------------------------- TX Buffer Bypass Ports -------------------------
				TXPHDLYTSTCLK	  => '0',
				------------------------ TX Configurable Driver Ports ----------------------
				TXPOSTCURSOR	  => "00000",
				TXPOSTCURSORINV  => '0',
				TXPRECURSOR		  => "00000",
				TXPRECURSORINV	  => '0',
				TXQPIBIASEN		  => '0',
				TXQPISTRONGPDOWN => '0',
				TXQPIWEAKPUP	  => '0',
				--------------------- TX Initialization and Reset Ports --------------------
				CFGRESET			  => '0',
				GTTXRESET		  => gtx(i).gtTxReset,
				PCSRSVDOUT		  => open,
				TXUSERRDY		  => gtx(i).txUserRdy,
				---------------------- Transceiver Reset Mode Operation --------------------
				GTRESETSEL		  => '0',
				RESETOVRD		  => '0',
				---------------- Transmit Ports - 8b10b Encoder Control Ports --------------
				TXCHARDISPMODE	  => x"00",
				TXCHARDISPVAL	  => x"00",
				------------------ Transmit Ports - FPGA TX Interface Ports ----------------
				TXUSRCLK			  => pgpTxClk,
				TXUSRCLK2		  => pgpTxClk,
				--------------------- Transmit Ports - PCI Express Ports -------------------
				TXELECIDLE		  => '0',
				TXMARGIN			  => "000",
				TXRATE			  => "000",
				TXSWING			  => '0',
				------------------ Transmit Ports - Pattern Generator Ports ----------------
				TXPRBSFORCEERR	  => '0',
				------------------ Transmit Ports - TX Buffer Bypass Ports -----------------
				TXDLYBYPASS		  => '1',
				TXDLYEN			  => '0',
				TXDLYHOLD		  => '0',
				TXDLYOVRDEN		  => '0',
				TXDLYSRESET		  => '0',
				TXDLYSRESETDONE  => open,
				TXDLYUPDOWN		  => '0',
				TXPHALIGN		  => '0',
				TXPHALIGNDONE	  => open,
				TXPHALIGNEN		  => '0',
				TXPHDLYPD		  => '0',
				TXPHDLYRESET	  => '0',
				TXPHINIT			  => '0',
				TXPHINITDONE	  => open,
				TXPHOVRDEN		  => '0',
				---------------------- Transmit Ports - TX Buffer Ports --------------------
				TXBUFSTATUS		  => open,
				--------------- Transmit Ports - TX Configurable Driver Ports --------------
				TXBUFDIFFCTRL	  => "100",
				TXDEEMPH			  => '0',
				TXDIFFCTRL		  => "1000",
				TXDIFFPD			  => '0',
				TXINHIBIT		  => '0',
				TXMAINCURSOR	  => "0000000",
				TXPISOPD			  => '0',
				------------------ Transmit Ports - TX Data Path interface -----------------
				TXDATA			  => gtx(i).txData,
				---------------- Transmit Ports - TX Driver and OOB signaling --------------
				GTXTXN			  => gtTxN(i),
				GTXTXP			  => gtTxP(i),
				----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
				TXOUTCLK			  => open,
				TXOUTCLKFABRIC	  => open,
				TXOUTCLKPCS		  => open,
				TXOUTCLKSEL		  => "010",
				TXRATEDONE		  => open,
				--------------------- Transmit Ports - TX Gearbox Ports --------------------
				TXCHARISK		  => gtx(i).txCharIsK,
				TXGEARBOXREADY	  => open,
				TXHEADER			  => "000",
				TXSEQUENCE		  => "0000000",
				TXSTARTSEQ		  => '0',
				------------- Transmit Ports - TX Initialization and Reset Ports -----------
				TXPCSRESET		  => '0',
				TXPMARESET		  => '0',
				TXRESETDONE		  => gtx(i).txResetDone,
				------------------ Transmit Ports - TX OOB signalling Ports ----------------
				TXCOMFINISH		  => open,
				TXCOMINIT		  => '0',
				TXCOMSAS			  => '0',
				TXCOMWAKE		  => '0',
				TXPDELECIDLEMODE => '0',
				----------------- Transmit Ports - TX Polarity Control Ports ---------------
				TXPOLARITY		  => '0',
				--------------- Transmit Ports - TX Receiver Detection Ports  --------------
				TXDETECTRX		  => '0',
				------------------ Transmit Ports - TX8b/10b Encoder Ports -----------------
				TX8B10BBYPASS	  => x"00",
				------------------ Transmit Ports - pattern Generator Ports ----------------
				TXPRBSSEL		  => "000",
				----------------------- Tx Configurable Driver	Ports ----------------------
				TXQPISENN		  => open,
				TXQPISENP		  => open);
	end generate GEN_GTXE2_CHANNEL;
end rtl;
