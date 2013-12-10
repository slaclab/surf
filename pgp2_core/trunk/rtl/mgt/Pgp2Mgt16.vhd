-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol, V2, MGT Wrapper
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : Pgp2Mgt16.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 05/27/2009
-------------------------------------------------------------------------------
-- Description:
-- VHDL source file containing the PGP, MGT and CRC blocks.
-- This module supports a standard PGP implementation where a single MGT
-- supports a bi-directional link. Both links operated at the same speed.
-------------------------------------------------------------------------------
-- Copyright (c) 2006 by Ryan Herbst. All rights reserved.
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
use work.Pgp2MgtPackage.all;
use work.Pgp2CorePackage.all;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;

entity Pgp2Mgt16 is 
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

      -- Frame state sync
      pgpFlush          : in  std_logic;                     -- Frame state sync

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
      mgtCombusOut      : out std_logic_vector(15 downto 0);

      -- MGT Dynamic Reconfiguration Port
      dclk              : in  std_logic; 
      den               : in  std_logic;
      dwen              : in  std_logic;
      daddr             : in  std_logic_vector( 7 downto 0);
      ddin              : in  std_logic_vector(15 downto 0);
      drdy              : out std_logic;
      ddout             : out std_logic_vector(15 downto 0);
      
      -- Debug
      debug             : out std_logic_vector(63 downto 0)
   );

end Pgp2Mgt16;


-- Define architecture
architecture Pgp2Mgt16 of Pgp2Mgt16 is

   -- Local Signals
   signal crcTxIn           : std_logic_vector(15 downto 0);
   signal crcTxInMgt        : std_logic_vector(63 downto 0);
   signal crcTxInit         : std_logic;
   signal crcTxValid        : std_logic;
   signal crcTxWidth        : std_logic_vector(2  downto 0);
   signal crcTxOut          : std_logic_vector(31 downto 0);
   signal crcRxIn           : std_logic_vector(15 downto 0);
   signal crcRxInMgt        : std_logic_vector(63 downto 0);
   signal crcRxInit         : std_logic;
   signal crcRxValid        : std_logic;
   signal crcRxWidth        : std_logic_vector(2  downto 0);
   signal crcRxOut          : std_logic_vector(31 downto 0);
   signal phyRxPolarity     : std_logic_vector(0 downto 0);
   signal phyRxData         : std_logic_vector(15 downto 0);
   signal phyRxDataK        : std_logic_vector(1  downto 0);
   signal phyTxData         : std_logic_vector(15 downto 0);
   signal phyTxDataK        : std_logic_vector(1  downto 0);
   signal mgtRxPmaReset     : std_logic;
   signal mgtTxPmaReset     : std_logic;
   signal mgtRxReset        : std_logic;
   signal mgtTxReset        : std_logic;
   signal mgtRxBuffError    : std_logic;
   signal mgtTxBuffError    : std_logic;
   signal phyRxDispErr      : std_logic_vector(1  downto 0);
   signal phyRxDecErr       : std_logic_vector(1  downto 0);
   signal mgtRxLock         : std_logic;
   signal mgtTxLock         : std_logic;
   signal crcRxReset        : std_logic;
   signal crcTxReset        : std_logic;
   signal intTxRst          : std_logic;
   signal intRxRst          : std_logic;
   signal phyRxReady        : std_logic;
   signal phyRxInit         : std_logic;
   signal phyTxReady        : std_logic;
   signal pgpRxLinkReady    : std_logic;
   signal pgpTxLinkReady    : std_logic;

   -- Register delay for simulation
   constant tpd:time := 0.5 ns;

begin

   -- Adapt CRC data width flag
   crcTxWidth <= "001";
   crcRxWidth <= "001";
   crcRxReset <= mgtRxReset;
   crcTxReset <= mgtTxReset;

   -- Pass CRC data in on proper bits
   crcTxInMgt(63 downto 56) <= crcTxIn(7  downto 0);
   crcTxInMgt(55 downto 48) <= crcTxIn(15 downto 8);
   crcTxInMgt(47 downto  0) <= (others=>'0');
   crcRxInMgt(63 downto 56) <= crcRxIn(7  downto 0);
   crcRxInMgt(55 downto 48) <= crcRxIn(15 downto 8);
   crcRxInMgt(47 downto  0) <= (others=>'0');

   -- Pll Resets
   intTxRst <= pllTxRst or pgpReset;
   intRxRst <= pllRxRst or pgpReset;

   -- PLL Lock
   pllRxReady <= phyRxReady;
   pllTxReady <= phyTxReady;

   -- Link Ready
   pgpLocLinkReady <= pgpRxLinkReady and pgpTxLinkReady;

   -- PGP Receive Core
   U_Pgp2Rx: entity work.Pgp2Rx 
      generic map (
         RxLaneCnt    => 1,
         EnShortCells => EnShortCells
      ) port map (
         pgpRxClk          => pgpClk,
         pgpRxReset        => pgpReset,
         pgpRxFlush        => pgpFlush,
         pgpRxLinkReady    => pgpRxLinkReady,
         pgpRxCellError    => pgpRxCellError,
         pgpRxLinkDown     => pgpRxLinkDown,
         pgpRxLinkError    => pgpRxLinkError,
         pgpRxOpCodeEn     => pgpRxOpCodeEn,
         pgpRxOpCode       => pgpRxOpCode,
         pgpRemLinkReady   => pgpRemLinkReady,
         pgpRemData        => pgpRemData,
         vcFrameRxSOF      => vcFrameRxSOF,
         vcFrameRxEOF      => vcFrameRxEOF,
         vcFrameRxEOFE     => vcFrameRxEOFE,
         vcFrameRxData     => vcFrameRxData,
         vc0FrameRxValid   => vc0FrameRxValid,
         vc0RemBuffAFull   => vc0RemBuffAFull,
         vc0RemBuffFull    => vc0RemBuffFull,
         vc1FrameRxValid   => vc1FrameRxValid,
         vc1RemBuffAFull   => vc1RemBuffAFull,
         vc1RemBuffFull    => vc1RemBuffFull,
         vc2FrameRxValid   => vc2FrameRxValid,
         vc2RemBuffAFull   => vc2RemBuffAFull,
         vc2RemBuffFull    => vc2RemBuffFull,
         vc3FrameRxValid   => vc3FrameRxValid,
         vc3RemBuffAFull   => vc3RemBuffAFull,
         vc3RemBuffFull    => vc3RemBuffFull,
         phyRxPolarity     => phyRxPolarity,
         phyRxData         => phyRxData,
         phyRxDataK        => phyRxDataK,
         phyRxDispErr      => phyRxDispErr,
         phyRxDecErr       => phyRxDecErr,
         phyRxReady        => phyRxReady,
         phyRxInit         => phyRxInit,
         crcRxIn           => crcRxIn,
         crcRxWidth        => open,
         crcRxInit         => crcRxInit,
         crcRxValid        => crcRxValid,
         crcRxOut          => crcRxOut,
         debug             => debug
      );


   -- PGP Transmit Core
   U_Pgp2Tx: entity work.Pgp2Tx 
      generic map (
         TxLaneCnt    => 1,
         VcInterleave => VcInterleave
      ) port map ( 
         pgpTxClk          => pgpClk,
         pgpTxReset        => pgpReset,
         pgpTxFlush        => pgpFlush,
         pgpTxLinkReady    => pgpTxLinkReady,
         pgpTxOpCodeEn     => pgpTxOpCodeEn,
         pgpTxOpCode       => pgpTxOpCode,
         pgpLocLinkReady   => pgpRxLinkReady,
         pgpLocData        => pgpLocData,
         vc0FrameTxValid   => vc0FrameTxValid,
         vc0FrameTxReady   => vc0FrameTxReady,
         vc0FrameTxSOF     => vc0FrameTxSOF,
         vc0FrameTxEOF     => vc0FrameTxEOF,
         vc0FrameTxEOFE    => vc0FrameTxEOFE,
         vc0FrameTxData    => vc0FrameTxData,
         vc0LocBuffAFull   => vc0LocBuffAFull,
         vc0LocBuffFull    => vc0LocBuffFull,
         vc1FrameTxValid   => vc1FrameTxValid,
         vc1FrameTxReady   => vc1FrameTxReady,
         vc1FrameTxSOF     => vc1FrameTxSOF,
         vc1FrameTxEOF     => vc1FrameTxEOF,
         vc1FrameTxEOFE    => vc1FrameTxEOFE,
         vc1FrameTxData    => vc1FrameTxData,
         vc1LocBuffAFull   => vc1LocBuffAFull,
         vc1LocBuffFull    => vc1LocBuffFull,
         vc2FrameTxValid   => vc2FrameTxValid,
         vc2FrameTxReady   => vc2FrameTxReady,
         vc2FrameTxSOF     => vc2FrameTxSOF,
         vc2FrameTxEOF     => vc2FrameTxEOF,
         vc2FrameTxEOFE    => vc2FrameTxEOFE,
         vc2FrameTxData    => vc2FrameTxData,
         vc2LocBuffAFull   => vc2LocBuffAFull,
         vc2LocBuffFull    => vc2LocBuffFull,
         vc3FrameTxValid   => vc3FrameTxValid,
         vc3FrameTxReady   => vc3FrameTxReady,
         vc3FrameTxSOF     => vc3FrameTxSOF,
         vc3FrameTxEOF     => vc3FrameTxEOF,
         vc3FrameTxEOFE    => vc3FrameTxEOFE,
         vc3FrameTxData    => vc3FrameTxData,
         vc3LocBuffAFull   => vc3LocBuffAFull,
         vc3LocBuffFull    => vc3LocBuffFull,
         phyTxData         => phyTxData,
         phyTxDataK        => phyTxDataK,
         phyTxReady        => phyTxReady,
         crcTxIn           => crcTxIn,
         crcTxInit         => crcTxInit,
         crcTxValid        => crcTxValid,
         crcTxOut          => crcTxOut,
         debug             => open
      );


   -- MGT Receive Reset
   U_Pgp2MgtRxRst: entity work.Pgp2MgtRxRst port map (
      mgtRxClk       => pgpClk,
      mgtRxRst       => intRxRst,
      mgtRxReady     => phyRxReady,
      mgtRxInit      => phyRxInit,
      mgtRxLock      => mgtRxLock,
      mgtRxPmaReset  => mgtRxPmaReset,
      mgtRxReset     => mgtRxReset,
      mgtRxBuffError => mgtRxBuffError
   );


   -- MGT Transmit Reset
   U_Pgp2MgtTxRst: entity work.Pgp2MgtTxRst port map (
      mgtTxClk       => pgpClk,
      mgtTxRst       => intTxRst,
      mgtTxReady     => phyTxReady,
      mgtTxLock      => mgtTxLock,
      mgtTxPmaReset  => mgtTxPmaReset,
      mgtTxReset     => mgtTxReset,
      mgtTxBuffError => mgtTxBuffError
   );

   
    --------------------------- GT11 Instantiations  ---------------------------   
    U_MGT : GT11
    generic map
    (
    
    ---------- RocketIO MGT 64B66B Block Sync State Machine Attributes --------- 

        SH_CNT_MAX                 =>      64,
        SH_INVALID_CNT_MAX         =>      16,
        
    ----------------------- RocketIO MGT Alignment Atrributes ------------------   

        ALIGN_COMMA_WORD           =>      2,
        COMMA_10B_MASK             =>      x"3ff",
        COMMA32                    =>      FALSE,
        DEC_MCOMMA_DETECT          =>      FALSE,
        DEC_PCOMMA_DETECT          =>      FALSE,
        DEC_VALID_COMMA_ONLY       =>      FALSE,
        MCOMMA_32B_VALUE           =>      x"00000283",
        MCOMMA_DETECT              =>      TRUE,
        PCOMMA_32B_VALUE           =>      x"0000017c",
        PCOMMA_DETECT              =>      TRUE,
        PCS_BIT_SLIP               =>      FALSE,        
        
    ---- RocketIO MGT Atrributes Common to Clk Correction & Channel Bonding ----   

        CCCB_ARBITRATOR_DISABLE    =>      FALSE,
        CLK_COR_8B10B_DE           =>      TRUE,        

    ------------------- RocketIO MGT Channel Bonding Atrributes ----------------   
    
        CHAN_BOND_LIMIT            =>      16,
        CHAN_BOND_MODE             =>      "NONE",
        CHAN_BOND_ONE_SHOT         =>      FALSE,
        CHAN_BOND_SEQ_1_1          =>      "00000000000",
        CHAN_BOND_SEQ_1_2          =>      "00000000000",
        CHAN_BOND_SEQ_1_3          =>      "00000000000",
        CHAN_BOND_SEQ_1_4          =>      "00000000000",
        CHAN_BOND_SEQ_1_MASK       =>      "1110",
        CHAN_BOND_SEQ_2_1          =>      "00000000000",
        CHAN_BOND_SEQ_2_2          =>      "00000000000",
        CHAN_BOND_SEQ_2_3          =>      "00000000000",
        CHAN_BOND_SEQ_2_4          =>      "00000000000",
        CHAN_BOND_SEQ_2_MASK       =>      "1111",
        CHAN_BOND_SEQ_2_USE        =>      FALSE,
        CHAN_BOND_SEQ_LEN          =>      1,
 
    ------------------ RocketIO MGT Clock Correction Atrributes ----------------   

        CLK_COR_MAX_LAT            =>      48,
        CLK_COR_MIN_LAT            =>      36,
        CLK_COR_SEQ_1_1            =>      "00110111100",
        CLK_COR_SEQ_1_2            =>      "00100011100",
        CLK_COR_SEQ_1_3            =>      "00100011100",
        CLK_COR_SEQ_1_4            =>      "00100011100",
        CLK_COR_SEQ_1_MASK         =>      "0000",
        CLK_COR_SEQ_2_1            =>      "00000000000",
        CLK_COR_SEQ_2_2            =>      "00000000000",
        CLK_COR_SEQ_2_3            =>      "00000000000",
        CLK_COR_SEQ_2_4            =>      "00000000000",
        CLK_COR_SEQ_2_MASK         =>      "1111",
        CLK_COR_SEQ_2_USE          =>      FALSE,
        CLK_COR_SEQ_DROP           =>      FALSE,
        CLK_COR_SEQ_LEN            =>      4,
        CLK_CORRECT_USE            =>      TRUE,
        
    ---------------------- RocketIO MGT Clocking Atrributes --------------------      
                                        
        RX_CLOCK_DIVIDER           =>      "01",
        RXASYNCDIVIDE              =>      "01",
        RXCLK0_FORCE_PMACLK        =>      TRUE,
        RXCLKMODE                  =>      "000011",
        RXOUTDIV2SEL               =>      2,
        RXPLLNDIVSEL               =>      20,   -- 8=1.25, 16=2.5, 20=3.125
        RXPMACLKSEL                =>      RefClkSel,
        RXRECCLK1_USE_SYNC         =>      FALSE,
        RXUSRDIVISOR               =>      1,
        TX_CLOCK_DIVIDER           =>      "01",
        TXABPMACLKSEL              =>      RefClkSel,
        TXASYNCDIVIDE              =>      "01",
        TXCLK0_FORCE_PMACLK        =>      TRUE,
        TXCLKMODE                  =>      "0100",
        TXOUTCLK1_USE_SYNC         =>      FALSE,
        TXOUTDIV2SEL               =>      2,
        TXPHASESEL                 =>      FALSE, 
        TXPLLNDIVSEL               =>      20,   -- 8=1.25, 16=2.5, 20=3.125

    -------------------------- RocketIO MGT CRC Atrributes ---------------------   

        RXCRCCLOCKDOUBLE           =>      FALSE,
        RXCRCENABLE                =>      TRUE,
        RXCRCINITVAL               =>      x"FFFFFFFF",
        RXCRCINVERTGEN             =>      TRUE,
        RXCRCSAMECLOCK             =>      TRUE,
        TXCRCCLOCKDOUBLE           =>      FALSE,
        TXCRCENABLE                =>      TRUE,
        TXCRCINITVAL               =>      x"FFFFFFFF",
        TXCRCINVERTGEN             =>      TRUE,
        TXCRCSAMECLOCK             =>      TRUE,
        
    --------------------- RocketIO MGT Data Path Atrributes --------------------   
    
        RXDATA_SEL                 =>      "00",
        TXDATA_SEL                 =>      "00",

    ---------------- RocketIO MGT Digital Receiver Attributes ------------------   

        DIGRX_FWDCLK               =>      "01",
        DIGRX_SYNC_MODE            =>      FALSE,
        ENABLE_DCDR                =>      FALSE,
        RXBY_32                    =>      FALSE,
        RXDIGRESET                 =>      FALSE,
        RXDIGRX                    =>      FALSE,
        SAMPLE_8X                  =>      FALSE,
                                        
    ----------------- Rocket IO MGT Miscellaneous Attributes ------------------     

        GT11_MODE                  =>      MgtMode,
        OPPOSITE_SELECT            =>      FALSE,
        PMA_BIT_SLIP               =>      FALSE,
        REPEATER                   =>      FALSE,
        RX_BUFFER_USE              =>      TRUE,
        RXCDRLOS                   =>      "000000",
        RXDCCOUPLE                 =>      TRUE,
--        RXDCCOUPLE                 =>      FALSE,
        RXFDCAL_CLOCK_DIVIDE       =>      "NONE",
        TX_BUFFER_USE              =>      TRUE,   
        TXFDCAL_CLOCK_DIVIDE       =>      "NONE",
        TXSLEWRATE                 =>      FALSE,

     ----------------- Rocket IO MGT Preemphasis and Equalization --------------
     
        RXAFEEQ                    =>       "000000000",
        RXEQ                       =>       x"4000FF0303030101",
        TXDAT_PRDRV_DAC            =>       "111",
        TXDAT_TAP_DAC              =>       "11011",  -- = TXPOST_TAP_DAC * 4
        TXHIGHSIGNALEN             =>       TRUE,
        TXPOST_PRDRV_DAC           =>       "111",
        TXPOST_TAP_DAC             =>       "00010",
        TXPOST_TAP_PD              =>       FALSE,
        TXPRE_PRDRV_DAC            =>       "111",
        TXPRE_TAP_DAC              =>       "00001",  -- = TXPOST_TAP_DAC / 2     
        TXPRE_TAP_PD               =>       TRUE,        
                                          
    ----------------------- Restricted RocketIO MGT Attributes -------------------  

    ---Note : THE FOLLOWING ATTRIBUTES ARE RESTRICTED. PLEASE DO NOT EDIT.

     ----------------------------- Restricted: Biasing -------------------------
     
        BANDGAPSEL                 =>       FALSE,
        BIASRESSEL                 =>       FALSE,    
        IREFBIASMODE               =>       "11",
        PMAIREFTRIM                =>       "0111",
        PMAVREFTRIM                =>       "0111",
        TXAREFBIASSEL              =>       TRUE, 
        TXTERMTRIM                 =>       "1100",
        VREFBIASMODE               =>       "11",

     ---------------- Restricted: Frequency Detector and Calibration -----------  

        CYCLE_LIMIT_SEL            =>       "00",
        FDET_HYS_CAL               =>       "010",
        FDET_HYS_SEL               =>       "100",
        FDET_LCK_CAL               =>       "101",
        FDET_LCK_SEL               =>       "001",
        LOOPCAL_WAIT               =>       "00",
        RXCYCLE_LIMIT_SEL          =>       "00",
        RXFDET_HYS_CAL             =>       "010",
        RXFDET_HYS_SEL             =>       "100",
        RXFDET_LCK_CAL             =>       "101",   
        RXFDET_LCK_SEL             =>       "001",
        RXLOOPCAL_WAIT             =>       "00",
        RXSLOWDOWN_CAL             =>       "00",
        SLOWDOWN_CAL               =>       "00",

     --------------------------- Restricted: PLL Settings ---------------------

        PMACLKENABLE               =>       TRUE,
        PMACOREPWRENABLE           =>       TRUE,
        PMAVBGCTRL                 =>       "00000",
        RXACTST                    =>       FALSE,          
        RXAFETST                   =>       FALSE,         
        RXCMADJ                    =>       "01",
        RXCPSEL                    =>       TRUE,
        RXCPTST                    =>       FALSE,
        RXCTRL1                    =>       x"200",
        RXFECONTROL1               =>       "00",  
        RXFECONTROL2               =>       "000",  
        RXFETUNE                   =>       "01", 
        RXLKADJ                    =>       "00000",
        RXLOOPFILT                 =>       "1111",
        RXPDDTST                   =>       TRUE,          
        RXRCPADJ                   =>       "011",   
        RXRIBADJ                   =>       "11",
        RXVCO_CTRL_ENABLE          =>       TRUE,
        RXVCODAC_INIT              =>       "0000101001",   
        TXCPSEL                    =>       TRUE,
        TXCTRL1                    =>       x"200",
        TXLOOPFILT                 =>       "1101",   
        VCO_CTRL_ENABLE            =>       TRUE,
        VCODAC_INIT                =>       "0000101001",
        
    --------------------------- Restricted: Powerdowns ------------------------  
    
        POWER_ENABLE               =>       TRUE,
        RXAFEPD                    =>       FALSE,
        RXAPD                      =>       FALSE,
        RXLKAPD                    =>       FALSE,
        RXPD                       =>       FALSE,
        RXRCPPD                    =>       FALSE,
        RXRPDPD                    =>       FALSE,
        RXRSDPD                    =>       FALSE,
        TXAPD                      =>       FALSE,
        TXDIGPD                    =>       FALSE,
        TXLVLSHFTPD                =>       FALSE,
        TXPD                       =>       FALSE,

    --------------------------- Recent Adds In Latest Software, Unknown -------  

        IN_DELAY                   =>       0 ps,
        DCDR_FILTER                =>       "010",
        RXAREGCTRL                 =>       "00000",
        RXCLMODE                   =>       "00",
        RXLB                       =>       FALSE,
        RXMODE                     =>       "000000",
        RXTUNE                     =>       X"0000",
        TXCLMODE                   =>       "00",
        TXTUNE                     =>       X"0000"
    )
    port map
    (
        ------------------------------- CRC Ports ------------------------------  

        RXCRCCLK                   =>      pgpClk,
        RXCRCDATAVALID             =>      crcRxValid,
        RXCRCDATAWIDTH             =>      crcRxWidth,
        RXCRCIN                    =>      crcRxInMgt,
        RXCRCINIT                  =>      crcRxInit,
        RXCRCINTCLK                =>      pgpClk,
        RXCRCOUT                   =>      crcRxOut,
        RXCRCPD                    =>      '0',
        RXCRCRESET                 =>      crcRxReset,
                                   
        TXCRCCLK                   =>      pgpClk,
        TXCRCDATAVALID             =>      crcTxValid,
        TXCRCDATAWIDTH             =>      crcTxWidth,
        TXCRCIN                    =>      crcTxInMgt,
        TXCRCINIT                  =>      crcTxInit,
        TXCRCINTCLK                =>      pgpClk,
        TXCRCOUT                   =>      crcTxOut,
        TXCRCPD                    =>      '0',
        TXCRCRESET                 =>      crcTxReset,

         ---------------------------- Calibration Ports ------------------------   

        RXCALFAIL                  =>      open,
        RXCYCLELIMIT               =>      open,
        TXCALFAIL                  =>      open,
        TXCYCLELIMIT               =>      open,

        ------------------------------ Serial Ports ----------------------------   

        RX1N                       =>      mgtRxN,
        RX1P                       =>      mgtRxP,
        TX1N                       =>      mgtTxN,
        TX1P                       =>      mgtTxP,

        ------------------------------- PLL Lock -------------------------------   

        RXLOCK                     =>      mgtRxLock,
        TXLOCK                     =>      mgtTxLock,

        -------------------------------- Resets -------------------------------  

        RXPMARESET                 =>      mgtRxPmaReset,
        RXRESET                    =>      mgtRxReset,
        TXPMARESET                 =>      mgtTxPmaReset,
        TXRESET                    =>      mgtTxReset,

        ---------------------------- Synchronization ---------------------------   
                                
        RXSYNC                     =>      '0',
        TXSYNC                     =>      '0',
                                
        ---------------------------- Out of Band Signalling -------------------   

        RXSIGDET                   =>      open,                      
        TXENOOB                    =>      '0',
 
        -------------------------------- Status --------------------------------   

        RXBUFERR                   =>      mgtRxBuffError,
        RXCLKSTABLE                =>      '1',
        RXSTATUS                   =>      open,
        TXBUFERR                   =>      mgtTxBuffError,
        TXCLKSTABLE                =>      '1',
  
        ---------------------------- Polarity Control Ports -------------------- 

        RXPOLARITY                 =>      phyRxPolarity(0),
        TXINHIBIT                  =>      '0',
        TXPOLARITY                 =>      '0',

        ------------------------------- Channel Bonding Ports ------------------   

        CHBONDI                    =>      (others=>'0'),
        CHBONDO                    =>      open,
        ENCHANSYNC                 =>      '0',
 
        ---------------------------- 64B66B Blocks Use Ports -------------------   

        RXBLOCKSYNC64B66BUSE       =>      '0',
        RXDEC64B66BUSE             =>      '0',
        RXDESCRAM64B66BUSE         =>      '0',
        RXIGNOREBTF                =>      '0',
        TXENC64B66BUSE             =>      '0',
        TXGEARBOX64B66BUSE         =>      '0',
        TXSCRAM64B66BUSE           =>      '0',

        ---------------------------- 8B10B Blocks Use Ports --------------------   

        RXDEC8B10BUSE              =>      '1',
        TXBYPASS8B10B(7 downto 2)  =>      (others=>'0'),
        TXBYPASS8B10B(1 downto 0)  =>      (others=>'0'),
        TXENC8B10BUSE              =>      '1',
                                    
        ------------------------------ Transmit Control Ports ------------------   

        TXCHARDISPMODE(7 downto 0) =>      (others=>'0'),
        TXCHARDISPVAL(7 downto 0)  =>      (others=>'0'),
        TXCHARISK(7 downto 2)      =>      (others=>'0'),
        TXCHARISK(1 downto 0)      =>      phyTxDataK,
        TXKERR(7 downto 0)         =>      open,
        TXRUNDISP(7 downto 0)      =>      open,

        ------------------------------ Receive Control Ports -------------------   

        RXCHARISCOMMA              =>      open, 
        RXCHARISK(7 downto 2)      =>      open,
        RXCHARISK(1 downto 0)      =>      phyRxDataK,
        RXDISPERR(7 downto 2)      =>      open,
        RXDISPERR(1 downto 0)      =>      phyRxDispErr,
        RXNOTINTABLE(7 downto 2)   =>      open,
        RXNOTINTABLE(1 downto 0)   =>      phyRxDecErr,
        RXRUNDISP(7 downto 0)      =>      open,

        ------------------------------- Serdes Alignment -----------------------  

        ENMCOMMAALIGN              =>      '1',
        ENPCOMMAALIGN              =>      '1',
        RXCOMMADET                 =>      open,
        RXCOMMADETUSE              =>      '1',
        RXLOSSOFSYNC               =>      open,           
        RXREALIGN                  =>      open,
        RXSLIDE                    =>      '0',

        ----------- Data Width Settings - Internal and fabric interface -------- 

        RXDATAWIDTH                =>      "01",
        RXINTDATAWIDTH             =>      "11",
        TXDATAWIDTH                =>      "01",
        TXINTDATAWIDTH             =>      "11",

        ------------------------------- Data Ports -----------------------------    

        RXDATA(63 downto 16)       =>      open,
        RXDATA(15 downto 0)        =>      phyRxData,
        TXDATA(63 downto 16)       =>      (others=>'0'),
        TXDATA(15 downto 0)        =>      phyTxData,

         ------------------------------- User Clocks -----------------------------   

        RXMCLK                     =>      open, 
        RXPCSHCLKOUT               =>      open, 
        RXRECCLK1                  =>      mgtRxRecClk,
        RXRECCLK2                  =>      open,
        RXUSRCLK                   =>      '0',
        RXUSRCLK2                  =>      pgpClk,
        TXOUTCLK1                  =>      open,
        TXOUTCLK2                  =>      open,
        TXPCSHCLKOUT               =>      open,
        TXUSRCLK                   =>      '0',
        TXUSRCLK2                  =>      pgpClk,
   
         ---------------------------- Reference Clocks --------------------------   

        GREFCLK                    =>      '0',
        REFCLK1                    =>      mgtRefClk1,
        REFCLK2                    =>      mgtRefClk2,

        ---------------------------- Powerdown and Loopback Ports --------------  

        LOOPBACK(1)                =>      mgtLoopback,
        LOOPBACK(0)                =>      mgtLoopback,
        POWERDOWN                  =>      '0',

       ------------------- Dynamic Reconfiguration Port (DRP) ------------------
 
        DADDR                      =>      daddr,
        DCLK                       =>      dclk,
        DEN                        =>      den,
        DI                         =>      ddin,
        DO                         =>      ddout,
        DRDY                       =>      drdy,
        DWE                        =>      dwen,

           --------------------- MGT Tile Communication Ports ------------------       

        COMBUSIN                   =>      mgtCombusIn,
        COMBUSOUT                  =>      mgtCombusOut
    );

end Pgp2Mgt16;

