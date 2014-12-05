-------------------------------------------------------------------------------
-- Title         : Gigabit Ethernet Core Package
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : GigEthPkg.vhd
-- Author        : Kurtis Nishimura, kurtisn@slac.stanford.edu
-- Created       : 05/28/2014
-------------------------------------------------------------------------------
-- Description:
-- Gigabit ethernet constants & types.
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 05/28/2014: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

package GigEthPkg is

   -----------------------------------------------------
   -- Constants
   -----------------------------------------------------

--   constant SSI_GIGETH_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(2, TKEEP_UNUSED_C);
   constant SSI_GIGETH_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(4);
  
   -- 8B10B Characters
   constant K_COM_C  : slv(7 downto 0) := "10111100"; -- K28.5, 0xBC
   constant D_215_C  : slv(7 downto 0) := "10110101"; -- D21.5, 0xB5
   constant D_022_C  : slv(7 downto 0) := "01000010"; -- D2.2,  0x42
   constant D_056_C  : slv(7 downto 0) := "11000101"; -- D5.6,  0xC5
   constant D_162_C  : slv(7 downto 0) := "01010000"; -- D16.2, 0x50
   
   -- Ordered sets
   constant OS_C1_C  : slv(15 downto 0) := D_215_C & K_COM_C; -- /C1/ 0xB5BC
   constant OS_C2_C  : slv(15 downto 0) := D_022_C & K_COM_C; -- /C2/ 0x42BC
   constant OS_I1_C  : slv(15 downto 0) := D_056_C & K_COM_C; -- /I1/ 0xC5BC
   constant OS_I2_C  : slv(15 downto 0) := D_162_C & K_COM_C; -- /I2/ 0x50BC
   constant K_SOP_C  : slv( 7 downto 0) := "11111011";        -- K27.7, 0xFB /S/ Start of packet
   constant K_EOP_C  : slv( 7 downto 0) := "11111101";        -- K29.7, 0xFD /T/ End of packet
   constant K_CAR_C  : slv( 7 downto 0) := "11110111";        -- K23.7, 0xF7 /R/ Carrier extend
   constant K_ERR_C  : slv( 7 downto 0) := "11111110";        -- K30.7, 0xFE /V/ Error propagation
   constant OS_BL_C  : slv(15 downto 0) := (others => '0');   -- Breaklink 0x0000
   
   -- Configuration registers
   -- No pause frames supported
   constant OS_CN_C  : slv(15 downto 0) := x"0020"; -- Configuration reg, ack bit unset
   constant OS_CA_C  : slv(15 downto 0) := x"4020"; -- Configuration reg, ack bit set
   -- Pause frames supported (this version of autonegotiation is not implemented yet)
   -- constant OS_CN_C  : slv(15 downto 0) := x"01a0";           --Config reg, no ack
   -- constant OS_CA_C  : slv(15 downto 0) := x"41a0";           --Config reg, with ack
   
   -- Ethernet constants
   constant ETH_PRE_C : slv(7 downto 0) := x"55";
   constant ETH_SOF_C : slv(7 downto 0) := x"D5";
   constant ETH_PAD_C : slv(7 downto 0) := x"00";
   
   -- Minimum payload size for Ethernet frame in bytes
   -- (starting from destination MAC and going through data)
   constant ETH_MIN_SIZE_C : integer := 64;

   -- This is the value you should get if you apply the CRC value to the packet
   -- over which it is applied.  It will be a constant value for correct CRC.
   constant CRC_CHECK_C : slv(31 downto 0) := x"1CDF4421";
   
   -- Link timer, assuming 62.5 MHz (16 bit data interface used by the GTX, Sync block, and autonegotiation)
   -- constant LINK_TIMER_C : natural := 625000; -- 625000 (0x98968) cycles @ 62.5 MHz, ~10 ms 
   constant LINK_TIMER_C : natural := 937500; -- 937500 (0xE4E1C) cycles @ 62.5 MHz, ~15 ms 
   
   -- Other types
   type EthRxPhyLaneOutType is record
      polarity : sl;             -- PHY receive signal polarity
   end record EthRxPhyLaneOutType;
   type EthRxPhyLaneOutArray is array (natural range <>) of EthRxPhyLaneOutType;

   type EthRxPhyLaneInType is record
      data    : slv(15 downto 0); -- PHY receive data
      dataK   : slv( 1 downto 0); -- PHY receive data is K character
      dispErr : slv( 1 downto 0); -- PHY receive data has disparity error
      decErr  : slv( 1 downto 0); -- PHY receive data not in table
   end record EthRxPhyLaneInType;
   type EthRxPhyLaneInArray is array (natural range <>) of EthRxPhyLaneInType;

   type EthTxPhyLaneOutType is record
      data  : slv(15 downto 0); -- PHY transmit data
      dataK : slv(1 downto 0);  -- PHY transmit data is K character
      valid : sl;
   end record EthTxPhyLaneOutType;

   type EthTxPhyLaneOutArray is array (natural range <>) of EthTxPhyLaneOutType;

   type EthMacDataType is record
      data      : slv(7 downto 0);
      dataK     : sl;
      dataValid : sl;
   end record EthMacDataType;
   
   type EthMacDataArray is array (natural range<>) of EthMacDataType;
   
end GigEthPkg;

package body GigEthPkg is
      
end package body GigEthPkg;
