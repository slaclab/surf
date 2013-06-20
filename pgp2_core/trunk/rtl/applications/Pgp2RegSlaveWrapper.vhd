-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol, V2, Register Slave Block
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : Pgp2RegSlaveWrapper.vhd
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

entity Pgp2RegSlaveWrapper is
   generic (
      RxLane   : integer := 0;          -- Receive Lanes Number (0 to 3)   
      TxLane   : integer := 0;          -- Transmit Lanes Number (0 to 3) 
      -- FifoType: (default = V5)
      -- V4 = Virtex 4,  V5 = Virtex 5, V6 = Virtex 6, V7 = Virtex 7, 
      -- S6 = Spartan 6, A7 = Artix 7,  K7 = kintex7
      FifoType : string  := "V5"
      );
   port (

      -- PGP Rx Clock And Reset
      pgpRxClk   : in sl;               -- PGP Clock
      pgpRxReset : in sl;               -- Synchronous PGP Reset

      -- PGP Tx Clock And Reset
      pgpTxClk   : in sl;               -- PGP Clock
      pgpTxReset : in sl;               -- Synchronous PGP Reset

      -- Local clock and reset
      locClk   : in sl;                 -- Local Clock
      locReset : in sl;                 -- Synchronous Local Reset

      -- PGP Receive Signals
      PgpRxVcOut       : in PgpRxVcOutType;
      PgpRxVcCommonOut : in PgpRxVcCommonOutType;

      -- PGP Transmit Signals
      PgpTxVcIn  : out PgpTxVcInType;
      PgpTxVcOut : in  PgpTxVcOutType;

      -- Local register control signals
      pgpRegIn  : in  RegSlaveInType;
      pgpRegOut : out RegSlaveOutType
      );

end Pgp2RegSlaveWrapper;

-- Define architecture
architecture mapping of Pgp2RegSlaveWrapper is

begin
   U_PgpReg : entity work.Pgp2RegSlave
      generic map (
         FifoType => FifoType
         ) 
      port map (
         pgpRxClk       => pgpRxClk,
         pgpRxReset     => pgpRxReset,
         pgpTxClk       => pgpTxClk,
         pgpTxReset     => pgpTxReset,
         locClk         => locClk,
         locReset       => locReset,
         vcFrameTxValid => pgpTxVcIn.frameTxValid,
         vcFrameTxReady => pgpTxVcOut.FrameTxReady,
         vcFrameTxSOF   => pgpTxVcIn.FrameTxSOF,
         vcFrameTxEOF   => pgpTxVcIn.FrameTxEOF,
         vcFrameTxEOFE  => pgpTxVcIn.FrameTxEOFE,
         vcFrameTxData  => pgpTxVcIn.FrameTxData(TxLane),
         vcRemBuffAFull => pgpRxVcOut.remBuffAFull,
         vcRemBuffFull  => pgpRxVcOut.remBuffFull,
         vcFrameRxValid => pgpRxVcOut.FrameRxValid,
         vcFrameRxSOF   => PgpRxVcCommonOut.FrameRxSOF,
         vcFrameRxEOF   => PgpRxVcCommonOut.FrameRxEOF,
         vcFrameRxEOFE  => PgpRxVcCommonOut.FrameRxEOFE,
         vcFrameRxData  => PgpRxVcCommonOut.frameRxData(RxLane),
         vcLocBuffAFull => pgpTxVcIn.locBuffAFull,
         vcLocBuffFull  => pgpTxVcIn.locBuffFull,
         regInp         => pgpRegOut.regInp,
         regReq         => pgpRegOut.regReq,
         regOp          => pgpRegOut.regOp,
         regAck         => pgpRegIn.regAck,
         regFail        => pgpRegIn.regFail,
         regAddr        => pgpRegOut.regAddr,
         regDataOut     => pgpRegOut.regDataOut,
         regDataIn      => pgpRegIn.regDataIn
         );

end mapping;

