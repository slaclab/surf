-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Pgp2TxWrapper.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-11-02
-- Last update: 2013-12-11
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
      TxLaneCnt     : integer := 4;     -- Number of receive lanes, 1-4
      VcInterleave  : integer := 1;     -- Interleave Frames
      PayloadCntTop : integer := 7;      -- Top bit for payload counter
      NUM_VC_EN_G : integer range 1 to 4 := 4
      );
   port (

      -- System clock, reset & control
      pgpTxClk   : in std_logic;        -- Master clock
      pgpTxReset : in std_logic;        -- Synchronous reset input

      -- Non-VC related IO
      pgpTxIn  : in  PgpTxInType;
      pgpTxOut : out PgpTxOutType;

      -- VC Interface
      pgpVcTxQuadIn  : in  VcTxQuadInType;
      pgpVcTxQuadOut : out VcTxQuadOutType;

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

   type   VcDataType is array (0 to 3) of std_logic_vector(16*TxLaneCnt-1 downto 0);
   signal intVcFrameTxData : VcDataType;
   signal intPhyTxData     : std_logic_vector(TxLaneCnt*16-1 downto 0);  -- PHY receive data
   signal intPhyTxDataK    : std_logic_vector(TxLaneCnt*2-1 downto 0);  -- PHY receive data is K character
   signal intCrcInData     : std_logic_vector(TxLaneCnt*16-1 downto 0);
   
begin

   wrap : process (intCrcInData, intPhyTxData, intPhyTxDataK, pgpVcTxQuadIn) is
   begin
      for i in 0 to TxLaneCnt-1 loop
         for j in 0 to 3 loop
            intVcFrameTxData(j)(16*i+15 downto 16*i) <= pgpVcTxQuadIn(j).data(i);
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
         PayloadCntTop => PayloadCntTop,
         NUM_VC_EN_G => NUM_VC_EN_G)
      port map (
         pgpTxClk        => pgpTxClk,
         pgpTxReset      => pgpTxReset,
         pgpTxFlush      => pgpTxIn.flush,
         pgpTxLinkReady  => pgpTxOut.linkReady,
         pgpTxOpCodeEn   => pgpTxIn.opCodeEn,
         pgpTxOpCode     => pgpTxIn.opCode,
         pgpLocLinkReady => pgpTxIn.locLinkReady,
         pgpLocData      => pgpTxIn.locData,
         vc0FrameTxValid => pgpVcTxQuadIn(0).valid,
         vc0FrameTxReady => pgpVcTxQuadOut(0).ready,
         vc0FrameTxSOF   => pgpVcTxQuadIn(0).sof,
         vc0FrameTxEOF   => pgpVcTxQuadIn(0).eof,
         vc0FrameTxEOFE  => pgpVcTxQuadIn(0).eofe,
         vc0FrameTxData  => intVcFrameTxData(0),
         vc0LocBuffAFull => pgpVcTxQuadIn(0).LocBuffAFull,
         vc0LocBuffFull  => pgpVcTxQuadIn(0).locBuffFull,
         vc1FrameTxValid => pgpVcTxQuadIn(1).valid,
         vc1FrameTxReady => pgpVcTxQuadOut(1).ready,
         vc1FrameTxSOF   => pgpVcTxQuadIn(1).sof,
         vc1FrameTxEOF   => pgpVcTxQuadIn(1).eof,
         vc1FrameTxEOFE  => pgpVcTxQuadIn(1).eofe,
         vc1FrameTxData  => intVcFrameTxData(1),
         vc1LocBuffAFull => pgpVcTxQuadIn(1).locBuffAFull,
         vc1LocBuffFull  => pgpVcTxQuadIn(1).LocBuffFull,
         vc2FrameTxValid => pgpVcTxQuadIn(2).valid,
         vc2FrameTxReady => pgpVcTxQuadOut(2).ready,
         vc2FrameTxSOF   => pgpVcTxQuadIn(2).sof,
         vc2FrameTxEOF   => pgpVcTxQuadIn(2).eof,
         vc2FrameTxEOFE  => pgpVcTxQuadIn(2).eofe,
         vc2FrameTxData  => intVcFrameTxData(2),
         vc2LocBuffAFull => pgpVcTxQuadIn(2).LocBuffAFull,
         vc2LocBuffFull  => pgpVcTxQuadIn(2).locBuffFull,
         vc3FrameTxValid => pgpVcTxQuadIn(3).valid,
         vc3FrameTxReady => pgpVcTxQuadOut(3).ready,
         vc3FrameTxSOF   => pgpVcTxQuadIn(3).sof,
         vc3FrameTxEOF   => pgpVcTxQuadIn(3).eof,
         vc3FrameTxEOFE  => pgpVcTxQuadIn(3).eofe,
         vc3FrameTxData  => intVcFrameTxData(3),
         vc3LocBuffAFull => pgpVcTxQuadIn(3).locBuffAFull,
         vc3LocBuffFull  => pgpVcTxQuadIn(3).LocBuffFull,
         phyTxData       => intPhyTxData,
         phyTxDataK      => intPhyTxDataK,
         phyTxReady      => phyTxReady,
         crcTxIn         => intCrcInData,
         crcTxInit       => crcTxIn.init,
         crcTxValid      => crcTxIn.valid,
         crcTxOut        => crcTxOut,
         debug           => debug);

end architecture rtl;
