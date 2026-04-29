-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for PGP4 RX protocol and depacketizer
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
use surf.AxiStreamPacketizer2Pkg.all;
use surf.SsiPkg.all;
use surf.Pgp4Pkg.all;

entity Pgp4RxProtocolDepacketizerWrapper is
   port (
      clk          : in  sl;
      rst          : in  sl;
      phyRxActive  : in  sl := '1';
      protRxValid  : in  sl;
      protRxHeader : in  slv(1 downto 0);
      protRxData   : in  slv(63 downto 0);
      rxReady      : in  sl := '1';
      linkReady    : out sl;
      frameRx      : out sl;
      frameRxErr   : out sl;
      linkError    : out sl;
      rxValid      : out sl;
      rxLast       : out sl;
      rxData       : out slv(63 downto 0);
      rxUser       : out slv(15 downto 0));
end entity Pgp4RxProtocolDepacketizerWrapper;

architecture rtl of Pgp4RxProtocolDepacketizerWrapper is

   signal pgpRxOut              : Pgp4RxOutType       := PGP4_RX_OUT_INIT_C;
   signal pgpRawRxMaster        : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal pgpRawRxSlave         : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal depacketizedRxMaster  : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal depacketizedRxSlave   : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal depacketizerDebug     : Packetizer2DebugType;
   signal remRxFifoCtrl         : AxiStreamCtrlArray(0 downto 0);
   signal remRxLinkReady        : sl;
   signal locRxLinkReady        : sl;

begin

   linkReady  <= pgpRxOut.linkReady;
   linkError  <= pgpRxOut.linkError;
   frameRx    <= depacketizerDebug.eof;
   frameRxErr <= depacketizerDebug.eofe;
   rxValid    <= depacketizedRxMaster.tValid;
   rxLast     <= depacketizedRxMaster.tLast;
   rxData     <= depacketizedRxMaster.tData(63 downto 0);
   rxUser     <= depacketizedRxMaster.tUser(15 downto 0);

   depacketizedRxSlave.tReady <= rxReady;

   U_Pgp4RxProtocol : entity surf.Pgp4RxProtocol
      generic map (
         NUM_VC_G => 1)
      port map (
         pgpRxClk       => clk,
         pgpRxRst       => rst,
         pgpRxIn        => PGP4_RX_IN_INIT_C,
         pgpRxOut       => pgpRxOut,
         pgpRxMaster    => pgpRawRxMaster,
         pgpRxSlave     => pgpRawRxSlave,
         remRxFifoCtrl  => remRxFifoCtrl,
         remRxLinkReady => remRxLinkReady,
         locRxLinkReady => locRxLinkReady,
         linkError      => '0',
         phyRxActive    => phyRxActive,
         protRxValid    => protRxValid,
         protRxPhyInit  => open,
         protRxData     => protRxData,
         protRxHeader   => protRxHeader);

   U_AxiStreamDepacketizer2 : entity surf.AxiStreamDepacketizer2
      generic map (
         MEMORY_TYPE_G       => "distributed",
         REG_EN_G            => false,
         CRC_PIPELINE_G      => 0,
         CRC_MODE_G          => "DATA",
         CRC_POLY_G          => PGP4_CRC_POLY_C,
         SEQ_CNT_SIZE_G      => 12,
         TDEST_BITS_G        => 0,
         INPUT_PIPE_STAGES_G => 0)
      port map (
         axisClk     => clk,
         axisRst     => rst,
         linkGood    => locRxLinkReady,
         debug       => depacketizerDebug,
         sAxisMaster => pgpRawRxMaster,
         sAxisSlave  => pgpRawRxSlave,
         mAxisMaster => depacketizedRxMaster,
         mAxisSlave  => depacketizedRxSlave);

end architecture rtl;
