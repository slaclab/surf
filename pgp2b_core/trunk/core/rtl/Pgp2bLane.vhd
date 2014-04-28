-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol, V2, Top Level RX/TX
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : Pgp2bLane.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 04/07/2014
-------------------------------------------------------------------------------
-- Description:
-- Top Level Transmit/Receive interface module for the Pretty Good Protocol core. 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 04/07/2014: created.
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
      pgpTxClk          : in  sl := '0';
      pgpTxClkRst       : in  sl := '0';

      -- Non-VC related IO
      pgpTxIn           : in  PgpTxInType := PGP_TX_IN_INIT_C;
      pgpTxOut          : out PgpTxOutType;

      -- VC Interface
      pgpTxMasters      : in  AxiStreamMasterArray(3 downto 0) := (others=>AXI_STREAM_MASTER_INIT_C);
      pgpTxSlaves       : out AxiStreamSlaveArray(3 downto 0);

      -- Phy interface
      phyTxLanesOut     : out PgpTxPhyLaneOutArray(0 to LANE_CNT_G-1);
      phyTxReady        : in  sl := '0';

      ---------------------------------
      -- Receiver Interface
      ---------------------------------

      -- System clock, reset & control
      pgpRxClk          : in  sl := '0';
      pgpRxClkRst       : in  sl := '0';

      -- Non-VC related IO
      pgpRxIn           : in  PgpRxInType := PGP_RX_IN_INIT_C;
      pgpRxOut          : out PgpRxOutType;

      -- VC Outputs
      pgpRxMasters      : out AxiStreamMasterArray(3 downto 0);
      pgpRxMasterMuxed  : out AxiStreamMasterType;

      -- Receive flow control
      axiFifoStatus     : in  AxiStreamFifoStatusArray(3 downto 0);

      -- PHY interface
      phyRxLanesOut     : out PgpRxPhyLaneOutArray(0 to LANE_CNT_G-1);
      phyRxLanesIn      : in  PgpRxPhyLaneInArray(0 to LANE_CNT_G-1) := (others=>PGP_RX_PHY_LANE_IN_INIT_C);
      phyRxReady        : in  sl := '0';
      phyRxInit         : out sl
   );

end Pgp2bLane;


-- Define architecture
architecture Pgp2bLane of Pgp2bLane is

   -- Local Signals
   signal intRxMaster   : AxiStreamMasterType;
   signal remFifoStatus : AxiStreamFifoStatusArray(3 downto 0);

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
            pgpTxClk           => pgpTxClk,
            pgpTxClkRst        => pgpTxClkRst,
            pgpTxIn            => pgpTxIn,
            pgpTxOut           => pgpTxOut,
            pgpTxMasters       => pgpTxMasters,
            pgpTxSlaves        => pgpTxSlaves,
            locFifoStatus      => axiFifoStatus,
            remFifoStatus      => remFifoStatus,
            phyTxLanesOut      => phyTxLanesOut,
            phyTxReady         => phyTxReady
         );
   end generate;

   U_TxDisGen: if TX_ENABLE_G = false generate
      pgpTxOut      <= PGP_TX_OUT_INIT_C;
      pgpTxSlaves   <= (others=>AXI_STREAM_SLAVE_INIT_C);
      phyTxLanesOut <= (others=>PGP_TX_PHY_LANE_OUT_INIT_C);
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
            pgpRxClk          => pgpRxClk,
            pgpRxClkRst       => pgpRxClkRst,
            pgpRxIn           => pgpRxIn,
            pgpRxOut          => pgpRxOut,
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
            axiClk            => pgpRxClk,
            axiRst            => pgpRxClkRst,
            sAxiStreamMaster  => intRxMaster,
            sAxiStreamSlave   => open,
            mAxiStreamMasters => pgpRxMasters,
            mAxiStreamSlaves  => (others=>AXI_STREAM_SLAVE_FORCE_C)
         );
      
   end generate;

   U_RxDisGen: if RX_ENABLE_G = false generate
      pgpRxOut               <= PGP_RX_OUT_INIT_C;
      pgpRxMasters           <= (others=>AXI_STREAM_MASTER_INIT_C);
      intRxMaster            <= AXI_STREAM_MASTER_INIT_C;
      phyRxLanesOut          <= (others=>PGP_RX_PHY_LANE_OUT_INIT_C);
      phyRxInit              <= '0';
      remFifoStatus          <= (others=>AXI_STREAM_FIFO_STATUS_INIT_C);
   end generate;

   -- De-Muxed Version
   pgpRxMasterMuxed <= intRxMaster;


end Pgp2bLane;

