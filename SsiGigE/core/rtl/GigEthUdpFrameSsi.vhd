-------------------------------------------------------------------------------
-- Title         : Ethernet Interface Module, 8-bit word receive / transmit
-- Project       : SID, KPIX ASIC
-------------------------------------------------------------------------------
-- File          : GigEthUdpFrameSsiWrapper.vhd
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
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.GigEthPkg.all;

entity GigEthUdpFrameSsi is 
    generic (
      TPD_G             : time       := 1 ns
    );
    port ( 

      -- Ethernet clock & reset
      gtpClk           : in  std_logic;                        -- 125Mhz master clock
      gtpClkRst        : in  std_logic;                        -- Synchronous reset input

      -- User Transmit Interface
      userTxValid      : in  std_logic;
      userTxReady      : out std_logic;
      userTxData       : in  std_logic_vector(31 downto 0);    -- Ethernet TX Data
      userTxSOF        : in  std_logic;                        -- Ethernet TX Start of Frame
      userTxEOF        : in  std_logic;                        -- Ethernet TX End of Frame
      userTxVc         : in  std_logic_vector(1  downto 0);    -- Ethernet TX Virtual Channel

      -- User Receive Interface
      ethRxMasters     : out AxiStreamMasterArray(3 downto 0);
      ethRxMasterMuxed : out AxiStreamMasterType;

      -- UDP Block Transmit Interface (connection to MAC)
      udpTxValid       : out std_logic;
      udpTxFast        : out std_logic;
      udpTxReady       : in  std_logic;
      udpTxData        : out std_logic_vector(7  downto 0);
      udpTxLength      : out std_logic_vector(15 downto 0);
      udpTxJumbo       : in  std_logic;

      -- UDP Block Receive Interface (connection from MAC)
      udpRxValid       : in  std_logic;
      udpRxData        : in  std_logic_vector(7  downto 0);
      udpRxGood        : in  std_logic;
      udpRxError       : in  std_logic;
      udpRxCount       : in  std_logic_vector(15 downto 0)

   );
end GigEthUdpFrameSsi;

-- Define architecture for Interface module
architecture GigEthUdpFrameSsi of GigEthUdpFrameSsi is 
   
   signal userRxValid  : sl;
   signal userRxData   : slv(31 downto 0);
   signal userRxSOF    : sl;
   signal userRxEOF    : sl;
   signal userRxEOFE   : sl;
   signal userRxVc     : slv(1 downto 0);
   signal intRxVcValid : slv(3 downto 0);
   
   signal intRxMaster   : AxiStreamMasterType;
   signal remFifoStatus : AxiStreamCtrlArray(3 downto 0);
                 
begin

   -- Demuxed output port
   ethRxMasterMuxed  <= intRxMaster;   

   -- Generate one-hot encoding for intRxValid for valid/vc logic
   intRxVcValid <= "0001" when userRxValid = '1' and userRxVc = 0 else 
                   "0010" when userRxValid = '1' and userRxVc = 1 else 
                   "0100" when userRxValid = '1' and userRxVc = 2 else 
                   "1000" when userRxValid = '1' and userRxVc = 3 else 
                   "0000";
   
   -- Generate valid/vc
   process ( gtpClk ) is
      variable intMaster : AxiStreamMasterType;
   begin
      if rising_edge ( gtpClk ) then
         intMaster := AXI_STREAM_MASTER_INIT_C;

         intMaster.tData(31 downto 0) := userRxData;
         intMaster.tStrb(0)           := '1';
         intMaster.tKeep(0)           := '1';

         intMaster.tLast := userRxEOF;

         axiStreamSetUserBit(SSI_GIGETH_CONFIG_C,intMaster,SSI_EOFE_C,userRxEOFE);
         axiStreamSetUserBit(SSI_GIGETH_CONFIG_C,intMaster,SSI_SOF_C,userRxSOF,0);

         -- Generate valid and dest values
         case intRxVcValid is 
            when "0001" =>
               intMaster.tValid            := '1';
               intMaster.tDest(3 downto 0) := "0000";
            when "0010" =>
               intMaster.tValid            := '1';
               intMaster.tDest(3 downto 0) := "0001";
            when "0100" =>
               intMaster.tValid            := '1';
               intMaster.tDest(3 downto 0) := "0010";
            when "1000" =>
               intMaster.tValid            := '1';
               intMaster.tDest(3 downto 0) := "0011";
            when others =>
               intMaster.tValid            := '0';
         end case;

         if gtpClkRst = '1' then
            intMaster := AXI_STREAM_MASTER_INIT_C;
         else

         intRxMaster <= intMaster after TPD_G;

         end if;
      end if;
   end process;

   
   U_RxDeMux : entity work.AxiStreamDeMux
      generic map (
         TPD_G         => TPD_G,
         NUM_MASTERS_G => 4
      ) port map (
         axisClk      => gtpClk,
         axisRst      => gtpClkRst,
         sAxisMaster  => intRxMaster,
         sAxisSlave   => open,
         mAxisMasters => ethRxMasters,
         mAxisSlaves  => (others=>AXI_STREAM_SLAVE_FORCE_C)
      );   

      
   -- U_GigEthUdpFrame : entity work.GigEthUdpFrame
      -- port map (
         -- -- Ethernet clock & reset
         -- gtpClk         => gtpClk,
         -- gtpClkRst      => gtpClkRst,
         -- -- User Transmit Interface
         -- userTxValid    => userTxValid,
         -- userTxReady    => userTxReady,
         -- userTxData     => userTxData,
         -- userTxSOF      => userTxSOF,
         -- userTxEOF      => userTxEOF,
         -- userTxVc       => userTxVc,
         -- -- User Receive Interface
         -- userRxValid    => userRxValid,
         -- userRxData     => userRxData,
         -- userRxSOF      => userRxSOF,
         -- userRxEOF      => userRxEOF,
         -- userRxEOFE     => userRxEOFE,
         -- userRxVc       => userRxVc,
         -- -- UDP Block Transmit Interface (connection to MAC)
         -- udpTxValid     => udpTxValid,
         -- udpTxFast      => udpTxFast,
         -- udpTxReady     => udpTxReady,
         -- udpTxData      => udpTxData,
         -- udpTxLength    => udpTxLength,
         -- udpTxJumbo     => udpTxJumbo,
         -- -- UDP Block Receive Interface (connection from MAC)
         -- udpRxValid     => udpRxValid,
         -- udpRxData      => udpRxData,
         -- udpRxGood      => udpRxGood,
         -- udpRxError     => udpRxError,
         -- udpRxCount     => udpRxCount
      -- );      

   U_GigEthUdpFrameTx : entity work.GigEthUdpFrameTx
      generic map (
         EN_JUMBO_G => false
      )
      port map (
         -- Ethernet clock & reset
         gtpClk         => gtpClk,
         gtpClkRst      => gtpClkRst,
         -- User Transmit Interface
         userTxValid    => userTxValid,
         userTxReady    => userTxReady,
         userTxData     => userTxData,
         userTxSOF      => userTxSOF,
         userTxEOF      => userTxEOF,
         userTxVc       => userTxVc,
         -- UDP Block Transmit Interface (connection to MAC)
         udpTxValid     => udpTxValid,
         udpTxFast      => udpTxFast,
         udpTxReady     => udpTxReady,
         udpTxData      => udpTxData,
         udpTxLength    => udpTxLength
      );      

   U_GigEthUdpFrameRx : entity work.GigEthUdpFrameRx
      port map (
         -- Ethernet clock & reset
         gtpClk         => gtpClk,
         gtpClkRst      => gtpClkRst,
         -- User Receive Interface
         userRxValid    => userRxValid,
         userRxData     => userRxData,
         userRxSOF      => userRxSOF,
         userRxEOF      => userRxEOF,
         userRxEOFE     => userRxEOFE,
         userRxVc       => userRxVc,
         -- UDP Block Receive Interface (connection from MAC)
         udpRxValid     => udpRxValid,
         udpRxData      => udpRxData,
         udpRxGood      => udpRxGood,
         udpRxError     => udpRxError,
         udpRxCount     => udpRxCount
      );      

      
end GigEthUdpFrameSsi;

