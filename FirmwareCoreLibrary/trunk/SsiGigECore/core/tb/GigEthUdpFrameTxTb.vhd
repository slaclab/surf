library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.GigEthPkg.all;
use work.EthClientPackage.all;
use work.AxiStreamPkg.all;

use ieee.std_logic_textio.all;
library std;
use std.textio.all;

entity GigEthUdpFrameTxTb is end GigEthUdpFrameTxTb;

architecture testbed of GigEthUdpFrameTxTb is

   constant CLK_PERIOD_C : time := 8 ns;
   constant TPD_C        : time := CLK_PERIOD_C/4;

   signal ethClk125MHz    : sl;
   signal ethClk125MHzRst : sl;

   signal userTxValid     : sl;
   signal userTxReady     : sl;
   signal userTxData      : slv(31 downto 0);
   signal userTxSOF       : sl;
   signal userTxEOF       : sl;
   signal userTxVc        : slv(1 downto 0);
   
   signal udpTxValid      : sl;
   signal udpTxFast       : sl;
   signal udpTxReady      : sl;
   signal udpTxData       : slv(7 downto 0);
   signal udpTxLength     : slv(15 downto 0);

   signal emacTxAck       : sl;
   signal emacTxIdle      : sl;
   signal emacTxData      : slv(7 downto 0);
   signal emacTxValid     : sl;
   signal emacTxFirst     : sl;

   signal macTxDataOut    : EthMacDataType;
   
   signal userTxMasters   : AxiStreamMasterArray(3 downto 0);
   signal userTxSlaves    : AxiStreamSlaveArray(3 downto 0);
   
   signal count           : slv(31 downto 0) := (others => '0');

   
begin

   userTxMasters(0) <= AXI_STREAM_MASTER_INIT_C;
   userTxMasters(2) <= AXI_STREAM_MASTER_INIT_C;
   userTxMasters(3) <= AXI_STREAM_MASTER_INIT_C;

   -- Dummy packet
   process(ethClk125MHz) begin
      if rising_edge(ethClk125MHz) then
         if (ethClk125MhzRst = '1') then
            count <= (others => '0');
         else
            count <= count + 1;
         end if;
         -- UDP packet here
         userTxMasters(1) <= AXI_STREAM_MASTER_INIT_C;
         if (count - 10 = 0) then
            userTxMasters(1).tvalid <= '1'; userTxMasters(1).tdata(31 downto 0) <= x"DEADBEEF";
         elsif (count - 10 < 500) then
            userTxMasters(1).tvalid <= '1'; userTxMasters(1).tdata(31 downto 0) <= count;
         elsif (count - 10 = 500) then
            userTxMasters(1).tvalid <= '1'; userTxMasters(1).tdata(31 downto 0) <= x"F00D1234"; userTxMasters(1).tlast <= '1';
         else 
            userTxMasters(1).tvalid <= '0'; userTxMasters(1).tdata(31 downto 0) <= x"A5A5B2B2";
         end if;
      end if;
   end process;


   -- Generate clocks and resets
   ClkRst_Inst : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,     -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 10 ns)   -- Hold reset for this long)
      port map (
         clkP => ethClk125MHz,
         clkN => open,
         rst  => ethClk125MHzRst,
         rstL => open); 

   U_GigEthUdpFrame : entity work.GigEthUdpFrameSsi 
      generic map ( 
         EN_JUMBO_G => false,
         TPD_G      => 1 ns
      )
      port map ( 
         gtpClk           => ethClk125MHz,
         gtpClkRst        => ethClk125MHzRst,
         -- User Transmit Interface
         userTxValid      => userTxValid,
         userTxReady      => userTxReady,
         userTxData       => userTxData,
         userTxSOF        => userTxSOF,
         userTxEOF        => userTxEOF,
         userTxVc         => userTxVc,
         -- User Receive Interface
         ethRxMasters     => open,
         ethRxMasterMuxed => open,
         -- UDP Block Transmit Interface (connection to MAC)
         udpTxValid       => udpTxValid,
         udpTxFast        => udpTxFast,
         udpTxReady       => udpTxReady,
         udpTxData        => udpTxData,
         udpTxLength      => udpTxLength,
         udpTxJumbo       => '0', 
         -- UDP Block Receive Interface (connection from MAC)
         udpRxValid       => '0',
         udpRxData        => (others => '0'),
         udpRxGood        => '0',
         udpRxError       => '0',
         udpRxCount       => (others => '0')
      );

   U_GigEthArbiterSsi : entity work.GigEthArbiterSsi 
      generic map ( 
         TPD_G   => 1 ns
      )
      port map (
         -- Ethernet clock & reset
         gtpClk         => ethClk125MHz,
         gtpClkRst      => ethClk125MHzRst,      
         -- User Transmit ETH Interface to UDP framer
         userTxValid    => userTxValid,
         userTxReady    => userTxReady,
         userTxData     => userTxData,
         userTxSOF      => userTxSOF,
         userTxEOF      => userTxEOF,
         userTxVc       => userTxVc,
         -- User transmit interfaces (data from virtual channels)
         userTxMasters  => userTxMasters, 
         userTxSlaves   => userTxSlaves
      );

   -- Ethernet client, including ARP engine and mux-ing between 
   -- ARP and UDP data
   U_EthClient : entity work.EthClient
      generic map (
         TPD_G      => 1 ns,
         UDP_PORT_G => 8192
      )
      port map (
         -- Ethernet clock & reset
         emacClk         => ethClk125MHz,
         emacClkRst      => ethClk125MHzRst,
         -- MAC Interface Signals, Receiver
         emacRxData      => (others => '0'),
         emacRxValid     => '0',
         emacRxGoodFrame => '0',
         emacRxBadFrame  => '0',
         -- MAC Interface Signals, Transmitter
         emacTxData      => emacTxData,
         emacTxValid     => emacTxValid,
         emacTxAck       => emacTxAck,
         emacTxIdle      => emacTxIdle,
         emacTxFirst     => emacTxFirst,
         -- Ethernet Constants
         ipAddr          => IP_ADDR_INIT_C,
         macAddr         => MAC_ADDR_INIT_C,
         -- UDP Transmit interface
         udpTxValid      => udpTxValid,
         udpTxFast       => udpTxFast,
         udpTxReady      => udpTxReady,
         udpTxData       => udpTxData,
         udpTxLength     => udpTxLength,
         -- UDP Receive interface
         udpRxValid      => open,
         udpRxData       => open,
         udpRxGood       => open,
         udpRxError      => open,
         udpRxCount      => open
      );


   -- MAC TX block
   U_GigEthMacTx : entity work.GigEthMacTx
      generic map (
         TPD_G => 1 ns)
      port map (
         -- 125 MHz ethernet clock in
         ethTxClk          => ethClk125MHz,
         ethTxRst          => ethClk125MHzRst,
         -- User data to be sent
         userDataIn        => emacTxData,
         userDataValid     => emacTxValid,
         userDataFirstByte => emacTxFirst,
         userDataAck       => emacTxAck,
         emacTxIdle        => emacTxIdle,
         -- Data out to the GTX
         ethMacDataOut     => macTxDataOut);      
      
   -- Dump packets out
   process (ethClk125MHz) 
      variable s : line;
   begin
      if rising_edge(ethClk125MHz) then
         if udpTxValid = '1' then
            hwrite(s,udpTxData);
            writeline(output,s);
         end if;
      end if;
   end process;



----------------- 
-- Old version --
-----------------
--   -- Dummy packet
--   process(ethClk125MHz) begin
--      if rising_edge(ethClk125MHz) then
--         if (ethClk125MhzRst = '1') then
--            count <= (others => '0');
--         else
--            count <= count + 1;
--         end if;
--         -- UDP packet here
--         userTxVc   <= "01";
--         udpTxReady <= '1';
--         if (count - 10 = 0) then
--            userTxValid <= '1'; userTxData <= x"DEADBEEF"; userTxSOF <= '1'; userTxEOF <= '0';
--         elsif (count - 10 < 500) then
--            userTxValid <= '1'; userTxData <= count(15 downto 0) & count(15 downto 0); userTxSOF <= '0'; userTxEOF <= '0';
--         elsif (count - 10 = 500) then
--            userTxValid <= '1'; userTxData <= x"F00D1234"; userTxSOF <= '0'; userTxEOF <= '1';
--         else 
--            userTxValid <= '0'; userTxData <= x"A5A5A5A5"; userTxSOF <= '0'; userTxEOF <= '0';
--         end if;
--      end if;
--   end process;
   
--   -- UDP Frame TX/RX
--   U_GigEthUdpFrameTx : entity work.GigEthUdpFrameTx
--    port map ( 
--      -- Ethernet clock & reset
--      gtpClk           => ethClk125MHz,
--      gtpClkRst        => ethClk125MHzRst,
--      -- User Transmit Interface
--      userTxValid      => userTxValid, --: in  std_logic;
--      userTxReady      => userTxReady, --: out std_logic;
--      userTxData       => userTxData,  --: in  std_logic_vector(31 downto 0);    -- Ethernet TX Data
--      userTxSOF        => userTxSOF,   --: in  std_logic;                        -- Ethernet TX Start of Frame
--      userTxEOF        => userTxEOF,   --: in  std_logic;                        -- Ethernet TX End of Frame
--      userTxVc         => userTxVc,    --: in  std_logic_vector(1  downto 0);    -- Ethernet TX Virtual Channel
--      -- UDP Block Transmit Interface (connection to MAC)
--      udpTxValid       => udpTxValid,  --: out std_logic;
--      udpTxFast        => udpTxFast,   --: out std_logic;
--      udpTxReady       => udpTxReady,  --: in  std_logic;
--      udpTxData        => udpTxData,   --: out std_logic_vector(7  downto 0);
--      udpTxLength      => udpTxLength  --: out std_logic_vector(15 downto 0)
--   );


         
end testbed;





