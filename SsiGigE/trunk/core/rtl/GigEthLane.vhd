-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : GigEthLane.vhd
-- Author     : Kurtis Nishimura <kurtisn@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-06-03
-- Last update: 2015-01-22
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Gtx7 Wrapper for Gigabit Ethernet
--
-- Dependencies:  ^/pgp2_core/trunk/rtl/core/Pgp2RxWrapper.vhd
--                ^/pgp2_core/trunk/rtl/core/Pgp2TxWrapper.vhd
--                ^/StdLib/trunk/rtl/CRC32Rtl.vhd
-------------------------------------------------------------------------------
--                ^/MgtLib/trunk/rtl/gtx7/Gtx7Core.vhd
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.GigEthPkg.all;
use work.EthClientPackage.all;
use work.AxiStreamPkg.all;

library UNISIM;
use UNISIM.VCOMPONENTS.all;

entity GigEthLane is
   generic (
      TPD_G               : time    := 1 ns;
      -- Sim Generics
      SIM_RESET_SPEEDUP_G : boolean := false;
      SIM_VERSION_G       : string  := "4.0");
   port (
      -- Clocking
      ethClk125MHz     : in  sl;
      ethClk125MHzRst  : in  sl;
      ethClk62MHz      : in  sl;
      ethClk62MHzRst   : in  sl;
      -- Link status signals
      ethRxLinkSync    : out sl;
      ethAutoNegDone   : out sl;
      -- GTX interface signals
      phyRxLaneIn      : in  EthRxPhyLaneInType;
      phyRxLaneOut     : out EthRxPhyLaneOutType;
      phyTxLaneOut     : out EthTxPhyLaneOutType;
      phyRxReady       : in  sl;
      -- Transmit interfaces from 4 VCs
      ethTxMasters     : in  AxiStreamMasterArray(3 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
      ethTxSlaves      : out AxiStreamSlaveArray(3 downto 0);
      -- Receive interfaces from 4 VCs
      ethRxMasters     : out AxiStreamMasterArray(3 downto 0);
      ethRxMasterMuxed : out AxiStreamMasterType;
      ethRxCtrl        : in  AxiStreamCtrlArray(3 downto 0);
      -- MAC address and IP address
      -- Default IP Address is 192.168.  1. 20 
      --                       xC0.xA8.x01.x14
      ipAddr           : in  IPAddrType                       := IP_ADDR_INIT_C;
      -- Default MAC is 01:03:00:56:44:00                            
      macAddr          : in  MacAddrType                      := MAC_ADDR_INIT_C);
end GigEthLane;

-- Define architecture
architecture rtl of GigEthLane is

   signal macRxLaneIn : EthMacDataType;

   signal anTxPhyData  : EthTxPhyLaneOutType;
   signal macTxPhyData : EthTxPhyLaneOutType;

   signal iEthRxLinkSync : sl;
   signal iEthLinkReady  : sl;

   signal macRxDataOut   : slv(7 downto 0);
   signal macRxDataValid : sl;
   signal macRxGoodFrame : sl;
   signal macRxBadFrame  : sl;

   signal macTxDataOut : EthMacDataType;

   signal emacTxData  : slv(7 downto 0);
   signal emacTxValid : sl;
   signal emacTxAck   : sl;
   signal emacTxFirst : sl;

   signal udpTxValid  : sl;
   signal udpTxFast   : sl;
   signal udpTxReady  : sl;
   signal udpTxData   : slv(7 downto 0);
   signal udpTxLength : slv(15 downto 0);

   signal udpRxValid : sl;
   signal udpRxData  : slv(7 downto 0);
   signal udpRxGood  : sl;
   signal udpRxError : sl;
   signal udpRxCount : slv(15 downto 0);

   signal userTxValid : sl;
   signal userTxReady : sl;
   signal userTxData  : slv(31 downto 0);
   signal userTxSOF   : sl;
   signal userTxEOF   : sl;
   signal userTxVc    : slv(1 downto 0);

   constant JUMBO_EN_C : sl := '0';
   
   
begin

   -- Connections to top level ports
   ethRxLinkSync  <= iEthRxLinkSync;
   ethAutoNegDone <= iEthLinkReady;

   -- No polarity detection at the moment
   phyRxLaneOut.polarity <= '0';

   -- Initialization for raw data
   U_GigEthRxSync : entity work.GigEthRxSync
      generic map (
         TPD_G => TPD_G)
      port map (
         ethRxClk       => ethClk62MHz,
         ethRxLinkReady => iEthRxLinkSync,
         ethRxClkRst    => ethClk62MHzRst,
         ethRxLinkDown  => open,
         ethRxLinkError => open,
         phyRxPolarity  => open,
         phyRxData      => phyRxLaneIn.data,
         phyRxDataK     => phyRxLaneIn.dataK,
         phyRxDispErr   => phyRxLaneIn.dispErr,
         phyRxDecErr    => phyRxLaneIn.decErr,
         phyRxReady     => phyRxReady,
         phyRxInit      => open);

   -- Autonegotiation block
   U_GigEthAutoNeg : entity work.GigEthAutoNeg
      generic map (
         TPD_G         => TPD_G,
         SIM_SPEEDUP_G => SIM_RESET_SPEEDUP_G)
      port map (
         -- System clock, reset & control
         ethRxClk       => ethClk62MHz,
         ethRxClkRst    => ethClk62MHzRst,
         -- Link is ready
         ethRxLinkReady => iEthLinkReady,
         -- Link is stable
         ethRxLinkSync  => iEthRxLinkSync,
         -- Physical Interface Signals
         phyRxData      => phyRxLaneIn.data,
         phyRxDataK     => phyRxLaneIn.dataK,
         phyTxData      => anTxPhyData.data,
         phyTxDataK     => anTxPhyData.dataK);

   anTxPhyData.valid <= '1';

   -- Width translation for MAC RX
   U_GigEth16To8Mux : entity work.GigEth16To8Mux
      generic map (
         TPD_G           => TPD_G,
         CASCADE_SIZE_G  => 1,
         RST_ASYNC_G     => false,
         BRAM_EN_G       => true,
         USE_DSP48_G     => "no",
         USE_BUILT_IN_G  => false,
         XIL_DEVICE_G    => "7SERIES",
         SYNC_STAGES_G   => 3,
         PIPE_STAGES_G   => 0,
         LITTLE_ENDIAN_G => false,
         ADDR_WIDTH_G    => 4)
      port map (
         -- Input clocking to deal with the GTX interface
         ethPhy62MHzClk => ethClk62MHz,
         ethPhy62MHzRst => ethClk62MHzRst,
         ethLinkReady   => iEthLinkReady,
         -- 125 MHz clock for 8 bit outputs
         eth125MHzClk   => ethClk125MHz,
         -- PHY (16 bit) data interface in (62.5 MHz domain)
         ethPhyDataIn   => phyRxLaneIn,
         -- MAC (8 bit) data interface out (125 MHz domain)
         ethMacDataOut  => macRxLaneIn);

   -- MAC RX block
   U_GigEthMacRx : entity work.GigEthMacRx
      generic map (
         TPD_G => TPD_G)
      port map (
         -- 125 MHz ethernet clock in
         ethRxClk          => ethClk125MHz,
         ethRxRst          => ethClk125MHzRst,
         -- Incoming data from the 16-to-8 mux
         ethMacDataIn      => macRxLaneIn,
         -- Outgoing bytes and flags to the applications
         ethMacRxData      => macRxDataOut,
         ethMacRxValid     => macRxDataValid,
         ethMacRxGoodFrame => macRxGoodFrame,
         ethMacRxBadFrame  => macRxBadFrame); 

   -- Width translation for MAC TX
   U_GigEth8To16Mux : entity work.GigEth8To16Mux
      generic map (
         TPD_G           => TPD_G,
         CASCADE_SIZE_G  => 1,
         RST_ASYNC_G     => false,
         BRAM_EN_G       => true,
         USE_DSP48_G     => "no",
         USE_BUILT_IN_G  => false,
         XIL_DEVICE_G    => "7SERIES",
         SYNC_STAGES_G   => 3,
         PIPE_STAGES_G   => 0,
         LITTLE_ENDIAN_G => false,
         ADDR_WIDTH_G    => 4)
      port map (
         -- Clocking to deal with the GTX data out (62.5 MHz)
         ethPhy62MHzClk => ethClk62MHz,
         ethPhy62MHzRst => ethClk62MHzRst,
         -- 125 MHz clock for 8 bit inputs
         eth125MHzClk   => ethClk125MHz,
         -- PHY (16 bit) data interface in (62.5 MHz domain)
         ethPhyDataOut  => macTxPhyData,
         -- MAC (8 bit) data interface out (125 MHz domain)
         ethMacDataIn   => macTxDataOut);

   -- MAC TX block
   U_GigEthMacTx : entity work.GigEthMacTx
      generic map (
         TPD_G => TPD_G)
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
         ethMacDataOut     => macTxDataOut);

   -- Multiplex data source between autonegotiation and MAC data
   process(ethClk62MHz)
   begin
      if rising_edge(ethClk62MHz) then
         if (iEthLinkReady = '1' and macTxPhyData.valid = '1') then
            phyTxLaneOut <= macTxPhyData after TPD_G;
         else
            phyTxLaneOut <= anTxPhyData after TPD_G;
         end if;
      end if;
   end process;

   -- Ethernet client, including ARP engine and mux-ing between 
   -- ARP and UDP data
   U_EthClient : entity work.EthClient
      generic map (
         TPD_G   => TPD_G,
         UdpPort => 8192)
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
         udpRxCount      => udpRxCount);

   -- UDP framer
   U_GigEthUdpFrameSsi : entity work.GigEthUdpFrameSsi
      generic map (
         TPD_G => TPD_G)
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
         udpRxCount       => udpRxCount);

   -- UDP TX arbiter
   U_GigEthArbiterSsi : entity work.GigEthArbiterSsi
      generic map (
         TPD_G => TPD_G)
      port map (
         -- Ethernet clock & reset
         gtpClk        => ethClk125MHz,
         gtpClkRst     => ethClk125MHzRst,
         -- User Transmit ETH Interface to UDP framer
         userTxValid   => userTxValid,
         userTxReady   => userTxReady,
         userTxData    => userTxData,
         userTxSOF     => userTxSOF,
         userTxEOF     => userTxEOF,
         userTxVc      => userTxVc,
         -- User transmit interfaces (data from virtual channels)
         userTxMasters => ethTxMasters,
         userTxSlaves  => ethTxSlaves); 

end rtl;
