-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Pgp2RxWrapper.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-10-31
-- Last update: 2012-11-26
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2012 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.Pgp2CoreTypesPkg.all;
use work.VcPkg.all;

entity Pgp2RxWrapper is
  
  generic (
    RxLaneCnt     : integer := 4;       -- Number of receive lanes, 1-4
    EnShortCells  : integer := 1;       -- Enable short non-EOF cells
    PayloadCntTop : integer := 7        -- Top bit for payload counter
    );
  port (

    -- System clock, reset & control
    pgpRxClk   : in std_logic;          -- Master clock
    pgpRxReset : in std_logic;          -- Synchronous reset input

    -- Non-VC related IO
    pgpRxIn  : in  PgpRxInType;
    pgpRxOut : out PgpRxOutType;

    -- VC Outputs
    pgpRxVcCommonOut : out RxVcCommonOutType;  -- Frame Receive common to all VCs
    pgpRxVcQuadOut   : out RxVcQuadOutType;    -- Frame Receive, 4 VCs

    -- PHY interface
    phyRxLanesOut : out PgpRxPhyLaneOutArray(0 to RxLaneCnt-1);
    phyRxLanesIn  : in  PgpRxPhyLaneInArray(0 to RxLaneCnt-1);
    phyRxReady    : in  std_logic;
    phyRxInit     : out std_logic;

    -- Crc Interface
    crcRxIn  : out PgpCrcInType;
    crcRxOut : in  std_logic_vector(31 downto 0);

    -- Debug
    debug : out std_logic_vector(63 downto 0)
    );
end entity Pgp2RxWrapper;

architecture rtl of Pgp2RxWrapper is

  signal intVcFrameRxData : std_logic_vector(16*RxLaneCnt-1 downto 0);
  signal intPhyRxPolarity : std_logic_vector(RxLaneCnt-1 downto 0);  -- PHY receive signal polarity
  signal intPhyRxData     : std_logic_vector(RxLaneCnt*16-1 downto 0);  -- PHY receive data
  signal intPhyRxDataK    : std_logic_vector(RxLaneCnt*2-1 downto 0);  -- PHY receive data is K character
  signal intPhyRxDispErr  : std_logic_vector(RxLaneCnt*2-1 downto 0);  -- PHY receive data has disparity error
  signal intPhyRxDecErr   : std_logic_vector(RxLaneCnt*2-1 downto 0);  -- PHY receive data not in table
  signal intCrcRxInData     : std_logic_vector(RxLaneCnt*16-1 downto 0);
  
begin

  wrap : process (intVcFrameRxData, intPhyRxPolarity, phyRxLanesIn, intCrcRxInData) is
  begin
    for i in 0 to RxLaneCnt-1 loop
      pgpRxVcCommonOut.frameRxData(i)    <= intVcFrameRxData(16*i+15 downto 16*i);
      phyRxLanesOut(i).polarity          <= intPhyRxPolarity(i);
      intPhyRxData(16*i+15 downto 16*i)  <= phyRxLanesIn(i).data;
      intPhyRxDataK(2*i+1 downto 2*i)    <= phyRxLanesIn(i).dataK;
      intPhyRxDispErr(2*i+1 downto 2*i)  <= phyRxLanesIn(i).dispErr;
      intPhyRxDecErr(2*i+1 downto 2*i)   <= phyRxLanesIn(i).decErr;
      crcRxIn.crcIn(16*i+15 downto 16*i) <= intCrcRxInData(16*i+15 downto 16*i);
    end loop;
  end process;

  Pgp2Rx_1 : entity work.Pgp2Rx
    generic map (
      RxLaneCnt     => RxLaneCnt,
      EnShortCells  => EnShortCells,
      PayloadCntTop => PayloadCntTop)
    port map (
      pgpRxClk        => pgpRxClk,
      pgpRxReset      => pgpRxReset,
      pgpRxFlush      => pgpRxIn.flush,                 --pgpRxFlush,
      pgpRxLinkReady  => pgpRxOut.linkReady,            --pgpRxLinkReady,
      pgpRxCellError  => pgpRxOut.cellError,            --pgpRxCellError,
      pgpRxLinkDown   => pgpRxOut.linkDown,             --pgpRxLinkDown,
      pgpRxLinkError  => pgpRxOut.linkError,            --pgpRxLinkError,
      pgpRxOpCodeEn   => pgpRxOut.opCodeEn,             --pgpRxOpCodeEn,
      pgpRxOpCode     => pgpRxOut.opCode,               --pgpRxOpCode,
      pgpRemLinkReady => pgpRxOut.remLinkReady,         --pgpRemLinkReady,
      pgpRemData      => pgpRxOut.remLinkData,          --pgpRemData,
      vcFrameRxSOF    => pgpRxVcCommonOut.frameRxSOF,   --vcFrameRxSOF,
      vcFrameRxEOF    => pgpRxVcCommonOut.frameRxEOF,   --vcFrameRxEOF,
      vcFrameRxEOFE   => pgpRxVcCommonOut.frameRxEOFE,  --vcFrameRxEOFE,
      vcFrameRxData   => intVcFrameRxData,
      vc0FrameRxValid => pgpRxVcQuadOut(0).frameRxValid,
      vc0RemBuffAFull => pgpRxVcQuadOut(0).remBuffAFull,
      vc0RemBuffFull  => pgpRxVcQuadOut(0).remBuffFull,
      vc1FrameRxValid => pgpRxVcQuadOut(1).frameRxValid,
      vc1RemBuffAFull => pgpRxVcQuadOut(1).remBuffAFull,
      vc1RemBuffFull  => pgpRxVcQuadOut(1).remBuffFull,
      vc2FrameRxValid => pgpRxVcQuadOut(2).frameRxValid,
      vc2RemBuffAFull => pgpRxVcQuadOut(2).remBuffAFull,
      vc2RemBuffFull  => pgpRxVcQuadOut(2).remBuffFull,
      vc3FrameRxValid => pgpRxVcQuadOut(3).frameRxValid,
      vc3RemBuffAFull => pgpRxVcQuadOut(3).remBuffAFull,
      vc3RemBuffFull  => pgpRxVcQuadOut(3).remBuffFull,
      phyRxPolarity   => intPhyRxPolarity,
      phyRxData       => intPhyRxData,
      phyRxDataK      => intPhyRxDataK,
      phyRxDispErr    => intPhyRxDispErr,
      phyRxDecErr     => intPhyRxDecErr,
      phyRxReady      => phyRxReady,
      phyRxInit       => phyRxInit,
      crcRxIn         => intCrcRxInData,
      crcRxWidth      => crcRxIn.width,
      crcRxInit       => crcRxIn.init,
      crcRxValid      => crcRxIn.valid,
      crcRxOut        => crcRxOut,
      debug           => debug);

end architecture rtl;
