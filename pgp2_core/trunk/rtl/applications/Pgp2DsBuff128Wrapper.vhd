-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol, V2, Down Stream Buffer Block
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : Pgp2DsBuff128Wrapper.vhd
-- Author        : Larry Ruckman, ruckman@slac.stanford.edu
-- Created       : 06/11/2013
-------------------------------------------------------------------------------
-- Description:
-- Wrapper for Pgp2DsBuff128
-------------------------------------------------------------------------------
-- Copyright (c) 2013 by Larry Ruckman. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 06/11/2013: created.
-------------------------------------------------------------------------------

library ieee;
use work.Pgp2CoreTypesPkg.all;
use work.Pgp2AppTypesPkg.all;
use work.StdRtlPkg.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity Pgp2DsBuff128Wrapper is
   generic (
      RxLane   : integer := 0;          -- Receive Lanes Number (0 to 3) 
      -- FifoType: (default = V5)
      -- V4 = Virtex 4,  V5 = Virtex 5, V6 = Virtex 6, V7 = Virtex 7, 
      -- S6 = Spartan 6, A7 = Artix 7,  K7 = kintex7
      FifoType : string  := "V5"
      );
   port (

      -- PGP Rx Clock And Reset
      pgpRxClk   : in sl;               -- PGP Clock
      pgpRxReset : in sl;               -- Synchronous PGP Reset

      -- Local clock and reset
      locClk   : in sl;                 -- Local Clock
      locReset : in sl;                 -- Synchronous Local Reset

      -- PGP Signals, Virtual Channel Rx Only
      PgpRxVcOut             : in  PgpRxVcOutType;
      PgpRxVcCommonOut       : in  PgpRxVcCommonOutType;
      pgpTxVcIn_locBuffAFull : out sl;
      pgpTxVcIn_locBuffFull  : out sl;

      -- Local data transfer signals
      DsBuff128In  : in  DsBuff128InType;
      DsBuff128Out : out DsBuff128OutType
      );
end Pgp2DsBuff128Wrapper;


-- Define architecture
architecture mapping of Pgp2DsBuff128Wrapper is

begin
   U_Pgp2DsBuff128 : entity work.Pgp2DsBuff128
      generic map (
         FifoType => FifoType
         ) port map ( 
            pgpClk         => pgpRxClk,
            pgpReset       => pgpRxReset,
            locClk         => locClk,
            locReset       => locReset,
            vcFrameRxValid => pgpRxVcOut.frameRxValid,
            vcFrameRxSOF   => PgpRxVcCommonOut.frameRxSOF,
            vcFrameRxEOF   => PgpRxVcCommonOut.frameRxEOF,
            vcFrameRxEOFE  => PgpRxVcCommonOut.frameRxEOFE,
            vcFrameRxData  => PgpRxVcCommonOut.frameRxData(RxLane),
            vcLocBuffAFull => pgpTxVcIn_locBuffAFull,
            vcLocBuffFull  => pgpTxVcIn_locBuffFull,
            frameRxValid   => DsBuff128Out.frameRxValid,
            frameRxReady   => DsBuff128In.frameRxReady,
            frameRxSOF     => DsBuff128Out.frameRxSOF,
            frameRxEOF     => DsBuff128Out.frameRxEOF,
            frameRxEOFE    => DsBuff128Out.frameRxEOFE,
            frameRxData    => DsBuff128Out.frameRxData
            );
end mapping;

