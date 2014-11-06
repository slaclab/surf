-------------------------------------------------------------------------------
-- Title         : Ethernet Client, Core Top Level
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : EthClient.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 10/18/2010
-------------------------------------------------------------------------------
-- Description:
-- Top level source code for general purpose firmware ethenet client.
--	Based on glink_intf.vhd by Susie Zheng
-------------------------------------------------------------------------------
-- Copyright (c) 2010 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 10/18/2010: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
--USE work.ALL;
USE work.EthClientPackage.ALL;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity EthClient is 
   generic ( 
      UdpPort : integer := 8192
   );
   port (

      -- Ethernet clock & reset
      emacClk         : in  std_logic;
      emacClkRst      : in  std_logic;

      -- MAC Interface Signals, Receiver
      emacRxData      : in  std_logic_vector(7 downto 0);
      emacRxValid     : in  std_logic;
      emacRxGoodFrame : in  std_logic;
      emacRxBadFrame  : in  std_logic;

      -- MAC Interface Signals, Transmitter
      emacTxData      : out std_logic_vector(7 downto 0);
      emacTxValid     : out std_logic;
      emacTxAck       : in  std_logic;
      emacTxFirst     : out std_logic;

      -- Ethernet Constants
      ipAddr          : in  IPAddrType;
      macAddr         : in  MacAddrType;

      -- UDP Transmit interface
      udpTxValid      : in  std_logic;
      udpTxFast       : in  std_logic;
      udpTxReady      : out std_logic;
      udpTxData       : in  std_logic_vector(7  downto 0);
      udpTxLength     : in  std_logic_vector(15 downto 0);

      -- UDP Receive interface
      udpRxValid      : out std_logic;
      udpRxData       : out std_logic_vector(7 downto 0);
      udpRxGood       : out std_logic;
      udpRxError      : out std_logic;
      udpRxCount      : out std_logic_vector(15 downto 0)
   );
end EthClient;

-- Define architecture
architecture EthClient of EthClient is

   -- Local Signals
   signal intRxData      : std_logic_vector(7  downto 0);
   signal intRxValid     : std_logic;
   signal intRxGoodFrame : std_logic;
   signal intRxBadFrame  : std_logic;
   signal selRxData      : std_logic_vector(7  downto 0);
   signal selRxError     : std_logic;
   signal selRxGood      : std_logic;
   signal selRxArpValid  : std_logic;
   signal selRxUdpValid  : std_logic;
   signal rxCount        : std_logic_vector(2  downto 0);
   signal rxEthType      : std_logic_vector(15 downto 0);
   signal rxSrcAddr      : MacAddrType;
   signal rxDstAddr      : MacAddrType;
   signal txCount        : std_logic_vector(2  downto 0);
   signal selTxArpValid  : std_logic;
   signal selTxArpReady  : std_logic;
   signal selTxArpData   : std_logic_vector(7 downto 0);
   signal selTxArpDst    : MacAddrType;
   signal selTxArp       : std_logic;
   signal selTxUdpValid  : std_logic;
   signal selTxUdpReady  : std_logic;
   signal selTxUdpData   : std_logic_vector(7 downto 0);
   signal selTxUdpDst    : MacAddrType;
   signal pauseCountRx   : std_logic_vector(15 downto 0);
   signal pauseCountSet  : std_logic;
   signal pauseCount     : std_logic_vector(15 downto 0);
   signal pauseCountPre  : std_logic_vector(2  downto 0);

   -- Ethernet RX States
   constant ST_RX_IDLE   : std_logic_vector(3 downto 0) := "0001";
   constant ST_RX_DST    : std_logic_vector(3 downto 0) := "0010";
   constant ST_RX_SRC    : std_logic_vector(3 downto 0) := "0011";
   constant ST_RX_TYPE   : std_logic_vector(3 downto 0) := "0100";
   constant ST_RX_SEL    : std_logic_vector(3 downto 0) := "0101";
   constant ST_RX_PAUSEA : std_logic_vector(3 downto 0) := "0110";
   constant ST_RX_PAUSEB : std_logic_vector(3 downto 0) := "0111";
   constant ST_RX_PAUSEC : std_logic_vector(3 downto 0) := "1000";
   constant ST_RX_PAUSED : std_logic_vector(3 downto 0) := "1001";
   constant ST_RX_DATA   : std_logic_vector(3 downto 0) := "1010";
   constant ST_RX_DONE   : std_logic_vector(3 downto 0) := "1011";
   signal   curRXState   : std_logic_vector(3 downto 0);

   -- Ethernet TX States
   constant ST_TX_IDLE   : std_logic_vector(2 downto 0) := "001";
   constant ST_TX_ACK    : std_logic_vector(2 downto 0) := "010";  
   constant ST_TX_DST    : std_logic_vector(2 downto 0) := "011";
   constant ST_TX_SRC    : std_logic_vector(2 downto 0) := "100";
   constant ST_TX_TYPE   : std_logic_vector(2 downto 0) := "101";
   constant ST_TX_DATA   : std_logic_vector(2 downto 0) := "110";
   constant ST_TX_PAUSE  : std_logic_vector(2 downto 0) := "111";
   signal   curTXState   : std_logic_vector(2 downto 0);

   -- Debug
   signal locEmacTxData  : std_logic_vector(7 downto 0);

   -- Register delay for simulation
   constant tpd:time := 0.5 ns;

begin

   --------------------------------
   -- Ethernet Receive Logic
   --------------------------------

   -- Register EMAC Data
   process ( emacClk, emacClkRst ) begin
      if emacClkRst = '1' then
         intRxData      <= (others=>'0') after tpd;
         intRxValid     <= '0'           after tpd;
         intRxGoodFrame <= '0'           after tpd;
         intRxBadFrame  <= '0'           after tpd;
      elsif rising_edge(emacClk) then
         intRxData      <= emacRxData      after tpd;
         intRxValid     <= emacRxValid     after tpd;
         intRxGoodFrame <= emacRxGoodFrame after tpd;
         intRxBadFrame  <= emacRxBadFrame  after tpd;
      end if;
   end process;

   -- Sync state logic
   process ( emacClk, emacClkRst ) begin
      if emacClkRst = '1' then
         selRxData      <= (others=>'0')   after tpd;
         selRxError     <= '0'             after tpd;
         selRxGood      <= '0'             after tpd;
         selRxArpValid  <= '0'             after tpd;
         selRxUdpValid  <= '0'             after tpd;
         rxSrcAddr      <= (others=>x"00") after tpd;
         rxDstAddr      <= (others=>x"00") after tpd;
         rxCount        <= (others=>'0')   after tpd;
         rxEthType      <= (others=>'0')   after tpd;
         pauseCountRx   <= (others=>'0')   after tpd;
         pauseCountSet  <= '0'             after tpd;
         curRxState     <= ST_RX_IDLE      after tpd;
      elsif rising_edge(emacClk) then

         -- Outgoing data
         selRxData <= intRxData after tpd;

         -- RX Counter
         if curRxState = ST_RX_IDLE then
            rxCount <= "001" after tpd;
         elsif rxCount = 5 then
            rxCount <= "000" after tpd;
         else
            rxCount <= rxCount + 1 after tpd;
         end if;

         -- State machine
         case curRxState is

            -- IDLE
            when ST_RX_IDLE =>
               selRxError    <= '0' after tpd;
               selRxGood     <= '0' after tpd;
               selRxArpValid <= '0' after tpd;
               selRxUdpValid <= '0' after tpd;
               pauseCountSet <= '0' after tpd;
                  
               -- New frame
               if intRxValid = '1' then
                  rxDstAddr(0) <= intRxData after tpd;
                  curRxState   <= ST_RX_DST after tpd;
               end if;

            -- Dest address
            when ST_RX_DST =>
               selRxError                       <= '0'       after tpd;
               selRxGood                        <= '0' after tpd;
               selRxArpValid                    <= '0'       after tpd;
               selRxUdpValid                    <= '0'       after tpd;
               rxDstAddr(conv_integer(rxCount)) <= intRxData after tpd;

               if intRxValid = '0' then
                  curRxState <= ST_RX_IDLE after tpd;
               elsif rxCount = 5 then
                  curRxState <= ST_RX_SRC after tpd;
               end if;

            -- Source address
            when ST_RX_SRC =>
               selRxError                       <= '0'       after tpd;
               selRxGood                        <= '0' after tpd;
               selRxArpValid                    <= '0'       after tpd;
               selRxUdpValid                    <= '0'       after tpd;
               rxSrcAddr(conv_integer(rxCount)) <= intRxData after tpd;

               if intRxValid = '0' then
                  curRxState <= ST_RX_IDLE after tpd;
               elsif rxCount = 5 then
                  curRxState <= ST_RX_TYPE after tpd;
               end if;

            -- Ethernet Type
            when ST_RX_TYPE =>
               selRxError    <= '0' after tpd;
               selRxGood     <= '0' after tpd;
               selRxArpValid <= '0' after tpd;
               selRxUdpValid <= '0' after tpd;

               if intRxValid = '0' then
                  curRxState <= ST_RX_IDLE after tpd;
               elsif rxCount = 0 then
                  rxEthType(15 downto 8) <= intRxData after tpd;
               else
                  rxEthType(7  downto 0) <= intRxData after tpd;
                  curRxState             <= ST_RX_SEL after tpd;
               end if;

            -- Select destination
            when ST_RX_SEL =>
               selRxError <= '0' after tpd;
               selRxGood  <= '0' after tpd;

               if intRxValid = '0' then
                  curRxState <= ST_RX_IDLE after tpd;

               -- Pause frame
               --elsif rxEthType = EthTypeMac and intRxData = x"00" then
                  --selRxArpValid <= '0'          after tpd;
                  --selRxUdpValid <= '0'          after tpd;
                  --curRxState    <= ST_RX_PAUSEA after tpd;

               -- ARP Request, dest mac is broadcast or our address
               elsif rxEthType = EthTypeARP and 
                     ((rxDstAddr(0) = x"FF" and rxDstAddr(1) = x"FF" and
                       rxDstAddr(2) = x"FF" and rxDstAddr(3) = x"FF" and
                       rxDstAddr(4) = x"FF" and rxDstAddr(5) = x"FF") or
                      rxDstAddr = MacAddr) then
                  selRxArpValid <= '1'        after tpd;
                  selRxUdpValid <= '0'        after tpd;
                  curRxState    <= ST_RX_DATA after tpd;

               -- IPV4 Packet
               elsif rxEthType = EthTypeIPV4 and rxDstAddr = MacAddr then
                  selRxArpValid <= '0'        after tpd;
                  selRxUdpValid <= '1'        after tpd;
                  curRxState    <= ST_RX_DATA after tpd;
               else
                  selRxArpValid <= '0'        after tpd;
                  selRxUdpValid <= '0'        after tpd;
                  curRxState    <= ST_RX_DATA after tpd;
               end if;

            -- Pause A
            when ST_RX_PAUSEA =>
               selRxError    <= '0' after tpd;
               selRxGood     <= '0' after tpd;

               if intRxData = x"01" then
                  curRxState <= ST_RX_PAUSEB after tpd;
               else
                  curRxState <= ST_RX_DATA   after tpd;
               end if;

            when ST_RX_PAUSEC =>
               selRxError                <= '0'          after tpd;
               selRxGood                 <= '0'          after tpd;
               pauseCountRx(15 downto 8) <= intRxData    after tpd;
               curRxState                <= ST_RX_PAUSEB after tpd;

            when ST_RX_PAUSED =>
               selRxError                <= '0'          after tpd;
               selRxGood                 <= '0'          after tpd;
               pauseCountRx(7  downto 0) <= intRxData    after tpd;
               pauseCountSet             <= '1'          after tpd;
               curRxState                <= ST_RX_DATA   after tpd;

            -- Move Data
            when ST_RX_DATA =>
               selRxError    <= '0' after tpd;
               selRxGood     <= '0' after tpd;
               pauseCountSet <= '0' after tpd;

               if intRxValid = '0' then
                  curRxState <= ST_RX_DONE after tpd;
               end if;

            -- Done
            when ST_RX_DONE =>
               selRxArpValid <= '0' after tpd;
               selRxUdpValid <= '0' after tpd;

               if intRxGoodFrame = '1' or intRxBadFrame  = '1' then
                  curRxState <= ST_RX_IDLE     after tpd;
                  selRxError <= intRxBadFrame  after tpd;
                  selRxGood  <= intRxGoodFrame after tpd;
               end if;

            when others => curRxState <= ST_RX_IDLE after tpd;
         end case;
      end if;
   end process;


   --------------------------------
   -- Ethernet Transmit Logic
   --------------------------------

   -- Transmit
   
   emacTxData <= locEmacTxData;
   
   process ( emacClk, emacClkRst ) begin
      if emacClkRst = '1' then
         locEmacTxData     <= (others=>'0') after tpd;
         emacTxValid    <= '0'           after tpd;
         emacTxFirst    <= '0'           after tpd;
         selTxArpReady  <= '0'           after tpd;
         selTxUdpReady  <= '0'           after tpd;
         selTxArp       <= '0'           after tpd;
         txCount        <= (others=>'0') after tpd;
         pauseCount     <= (others=>'0') after tpd;
         pauseCountPre  <= (others=>'0') after tpd;
         curTxState     <= ST_TX_IDLE    after tpd;
      elsif rising_edge(emacClk) then

         -- Pause counter
         if pauseCountSet = '1' then
            pauseCount    <= pauseCountRx  after tpd;
            pauseCountPre <= (others=>'0') after tpd;

         elsif curTxState = ST_TX_IDLE then

            -- Prescale, 512 bit times at 1gbs = 51.2 clocks @ 125Mhz
            if pauseCountPre = 52 then
               pauseCountPre <= (others=>'0') after tpd;
               if pauseCount /= 0 then
                  pauseCount <= pauseCount - 1 after tpd;
               end if;
            else
               pauseCountPre <= pauseCountPre + 1 after tpd;
            end if;
         end if; 

         -- TX Counter
         if curTxState = ST_TX_IDLE or txCount = 5 then
            txCount <= "000" after tpd;
         elsif curTxState = ST_TX_ACK then
            txCount <= "010" after tpd;
         else
            txCount <= txCount + 1 after tpd;
         end if;

         -- State machine
         case curTxState is

            -- IDLE
            when ST_TX_IDLE =>
               locEmacTxData    <= (others=>'0') after tpd;
               emacTxValid   <= '0'           after tpd;
               emacTxFirst   <= '0'           after tpd;
               selTxArpReady <= '0'           after tpd;
               selTxUdpReady <= '0'           after tpd;

               -- Don't transmit is pause counter is non zero
               --if pauseCount = 0 then
                  if selTxArpValid = '1' then
                     selTxArp      <= '1'            after tpd;
                     curTxState    <= ST_TX_ACK      after tpd;
                     locEmacTxData <= selTxArpDst(0) after tpd;
                  elsif selTxUdpValid = '1' then
                     selTxArp      <= '0'            after tpd;
                     curTxState    <= ST_TX_ACK      after tpd;
                     locEmacTxData <= selTxUdpDst(0) after tpd;
                  end if;
               --end if;
               
            -- Wait on ack
            when ST_TX_ACK =>
               emacTxValid   <= '1'       after tpd;
               selTxArpReady <= '0'       after tpd;
               selTxUdpReady <= '0'       after tpd;
               emacTxFirst   <= emacTxAck after tpd;

               if emacTxAck = '1' then
                  if selTxArp = '1' then
                     locEmacTxData <= selTxArpDst(1) after tpd;
                  else
                     locEmacTxData <= selTxUdpDst(1) after tpd;
                  end if;
                  curTxState <= ST_TX_DST after tpd;
               end if;

            -- Dest address
            when ST_TX_DST =>
               emacTxValid   <= '1' after tpd;
               selTxArpReady <= '0' after tpd;
               selTxUdpReady <= '0' after tpd;
               emacTxFirst   <= '0' after tpd;

               if selTxArp = '1' then
                  locEmacTxData <= selTxArpDst(conv_integer(txCount)) after tpd;
               else
                  locEmacTxData <= selTxUdpDst(conv_integer(txCount)) after tpd;
               end if;

               if txCount = 5 then
                  curTxState <= ST_TX_SRC after tpd;
               end if;

            -- Source address
            when ST_TX_SRC =>
               emacTxValid   <= '1' after tpd;
               selTxArpReady <= '0' after tpd;
               selTxUdpReady <= '0' after tpd;
               emacTxFirst   <= '0' after tpd;

               locEmacTxData <= MacAddr(conv_integer(txCount)) after tpd;

               if txCount = 5 then
                  curTxState <= ST_TX_TYPE after tpd;
               end if;

            -- Ethernet Type
            when ST_TX_TYPE =>
               emacTxValid   <= '1' after tpd;
               emacTxFirst   <= '0' after tpd;

               if selTxArp = '1' then
                  if txCount = 0 then
                     locEmacTxData <= EthTypeARP(15 downto 8) after tpd;
                  else
                     locEmacTxData <= EthTypeARP(7  downto 0) after tpd;
                  end if;
               else
                  if txCount = 0 then
                     locEmacTxData <= EthTypeIPV4(15 downto 8) after tpd;
                  else
                     locEmacTxData <= EthTypeIPV4(7  downto 0) after tpd;
                  end if;
               end if;

               if txCount = 1 then
                  curTxState    <= ST_TX_DATA   after tpd;
                  selTxArpReady <= selTxArp     after tpd;
                  selTxUdpReady <= not selTxArp after tpd;
               end if;

            -- Payload Data
            when ST_TX_DATA =>
               emacTxValid   <= '1'          after tpd;
               emacTxFirst   <= '0'          after tpd;
               selTxArpReady <= selTxArp     after tpd;
               selTxUdpReady <= not selTxArp after tpd;

               if selTxArp = '1' then
                  emacTxValid <= selTxArpValid after tpd;
                  locEmacTxData  <= selTxArpData  after tpd;
                  if selTxArpValid = '0' then
                     curTxState <= ST_TX_IDLE;
                  end if;
               else
                  emacTxValid <= selTxUdpValid after tpd;
                  locEmacTxData  <= selTxUdpData  after tpd;
                  if selTxUdpValid = '0' then
                     curTxState <= ST_TX_IDLE;
                  end if;
               end if;

            when others => curTxState <= ST_TX_IDLE after tpd;
         end case;
      end if;
   end process;


   --------------------------------
   -- ARP Engine
   --------------------------------
   U_EthClientArp : entity work.EthClientArp port map (
      emacClk    => emacClk,
      emacClkRst => emacClkRst,
      ipAddr     => ipAddr,
      macAddr    => macAddr,
      rxData     => selRxData,
      rxError    => selRxError,
      rxGood     => selRxGood,
      rxValid    => selRxArpValid,
      rxSrc      => rxSrcAddr,
      txValid    => selTxArpValid,
      txReady    => selTxArpReady,
      txData     => selTxArpData,
      txDst      => selTxArpDst
   );


   --------------------------------
   -- UDP Engine
   --------------------------------
   U_EthClientUdp: entity work.EthClientUdp generic map ( UdpPort => UdpPort ) port map (
      emacClk     => emacClk,
      emacClkRst  => emacClkRst,
      ipAddr      => ipAddr,
      rxData      => selRxData,
      rxError     => selRxError,
      rxGood      => selRxGood,
      rxValid     => selRxUdpValid,
      rxSrc       => rxSrcAddr,
      txValid     => selTxUdpValid,
      txReady     => selTxUdpReady,
      txData      => selTxUdpData,
      txDst       => selTxUdpDst,
      udpTxValid  => udpTxValid,
      udpTxFast   => udpTxFast,
      udpTxReady  => udpTxReady,
      udpTxData   => udpTxData,
      udpTxLength => udpTxLength,
      udpRxValid  => udpRxValid,
      udpRxData   => udpRxData,
      udpRxError  => udpRxError,
      udpRxCount  => udpRxCount,
      udpRxGood   => udpRxGood
   );


end EthClient;

