-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Pgp2CoreTypesPkg.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-11-02
-- Last update: 2013-07-03
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2012 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.StdRtlPkg.all;

package Pgp2CoreTypesPkg is
   --------------------------------------------------------------------------------------------------
   -- Virtural Channel IO
   -- Always 4 VCs per lane
   -- Configurable number of lanes
   --------------------------------------------------------------------------------------------------
   type PgpTxVcInType is record
      frameTxValid : sl;           -- User frame data is valid
      frameTxSOF   : sl;           -- User frame data start of frame
      frameTxEOF   : sl;           -- User frame data end of frame
      frameTxEOFE  : sl;           -- User frame data error
      frameTxData  : slv16Array(0 to 3);  -- User frame data (up to 4 lanes)
      locBuffAFull : sl;           -- Remote buffer almost full
      locBuffFull  : sl;           -- Remote buffer full
   end record;
   constant PgpTxVcInInit : PgpTxVcInType := (
      '0',                              --frameTxValid
      '0',                              --frameTxSOF
      '0',                              --frameTxEOF
      '0',                              --frameTxEOFE
      (others => (others => '0')),      --frameTxData
      '0',                              --locBuffAFull
      '0');                             --locBuffFull     

   type PgpTxVcQuadInType is array (0 to 3) of PgpTxVcInType;  -- 4 Virtual Channel inputs
   type PgpTxVcQuadInArray is array (natural range <>) of PgpTxVcQuadInType;
   constant PgpTxVcQuadInInit : PgpTxVcQuadInType := (
      (others => PgpTxVcInInit)); 
      
   type PgpTxVcOutType is record
      frameTxReady : sl;         -- PGP is ready
   end record PgpTxVcOutType;
   constant PgpTxVcOutInit : PgpTxVcOutType := (
      (others => '0'));                 --frameTxReady  

   type PgpTxVcQuadOutType is array (0 to 3) of PgpTxVcOutType;
   type PgpTxVcQuadOutArray is array (natural range <>) of PgpTxVcQuadOutType;
   constant PgpTxVcQuadOutInit : PgpTxVcQuadOutType := (
      (others => PgpTxVcOutInit));    

   -- Signals common to all Rx Virtual Channels
   type PgpRxVcCommonOutType is record
      frameRxSOF  : sl;           -- PGP frame data start of frame
      frameRxEOF  : sl;           -- PGP frame data end of frame
      frameRxEOFE : sl;           -- PGP frame data error
      frameRxData : slv16Array(0 to 3);  -- PGP frame data
   end record PgpRxVcCommonOutType;
   type PgpRxVcCommonOutArray is array (natural range <>) of PgpRxVcCommonOutType;
   constant PgpRxVcCommonOutInit : PgpRxVcCommonOutType := (
      '0',                              --frameRxSOF
      '0',                              --frameRxEOF
      '0',                              --frameRxEOFE
      (others => (others => '0')));     --frameRxData   
      
   -- One Rx Virtual Channel output
   type PgpRxVcOutType is record
      frameRxValid : sl;         -- PGP frame data is valid
      remBuffAFull : sl;         -- Remote buffer almost full
      remBuffFull  : sl;         -- Remote buffer full
   end record PgpRxVcOutType;
   constant PgpRxVcOutInit : PgpRxVcOutType := (
      '0',                              --frameRxValid
      '0',                              --remBuffAFull
      '0');                             --remBuffFull   

   type PgpRxVcQuadOutType is array (0 to 3) of PgpRxVcOutType;  -- 4 Rx Virtual Channel outputs
   type PgpRxVcQuadOutArray is array (natural range <>) of PgpRxVcQuadOutType;
   constant PgpRxVcQuadOutInit : PgpRxVcQuadOutType := (
      (others => PgpRxVcOutInit));    

   --------------------------------------------------------------------------------------------------
   -- PGP Rx and Tx (inclides VC IO)
   --------------------------------------------------------------------------------------------------
   type PgpRxInType is record
      flush   : sl;              -- Flush the link
      resetRx : sl;
   end record PgpRxInType;
   constant PgpRxInInit : PgpRxInType := (
      '0',                              --flush
      '0');                             --resetRx      
   type PgpRxInArray is array (natural range <>) of PgpRxInType;

   type PgpRxOutType is record
      linkReady    : sl;         -- Local side has link
      cellError    : sl;         -- A cell error has occured
      linkDown     : sl;         -- A link down event has occured
      linkError    : sl;         -- A link error has occured
      opCodeEn     : sl;         -- Opcode receive enable
      opCode       : slv(7 downto 0);  -- Opcode receive value
      remLinkReady : sl;         -- Far end side has link
      remLinkData  : slv(7 downto 0);  -- Far end side User Data
   end record PgpRxOutType;
   constant PgpRxOutInit : PgpRxOutType := (
      '0',                              --linkReady
      '0',                              --cellError
      '0',                              --linkDown
      '0',                              --linkError
      '0',                              --opCodeEn
      (others => '0'),                  --opCode
      '0',                              --remLinkReady
      (others => '0'));                 --remLinkData      
   type PgpRxOutArray is array (natural range <>) of PgpRxOutType;

   type PgpTxInType is record
      flush        : sl;                     -- Flush the link
      opCodeEn     : sl;                     -- Opcode receive enable
      opCode       : slv(7 downto 0);  -- Opcode receive value
      locLinkReady : sl;                     -- Near end side has link
      locData      : slv(7 downto 0);  -- Near end side User Data
   end record PgpTxInType;
   constant PgpTxInInit : PgpTxInType := (
      '0',                              --flush
      '0',                              --opCodeEn
      (others => '0'),                  --opCode
      '0',                              --locLinkReady
      (others => '0'));                 --locData    
   type PgpTxInArray is array (natural range <>) of PgpTxInType;

   type PgpTxOutType is record
      linkReady : sl;            -- Local side has link
   end record PgpTxOutType;
   constant PgpTxOutInit : PgpTxOutType := (
      (others => '0'));                 --linkReady     
   type PgpTxOutArray is array (natural range <>) of PgpTxOutType;
   
   --------------------------------------------------------------------------------------------------
   -- Pgp PHY IO
   --------------------------------------------------------------------------------------------------
   type PgpRxPhyLaneOutType is record
      polarity : sl;             -- PHY receive signal polarity
   end record PgpRxPhyLaneOutType;
   type PgpRxPhyLaneOutArray is array (natural range <>) of PgpRxPhyLaneOutType;


   type PgpRxPhyLaneInType is record
      data    : slv(15 downto 0);  -- PHY receive data
      dataK   : slv(1 downto 0);  -- PHY receive data is K character
      dispErr : slv(1 downto 0);  -- PHY receive data has disparity error
      decErr  : slv(1 downto 0);  -- PHY receive data not in table
   end record PgpRxPhyLaneInType;
   type PgpRxPhyLaneInArray is array (natural range <>) of PgpRxPhyLaneInType;


   type PgpTxPhyLaneOutType is record
      data  : slv(15 downto 0);  -- PHY transmit data
      dataK : slv(1 downto 0);  -- PHY transmit data is K character
   end record PgpTxPhyLaneOutType;
   type PgpTxPhyLaneOutArray is array (natural range <>) of PgpTxPhyLaneOutType;

   --------------------------------------------------------------------------------------------------
   -- PGP Cell IO
   --------------------------------------------------------------------------------------------------
   -- Used by both RxCell and TxCell (in opposite directions)
   type PgpCellCtrlType is record
      pause : sl;                -- Cell data pause (Not used by Tx)
      soc   : sl;                -- Cell data start of cell
      sof   : sl;                -- Cell data start of frame
      eoc   : sl;                -- Cell data end of cell
      eof   : sl;                -- Cell data end of frame
      eofe  : sl;                -- Cell data end of frame error
   end record PgpCellCtrlType;

   subtype PgpCellDataType is slv16Array;  -- Cell Data (16 bits per lane)

   --------------------------------------------------------------------------------------------------
   -- PGP Sched IO
   --------------------------------------------------------------------------------------------------
   type PgpTxSchedInType is record
      sof : sl;                  -- Cell contained SOF
      eof : sl;                  -- Cell contained EOF
      ack : sl;                  -- Cell transmit acknowledge
   end record PgpTxSchedInType;

   type PgpTxSchedOutType is record
      idle    : sl;                     -- Force IDLE transmit
      req     : sl;                     -- Cell transmit request
      timeout : sl;                     -- Cell transmit timeout
      dataVc  : slv(1 downto 0);  -- Cell transmit virtual channel
   end record PgpTxSchedOutType;


   --------------------------------------------------------------------------------------------------
   -- CRC Type
   --------------------------------------------------------------------------------------------------
   type PgpCrcInType is record
      crcIn : slv(63 downto 0);  -- Receive data for CRC
      valid : sl;                -- Receive CRC width, 1=full, 0=32-bit
      width : sl;                -- Receive CRC value init
      init  : sl;                -- Receive data for CRC is valid
   end record PgpCrcInType;
   type PgpCrcInArray is array (natural range <>) of PgpCrcInType;

   -- Out type is 32 bit slv

   --------------------------------------------------------------------------------------------------

end package Pgp2CoreTypesPkg;
