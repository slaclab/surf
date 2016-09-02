-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol, V2, MGT Wrapper
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : Pgp2Mgt16Model.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 05/27/2009
-------------------------------------------------------------------------------
-- Description:
-- VHDL source file containing the PGP, MGT and CRC blocks.
-- This module supports a standard PGP implementation where a single MGT
-- supports a bi-directional link. Both links operated at the same speed.
-------------------------------------------------------------------------------
-- This file is part of 'SLAC PGP2 Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC PGP2 Core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
-- Modification history:
-- 05/27/2009: created.
-- 01/13/2010: Added received init line to help linking.
-------------------------------------------------------------------------------

LIBRARY ieee;
use work.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;

entity Pgp2Mgt16Model is 
   generic (
      EnShortCells : integer := 1;         -- Enable short non-EOF cells
      VcInterleave : integer := 1;         -- Interleave Frames
      MgtMode      : string  := "A";       -- Default Location
      RefClkSel    : string  := "REFCLK1"  -- Reference Clock To Use "REFCLK1" or "REFCLK2"
   );
   port (

      -- System clock, reset & control
      pgpClk            : in  std_logic;                     -- 156.25Mhz master clock
      pgpReset          : in  std_logic;                     -- Synchronous reset input

      -- PLL Reset Control
      pllTxRst          : in  std_logic;                     -- Reset transmit PLL logic
      pllRxRst          : in  std_logic;                     -- Reset receive  PLL logic

      -- PLL Lock Status
      pllRxReady        : out std_logic;                     -- MGT Receive logic is ready
      pllTxReady        : out std_logic;                     -- MGT Transmit logic is ready

      -- Sideband data
      pgpRemData        : out std_logic_vector(7 downto 0);  -- Far end side User Data
      pgpLocData        : in  std_logic_vector(7 downto 0);  -- Far end side User Data

      -- Opcode Transmit Interface
      pgpTxOpCodeEn     : in  std_logic;                     -- Opcode receive enable
      pgpTxOpCode       : in  std_logic_vector(7 downto 0);  -- Opcode receive value

      -- Opcode Receive Interface
      pgpRxOpCodeEn     : out std_logic;                     -- Opcode receive enable
      pgpRxOpCode       : out std_logic_vector(7 downto 0);  -- Opcode receive value

      -- Link status
      pgpLocLinkReady   : out std_logic;                     -- Local Link is ready
      pgpRemLinkReady   : out std_logic;                     -- Far end side has link

      -- Error Flags, one pulse per event
      pgpRxCellError    : out std_logic;                     -- A cell error has occured
      pgpRxLinkDown     : out std_logic;                     -- A link down event has occured
      pgpRxLinkError    : out std_logic;                     -- A link error has occured

      -- Frame Transmit Interface, VC 0
      vc0FrameTxValid   : in  std_logic;                     -- User frame data is valid
      vc0FrameTxReady   : out std_logic;                     -- PGP is ready
      vc0FrameTxSOF     : in  std_logic;                     -- User frame data start of frame
      vc0FrameTxEOF     : in  std_logic;                     -- User frame data end of frame
      vc0FrameTxEOFE    : in  std_logic;                     -- User frame data error
      vc0FrameTxData    : in  std_logic_vector(15 downto 0); -- User frame data
      vc0LocBuffAFull   : in  std_logic;                     -- Remote buffer almost full
      vc0LocBuffFull    : in  std_logic;                     -- Remote buffer full

      -- Frame Transmit Interface, VC 1
      vc1FrameTxValid   : in  std_logic;                     -- User frame data is valid
      vc1FrameTxReady   : out std_logic;                     -- PGP is ready
      vc1FrameTxSOF     : in  std_logic;                     -- User frame data start of frame
      vc1FrameTxEOF     : in  std_logic;                     -- User frame data end of frame
      vc1FrameTxEOFE    : in  std_logic;                     -- User frame data error
      vc1FrameTxData    : in  std_logic_vector(15 downto 0); -- User frame data
      vc1LocBuffAFull   : in  std_logic;                     -- Remote buffer almost full
      vc1LocBuffFull    : in  std_logic;                     -- Remote buffer full

      -- Frame Transmit Interface, VC 2
      vc2FrameTxValid   : in  std_logic;                     -- User frame data is valid
      vc2FrameTxReady   : out std_logic;                     -- PGP is ready
      vc2FrameTxSOF     : in  std_logic;                     -- User frame data start of frame
      vc2FrameTxEOF     : in  std_logic;                     -- User frame data end of frame
      vc2FrameTxEOFE    : in  std_logic;                     -- User frame data error
      vc2FrameTxData    : in  std_logic_vector(15 downto 0); -- User frame data
      vc2LocBuffAFull   : in  std_logic;                     -- Remote buffer almost full
      vc2LocBuffFull    : in  std_logic;                     -- Remote buffer full

      -- Frame Transmit Interface, VC 3
      vc3FrameTxValid   : in  std_logic;                     -- User frame data is valid
      vc3FrameTxReady   : out std_logic;                     -- PGP is ready
      vc3FrameTxSOF     : in  std_logic;                     -- User frame data start of frame
      vc3FrameTxEOF     : in  std_logic;                     -- User frame data end of frame
      vc3FrameTxEOFE    : in  std_logic;                     -- User frame data error
      vc3FrameTxData    : in  std_logic_vector(15 downto 0); -- User frame data
      vc3LocBuffAFull   : in  std_logic;                     -- Remote buffer almost full
      vc3LocBuffFull    : in  std_logic;                     -- Remote buffer full

      -- Common Frame Receive Interface For All VCs
      vcFrameRxSOF      : out std_logic;                     -- PGP frame data start of frame
      vcFrameRxEOF      : out std_logic;                     -- PGP frame data end of frame
      vcFrameRxEOFE     : out std_logic;                     -- PGP frame data error
      vcFrameRxData     : out std_logic_vector(15 downto 0); -- PGP frame data

      -- Frame Receive Interface, VC 0
      vc0FrameRxValid   : out std_logic;                     -- PGP frame data is valid
      vc0RemBuffAFull   : out std_logic;                     -- Remote buffer almost full
      vc0RemBuffFull    : out std_logic;                     -- Remote buffer full

      -- Frame Receive Interface, VC 1
      vc1FrameRxValid   : out std_logic;                     -- PGP frame data is valid
      vc1RemBuffAFull   : out std_logic;                     -- Remote buffer almost full
      vc1RemBuffFull    : out std_logic;                     -- Remote buffer full

      -- Frame Receive Interface, VC 2
      vc2FrameRxValid   : out std_logic;                     -- PGP frame data is valid
      vc2RemBuffAFull   : out std_logic;                     -- Remote buffer almost full
      vc2RemBuffFull    : out std_logic;                     -- Remote buffer full

      -- Frame Receive Interface, VC 3
      vc3FrameRxValid   : out std_logic;                     -- PGP frame data is valid
      vc3RemBuffAFull   : out std_logic;                     -- Remote buffer almost full
      vc3RemBuffFull    : out std_logic;                     -- Remote buffer full

      -- MGT loopback control
      mgtLoopback       : in  std_logic;                     -- MGT Serial Loopback Control

      -- MGT Signals, Drive Ref Clock Which Matches RefClkSel Generic Above
      mgtRefClk1        : in  std_logic;                     -- MGT Reference Clock In 1
      mgtRefClk2        : in  std_logic;                     -- MGT Reference Clock In 2
      mgtRxRecClk       : out std_logic;                     -- MGT Rx Recovered Clock
      mgtRxN            : in  std_logic;                     -- MGT Serial Receive Negative
      mgtRxP            : in  std_logic;                     -- MGT Serial Receive Positive
      mgtTxN            : out std_logic;                     -- MGT Serial Transmit Negative
      mgtTxP            : out std_logic;                     -- MGT Serial Transmit Positive

      -- MGT Signals For Simulation, 
      -- Drive mgtCombusIn to 0's, Leave mgtCombusOut open for real use
      mgtCombusIn       : in  std_logic_vector(15 downto 0);
      mgtCombusOut      : out std_logic_vector(15 downto 0)
   );

end Pgp2Mgt16Model;


-- Define architecture
architecture Pgp2Mgt16Model of Pgp2Mgt16Model is

   component Pgp2VcTest
      port (
         pgpRxClk          : in  std_logic;
         pgpRxRst          : in  std_logic;
         pgpTxClk          : in  std_logic;
         pgpTxRst          : in  std_logic;
         pgpLinkReady      : in  std_logic;
         vcTxValid         : out std_logic;
         vcTxReady         : in  std_logic;
         vcTxSOF           : out std_logic;
         vcTxEOF           : out std_logic;
         vcTxEOFE          : out std_logic;
         vcTxDataLow       : out std_logic_vector(31 downto 0);
         vcTxDataHigh      : out std_logic_vector(31 downto 0);
         vcLocBuffAFull    : out std_logic;
         vcLocBuffFull     : out std_logic;
         vcRxSOF           : in  std_logic;
         vcRxEOF           : in  std_logic;
         vcRxEOFE          : in  std_logic;
         vcRxDataLow       : in  std_logic_vector(31 downto 0);
         vcRxDataHigh      : in  std_logic_vector(31 downto 0);
         vcRxValid         : in  std_logic;
         vcRemBuffAFull    : in  std_logic;
         vcRemBuffFull     : in  std_logic;
         vcWidth           : in  std_logic_vector(1 downto 0);
         vcNum             : in  std_logic_vector(1 downto 0)
      );
   end component;

   -- Local signals
   signal intValid0        : std_logic;
   signal intReady0        : std_logic;

   -- Register delay for simulation
   constant tpd:time := 0.5 ns;

begin

   pllRxReady        <= '1';
   pllTxReady        <= '1';
   pgpRemData        <= (others=>'0');
   pgpRxOpCodeEn     <= '0';
   pgpRxOpCode       <= (others=>'0');
   pgpLocLinkReady   <= '1';
   pgpRemLinkReady   <= '1';
   pgpRxCellError    <= '0';
   pgpRxLinkDown     <= '0';
   pgpRxLinkError    <= '0';
   mgtRxRecClk       <= '0';
   mgtTxN            <= '0';
   mgtTxP            <= '0';
   mgtCombusOut      <= (others=>'0');

   -- VC 0
   vc0FrameRxValid <= intValid0 and (not vc0LocBuffAFull);
   intReady0       <= intValid0 and (not vc0LocBuffAFull);
   vc0FrameTxReady <= vc0FrameTxValid;
   vc0RemBuffAFull <= '0';
   vc0RemBuffFull  <= '0';

   -- VC0 Model
   U_Pgp2Vc0Test: Pgp2VcTest port map (
      pgpRxClk                  => pgpClk,
      pgpRxRst                  => pgpReset,
      pgpTxClk                  => pgpClk,
      pgpTxRst                  => pgpReset,
      pgpLinkReady              => '1',
      vcTxValid                 => intValid0,       
      vcTxReady                 => intReady0,
      vcTxSOF                   => vcFrameRxSOF,
      vcTxEOF                   => vcFrameRxEOF,
      vcTxEOFE                  => vcFrameRxEOFE,
      vcTxDataLow(15 downto  0) => vcFrameRxData,
      vcTxDataLow(31 downto 16) => open,
      vcTxDataHigh              => open,
      vcLocBuffAFull            => open,
      vcLocBuffFull             => open,
      vcRxSOF                   => vc0FrameTxSOF,
      vcRxEOF                   => vc0FrameTxEOF,
      vcRxEOFE                  => vc0FrameTxEOFE,
      vcRxDataLow(15 downto  0) => vc0FrameTxData,
      vcRxDataLow(31 downto 16) => (others=>'0'),
      vcRxDataHigh              => (others=>'0'),
      vcRxValid                 => vc0FrameTxValid,
      vcRemBuffAFull            => '0',
      vcRemBuffFull             => '0',
      vcWidth                   => "00",
      vcNum                     => "00"
   );

   vc1FrameTxReady   <= '0';
   vc2FrameTxReady   <= '0';
   vc3FrameTxReady   <= '0';
   vc1FrameRxValid   <= '0';
   vc1RemBuffAFull   <= '0';
   vc1RemBuffFull    <= '0';
   vc2FrameRxValid   <= '0';
   vc2RemBuffAFull   <= '0';
   vc2RemBuffFull    <= '0';
   vc3FrameRxValid   <= '0';
   vc3RemBuffAFull   <= '0';
   vc3RemBuffFull    <= '0';

end Pgp2Mgt16Model;

