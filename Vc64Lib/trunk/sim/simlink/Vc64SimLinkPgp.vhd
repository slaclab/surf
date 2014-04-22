-------------------------------------------------------------------------------
-- Title         : VC64 Lib, Simulation Link, PGP Like Interface
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : Vc64SimLinkPgp.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 04/18/2014
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- Copyright (c) 2014 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 04/18/2014: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.StdRtlPkg.all;
use work.Pgp2bPkg.all;
use work.Vc64Pkg.all;

entity Vc64SimLinkPgp is 
   generic (
      TPD_G             : time                 := 1 ns;
      LANE_CNT_G        : integer range 1 to 2 := 1
   );
   port ( 

      -- System clock, reset & control
      pgpTxClk          : in  sl;
      pgpTxClkRst       : in  sl;

      -- Non-VC related IO
      pgpTxIn           : in  PgpTxInType;
      pgpTxOut          : out PgpTxOutType;

      -- VC Interface
      pgpTxVcData       : in  Vc64DataArray(3 downto 0);
      pgpTxVcCtrl       : out Vc64CtrlArray(3 downto 0);

      -- System clock, reset & control
      pgpRxClk          : in  sl;
      pgpRxClkRst       : in  sl;

      -- Non-VC related IO
      pgpRxIn           : in  PgpRxInType;
      pgpRxOut          : out PgpRxOutType;

      -- VC Outputs
      pgpRxVcData       : out Vc64DataType;
      pgpRxVcCtrl       : in  Vc64CtrlArray(3 downto 0)
   );

end Vc64SimLinkPgp;


-- Define architecture
architecture Vc64SimLinkPgp of Vc64SimLinkPgp is

   signal ibVcData : Vc64DataType;
   signal ibVcCtrl : Vc64CtrlType;
   signal obVcData : Vc64DataType;
   signal obVcCtrl : Vc64CtrlArray(3 downto 0);

begin

   -- Simulation link
   U_Vc64SimLink : entity work.Vc64SimLink
      generic map (
         TPD_G             => TPD_G,
         VC_WIDTH_G        => (LANE_CNT_G * 16),
         VC_COUNT_G        => 4,
         LITTLE_ENDIAN_G   => true
      ) port map ( 
         ibVcClk         => pgpTxClk,
         ibVcClkRst      => pgpTxClkRst,
         ibVcData        => ibVcData,
         ibVcCtrl        => ibVcCtrl,
         obVcClk         => pgpRxClk,
         obVcClkRst      => pgpRxClkRst,
         obVcData        => obVcData,
         obVcCtrl        => obVcCtrl
      );

   -- Fake control signals
   pgpTxOut.linkReady    <= '1';
   pgpRxOut.linkReady    <= '1';
   pgpRxOut.cellError    <= '0';
   pgpRxOut.linkDown     <= '0';
   pgpRxOut.linkError    <= '0';
   pgpRxOut.opCodeEn     <= '0';
   pgpRxOut.opCode       <= (others=>'0');
   pgpRxOut.remLinkReady <= '1';
   pgpRxOut.remLinkData  <= (others=>'0');
      
   -- Transmit MUX and arbiter
   U_TxMux : entity work.Vc64Mux 
      generic map (
         TPD_G           => TPD_G,
         IB_VC_COUNT_G   => 4,
         VC_INTERLEAVE_G => false
      ) port map (
         vcClk         => pgpTxClk,
         vcClkRst      => pgpTxClkRst,
         ibVcData      => pgpTxVcData,
         ibVcCtrl      => pgpTxVcCtrl,
         obVcData      => ibVcData,
         obVcCtrl      => ibVcCtrl
      );

   -- Receive Connection is direct
   obVcCtrl    <= pgpRxVcCtrl;
   pgpRxVcData <= obVcData;

end Vc64SimLinkPgp;

