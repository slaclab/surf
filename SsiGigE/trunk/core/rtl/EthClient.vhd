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
      TPD_G      : time    := 1 ns;
      UDP_PORT_G : natural := 8192);
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
      udpRxCount      : out std_logic_vector(15 downto 0));
end EthClient;

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

begin

   --------------------------------
   -- Ethernet Receive Logic
   --------------------------------

   -- Register EMAC Data
   process ( emacClk ) 
   begin
      if rising_edge(emacClk) then
         if emacClkRst = '1' then
            intRxData      <= (others=>'0') after TPD_G;
            intRxValid     <= '0'           after TPD_G;
            intRxGoodFrame <= '0'           after TPD_G;
            intRxBadFrame  <= '0'           after TPD_G;
         else
            intRxData      <= emacRxData      after TPD_G;
            intRxValid     <= emacRxValid     after TPD_G;
            intRxGoodFrame <= emacRxGoodFrame after TPD_G;
            intRxBadFrame  <= emacRxBadFrame  after TPD_G;
         end if;
      end if;
   end process;

   -- Sync state logic
   process ( emacClk ) 
   begin
      if rising_edge(emacClk) then
         if emacClkRst = '1' then
            selRxData      <= (others=>'0')   after TPD_G;
            selRxError     <= '0'             after TPD_G;
            selRxGood      <= '0'             after TPD_G;
            selRxArpValid  <= '0'             after TPD_G;
            selRxUdpValid  <= '0'             after TPD_G;
            rxSrcAddr      <= (others=>x"00") after TPD_G;
            rxDstAddr      <= (others=>x"00") after TPD_G;
            rxCount        <= (others=>'0')   after TPD_G;
            rxEthType      <= (others=>'0')   after TPD_G;
            pauseCountRx   <= (others=>'0')   after TPD_G;
            pauseCountSet  <= '0'             after TPD_G;
            curRxState     <= ST_RX_IDLE      after TPD_G;
         else
            -- Outgoing data
            selRxData <= intRxData after TPD_G;

            -- RX Counter
            if curRxState = ST_RX_IDLE then
               rxCount <= "001" after TPD_G;
            elsif rxCount = 5 then
               rxCount <= "000" after TPD_G;
            else
               rxCount <= rxCount + 1 after TPD_G;
            end if;

            -- State machine
            case curRxState is

               -- IDLE
               when ST_RX_IDLE =>
                  selRxError    <= '0' after TPD_G;
                  selRxGood     <= '0' after TPD_G;
                  selRxArpValid <= '0' after TPD_G;
                  selRxUdpValid <= '0' after TPD_G;
                  pauseCountSet <= '0' after TPD_G;
                     
                  -- New frame
                  if intRxValid = '1' then
                     rxDstAddr(0) <= intRxData after TPD_G;
                     curRxState   <= ST_RX_DST after TPD_G;
                  end if;

               -- Dest address
               when ST_RX_DST =>
                  selRxError                       <= '0'       after TPD_G;
                  selRxGood                        <= '0'       after TPD_G;
                  selRxArpValid                    <= '0'       after TPD_G;
                  selRxUdpValid                    <= '0'       after TPD_G;
                  rxDstAddr(conv_integer(rxCount)) <= intRxData after TPD_G;

                  if intRxValid = '0' then
                     curRxState <= ST_RX_IDLE after TPD_G;
                  elsif rxCount = 5 then
                     curRxState <= ST_RX_SRC after TPD_G;
                  end if;

               -- Source address
               when ST_RX_SRC =>
                  selRxError                       <= '0'       after TPD_G;
                  selRxGood                        <= '0'       after TPD_G;
                  selRxArpValid                    <= '0'       after TPD_G;
                  selRxUdpValid                    <= '0'       after TPD_G;
                  rxSrcAddr(conv_integer(rxCount)) <= intRxData after TPD_G;

                  if intRxValid = '0' then
                     curRxState <= ST_RX_IDLE after TPD_G;
                  elsif rxCount = 5 then
                     curRxState <= ST_RX_TYPE after TPD_G;
                  end if;

               -- Ethernet Type
               when ST_RX_TYPE =>
                  selRxError    <= '0' after TPD_G;
                  selRxGood     <= '0' after TPD_G;
                  selRxArpValid <= '0' after TPD_G;
                  selRxUdpValid <= '0' after TPD_G;

                  if intRxValid = '0' then
                     curRxState <= ST_RX_IDLE after TPD_G;
                  elsif rxCount = 0 then
                     rxEthType(15 downto 8) <= intRxData after TPD_G;
                  else
                     rxEthType(7  downto 0) <= intRxData after TPD_G;
                     curRxState             <= ST_RX_SEL after TPD_G;
                  end if;

               -- Select destination
               when ST_RX_SEL =>
                  selRxError <= '0' after TPD_G;
                  selRxGood  <= '0' after TPD_G;

                  if intRxValid = '0' then
                     curRxState <= ST_RX_IDLE after TPD_G;

                  -- Pause frame
                  --elsif rxEthType = EthTypeMac and intRxData = x"00" then
                     --selRxArpValid <= '0'          after TPD_G;
                     --selRxUdpValid <= '0'          after TPD_G;
                     --curRxState    <= ST_RX_PAUSEA after TPD_G;

                  -- ARP Request, dest mac is broadcast or our address
                  elsif rxEthType = EthTypeARP and 
                        ((rxDstAddr(0) = x"FF" and rxDstAddr(1) = x"FF" and
                          rxDstAddr(2) = x"FF" and rxDstAddr(3) = x"FF" and
                          rxDstAddr(4) = x"FF" and rxDstAddr(5) = x"FF") or
                         rxDstAddr = MacAddr) then
                     selRxArpValid <= '1'        after TPD_G;
                     selRxUdpValid <= '0'        after TPD_G;
                     curRxState    <= ST_RX_DATA after TPD_G;

                  -- IPV4 Packet
                  elsif rxEthType = EthTypeIPV4 and rxDstAddr = MacAddr then
                     selRxArpValid <= '0'        after TPD_G;
                     selRxUdpValid <= '1'        after TPD_G;
                     curRxState    <= ST_RX_DATA after TPD_G;
                  else
                     selRxArpValid <= '0'        after TPD_G;
                     selRxUdpValid <= '0'        after TPD_G;
                     curRxState    <= ST_RX_DATA after TPD_G;
                  end if;

               -- Pause A
               when ST_RX_PAUSEA =>
                  selRxError    <= '0' after TPD_G;
                  selRxGood     <= '0' after TPD_G;

                  if intRxData = x"01" then
                     curRxState <= ST_RX_PAUSEB after TPD_G;
                  else
                     curRxState <= ST_RX_DATA   after TPD_G;
                  end if;

               when ST_RX_PAUSEC =>
                  selRxError                <= '0'          after TPD_G;
                  selRxGood                 <= '0'          after TPD_G;
                  pauseCountRx(15 downto 8) <= intRxData    after TPD_G;
                  curRxState                <= ST_RX_PAUSEB after TPD_G;

               when ST_RX_PAUSED =>
                  selRxError                <= '0'          after TPD_G;
                  selRxGood                 <= '0'          after TPD_G;
                  pauseCountRx(7  downto 0) <= intRxData    after TPD_G;
                  pauseCountSet             <= '1'          after TPD_G;
                  curRxState                <= ST_RX_DATA   after TPD_G;

               -- Move Data
               when ST_RX_DATA =>
                  selRxError    <= '0' after TPD_G;
                  selRxGood     <= '0' after TPD_G;
                  pauseCountSet <= '0' after TPD_G;

                  if intRxValid = '0' then
                     curRxState <= ST_RX_DONE after TPD_G;
                  end if;

               -- Done
               when ST_RX_DONE =>
                  selRxArpValid <= '0' after TPD_G;
                  selRxUdpValid <= '0' after TPD_G;

                  if intRxGoodFrame = '1' or intRxBadFrame  = '1' then
                     curRxState <= ST_RX_IDLE     after TPD_G;
                     selRxError <= intRxBadFrame  after TPD_G;
                     selRxGood  <= intRxGoodFrame after TPD_G;
                  end if;

               when others => curRxState <= ST_RX_IDLE after TPD_G;
            end case;
         end if;
      end if;
   end process;


   --------------------------------
   -- Ethernet Transmit Logic
   --------------------------------

   -- Transmit
   
   emacTxData <= locEmacTxData;
   
   process ( emacClk ) 
   begin
      if rising_edge(emacClk) then
         if emacClkRst = '1' then
            locEmacTxData     <= (others=>'0') after TPD_G;
            emacTxValid    <= '0'           after TPD_G;
            emacTxFirst    <= '0'           after TPD_G;
            selTxArpReady  <= '0'           after TPD_G;
            selTxUdpReady  <= '0'           after TPD_G;
            selTxArp       <= '0'           after TPD_G;
            txCount        <= (others=>'0') after TPD_G;
            pauseCount     <= (others=>'0') after TPD_G;
            pauseCountPre  <= (others=>'0') after TPD_G;
            curTxState     <= ST_TX_IDLE    after TPD_G;
         else
            -- Pause counter
            if pauseCountSet = '1' then
               pauseCount    <= pauseCountRx  after TPD_G;
               pauseCountPre <= (others=>'0') after TPD_G;

            elsif curTxState = ST_TX_IDLE then

               -- Prescale, 512 bit times at 1gbs = 51.2 clocks @ 125Mhz
               if pauseCountPre = 52 then
                  pauseCountPre <= (others=>'0') after TPD_G;
                  if pauseCount /= 0 then
                     pauseCount <= pauseCount - 1 after TPD_G;
                  end if;
               else
                  pauseCountPre <= pauseCountPre + 1 after TPD_G;
               end if;
            end if; 

            -- TX Counter
            if curTxState = ST_TX_IDLE or txCount = 5 then
               txCount <= "000" after TPD_G;
            elsif curTxState = ST_TX_ACK then
               txCount <= "010" after TPD_G;
            else
               txCount <= txCount + 1 after TPD_G;
            end if;

            -- State machine
            case curTxState is

               -- IDLE
               when ST_TX_IDLE =>
                  locEmacTxData    <= (others=>'0') after TPD_G;
                  emacTxValid   <= '0'           after TPD_G;
                  emacTxFirst   <= '0'           after TPD_G;
                  selTxArpReady <= '0'           after TPD_G;
                  selTxUdpReady <= '0'           after TPD_G;

                  -- Don't transmit is pause counter is non zero
                  --if pauseCount = 0 then
                     if selTxArpValid = '1' then
                        selTxArp      <= '1'            after TPD_G;
                        curTxState    <= ST_TX_ACK      after TPD_G;
                        locEmacTxData <= selTxArpDst(0) after TPD_G;
                     elsif selTxUdpValid = '1' then
                        selTxArp      <= '0'            after TPD_G;
                        curTxState    <= ST_TX_ACK      after TPD_G;
                        locEmacTxData <= selTxUdpDst(0) after TPD_G;
                     end if;
                  --end if;
                  
               -- Wait on ack
               when ST_TX_ACK =>
                  emacTxValid   <= '1'       after TPD_G;
                  selTxArpReady <= '0'       after TPD_G;
                  selTxUdpReady <= '0'       after TPD_G;
                  emacTxFirst   <= emacTxAck after TPD_G;

                  if emacTxAck = '1' then
                     if selTxArp = '1' then
                        locEmacTxData <= selTxArpDst(1) after TPD_G;
                     else
                        locEmacTxData <= selTxUdpDst(1) after TPD_G;
                     end if;
                     curTxState <= ST_TX_DST after TPD_G;
                  end if;

               -- Dest address
               when ST_TX_DST =>
                  emacTxValid   <= '1' after TPD_G;
                  selTxArpReady <= '0' after TPD_G;
                  selTxUdpReady <= '0' after TPD_G;
                  emacTxFirst   <= '0' after TPD_G;

                  if selTxArp = '1' then
                     locEmacTxData <= selTxArpDst(conv_integer(txCount)) after TPD_G;
                  else
                     locEmacTxData <= selTxUdpDst(conv_integer(txCount)) after TPD_G;
                  end if;

                  if txCount = 5 then
                     curTxState <= ST_TX_SRC after TPD_G;
                  end if;

               -- Source address
               when ST_TX_SRC =>
                  emacTxValid   <= '1' after TPD_G;
                  selTxArpReady <= '0' after TPD_G;
                  selTxUdpReady <= '0' after TPD_G;
                  emacTxFirst   <= '0' after TPD_G;

                  locEmacTxData <= MacAddr(conv_integer(txCount)) after TPD_G;

                  if txCount = 5 then
                     curTxState <= ST_TX_TYPE after TPD_G;
                  end if;

               -- Ethernet Type
               when ST_TX_TYPE =>
                  emacTxValid   <= '1' after TPD_G;
                  emacTxFirst   <= '0' after TPD_G;

                  if selTxArp = '1' then
                     if txCount = 0 then
                        locEmacTxData <= EthTypeARP(15 downto 8) after TPD_G;
                     else
                        locEmacTxData <= EthTypeARP(7  downto 0) after TPD_G;
                     end if;
                  else
                     if txCount = 0 then
                        locEmacTxData <= EthTypeIPV4(15 downto 8) after TPD_G;
                     else
                        locEmacTxData <= EthTypeIPV4(7  downto 0) after TPD_G;
                     end if;
                  end if;

                  if txCount = 1 then
                     curTxState    <= ST_TX_DATA   after TPD_G;
                     selTxArpReady <= selTxArp     after TPD_G;
                     selTxUdpReady <= not selTxArp after TPD_G;
                  end if;

               -- Payload Data
               when ST_TX_DATA =>
                  emacTxValid   <= '1'          after TPD_G;
                  emacTxFirst   <= '0'          after TPD_G;
                  selTxArpReady <= selTxArp     after TPD_G;
                  selTxUdpReady <= not selTxArp after TPD_G;

                  if selTxArp = '1' then
                     emacTxValid    <= selTxArpValid after TPD_G;
                     locEmacTxData  <= selTxArpData  after TPD_G;
                     if selTxArpValid = '0' then
                        curTxState <= ST_TX_IDLE;
                     end if;
                  else
                     emacTxValid    <= selTxUdpValid after TPD_G;
                     locEmacTxData  <= selTxUdpData  after TPD_G;
                     if selTxUdpValid = '0' then
                        curTxState <= ST_TX_IDLE;
                     end if;
                  end if;

               when others => curTxState <= ST_TX_IDLE after TPD_G;
            end case;
         end if;
      end if;
   end process;


   --------------------------------
   -- ARP Engine
   --------------------------------
   U_EthClientArp : entity work.EthClientArp 
      generic map (
         TPD_G => TPD_G)
      port map (
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
         txDst      => selTxArpDst);
         
   --------------------------------
   -- UDP Engine
   --------------------------------
   U_EthClientUdp: entity work.EthClientUdp 
      generic map (
         TPD_G      => TPD_G,
         UDP_PORT_G => UDP_PORT_G ) 
      port map (
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
         udpRxGood   => udpRxGood);

end EthClient;
