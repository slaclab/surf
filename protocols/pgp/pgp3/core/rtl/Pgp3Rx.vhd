-------------------------------------------------------------------------------
-- Title      : Pgp3 Receive Block
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-04-07
-- Last update: 2017-04-11
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of SURF. It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of SURF, including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.Pgp3Pkg.all;

entity Pgp3Rx is

   generic (
      TPD_G    : time                  := 1 ns;
      NUM_VC_G : integer range 1 to 16 := 4);
   port (
      -- User Transmit interface
      pgpRxClk    : in  sl;
      pgpRxRst    : in  sl;
      pgpRxIn     : in  Pgp3RxInType;
      pgpRxOut    : out Pgp3RxOutType;
      pgpRxMasters : out AxiStreamMasterArray(NUM_VC_G-1 downto 0);
      pgpRxCtrl   : in  AxiStreamCtrlArray(NUM_VC_G-1 downto 0);

      -- Status of local receive fifos
      -- Should these all be on pgpRxOut?
      remRxFifoCtrl  : out AxiStreamCtrlArray(NUM_VC_G-1 downto 0);
      remRxLinkReady : out sl;
      locRxLinkReady : out sl;

      -- Phy interface
      phyRxClk         : in  sl;
      phyRxHeaderValid : in  sl;
      phyRxHeader      : in  slv(1 downto 0);
      phyRxDataValid   : in  slv(1 downto 0);
      phyRxData        : in  slv(63 downto 0);
      phyRxStartSeq    : in  sl;
      phyRxSlip        : out sl);



end entity Pgp3Rx;

architecture rtl of Pgp3Rx is

   signal gearboxAligned         : sl := '1';
   signal unscramblerValid       : sl;
   signal unscrambledData        : slv(63 downto 0);
   signal unscrambedHeader       : slv(1 downto 0);
   signal pgpRawRxMaster         : AxiStreamMasterType;
   signal pgpRawRxSlave          : AxiStreamSlaveType;
   signal depacketizedAxisMaster : AxiStreamMasterType;
   signal depacketizedAxisSlave  : AxiStreamSlaveType;

begin

   -- Gearbox aligner

   -- Unscramble the data for 64b66b
   U_Scrambler_1 : entity work.Scrambler
      generic map (
         TPD_G            => TPD_G,
         DIRECTION_G      => "DESCRAMBLER",
         DATA_WIDTH_G     => 64,
         SIDEBAND_WIDTH_G => 2,
         TAPS_G           => SCRAMBLER_TAPS_C)
      port map (
         clk         => pgpRxClk,           -- [in]
         rst         => '0',                -- [in]
         inputEn     => gearboxAligned,     -- [in]         
         dataIn      => phyRxData,          -- [in]
         sidebandIn  => phyRxHeader,        -- [in]
         outputValid => unscramblerValid,   -- [out]
         dataOut     => unscrambledData,    -- [out]
         sidebandOut => unscrambedHeader);  -- [out]

   -- Elastic Buffer

   -- Main RX protocol logic
   U_Pgp3RxProtocol_1 : entity work.Pgp3RxProtocol
      generic map (
         TPD_G    => TPD_G,
         NUM_VC_G => NUM_VC_G)
      port map (
         pgpRxClk       => pgpRxClk,           -- [in]
         pgpRxRst       => pgpRxRst,           -- [in]
         pgpRxIn        => pgpRxIn,            -- [in]
         pgpRxOut       => pgpRxOut,           -- [out]
         pgpRxMaster    => pgpRawRxMaster,     -- [out]
         pgpRxSlave     => pgpRawRxSlave,      -- [in]
         remRxFifoCtrl  => remRxFifoCtrl,      -- [out]
         remRxLinkReady => remRxLinkReady,     -- [out]
         locRxLinkReady => locRxLinkReady,     -- [out]
         phyRxValid     => unscramblerValid,   -- [in]
         phyRxData      => unscrambledData,    -- [in]
         phyRxHeader    => unscrambedHeader);  -- [in]

   -- Depacketize the RX data frames
   U_AxiStreamDepacketizer2_1 : entity work.AxiStreamDepacketizer2
      generic map (
         TPD_G               => TPD_G,
         CRC_EN_G            => true,
--       CRC_POLY_G           => CRC_POLY_G,
         INPUT_PIPE_STAGES_G => 0)
      port map (
         axisClk     => pgpRxClk,                -- [in]
         axisRst     => pgpRxRst,                -- [in]
         sAxisMaster => pgpRawRxMaster,          -- [in]
         sAxisSlave  => pgpRawRxSlave,           -- [out]
         mAxisMaster => depacketizedAxisMaster,  -- [out]
         mAxisSlave  => depacketizedAxisSlave);  -- [in]

   -- Demultiplex the depacketized streams
   U_AxiStreamDeMux_1 : entity work.AxiStreamDeMux
      generic map (
         TPD_G         => TPD_G,
         NUM_MASTERS_G => NUM_VC_G,
         MODE_G        => "INDEXED",
--       TDEST_ROUTES_G => DEMUX_ROUTES_G,
         PIPE_STAGES_G => 0,
         TDEST_HIGH_G  => 7,                                     -- Maybe 3?
         TDEST_LOW_G   => 0)
      port map (
         axisClk      => pgpRxClk,                               -- [in]
         axisRst      => pgpRxRst,                               -- [in]
         sAxisMaster  => depacketizedAxisMaster,                 -- [in]
         sAxisSlave   => depacketizedAxisSlave,                  -- [out]
         mAxisMasters => pgpRxMasters,                           -- [out]
         mAxisSlaves  => (others => AXI_STREAM_SLAVE_FORCE_C));  -- [in]

end architecture rtl;
