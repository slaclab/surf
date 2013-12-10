-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol, RCE Package
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : Pgp2RcePackage.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 11/23/2009
-------------------------------------------------------------------------------
-- Description:
-- Application Components package.
-------------------------------------------------------------------------------
-- Copyright (c) 2006 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 11/23/2009: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

package Pgp2RcePackage is

   -- PGP Lane
   component Pgp2RceLane 
      generic (
         MgtMode   : string  := "A";
         RefClkSel : string  := "REFCLK1"
      ); port ( 
         pgpClk            : in  std_logic;
         pgpReset          : in  std_logic;
         pllTxRst          : in  std_logic;
         pllRxRst          : in  std_logic;
         pllRxReady        : out std_logic;
         pllTxReady        : out std_logic;
         pgpLocLinkReady   : out std_logic;
         pgpRemLinkReady   : out std_logic;
         pgpLocData        : in  std_logic_vector(7 downto 0);
         pgpRemData        : out std_logic_vector(7 downto 0);
         cntReset          : in  std_logic;
         pgpCntCellError   : out std_logic_vector(3 downto 0);
         pgpCntLinkDown    : out std_logic_vector(3 downto 0);
         pgpCntLinkError   : out std_logic_vector(3 downto 0);
         pgpRxFifoErr      : out std_logic;
         pgpRxCnt          : out std_logic_vector(3 downto 0);
         laneNumber        : in  std_logic_vector(1 downto 0);
         vcFrameRxSOF      : out std_logic;
         vcFrameRxEOF      : out std_logic;
         vcFrameRxEOFE     : out std_logic;
         vcFrameRxData     : out std_logic_vector(63 downto 0);
         vcFrameRxReq      : out std_logic;
         vcFrameRxValid    : out std_logic;
         vcFrameRxReady    : in  std_logic;
         vcFrameRxWidth    : out std_logic_vector(1  downto 0);
         vcFrameTxVc       : in  std_logic_vector(1 downto 0);
         vcFrameTxValid    : in  std_logic;
         vcFrameTxReady    : out std_logic;
         vcFrameTxSOF      : in  std_logic;
         vcFrameTxEOF      : in  std_logic;
         vcFrameTxEOFE     : in  std_logic;
         vcFrameTxData     : in  std_logic_vector(15 downto 0);
         vcRemBuffAFull    : out std_logic_vector(3 downto 0);
         vcRemBuffFull     : out std_logic_vector(3 downto 0);
         mgtLoopback       : in  std_logic;
         mgtRefClk1        : in  std_logic;
         mgtRefClk2        : in  std_logic;
         mgtRxN            : in  std_logic;
         mgtRxP            : in  std_logic;
         mgtTxN            : out std_logic;
         mgtTxP            : out std_logic;
         mgtCombusIn       : in  std_logic_vector(15 downto 0);
         mgtCombusOut      : out std_logic_vector(15 downto 0);
         dclk              : in  std_logic;                     -- MGT Dynamic reconfig port
         den               : in  std_logic;
         dwen              : in  std_logic;
         daddr             : in  std_logic_vector( 7 downto 0);
         ddin              : in  std_logic_vector(15 downto 0);
         drdy              : out std_logic;
         ddout             : out std_logic_vector(15 downto 0);
         debug             : out std_logic_vector(63 downto 0)
      );
   end component;

   -- RCE Export Block
   component Pgp2RceExport 
      port ( 
         pgpClk                         : in  std_logic;
         pgpReset                       : in  std_logic;
         Export_Clock                   : out std_logic;
         Export_Core_Reset              : in  std_logic;
         Export_Data_Available          : in  std_logic;
         Export_Data_Start              : in  std_logic;
         Export_Advance_Data_Pipeline   : out std_logic;
         Export_Data_Last_Line          : in  std_logic;
         Export_Data_Last_Valid_Byte    : in  std_logic_vector(2  downto 0);
         Export_Data                    : in  std_logic_vector(63 downto 0);
         Export_Advance_Status_Pipeline : out std_logic;
         Export_Status                  : out std_logic_vector(31 downto 0);
         Export_Status_Full             : in  std_logic;
         pgpRemLinkReady                : in  std_logic_vector(3  downto 0);
         vcFrameTxVc                    : out std_logic_vector(1  downto 0);
         vcFrameTxSOF                   : out std_logic;
         vcFrameTxEOF                   : out std_logic;
         vcFrameTxEOFE                  : out std_logic;
         vcFrameTxData                  : out std_logic_vector(15 downto 0);
         vcFrameTxValid                 : out std_logic_vector(3  downto 0);
         vcFrameTxReady                 : in  std_logic_vector(3  downto 0);
         vcRemBuffAFull                 : in  std_logic_vector(15 downto 0);
         vcRemBuffFull                  : in  std_logic_vector(15 downto 0);
         bigEndian                      : in  std_logic;
         debug                          : out std_logic_vector(63 downto 0)
      );
   end component;

   -- RCE Import Block
   component Pgp2RceImport
      generic (
         FreeListA     : natural := 1;
         FreeListB     : natural := 2;
         FreeListC     : natural := 3;
         FreeListD     : natural := 4;
         PayloadCntTop : integer := 7
      );
      port ( 
         pgpClk                       : in  std_logic;
         pgpReset                     : in  std_logic;
         Import_Clock                 : out std_logic;
         Import_Core_Reset            : in  std_logic;
         Import_Free_List             : out std_logic_vector( 3 downto 0);
         Import_Advance_Data_Pipeline : out std_logic;
         Import_Data_Last_Line        : out std_logic;
         Import_Data_Last_Valid_Byte  : out std_logic_vector( 2 downto 0);
         Import_Data                  : out std_logic_vector(63 downto 0);
         Import_Data_Pipeline_Full    : in  std_logic;
         Import_Pause                 : in  std_logic;
         pgpLocLinkReady              : in  std_logic_vector(3  downto 0);
         vcFrameRxSOF                 : in  std_logic_vector(3  downto 0);
         vcFrameRxEOF                 : in  std_logic_vector(3  downto 0);
         vcFrameRxEOFE                : in  std_logic_vector(3  downto 0);
         vcFrameRxDataA               : in  std_logic_vector(63 downto 0);
         vcFrameRxDataB               : in  std_logic_vector(63 downto 0);
         vcFrameRxDataC               : in  std_logic_vector(63 downto 0);
         vcFrameRxDataD               : in  std_logic_vector(63 downto 0);
         vcFrameRxReq                 : in  std_logic_vector(3  downto 0);
         vcFrameRxValid               : in  std_logic_vector(3  downto 0);
         vcFrameRxReady               : out std_logic_vector(3  downto 0);
         vcFrameRxWidthA              : in  std_logic_vector(1  downto 0);
         vcFrameRxWidthB              : in  std_logic_vector(1  downto 0);
         vcFrameRxWidthC              : in  std_logic_vector(1  downto 0);
         vcFrameRxWidthD              : in  std_logic_vector(1  downto 0);
         bigEndian                    : in  std_logic;
         debug                        : out std_logic_vector(63 downto 0)
      );
   end component;

   
   -- RCE Wrapper
   component Pgp2Rce
      generic (
         FreeListA  : natural := 1;
         FreeListB  : natural := 2;
         FreeListC  : natural := 3;
         FreeListD  : natural := 4;
         RefClkSel  : string  := "REFCLK1";
         PgpLaneCnt : natural := 4
      );
      port ( 
         Import_Clock                    : out std_logic;
         Import_Core_Reset               : in  std_logic;
         Import_Free_List                : out std_logic_vector( 3 downto 0);
         Import_Advance_Data_Pipeline    : out std_logic;
         Import_Data_Last_Line           : out std_logic;
         Import_Data_Last_Valid_Byte     : out std_logic_vector( 2 downto 0);
         Import_Data                     : out std_logic_vector(63 downto 0);
         Import_Data_Pipeline_Full       : in  std_logic;
         Import_Pause                    : in  std_logic;
         Export_Clock                    : out std_logic;
         Export_Core_Reset               : in  std_logic;
         Export_Data_Available           : in  std_logic;
         Export_Data_Start               : in  std_logic;
         Export_Advance_Data_Pipeline    : out std_logic;
         Export_Data_Last_Line           : in  std_logic;
         Export_Data_Last_Valid_Byte     : in  std_logic_vector( 2 downto 0);
         Export_Data                     : in  std_logic_vector(63 downto 0);
         Export_Advance_Status_Pipeline  : out std_logic;
         Export_Status                   : out std_logic_vector(31 downto 0);
         Export_Status_Full              : in  std_logic;
         Dcr_Clock                       : in  std_logic;
         Dcr_Write                       : in  std_logic;
         Dcr_Write_Data                  : in  std_logic_vector(31 downto 0);
         Dcr_Read_Address                : in  std_logic_vector( 1 downto 0);
         Dcr_Read_Data                   : out std_logic_vector(31 downto 0);
         pgpRefClk1                      : in  std_logic;
         pgpRefClk2                      : in  std_logic;
         pgpClk                          : in  std_logic;
         pgpReset                        : in  std_logic;
         mgtRxN                          : in  std_logic_vector(PgpLaneCnt-1 downto 0);
         mgtRxP                          : in  std_logic_vector(PgpLaneCnt-1 downto 0);
         mgtTxN                          : out std_logic_vector(PgpLaneCnt-1 downto 0);
         mgtTxP                          : out std_logic_vector(PgpLaneCnt-1 downto 0)
      );
   end component;


end Pgp2RcePackage;

