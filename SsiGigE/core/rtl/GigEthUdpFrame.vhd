-------------------------------------------------------------------------------
-- Title         : Ethernet Interface Module, 8-bit word receive / transmit
-- Project       : SID, KPIX ASIC
-------------------------------------------------------------------------------
-- File          : GigEthUdpFrame.vhd
-- Author        : Raghuveer Ausoori, ausoori@slac.stanford.edu
-- Created       : 11/12/2010
-------------------------------------------------------------------------------
-- Description:
-- This module receives and transmits 8-bit data through the ethernet line
-------------------------------------------------------------------------------
-- Copyright (c) 2011 by Raghuveer Ausoori. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 2/16/2011: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
Library Unisim;
USE ieee.std_logic_1164.ALL;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.StdRtlPkg.all;
use work.EthClientPackage.all;

entity GigEthUdpFrame is port ( 

      -- Ethernet clock & reset
      gtpClk         : in  std_logic;                        -- 125Mhz master clock
      gtpClkRst      : in  std_logic;                        -- Synchronous reset input

      -- User Transmit Interface
      userTxValid    : in  std_logic;
      userTxReady    : out std_logic;
      userTxData     : in  std_logic_vector(15 downto 0);    -- Ethernet TX Data
      userTxSOF      : in  std_logic;                        -- Ethernet TX Start of Frame
      userTxEOF      : in  std_logic;                        -- Ethernet TX End of Frame
      userTxVc       : in  std_logic_vector(1  downto 0);    -- Ethernet TX Virtual Channel

      -- User Receive Interface
      userRxValid    : out std_logic;
      userRxData     : out std_logic_vector(15 downto 0);    -- Ethernet RX Data
      userRxSOF      : out std_logic;                        -- Ethernet RX Start of Frame
      userRxEOF      : out std_logic;                        -- Ethernet RX End of Frame
      userRxEOFE     : out std_logic;                        -- Ethernet RX End of Frame Error
      userRxVc       : out std_logic_vector(1  downto 0);    -- Ethernet RX Virtual Channel

      -- UDP Block Transmit Interface (connection to MAC)
      udpTxValid     : out std_logic;
      udpTxFast      : out std_logic;
      udpTxReady     : in  std_logic;
      udpTxData      : out std_logic_vector(7  downto 0);
      udpTxLength    : out std_logic_vector(15 downto 0);
      udpTxJumbo     : in  std_logic;

      -- UDP Block Receive Interface (connection from MAC)
      udpRxValid     : in  std_logic;
      udpRxData      : in  std_logic_vector(7  downto 0);
      udpRxGood      : in  std_logic;
      udpRxError     : in  std_logic;
      udpRxCount     : in  std_logic_vector(15 downto 0)

   );
end GigEthUdpFrame;


-- Define architecture for Interface module
architecture GigEthUdpFrame of GigEthUdpFrame is 

   constant FWFT_EN_G       : boolean := false;

   -- Local signals
   signal tdataFifoDin      : std_logic_vector(18 downto 0);
   signal tdataFifoWr       : std_logic;
   signal tdataFifoFull     : std_logic;
   signal tdataFifoDout     : std_logic_vector(18 downto 0);
   signal tdataFifoRd       : std_logic;
   signal tdataFifoCount    : std_logic_vector(12 downto 0);
   signal tdataFifoAFull    : std_logic;
   signal tcountFifoDin     : std_logic_vector(12 downto 0);
   signal tcountFifoWr      : std_logic;
   signal tcountFifoFull    : std_logic;
   signal tcountFifoDout    : std_logic_vector(12 downto 0);
   signal tcountFifoRd      : std_logic;
   signal tcountFifoEmpty   : std_logic;
   signal tcountFifoCount   : std_logic_vector(9  downto 0);
   signal tdataCount        : std_logic_vector(11 downto 0);
   signal treadCount        : std_logic_vector(11 downto 0);
   signal treadCountRst     : std_logic;
   signal udpRxGoodError    : std_logic;
   signal rdataFifoRd       : std_logic;
   signal rdataFifoDout     : std_logic_vector(7 downto 0);
   signal rcountFifoRd      : std_logic;
   signal rcountFifoEmpty   : std_logic;
   signal rcountFifoDout    : std_logic_vector(15 downto 0);
   signal rcountFifoError   : std_logic;
   signal rcountFifoGood    : std_logic;
   signal rxCount           : std_logic_vector(15 downto 0);
   signal rxCntRst          : std_logic;
   signal intRxFifoData     : std_logic_vector(15 downto 0);
   signal intRxFifoSOF      : std_logic;
   signal intRxFifoEOF      : std_logic;
   signal intRxFifoEOFE     : std_logic;
   signal intRxFifoType     : std_logic_vector(1  downto 0);
   signal intRxFifoWr       : std_logic;
   signal nxtRxFifoData     : std_logic_vector(15 downto 0);
   signal nxtRxFifoSOF      : std_logic;
   signal nxtRxFifoEOF      : std_logic;
   signal nxtRxFifoEOFE     : std_logic;
   signal nxtRxFifoType     : std_logic_vector(1  downto 0);
   signal nxtRxFifoWr       : std_logic;
   signal intRxFirst        : std_logic;
   signal nxtRxFirst        : std_logic;
   signal intRxLast         : std_logic;
   signal nxtRxLast         : std_logic;
   signal intRxInFrame      : std_logic;
   signal nxtRxInFrame      : std_logic;
   signal txSerial          : std_logic_vector(3 downto 0);
   signal txSerialRst       : std_logic;
   signal txSerialEn        : std_logic;
   signal txBreakSize       : std_logic_vector(11 downto 0);

   -- Tx States
   constant ST_TX_IDLE   : std_logic_vector(2 downto 0) := "000";
   constant ST_TX_HEADA  : std_logic_vector(2 downto 0) := "001";
   constant ST_TX_HEADB  : std_logic_vector(2 downto 0) := "010";
   constant ST_TX_HIGH   : std_logic_vector(2 downto 0) := "011";
   constant ST_TX_LOW    : std_logic_vector(2 downto 0) := "100";
   signal   curTxState   : std_logic_vector(2 downto 0);
   signal   nxtTxState   : std_logic_vector(2 downto 0);

   -- RX States
   constant ST_RX_IDLE   : std_logic_vector(2 downto 0) := "000";
   constant ST_RX_READ   : std_logic_vector(2 downto 0) := "001";
   constant ST_RX_HEADA  : std_logic_vector(2 downto 0) := "010";
   constant ST_RX_HEADB  : std_logic_vector(2 downto 0) := "011";
   constant ST_RX_HIGH   : std_logic_vector(2 downto 0) := "100";
   constant ST_RX_LOW    : std_logic_vector(2 downto 0) := "101";
   constant ST_RX_DUMP   : std_logic_vector(2 downto 0) := "110";
   signal   curRXState   : std_logic_vector(2 downto 0);
   signal   nxtRXState   : std_logic_vector(2 downto 0);

begin

   ---------------------------
   --- Transmit
   ---------------------------
 
   userTxReady  <= userTxValid and (not tdataFifoAFull);

   process (gtpClk, gtpClkRst ) begin
      if gtpClkRst = '1' then
         tdataFifoDin   <= (others=>'0') after tpd;
         tdataFifoWr    <= '0'           after tpd;
         tcountFifoDin  <= (others=>'0') after tpd;
         tcountFifoWr   <= '0'           after tpd;
         tdataCount     <= x"002"        after tpd;
         tdataFifoAFull <= '0'           after tpd;
         txBreakSize    <= (others=>'0') after tpd;
      elsif rising_edge(gtpClk) then

         -- Set frame break size
         if udpTxJumbo = '1' then
            txBreakSize <= x"F9F" after tpd; -- 3999 (8000 bytes)
         else
            txBreakSize <= x"2bb" after tpd; -- 699 (1400 bytes)
         end if;

         -- Data fifo
         tdataFifoDin(18)           <= userTxSOF;
         tdataFifoDin(17 downto 16) <= userTxVc;
         tdataFifoDin(15 downto  0) <= userTxData;
         tdataFifoWr                <= userTxValid and (not tdataFifoAFull);

         -- Count FIFO
         if userTxValid = '1' and tdataFifoAFull = '0' and (userTxEOF = '1' or tdataCount = txBreakSize) then
            tcountFifoWr <= '1' after tpd;
         else
            tcountFifoWr <= '0' after tpd;
         end if;
         tcountFifoDin(12)          <= userTxEOF  after tpd;
         tcountFifoDin(11 downto 0) <= tdataCount after tpd;

         -- Counter
         if userTxValid = '1' and tdataFifoAFull = '0' then
            if userTxEOF = '1' or tdataCount = txBreakSize then
               tdataCount <= x"002"        after tpd;
            else
               tdataCount <= tdataCount + 1 after tpd;
            end if;
         end if;

         if tcountFifoCount > 900 or tdataFifoCount > 7000 then
            tdataFifoAFull <= '1' after tpd;
         else
            tdataFifoAFull <= '0' after tpd;
         end if;

      end if;
   end process;

   -- Transmitter data fifo (19x8k)
   U_TxDataFifo : entity work.FifoMux
      generic map (
         TPD_G              => tpd,
         LAST_STAGE_ASYNC_G => false,
         RST_POLARITY_G     => '1',
         GEN_SYNC_FIFO_G    => true,
         FWFT_EN_G          => FWFT_EN_G,
         WR_DATA_WIDTH_G    => 19,
         RD_DATA_WIDTH_G    => 19,
         ADDR_WIDTH_G       => 13
      )
      port map (
         -- Resets
         rst           => gtpClkRst,
         --Write Ports (wr_clk domain)
         wr_clk        => gtpClk,
         wr_en         => tdataFifoWr,
         din           => tdataFifoDin,
         full          => tdataFifoFull,
         --Read Ports (rd_clk domain)
         rd_clk        => gtpClk,
         rd_en         => tdataFifoRd,
         dout          => tdataFifoDout,
         rd_data_count => tdataFifoCount,
         empty         => open
      );            
   
   -- Transmitter Data Count Fifo (13x1k)
   U_TxCntFifo : entity work.FifoMux
      generic map (
         TPD_G              => tpd,
         LAST_STAGE_ASYNC_G => false,
         RST_POLARITY_G     => '1',
         GEN_SYNC_FIFO_G    => true,
         FWFT_EN_G          => FWFT_EN_G,
         WR_DATA_WIDTH_G    => 13,
         RD_DATA_WIDTH_G    => 13,
         ADDR_WIDTH_G       => 10
      )
      port map (
         -- Resets
         rst           => gtpClkRst,
         --Write Ports (wr_clk domain)
         wr_clk        => gtpClk,
         wr_en         => tcountFifoWr,
         din           => tcountFifoDin,
         full          => tcountFifoFull,
         --Read Ports (rd_clk domain)
         rd_clk        => gtpClk,
         rd_en         => tcountFifoRd,
         dout          => tcountFifoDout,
         rd_data_count => tcountFifoCount,
         empty         => tcountFifoEmpty
      );           

   process (gtpClk, gtpClkRst ) begin
      if gtpClkRst = '1' then
         treadCount   <= x"001"        after tpd;
         txSerial     <= (others=>'0') after tpd;
         curTxState   <= ST_TX_IDLE    after tpd;
      elsif rising_edge(gtpClk) then

         if treadCountRst = '1' then
            treadCount <= x"001"         after tpd;
         elsif tdataFifoRd = '1' then
            treadCount <= treadCount + 1 after tpd;
         end if;

         if txSerialRst = '1' then
            txSerial <= "0001" after tpd;
         elsif txSerialEn = '1' then
            txSerial <= txSerial + 1  after tpd;
         end if;

         curTxState  <= nxtTxState after tpd;
      end if;
   end process;

   -- Data output
   udpTxLength <= "000" & tcountFifoDout(11 downto 0) & "0";

   process (curTxState, tcountFifoEmpty, udpTxReady, tcountFifoDout, tdataFifoDout, treadCount, txSerial ) begin
                                                                                                   
      case curTxState is

         when ST_TX_IDLE  =>
            udpTxValid    <= '0';
            udpTxFast     <= '0';
            treadCountRst <= '0';
            udpTxData     <= (others=>'0');
            txSerialEn    <= '0';
            txSerialRst   <= '0';

            if tcountFifoEmpty = '0' then
               tcountFifoRd  <= '1';
               tdataFifoRd   <= '1';
               nxtTxState    <= ST_TX_HEADA;
            else
               tcountFifoRd  <= '0';
               tdataFifoRd   <= '0';
               nxtTxState    <= curTxState;
            end if;

         when ST_TX_HEADA =>
            treadCountRst         <= '0';
            tcountFifoRd          <= '0';
            tdataFifoRd           <= '0';
            udpTxValid            <= '1';
            udpTxFast             <= (not tdataFifoDout(17)) and (not tdataFifoDout(16)); -- VC=0
            udpTxData(7)          <= tdataFifoDout(18);  -- SOF
            udpTxData(6)          <= tcountFifoDout(12); -- EOF
            udpTxData(5 downto 4) <= tdataFifoDout(17 downto 16); -- VC

            -- -- Serial number
            -- if tdataFifoDout(18) = '1' then
               -- udpTxData(3 downto 0) <= (others=>'0');
               -- txSerialEn            <= '0';
               -- txSerialRst           <= '1';
            -- else
               -- udpTxData(3 downto 0) <= txSerial;
               -- txSerialEn            <= '1';
               -- txSerialRst           <= '0';
            -- end if;

            if udpTxReady = '1' then
               nxtTxState <= ST_TX_HEADB;
               -- Kurtis moving this block here to avoid repeated increments while waiting for ready
               -- Serial number
               if tdataFifoDout(18) = '1' then
                  udpTxData(3 downto 0) <= (others=>'0');
                  txSerialEn            <= '0';
                  txSerialRst           <= '1';
               else
                  udpTxData(3 downto 0) <= txSerial;
                  txSerialEn            <= '1';
                  txSerialRst           <= '0';
               end if;
            else
               nxtTxState <= curTxState;
            end if;

         when ST_TX_HEADB =>
            treadCountRst <= '0';
            tcountFifoRd  <= '0';
            tdataFifoRd   <= '0';
            udpTxValid    <= '1';
            udpTxFast     <= '0';
            udpTxData     <= tcountFifoDout(7 downto 0); -- Size
            nxtTxState    <= ST_TX_HIGH;
            txSerialEn    <= '0';
            txSerialRst   <= '0';
            
         when ST_TX_HIGH  =>
            tcountFifoRd  <= '0';
            udpTxValid    <= '1';
            udpTxFast     <= '0';
            treadCountRst <= '0';
            nxtTxState    <= ST_TX_LOW;
            tdataFifoRd   <= '0';
            udpTxData     <= tdataFifoDout(15 downto 8);
            txSerialEn    <= '0';
            txSerialRst   <= '0';
            
         when ST_TX_LOW   =>
            tcountFifoRd  <= '0';
            udpTxValid    <= '1';
            udpTxFast     <= '0';
            udpTxData     <= tdataFifoDout(7 downto 0);
            txSerialEn    <= '0';
            txSerialRst   <= '0';
            
            if treadCount = tcountFifoDout(11 downto 0) then
               treadCountRst <= '1';
               nxtTxState    <= ST_TX_IDLE;
               tdataFifoRd   <= '0';
            else
               treadCountRst <= '0';
               nxtTxState    <= ST_TX_HIGH;
               tdataFifoRd   <= '1';
            end if;

         when others =>
            treadCountRst <= '0';
            tcountFifoRd  <= '0';
            udpTxValid    <= '0';
            udpTxFast     <= '0';
            udpTxData     <= (others=>'0');
            tdataFifoRd   <= '0';
            nxtTxState    <= ST_TX_IDLE;
            txSerialEn    <= '0';
            txSerialRst   <= '0';
      end case;
   end process;


   ---------------------------
   --- Receive
   ---------------------------

   -- Receiver Data Fifo (8 x 16k)
   U_RxDataFifo : entity work.FifoMux
      generic map (
         TPD_G              => tpd,
         LAST_STAGE_ASYNC_G => false,
         RST_POLARITY_G     => '1',
         GEN_SYNC_FIFO_G    => true,
         FWFT_EN_G          => FWFT_EN_G,
         WR_DATA_WIDTH_G    => 8,
         RD_DATA_WIDTH_G    => 8,
         ADDR_WIDTH_G       => 14
      )
      port map (
         -- Resets
         rst           => gtpClkRst,
         --Write Ports (wr_clk domain)
         wr_clk        => gtpClk,
         wr_en         => udpRxValid,
         din           => udpRxData,
         full          => open,
         --Read Ports (rd_clk domain)
         rd_clk        => gtpClk,
         rd_en         => rdataFifoRd,
         dout          => rdataFifoDout,
         rd_data_count => open,
         empty         => open
      );           
   
   -- Receiver Data Count Fifo (18x1k)
   U_RxCntFifo : entity work.FifoMux
      generic map (
         TPD_G              => tpd,
         LAST_STAGE_ASYNC_G => false,
         RST_POLARITY_G     => '1',
         GEN_SYNC_FIFO_G    => true,
         FWFT_EN_G          => FWFT_EN_G,
         WR_DATA_WIDTH_G    => 18,
         RD_DATA_WIDTH_G    => 18,
         ADDR_WIDTH_G       => 14
      )
      port map (
         -- Resets
         rst               => gtpClkRst,
         --Write Ports (wr_clk domain)
         wr_clk            => gtpClk,
         wr_en             => udpRxGoodError,
         din(17)           => udpRxError,
         din(16)           => udpRxGood,
         din(15 downto 0)  => udpRxCount,
         full              => open,
         --Read Ports (rd_clk domain)
         rd_clk            => gtpClk,
         rd_en             => rcountFifoRd,
         dout(17)          => rcountFifoError,
         dout(16)          => rcountFifoGood,
         dout(15 downto 0) => rcountFifoDout,
         rd_data_count     => open,
         empty             => rcountFifoEmpty
      );           
   udpRxGoodError <= udpRxError or udpRxGood;

   -- Data output
   userRxData  <= intRxFifoData;
   userRxSOF   <= intRxFifoSOF;
   userRxEOF   <= intRxFifoEOF;
   userRxEOFE  <= intRxFifoEOFE;
   userRxVc    <= intRxFifoType;
   userRxValid <= intRxFifoWr;


   -- Convert byte data into 16-bit words
   process (gtpClk, gtpClkRst ) begin
      if gtpClkRst = '1' then
         intRxFifoData <= (others=>'0') after tpd;
         intRxFifoSOF  <= '0'           after tpd;
         intRxFifoEOF  <= '0'           after tpd;
         intRxFifoEOFE <= '0'           after tpd;
         intRxFifoType <= (others=>'0') after tpd;
         intRxFifoWr   <= '0'           after tpd;
         intRxFirst    <= '0'           after tpd;
         intRxLast     <= '0'           after tpd;
         intRxInFrame  <= '0'           after tpd;
         rxCount       <= (others=>'0') after tpd;
         curRxState    <= ST_RX_IDLE    after tpd;
      elsif rising_edge(gtpClk) then

         -- Read counter
         if rxCntRst = '1' then
            rxCount <= (others=>'0') after tpd;
         elsif rdataFifoRd = '1' then
            rxCount <= rxCount + 1 after tpd;
         end if;

         -- Track in frame status
         intRxInFrame <= nxtRxInFrame after tpd;

         -- Track first and last
         intRxFirst <= nxtRxFirst after tpd;
         intRxLast  <= nxtRxLast  after tpd;

         -- Output
         intRxFifoData <= nxtRxFifoData   after tpd;
         intRxFifoSOF  <= nxtRxFifoSOF    after tpd;
         intRxFifoEOF  <= nxtRxFifoEOF    after tpd;
         intRxFifoEOFE <= nxtRxFifoEOFE   after tpd;
         intRxFifoType <= nxtRxFifoType   after tpd;
         intRxFifoWr   <= nxtRxFifoWr     after tpd;
         
         -- State
         curRxState <= nxtRxState after tpd;
      end if;
   end process;


   process ( rdataFifoDout, rcountFifoEmpty, rcountFifoDout, intRxInFrame, intRxFifoEOFE, 
             intRxLast, intRxFifoType, rcountFifoError, intRxFifoData, intRxFifoType , 
             intRxFirst, intRxFifoSOF, curRxState, rxCount ) begin
      case curRxState is

         when ST_RX_IDLE =>
            rxCntRst       <= '1';
            rdataFifoRd    <= '0';
            nxtRxInFrame   <= intRxInFrame;
            nxtRxFifoData  <= (others=>'0');
            nxtRxFifoSOF   <= '0';
            nxtRxFifoEOF   <= '0';
            nxtRxFifoWr    <= '0';
            nxtRxFirst     <= '0';
            nxtRxLast      <= '0';

            -- In Frame
            if intRxInFrame = '1' then
               nxtRxFifoEOFE  <= intRxFifoEOFE;
               nxtRxFifoType  <= intRxFifoType;
            else
               nxtRxFifoEOFE  <= '0';
               nxtRxFifoType  <= (others=>'0');
            end if;

            -- Count fifo has data
            if rcountFifoEmpty = '0' then
               rcountFifoRd <= '1';
               nxtRxState   <= ST_RX_READ;
            else
               rcountFifoRd <= '0';
               nxtRxState   <= curRxState;
            end if;

         when ST_RX_READ =>
            rxCntRst       <= '0';
            rcountFifoRd   <= '0';
            nxtRxFifoData  <= (others=>'0');
            nxtRxFifoSOF   <= '0';
            nxtRxFifoType  <= intRxFifoType;
            rdataFifoRd    <= '1';
            nxtRxFirst     <= '0';
            nxtRxLast      <= '0';

            -- Error detected
            if rcountFifoError = '1' or rcountFifoDout < 2 or rcountFifoDout(0) = '1' then
              nxtRxState   <= ST_RX_DUMP;
              nxtRxInFrame <= '0';
           
              -- Not in frame
              if intRxInFrame = '0' then
                 nxtRxFifoEOFE <= '0';
                 nxtRxFifoEOF  <= '0';
                 nxtRxFifoWr   <= '0';

              -- In Frame
              else
                 nxtRxFifoEOFE <= '1';
                 nxtRxFifoEOF  <= '1';
                 nxtRxFifoWr   <= '1';
              end if;
            else
               nxtRxInFrame  <= intRxInFrame;
               nxtRxFifoEOFE <= intRxFifoEOFE;
               nxtRxFifoEOF  <= '0';
               nxtRxFifoWr   <= '0';
               nxtRxState    <= ST_RX_HEADA;
            end if;

         when ST_RX_HEADA =>
            rxCntRst       <= '0';
            rcountFifoRd   <= '0';
            nxtRxFifoData  <= (others=>'0');
            rdataFifoRd    <= '1';
            nxtRxFifoSOF   <= rDataFifoDout(7);
            nxtRxFirst     <= rdataFifoDout(7);
            nxtRxLast      <= rdataFifoDout(6);

            -- Not in frame, not SOF
            if intRxInFrame = '0' and rDataFifoDout(7) = '0' then
               nxtRxState    <= ST_RX_DUMP;
               nxtRxInFrame  <= '0';
               nxtRxFifoEOF  <= '0';
               nxtRxFifoEOFE <= '0';
               nxtRxFifoWr   <= '0';
               nxtRxFifoType <= (others=>'0');

            -- In Frame, SOF or type mismatch
            elsif intRxInFrame = '1' and (rdataFifoDout(7) = '1' or rdataFifoDout(5 downto 4 ) /= intRxFifoType) then
               nxtRxState    <= ST_RX_DUMP;
               nxtRxInFrame  <= '0';
               nxtRxFifoEOF  <= '1';
               nxtRxFifoEOFE <= '1';
               nxtRxFifoWr   <= '1';
               nxtRxFifoType <= intRxFifoType;

            -- No error
            else
               nxtRxState    <= ST_RX_HEADB;
               nxtRxInFrame  <= '1';
               nxtRxFifoEOF  <= '0';
               nxtRxFifoEOFE <= '0';
               nxtRxFifoWr   <= '0';
               nxtRxFifoType <= rDataFifoDout(5 downto 4);
            end if;

         when ST_RX_HEADB =>
            rxCntRst       <= '0';
            rcountFifoRd   <= '0';
            nxtRxInFrame   <= '1';
            nxtRxFifoData  <= (others=>'0');
            nxtRxFifoSOF   <= intRxFifoSOF;
            nxtRxFifoEOF   <= '0';
            nxtRxFifoEOFE  <= '0';
            nxtRxFifoType  <= intRxFifoType;
            nxtRxFifoWr    <= '0';
            nxtRxFirst     <= intRxFirst;
            nxtRxLast      <= intRxLast;
            rdataFifoRd    <= '1';
            nxtRxState     <= ST_RX_HIGH;

         when ST_RX_HIGH =>
            rxCntRst                   <= '0';
            rcountFifoRd               <= '0';
            nxtRxInFrame               <= '1';
            nxtRxFifoData(15 downto 8) <= rdataFifoDout;
            nxtRxFifoData(7  downto 0) <= (others=>'0');
            nxtRxFifoSOF               <= intRxFifoSOF and intRxFirst;
            nxtRxFifoEOF               <= '0';
            nxtRxFifoEOFE              <= '0';
            nxtRxFifoType              <= intRxFifoType;
            nxtRxFifoWr                <= '0';
            nxtRxFirst                 <= intRxFirst;
            nxtRxLast                  <= intRxLast;
            rdataFifoRd                <= '1';
            nxtRxState                 <= ST_RX_LOW;

         when ST_RX_LOW  =>
            rxCntRst                   <= '0';
            rcountFifoRd               <= '0';
            nxtRxInFrame               <= not intRxLast;
            nxtRxFifoData(15 downto 8) <= intRxFifoData(15 downto 8);
            nxtRxFifoData(7  downto 0) <= rdataFifoDout;
            nxtRxFifoSOF               <= intRxFifoSOF and intRxFirst;
            nxtRxFifoEOFE              <= '0';
            nxtRxFifoType              <= intRxFifoType;
            nxtRxFifoWr                <= '1';
            nxtRxFirst                 <= '0';
            nxtRxLast                  <= intRxLast;

            -- Detect last
            if rxCount = rcountFifoDout then
               nxtRxState   <= ST_RX_IDLE;
               rdataFifoRd  <= '0';
               nxtRxFifoEOF <= intRxLast;
            else
               nxtRxState   <= ST_RX_HIGH;
               rdataFifoRd  <= '1';
               nxtRxFifoEOF <= '0';
            end if;

         when ST_RX_DUMP =>
            rxCntRst       <= '0';
            rcountFifoRd   <= '0';
            nxtRxInFrame   <= '0';
            nxtRxFifoData  <= (others=>'0');
            nxtRxFifoSOF   <= '0';
            nxtRxFifoEOF   <= '0';
            nxtRxFifoEOFE  <= '0';
            nxtRxFifoType  <= (others=>'0');
            nxtRxFifoWr    <= '0';
            nxtRxFirst     <= '0';
            nxtRxLast      <= '0';

            if rxCount = rcountFifoDout then
               nxtRxState  <= ST_RX_IDLE;
               rdataFifoRd <= '0';
            else
               nxtRxState  <= curRxState;
               rdataFifoRd <= '1';
            end if;

         when others =>
            rxCntRst       <= '0';
            rcountFifoRd   <= '0';
            nxtRxInFrame   <= '0';
            nxtRxFifoData  <= (others=>'0');
            nxtRxFifoSOF   <= '0';
            nxtRxFifoEOF   <= '0';
            nxtRxFifoEOFE  <= '0';
            nxtRxFifoType  <= (others=>'0');
            nxtRxFifoWr    <= '0';
            nxtRxFirst     <= '0';
            nxtRxLast      <= '0';
            nxtRxState     <= ST_RX_IDLE;
            rdataFifoRd    <= '0';
      end case;
   end process;

end GigEthUdpFrame;

