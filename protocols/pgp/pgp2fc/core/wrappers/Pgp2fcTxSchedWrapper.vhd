-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for surf.Pgp2fcTxSched
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library surf;
use surf.StdRtlPkg.all;

entity Pgp2fcTxSchedWrapper is
   port (
      clk              : in  sl;
      rst              : in  sl;
      pgpTxFlush       : in  sl := '0';
      pgpTxLinkReady   : in  sl := '1';
      pgpTxBusy        : in  sl := '0';
      schTxSOF         : in  sl := '0';
      schTxEOF         : in  sl := '0';
      schTxAck         : in  sl := '0';
      vc0FrameTxValid  : in  sl := '0';
      vc0RemAlmostFull : in  sl := '0';
      schTxIdle        : out sl;
      schTxReq         : out sl;
      schTxTimeout     : out sl;
      schTxDataVc      : out slv(1 downto 0));
end entity Pgp2fcTxSchedWrapper;

architecture rtl of Pgp2fcTxSchedWrapper is

begin

   U_DUT : entity surf.Pgp2fcTxSched
      generic map (
         NUM_VC_EN_G => 1)
      port map (
         pgpTxClk         => clk,
         pgpTxClkRst      => rst,
         pgpTxFlush       => pgpTxFlush,
         pgpTxLinkReady   => pgpTxLinkReady,
         pgpTxBusy        => pgpTxBusy,
         schTxSOF         => schTxSOF,
         schTxEOF         => schTxEOF,
         schTxIdle        => schTxIdle,
         schTxReq         => schTxReq,
         schTxAck         => schTxAck,
         schTxTimeout     => schTxTimeout,
         schTxDataVc      => schTxDataVc,
         vc0FrameTxValid  => vc0FrameTxValid,
         vc1FrameTxValid  => '0',
         vc2FrameTxValid  => '0',
         vc3FrameTxValid  => '0',
         vc0RemAlmostFull => vc0RemAlmostFull,
         vc1RemAlmostFull => '0',
         vc2RemAlmostFull => '0',
         vc3RemAlmostFull => '0');

end architecture rtl;
