-------------------------------------------------------------------------------
-- Title      : PGPv2fc: https://confluence.slac.stanford.edu/x/q86fD
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
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

library ieee;
use ieee.std_logic_1164.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

package Pgp2fcPkg is

   -----------------------------------------------------
   -- Constants
   -----------------------------------------------------
   constant PGP2FC_AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(2, TKEEP_COMP_C);

   -- 8B10B Characters
   constant K_FCD_C  : slv(7 downto 0) := "10111100";  -- K28.5, 0xBC
   constant K_LTS_C  : slv(7 downto 0) := "00111100";  -- K28.1, 0x3C
   constant D_102_C  : slv(7 downto 0) := "01001010";  -- D10.2, 0x4A
   constant D_215_C  : slv(7 downto 0) := "10110101";  -- D21.5, 0xB5
--   constant K_SKP_C  : slv(7 downto 0) := "00011100";  -- K28.0, 0x1C
--   constant K_OTS_C  : slv(7 downto 0) := "01111100";  -- K28.3, 0x7C
--   constant K_ALN_C  : slv(7 downto 0) := "11011100";  -- K28.6, 0xDC
   constant K_SOC_C  : slv(7 downto 0) := "11111011";  -- K27.7, 0xFB
   constant K_SOF_C  : slv(7 downto 0) := "11110111";  -- K23.7, 0xF7
   constant K_EOF_C  : slv(7 downto 0) := "11111101";  -- K29.7, 0xFD
   constant K_EOFE_C : slv(7 downto 0) := "11111110";  -- K30.7, 0xFE
   constant K_EOC_C  : slv(7 downto 0) := "01011100";  -- K28.2, 0x5C

   -- ID Constant
   constant PGP2FC_ID_C : slv(3 downto 0) := "0111";

   constant MAX_FC_WORDS_C : integer := 8;
   constant MAX_FC_BITS_C  : integer := MAX_FC_WORDS_C * 16;

   -----------------------------------------------------
   -- PGP RX non-data types
   -----------------------------------------------------

   type Pgp2fcRxInType is record
      flush    : sl;                    -- Flush the link
      resetRx  : sl;                    -- Reset RX transceiver path
      loopback : slv(2 downto 0);       -- Transceiver loopback
   end record Pgp2fcRxInType;

   type Pgp2fcRxInArray is array (natural range <>) of Pgp2fcRxInType;

   constant PGP2FC_RX_IN_INIT_C : Pgp2fcRxInType := (
      flush    => '0',
      resetRx  => '0',
      loopback => "000");

   type Pgp2fcRxOutType is record
      phyRxReady   : sl;                             -- RX Phy is ready
      linkReady    : sl;                             -- Local side has link
      frameRx      : sl;                             -- A good frame was received
      frameRxErr   : sl;                             -- An errored frame was received
      cellError    : sl;                             -- A cell error has occured
      linkDown     : sl;                             -- A link down event has occured
      linkError    : sl;                             -- A link error has occured
      fcValid      : sl;                             -- Fast Control word received
      fcError      : sl;                             -- Fast Control word received with error
      fcWord       : slv(MAX_FC_BITS_C-1 downto 0);  -- Fast control word
      remLinkReady : sl;                             -- Far end side has link
      remLinkData  : slv(7 downto 0);                -- Far end side User Data
      remOverflow  : slv(3 downto 0);                -- Far end overflow status
      remPause     : slv(3 downto 0);                -- Far end pause status
   end record Pgp2fcRxOutType;

   type Pgp2fcRxOutArray is array (natural range <>) of Pgp2fcRxOutType;

   constant PGP2FC_RX_OUT_INIT_C : Pgp2fcRxOutType := (
      phyRxReady   => '0',
      linkReady    => '0',
      frameRx      => '0',
      frameRxErr   => '0',
      cellError    => '0',
      linkDown     => '0',
      linkError    => '0',
      fcValid      => '0',
      fcError      => '0',
      fcWord       => (others => '0'),
      remLinkReady => '0',
      remLinkData  => (others => '0'),
      remOverflow  => (others => '0'),
      remPause     => (others => '0'));

   -----------------------------------------------------
   -- PGP2FC TX non-data types
   -----------------------------------------------------

   type Pgp2fcTxInType is record
      flush       : sl;                             -- Flush the link
      fcValid     : sl;                             -- Fast Control word send
      fcWord      : slv(MAX_FC_BITS_C-1 downto 0);  -- Fast Control word
      locData     : slv(7 downto 0);                -- Near end side User Data
      flowCntlDis : sl;                             -- Ignore flow control
      resetTx     : sl;                             -- Reset tx phy
      resetGt     : sl;
   end record Pgp2fcTxInType;

   type Pgp2fcTxInArray is array (natural range <>) of Pgp2fcTxInType;

   constant PGP2FC_TX_IN_INIT_C : Pgp2fcTxInType := (
      flush       => '0',
      fcValid     => '0',
      fcWord      => (others => '0'),
      locData     => (others => '0'),
      flowCntlDis => '0',
      resetTx     => '0',
      resetGt     => '0');

   constant PGP2FC_TX_IN_HALF_DUPLEX_C : Pgp2fcTxInType := (
      flush       => '0',
      fcValid     => '0',
      fcWord      => (others => '0'),
      locData     => (others => '0'),
      flowCntlDis => '1',
      resetTx     => '0',
      resetGt     => '0');

   type Pgp2fcTxOutType is record
      locOverflow : slv(3 downto 0);    -- Local overflow status
      locPause    : slv(3 downto 0);    -- Local pause status
      phyTxReady  : sl;                 -- TX Phy is ready
      linkReady   : sl;                 -- Local side has link
      fcSent      : sl;                 -- Fast Control word sent
      frameTx     : sl;                 -- A good frame was transmitted
      frameTxErr  : sl;                 -- An errored frame was transmitted
   end record Pgp2fcTxOutType;

   type Pgp2fcTxOutArray is array (natural range <>) of Pgp2fcTxOutType;

   constant PGP2FC_TX_OUT_INIT_C : Pgp2fcTxOutType := (
      locOverflow => (others => '0'),
      locPause    => (others => '0'),
      phyTxReady  => '0',
      linkReady   => '0',
      fcSent      => '0',
      frameTx     => '0',
      frameTxErr  => '0');

   -----------------------------------------------------
   -- PGP2FC RX Phy types
   -----------------------------------------------------

   type Pgp2fcRxPhyLaneInType is record
      data    : slv(15 downto 0);       -- PHY receive data
      dataK   : slv(1 downto 0);        -- PHY receive data is K character
      dispErr : slv(1 downto 0);        -- PHY receive data has disparity error
      decErr  : slv(1 downto 0);        -- PHY receive data not in table
   end record Pgp2fcRxPhyLaneInType;

   type Pgp2fcRxPhyLaneInArray is array (natural range <>) of Pgp2fcRxPhyLaneInType;

   constant PGP2FC_RX_PHY_LANE_IN_INIT_C : Pgp2fcRxPhyLaneInType := (
      data    => (others => '0'),
      dataK   => (others => '0'),
      dispErr => (others => '0'),
      decErr  => (others => '0'));

   -----------------------------------------------------
   -- PGP2FC TX Phy types
   -----------------------------------------------------

   type Pgp2fcTxPhyLaneOutType is record
      data  : slv(15 downto 0);         -- PHY transmit data
      dataK : slv(1 downto 0);          -- PHY transmit data is K character
   end record Pgp2fcTxPhyLaneOutType;

   type Pgp2fcTxPhyLaneOutArray is array (natural range <>) of Pgp2fcTxPhyLaneOutType;

   constant PGP2FC_TX_PHY_LANE_OUT_INIT_C : Pgp2fcTxPhyLaneOutType := (
      data  => (others => '0'),
      datak => (others => '0'));

end Pgp2fcPkg;

