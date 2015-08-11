-------------------------------------------------------------------------------
-- Title      : SLAC Asynchronous Logic Transceiver (SALT)
-------------------------------------------------------------------------------
-- File       : Pgp2bSalt.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-08-10
-- Last update: 2015-08-10
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: PGP wraper for SALT
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.Pgp2bPkg.all;

entity Pgp2bSalt is
   generic (
      TPD_G             : time                 := 1 ns;
      ----------------
      -- SALT Settings
      ----------------
      XIL_DEVICE_G      : string               := "7SERIES";
      RXCLK2X_FREQ_G    : real                 := 200.0;  -- In units of MHz
      IODELAY_GROUP_G   : string               := "SALT_IODELAY_GRP";
      ---------------
      -- PGP Settings
      ---------------
      PGP_RX_ENABLE_G   : boolean              := true;
      PGP_TX_ENABLE_G   : boolean              := true;
      PAYLOAD_CNT_TOP_G : integer              := 7;      -- Top bit for payload counter
      VC_INTERLEAVE_G   : integer              := 1;      -- Interleave Frames
      NUM_VC_EN_G       : integer range 1 to 4 := 4);
   port (
      -- TX Serial Stream
      txP              : out sl;
      txN              : out sl;
      -- RX Serial Stream
      rxP              : in  sl;
      rxN              : in  sl;
      -- Tx Clocking
      pgpTxClk         : in  sl;
      pgpTxRst         : in  sl;
      -- Rx clocking
      pgpRxClk         : in  sl;  -- Equal frequecy of pgpTxClk (independent of pgpTxClk phase)
      pgpRxClk2x       : in  sl;  -- Twice the frequecy of pgpRxClk (independent of pgpRxClk phase)
      pgpRxClk2xInv    : in  sl;        -- Twice the frequecy of pgpRxClk (180 phase of pgpRxClk2x)
      pgpRxRst         : in  sl;
      -- IODELAY Ref. Clock and Reset
      refClk           : in  sl;
      refRst           : in  sl;
      -- Non VC Rx Signals
      pgpRxIn          : in  Pgp2bRxInType;
      pgpRxOut         : out Pgp2bRxOutType;
      -- Non VC Tx Signals
      pgpTxIn          : in  Pgp2bTxInType;
      pgpTxOut         : out Pgp2bTxOutType;
      -- Frame Transmit Interface - Array of 4 VCs
      pgpTxMasters     : in  AxiStreamMasterArray(3 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
      pgpTxSlaves      : out AxiStreamSlaveArray(3 downto 0);
      -- Frame Receive Interface - Array of 4 VCs
      pgpRxMasters     : out AxiStreamMasterArray(3 downto 0);
      pgpRxMasterMuxed : out AxiStreamMasterType;
      pgpRxCtrl        : in  AxiStreamCtrlArray(3 downto 0)   := (others => AXI_STREAM_CTRL_UNUSED_C));
end Pgp2bSalt;

architecture mapping of Pgp2bSalt is

   signal loopback : sl;

   signal pgpTxClkEn    : sl;
   signal phyTxReady    : sl;
   signal phyTxLanesOut : Pgp2bTxPhyLaneOutType;

   signal rxClkEn       : sl;
   signal pgpRxClkEn    : sl;
   signal phyRxReady    : sl;
   signal phyRxInit     : sl;
   signal pgpRxReset    : sl;
   signal phyRxLanesIn  : Pgp2bRxPhyLaneInType;
   signal phyRxLanesOut : Pgp2bRxPhyLaneOutType;

begin

   pgpRxReset <= phyRxInit or pgpRxRst or pgpRxIn.resetRx;
   pgpRxClkEn <= rxClkEn or pgpRxReset or not(phyRxReady);
   loopback   <= uOr(pgpRxIn.loopback);

   U_Pgp2bLane : entity work.Pgp2bLane
      generic map (
         TPD_G             => TPD_G,
         LANE_CNT_G        => 1,
         VC_INTERLEAVE_G   => VC_INTERLEAVE_G,
         PAYLOAD_CNT_TOP_G => PAYLOAD_CNT_TOP_G,
         NUM_VC_EN_G       => NUM_VC_EN_G,
         TX_ENABLE_G       => PGP_TX_ENABLE_G,
         RX_ENABLE_G       => PGP_RX_ENABLE_G) 
      port map (
         pgpTxClkEn       => pgpTxClkEn,
         pgpTxClk         => pgpTxClk,
         pgpTxClkRst      => pgpTxRst,
         pgpTxIn          => pgpTxIn,
         pgpTxOut         => pgpTxOut,
         pgpTxMasters     => pgpTxMasters,
         pgpTxSlaves      => pgpTxSlaves,
         phyTxLanesOut(0) => phyTxLanesOut,
         phyTxReady       => phyTxReady,
         pgpRxClkEn       => pgpRxClkEn,
         pgpRxClk         => pgpRxClk,
         pgpRxClkRst      => pgpRxRst,
         pgpRxIn          => pgpRxIn,
         pgpRxOut         => pgpRxOut,
         pgpRxMasters     => pgpRxMasters,
         pgpRxMasterMuxed => pgpRxMasterMuxed,
         pgpRxCtrl        => pgpRxCtrl,
         phyRxLanesOut(0) => phyRxLanesOut,
         phyRxLanesIn(0)  => phyRxLanesIn,
         phyRxReady       => phyRxReady,
         phyRxInit        => phyRxInit);   

   U_SaltCore : entity work.SaltCore
      generic map (
         TPD_G           => TPD_G,
         NUM_BYTES_G     => 2,
         COMMA_EN_G      => "0011",
         COMMA_0_G       => "----------0101111100",
         COMMA_1_G       => "----------1010000011",
         COMMA_2_G       => "XXXXXXXXXXXXXXXXXXXX",
         COMMA_3_G       => "XXXXXXXXXXXXXXXXXXXX",
         IODELAY_GROUP_G => IODELAY_GROUP_G,
         RXCLK2X_FREQ_G  => RXCLK2X_FREQ_G,
         XIL_DEVICE_G    => XIL_DEVICE_G) 
      port map (
         loopback   => loopback,
         -- TX Serial Stream
         txP        => txP,
         txN        => txN,
         txInv      => '0',
         -- RX Serial Stream
         rxP        => rxP,
         rxN        => rxN,
         rxInv      => phyRxLanesOut.polarity,
         -- TX Parallel 8B/10B data bus
         txDataIn   => phyTxLanesOut.data,
         txDataKIn  => phyTxLanesOut.dataK,
         txPhyReady => phyTxReady,
         -- RX Parallel 8B/10B data bus
         rxDataOut  => phyRxLanesIn.data,
         rxDataKOut => phyRxLanesIn.dataK,
         rxCodeErr  => phyRxLanesIn.decErr,
         rxDispErr  => phyRxLanesIn.dispErr,
         rxPhyReady => phyRxReady,
         -- Clock and Reset
         refClk     => refClk,
         refRst     => refRst,
         txClkEn    => pgpTxClkEn,
         txClk      => pgpTxClk,
         txRst      => pgpTxRst,
         rxClkEn    => rxClkEn,
         rxClk      => pgpRxClk,
         rxClk2x    => pgpRxClk2x,
         rxClk2xInv => pgpRxClk2xInv,
         rxRst      => pgpRxReset);      

end mapping;
