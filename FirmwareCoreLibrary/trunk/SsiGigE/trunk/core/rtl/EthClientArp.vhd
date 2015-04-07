-------------------------------------------------------------------------------
-- Title         : Ethernet Client, ARP Processor
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : EthClientArp.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 10/18/2010
-------------------------------------------------------------------------------
-- Description:
-- ARP processor source code for general purpose firmware ethenet client.
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

entity EthClientArp is 
   generic (
      TPD_G : time := 1 ns);
   port ( 

      -- Ethernet clock & reset
      emacClk    : in  std_logic;
      emacClkRst : in  std_logic;

      -- Local IP Address
      ipAddr  : in  IPAddrType;
      macAddr : in  MacAddrType;

      -- Receive interface
      rxData  : in  std_logic_vector(7 downto 0);
      rxError : in  std_logic;
      rxGood  : in  std_logic;
      rxValid : in  std_logic;
      rxSrc   : in  MacAddrType;

      -- Transmit interface
      txValid : out std_logic;
      txReady : in  std_logic;
      txData  : out std_logic_vector(7 downto 0);
      txDst   : out MacAddrType);

end EthClientArp;

architecture EthClientArp of EthClientArp is

   -- Local Signals
   signal rxCount  : std_logic_vector(5 downto 0);
   signal txCount  : std_logic_vector(5 downto 0);
   signal rxArpMsg : ArpMsgType;
   signal txArpMsg : ArpMsgType;
   signal txStart  : std_logic;
   signal txBusy   : std_logic;

   -- Ethernet RX States
   constant ST_RX_IDLE   : std_logic_vector(1 downto 0) := "00";
   constant ST_RX_ARP    : std_logic_vector(1 downto 0) := "01";
   constant ST_RX_WAIT   : std_logic_vector(1 downto 0) := "10";
   constant ST_RX_SEND   : std_logic_vector(1 downto 0) := "11";
   signal   curRXState   : std_logic_vector(1 downto 0);

   -- Debug
   signal   locTxData    : std_logic_vector(7 downto 0);

begin

   --------------------------------
   -- ARP Receive Logic
   --------------------------------

   -- Sync state logic
   process ( emacClk ) 
   begin
      if rising_edge(emacClk) then
         if emacClkRst = '1' then
            rxCount    <= (others=>'0')    after TPD_G;
            rxArpMsg   <= (others=>x"00")  after TPD_G;
            txDst      <= (others=>x"00")  after TPD_G;
            txStart    <= '0'              after TPD_G;
            curRxState <= ST_RX_IDLE       after TPD_G;
         else
            -- RX Data
            if rxValid = '1' and rxCount < 28 then
              rxArpMsg(conv_integer(rxCount)) <= rxData after TPD_G; 
            end if;

            -- RX Counter
            if rxValid = '0' then
               rxCount <= (others=>'0') after TPD_G;
            elsif rxCount /= 63 then
               rxCount <= rxCount + 1 after TPD_G;
            end if;

            -- State machine
            case curRxState is

               -- IDLE
               when ST_RX_IDLE =>
                  if rxValid = '1' then
                     curRxState <= ST_RX_ARP after TPD_G;
                  end if;
                  txStart <= '0' after TPD_G;

               -- ARP message
               when ST_RX_ARP =>
                  if rxValid = '0' then
                     curRxState <= ST_RX_IDLE after TPD_G;
                  elsif rxCount = 27 then
                     curRxState <= ST_RX_WAIT after TPD_G;
                  end if;

               -- Wait for message status
               when ST_RX_WAIT =>
                  if rxError = '1' then
                     curRxState <= ST_RX_IDLE after TPD_G;
                  elsif rxGood = '1' then
                     if txBusy = '0' then
                        curRxState <= ST_RX_SEND after TPD_G;
                        txDst      <= rxSrc      after TPD_G;
                     else
                        curRxState <= ST_RX_IDLE after TPD_G;
                     end if;
                  end if;

               -- Check message and send response
               when ST_RX_SEND =>
                  if rxArpMsg(0) = x"00"                    and  -- Hardware type
                     rxArpMsg(1) = x"01"                    and  -- Hardware type
                     rxArpMsg(2) = EthTypeIPV4(15 downto 8) and  -- Protocol type
                     rxArpMsg(3) = EthTypeIPV4(7  downto 0) and  -- Protocol type
                     rxArpMsg(4) = x"06"                    and  -- Hardware Addr length
                     rxArpMsg(5) = x"04"                    and  -- Protocol Addr length
                     rxArpMsg(6) = x"00"                    and  -- Opcode, Arp Request
                     rxArpMsg(7) = x"01"                    then -- Opcode, Arp Request
                     txStart <= '1' after TPD_G;
                  end if;
                  curRxState <= ST_RX_IDLE after TPD_G;

               when others => curRxState <= ST_RX_IDLE after TPD_G;
            end case;
         end if;
      end if;
   end process;


   --------------------------------
   -- Ethernet Transmit Logic
   --------------------------------

   -- Transmit
   
   txData <= locTxData;
   
   process ( emacClk ) 
   begin
      if rising_edge(emacClk) then
         if emacClkRst = '1' then
            txBusy         <= '0'             after TPD_G;
            locTxData      <= (others=>'0')   after TPD_G;
            txCount        <= (others=>'0')   after TPD_G;
            txArpMsg       <= (others=>x"00") after TPD_G;
         else
            -- RX Data
            if txReady = '0' then
               locTxData <= txArpMsg(0) after TPD_G;
            elsif txCount < 28 then
               locTxData <= txArpMsg(conv_integer(txCount)) after TPD_G;
            else
               locTxData <= (others=>'0')  after TPD_G;
            end if;

            -- TX Counter
            if txReady = '0' or txBusy = '0' then
               txCount <= "000001" after TPD_G;
            elsif txCount /= 63 then
               txCount <= txCount + 1 after TPD_G;
            end if;

            -- Create arp response
            if txStart = '1' then
               txArpMsg(0)  <= x"00"                    after TPD_G; -- Hardware type
               txArpMsg(1)  <= x"01"                    after TPD_G; -- Hardware type
               txArpMsg(2)  <= EthTypeIPV4(15 downto 8) after TPD_G; -- Protocol Type
               txArpMsg(3)  <= EthTypeIPV4(7  downto 0) after TPD_G; -- Protocol Type
               txArpMsg(4)  <= x"06"                    after TPD_G; -- Hardware Length
               txArpMsg(5)  <= x"04"                    after TPD_G; -- Protocol Length
               txArpMsg(6)  <= x"00"                    after TPD_G; -- OpCode, Arp Reply
               txArpMsg(7)  <= x"02"                    after TPD_G; -- OpCode, Arp Reply
               txArpMsg(8)  <= MacAddr(0)               after TPD_G; -- My Mac Addr
               txArpMsg(9)  <= MacAddr(1)               after TPD_G;
               txArpMsg(10) <= MacAddr(2)               after TPD_G;
               txArpMsg(11) <= MacAddr(3)               after TPD_G;
               txArpMsg(12) <= MacAddr(4)               after TPD_G;
               txArpMsg(13) <= MacAddr(5)               after TPD_G;
               txArpMsg(14) <= IpAddr(3)                after TPD_G; -- My IP Address
               txArpMsg(15) <= IpAddr(2)                after TPD_G;
               txArpMsg(16) <= IpAddr(1)                after TPD_G;
               txArpMsg(17) <= IpAddr(0)                after TPD_G;
               txArpMsg(18) <= rxArpMsg(8)              after TPD_G; -- Dest Mac Addr
               txArpMsg(19) <= rxArpMsg(9)              after TPD_G;
               txArpMsg(20) <= rxArpMsg(10)             after TPD_G;
               txArpMsg(21) <= rxArpMsg(11)             after TPD_G;
               txArpMsg(22) <= rxArpMsg(12)             after TPD_G;
               txArpMsg(23) <= rxArpMsg(13)             after TPD_G;
               txArpMsg(24) <= rxArpMsg(14)             after TPD_G; -- Dest IP Address
               txArpMsg(25) <= rxArpMsg(15)             after TPD_G;
               txArpMsg(26) <= rxArpMsg(16)             after TPD_G;
               txArpMsg(27) <= rxArpMsg(17)             after TPD_G;
            end if;

            -- State control
            if txStart = '1' then
               txBusy  <= '1' after TPD_G;
            elsif txCount = 45 then
               txBusy <= '0' after TPD_G;
            end if;
         end if;
      end if;
   end process;

   -- Drive valid
   txValid <= txBusy;

end EthClientArp;
