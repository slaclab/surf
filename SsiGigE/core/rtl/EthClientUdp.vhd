-------------------------------------------------------------------------------
-- Title         : Ethernet Client, UDP Processor
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : EthClientUdp.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 10/18/2010
-------------------------------------------------------------------------------
-- Description:
-- UDP processor source code for general purpose firmware ethenet client.
-------------------------------------------------------------------------------
-- Copyright (c) 2010 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 10/18/2010: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
--USE work.ALL;
use work.EthClientPackage.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity EthClientUdp is 
   generic ( 
      UdpPort : integer := 8192
   );
   port (

      -- Ethernet clock & reset
      emacClk     : in  std_logic;
      emacClkRst  : in  std_logic;

      -- Local IP Address
      ipAddr      : in  IPAddrType;

      -- Receive interface
      rxData      : in  std_logic_vector(7 downto 0);
      rxError     : in  std_logic;
      rxGood      : in  std_logic;
      rxValid     : in  std_logic;
      rxSrc       : in  MacAddrType;

      -- Transmit interface
      txValid     : out std_logic;
      txReady     : in  std_logic;
      txData      : out std_logic_vector(7 downto 0);
      txDst       : out MacAddrType;

      -- UDP Transmit interface
      udpTxFast   : in  std_logic;
      udpTxValid  : in  std_logic;
      udpTxReady  : out std_logic;
      udpTxData   : in  std_logic_vector(7  downto 0);
      udpTxLength : in  std_logic_vector(15 downto 0);

      -- UDP Receive interface
      udpRxValid  : out std_logic;
      udpRxData   : out std_logic_vector(7 downto 0);
      udpRxCount  : out std_logic_vector(15 downto 0);
      udpRxError  : out std_logic;
      udpRxGood   : out std_logic
   );

end EthClientUdp;


-- Define architecture
architecture EthClientUdp of EthClientUdp is

   -- Local Signals
   signal rxUdpHead    : UDPMsgType;
   signal txUdpHead    : UDPMsgType;
   signal rxCount      : std_logic_vector(15 downto 0);
   signal txCount      : std_logic_vector(15 downto 0);
   signal myPortAddr   : std_logic_vector(15 downto 0);
   signal lastIpAddr   : IPAddrType;
   signal lastMacAddr  : MacAddrType;
   signal fastMacAddr  : MacAddrType;
   signal lastPort     : std_logic_vector(15 downto 0);
   signal intTxLength  : std_logic_vector(15 downto 0);
   signal IPV4Length   : std_logic_vector(15 downto 0);
   signal UDPLength    : std_logic_vector(15 downto 0);
   signal compCSumAA   : std_logic_vector(16 downto 0);
   signal compCSumAB   : std_logic_vector(16 downto 0);
   signal compCSumAC   : std_logic_vector(16 downto 0);
   signal compCSumAD   : std_logic_vector(16 downto 0);
   signal compCSumBA   : std_logic_vector(17 downto 0);
   signal compCSumBB   : std_logic_vector(17 downto 0);
   signal compCSumC    : std_logic_vector(18 downto 0);
   signal compCSumD    : std_logic_vector(19 downto 0);
   signal CompCheckSum : std_logic_vector(20 downto 0);
   signal pktNum       : std_logic_vector(7  downto 0);
   signal intPayCount  : std_logic_vector(15 downto 0);
   signal intRxValid   : std_logic;
   signal intRxError   : std_logic;
   signal intRxGood    : std_logic;
   
   -- RX States
   constant ST_RX_IDLE   : std_logic_vector(2 downto 0) := "000";
   constant ST_RX_HEAD   : std_logic_vector(2 downto 0) := "001";
   constant ST_RX_CHECK  : std_logic_vector(2 downto 0) := "010";
   constant ST_RX_DATA   : std_logic_vector(2 downto 0) := "011";
   constant ST_RX_DUMP   : std_logic_vector(2 downto 0) := "100";
   constant ST_RX_WAIT   : std_logic_vector(2 downto 0) := "101";
   signal   curRXState   : std_logic_vector(2 downto 0);

   -- TX States
   constant ST_TX_IDLE   : std_logic_vector(1 downto 0) := "00";
   constant ST_TX_HEAD   : std_logic_vector(1 downto 0) := "01";
   constant ST_TX_DATA   : std_logic_vector(1 downto 0) := "10";
   constant ST_TX_PAD    : std_logic_vector(1 downto 0) := "11";
   signal   curTXState   : std_logic_vector(1 downto 0);

   -- Debug
   signal   locTxData    : std_logic_vector(7 downto 0);
   signal   locUdpRxValid: std_logic;
   signal   locTxValid   : std_logic;
   
   -- Register delay for simulation
   constant tpd:time := 0.5 ns;

begin

   -- Convert port address
   myPortAddr <= conv_std_logic_vector(UdpPort,16);

   -- Mac address for fast transfers
   fastMacAddr(0) <= x"16";
   fastMacAddr(1) <= x"44";
   fastMacAddr(2) <= x"56";
   fastMacAddr(3) <= x"00";
   fastMacAddr(4) <= x"03";
   fastMacAddr(5) <= x"01";

   --------------------------------
   -- Receive Logic
   --------------------------------

   udpRxValid <= intRxValid;
   udpRxError <= intRxError;
   udpRxGood  <= intRxGood;
   udpRxCount <= intPayCount;

   -- Sync state logic
   process ( emacClk, emacClkRst ) begin
      if emacClkRst = '1' then
         rxCount     <= (others=>'0')   after tpd;
         rxUdpHead   <= (others=>x"00") after tpd;
         intRxValid  <= '0'             after tpd;
         locUdpRxValid  <= '0'          after tpd;
         udpRxData   <= (others=>'0')   after tpd;
         intRxError  <= '0'             after tpd;
         intRxGood   <= '0'             after tpd;
         lastIpAddr  <= (others=>x"00") after tpd;
         lastMacAddr <= (others=>x"00") after tpd;
         lastPort    <= (others=>'0')   after tpd;
         intPayCount <= (others=>'0')   after tpd;
         curRxState  <= ST_RX_IDLE      after tpd;
      elsif rising_edge(emacClk) then

         -- Payload counter
         if intRxError = '1' or intRxGood = '1' then
            intPayCount <= (others=>'0') after tpd;
         elsif intRxValid = '1' then
            intPayCount <= intPayCount + 1 after tpd;
         end if;

         -- RX Data
         if curRxState = ST_RX_IDLE then
            rxUdpHead(0) <= rxData after tpd; 
         elsif curRxState = ST_RX_HEAD then
           rxUdpHead(conv_integer(rxCount)) <= rxData after tpd; 
         end if;

         -- RX Counter
         if rxValid = '0' then
            rxCount <= x"0000" after tpd;
         elsif curRxState = ST_RX_CHECK then
            rxCount <= x"0008" after tpd;
         elsif rxCount /= x"FFFF" then
            rxCount <= rxCount + 1 after tpd;
         end if;

         -- Data RX
         udpRxData <= rxData after tpd;

         -- State machine
         case curRxState is

            -- IDLE
            when ST_RX_IDLE =>
               if rxValid = '1' then
                  curRxState <= ST_RX_HEAD after tpd;
               end if;
               intRxValid <= '0' after tpd;
               locUdpRxValid <= '0' after tpd;
               intRxError <= '0' after tpd;
               intRxGood  <= '0' after tpd;

            -- IPV4 Header
            when ST_RX_HEAD =>
               if rxValid = '0' then
                  curRxState <= ST_RX_IDLE after tpd;
               elsif rxCount = 26 then
                  curRxState <= ST_RX_CHECK after tpd;
               end if;
               intRxValid <= '0' after tpd;
               locUdpRxValid <= '0' after tpd;
               intRxError <= '0' after tpd;
               intRxGood  <= '0' after tpd;

            -- Check header
            when ST_RX_CHECK =>
               if rxValid = '0' then
                  curRxState <= ST_RX_IDLE after tpd;
               elsif rxUdpHead(9) = UDPProtocol              and  -- Protocol
                     rxUdpHead(16) = ipAddr(3)               and  -- My IP Address
                     rxUdpHead(17) = ipAddr(2)               and  -- My IP Address
                     rxUdpHead(18) = ipAddr(1)               and  -- My IP Address
                     rxUdpHead(19) = ipAddr(0)               and  -- My IP Address
                     rxUdpHead(22) = myPortAddr(15 downto 8) and  -- My UDP Port
                     rxUdpHead(23) = myPortAddr(7  downto 0) then -- My UDP Port

                  -- Store some fields for transmittion
                  lastIpAddr(3)         <= rxUdpHead(12) after tpd;
                  lastIpAddr(2)         <= rxUdpHead(13) after tpd;
                  lastIpAddr(1)         <= rxUdpHead(14) after tpd;
                  lastIpAddr(0)         <= rxUdpHead(15) after tpd;
                  lastMacAddr           <= rxSrc         after tpd;
                  lastPort(15 downto 8) <= rxUdpHead(20) after tpd;
                  lastPort(7  downto 0) <= rxUdpHead(21) after tpd;
                  curRxState            <= ST_RX_DATA    after tpd;
               else
                  curRxState <= ST_RX_DUMP after tpd;
               end if;
               intRxValid <= '0' after tpd;
               locUdpRxValid <= '0' after tpd;
               intRxError <= '0' after tpd;
               intRxGood  <= '0' after tpd;

            -- Output Data
            when ST_RX_DATA =>
               if rxValid = '0' or (rxCount(15 downto 8) = rxUdpHead(24) and 
                                    rxCount(7  downto 0) = rxUdpHead(25)) then 
                  intRxValid <= '0'        after tpd;
                  locUdpRxValid <= '0'     after tpd;
                  curRxState <= ST_RX_WAIT after tpd;
               else
                  intRxValid <= '1';
                  locUdpRxValid <= '1';
               end if;
               intRxError <= '0' after tpd;
               intRxGood  <= '0' after tpd;

            -- Dump Data
            when ST_RX_DUMP =>
               if rxValid = '0' then
                  curRxState <= ST_RX_IDLE after tpd;
               end if;
               intRxValid <= '0' after tpd;
               locUdpRxValid <= '0' after tpd;
               intRxError <= '0' after tpd;
               intRxGood  <= '0' after tpd;

            -- Wait
            when ST_RX_WAIT =>
               if rxError = '1' or rxGood = '1' then
                  curRxState <= ST_RX_IDLE after tpd;
               end if;
               intRxValid <= '0'     after tpd;
               locUdpRxValid <= '0'     after tpd;
               intRxError <= rxError after tpd;
               intRxGood  <= rxGood  after tpd;

            when others => curRxState <= ST_RX_IDLE after tpd;
         end case;
      end if;
   end process;


   --------------------------------
   -- Transmit Logic
   --------------------------------

   -- Checksum and length adder
   process ( emacClk, emacClkRst ) begin
      if emacClkRst = '1' then
         compCSumAA   <= (others=>'0') after tpd;
         compCSumAB   <= (others=>'0') after tpd;
         compCSumAC   <= (others=>'0') after tpd;
         compCSumAD   <= (others=>'0') after tpd;
         compCSumBA   <= (others=>'0') after tpd;
         compCSumBB   <= (others=>'0') after tpd;
         compCSumC    <= (others=>'0') after tpd;
         compCSumD    <= (others=>'0') after tpd;
         compCheckSum <= (others=>'0') after tpd;
      elsif rising_edge(emacClk) then

         -- Level 0
         compCSumAA   <= ('0' & txUdpHead(0)  & txUdpHead(1))  + ('0' & txUdpHead(2)  & txUdpHead(3))  after tpd;
         compCSumAB   <= ('0' & txUdpHead(4)  & txUdpHead(5))  + ('0' & txUdpHead(6)  & txUdpHead(7))  after tpd;
         compCSumAC   <= ('0' & txUdpHead(8)  & txUdpHead(9))  + ('0' & txUdpHead(12) & txUdpHead(13)) after tpd;
         compCSumAD   <= ('0' & txUdpHead(14) & txUdpHead(15)) + ('0' & txUdpHead(16) & txUdpHead(17)) after tpd;

         -- Level 1
         compCSumBA   <= ('0' & compCSumAA) + ('0' & compCSumAB) after tpd;
         compCSumBB   <= ('0' & compCSumAC) + ('0' & compCSumAD) after tpd;

         -- Level 2
         compCSumC    <= ('0' & compCSumBA) + ('0' & compCSumBB) after tpd;

         -- Level 3
         compCSumD    <= ('0' & compCSumC) + ("000" & txUdpHead(18) & txUdpHead(19)) after tpd;

         -- Level 4
         compCheckSum <= ('0' & x"0000" & compCSumD(19 downto 16)) + ("00000" & compCSumD(15 downto 0));
                        
      end if;
   end process;

   -- Define IPV4/UDP Header
   txUdpHead(0)  <= x"45";                         -- Header length 5, IPVersion 4
   txUdpHead(1)  <= x"00";                         -- Type of service
   txUdpHead(2)  <= IPV4Length(15 downto 8);       -- Length
   txUdpHead(3)  <= IPV4Length(7  downto 0);       -- Length
   txUdpHead(4)  <= x"00";                         -- Id
   txUdpHead(5)  <= x"00";                         -- Id
   txUdpHead(6)  <= x"00";                         -- flags, frag
   txUdpHead(7)  <= x"00";                         -- flags, frag
   txUdpHead(8)  <= x"06";                         -- Time to live
   txUdpHead(9)  <= UDPProtocol;                   -- Protocol
   txUdpHead(10) <= not compCheckSum(15 downto 8); -- Checksum
   txUdpHead(11) <= not compCheckSum(7  downto 0); -- Checksum
   txUdpHead(12) <= ipAddr(3);                     
   txUdpHead(13) <= ipAddr(2);                     
   txUdpHead(14) <= ipAddr(1);                     
   txUdpHead(15) <= ipAddr(0);                     
   txUdpHead(16) <= lastIpAddr(3);                 
   txUdpHead(17) <= lastIpAddr(2);                 
   txUdpHead(18) <= lastIpAddr(1);                 
   txUdpHead(19) <= lastIpAddr(0);
   txUdpHead(20) <= myPortAddr(15 downto 8);       
   txUdpHead(21) <= myPortAddr(7  downto 0);                 
   txUdpHead(22) <= lastPort(15 downto 8);
   txUdpHead(23) <= lastPort(7  downto 0);
   txUdpHead(24) <= UDPLength(15 downto 8);        
   txUdpHead(25) <= UDPLength(7  downto 0);        
   txUdpHead(26) <= x"00";                         -- UDP Checksum unused
   txUdpHead(27) <= x"00";                         -- UDP Checksum unused

   -- Transmit
   txData  <= locTxData;
   txValid <= locTxValid;
   process ( emacClk, emacClkRst ) begin
      if emacClkRst = '1' then
         IPV4Length        <= (others=>'0') after tpd;
         UDPLength         <= (others=>'0') after tpd;
         locTxValid        <= '0'             after tpd;
         locTxData         <= (others=>'0')   after tpd;
         txCount           <= (others=>'0')   after tpd;
         pktNum            <= (others=>'0')   after tpd;
         txDst             <= (others=>x"00") after tpd;
         udpTxReady        <= '0'             after tpd;
         intTxLength       <= (others=>'0')   after tpd;
         curTxState        <= ST_TX_IDLE      after tpd;
      elsif rising_edge(emacClk) then

         if (udpTxValid = '1') then
            -- UDP Length, 8 Byte + length + SOF/EOF frames
            UDPLength  <= udpTxLength + x"0008"; --+ "10";
            -- IPV4 Length, 20 Byte IPV4 + UDP Length + SOF/EOF frames
            IPV4Length <= udpTxLength + x"001C"; --+ "10";
         end if;
         
         -- TX Data
         if txReady = '0' then
            locTxData <= txUdpHead(0) after tpd;
         elsif curTxState = ST_TX_HEAD then
            locTxData <= txUdpHead(conv_integer(txCount)) after tpd;
         elsif curTxState = ST_TX_PAD then
            locTxData <= (others=>'0') after tpd;
         else
            locTxData <= udpTxData after tpd;
         end if;

         -- TX Counter
         if curTxState = ST_TX_HEAD and txCount = 27 then
            txCount <= (others=>'0') after tpd;
         elsif txReady = '0' or curTxState = ST_TX_IDLE then
            txCount <= x"0001" after tpd;
         elsif txCount /= x"FFFF" then
            txCount <= txCount + 1 after tpd;
         end if;

         -- State machine
         case curTxState is

            -- IDLE
            when ST_TX_IDLE =>
               if udpTxValid = '1' then
                  curTxState       <= ST_TX_HEAD  after tpd;
                  locTxValid       <= '1'         after tpd;
                  if udpTxFast = '1' then
                     txDst         <= fastMacAddr after tpd; 
                  else
                  txDst            <= lastMacAddr after tpd; 
                  end if;
                  intTxLength      <= udpTxLength after tpd;
--                   pktNum           <= pktNum + 1  after tpd;
               end if;
               udpTxReady          <= '0'         after tpd;
         
            -- Header
            when ST_TX_HEAD =>
--                   curTxState <= ST_TX_DATA after tpd; -- One clk delay for udpTxData to arrive
--                   
--                els
               if txReady = '1' and txCount = 26 then
                  udpTxReady <= '1'        after tpd; -- Asserting one clk early for
               end if;
               if txReady = '1' and txCount = 27 then --26
                  --udpTxReady <= '1'        after tpd; -- Asserting one clk early for
                  curTxState <= ST_TX_DATA after tpd;
               elsif locTxValid = '0' then
                  curTxState <= ST_TX_IDLE after tpd;
               end if;

            -- Data  
            when ST_TX_DATA =>
               if txCount = intTxLength then
                  if txCount < 18 then
                     curTxState <= ST_TX_PAD after tpd;
                  else
                     curTxState <= ST_TX_IDLE after tpd;
                     locTxValid <= '0'       after tpd;
                  end if;
                  
                  udpTxReady    <= '0'       after tpd;
               end if;

            -- PAD to 46 bytes
            when ST_TX_PAD =>
               if txCount >= 18 then
                  curTxState    <= ST_TX_IDLE after tpd;
                  locTxValid    <= '0'       after tpd;
               end if;

            when others => curTxState <= ST_TX_IDLE after tpd;
         end case;
      end if;
   end process;

end EthClientUdp;

