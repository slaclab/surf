-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for surf.Pgp4RxProtocol
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SLAC Firmware Standard Library', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.Pgp4Pkg.all;

entity Pgp4RxProtocolWrapper is
   port (
      clk            : in  sl;
      rst            : in  sl;
      phyRxActive    : in  sl := '1';
      linkErrorIn    : in  sl := '0';
      resetRx        : in  sl := '0';
      protRxValid    : in  sl;
      protRxHeader   : in  slv(1 downto 0);
      protRxData     : in  slv(63 downto 0);
      pktReady       : in  sl := '1';
      linkReady      : out sl;
      linkDown       : out sl;
      linkErrorOut   : out sl;
      phyRxInit      : out sl;
      opCodeEn       : out sl;
      opCodeData     : out slv(47 downto 0);
      remRxLinkReady : out sl;
      remPause       : out sl;
      remOverflow    : out sl;
      pktValid       : out sl;
      pktLast        : out sl;
      pktData        : out slv(63 downto 0);
      pktDest        : out slv(7 downto 0);
      pktUser        : out slv(15 downto 0));
end entity Pgp4RxProtocolWrapper;

architecture rtl of Pgp4RxProtocolWrapper is

   signal pgpRxIn       : Pgp4RxInType        := PGP4_RX_IN_INIT_C;
   signal pgpRxOut      : Pgp4RxOutType       := PGP4_RX_OUT_INIT_C;
   signal pgpRxMaster   : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal pgpRxSlave    : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal remRxFifoCtrl : AxiStreamCtrlArray(0 downto 0);
   signal remReady      : sl;
   signal locReady      : sl;

begin

   pgpRxIn.resetRx <= resetRx;

   linkReady      <= pgpRxOut.linkReady;
   linkDown       <= pgpRxOut.linkDown;
   linkErrorOut   <= pgpRxOut.linkError;
   opCodeEn       <= pgpRxOut.opCodeEn;
   opCodeData     <= pgpRxOut.opCodeData;
   remRxLinkReady <= remReady;
   remPause       <= remRxFifoCtrl(0).pause;
   remOverflow    <= remRxFifoCtrl(0).overflow;

   pktValid <= pgpRxMaster.tValid;
   pktLast  <= pgpRxMaster.tLast;
   pktData  <= pgpRxMaster.tData(63 downto 0);
   pktDest  <= pgpRxMaster.tDest(7 downto 0);
   pktUser  <= pgpRxMaster.tUser(15 downto 0);

   pgpRxSlave.tReady <= pktReady;

   U_DUT : entity surf.Pgp4RxProtocol
      generic map (
         NUM_VC_G => 1)
      port map (
         pgpRxClk       => clk,
         pgpRxRst       => rst,
         pgpRxIn        => pgpRxIn,
         pgpRxOut       => pgpRxOut,
         pgpRxMaster    => pgpRxMaster,
         pgpRxSlave     => pgpRxSlave,
         remRxFifoCtrl  => remRxFifoCtrl,
         remRxLinkReady => remReady,
         locRxLinkReady => locReady,
         linkError      => linkErrorIn,
         phyRxActive    => phyRxActive,
         protRxValid    => protRxValid,
         protRxPhyInit  => phyRxInit,
         protRxData     => protRxData,
         protRxHeader   => protRxHeader);

end architecture rtl;
