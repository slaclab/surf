-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Pgp2TxWrapper.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-11-02
-- Last update: 2012-11-14
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

entity Pgp2TxWrapper is
  
  generic (
    TxLaneCnt     : integer := 4;       -- Number of receive lanes, 1-4
    VcInterleave  : integer := 1;       -- Interleave Frames
    PayloadCntTop : integer := 7        -- Top bit for payload counter
    );
  port (

    -- System clock, reset & control
    pgpTxClk   : in std_logic;          -- Master clock
    pgpTxReset : in std_logic;          -- Synchronous reset input

    -- Non-VC related IO
    pgpTxIn  : in  PgpTxInType;
    pgpTxOut : out PgpTxOutType;

    -- VC Interface
    pgpTxVcQuadIn  : in  TxVcQuadInType;
    pgpTxVcQuadOut : out TxVcQuadOutType;

    phyTxLanesOut : out PgpTxPhyLaneOutArray(0 to TxLaneCnt-1);
    phyTxReady    : in  std_logic;

    -- Transmit CRC Interface
    crcTxIn  : out PgpCrcInType;
    crcTxOut : in  std_logic_vector(31 downto 0);  -- Transmit calculated CRC value

    -- Debug
    debug : out std_logic_vector(63 downto 0)
    );

end entity Pgp2TxWrapper;

architecture rtl of Pgp2TxWrapper is

  type VcDataType is array (0 to 3) of std_logic_vector(16*TxLaneCnt-1 downto 0);
  signal intVcFrameTxData : VcDataType;
  signal intPhyTxData     : std_logic_vector(TxLaneCnt*16-1 downto 0);  -- PHY receive data
  signal intPhyTxDataK    : std_logic_vector(TxLaneCnt*2-1 downto 0);  -- PHY receive data is K character
  signal intCrcInData     : std_logic_vector(TxLaneCnt*16-1 downto 0);
  
begin

  wrap : process (intVcFrameTxData, intPhyTxData, intPhyTxDataK, intCrcInData, pgpTxVcQuadIn) is
  begin
    for i in 0 to TxLaneCnt-1 loop
      for j in 0 to 3 loop
        intVcFrameTxData(j)(16*i+15 downto 16*i) <= pgpTxVcQuadIn(j).frameTxData(i);
      end loop;
      phyTxLanesOut(i).data              <= intPhyTxData(16*i+15 downto 16*i);
      phyTxLanesOut(i).dataK             <= intPhyTxDataK(2*i+1 downto 2*i);
      crcTxIn.crcIn(16*i+15 downto 16*i) <= intCrcInData(16*i+15 downto 16*i);
    end loop;
  end process;

  Pgp2Tx_1 : entity work.Pgp2Tx
    generic map (
      TxLaneCnt     => TxLaneCnt,
      VcInterleave  => VcInterleave,
      PayloadCntTop => PayloadCntTop)
    port map (
      pgpTxClk        => pgpTxClk,
      pgpTxReset      => pgpTxReset,
      pgpTxFlush      => pgpTxIn.flush,
      pgpTxLinkReady  => pgpTxOut.linkReady,
      pgpTxOpCodeEn   => pgpTxIn.opCodeEn,
      pgpTxOpCode     => pgpTxIn.opCode,
      pgpLocLinkReady => pgpTxIn.locLinkReady,
      pgpLocData      => pgpTxIn.locData,
      vc0FrameTxValid => pgpTxVcQuadIn(0).frameTxValid,
      vc0FrameTxReady => pgpTxVcQuadOut(0).frameTxReady,
      vc0FrameTxSOF   => pgpTxVcQuadIn(0).frameTxSOF,
      vc0FrameTxEOF   => pgpTxVcQuadIn(0).frameTxEOF,
      vc0FrameTxEOFE  => pgpTxVcQuadIn(0).frameTxEOFE,
      vc0FrameTxData  => intVcFrameTxData(0),
      vc0LocBuffAFull => pgpTxVcQuadIn(0).LocBuffAFull,
      vc0LocBuffFull  => pgpTxVcQuadIn(0).locBuffFull,
      vc1FrameTxValid => pgpTxVcQuadIn(1).frameTxValid,
      vc1FrameTxReady => pgpTxVcQuadOut(1).frameTxReady,
      vc1FrameTxSOF   => pgpTxVcQuadIn(1).frameTxSOF,
      vc1FrameTxEOF   => pgpTxVcQuadIn(1).frameTxEOF,
      vc1FrameTxEOFE  => pgpTxVcQuadIn(1).frameTxEOFE,
      vc1FrameTxData  => intVcFrameTxData(1),
      vc1LocBuffAFull => pgpTxVcQuadIn(1).locBuffAFull,
      vc1LocBuffFull  => pgpTxVcQuadIn(1).LocBuffFull,
      vc2FrameTxValid => pgpTxVcQuadIn(2).frameTxValid,
      vc2FrameTxReady => pgpTxVcQuadOut(2).frameTxReady,
      vc2FrameTxSOF   => pgpTxVcQuadIn(2).frameTxSOF,
      vc2FrameTxEOF   => pgpTxVcQuadIn(2).frameTxEOF,
      vc2FrameTxEOFE  => pgpTxVcQuadIn(2).frameTxEOFE,
      vc2FrameTxData  => intVcFrameTxData(2),
      vc2LocBuffAFull => pgpTxVcQuadIn(2).LocBuffAFull,
      vc2LocBuffFull  => pgpTxVcQuadIn(2).locBuffFull,
      vc3FrameTxValid => pgpTxVcQuadIn(3).frameTxValid,
      vc3FrameTxReady => pgpTxVcQuadOut(3).frameTxReady,
      vc3FrameTxSOF   => pgpTxVcQuadIn(3).frameTxSOF,
      vc3FrameTxEOF   => pgpTxVcQuadIn(3).frameTxEOF,
      vc3FrameTxEOFE  => pgpTxVcQuadIn(3).frameTxEOFE,
      vc3FrameTxData  => intVcFrameTxData(3),
      vc3LocBuffAFull => pgpTxVcQuadIn(3).locBuffAFull,
      vc3LocBuffFull  => pgpTxVcQuadIn(3).LocBuffFull,
      phyTxData       => intPhyTxData,
      phyTxDataK      => intPhyTxDataK,
      phyTxReady      => phyTxReady,
      crcTxIn         => intCrcInData,
      crcTxInit       => crcTxIn.init,
      crcTxValid      => crcTxIn.valid,
      crcTxOut        => crcTxOut,
      debug           => debug);

end architecture rtl;
