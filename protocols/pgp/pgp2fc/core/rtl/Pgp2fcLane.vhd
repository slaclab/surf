-------------------------------------------------------------------------------
-- Title      : PGPv2fc: https://confluence.slac.stanford.edu/x/q86fD
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
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

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;


library surf;
use surf.StdRtlPkg.all;
use surf.Pgp2fcPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

entity Pgp2fcLane is
   generic (
      TPD_G             : time                 := 1 ns;
      FC_WORDS_G        : integer range 1 to 8 := 1;     -- Number of words in FC bus
      VC_INTERLEAVE_G   : integer              := 1;     -- Interleave Frames
      PAYLOAD_CNT_TOP_G : integer              := 7;     -- Top bit for payload counter
      NUM_VC_EN_G       : integer range 1 to 4 := 4;
      TX_ENABLE_G       : boolean              := true;  -- Enable TX direction
      RX_ENABLE_G       : boolean              := true   -- Enable RX direction
      );
   port (

      ---------------------------------
      -- Transmitter Interface
      ---------------------------------

      -- System clock, reset & control
      pgpTxClkEn  : in sl := '1';
      pgpTxClk    : in sl := '0';
      pgpTxClkRst : in sl := '0';

      -- Non-VC related IO
      pgpTxIn  : in  Pgp2fcTxInType := PGP2FC_TX_IN_INIT_C;
      pgpTxOut : out Pgp2fcTxOutType;

      -- VC Interface
      pgpTxMasters : in  AxiStreamMasterArray(3 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
      pgpTxSlaves  : out AxiStreamSlaveArray(3 downto 0);

      -- Phy interface
      phyTxLaneOut : out Pgp2fcTxPhyLaneOutType;
      phyTxReady   : in  sl := '0';

      ---------------------------------
      -- Receiver Interface
      ---------------------------------

      -- System clock, reset & control
      pgpRxClkEn  : in sl := '1';
      pgpRxClk    : in sl := '0';
      pgpRxClkRst : in sl := '0';

      -- Non-VC related IO
      pgpRxIn  : in  Pgp2fcRxInType := PGP2FC_RX_IN_INIT_C;
      pgpRxOut : out Pgp2fcRxOutType;

      -- VC Outputs
      pgpRxMasters     : out AxiStreamMasterArray(3 downto 0);
      pgpRxMasterMuxed : out AxiStreamMasterType;

      -- Receive flow control
      pgpRxCtrl : in AxiStreamCtrlArray(3 downto 0) := (others => AXI_STREAM_CTRL_UNUSED_C);

      -- PHY interface
      phyRxLaneIn : in  Pgp2fcRxPhyLaneInType;
      phyRxReady  : in  sl := '0';
      phyRxInit   : out sl
      );

end Pgp2fcLane;


-- Define architecture
architecture Pgp2fcLane of Pgp2fcLane is

   -- Local Signals
   signal intRxMaster   : AxiStreamMasterType;
   signal remFifoStatus : AxiStreamCtrlArray(3 downto 0);
   signal intRxOut      : Pgp2fcRxOutType;

begin

   -----------------------------
   -- Transmit
   -----------------------------

   U_TxEnGen : if TX_ENABLE_G = true generate

      -- Transmit
      U_Pgp2fcTx : entity surf.Pgp2fcTx
         generic map (
            TPD_G             => TPD_G,
            FC_WORDS_G        => FC_WORDS_G,
            VC_INTERLEAVE_G   => VC_INTERLEAVE_G,
            PAYLOAD_CNT_TOP_G => PAYLOAD_CNT_TOP_G,
            NUM_VC_EN_G       => NUM_VC_EN_G
            ) port map (
               pgpTxClkEn    => pgpTxClkEn,
               pgpTxClk      => pgpTxClk,
               pgpTxClkRst   => pgpTxClkRst,
               pgpTxIn       => pgpTxIn,
               pgpTxOut      => pgpTxOut,
               locLinkReady  => intRxOut.linkReady,
               pgpTxMasters  => pgpTxMasters,
               pgpTxSlaves   => pgpTxSlaves,
               locFifoStatus => pgpRxCtrl,
               remFifoStatus => remFifoStatus,
               phyTxLaneOut  => phyTxLaneOut,
               phyTxReady    => phyTxReady
               );
   end generate;

   U_TxDisGen : if TX_ENABLE_G = false generate
      pgpTxOut     <= PGP2FC_TX_OUT_INIT_C;
      pgpTxSlaves  <= (others => AXI_STREAM_SLAVE_INIT_C);
      phyTxLaneOut <= PGP2FC_TX_PHY_LANE_OUT_INIT_C;
   end generate;


   -----------------------------
   -- Receive
   -----------------------------

   U_RxEnGen : if RX_ENABLE_G = true generate

      -- Receive
      U_Pgp2fcRx : entity surf.Pgp2fcRx
         generic map (
            TPD_G             => TPD_G,
            FC_WORDS_G        => FC_WORDS_G,
            PAYLOAD_CNT_TOP_G => PAYLOAD_CNT_TOP_G
            ) port map (
               pgpRxClkEn    => pgpRxClkEn,
               pgpRxClk      => pgpRxClk,
               pgpRxClkRst   => pgpRxClkRst,
               pgpRxIn       => pgpRxIn,
               pgpRxOut      => intRxOut,
               pgpRxMaster   => intRxMaster,
               remFifoStatus => remFifoStatus,
               phyRxLaneIn   => phyRxLaneIn,
               phyRxReady    => phyRxReady,
               phyRxInit     => phyRxInit
               );

      -- Demux
      U_RxDeMux : entity surf.AxiStreamDeMux
         generic map (
            TPD_G         => TPD_G,
            NUM_MASTERS_G => 4
            ) port map (
               axisClk      => pgpRxClk,
               axisRst      => pgpRxClkRst,
               sAxisMaster  => intRxMaster,
               sAxisSlave   => open,
               mAxisMasters => pgpRxMasters,
               mAxisSlaves  => (others => AXI_STREAM_SLAVE_FORCE_C)
               );

   end generate;

   U_RxDisGen : if RX_ENABLE_G = false generate
      intRxOut      <= PGP2FC_RX_OUT_INIT_C;
      pgpRxMasters  <= (others => AXI_STREAM_MASTER_INIT_C);
      intRxMaster   <= AXI_STREAM_MASTER_INIT_C;
      phyRxInit     <= '0';
      remFifoStatus <= (others => AXI_STREAM_CTRL_UNUSED_C);
   end generate;

   -- De-Muxed Version
   pgpRxMasterMuxed <= intRxMaster;
   pgpRxOut         <= intRxOut;

end Pgp2fcLane;

