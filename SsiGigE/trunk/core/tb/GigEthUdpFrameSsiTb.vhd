library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.GigEthPkg.all;
use work.EthClientPackage.all;
use work.AxiStreamPkg.all;
use work.AxiLitePkg.all;
use work.CommonPkg.all;
use work.SsiPkg.all;

entity GigEthUdpFrameSsiTb is end GigEthUdpFrameSsiTb;

architecture testbed of GigEthUdpFrameSsiTb is

   constant CLK_PERIOD_C : time := 8 ns;
   constant TPD_C        : time := CLK_PERIOD_C/4;

   signal ethClk125MHz    : sl;
   signal ethClk125MHzRst : sl;
   
   signal count           : slv(15 downto 0) := (others => '0');

   signal udpRxValid      : sl;
   signal udpRxData       : slv(7  downto 0);
   signal udpRxGood       : sl;
   signal udpRxError      : sl;
   signal udpRxCount      : slv(15 downto 0);

   -- TX Interfaces - 1 lane, 4 VCs
   signal ethTxMasters   : AxiStreamMasterArray(3 downto 0);
   signal ethTxSlaves    : AxiStreamSlaveArray(3 downto 0);
   -- RX Interfaces - 1 lane, 4 VCs
   signal ethRxMasters   : AxiStreamMasterArray(3 downto 0);
   signal ethRxCtrl      : AxiStreamCtrlArray(3 downto 0);   
   
   
   signal axiRst : sl := '0';
   
   signal mAxiLiteReadMaster  : AxiLiteReadMasterType;
   signal mAxiLiteReadSlave   : AxiLiteReadSlaveType;
   signal mAxiLiteWriteMaster : AxiLiteWriteMasterType;
   signal mAxiLiteWriteSlave  : AxiLiteWriteSlaveType;   

   -- AXI-Lite Signals
   signal mAxiWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0); 
   signal mAxiWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXI_MASTERS_C-1 downto 0); 
   signal mAxiReadMasters  : AxiLiteReadMasterArray(NUM_AXI_MASTERS_C-1 downto 0); 
   signal mAxiReadSlaves   : AxiLiteReadSlaveArray(NUM_AXI_MASTERS_C-1 downto 0); 


   signal userTxValid      : sl;
   signal userTxReady      : sl;
   signal userTxData       : slv(15 downto 0);
   signal userTxSOF        : sl;
   signal userTxEOF        : sl;
   signal userTxVc         : slv(1 downto 0);

   signal status : CommonStatusType;
   signal config : CommonConfigType;
   
   
   
begin

   -- Generate clocks and resets
   ClkRst_Inst : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,     -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 745 ns)   -- Hold reset for this long)
      port map (
         clkP => ethClk125MHz,
         clkN => open,
         rst  => ethClk125MHzRst,
         rstL => open); 
         
   -- Dummy up a register packet
   process(ethClk125MHz) begin
      if rising_edge(ethClk125MHz) then
         if (ethClk125MhzRst = '1') then
            count <= (others => '0');
         else
            count <= count + 1;         
         end if;
         -- UDP packet here
         case conv_integer(count-10) is
            when  0 => udpRxData <= x"C1";
            when  1 => udpRxData <= x"B2";
            when  2 => udpRxData <= x"1F";
            when  3 => udpRxData <= x"9A";
            when  4 => udpRxData <= x"00";
            when  5 => udpRxData <= x"1A";
            when  6 => udpRxData <= x"D6";
            when  8 => udpRxData <= x"7D";
            when  9 => udpRxData <= x"C0";
            when 10 => udpRxData <= x"08";
            when 11 => udpRxData <= x"00";
            when 12 => udpRxData <= x"00";
            when 13 => udpRxData <= x"00";
            when 14 => udpRxData <= x"00";
            when 15 => udpRxData <= x"00";
            when 16 => udpRxData <= x"00";
            when 17 => udpRxData <= x"04";
            when 18 => udpRxData <= x"80";
            when 19 => udpRxData <= x"00";
            when 20 => udpRxData <= x"00";
            when 21 => udpRxData <= x"00";
            when 22 => udpRxData <= x"00";
            when 23 => udpRxData <= x"00";
            when 24 => udpRxData <= x"00";
            when 25 => udpRxData <= x"00";
            when 26 => udpRxData <= x"00";            
            when others => udpRxData <= x"AA";
         end case;
         if (conv_integer(count-10) <= 26) then
            udpRxValid <= '1';
         end if;
         if (conv_integer(count-10) = 27) then
            udpRxGood <= '1';
         end if;
         udpRxError <= '0';
         udpRxCount <= x"001B";
      end if;
   end process;

   
   -- UDP Frame TX/RX
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
      ethRxMasterMuxed => open,
      -- UDP Block Transmit Interface (connection to MAC)
      udpTxValid       => open,
      udpTxFast        => open,
      udpTxReady       => '1',
      udpTxData        => open,
      udpTxLength      => open,
      udpTxJumbo       => '0',
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
   
   -- Lane 0, VC0 RX/TX, Register access control        
   U_AxiMasterRegisters : entity work.SsiAxiLiteMaster 
      generic map (
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
         axiLiteRst          => axiRst,
         mAxiLiteWriteMaster => mAxiLiteWriteMaster,
         mAxiLiteWriteSlave  => mAxiLiteWriteSlave,
         mAxiLiteReadMaster  => mAxiLiteReadMaster,
         mAxiLiteReadSlave   => mAxiLiteReadSlave
      );
  
      -- RX control not used yet
      ethRxCtrl(0) <= AXI_STREAM_CTRL_UNUSED_C;
      ethRxCtrl(1) <= AXI_STREAM_CTRL_UNUSED_C;
      ethRxCtrl(2) <= AXI_STREAM_CTRL_UNUSED_C;
      ethRxCtrl(3) <= AXI_STREAM_CTRL_UNUSED_C;
      -- Unused Tx masters
      ethTxMasters(1) <= AXI_STREAM_MASTER_INIT_C;
      ethTxMasters(2) <= AXI_STREAM_MASTER_INIT_C;
      ethTxMasters(3) <= AXI_STREAM_MASTER_INIT_C;   

   -- -------------------------
   -- -- AXI-Lite Crossbar Core
   -- -------------------------         
   -- U_AxiLiteCrossbar : entity work.AxiLiteCrossbar
      -- generic map (
         -- NUM_SLAVE_SLOTS_G  => 1,
         -- NUM_MASTER_SLOTS_G => NUM_AXI_MASTERS_C,
         -- MASTERS_CONFIG_G   => AXI_CROSSBAR_MASTERS_CONFIG_C)
      -- port map (
         -- sAxiWriteMasters(0) => mAxiLiteWriteMaster,
         -- sAxiWriteSlaves(0)  => mAxiLiteWriteSlave,
         -- sAxiReadMasters(0)  => mAxiLiteReadMaster,
         -- sAxiReadSlaves(0)   => mAxiLiteReadSlave,
         -- mAxiWriteMasters    => mAxiWriteMasters,
         -- mAxiWriteSlaves     => mAxiWriteSlaves,
         -- mAxiReadMasters     => mAxiReadMasters,
         -- mAxiReadSlaves      => mAxiReadSlaves,
         -- axiClk              => ethClk125MHz,
         -- axiClkRst           => axiRst);      
      
   -- ------------------------------            
   -- -- Common Core Register Module
   -- ------------------------------            
   -- U_AxiCommonReg : entity work.AxiCommonReg
      -- port map (
         -- -- AXI-Lite Register Interface    
         -- axiReadMaster  => mAxiReadMasters(COMMON_AXI_INDEX_C),
         -- axiReadSlave   => mAxiReadSlaves(COMMON_AXI_INDEX_C),
         -- axiWriteMaster => mAxiWriteMasters(COMMON_AXI_INDEX_C),
         -- axiWriteSlave  => mAxiWriteSlaves(COMMON_AXI_INDEX_C),
         -- -- VC command (axiClk domain)
         -- -- Register Inputs/Outputs (axiClk domain)
         -- status         => status,
         -- config         => config,
         -- -- Clock and reset
         -- axiClk         => ethClk125MHz,
         -- axiRst         => axiRst,
         -- sysRst         => ethClk125MHzRst);      
         
end testbed;





