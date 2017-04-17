-------------------------------------------------------------------------------
-- File       : Pgp2bPkg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2009-05-27
-- Last update: 2017-03-28
-------------------------------------------------------------------------------
-- Description:
-- PGP ID and other global constants.
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
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
   constant SSI_PGP2B_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(2, TKEEP_COMP_C);

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

   type Pgp2bRxInType is record
      flush    : sl;  -- Flush the link
      resetRx  : sl;
      loopback : slv(2 downto 0);
   end record Pgp2bRxInType;

   type Pgp2bRxInArray is array (natural range <>) of Pgp2bRxInType;

   constant PGP2B_RX_IN_INIT_C : Pgp2bRxInType := (
      '0',
      '0',
      "000"
   );

   type Pgp2bRxOutType is record
      phyRxReady    : sl;                -- RX Phy is ready
      linkReady     : sl;                -- Local side has link
      linkPolarity  : slv(1 downto 0);   -- Receive link polarity
      frameRx       : sl;                -- A good frame was received
      frameRxErr    : sl;                -- An errored frame was received
      cellError     : sl;                -- A cell error has occured
      linkDown      : sl;                -- A link down event has occured
      linkError     : sl;                -- A link error has occured
      opCodeEn      : sl;                -- Opcode receive enable
      opCode        : slv(7 downto 0);   -- Opcode receive value
      remLinkReady  : sl;                -- Far end side has link
      remLinkData   : slv(7 downto 0);   -- Far end side User Data
      remOverflow   : slv(3 downto 0);   -- Far end overflow status
      remPause      : slv(3 downto 0);   -- Far end pause status
   end record Pgp2bRxOutType;

   type Pgp2bRxOutArray is array (natural range <>) of Pgp2bRxOutType;

   constant PGP2B_RX_OUT_INIT_C : Pgp2bRxOutType := (
      '0',
      '0',
      "00",
      '0',
      '0',
      '0',
      '0',
      '0',
      '0',
      (others => '0'),
      '0',
      (others => '0'),
      (others => '0'),
      (others => '0')
   );

   -----------------------------------------------------
   -- PGP2B TX non-data types
   -----------------------------------------------------

   type Pgp2bTxInType is record
      flush           : sl;                -- Flush the link
      opCodeEn        : sl;                -- Opcode receive enable
      opCode          : slv(7 downto 0);   -- Opcode receive value
      locData         : slv(7 downto 0);   -- Near end side User Data
      flowCntlDis     : sl;                -- Ignore flow control 
   end record Pgp2bTxInType;

   type Pgp2bTxInArray is array (natural range <>) of Pgp2bTxInType;

   constant PGP2B_TX_IN_INIT_C : Pgp2bTxInType := (
      '0',
      '0',
      (others => '0'),
      (others => '0'),
      '0'
   ); 

   constant PGP2B_TX_IN_HALF_DUPLEX_C : Pgp2bTxInType := (
      '0',
      '0',
      (others => '0'),
      (others => '0'),
      '1'
   );    

   type Pgp2bTxOutType is record
      locOverflow : slv(3 downto 0);   -- Local overflow status
      locPause    : slv(3 downto 0);   -- Local pause status
      phyTxReady  : sl;                -- TX Phy is ready
      linkReady   : sl;                -- Local side has link
      frameTx     : sl;                -- A good frame was transmitted
      frameTxErr  : sl;                -- An errored frame was transmitted
   end record Pgp2bTxOutType;

   type Pgp2bTxOutArray is array (natural range <>) of Pgp2bTxOutType;

   constant PGP2B_TX_OUT_INIT_C : Pgp2bTxOutType := (
      (others => '0'),
      (others => '0'),
      '0',
      '0',
      '0',
      '0'
   );                

   -----------------------------------------------------
   -- PGP2B RX Phy types
   -----------------------------------------------------

   type Pgp2bRxPhyLaneOutType is record
      polarity : sl;                    -- PHY receive signal polarity
   end record Pgp2bRxPhyLaneOutType;

   type Pgp2bRxPhyLaneOutArray is array (natural range <>) of Pgp2bRxPhyLaneOutType;

   constant PGP2B_RX_PHY_LANE_OUT_INIT_C : Pgp2bRxPhyLaneOutType := (
      (others => '0')
   );   

   type Pgp2bRxPhyLaneInType is record
      data    : slv(15 downto 0);       -- PHY receive data
      dataK   : slv(1 downto 0);        -- PHY receive data is K character
      dispErr : slv(1 downto 0);        -- PHY receive data has disparity error
      decErr  : slv(1 downto 0);        -- PHY receive data not in table
   end record Pgp2bRxPhyLaneInType;

   type Pgp2bRxPhyLaneInArray is array (natural range <>) of Pgp2bRxPhyLaneInType;

   constant PGP2B_RX_PHY_LANE_IN_INIT_C : Pgp2bRxPhyLaneInType := (
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0')
   );    

   -----------------------------------------------------
   -- PGP2B TX Phy types
   -----------------------------------------------------

   type Pgp2bTxPhyLaneOutType is record
      data  : slv(15 downto 0);         -- PHY transmit data
      dataK : slv(1 downto 0);          -- PHY transmit data is K character
   end record Pgp2bTxPhyLaneOutType;

   type Pgp2bTxPhyLaneOutArray is array (natural range <>) of Pgp2bTxPhyLaneOutType;

   constant PGP2B_TX_PHY_LANE_OUT_INIT_C : Pgp2bTxPhyLaneOutType := (
      (others => '0'),
      (others => '0')
   );    
   
end Pgp2bPkg;

