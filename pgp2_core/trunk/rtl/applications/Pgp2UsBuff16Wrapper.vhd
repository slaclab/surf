-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol, V2, Upstream Data Buffer
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : Pgp2UsBuff16Wrapper.vhd
-- Author        : Larry Ruckman, ruckman@slac.stanford.edu
-- Created       : 06/11/2013
-------------------------------------------------------------------------------
-- Description:
-- Wrapper for Pgp2DsBuff16
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

entity Pgp2UsBuff16Wrapper is
   generic (
      TxLane   : integer := 0;          -- Transmit Lanes Number (0 to 3) 
      -- FifoType: (default = V5)
      -- V4 = Virtex 4,  V5 = Virtex 5, V6 = Virtex 6, V7 = Virtex 7, 
      -- S6 = Spartan 6, A7 = Artix 7,  K7 = kintex7
      FifoType : string  := "V5"
      );
   port (

      -- PGP Tx Clock And Reset
      pgpTxClk   : in sl;               -- PGP Clock
      pgpTxReset : in sl;               -- Synchronous PGP Reset

      -- Local clock and reset
      locClk   : in sl;                 -- Local Clock
      locReset : in sl;                 -- Synchronous Local Reset  

      -- PGP Transmit Signals
      PgpTxVcIn               : out PgpTxVcInType;
      PgpTxVcOut              : in  PgpTxVcOutType;
      pgpRxVcOut_remBuffAFull : in  sl;
      pgpRxVcOut_remBuffFull  : in  sl;

      -- Local data transfer signals
      UsBuff16In  : in  UsBuff16InType;
      UsBuff16Out : out UsBuff16OutType
      );
end Pgp2UsBuff16Wrapper;

-- Define architecture
architecture mapping of Pgp2UsBuff16Wrapper is

begin
   U_Pgp2UsBuff16 : entity work.Pgp2UsBuff16
      generic map (
         FifoType => FifoType
         )
      port map (
         pgpClk         => pgpTxClk,
         pgpReset       => pgpTxReset,
         locClk         => locClk,
         locReset       => locReset,
         vcFrameTxValid => pgpTxVcIn.frameTxValid,
         vcFrameTxReady => pgpTxVcOut.frameTxReady,
         vcFrameTxSOF   => pgpTxVcIn.frameTxSOF,
         vcFrameTxEOF   => pgpTxVcIn.frameTxEOF,
         vcFrameTxEOFE  => pgpTxVcIn.frameTxEOFE,
         vcFrameTxData  => pgpTxVcIn.FrameTxData(TxLane),
         vcRemBuffAFull => pgpRxVcOut_remBuffAFull,
         vcRemBuffFull  => pgpRxVcOut_remBuffFull,
         frameTxValid   => UsBuff16In.frameTxEnable,
         frameTxSOF     => UsBuff16In.frameTxSOF,
         frameTxEOF     => UsBuff16In.frameTxEOF,
         frameTxEOFE    => UsBuff16In.frameTxEOFE,
         frameTxData    => UsBuff16In.frameTxData,
         frameTxAFull   => UsBuff16Out.frameTxAFull
         );
end mapping;
