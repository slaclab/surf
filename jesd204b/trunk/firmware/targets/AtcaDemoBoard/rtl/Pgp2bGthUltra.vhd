-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Pgp2bGthUltra.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-06-29
-- Last update: 2015-06-10
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Gtx7 Wrapper
--
-- Dependencies:  ^/pgp2_core/trunk/rtl/core/Pgp2RxWrapper.vhd
--                ^/pgp2_core/trunk/rtl/core/Pgp2TxWrapper.vhd
--                ^/StdLib/trunk/rtl/CRC32Rtl.vhd
--                ^/MgtLib/trunk/rtl/gtx7/Gtx7Core.vhd
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.Pgp2bPkg.all;

library UNISIM;
use UNISIM.VCOMPONENTS.all;

entity Pgp2bGthUltra is
   generic (
      TPD_G             : time                 := 1 ns;
      ----------------------------------------------------------------------------------------------
      -- PGP Settings
      ----------------------------------------------------------------------------------------------
      PGP_RX_ENABLE_G   : boolean              := true;
      PGP_TX_ENABLE_G   : boolean              := true;
      PAYLOAD_CNT_TOP_G : integer              := 7;  -- Top bit for payload counter
      VC_INTERLEAVE_G   : integer              := 1;  -- Interleave Frames
      NUM_VC_EN_G       : integer range 1 to 4 := 4
      );
   port (
      -- GT Clocking
      stableClk        : in  sl;                      -- GT needs a stable clock to "boot up"
      gtRefClk         : in  sl;
      -- Gt Serial IO
      pgpGtTxP         : out sl;
      pgpGtTxN         : out sl;
      pgpGtRxP         : in  sl;
      pgpGtRxN         : in  sl;
      -- Tx Clocking
      pgpTxReset       : in  sl;
      pgpTxRecClk      : out sl;                      -- recovered clock
      pgpTxClk         : in  sl;
      pgpTxMmcmLocked  : in  sl;
      -- Rx clocking
      pgpRxReset       : in  sl;
      pgpRxRecClk      : out sl;                      -- recovered clock
      pgpRxClk         : in  sl;
      pgpRxMmcmLocked  : in  sl;
      -- Non VC Rx Signals
      pgpRxIn          : in  Pgp2bRxInType;
      pgpRxOut         : out Pgp2bRxOutType;
      -- Non VC Tx Signals
      pgpTxIn          : in  Pgp2bTxInType;
      pgpTxOut         : out Pgp2bTxOutType;
      -- Frame Transmit Interface - 1 Lane, Array of 4 VCs
      pgpTxMasters     : in  AxiStreamMasterArray(3 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
      pgpTxSlaves      : out AxiStreamSlaveArray(3 downto 0);
      -- Frame Receive Interface - 1 Lane, Array of 4 VCs
      pgpRxMasters     : out AxiStreamMasterArray(3 downto 0);
      pgpRxMasterMuxed : out AxiStreamMasterType;
      pgpRxCtrl        : in  AxiStreamCtrlArray(3 downto 0));

end Pgp2bGthUltra;

-- Define architecture
architecture rtl of Pgp2bGthUltra is

   -- PgpRx Signals
   signal gtRxUserReset : sl;
   signal phyRxLaneIn   : Pgp2bRxPhyLaneInType;
   signal phyRxLaneOut  : Pgp2bRxPhyLaneOutType;
   signal phyRxReady    : sl;
   signal phyRxInit     : sl;

   -- PgpTx Signals
   signal gtTxUserReset : sl;
   signal phyTxLaneOut  : Pgp2bTxPhyLaneOutType;
   signal phyTxReady    : sl;


begin

   gtRxUserReset <= phyRxInit or pgpRxReset or pgpRxIn.resetRx;
   gtTxUserReset <= pgpTxReset;

   U_Pgp2bLane : entity work.Pgp2bLane
      generic map (
         LANE_CNT_G        => 1,
         VC_INTERLEAVE_G   => VC_INTERLEAVE_G,
         PAYLOAD_CNT_TOP_G => PAYLOAD_CNT_TOP_G,
         NUM_VC_EN_G       => NUM_VC_EN_G,
         TX_ENABLE_G       => PGP_TX_ENABLE_G,
         RX_ENABLE_G       => PGP_RX_ENABLE_G)
      port map (
         pgpTxClk         => pgpTxClk,
         pgpTxClkRst      => pgpTxReset,
         pgpTxIn          => pgpTxIn,
         pgpTxOut         => pgpTxOut,
         pgpTxMasters     => pgpTxMasters,
         pgpTxSlaves      => pgpTxSlaves,
         phyTxLanesOut(0) => phyTxLaneOut,
         phyTxReady       => phyTxReady,
         pgpRxClk         => pgpRxClk,
         pgpRxClkRst      => pgpRxReset,
         pgpRxIn          => pgpRxIn,
         pgpRxOut         => pgpRxOut,
         pgpRxMasters     => pgpRxMasters,
         pgpRxMasterMuxed => pgpRxMasterMuxed,
         pgpRxCtrl        => pgpRxCtrl,
         phyRxLanesOut(0) => phyRxLaneOut,
         phyRxLanesIn(0)  => phyRxLaneIn,
         phyRxReady       => phyRxReady,
         phyRxInit        => phyRxInit);

   --------------------------------------------------------------------------------------------------
   -- Generate the GT
   --------------------------------------------------------------------------------------------------
   PgpGthCoreWrapper_1 : entity work.PgpGthCoreWrapper
      generic map (
         TPD_G => TPD_G)
      port map (
         stableClk      => stableClk,
         gtRefClk       => gtRefClk,
         gtRxP          => pgpGtRxP,
         gtRxN          => pgpGtRxN,
         gtTxP          => pgpGtTxP,
         gtTxN          => pgpGtTxN,
         rxReset        => gtRxUserReset,
         rxUsrClkActive => pgpRxMmcmLocked,
         rxCdrStable    => open,
         rxResetDone    => phyRxReady,
         rxUsrClk       => pgpRxClk,
         rxData         => phyRxLaneIn.data,
         rxDataK        => phyRxLaneIn.dataK,
         rxDispErr      => phyRxLaneIn.dispErr,
         rxDecErr       => phyRxLaneIn.decErr,
         rxPolarity     => phyRxLaneOut.polarity,
         rxOutClk       => pgpRxRecClk,
         txReset        => gtTxUserReset,
         txUsrClk       => pgpTxClk,
         txUsrClkActive => pgpTxMmcmLocked,
         txResetDone    => phyTxReady,
         txData         => phyTxLaneOut.data,
         txDataK        => phyTxLaneOut.dataK,
         txOutClk       => pgpTxRecClk,
         loopback       => pgpRxIn.loopback);


end rtl;
