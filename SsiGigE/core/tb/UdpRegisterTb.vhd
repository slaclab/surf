library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.GigEthPkg.all;
use work.EthClientPackage.all;
use work.CommonPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.SsiCmdMasterPkg.all;

use ieee.std_logic_textio.all;
library std;
use std.textio.all;

entity UdpRegisterTb is end UdpRegisterTb;

architecture testbed of UdpRegisterTb is

   constant CLK_PERIOD_C : time := 8 ns;
   constant TPD_C        : time := CLK_PERIOD_C/4;
   
   constant JUMBO_EN_C : sl := '0';

   signal ipAddr          : IPAddrType := (3 => x"C0",2 => x"A8",1 => x"01",0 => x"14");
   signal macAddr         : MacAddrType := (5 => x"01",4 => x"03",3 => x"00",2 => x"56",1 => x"44",0 => x"05");
   
   signal ethClk125MHz    : sl;
   signal ethClk125MHzRst : sl;
   
   signal macRxDataOut    : slv(7 downto 0);
   signal macRxDataValid  : sl;
   signal macRxGoodFrame  : sl;
   signal macRxBadFrame   : sl;

   signal emacTxData      : slv(7 downto 0);
   signal emacTxValid     : sl;
   signal emacTxAck       : sl;
   signal emacTxFirst     : sl;

   signal macTxDataOut    : EthMacDataType;
   
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
   
   signal udpRxValid : sl;
   signal udpRxData  : slv(7 downto 0);
   signal udpRxGood  : sl;
   signal udpRxError : sl;
   signal udpRxCount : slv(15 downto 0);

   signal ethRxMasters     : AxiStreamMasterArray(3 downto 0);
   signal ethRxMasterMuxed : AxiStreamMasterType;
   signal ethRxCtrl        : AxiStreamCtrlArray(3 downto 0);

   signal ethTxMasters     : AxiStreamMasterArray(3 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal ethTxSlaves      : AxiStreamSlaveArray(3 downto 0);

   signal mAxiWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0); 
   signal mAxiWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXI_MASTERS_C-1 downto 0); 
   signal mAxiReadMasters  : AxiLiteReadMasterArray(NUM_AXI_MASTERS_C-1 downto 0); 
   signal mAxiReadSlaves   : AxiLiteReadSlaveArray(NUM_AXI_MASTERS_C-1 downto 0); 
   
   signal mAxiLiteReadMaster  : AxiLiteReadMasterType;
   signal mAxiLiteReadSlave   : AxiLiteReadSlaveType;
   signal mAxiLiteWriteMaster : AxiLiteWriteMasterType;
   signal mAxiLiteWriteSlave  : AxiLiteWriteSlaveType;

   -- signal sAxiReadMaster  : AxiLiteReadMasterType;
   -- signal sAxiReadSlave   : AxiLiteReadSlaveType;
   -- signal sAxiWriteMaster : AxiLiteWriteMasterType;
   -- signal sAxiWriteSlave  : AxiLiteWriteSlaveType;

   type ipPacket is array(integer range<>) of slv(7 downto 0);
   
   constant packet : ipPacket(0 to 61) := (
        x"05",x"44",x"56",x"00",x"03",x"01", --MAC dest
        x"07",x"e0",x"b3",x"10",x"f8",x"54", --MAC src
        x"08",x"00",                         --  ethertype
        x"45",x"00",x"00",x"30",             --  version, IHL, DSCP, ECN, length
        x"00",x"00",x"40",x"00",             --  ID, flags, fragment offset
        x"40",x"11",x"b7",x"56",             --  time-to-live, protocol, header checksum
        x"c0",x"a8",x"01",x"02",             --  source ip
        x"c0",x"a8",x"01",x"14",             --  dest ip
        x"d9",x"b0",x"20",x"00",             --    source port, dest port
        x"00",x"1c",x"82",x"99",             --    length, checksum
        x"00",x"00",x"00",x"00",             --    payload (bits 31:24 - lane[3:0], vc[3:0], 23 - continuation)
        x"DE",x"AD",x"BE",x"EF",             --    payload (TID[31:0] echoed) - reused as context now
        x"40",x"00",x"00",x"04",             --    payload (31:30 - opcode, address 31:2 mapped to 29:0)
        x"A0",x"1B",x"C2",x"3D",             --    payload (write data or read count)
        x"00",x"00",x"00",x"00");            --    payload (don't care)
   
   signal count : slv(15 downto 0) := (others => '0');

   
begin

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
         
   -- Dummy packet
   process(ethClk125MHz) begin
      if rising_edge(ethClk125MHz) then
         if (ethClk125MhzRst = '1') then
            count <= (others => '0');
         else
            if (count < 80) then
               count <= count + 1;         
            end if;
         end if;
         if (count = 73) then 
            macRxGoodFrame <= '1';
         else
            macRxGoodFrame <= '0';
         end if;
         macRxBadFrame <= '0';
         if (count < 10 or count > 71) then
            macRxDataValid <= '0';
            macRxDataOut   <= x"FF";
         else 
            macRxDataOut   <= packet(conv_integer(count-10));
            macRxDataValid <= '1';
         end if;
      end if;
   end process;
   
----------------------------------------------
   -- udpTxReady <= '1';

   -- -- UDP framer
   -- U_GigEthUdpFrameSsi : entity work.GigEthUdpFrameSsi
      -- port map (
         -- -- Ethernet clock & reset
         -- gtpClk           => ethClk125MHz,
         -- gtpClkRst        => ethClk125MHzRst,
         -- -- User Transmit Interface
         -- userTxValid      => userTxValid,
         -- userTxReady      => userTxReady,
         -- userTxData       => userTxData,
         -- userTxSOF        => userTxSOF,
         -- userTxEOF        => userTxEOF,
         -- userTxVc         => userTxVc,
         -- -- User Receive Interface
         -- ethRxMasters     => ethRxMasters,
         -- ethRxMasterMuxed => ethRxMasterMuxed,
         -- -- UDP Block Transmit Interface (connection to MAC)
         -- udpTxValid       => udpTxValid,
         -- udpTxFast        => udpTxFast,
         -- udpTxReady       => udpTxReady,
         -- udpTxData        => udpTxData,
         -- udpTxLength      => udpTxLength,
         -- udpTxJumbo       => JUMBO_EN_C,
         -- -- UDP Block Receive Interface (connection from MAC)
         -- udpRxValid       => udpRxValid,
         -- udpRxData        => udpRxData,
         -- udpRxGood        => udpRxGood,
         -- udpRxError       => udpRxError,
         -- udpRxCount       => udpRxCount
      -- );

   -- -- UDP TX arbiter
   -- U_GigEthArbiterSsi : entity work.GigEthArbiterSsi
   -- port map ( 
      -- -- Ethernet clock & reset
      -- gtpClk         => ethClk125MHz,
      -- gtpClkRst      => ethClk125MHzRst,
      -- -- User Transmit ETH Interface to UDP framer
      -- userTxValid    => userTxValid,
      -- userTxReady    => userTxReady,
      -- userTxData     => userTxData,
      -- userTxSOF      => userTxSOF,
      -- userTxEOF      => userTxEOF,
      -- userTxVc       => userTxVc,
      -- -- User transmit interfaces (data from virtual channels)
      -- userTxMasters  => ethTxMasters,
      -- userTxSlaves   => ethTxSlaves
   -- ); 

   -- MAC TX block
   U_GigEthMacTx : entity work.GigEthMacTx
      generic map (
         TPD_G => TPD_C
      )
      port map (
         -- 125 MHz ethernet clock in
         ethTxClk          => ethClk125MHz,
         ethTxRst          => ethClk125MHzRst,
         -- User data to be sent
         userDataIn        => emacTxData,
         userDataValid     => emacTxValid,
         userDataFirstByte => emacTxFirst,
         userDataAck       => emacTxAck,
         -- Data out to the GTX
         ethMacDataOut     => macTxDataOut
      );      
   
   -- Ethernet client, including ARP engine and mux-ing between 
   -- ARP and UDP data
   U_EthClient : entity work.EthClient
      generic map (
         UdpPort => 8192
      )
      port map (
         -- Ethernet clock & reset
         emacClk         => ethClk125MHz, 
         emacClkRst      => ethClk125MHzRst, 
         -- MAC Interface Signals, Receiver
         emacRxData      => macRxDataOut,
         emacRxValid     => macRxDataValid,
         emacRxGoodFrame => macRxGoodFrame,
         emacRxBadFrame  => macRxBadFrame,
         -- MAC Interface Signals, Transmitter
         emacTxData      => emacTxData,
         emacTxValid     => emacTxValid,
         emacTxAck       => emacTxAck,
         emacTxFirst     => emacTxFirst,
         -- Ethernet Constants
         ipAddr          => ipAddr,
         macAddr         => macAddr,
         -- UDP Transmit interface
         udpTxValid      => udpTxValid,
         --udpTxFast       => udpTxFast,
         udpTxFast       => '0',
         udpTxReady      => udpTxReady,
         udpTxData       => udpTxData,
         udpTxLength     => udpTxLength,
         -- UDP Receive interface
         udpRxValid      => udpRxValid,
         udpRxData       => udpRxData,
         udpRxGood       => udpRxGood,
         udpRxError      => udpRxError,
         udpRxCount      => udpRxCount
      );

   -- UDP framer
   U_GigEthUdpFrameSsi : entity work.GigEthUdpFrameSsi
      port map (
         -- Ethernet clock & reset
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
         ethRxMasters     => ethRxMasters,
         ethRxMasterMuxed => ethRxMasterMuxed,
         -- UDP Block Transmit Interface (connection to MAC)
         udpTxValid       => udpTxValid,
         udpTxFast        => udpTxFast,
         udpTxReady       => udpTxReady,
         udpTxData        => udpTxData,
         udpTxLength      => udpTxLength,
         udpTxJumbo       => JUMBO_EN_C,
         -- UDP Block Receive Interface (connection from MAC)
         udpRxValid       => udpRxValid,
         udpRxData        => udpRxData,
         udpRxGood        => udpRxGood,
         udpRxError       => udpRxError,
         udpRxCount       => udpRxCount
      );

   -- UDP TX arbiter
   U_GigEthArbiterSsi : entity work.GigEthArbiterSsi
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
      userTxMasters  => ethTxMasters,
      userTxSlaves   => ethTxSlaves
   ); 
   
   
--------------------------------------------------------------------------
--   User code 
--------------------------------------------------------------------------
   
   -- Lane 0, VC0 RX/TX, Register access control        
   U_AxiMasterRegisters : entity work.SsiAxiLiteMaster 
      generic map (
         EN_32BIT_ADDR_G     => true,
         USE_BUILT_IN_G      => false,
         AXI_STREAM_CONFIG_G => SSI_GIGETH_CONFIG_C
      )
      port map (
         -- Streaming Slave (Rx) Interface (sAxisClk domain) 
         sAxisClk    => ethClk125MHz,
         sAxisRst    => ethClk125MHzRst,
         sAxisMaster => ethRxMasters(0),
         sAxisSlave  => open,
         sAxisCtrl   => ethRxCtrl(0),
         -- Streaming Master (Tx) Data Interface (mAxisClk domain)
         mAxisClk    => ethClk125MHz,
         mAxisRst    => ethClk125MHzRst,
         mAxisMaster => ethTxMasters(0),
         mAxisSlave  => ethTxSlaves(0),
         -- AXI Lite Bus (axiLiteClk domain)
         axiLiteClk          => ethClk125MHz,
         axiLiteRst          => ethClk125MHzRst,
         mAxiLiteWriteMaster => mAxiLiteWriteMaster,
         mAxiLiteWriteSlave  => mAxiLiteWriteSlave,
         mAxiLiteReadMaster  => mAxiLiteReadMaster,
         mAxiLiteReadSlave   => mAxiLiteReadSlave
      );

   -------------------------
   -- AXI-Lite Crossbar Core
   -------------------------         
   U_AxiLiteCrossbar : entity work.AxiLiteCrossbar
      generic map (
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXI_MASTERS_C,
         MASTERS_CONFIG_G   => AXI_CROSSBAR_MASTERS_CONFIG_C)
      port map (
         sAxiWriteMasters(0) => mAxiLiteWriteMaster,
         sAxiWriteSlaves(0)  => mAxiLiteWriteSlave,
         sAxiReadMasters(0)  => mAxiLiteReadMaster,
         sAxiReadSlaves(0)   => mAxiLiteReadSlave,
         mAxiWriteMasters    => mAxiWriteMasters,
         mAxiWriteSlaves     => mAxiWriteSlaves,
         mAxiReadMasters     => mAxiReadMasters,
         mAxiReadSlaves      => mAxiReadSlaves,
         axiClk              => ethClk125MHz,
         axiClkRst           => ethClk125MHzRst);

   --------------------------
   -- AXI-Lite Version Module
   --------------------------            
   U_AxiVersion : entity work.AxiVersion
      generic map (
         EN_DEVICE_DNA_G => true)   
      port map (
         axiReadMaster  => mAxiReadMasters(VERSION_AXI_INDEX_C),
         axiReadSlave   => mAxiReadSlaves(VERSION_AXI_INDEX_C),
         axiWriteMaster => mAxiWriteMasters(VERSION_AXI_INDEX_C),
         axiWriteSlave  => mAxiWriteSlaves(VERSION_AXI_INDEX_C),
         axiClk         => ethClk125MHz,
         axiRst         => ethClk125MHzRst);
      
end testbed;





