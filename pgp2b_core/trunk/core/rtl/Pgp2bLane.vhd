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
use work.Vc64Pkg.all;

entity Pgp2bLane is 
   generic (
      TPD_G             : time                 := 1 ns;
      LANE_CNT_G        : integer range 1 to 2 := 1; -- Number of lanes, 1-2
      VC_INTERLEAVE_G   : integer              := 1; -- Interleave Frames
      EN_SHORT_CELLS_G  : integer              := 1; -- Enable short non-EOF cells
      PAYLOAD_CNT_TOP_G : integer              := 7; -- Top bit for payload counter
      NUM_VC_EN_G       : integer range 1 to 4 := 4
   );
   port ( 

      -- System clock, reset & control
      pgpTxClk          : in  sl;    -- Master clock
      pgpTxClkRst        : in  sl;    -- Synchronous reset input

      -- Non-VC related IO
      pgpTxIn           : in  PgpTxInType;
      pgpTxOut          : out PgpTxOutType;

      -- VC Interface
      pgpTxVcData       : in  Vc64DataArray(3 downto 0);
      pgpTxVcCtrl       : out Vc64CtrlArray(3 downto 0);

      -- Phy interface
      phyTxLanesOut     : out PgpTxPhyLaneOutArray(0 to LANE_CNT_G-1);
      phyTxReady        : in  sl;

      -- System clock, reset & control
      pgpRxClk          : in  sl;        -- Master clock
      pgpRxClkRst       : in  sl;        -- Synchronous reset input

      -- Non-VC related IO
      pgpRxIn           : in  PgpRxInType;
      pgpRxOut          : out PgpRxOutType;

      -- VC Outputs
      pgpRxVcData       : out Vc64DataType;
      pgpRxVcCtrl       : in  Vc64CtrlArray(3 downto 0);

      -- PHY interface
      phyRxLanesOut     : out PgpRxPhyLaneOutArray(0 to LANE_CNT_G-1);
      phyRxLanesIn      : in  PgpRxPhyLaneInArray(0 to LANE_CNT_G-1);
      phyRxReady        : in  sl;
      phyRxInit         : out sl
   );

end Pgp2bLane;


-- Define architecture
architecture Pgp2bLane of Pgp2bLane is

   -- Local Signals
   signal intTxVcCtrl      : Vc64CtrlArray(3 downto 0);
   signal intTxLocVcCtrl   : Vc64CtrlArray(3 downto 0);
   signal intRxRemVcCtrl   : Vc64CtrlArray(3 downto 0);

begin


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
         pgpTxVcData        => pgpTxVcData,
         pgpTxVcCtrl        => intTxVcCtrl,
         pgpTxLocVcCtrl     => intTxLocVcCtrl,
         phyTxLanesOut      => phyTxLanesOut,
         phyTxReady         => phyTxReady
      );

   -- Receive
   U_Pgp2bRx: entity work.Pgp2bRx 
      generic map (
         TPD_G              => TPD_G,
         RX_LANE_CNT_G      => LANE_CNT_G,
         EN_SHORT_CELLS_G   => EN_SHORT_CELLS_G,
         PAYLOAD_CNT_TOP_G  => PAYLOAD_CNT_TOP_G
      ) port map (
         pgpRxClk          => pgpRxClk,
         pgpRxClkRst       => pgpRxClkRst,
         pgpRxIn           => pgpRxIn,
         pgpRxOut          => pgpRxOut,
         pgpRxVcData       => pgpRxVcData,
         pgpRxRemVcCtrl    => intRxRemVcCtrl,
         phyRxLanesOut     => phyRxLanesOut,
         phyRxLanesIn      => phyRxLanesIn,
         phyRxReady        => phyRxReady,
         phyRxInit         => phyRxInit
      );

   U_VcCtrlGen: for i in 0 to 3 generate

      -- Sync flow control to tx clock
      U_Sync: entity work.SynchronizerVector
         generic map (
            TPD_G          => TPD_G,
            RST_POLARITY_G => '1',
            OUT_POLARITY_G => '1',
            RST_ASYNC_G    => false,
            STAGES_G       => 2,
            WIDTH_G        => 4,
            INIT_G         => "0"
         ) port map (
            clk        => pgpTxClk,
            rst        => pgpTxClkRst,
            dataIn(0)  => intRxRemVcCtrl(i).almostFull,
            dataIn(1)  => intRxRemVcCtrl(i).overflow,
            dataIn(2)  => pgpRxVcCtrl(i).almostFull,
            dataIn(3)  => pgpRxVcCtrl(i).overflow,
            dataOut(0) => pgpTxVcCtrl(i).almostFull,
            dataOut(1) => pgpTxVcCtrl(i).overflow,
            dataOut(2) => intTxLocVcCtrl(i).almostFull,
            dataOut(3) => intTxLocVcCtrl(i).overflow
         );

      intTxLocVcCtrl(i).ready <= '1';
      pgpTxVcCtrl(i).ready    <= intTxVcCtrl(i).ready;

   end generate;

end Pgp2bLane;

