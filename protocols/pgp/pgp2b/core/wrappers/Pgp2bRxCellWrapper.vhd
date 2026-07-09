-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-- Description: Cocotb-facing wrapper for surf.Pgp2bRxCell
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library surf;
use surf.StdRtlPkg.all;

entity Pgp2bRxCellWrapper is
   port (
      clk              : in  sl;
      rst              : in  sl;
      pgpRxFlush       : in  sl               := '0';
      pgpRxLinkReady   : in  sl               := '1';
      cellRxPause      : in  sl               := '0';
      cellRxSOC        : in  sl               := '0';
      cellRxSOF        : in  sl               := '0';
      cellRxEOC        : in  sl               := '0';
      cellRxEOF        : in  sl               := '0';
      cellRxEOFE       : in  sl               := '0';
      cellRxData       : in  slv(15 downto 0) := (others => '0');
      pgpRxCellError   : out sl;
      vcFrameRxSOF     : out sl;
      vcFrameRxEOF     : out sl;
      vcFrameRxEOFE    : out sl;
      vcFrameRxData    : out slv(15 downto 0);
      vc0FrameRxValid  : out sl;
      vc0RemAlmostFull : out sl;
      vc0RemOverflow   : out sl;
      crcRxIn          : out slv(15 downto 0);
      crcRxInit        : out sl;
      crcRxValid       : out sl;
      crcRxOut         : in  slv(31 downto 0) := (others => '0'));
end entity Pgp2bRxCellWrapper;

architecture rtl of Pgp2bRxCellWrapper is

begin

   U_DUT : entity surf.Pgp2bRxCell
      generic map (
         RX_LANE_CNT_G => 1)
      port map (
         pgpRxClk         => clk,
         pgpRxClkRst      => rst,
         pgpRxFlush       => pgpRxFlush,
         pgpRxLinkReady   => pgpRxLinkReady,
         cellRxPause      => cellRxPause,
         cellRxSOC        => cellRxSOC,
         cellRxSOF        => cellRxSOF,
         cellRxEOC        => cellRxEOC,
         cellRxEOF        => cellRxEOF,
         cellRxEOFE       => cellRxEOFE,
         cellRxData       => cellRxData,
         pgpRxCellError   => pgpRxCellError,
         vcFrameRxSOF     => vcFrameRxSOF,
         vcFrameRxEOF     => vcFrameRxEOF,
         vcFrameRxEOFE    => vcFrameRxEOFE,
         vcFrameRxData    => vcFrameRxData,
         vc0FrameRxValid  => vc0FrameRxValid,
         vc0RemAlmostFull => vc0RemAlmostFull,
         vc0RemOverflow   => vc0RemOverflow,
         vc1FrameRxValid  => open,
         vc1RemAlmostFull => open,
         vc1RemOverflow   => open,
         vc2FrameRxValid  => open,
         vc2RemAlmostFull => open,
         vc2RemOverflow   => open,
         vc3FrameRxValid  => open,
         vc3RemAlmostFull => open,
         vc3RemOverflow   => open,
         crcRxIn          => crcRxIn,
         crcRxInit        => crcRxInit,
         crcRxValid       => crcRxValid,
         crcRxOut         => crcRxOut);

end architecture rtl;
