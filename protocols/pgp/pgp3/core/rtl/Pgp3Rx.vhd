-------------------------------------------------------------------------------
-- Title      : Pgp3 Receive Block
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-04-07
-- Last update: 2017-10-04
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
use work.AxiStreamPacketizer2Pkg.all;

entity Pgp3Rx is

   generic (
      TPD_G              : time                  := 1 ns;
      NUM_VC_G           : integer range 1 to 16 := 4;
      ALIGN_GOOD_COUNT_G : integer               := 128;
      ALIGN_BAD_COUNT_G  : integer               := 16;
      ALIGN_SLIP_WAIT_G  : integer               := 32);
   port (
      -- User Transmit interface
      pgpRxClk     : in  sl;
      pgpRxRst     : in  sl;
      pgpRxIn      : in  Pgp3RxInType;
      pgpRxOut     : out Pgp3RxOutType;
      pgpRxMasters : out AxiStreamMasterArray(NUM_VC_G-1 downto 0);
      pgpRxCtrl    : in  AxiStreamCtrlArray(NUM_VC_G-1 downto 0);

      -- Status of local receive fifos
      remRxFifoCtrl  : out AxiStreamCtrlArray(NUM_VC_G-1 downto 0);
      remRxLinkReady : out sl;
      locRxLinkReady : out sl;

      -- Phy interface
      phyRxClk      : in  sl;
      phyRxRst      : in  sl;
      phyRxInit     : out sl;
      phyRxActive   : in  sl;
      phyRxValid    : in  sl;
      phyRxHeader   : in  slv(1 downto 0);
      phyRxData     : in  slv(63 downto 0);
      phyRxStartSeq : in  sl;
      phyRxSlip     : out sl);



end entity Pgp3Rx;

architecture rtl of Pgp3Rx is

   constant SCRAMBLER_TAPS_C : IntegerArray := (0 => 39, 1 => 58);

   signal gearboxAligned         : sl := '1';
   signal unscramblerValid       : sl;
   signal unscrambledValid       : sl;
   signal unscrambledData        : slv(63 downto 0);
   signal unscrambledHeader      : slv(1 downto 0);
   signal ebValid                : sl;
   signal ebData                 : slv(63 downto 0);
   signal ebHeader               : slv(1 downto 0);
   signal ebOverflow             : sl;
   signal ebStatus               : slv(8 downto 0);
   signal phyRxInitInt           : sl;
   signal pgpRawRxMaster         : AxiStreamMasterType;
   signal pgpRawRxSlave          : AxiStreamSlaveType;
   signal depacketizedAxisMaster : AxiStreamMasterType;
   signal depacketizedAxisSlave  : AxiStreamSlaveType;

   signal pgpRxOutProtocol  : Pgp3RxOutType;
   signal depacketizerDebug : Packetizer2DebugType;

   signal locRxLinkReadyInt : sl;
   signal remRxLinkReadyInt : sl;
   signal remRxFifoCtrlInt  : AxiStreamCtrlArray(NUM_VC_G-1 downto 0);

begin
   phyRxInit      <= phyRxInitInt;
   locRxLinkReady <= locRxLinkReadyInt;
   remRxLinkReady <= remRxLinkReadyInt;
   remRxFifoCtrl  <= remRxFifoCtrlInt;

   -- Gearbox aligner
   U_Pgp3RxGearboxAligner_1 : entity work.Pgp3RxGearboxAligner
      generic map (
         TPD_G        => TPD_G,
         GOOD_COUNT_G => ALIGN_GOOD_COUNT_G,
         BAD_COUNT_G  => ALIGN_BAD_COUNT_G,
         SLIP_WAIT_G  => ALIGN_SLIP_WAIT_G)
      port map (
         clk           => phyRxClk,         -- [in]
         rst           => phyRxRst,         -- [in]
         rxHeader      => phyRxHeader,      -- [in]
         rxHeaderValid => phyRxValid,       -- [in]
         slip          => phyRxSlip,        -- [out]
         locked        => gearboxAligned);  -- [out]

   -- Unscramble the data for 64b66b
   unscramblerValid <= gearboxAligned and phyRxValid;
   U_Scrambler_1 : entity work.Scrambler
      generic map (
         TPD_G            => TPD_G,
         DIRECTION_G      => "DESCRAMBLER",
         DATA_WIDTH_G     => 64,
         SIDEBAND_WIDTH_G => 2,
         TAPS_G           => SCRAMBLER_TAPS_C)
      port map (
         clk            => phyRxClk,            -- [in]
         rst            => phyRxRst,            -- [in]
         inputValid     => unscramblerValid,    -- [in]         
         inputData      => phyRxData,           -- [in]
         inputSideband  => phyRxHeader,         -- [in]
         outputValid    => unscrambledValid,    -- [out]
         outputData     => unscrambledData,     -- [out]
         outputSideband => unscrambledHeader);  -- [out]

   -- Elastic Buffer
   U_Pgp3RxEb_1 : entity work.Pgp3RxEb
      generic map (
         TPD_G => TPD_G)
      port map (
         phyRxClk    => phyRxClk,           -- [in]
         phyRxRst    => phyRxRst,           -- [in]
         phyRxValid  => unscrambledValid,   -- [in]
         phyRxData   => unscrambledData,    -- [in]
         phyRxHeader => unscrambledHeader,  -- [in]
         pgpRxClk    => pgpRxClk,           -- [in]
         pgpRxRst    => pgpRxRst,           -- [in]
         pgpRxValid  => ebValid,            -- [out]
         pgpRxData   => ebData,             -- [out]
         pgpRxHeader => ebHeader,           -- [out]
         overflow    => ebOverflow,         -- [out]
         status      => ebStatus);          -- [out]

   -- Main RX protocol logic
   U_Pgp3RxProtocol_1 : entity work.Pgp3RxProtocol
      generic map (
         TPD_G    => TPD_G,
         NUM_VC_G => NUM_VC_G)
      port map (
         pgpRxClk       => pgpRxClk,           -- [in]
         pgpRxRst       => pgpRxRst,           -- [in]
         pgpRxIn        => pgpRxIn,            -- [in]
         pgpRxOut       => pgpRxOutProtocol,   -- [out]
         pgpRxMaster    => pgpRawRxMaster,     -- [out]
         pgpRxSlave     => pgpRawRxSlave,      -- [in]
         remRxFifoCtrl  => remRxFifoCtrlInt,   -- [out]
         remRxLinkReady => remRxLinkReadyInt,  -- [out]
         locRxLinkReady => locRxLinkReadyInt,  -- [out]
         phyRxActive    => phyRxActive,        -- [in]
         protRxValid    => ebValid,            -- [in]
         protRxPhyInit  => phyRxInitInt,       -- [out]
         protRxData     => ebData,             -- [in]
         protRxHeader   => ebHeader);          -- [in]

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
         linkGood    => locRxLinkReadyInt,       -- [in]
         debug       => depacketizerDebug,       -- [out]
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

   pgpRxOut.phyRxActive    <= phyRxActive;
   pgpRxOut.linkReady      <= pgpRxOutProtocol.linkReady;
   pgpRxOut.frameRx        <= depacketizerDebug.eof;
   pgpRxOut.frameRxErr     <= depacketizerDebug.eofe;
   pgpRxOut.cellError      <= depacketizerDebug.packetError;
   pgpRxOut.opCodeEn       <= pgpRxOutProtocol.opCodeEn;
   pgpRxOut.opCodeNumber   <= pgpRxOutProtocol.opCodeNumber;
   pgpRxOut.opCodeData     <= pgpRxOutProtocol.opCodeData;
   pgpRxOut.remRxLinkReady <= remRxLinkReadyInt;

   pgpRxOut.phyRxData   <= phyRxData;
   pgpRxOut.phyRxHeader <= phyRxHeader;
   pgpRxOut.phyRxValid  <= phyRxValid;
   pgpRxOut.phyRxInit   <= phyRxInitInt;

   pgpRxOut.gearboxAligned <= gearboxAligned;

   pgpRxOut.ebData     <= ebData;
   pgpRxOut.ebHeader   <= ebHeader;
   pgpRxOut.ebValid    <= ebValid;
   pgpRxOut.ebOverflow <= ebOverflow;
   pgpRxOut.ebStatus   <= ebStatus;


   CTRL_OUT : for i in 15 downto 0 generate
      USED : if (i < NUM_VC_G) generate
         pgpRxOut.remRxOverflow(i) <= remRxFifoCtrlInt(i).overflow;
         pgpRxOut.remRxPause(i)    <= remRxFifoCtrlInt(i).pause;
      end generate;
      UNUSED : if (i >= NUM_VC_G) generate
         pgpRxOut.remRxOverflow(i) <= '0';
         pgpRxOut.remRxPause(i)    <= '0';
      end generate;
   end generate;


end architecture rtl;
