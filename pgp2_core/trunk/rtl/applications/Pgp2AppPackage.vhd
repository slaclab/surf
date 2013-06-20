-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol, Applications Package
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : Pgp2AppPackage.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 11/23/2009
-------------------------------------------------------------------------------
-- Description:
-- Application Components package.
-------------------------------------------------------------------------------
-- Copyright (c) 2006 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 11/23/2009: created.
-- 06/10/2013: updated for series 7 FPGAs (LLR)
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

package Pgp2AppPackage is

   -- Register Slave
   component Pgp2RegSlave
      generic (
         -- FifoType: (default = V5)
         -- V4 = Virtex 4,  V5 = Virtex 5, V6 = Virtex 6, V7 = Virtex 7, 
         -- S6 = Spartan 6, A7 = Artix 7,  K7 = kintex7
         FifoType : string := "V5"
         );
      port (
         pgpRxClk       : in  std_logic;  -- PGP Clock
         pgpRxReset     : in  std_logic;  -- Synchronous PGP Reset
         pgpTxClk       : in  std_logic;  -- PGP Clock
         pgpTxReset     : in  std_logic;  -- Synchronous PGP Reset
         locClk         : in  std_logic;  -- Local Clock
         locReset       : in  std_logic;  -- Synchronous Local Reset
         vcFrameRxValid : in  std_logic;  -- Data is valid
         vcFrameRxSOF   : in  std_logic;  -- Data is SOF
         vcFrameRxEOF   : in  std_logic;  -- Data is EOF
         vcFrameRxEOFE  : in  std_logic;  -- Data is EOF with Error
         vcFrameRxData  : in  std_logic_vector(15 downto 0);  -- Data
         vcLocBuffAFull : out std_logic;  -- Local buffer almost full
         vcLocBuffFull  : out std_logic;  -- Local buffer full
         vcFrameTxValid : out std_logic;  -- User frame data is valid
         vcFrameTxReady : in  std_logic;  -- PGP is ready
         vcFrameTxSOF   : out std_logic;  -- User frame data start of frame
         vcFrameTxEOF   : out std_logic;  -- User frame data end of frame
         vcFrameTxEOFE  : out std_logic;  -- User frame data error
         vcFrameTxData  : out std_logic_vector(15 downto 0);  -- User frame data
         vcRemBuffAFull : in  std_logic;  -- Remote buffer almost full
         vcRemBuffFull  : in  std_logic;  -- Remote buffer full
         regInp         : out std_logic;  -- Register Access In Progress Flag
         regReq         : out std_logic;  -- Register Access Request
         regOp          : out std_logic;  -- Register OpCode, 0=Read, 1=Write
         regAck         : in  std_logic;  -- Register Access Acknowledge
         regFail        : in  std_logic;  -- Register Access Fail
         regAddr        : out std_logic_vector(23 downto 0);  -- Register Address
         regDataOut     : out std_logic_vector(31 downto 0);  -- Register Data Out
         regDataIn      : in  std_logic_vector(31 downto 0)  -- Register Data In
         );
   end component;

   -- Register Slave
   component Pgp2CmdSlave
      generic (
         DestId   : natural := 0;       -- Destination ID Value To Match
         DestMask : natural := 0;       -- Destination ID Mask For Match
         -- FifoType: (default = V5)
         -- V4 = Virtex 4,  V5 = Virtex 5, V6 = Virtex 6, V7 = Virtex 7, 
         -- S6 = Spartan 6, A7 = Artix 7,  K7 = kintex7
         FifoType : string  := "V5"
         );
      port (
         pgpRxClk       : in  std_logic;  -- PGP Clock
         pgpRxReset     : in  std_logic;  -- Synchronous PGP Reset
         locClk         : in  std_logic;  -- Local Clock
         locReset       : in  std_logic;  -- Synchronous Local Reset
         vcFrameRxValid : in  std_logic;  -- Data is valid
         vcFrameRxSOF   : in  std_logic;  -- Data is SOF
         vcFrameRxEOF   : in  std_logic;  -- Data is EOF
         vcFrameRxEOFE  : in  std_logic;  -- Data is EOF with Error
         vcFrameRxData  : in  std_logic_vector(15 downto 0);  -- Data
         vcLocBuffAFull : out std_logic;  -- Local buffer almost full
         vcLocBuffFull  : out std_logic;  -- Local buffer full
         cmdEn          : out std_logic;  -- Command Enable
         cmdOpCode      : out std_logic_vector(7 downto 0);  -- Command OpCode
         cmdCtxOut      : out std_logic_vector(23 downto 0)  -- Command Context
         );
   end component;

   -- Downstream Buffer
   component Pgp2DsBuff
      generic (
         -- FifoType: (default = V5)
         -- V4 = Virtex 4,  V5 = Virtex 5, V6 = Virtex 6, V7 = Virtex 7, 
         -- S6 = Spartan 6, A7 = Artix 7,  K7 = kintex7
         FifoType : string := "V5"
         );
      port (
         pgpClk         : in  std_logic;
         pgpReset       : in  std_logic;
         locClk         : in  std_logic;
         locReset       : in  std_logic;
         vcFrameRxValid : in  std_logic;
         vcFrameRxSOF   : in  std_logic;
         vcFrameRxEOF   : in  std_logic;
         vcFrameRxEOFE  : in  std_logic;
         vcFrameRxData  : in  std_logic_vector(15 downto 0);
         vcLocBuffAFull : out std_logic;
         vcLocBuffFull  : out std_logic;
         frameRxValid   : out std_logic;
         frameRxReady   : in  std_logic;
         frameRxSOF     : out std_logic;
         frameRxEOF     : out std_logic;
         frameRxEOFE    : out std_logic;
         frameRxData    : out std_logic_vector(15 downto 0)
         );
   end component;


   -- Upstream Buffer: 16-bit wide
   component Pgp2UsBuff
      generic (
         -- FifoType: (default = V5)
         -- V4 = Virtex 4,  V5 = Virtex 5, V6 = Virtex 6, V7 = Virtex 7, 
         -- S6 = Spartan 6, A7 = Artix 7,  K7 = kintex7
         FifoType : string := "V5"
         );
      port (
         pgpClk         : in  std_logic;
         pgpReset       : in  std_logic;
         locClk         : in  std_logic;
         locReset       : in  std_logic;
         frameTxValid   : in  std_logic;
         frameTxSOF     : in  std_logic;
         frameTxEOF     : in  std_logic;
         frameTxEOFE    : in  std_logic;
         frameTxData    : in  std_logic_vector(15 downto 0);
         frameTxAFull   : out std_logic;
         vcFrameTxValid : out std_logic;
         vcFrameTxReady : in  std_logic;
         vcFrameTxSOF   : out std_logic;
         vcFrameTxEOF   : out std_logic;
         vcFrameTxEOFE  : out std_logic;
         vcFrameTxData  : out std_logic_vector(15 downto 0);
         vcRemBuffAFull : in  std_logic;
         vcRemBuffFull  : in  std_logic
         );
   end component;

   -- Upstream Buffer: 32-bit wide
   component Pgp2Us32Buff
      generic (
         -- FifoType: (default = V5)
         -- V4 = Virtex 4,  V5 = Virtex 5, V6 = Virtex 6, V7 = Virtex 7, 
         -- S6 = Spartan 6, A7 = Artix 7,  K7 = kintex7
         FifoType : string := "V5"
         );
      port (
         pgpClk         : in  std_logic;
         pgpReset       : in  std_logic;
         locClk         : in  std_logic;
         locReset       : in  std_logic;
         frameTxValid   : in  std_logic;
         frameTxSOF     : in  std_logic;
         frameTxEOF     : in  std_logic;
         frameTxEOFE    : in  std_logic;
         frameTxData    : in  std_logic_vector(31 downto 0);
         frameTxAFull   : out std_logic;
         vcFrameTxValid : out std_logic;
         vcFrameTxReady : in  std_logic;
         vcFrameTxSOF   : out std_logic;
         vcFrameTxEOF   : out std_logic;
         vcFrameTxEOFE  : out std_logic;
         vcFrameTxData  : out std_logic_vector(15 downto 0);
         vcRemBuffAFull : in  std_logic;
         vcRemBuffFull  : in  std_logic
         );
   end component;

end Pgp2AppPackage;

