-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol, Core Package
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : Pgp2bPkg.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 05/27/2009
-------------------------------------------------------------------------------
-- Description:
-- PGP ID and other global constants.
-------------------------------------------------------------------------------
-- Copyright (c) 2006 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 05/27/2009: created.
-- 11/23/2009: Renamed package.
-- 12/13/2010: Added received init line to help linking.
-- 06/25/2010: Added payload size config as generic.
-- 05/18/2012: Added VC transmit timeout
-- 04/04/2014: Changes for pgp2b
-------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

package Pgp2bPkg is

   -----------------------------------------------------
   -- Constants
   -----------------------------------------------------
   constant SSI_PGP_CONFIG_G : AxiStreamConfigType := ssiAxiStreamConfig(2);

   -- 8B10B Characters
   constant K_COM_C  : slv(7 downto 0) := "10111100"; -- K28.5, 0xBC
   constant K_LTS_C  : slv(7 downto 0) := "00111100"; -- K28.1, 0x3C
   constant D_102_C  : slv(7 downto 0) := "01001010"; -- D10.2, 0x4A
   constant D_215_C  : slv(7 downto 0) := "10110101"; -- D21.5, 0xB5
   constant K_SKP_C  : slv(7 downto 0) := "00011100"; -- K28.0, 0x1C
   constant K_OTS_C  : slv(7 downto 0) := "01111100"; -- K28.3, 0x7C
   constant K_ALN_C  : slv(7 downto 0) := "11011100"; -- K28.6, 0xDC
   constant K_SOC_C  : slv(7 downto 0) := "11111011"; -- K27.7, 0xFB
   constant K_SOF_C  : slv(7 downto 0) := "11110111"; -- K23.7, 0xF7
   constant K_EOF_C  : slv(7 downto 0) := "11111101"; -- K29.7, 0xFD
   constant K_EOFE_C : slv(7 downto 0) := "11111110"; -- K30.7, 0xFE
   constant K_EOC_C  : slv(7 downto 0) := "01011100"; -- K28.2, 0x5C

   -- ID Constant
   constant PGP2B_ID_C : slv(3 downto 0) := "0101";

   -----------------------------------------------------
   -- PGP RX non-data types
   -----------------------------------------------------

   type PgpRxInType is record
      flush   : sl;                     -- Flush the link
      resetRx : sl;
   end record PgpRxInType;

   type PgpRxInArray is array (natural range <>) of PgpRxInType;

   constant PGP_RX_IN_INIT_C : PgpRxInType := (
      '0',
      '0'
   );

   type PgpRxOutType is record
      linkReady     : sl;                -- Local side has link
      cellError     : sl;                -- A cell error has occured
      linkDown      : sl;                -- A link down event has occured
      linkError     : sl;                -- A link error has occured
      opCodeEn      : sl;                -- Opcode receive enable
      opCode        : slv(7 downto 0);   -- Opcode receive value
      remLinkReady  : sl;                -- Far end side has link
      remLinkData   : slv(7 downto 0);   -- Far end side User Data
      remOverFlow   : slv(3 downto 0);   -- Far end overflow status
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
      (others => '0'),
      (others => '0')
   );

   -----------------------------------------------------
   -- PGP TX non-data types
   -----------------------------------------------------

   type PgpTxInType is record
      flush         : sl;                -- Flush the link
      opCodeEn      : sl;                -- Opcode receive enable
      opCode        : slv(7 downto 0);   -- Opcode receive value
      locLinkReady  : sl;                -- Near end side has link
      locData       : slv(7 downto 0);   -- Near end side User Data
   end record PgpTxInType;

   type PgpTxInArray is array (natural range <>) of PgpTxInType;

   constant PGP_TX_IN_INIT_C : PgpTxInType := (
      '0',
      '0',
      (others => '0'),
      '0',
      (others => '0')
   );               

   type PgpTxOutType is record
      linkReady : sl;                   -- Local side has link
   end record PgpTxOutType;

   type PgpTxOutArray is array (natural range <>) of PgpTxOutType;

   constant PGP_TX_OUT_INIT_C : PgpTxOutType := (
      (others => '0')
   );                

   -----------------------------------------------------
   -- PGP RX Phy types
   -----------------------------------------------------

   type PgpRxPhyLaneOutType is record
      polarity : sl;                    -- PHY receive signal polarity
   end record PgpRxPhyLaneOutType;

   type PgpRxPhyLaneOutArray is array (natural range <>) of PgpRxPhyLaneOutType;

   constant PGP_RX_PHY_LANE_OUT_INIT_C : PgpRxPhyLaneOutType := (
      (others => '0')
   );   

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
      (others => '0')
   );    

   -----------------------------------------------------
   -- PGP TX Phy types
   -----------------------------------------------------

   type PgpTxPhyLaneOutType is record
      data  : slv(15 downto 0);         -- PHY transmit data
      dataK : slv(1 downto 0);          -- PHY transmit data is K character
   end record PgpTxPhyLaneOutType;

   type PgpTxPhyLaneOutArray is array (natural range <>) of PgpTxPhyLaneOutType;

   constant PGP_TX_PHY_LANE_OUT_INIT_C : PgpTxPhyLaneOutType := (
      (others => '0'),
      (others => '0')
   );    

end Pgp2bPkg;

