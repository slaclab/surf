-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol, V2, Top Level PGP + MGT Test Bench
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : Pgp2RceTb.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 05/27/2009
-------------------------------------------------------------------------------
-- Description:
-- Test Bench for PGP core plus Xilinx MGT
-------------------------------------------------------------------------------
-- This file is part of 'SLAC PGP2 Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC PGP2 Core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
-- Modification history:
-- 05/27/2009: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
USE work.ALL;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.Pgp2MgtPackage.all;
use work.Pgp2RcePackage.all;
Library unisim;
use unisim.vcomponents.all;

entity Pgp2RceTb is end Pgp2RceTb;


-- Define architecture
architecture Pgp2RceTb of Pgp2RceTb is

   component RceLoop
      port (
         Export_Clock                    : in  std_logic;
         Export_Core_Reset               : out std_logic;
         Export_Data_Available           : out std_logic;
         Export_Data_Start               : out std_logic;
         Export_Advance_Data_Pipeline    : in  std_logic;
         Export_Data_Last_Line           : out std_logic;
         Export_Data_Last_Valid_Byte     : out std_logic_vector( 2 downto 0);
         Export_Data_Low                 : out std_logic_vector(31 downto 0);
         Export_Data_High                : out std_logic_vector(31 downto 0);
         Export_Advance_Status_Pipeline  : in  std_logic;
         Export_Status                   : in  std_logic_vector(31 downto 0);
         Export_Status_Full              : out std_logic;
         Import_Clock                    : in  std_logic;
         Import_Core_Reset               : out std_logic;
         Import_Free_List                : in  std_logic_vector( 3 downto 0);
         Import_Advance_Data_Pipeline    : in  std_logic;
         Import_Data_Last_Line           : in  std_logic;
         Import_Data_Last_Valid_Byte     : in  std_logic_vector( 2 downto 0);
         Import_Data_Low                 : in  std_logic_vector(31 downto 0);
         Import_Data_High                : in  std_logic_vector(31 downto 0);
         Import_Data_Pipeline_Full       : out std_logic;
         Import_Pause                    : out std_logic;
         Dcr_Clock                       : in  std_logic;
         Dcr_Write                       : out std_logic;
         Dcr_Write_Data                  : out std_logic_vector(31 downto 0);
         Dcr_Read_Address                : out std_logic_vector( 1 downto 0);
         Dcr_Read_Data                   : in  std_logic_vector(31 downto 0)
      );
   end component;


   -- Internal signals
   signal pgpClk                          : std_logic;
   signal pgpReset                        : std_logic;
   signal refClk                          : std_logic;
   signal ponRstL                         : std_logic;
   signal Import_Clock                    : std_logic;
   signal Import_Core_Reset               : std_logic;
   signal Import_Free_List                : std_logic_vector( 3 downto 0);
   signal Import_Advance_Data_Pipeline    : std_logic;
   signal Import_Data_Last_Line           : std_logic;
   signal Import_Data_Last_Valid_Byte     : std_logic_vector( 2 downto 0);
   signal Import_Data                     : std_logic_vector(63 downto 0);
   signal Import_Data_Pipeline_Full       : std_logic;
   signal Import_Pause                    : std_logic;
   signal Export_Clock                    : std_logic;
   signal Export_Core_Reset               : std_logic;
   signal Export_Data_Available           : std_logic;
   signal Export_Data_Start               : std_logic;
   signal Export_Advance_Data_Pipeline    : std_logic;
   signal Export_Data_Last_Line           : std_logic;
   signal Export_Data_Last_Valid_Byte     : std_logic_vector( 2 downto 0);
   signal Export_Data                     : std_logic_vector(63 downto 0);
   signal Export_Advance_Status_Pipeline  : std_logic;
   signal Export_Status                   : std_logic_vector(31 downto 0);
   signal Export_Status_Full              : std_logic;
   signal Dcr_Clock                       : std_logic;
   signal Dcr_Write                       : std_logic;
   signal Dcr_Write_Data                  : std_logic_vector(31 downto 0);
   signal Dcr_Read_Address                : std_logic_vector( 1 downto 0);
   signal Dcr_Read_Data                   : std_logic_vector(31 downto 0);

begin


   -- Power On Reset generation
   process 
   begin
      ponRstL  <= '1';
      wait for (6.4 ns);
      ponRstL  <= '0';
      wait for (6.4 ns * 20);
      ponRstL  <= '1';
      wait;
   end process;

   -- 156.25Mhz Reference Clock generation
   process 
   begin
      refClk <= '0';
      wait for (6.4 ns / 2);
      refClk <= '1';
      wait for (6.4 ns / 2);
   end process;


   -- PGP Clcok Block
   U_Pgp2MgtClk: Pgp2MgtPackage.Pgp2MgtClk generic map (
      UserFxDiv  => 5,
      UserFxMult => 4
   ) port map (
      refClkIn      => refClk,
      ponResetL     => ponRstL,
      locReset      => '0',
      pgpClk        => pgpClk,
      pgpReset      => pgpReset,
      userClk       => open,
      userReset     => open,
      pgpClkIn      => pgpClk,
      userClkIn     => '0'
   );


   -- RCE Interface
   U_Pgp2Rce4x: Pgp2RcePackage.Pgp2Rce4x 
      generic map (
         FreeListA  => 7,
         FreeListB  => 7,
         FreeListC  => 7,
         FreeListD  => 7,
         RefClkSel  => "REFCLK1"
      )
      port map ( 
         Import_Clock                    => Import_Clock,
         Import_Core_Reset               => Import_Core_Reset,
         Import_Free_List                => Import_Free_List,
         Import_Advance_Data_Pipeline    => Import_Advance_Data_Pipeline,
         Import_Data_Last_Line           => Import_Data_Last_Line,
         Import_Data_Last_Valid_Byte     => Import_Data_Last_Valid_Byte,
         Import_Data                     => Import_Data,
         Import_Data_Pipeline_Full       => Import_Data_Pipeline_Full,
         Import_Pause                    => Import_Pause,
         Export_Clock                    => Export_Clock,
         Export_Core_Reset               => Export_Core_Reset,
         Export_Data_Available           => Export_Data_Available,
         Export_Data_Start               => Export_Data_Start,
         Export_Advance_Data_Pipeline    => Export_Advance_Data_Pipeline,
         Export_Data_Last_Line           => Export_Data_Last_Line,
         Export_Data_Last_Valid_Byte     => Export_Data_Last_Valid_Byte,
         Export_Data                     => Export_Data,
         Export_Advance_Status_Pipeline  => Export_Advance_Status_Pipeline,
         Export_Status                   => Export_Status,
         Export_Status_Full              => Export_Status_Full,
         Dcr_Clock                       => Dcr_Clock,
         Dcr_Write                       => Dcr_Write,
         Dcr_Write_Data                  => Dcr_Write_Data,
         Dcr_Read_Address                => Dcr_Read_Address,
         Dcr_Read_Data                   => Dcr_Read_Data,
         pgpRefClk1                      => refClk,
         pgpRefClk2                      => '0',
         pgpClk                          => pgpClk,
         pgpReset                        => pgpReset,
         mgtRxN                          => (others=>'0'),
         mgtRxP                          => (others=>'0'),
         mgtTxN                          => open,
         mgtTxP                          => open
      );


   -- SYSC RCE Loopback Model
   U_RceLoop: RceLoop 
      port map (
         Export_Clock                    => Export_Clock,
         Export_Core_Reset               => Export_Core_Reset,
         Export_Data_Available           => Export_Data_Available,
         Export_Data_Start               => Export_Data_Start,
         Export_Advance_Data_Pipeline    => Export_Advance_Data_Pipeline,
         Export_Data_Last_Line           => Export_Data_Last_Line,
         Export_Data_Last_Valid_Byte     => Export_Data_Last_Valid_Byte,
         Export_Data_Low                 => Export_Data(31 downto 0),
         Export_Data_High                => Export_Data(63 downto 32),
         Export_Advance_Status_Pipeline  => Export_Advance_Status_Pipeline,
         Export_Status                   => Export_Status,
         Export_Status_Full              => Export_Status_Full,
         Import_Clock                    => Import_Clock,
         Import_Core_Reset               => Import_Core_Reset,
         Import_Free_List                => Import_Free_List,
         Import_Advance_Data_Pipeline    => Import_Advance_Data_Pipeline,
         Import_Data_Last_Line           => Import_Data_Last_Line,
         Import_Data_Last_Valid_Byte     => Import_Data_Last_Valid_Byte,
         Import_Data_Low                 => Import_Data(31 downto 0),
         Import_Data_High                => Import_Data(63 downto 32),
         Import_Data_Pipeline_Full       => Import_Data_Pipeline_Full,
         Import_Pause                    => Import_Pause,
         Dcr_Clock                       => Dcr_Clock,
         Dcr_Write                       => Dcr_Write,
         Dcr_Write_Data                  => Dcr_Write_Data,
         Dcr_Read_Address                => Dcr_Read_Address,
         Dcr_Read_Data                   => Dcr_Read_Data
      );

end Pgp2RceTb;

