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
      txDst   : out MacAddrType
   );

end EthClientArp;


-- Define architecture
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
   
   -- Register delay for simulation
   constant tpd:time := 0.5 ns;

begin

   --------------------------------
   -- ARP Receive Logic
   --------------------------------

   -- Sync state logic
   process ( emacClk, emacClkRst ) begin
      if emacClkRst = '1' then
         rxCount    <= (others=>'0')   after tpd;
         rxArpMsg   <= (others=>x"00") after tpd;
         txDst      <= (others=>x"00")  after tpd;
         txStart    <= '0'             after tpd;
         curRxState <= ST_RX_IDLE      after tpd;
      elsif rising_edge(emacClk) then

         -- RX Data
         if rxValid = '1' and rxCount < 28 then
           rxArpMsg(conv_integer(rxCount)) <= rxData after tpd; 
         end if;

         -- RX Counter
         if rxValid = '0' then
            rxCount <= (others=>'0') after tpd;
         elsif rxCount /= 63 then
            rxCount <= rxCount + 1 after tpd;
         end if;

         -- State machine
         case curRxState is

            -- IDLE
            when ST_RX_IDLE =>
               if rxValid = '1' then
                  curRxState <= ST_RX_ARP after tpd;
               end if;
               txStart <= '0' after tpd;

            -- ARP message
            when ST_RX_ARP =>
               if rxValid = '0' then
                  curRxState <= ST_RX_IDLE after tpd;
               elsif rxCount = 27 then
                  curRxState <= ST_RX_WAIT after tpd;
               end if;

            -- Wait for message status
            when ST_RX_WAIT =>
               if rxError = '1' then
                  curRxState <= ST_RX_IDLE after tpd;
               elsif rxGood = '1' then
                  if txBusy = '0' then
                     curRxState <= ST_RX_SEND after tpd;
                     txDst      <= rxSrc      after tpd;
                  else
                     curRxState <= ST_RX_IDLE after tpd;
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
                  txStart <= '1' after tpd;
               end if;
               curRxState <= ST_RX_IDLE after tpd;

            when others => curRxState <= ST_RX_IDLE after tpd;
         end case;
      end if;
   end process;


   --------------------------------
   -- Ethernet Transmit Logic
   --------------------------------

   -- Transmit
   
   txData <= locTxData;
   
   process ( emacClk, emacClkRst ) begin
      if emacClkRst = '1' then
         txBusy         <= '0'             after tpd;
         locTxData      <= (others=>'0')   after tpd;
         txCount        <= (others=>'0')   after tpd;
         txArpMsg       <= (others=>x"00") after tpd;
      elsif rising_edge(emacClk) then

         -- RX Data
         if txReady = '0' then
            locTxData <= txArpMsg(0) after tpd;
         elsif txCount < 28 then
            locTxData <= txArpMsg(conv_integer(txCount)) after tpd;
         else
            locTxData <= (others=>'0')  after tpd;
         end if;

         -- TX Counter
         if txReady = '0' or txBusy = '0' then
            txCount <= "000001" after tpd;
         elsif txCount /= 63 then
            txCount <= txCount + 1 after tpd;
         end if;

         -- Create arp response
         if txStart = '1' then
            txArpMsg(0)  <= x"00"                    after tpd; -- Hardware type
            txArpMsg(1)  <= x"01"                    after tpd; -- Hardware type
            txArpMsg(2)  <= EthTypeIPV4(15 downto 8) after tpd; -- Protocol Type
            txArpMsg(3)  <= EthTypeIPV4(7  downto 0) after tpd; -- Protocol Type
            txArpMsg(4)  <= x"06"                    after tpd; -- Hardware Length
            txArpMsg(5)  <= x"04"                    after tpd; -- Protocol Length
            txArpMsg(6)  <= x"00"                    after tpd; -- OpCode, Arp Reply
            txArpMsg(7)  <= x"02"                    after tpd; -- OpCode, Arp Reply
            txArpMsg(8)  <= MacAddr(0)               after tpd; -- My Mac Addr
            txArpMsg(9)  <= MacAddr(1)               after tpd;
            txArpMsg(10) <= MacAddr(2)               after tpd;
            txArpMsg(11) <= MacAddr(3)               after tpd;
            txArpMsg(12) <= MacAddr(4)               after tpd;
            txArpMsg(13) <= MacAddr(5)               after tpd;
            txArpMsg(14) <= IpAddr(3)                after tpd; -- My IP Address
            txArpMsg(15) <= IpAddr(2)                after tpd;
            txArpMsg(16) <= IpAddr(1)                after tpd;
            txArpMsg(17) <= IpAddr(0)                after tpd;
            txArpMsg(18) <= rxArpMsg(8)              after tpd; -- Dest Mac Addr
            txArpMsg(19) <= rxArpMsg(9)              after tpd;
            txArpMsg(20) <= rxArpMsg(10)             after tpd;
            txArpMsg(21) <= rxArpMsg(11)             after tpd;
            txArpMsg(22) <= rxArpMsg(12)             after tpd;
            txArpMsg(23) <= rxArpMsg(13)             after tpd;
            txArpMsg(24) <= rxArpMsg(14)             after tpd; -- Dest IP Address
            txArpMsg(25) <= rxArpMsg(15)             after tpd;
            txArpMsg(26) <= rxArpMsg(16)             after tpd;
            txArpMsg(27) <= rxArpMsg(17)             after tpd;
         end if;

         -- State control
         if txStart = '1' then
            txBusy  <= '1' after tpd;
         elsif txCount = 45 then
            txBusy <= '0' after tpd;
         end if;
      end if;
   end process;

   -- Drive valid
   txValid <= txBusy;

end EthClientArp;

