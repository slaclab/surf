-------------------------------------------------------------------------------
-- Title         : Ethernet Arbiter Module
-- Project       : General Use
-------------------------------------------------------------------------------
-- File          : GigEthArbiterSsi.vhd
-- Author        : Kurtis Nishimura <kurtisn@slac.stanford.edu>
-- Created       : 06/03/2014
-------------------------------------------------------------------------------
-- Description:
-- Simple wrapper over existing ethernet TX arbiter to match SSI conventions.
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC.
-------------------------------------------------------------------------------
-- Modification history:
-- 06/03/2014: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
Library Unisim;
USE ieee.std_logic_1164.ALL;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.EthClientPackage.all;
use work.GigEthPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.StdRtlPkg.all;

entity GigEthArbiterSsi is 
   port ( 

      -- Ethernet clock & reset
      gtpClk         : in  std_logic;                        -- 125Mhz master clock
      gtpClkRst      : in  std_logic;                        -- Synchronous reset input
      
      -- User Transmit ETH Interface to UDP framer
      userTxValid    : out std_logic;
      userTxReady    : in  std_logic;
      userTxData     : out std_logic_vector(31 downto 0);    -- Ethernet TX Data
      userTxSOF      : out std_logic;                        -- Ethernet TX Start of Frame
      userTxEOF      : out std_logic;                        -- Ethernet TX End of Frame
      userTxVc       : out std_logic_vector(1  downto 0);    -- Ethernet TX Virtual Channel

      -- User transmit interfaces (data from virtual channels)
      userTxMasters  : in  AxiStreamMasterArray(3 downto 0);
      userTxSlaves   : out AxiStreamSlaveArray(3 downto 0) 
      
   );
end GigEthArbiterSsi;


-- Define architecture for Interface module
architecture GigEthArbiterSsi of GigEthArbiterSsi is 

   signal iTxMasters  : AxiStreamMasterArray(3 downto 0);
   signal iTxSlaves   : AxiStreamSlaveArray(3 downto 0);
   signal userSOF     : slv(3 downto 0);
   signal thisSOF     : slv(3 downto 0);
   signal lastSOF     : slv(3 downto 0);
   signal lastSOF2    : slv(3 downto 0);
   
begin

   -- Assignments to/from ports
   iTxMasters   <= userTxMasters;
   userTxSlaves <= iTxSlaves;

   -- Generate SOF from AxiStream information
   U_Vc_Gen : for i in 0 to 3 generate
      userSOF(i) <= axiStreamGetUserBit(SSI_GIGETH_CONFIG_C,userTxMasters(i),SSI_SOF_C,0);
   end generate;
   
   -- Map into the ethernet arbiter
   U_EthArbiter : entity work.EthArbiter
      port map (
         -- Ethernet clock & reset
         gtpClk         => gtpClk,
         gtpClkRst      => gtpClkRst,
         -- User Transmit ETH Interface
         userTxValid    => userTxValid,
         userTxReady    => userTxReady,
         userTxData     => userTxData,
         userTxSOF      => userTxSOF,
         userTxEOF      => userTxEOF,
         userTxVc       => userTxVc,
         -- User 0 Transmit Interface
         user0TxValid   => iTxMasters(0).tValid,
         user0TxReady   => iTxSlaves(0).tReady,
         user0TxData    => iTxMasters(0).tData(31 downto 0),
         user0TxSOF     => userSOF(0),
         user0TxEOF     => iTxMasters(0).tLast,
         -- User 1 Transmit Interface
         user1TxValid   => iTxMasters(1).tValid,
         user1TxReady   => iTxSlaves(1).tReady,
         user1TxData    => iTxMasters(1).tData(31 downto 0),
         user1TxSOF     => userSOF(1),
         user1TxEOF     => iTxMasters(1).tLast,
         -- User 2 Transmit Interface
         user2TxValid   => iTxMasters(2).tValid,
         user2TxReady   => iTxSlaves(2).tReady,
         user2TxData    => iTxMasters(2).tData(31 downto 0),
         user2TxSOF     => userSOF(2),
         user2TxEOF     => iTxMasters(2).tLast,
         -- User 3 Transmit Interface
         user3TxValid   => iTxMasters(3).tValid,
         user3TxReady   => iTxSlaves(3).tReady,
         user3TxData    => iTxMasters(3).tData(31 downto 0),
         user3TxSOF     => userSOF(3),
         user3TxEOF     => iTxMasters(3).tLast         
      );

end GigEthArbiterSsi;
