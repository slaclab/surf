-------------------------------------------------------------------------------
-- File       : Pgp2bLane.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2009-05-27
-- Last update: 2017-03-28
-------------------------------------------------------------------------------
-- Description:
-- Top Level Transmit/Receive interface module for the Pretty Good Protocol core. 
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

LIBRARY ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.Pgp2bPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

entity Pgp2bLane is 
   generic (
      TPD_G             : time                             := 1 ns;
      LANE_CNT_G        : integer range 1 to 2             := 1;    -- Number of lanes, 1-2
      VC_INTERLEAVE_G   : integer                          := 1;    -- Interleave Frames
      PAYLOAD_CNT_TOP_G : integer                          := 7;    -- Top bit for payload counter
      NUM_VC_EN_G       : integer range 1 to 4             := 4;
      TX_ENABLE_G       : boolean                          := true; -- Enable TX direction
      RX_ENABLE_G       : boolean                          := true  -- Enable RX direction
   );
   port ( 

      ---------------------------------
      -- Transmitter Interface
      ---------------------------------
   
      -- System clock, reset & control
      pgpTxClkEn        : in  sl := '1';
      pgpTxClk          : in  sl := '0';
      pgpTxClkRst       : in  sl := '0';

      -- Non-VC related IO
      pgpTxIn           : in  Pgp2bTxInType := PGP2B_TX_IN_INIT_C;
      pgpTxOut          : out Pgp2bTxOutType;

      -- VC Interface
      pgpTxMasters      : in  AxiStreamMasterArray(3 downto 0) := (others=>AXI_STREAM_MASTER_INIT_C);
      pgpTxSlaves       : out AxiStreamSlaveArray(3 downto 0);

      -- Phy interface
      phyTxLanesOut     : out Pgp2bTxPhyLaneOutArray(0 to LANE_CNT_G-1);
      phyTxReady        : in  sl := '0';

      ---------------------------------
      -- Receiver Interface
      ---------------------------------

      -- System clock, reset & control
      pgpRxClkEn        : in  sl := '1';
      pgpRxClk          : in  sl := '0';
      pgpRxClkRst       : in  sl := '0';

      -- Non-VC related IO
      pgpRxIn           : in  Pgp2bRxInType := PGP2B_RX_IN_INIT_C;
      pgpRxOut          : out Pgp2bRxOutType;

      -- VC Outputs
      pgpRxMasters      : out AxiStreamMasterArray(3 downto 0);
      pgpRxMasterMuxed  : out AxiStreamMasterType;

      -- Receive flow control
      pgpRxCtrl         : in  AxiStreamCtrlArray(3 downto 0) := (others=>AXI_STREAM_CTRL_UNUSED_C);

      -- PHY interface
      phyRxLanesOut     : out Pgp2bRxPhyLaneOutArray(0 to LANE_CNT_G-1);
      phyRxLanesIn      : in  Pgp2bRxPhyLaneInArray(0 to LANE_CNT_G-1) := (others=>PGP2B_RX_PHY_LANE_IN_INIT_C);
      phyRxReady        : in  sl := '0';
      phyRxInit         : out sl
   );

end Pgp2bLane;


-- Define architecture
architecture Pgp2bLane of Pgp2bLane is

   -- Local Signals
   signal intRxMaster   : AxiStreamMasterType;
   signal remFifoStatus : AxiStreamCtrlArray(3 downto 0);
   signal intRxOut      : Pgp2bRxOutType;

begin

   -----------------------------
   -- Transmit
   -----------------------------

   U_TxEnGen: if TX_ENABLE_G = true generate

      -- Transmit
      U_Pgp2bTx: entity work.Pgp2bTx 
         generic map (
            TPD_G              => TPD_G,
            TX_LANE_CNT_G      => LANE_CNT_G,
            VC_INTERLEAVE_G    => VC_INTERLEAVE_G,
            PAYLOAD_CNT_TOP_G  => PAYLOAD_CNT_TOP_G,
            NUM_VC_EN_G        => NUM_VC_EN_G
         ) port map ( 
            pgpTxClkEn         => pgpTxClkEn,
            pgpTxClk           => pgpTxClk,
            pgpTxClkRst        => pgpTxClkRst,
            pgpTxIn            => pgpTxIn,
            pgpTxOut           => pgpTxOut,
            locLinkReady       => intRxOut.linkReady,
            pgpTxMasters       => pgpTxMasters,
            pgpTxSlaves        => pgpTxSlaves,
            locFifoStatus      => pgpRxCtrl,
            remFifoStatus      => remFifoStatus,
            phyTxLanesOut      => phyTxLanesOut,
            phyTxReady         => phyTxReady
         );
   end generate;

   U_TxDisGen: if TX_ENABLE_G = false generate
      pgpTxOut      <= PGP2B_TX_OUT_INIT_C;
      pgpTxSlaves   <= (others=>AXI_STREAM_SLAVE_INIT_C);
      phyTxLanesOut <= (others=>PGP2B_TX_PHY_LANE_OUT_INIT_C);
   end generate;


   -----------------------------
   -- Receive
   -----------------------------

   U_RxEnGen: if RX_ENABLE_G = true generate

      -- Receive
      U_Pgp2bRx: entity work.Pgp2bRx 
         generic map (
            TPD_G              => TPD_G,
            RX_LANE_CNT_G      => LANE_CNT_G,
            PAYLOAD_CNT_TOP_G  => PAYLOAD_CNT_TOP_G
         ) port map (
            pgpRxClkEn        => pgpRxClkEn,
            pgpRxClk          => pgpRxClk,
            pgpRxClkRst       => pgpRxClkRst,
            pgpRxIn           => pgpRxIn,
            pgpRxOut          => intRxOut,
            pgpRxMaster       => intRxMaster,
            remFifoStatus     => remFifoStatus,
            phyRxLanesOut     => phyRxLanesOut,
            phyRxLanesIn      => phyRxLanesIn,
            phyRxReady        => phyRxReady,
            phyRxInit         => phyRxInit
         );

      -- Demux
      U_RxDeMux : entity work.AxiStreamDeMux
         generic map (
            TPD_G         => TPD_G,
            NUM_MASTERS_G => 4
         ) port map (
            axisClk      => pgpRxClk,
            axisRst      => pgpRxClkRst,
            sAxisMaster  => intRxMaster,
            sAxisSlave   => open,
            mAxisMasters => pgpRxMasters,
            mAxisSlaves  => (others=>AXI_STREAM_SLAVE_FORCE_C)
         );
     
   end generate;

   U_RxDisGen: if RX_ENABLE_G = false generate
      intRxOut               <= PGP2B_RX_OUT_INIT_C;
      pgpRxMasters           <= (others=>AXI_STREAM_MASTER_INIT_C);
      intRxMaster            <= AXI_STREAM_MASTER_INIT_C;
      phyRxLanesOut          <= (others=>PGP2B_RX_PHY_LANE_OUT_INIT_C);
      phyRxInit              <= '0';
      remFifoStatus          <= (others=>AXI_STREAM_CTRL_UNUSED_C);
   end generate;

   -- De-Muxed Version
   pgpRxMasterMuxed <= intRxMaster;
   pgpRxOut         <= intRxOut;

end Pgp2bLane;

