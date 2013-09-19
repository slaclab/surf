-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Pgp2CoreTypesPkg.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-11-02
-- Last update: 2013-07-16
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
   -- PGP Rx and Tx (includes VC IO)
   --------------------------------------------------------------------------------------------------
   type PgpRxInType is record
      flush   : sl;                     -- Flush the link
      resetRx : sl;
   end record PgpRxInType;
   type PgpRxInArray is array (natural range <>) of PgpRxInType;
   constant PGP_RX_IN_INIT_C : PgpRxInType := (
      '0',
      '0');                         

   type PgpRxOutType is record
      linkReady    : sl;                -- Local side has link
      cellError    : sl;                -- A cell error has occured
      linkDown     : sl;                -- A link down event has occured
      linkError    : sl;                -- A link error has occured
      opCodeEn     : sl;                -- Opcode receive enable
      opCode       : slv(7 downto 0);   -- Opcode receive value
      remLinkReady : sl;                -- Far end side has link
      remLinkData  : slv(7 downto 0);   -- Far end side User Data
   end record PgpRxOutType;
   type PgpRxOutArray is array (natural range <>) of PgpRxOutType;
   constant PGP_RX_OUT_INIT_C : PgpRxOutType := (
      '0',
      '0',
      '0',
      '0',
      '0',
      (others => '0'),
      '0',
      (others => '0'));                    

   type PgpTxInType is record
      flush        : sl;                -- Flush the link
      opCodeEn     : sl;                -- Opcode receive enable
      opCode       : slv(7 downto 0);   -- Opcode receive value
      locLinkReady : sl;                -- Near end side has link
      locData      : slv(7 downto 0);   -- Near end side User Data
   end record PgpTxInType;
   type PgpTxInArray is array (natural range <>) of PgpTxInType;
   constant PGP_TX_IN_INIT_C : PgpTxInType := (
      '0',
      '0',
      (others => '0'),
      '0',
      (others => '0'));               

   type PgpTxOutType is record
      linkReady : sl;                   -- Local side has link
   end record PgpTxOutType;
   type PgpTxOutArray is array (natural range <>) of PgpTxOutType;
   constant PGP_TX_OUT_INIT_C : PgpTxOutType := (
      (others => '0'));                

   --------------------------------------------------------------------------------------------------
   -- Pgp PHY IO
   --------------------------------------------------------------------------------------------------
   type PgpRxPhyLaneOutType is record
      polarity : sl;                    -- PHY receive signal polarity
   end record PgpRxPhyLaneOutType;
   type PgpRxPhyLaneOutArray is array (natural range <>) of PgpRxPhyLaneOutType;
   constant PGP_RX_PHY_LANE_OUT_INIT_C : PgpRxPhyLaneOutType := (
      (others => '0'));   

   type PgpRxPhyLaneInType is record
      data    : slv(15 downto 0);       -- PHY receive data
      dataK   : slv(1 downto 0);        -- PHY receive data is K character
      dispErr : slv(1 downto 0);        -- PHY receive data has disparity error
      decErr  : slv(1 downto 0);        -- PHY receive data not in table
   end record PgpRxPhyLaneInType;
   type PgpRxPhyLaneInArray is array (natural range <>) of PgpRxPhyLaneInType;
   constant PGP_RX_PHY_LANE_IN_INIT_C : PgpRxPhyLaneInType := (
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'));    

   type PgpTxPhyLaneOutType is record
      data  : slv(15 downto 0);         -- PHY transmit data
      dataK : slv(1 downto 0);          -- PHY transmit data is K character
   end record PgpTxPhyLaneOutType;
   type PgpTxPhyLaneOutArray is array (natural range <>) of PgpTxPhyLaneOutType;
   constant PGP_TX_PHY_LANE_OUT_INIT_C : PgpTxPhyLaneOutType := (
      (others => '0'),
      (others => '0'));    

   --------------------------------------------------------------------------------------------------
   -- PGP Cell IO
   --------------------------------------------------------------------------------------------------
   -- Used by both RxCell and TxCell (in opposite directions)
   type PgpCellCtrlType is record
      pause : sl;                       -- Cell data pause (Not used by Tx)
      soc   : sl;                       -- Cell data start of cell
      sof   : sl;                       -- Cell data start of frame
      eoc   : sl;                       -- Cell data end of cell
      eof   : sl;                       -- Cell data end of frame
      eofe  : sl;                       -- Cell data end of frame error
   end record PgpCellCtrlType;

   subtype PgpCellDataType is slv16Array;  -- Cell Data (16 bits per lane)

   --------------------------------------------------------------------------------------------------
   -- PGP Sched IO
   --------------------------------------------------------------------------------------------------
   type PgpTxSchedInType is record
      sof : sl;                         -- Cell contained SOF
      eof : sl;                         -- Cell contained EOF
      ack : sl;                         -- Cell transmit acknowledge
   end record PgpTxSchedInType;

   type PgpTxSchedOutType is record
      idle    : sl;                     -- Force IDLE transmit
      req     : sl;                     -- Cell transmit request
      timeout : sl;                     -- Cell transmit timeout
      dataVc  : slv(1 downto 0);        -- Cell transmit virtual channel
   end record PgpTxSchedOutType;


   --------------------------------------------------------------------------------------------------
   -- CRC Type
   --------------------------------------------------------------------------------------------------
   type PgpCrcInType is record
      crcIn : slv(63 downto 0);         -- Receive data for CRC
      valid : sl;                       -- Receive CRC width, 1=full, 0=32-bit
      width : sl;                       -- Receive CRC value init
      init  : sl;                       -- Receive data for CRC is valid
   end record PgpCrcInType;
   type PgpCrcInArray is array (natural range <>) of PgpCrcInType;
   constant PGP_CRC_IN_INIT_C : PgpCrcInType := (
      (others => '0'),
      '0',
      '0',
      '0');    

   -- Out type is 32 bit slv

   --------------------------------------------------------------------------------------------------

end package Pgp2CoreTypesPkg;
