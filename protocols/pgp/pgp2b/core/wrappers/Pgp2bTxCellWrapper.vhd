-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-- Description: Cocotb-facing wrapper for surf.Pgp2bTxCell
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library surf;
use surf.StdRtlPkg.all;

entity Pgp2bTxCellWrapper is
   port (
      clk              : in  sl;
      rst              : in  sl;
      pgpTxLinkReady   : in  sl               := '1';
      schTxIdle        : in  sl               := '0';
      schTxReq         : in  sl               := '0';
      schTxTimeout     : in  sl               := '0';
      schTxDataVc      : in  slv(1 downto 0)  := (others => '0');
      vc0FrameTxValid  : in  sl               := '0';
      vc0FrameTxSOF    : in  sl               := '0';
      vc0FrameTxEOF    : in  sl               := '0';
      vc0FrameTxEOFE   : in  sl               := '0';
      vc0FrameTxData   : in  slv(15 downto 0) := (others => '0');
      vc0LocAlmostFull : in  sl               := '0';
      vc0LocOverflow   : in  sl               := '0';
      vc0RemAlmostFull : in  sl               := '0';
      cellTxSOC        : out sl;
      cellTxSOF        : out sl;
      cellTxEOC        : out sl;
      cellTxEOF        : out sl;
      cellTxEOFE       : out sl;
      cellTxData       : out slv(15 downto 0);
      schTxAck         : out sl;
      crcTxIn          : out slv(15 downto 0);
      crcTxInit        : out sl;
      crcTxValid       : out sl);
end entity Pgp2bTxCellWrapper;

architecture rtl of Pgp2bTxCellWrapper is

begin

   U_DUT : entity surf.Pgp2bTxCell
      generic map (
         TX_LANE_CNT_G => 1)
      port map (
         pgpTxClk       => clk,
         pgpTxClkRst    => rst,
         pgpTxLinkReady => pgpTxLinkReady,
         cellTxSOC       => cellTxSOC,
         cellTxSOF       => cellTxSOF,
         cellTxEOC       => cellTxEOC,
         cellTxEOF       => cellTxEOF,
         cellTxEOFE      => cellTxEOFE,
         cellTxData      => cellTxData,
         schTxIdle       => schTxIdle,
         schTxReq        => schTxReq,
         schTxAck        => schTxAck,
         schTxTimeout    => schTxTimeout,
         schTxDataVc     => schTxDataVc,
         vc0FrameTxValid => vc0FrameTxValid,
         vc0FrameTxSOF   => vc0FrameTxSOF,
         vc0FrameTxEOF   => vc0FrameTxEOF,
         vc0FrameTxEOFE  => vc0FrameTxEOFE,
         vc0FrameTxData  => vc0FrameTxData,
         vc0LocAlmostFull => vc0LocAlmostFull,
         vc0LocOverflow   => vc0LocOverflow,
         vc0RemAlmostFull => vc0RemAlmostFull,
         vc1FrameTxValid  => '0',
         vc1FrameTxSOF    => '0',
         vc1FrameTxEOF    => '0',
         vc1FrameTxEOFE   => '0',
         vc1FrameTxData   => (others => '0'),
         vc1LocAlmostFull => '0',
         vc1LocOverflow   => '0',
         vc1RemAlmostFull => '0',
         vc2FrameTxValid  => '0',
         vc2FrameTxSOF    => '0',
         vc2FrameTxEOF    => '0',
         vc2FrameTxEOFE   => '0',
         vc2FrameTxData   => (others => '0'),
         vc2LocAlmostFull => '0',
         vc2LocOverflow   => '0',
         vc2RemAlmostFull => '0',
         vc3FrameTxValid  => '0',
         vc3FrameTxSOF    => '0',
         vc3FrameTxEOF    => '0',
         vc3FrameTxEOFE   => '0',
         vc3FrameTxData   => (others => '0'),
         vc3LocAlmostFull => '0',
         vc3LocOverflow   => '0',
         vc3RemAlmostFull => '0',
         crcTxIn          => crcTxIn,
         crcTxInit        => crcTxInit,
         crcTxValid       => crcTxValid,
         crcTxOut         => (others => '0'));

end architecture rtl;
