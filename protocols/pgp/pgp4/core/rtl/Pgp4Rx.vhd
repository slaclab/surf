-------------------------------------------------------------------------------
-- Title      : PGPv4: https://confluence.slac.stanford.edu/x/1dzgEQ
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PGPv4 Receive Block
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;
use surf.Pgp4Pkg.all;
use surf.AxiStreamPacketizer2Pkg.all;

entity Pgp4Rx is
   generic (
      TPD_G              : time                  := 1 ns;
      RST_ASYNC_G        : boolean               := false;
      NUM_VC_G           : integer range 1 to 16 := 4;
      SKIP_EN_G          : boolean               := true;  -- TRUE for Elastic Buffer
      LITE_EN_G          : boolean               := false; -- TRUE: Lite does NOT support SOC/EOC
      ALIGN_SLIP_WAIT_G  : integer               := 32);
   port (
      -- User Transmit interface
      pgpRxClk     : in  sl;
      pgpRxRst     : in  sl;
      pgpRxIn      : in  Pgp4RxInType := PGP4_RX_IN_INIT_C;
      pgpRxOut     : out Pgp4RxOutType;
      pgpRxMasters : out AxiStreamMasterArray(NUM_VC_G-1 downto 0);
      pgpRxCtrl    : in  AxiStreamCtrlArray(NUM_VC_G-1 downto 0); -- Unused

      -- Status of local receive fifos
      remRxFifoCtrl  : out AxiStreamCtrlArray(NUM_VC_G-1 downto 0);
      remRxLinkReady : out sl;
      locRxLinkReady : out sl;

      -- PHY interface
      phyRxClk      : in  sl;
      phyRxRst      : in  sl;
      phyRxInit     : out sl;
      phyRxActive   : in  sl;
      phyRxValid    : in  sl;
      phyRxHeader   : in  slv(1 downto 0);
      phyRxData     : in  slv(63 downto 0);
      phyRxStartSeq : in  sl;
      phyRxSlip     : out sl);
end entity Pgp4Rx;

architecture rtl of Pgp4Rx is

   constant SCRAMBLER_TAPS_C : IntegerArray := (0 => 39, 1 => 58);

   signal gearboxAligned         : sl := '1';
   signal unscramblerValid       : sl;
   signal unscrambledValid       : sl;
   signal unscrambledData        : slv(63 downto 0);
   signal unscrambledHeader      : slv(1 downto 0);
   signal remLinkData            : slv(47 downto 0);
   signal ebValid                : sl;
   signal ebData                 : slv(63 downto 0);
   signal ebHeader               : slv(1 downto 0);
   signal ebOverflow             : sl;
   signal linkError              : sl;
   signal ebStatus               : slv(8 downto 0);
   signal phyRxInitInt           : sl;
   signal pgpRawRxMaster         : AxiStreamMasterType;
   signal pgpRawRxSlave          : AxiStreamSlaveType;
   signal depacketizedAxisMaster : AxiStreamMasterType;
   signal depacketizedAxisSlave  : AxiStreamSlaveType;

   signal pgpRxOutProtocol  : Pgp4RxOutType;
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
   U_Pgp3RxGearboxAligner_1 : entity surf.Pgp3RxGearboxAligner -- Same RX gearbox aligner as PGPv3
      generic map (
         TPD_G        => TPD_G,
         RST_ASYNC_G  => RST_ASYNC_G,
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
   U_Scrambler_1 : entity surf.Scrambler
      generic map (
         TPD_G            => TPD_G,
         RST_ASYNC_G      => RST_ASYNC_G,
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

   GEN_EB : if (SKIP_EN_G = true) generate
      -- Elastic Buffer
      U_Pgp4RxEb_1 : entity surf.Pgp4RxEb
         generic map (
            TPD_G       => TPD_G,
            RST_ASYNC_G => RST_ASYNC_G)
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
            remLinkData => remLinkData,        -- [out]
            overflow    => ebOverflow,         -- [out]
            linkError   => linkError,          -- [out]
            status      => ebStatus);          -- [out]
   end generate GEN_EB;
   NO_EB : if (SKIP_EN_G = false) generate
      ebValid  <= unscrambledValid;
      ebHeader <= unscrambledHeader;
      ebData   <= unscrambledData;
   end generate NO_EB;

   -- Main RX protocol logic
   U_Pgp4RxProtocol_1 : entity surf.Pgp4RxProtocol
      generic map (
         TPD_G       => TPD_G,
         RST_ASYNC_G => RST_ASYNC_G,
         NUM_VC_G    => NUM_VC_G)
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
         linkError      => linkError,          -- [in]
         phyRxActive    => phyRxActive,        -- [in]
         protRxValid    => ebValid,            -- [in]
         protRxPhyInit  => phyRxInitInt,       -- [out]
         protRxData     => ebData,             -- [in]
         protRxHeader   => ebHeader);          -- [in]

   -- Depacketize the RX data frames
   U_AxiStreamDepacketizer2_1 : entity surf.AxiStreamDepacketizer2
      generic map (
         TPD_G               => TPD_G,
         RST_ASYNC_G         => RST_ASYNC_G,
         MEMORY_TYPE_G       => "distributed",
         CRC_MODE_G          => "DATA",
         CRC_POLY_G          => PGP4_CRC_POLY_C,
         SEQ_CNT_SIZE_G      => ite(LITE_EN_G,0,12),-- ZERO: Pgp4TxLite does NOT support SOC/EOC
         TDEST_BITS_G        => ite(NUM_VC_G=1,0,bitSize(NUM_VC_G)),
         INPUT_PIPE_STAGES_G => 1)
      port map (
         axisClk     => pgpRxClk,                -- [in]
         axisRst     => pgpRxRst,                -- [in]
         linkGood    => locRxLinkReadyInt,       -- [in]
         debug       => depacketizerDebug,       -- [out]
         sAxisMaster => pgpRawRxMaster,          -- [in]
         sAxisSlave  => pgpRawRxSlave,           -- [out]
         mAxisMaster => depacketizedAxisMaster,  -- [out]
         mAxisSlave  => depacketizedAxisSlave);  -- [in]

   GEN_DEMUX : if (NUM_VC_G > 1) generate
      -- Demultiplex the depacketized streams
      U_AxiStreamDeMux_1 : entity surf.AxiStreamDeMux
         generic map (
            TPD_G         => TPD_G,
            RST_ASYNC_G   => RST_ASYNC_G,
            NUM_MASTERS_G => NUM_VC_G,
            MODE_G        => "INDEXED",
            PIPE_STAGES_G => 0,
            TDEST_HIGH_G  => 7,
            TDEST_LOW_G   => 0)
         port map (
            axisClk      => pgpRxClk,                               -- [in]
            axisRst      => pgpRxRst,                               -- [in]
            sAxisMaster  => depacketizedAxisMaster,                 -- [in]
            sAxisSlave   => depacketizedAxisSlave,                  -- [out]
            mAxisMasters => pgpRxMasters,                           -- [out]
            mAxisSlaves  => (others => AXI_STREAM_SLAVE_FORCE_C));  -- [in]
   end generate GEN_DEMUX;

   NO_DEMUX : if (NUM_VC_G = 1) generate
      pgpRxMasters(0)       <= depacketizedAxisMaster;
      depacketizedAxisSlave <= AXI_STREAM_SLAVE_FORCE_C;
   end generate NO_DEMUX;

   pgpRxOut.phyRxActive    <= phyRxActive;
   pgpRxOut.linkReady      <= pgpRxOutProtocol.linkReady;
   pgpRxOut.frameRx        <= depacketizerDebug.eof;
   pgpRxOut.frameRxErr     <= depacketizerDebug.eofe;

   pgpRxOut.cellError        <= depacketizerDebug.packetError;
   pgpRxOut.cellSofError     <= depacketizerDebug.sofError;
   pgpRxOut.cellSeqError     <= depacketizerDebug.seqError;
   pgpRxOut.cellVersionError <= depacketizerDebug.versionError;
   pgpRxOut.cellCrcModeError <= depacketizerDebug.crcModeError;
   pgpRxOut.cellCrcError     <= depacketizerDebug.crcError;
   pgpRxOut.cellEofeError    <= depacketizerDebug.eofeError;

   pgpRxOut.opCodeEn       <= pgpRxOutProtocol.opCodeEn;
   pgpRxOut.opCodeData     <= pgpRxOutProtocol.opCodeData;
   pgpRxOut.remLinkData    <= remLinkData;
   pgpRxOut.remRxLinkReady <= remRxLinkReadyInt;

   pgpRxOut.phyRxInit      <= phyRxInitInt;
   pgpRxOut.gearboxAligned <= gearboxAligned;
   pgpRxOut.ebOverflow     <= ebOverflow;

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
