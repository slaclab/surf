-------------------------------------------------------------------------------
-- Title         : Ethernet Client, Core Package File
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : EthClientPackage.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 10/18/2010
-------------------------------------------------------------------------------
-- Description:
-- Core package file for general purpose firmware ethenet client.
-------------------------------------------------------------------------------
-- Copyright (c) 2010 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 10/18/2010: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

package EthClientPackage is

    -- Register delay for simulation
   constant tpd:time := 0.5 ns;

   -- Type for IP address
   type IPAddrType is array(3 downto 0) of std_logic_vector(7 downto 0);

   -- Type for mac address
   type MacAddrType is array(5 downto 0) of std_logic_vector(7 downto 0);

   -- Ethernet header field constants
   constant EthTypeIPV4 : std_logic_vector(15 downto 0) := x"0800";
   constant EthTypeARP  : std_logic_vector(15 downto 0) := x"0806";
   constant EthTypeMac  : std_logic_vector(15 downto 0) := x"8808";

   -- UDP header field constants
   constant UDPProtocol   : std_logic_vector(7 downto 0)  := x"11";

   -- ARP Message container
   type ARPMsgType is array(27 downto 0) of std_logic_vector(7 downto 0);

   -- IPV4/UDP Header container
   type UDPMsgType is array(27 downto 0) of std_logic_vector(7 downto 0);

   -- component eth_fifo_19x8k
      -- port (
      -- clk: in std_logic;
      -- rst: in std_logic;
      -- din: in std_logic_vector(18 downto 0);
      -- wr_en: in std_logic;
      -- rd_en: in std_logic;
      -- dout: out std_logic_vector(18 downto 0);
      -- full: out std_logic;
      -- empty: out std_logic;
      -- data_count: out std_logic_vector(12 downto 0));
   -- end component;

   -- component eth_fifo_13x1k
      -- port (
      -- clk: in std_logic;
      -- rst: in std_logic;
      -- din: in std_logic_vector(12 downto 0);
      -- wr_en: in std_logic;
      -- rd_en: in std_logic;
      -- dout: out std_logic_vector(12 downto 0);
      -- full: out std_logic;
      -- empty: out std_logic;
      -- data_count: out std_logic_vector(9 downto 0));
   -- end component;

   -- component eth_fifo_8x16k
      -- port (
      -- clk: in std_logic;
      -- rst: in std_logic;
      -- din: in std_logic_vector(7 downto 0);
      -- wr_en: in std_logic;
      -- rd_en: in std_logic;
      -- dout: out std_logic_vector(7 downto 0);
      -- full: out std_logic;
      -- empty: out std_logic;
      -- data_count: out std_logic_vector(13 downto 0));
   -- end component;

   -- component eth_fifo_18x1k
      -- port (
      -- clk: in std_logic;
      -- rst: in std_logic;
      -- din: in std_logic_vector(17 downto 0);
      -- wr_en: in std_logic;
      -- rd_en: in std_logic;
      -- dout: out std_logic_vector(17 downto 0);
      -- full: out std_logic;
      -- empty: out std_logic;
      -- data_count: out std_logic_vector(9 downto 0));
   -- end component;

   -- component EthClient
      -- generic ( 
         -- UdpPort : integer := 8192
      -- );
      -- port (
         -- emacClk         : in  std_logic;
         -- emacClkRst      : in  std_logic;
         -- emacRxData      : in  std_logic_vector(7 downto 0);
         -- emacRxValid     : in  std_logic;
         -- emacRxGoodFrame : in  std_logic;
         -- emacRxBadFrame  : in  std_logic;
         -- emacTxData      : out std_logic_vector(7 downto 0);
         -- emacTxValid     : out std_logic;
         -- emacTxAck       : in  std_logic;
         -- emacTxFirst     : out std_logic;
         -- ipAddr          : in  IPAddrType;
         -- macAddr         : in  MacAddrType;
         -- udpTxValid      : in  std_logic;
         -- udpTxFast       : in  std_logic;
         -- udpTxReady      : out std_logic;
         -- udpTxLength     : in  std_logic_vector(15 downto 0);
         -- udpTxData       : in  std_logic_vector(7 downto 0);
         -- udpRxValid      : out std_logic;
         -- udpRxData       : out std_logic_vector(7 downto 0);
         -- udpRxGood       : out std_logic;
         -- udpRxError      : out std_logic;
         -- udpRxCount      : out std_logic_vector(15 downto 0)
      -- );
   -- end component;

   -- -- ARP Processor
   -- component EthClientArp port (
      -- emacClk    : in  std_logic;
      -- emacClkRst : in  std_logic;
      -- ipAddr     : in  IPAddrType;
      -- macAddr    : in  MacAddrType;
      -- rxData     : in  std_logic_vector(7 downto 0);
      -- rxError    : in  std_logic;
      -- rxGood     : in  std_logic;
      -- rxValid    : in  std_logic;
      -- rxSrc      : in  MacAddrType;
      -- txValid    : out std_logic;
      -- txReady    : in  std_logic;
      -- txData     : out std_logic_vector(7 downto 0);
      -- txDst      : out MacAddrType
   -- );
   -- end component;

   -- -- UDP interface
   -- component EthClientUdp 
      -- generic ( 
         -- UdpPort : integer := 8192
      -- );
      -- port (
         -- emacClk     : in  std_logic;
         -- emacClkRst  : in  std_logic;
         -- ipAddr      : in  IPAddrType;
         -- rxData      : in  std_logic_vector(7 downto 0);
         -- rxError     : in  std_logic;
         -- rxGood      : in  std_logic;
         -- rxValid     : in  std_logic;
         -- rxSrc       : in  MacAddrType;
         -- txValid     : out std_logic;
         -- txReady     : in  std_logic;
         -- txData      : out std_logic_vector(7 downto 0);
         -- txDst       : out MacAddrType;
         -- udpTxValid  : in  std_logic;
         -- udpTxFast   : in  std_logic;
         -- udpTxReady  : out std_logic;
         -- udpTxData   : in  std_logic_vector(7  downto 0);
         -- udpTxLength : in  std_logic_vector(15 downto 0);
         -- udpRxValid  : out std_logic;
         -- udpRxData   : out std_logic_vector(7 downto 0);
         -- udpRxCount  : out std_logic_vector(15 downto 0);
         -- udpRxError  : out std_logic;
         -- udpRxGood   : out std_logic
      -- );
   -- end component;

   -- component EthClientGtp is 
      -- generic (
         -- UdpPort      : integer := 8192         -- Enable short non-EOF cells
      -- );
      -- port (

         -- -- System clock, reset & control
         -- gtpClk       : in  std_logic;          -- 125Mhz master clock
         -- gtpClkOut    : out std_logic;          -- 125Mhz gtp clock out
         -- gtpClkRef    : in  std_logic;          -- 125Mhz reference clock
         -- gtpClkRst    : in  std_logic;          -- Synchronous reset input

         -- -- Ethernet Constants
         -- ipAddr       : in  IPAddrType;
         -- macAddr      : in  MacAddrType;

         -- -- UDP Transmit interface
         -- udpTxValid   : in  std_logic;
         -- udpTxFast    : in  std_logic;
         -- udpTxReady   : out std_logic;
         -- udpTxData    : in  std_logic_vector(7  downto 0);
         -- udpTxLength  : in  std_logic_vector(15 downto 0);

         -- -- UDP Receive interface
         -- udpRxValid   : out std_logic;
         -- udpRxData    : out std_logic_vector(7 downto 0);
         -- udpRxGood    : out std_logic;
         -- udpRxError   : out std_logic;
         -- udpRxCount   : out std_logic_vector(15 downto 0);

         -- -- GTP Signals
         -- gtpRxN       : in  std_logic;          -- GTP Serial Receive Negative
         -- gtpRxP       : in  std_logic;          -- GTP Serial Receive Positive
         -- gtpTxN       : out std_logic;          -- GTP Serial Transmit Negative
         -- gtpTxP       : out std_logic           -- GTP Serial Transmit Positive
      -- );
   -- end component;

   -- component EthClientGtpRxRst is 
      -- port (

         -- -- Clock and reset
         -- gtpRxClk          : in  std_logic;
         -- gtpRxRst          : in  std_logic;

         -- -- RX Side is ready
         -- gtpRxReady        : out std_logic;
         
         -- -- GTP Status
         -- gtpLockDetect     : in  std_logic;
         -- gtpRxElecIdle     : in  std_logic;
         -- gtpRxBuffStatus   : in  std_logic_vector(1  downto 0);
         -- gtpRstDone        : in  std_logic;

         -- -- Reset Control
         -- gtpRxElecIdleRst  : out std_logic;
         -- gtpRxReset        : out std_logic;
         -- gtpRxCdrReset     : out std_logic 
       
      -- );
   -- end component;

   -- component EthClientGtpTxRst is 
      -- port (

         -- -- Clock and reset
         -- gtpTxClk          : in  std_logic;
         -- gtpTxRst          : in  std_logic;

         -- -- TX Side is ready
         -- gtpTxReady        : out std_logic;

         -- -- GTP Status
         -- gtpLockDetect     : in  std_logic;
         -- gtpTxBuffStatus   : in  std_logic_vector(1  downto 0);
         -- gtpRstDone        : in  std_logic;

         -- -- Reset Control
         -- gtpTxReset        : out std_logic
      -- );
   -- end component;

   -- component EthClientGtx is 
      -- generic (
         -- UdpPort      : integer := 8192         -- Enable short non-EOF cells
      -- );
      -- port (

         -- -- System clock, reset & control
         -- gtxClk       : in  std_logic;          -- 125Mhz master clock
         -- gtxClkDiv    : in  std_logic;          -- 62.5Mhz master clock
         -- gtxClkOut    : out std_logic;          -- 125Mhz gtp clock out
         -- gtxClkRef    : in  std_logic;          -- 125Mhz reference clock
         -- gtxClkRst    : in  std_logic;          -- Synchronous reset input

         -- -- Ethernet Constants
         -- ipAddr       : in  IPAddrType;
         -- macAddr      : in  MacAddrType;

         -- -- UDP Transmit interface
         -- udpTxValid   : in  std_logic;
         -- udpTxFast    : in  std_logic;
         -- udpTxReady   : out std_logic;
         -- udpTxData    : in  std_logic_vector(7  downto 0);
         -- udpTxLength  : in  std_logic_vector(15 downto 0);

         -- -- UDP Receive interface
         -- udpRxValid   : out std_logic;
         -- udpRxData    : out std_logic_vector(7 downto 0);
         -- udpRxGood    : out std_logic;
         -- udpRxError   : out std_logic;
         -- udpRxCount   : out std_logic_vector(15 downto 0);

         -- -- GTP Signals
         -- gtxRxN       : in  std_logic;          -- GTP Serial Receive Negative
         -- gtxRxP       : in  std_logic;          -- GTP Serial Receive Positive
         -- gtxTxN       : out std_logic;          -- GTP Serial Transmit Negative
         -- gtxTxP       : out std_logic           -- GTP Serial Transmit Positive
      -- );
   -- end component;

   -- component EthClientGtxRxRst is 
      -- port (

         -- -- Clock and reset
         -- gtxRxClk          : in  std_logic;
         -- gtxRxRst          : in  std_logic;

         -- -- RX Side is ready
         -- gtxRxReady        : out std_logic;
         
         -- -- GTP Status
         -- gtxLockDetect     : in  std_logic;
         -- gtxRxElecIdle     : in  std_logic;
         -- gtxRxBuffStatus   : in  std_logic_vector(1  downto 0);
         -- gtxRstDone        : in  std_logic;

         -- -- Reset Control
         -- gtxRxReset        : out std_logic;
         -- gtxRxCdrReset     : out std_logic 
       
      -- );
   -- end component;

   -- component EthClientGtxTxRst is 
      -- port (

         -- -- Clock and reset
         -- gtxTxClk          : in  std_logic;
         -- gtxTxRst          : in  std_logic;

         -- -- TX Side is ready
         -- gtxTxReady        : out std_logic;

         -- -- GTP Status
         -- gtxLockDetect     : in  std_logic;
         -- gtxTxBuffStatus   : in  std_logic_vector(1  downto 0);
         -- gtxRstDone        : in  std_logic;

         -- -- Reset Control
         -- gtxTxReset        : out std_logic
      -- );
   -- end component;

   -- component EthArbiter is 
      -- port ( 

         -- -- Ethernet clock & reset
         -- gtpClk         : in  std_logic;                        -- 125Mhz master clock
         -- gtpClkRst      : in  std_logic;                        -- Synchronous reset input

         -- -- User Transmit ETH Interface
         -- userTxValid    : out std_logic;
         -- userTxReady    : in  std_logic;
         -- userTxData     : out std_logic_vector(15 downto 0);    -- Ethernet TX Data
         -- userTxSOF      : out std_logic;                        -- Ethernet TX Start of Frame
         -- userTxEOF      : out std_logic;                        -- Ethernet TX End of Frame
         -- userTxVc       : out std_logic_vector(1  downto 0);    -- Ethernet TX Virtual Channel

         -- -- User 0 Transmit Interface
         -- user0TxValid   : in  std_logic;
         -- user0TxReady   : out std_logic;
         -- user0TxData    : in  std_logic_vector(15 downto 0);    -- Ethernet TX Data
         -- user0TxSOF     : in  std_logic;                        -- Ethernet TX Start of Frame
         -- user0TxEOF     : in  std_logic;                        -- Ethernet TX End of Frame

         -- -- User 1 Transmit Interface
         -- user1TxValid   : in  std_logic;
         -- user1TxReady   : out std_logic;
         -- user1TxData    : in  std_logic_vector(15 downto 0);    -- Ethernet TX Data
         -- user1TxSOF     : in  std_logic;                        -- Ethernet TX Start of Frame
         -- user1TxEOF     : in  std_logic;                        -- Ethernet TX End of Frame

          -- -- User 2 Transmit Interface
         -- user2TxValid   : in  std_logic;
         -- user2TxReady   : out std_logic;
         -- user2TxData    : in  std_logic_vector(15 downto 0);    -- Ethernet TX Data
         -- user2TxSOF     : in  std_logic;                        -- Ethernet TX Start of Frame
         -- user2TxEOF     : in  std_logic;                        -- Ethernet TX End of Frame

         -- -- User 3 Transmit Interface
         -- user3TxValid   : in  std_logic;
         -- user3TxReady   : out std_logic;
         -- user3TxData    : in  std_logic_vector(15 downto 0);    -- Ethernet TX Data
         -- user3TxSOF     : in  std_logic;                        -- Ethernet TX Start of Frame
         -- user3TxEOF     : in  std_logic                         -- Ethernet TX End of Frame

      -- );
   -- end component;

   -- component EthUdpFrame is port ( 
      -- gtpClk         : in  std_logic;                        -- 125Mhz master clock
      -- gtpClkRst      : in  std_logic;                        -- Synchronous reset input
      -- userTxValid    : in  std_logic;
      -- userTxReady    : out std_logic;
      -- userTxData     : in  std_logic_vector(15 downto 0);    -- Ethernet TX Data
      -- userTxSOF      : in  std_logic;                        -- Ethernet TX Start of Frame
      -- userTxEOF      : in  std_logic;                        -- Ethernet TX End of Frame
      -- userTxVc       : in  std_logic_vector(1  downto 0);    -- Ethernet TX Virtual Channel
      -- userRxValid    : out std_logic;
      -- userRxData     : out std_logic_vector(15 downto 0);    -- Ethernet RX Data
      -- userRxSOF      : out std_logic;                        -- Ethernet RX Start of Frame
      -- userRxEOF      : out std_logic;                        -- Ethernet RX End of Frame
      -- userRxEOFE     : out std_logic;                        -- Ethernet RX End of Frame Error
      -- userRxVc       : out std_logic_vector(1  downto 0);    -- Ethernet RX Virtual Channel
      -- udpTxValid     : out std_logic;
      -- udpTxFast      : out std_logic;
      -- udpTxReady     : in  std_logic;
      -- udpTxData      : out std_logic_vector(7  downto 0);
      -- udpTxLength    : out std_logic_vector(15 downto 0);
      -- udpTxJumbo     : in  std_logic;
      -- udpRxValid     : in  std_logic;
      -- udpRxData      : in  std_logic_vector(7  downto 0);
      -- udpRxGood      : in  std_logic;
      -- udpRxError     : in  std_logic;
      -- udpRxCount     : in  std_logic_vector(15 downto 0)
   -- );
   -- end component;

-- component EthCmdSlave
   -- generic (
      -- DestId     : natural := 0;     -- Destination ID Value To Match
      -- DestMask   : natural := 0;     -- Destination ID Mask For Match
      -- FifoType   : string  := "V5"   -- V5 = Virtex 5, V4 = Virtex 4
   -- );
   -- port ( 

      -- -- PGP Rx Clock And Reset
      -- pgpRxClk         : in  std_logic;                      -- PGP Clock
      -- pgpRxReset       : in  std_logic;                      -- Synchronous PGP Reset

      -- -- Local clock and reset
      -- locClk           : in  std_logic;                      -- Local Clock
      -- locReset         : in  std_logic;                      -- Synchronous Local Reset

      -- -- PGP Signals, Virtual Channel Rx Only
      -- vcFrameRxValid   : in  std_logic;                      -- Data is valid
      -- vcFrameRxSOF     : in  std_logic;                      -- Data is SOF
      -- vcFrameRxEOF     : in  std_logic;                      -- Data is EOF
      -- vcFrameRxEOFE    : in  std_logic;                      -- Data is EOF with Error
      -- vcFrameRxData    : in  std_logic_vector(15 downto 0);  -- Data
      -- vcLocBuffAFull   : out std_logic;                      -- Local buffer almost full
      -- vcLocBuffFull    : out std_logic;                      -- Local buffer full

      -- -- Local command signals
      -- cmdEn            : out std_logic;                      -- Command Enable
      -- cmdOpCode        : out std_logic_vector(7  downto 0);  -- Command OpCode
      -- cmdCtxOut        : out std_logic_vector(23 downto 0)   -- Command Context
   -- );

-- end component;

-- component EthRegSlave
   -- generic (
      -- FifoType   : string  := "V5"   -- V5 = Virtex 5, V4 = Virtex 4
   -- );
   -- port ( 

      -- -- PGP Rx Clock And Reset
      -- pgpRxClk         : in  std_logic;                     -- PGP Clock
      -- pgpRxReset       : in  std_logic;                     -- Synchronous PGP Reset

      -- -- PGP Tx Clock And Reset
      -- pgpTxClk         : in  std_logic;                     -- PGP Clock
      -- pgpTxReset       : in  std_logic;                     -- Synchronous PGP Reset

      -- -- Local clock and reset
      -- locClk           : in  std_logic;                     -- Local Clock
      -- locReset         : in  std_logic;                     -- Synchronous Local Reset

      -- -- PGP Receive Signals
      -- vcFrameRxValid   : in  std_logic;                     -- Data is valid
      -- vcFrameRxSOF     : in  std_logic;                     -- Data is SOF
      -- vcFrameRxEOF     : in  std_logic;                     -- Data is EOF
      -- vcFrameRxEOFE    : in  std_logic;                     -- Data is EOF with Error
      -- vcFrameRxData    : in  std_logic_vector(15 downto 0); -- Data
      -- vcLocBuffAFull   : out std_logic;                     -- Local buffer almost full
      -- vcLocBuffFull    : out std_logic;                     -- Local buffer full

      -- -- PGP Transmit Signals
      -- vcFrameTxValid   : out std_logic;                     -- User frame data is valid
      -- vcFrameTxReady   : in  std_logic;                     -- PGP is ready
      -- vcFrameTxSOF     : out std_logic;                     -- User frame data start of frame
      -- vcFrameTxEOF     : out std_logic;                     -- User frame data end of frame
      -- vcFrameTxEOFE    : out std_logic;                     -- User frame data error
      -- vcFrameTxData    : out std_logic_vector(15 downto 0); -- User frame data
      -- vcRemBuffAFull   : in  std_logic;                     -- Remote buffer almost full
      -- vcRemBuffFull    : in  std_logic;                     -- Remote buffer full

      -- -- Local register control signals
      -- regInp           : out std_logic;                     -- Register Access In Progress Flag
      -- regReq           : out std_logic;                     -- Register Access Request
      -- regOp            : out std_logic;                     -- Register OpCode, 0=Read, 1=Write
      -- regAck           : in  std_logic;                     -- Register Access Acknowledge
      -- regFail          : in  std_logic;                     -- Register Access Fail
      -- regAddr          : out std_logic_vector(23 downto 0); -- Register Address
      -- regDataOut       : out std_logic_vector(31 downto 0); -- Register Data Out
      -- regDataIn        : in  std_logic_vector(31 downto 0)  -- Register Data In
   -- );

-- end component;

end EthClientPackage;

