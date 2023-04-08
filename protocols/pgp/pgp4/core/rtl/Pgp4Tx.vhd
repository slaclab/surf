-------------------------------------------------------------------------------
-- Title      : PGPv4: https://confluence.slac.stanford.edu/x/1dzgEQ
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Pgpv4 Transmit
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

entity Pgp4Tx is
   generic (
      TPD_G                    : time                  := 1 ns;
      RST_ASYNC_G              : boolean               := false;
      -- PGP configuration
      NUM_VC_G                 : integer range 1 to 16 := 1;
      CELL_WORDS_MAX_G         : integer               := 256;  -- Number of 64-bit words per cell
      -- MUX configuration
      MUX_MODE_G               : string                := "INDEXED";  -- Or "ROUTED"
      MUX_TDEST_ROUTES_G       : Slv8Array             := (0 => "--------");  -- Only used in ROUTED mode
      MUX_TDEST_LOW_G          : integer range 0 to 7  := 0;
      MUX_ILEAVE_EN_G          : boolean               := true;
      MUX_ILEAVE_ON_NOTVALID_G : boolean               := true);
   port (
      -- Transmit interface
      pgpTxClk     : in  sl;
      pgpTxRst     : in  sl;
      pgpTxIn      : in  Pgp4TxInType := PGP4_TX_IN_INIT_C;
      pgpTxOut     : out Pgp4TxOutType;
      pgpTxMasters : in  AxiStreamMasterArray(NUM_VC_G-1 downto 0);
      pgpTxSlaves  : out AxiStreamSlaveArray(NUM_VC_G-1 downto 0);

      -- Status of receive and remote FIFOs (Asynchronous)
      locRxFifoCtrl  : in AxiStreamCtrlArray(NUM_VC_G-1 downto 0);
      locRxLinkReady : in sl;
      remRxFifoCtrl  : in AxiStreamCtrlArray(NUM_VC_G-1 downto 0);
      remRxLinkReady : in sl;

      -- PHY interface
      phyTxActive : in  sl;
      phyTxReady  : in  sl;
      phyTxValid  : out sl;
      phyTxStart  : out sl;
      phyTxData   : out slv(63 downto 0);
      phyTxHeader : out slv(1 downto 0));
end entity Pgp4Tx;

architecture rtl of Pgp4Tx is

   -- Synchronized statuses
   signal syncLocRxFifoCtrl  : AxiStreamCtrlArray(NUM_VC_G-1 downto 0);
   signal syncLocRxLinkReady : sl;
   signal syncRemRxFifoCtrl  : AxiStreamCtrlArray(NUM_VC_G-1 downto 0);
   signal syncRemRxLinkReady : sl;

   -- Pipeline signals
   signal disableSel         : slv(NUM_VC_G-1 downto 0);
   signal rearbitrate        : sl := '0';
   signal muxedTxMaster      : AxiStreamMasterType;
   signal muxedTxSlave       : AxiStreamSlaveType;
   signal packetizedTxMaster : AxiStreamMasterType;
   signal packetizedTxSlave  : AxiStreamSlaveType;

   signal phyTxActiveL : sl;
   signal protTxValid  : sl;
   signal protTxReady  : sl;
   signal protTxStart  : sl;
   signal protTxData   : slv(63 downto 0);
   signal protTxHeader : slv(1 downto 0);

begin

   -- Synchronize remote link and FIFO status to TX clock
   U_Synchronizer_REM : entity surf.Synchronizer
      generic map (
         TPD_G       => TPD_G,
         RST_ASYNC_G => RST_ASYNC_G)
      port map (
         clk     => pgpTxClk,                              -- [in]
         rst     => pgpTxRst,                              -- [in]
         dataIn  => remRxLinkReady,                        -- [in]
         dataOut => syncRemRxLinkReady);                   -- [out]
   REM_STATUS_SYNC : for i in NUM_VC_G-1 downto 0 generate
      U_SynchronizerVector_1 : entity surf.SynchronizerVector
         generic map (
            TPD_G       => TPD_G,
            RST_ASYNC_G => RST_ASYNC_G,
            WIDTH_G     => 2)
         port map (
            clk        => pgpTxClk,                        -- [in]
            rst        => pgpTxRst,                        -- [in]
            dataIn(0)  => remRxFifoCtrl(i).pause,          -- [in]
            dataIn(1)  => remRxFifoCtrl(i).overflow,       -- [in]
            dataOut(0) => syncRemRxFifoCtrl(i).pause,      -- [out]
            dataOut(1) => syncRemRxFifoCtrl(i).overflow);  -- [out]
   end generate;

   -- Synchronize local RX status
   U_Synchronizer_LOC : entity surf.Synchronizer
      generic map (
         TPD_G       => TPD_G,
         RST_ASYNC_G => RST_ASYNC_G)
      port map (
         clk     => pgpTxClk,                           -- [in]
         rst     => pgpTxRst,                           -- [in]
         dataIn  => locRxLinkReady,                     -- [in]
         dataOut => syncLocRxLinkReady);                -- [out]
   LOC_STATUS_SYNC : for i in NUM_VC_G-1 downto 0 generate
      U_Synchronizer_pause : entity surf.Synchronizer
         generic map (
            TPD_G       => TPD_G,
            RST_ASYNC_G => RST_ASYNC_G)
         port map (
            clk     => pgpTxClk,                        -- [in]
            rst     => pgpTxRst,                        -- [in]
            dataIn  => locRxFifoCtrl(i).pause,          -- [in]
            dataOut => syncLocRxFifoCtrl(i).pause);     -- [out]
      U_Synchronizer_overflow : entity surf.SynchronizerOneShot
         generic map (
            TPD_G       => TPD_G,
            RST_ASYNC_G => RST_ASYNC_G)
         port map (
            clk     => pgpTxClk,                        -- [in]
            rst     => pgpTxRst,                        -- [in]
            dataIn  => locRxFifoCtrl(i).overflow,       -- [in]
            dataOut => syncLocRxFifoCtrl(i).overflow);  -- [out]
   end generate;

   -- Use synchronized remote status to disable channels from mux selection
   -- All flow control overridden by pgpTxIn 'disable' and 'flowCntlDis'
   DISABLE_SEL : process (pgpTxIn, syncRemRxFifoCtrl) is
   begin
      for i in NUM_VC_G-1 downto 0 loop
         if (pgpTxIn.disable = '1') then
            disableSel(i) <= '1';
         elsif (pgpTxIn.flowCntlDis = '1') then
            disableSel(i) <= '0';
         else
            disableSel(i) <= syncRemRxFifoCtrl(i).pause;
         end if;
      end loop;
   end process;

   -- Multiplex the incoming TX streams with interleaving
   U_AxiStreamMux_1 : entity surf.AxiStreamMux
      generic map (
         TPD_G                => TPD_G,
         RST_ASYNC_G          => RST_ASYNC_G,
         NUM_SLAVES_G         => NUM_VC_G,
         MODE_G               => MUX_MODE_G,
         PIPE_STAGES_G        => 0,
         TDEST_LOW_G          => MUX_TDEST_LOW_G,
         ILEAVE_EN_G          => ite(NUM_VC_G > 1, MUX_ILEAVE_EN_G, false),  -- Interleave if more than 1 VC
         ILEAVE_ON_NOTVALID_G => MUX_ILEAVE_ON_NOTVALID_G,
         ILEAVE_REARB_G       => CELL_WORDS_MAX_G)
      port map (
         axisClk      => pgpTxClk,      -- [in]
         axisRst      => pgpTxRst,      -- [in]
         disableSel   => disableSel,    -- [in]
         rearbitrate  => rearbitrate,   -- [in]
         sAxisMasters => pgpTxMasters,  -- [in]
         sAxisSlaves  => pgpTxSlaves,   -- [out]
         mAxisMaster  => muxedTxMaster,  -- [out]
         mAxisSlave   => muxedTxSlave);  -- [in]

   -- Feed MUX'd stream to packetizer
   -- Note that the MUX is doing the work of chunking
   -- Packetizer applies packet formatting and CRC
   -- rearbitrate signal doesn't really do anything (yet)
   U_AxiStreamPacketizer2_1 : entity surf.AxiStreamPacketizer2
      generic map (
         TPD_G                => TPD_G,
         RST_ASYNC_G          => RST_ASYNC_G,
         CRC_MODE_G           => "DATA",
         CRC_POLY_G           => PGP4_CRC_POLY_C,
         MAX_PACKET_BYTES_G   => CELL_WORDS_MAX_G*8*2,
         SEQ_CNT_SIZE_G       => 12,
         INPUT_PIPE_STAGES_G  => 1,
         OUTPUT_PIPE_STAGES_G => 1)
      port map (
         axisClk     => pgpTxClk,            -- [in]
         axisRst     => pgpTxRst,            -- [in]
         rearbitrate => rearbitrate,         -- [out]
         sAxisMaster => muxedTxMaster,       -- [in]
         sAxisSlave  => muxedTxSlave,        -- [out]
         mAxisMaster => packetizedTxMaster,  -- [out]
         mAxisSlave  => packetizedTxSlave);  -- [in]

   -- Feed packets into PGP TX Protocol engine
   -- Translates Packetizer2 frames, status, and opcodes into unscrambled 64b66b charachters
   U_Pgp4TxProtocol_1 : entity surf.Pgp4TxProtocol
      generic map (
         TPD_G       => TPD_G,
         RST_ASYNC_G => RST_ASYNC_G,
         NUM_VC_G    => NUM_VC_G)
      port map (
         pgpTxClk       => pgpTxClk,            -- [in]
         pgpTxRst       => pgpTxRst,            -- [in]
         pgpTxIn        => pgpTxIn,             -- [in]
         pgpTxOut       => pgpTxOut,            -- [out]
         pgpTxMaster    => packetizedTxMaster,  -- [in]
         pgpTxSlave     => packetizedTxSlave,   -- [out]
         locRxFifoCtrl  => syncLocRxFifoCtrl,   -- [in]
         locRxLinkReady => syncLocRxLinkReady,  -- [in]
         remRxLinkReady => syncRemRxLinkReady,  -- [in]
         phyTxActive    => phyTxActive,         -- [in]
         protTxReady    => protTxReady,         -- [in]
         protTxValid    => protTxValid,         -- [out]
         protTxStart    => protTxStart,         -- [out]
         protTxData     => protTxData,          -- [out]
         protTxHeader   => protTxHeader);       -- [out]

   -- Scramble the data for 64b66b
   U_Scrambler_1 : entity surf.Scrambler
      generic map (
         TPD_G            => TPD_G,
         RST_ASYNC_G      => RST_ASYNC_G,
         DIRECTION_G      => "SCRAMBLER",
         DATA_WIDTH_G     => 64,
         SIDEBAND_WIDTH_G => 3,
         TAPS_G           => PGP4_SCRAMBLER_TAPS_C)
      port map (
         clk                        => pgpTxClk,      -- [in]
         rst                        => phyTxActiveL,  -- [in]
         -- Input Interface
         inputValid                 => protTxValid,   -- [in]
         inputReady                 => protTxReady,   -- [out]
         inputData                  => protTxData,    -- [in]
         inputSideband(1 downto 0)  => protTxHeader,  -- [in]
         inputSideband(2)           => protTxStart,   -- [in]
         -- Output Interface
         outputValid                => phyTxValid,    -- [out]
         outputReady                => phyTxReady,    -- [in]
         outputData                 => phyTxData,     -- [out]
         outputSideband(1 downto 0) => phyTxHeader,   -- [out]
         outputSideband(2)          => phyTxStart);   -- [out]

   phyTxActiveL <= not(phyTxActive);

end architecture rtl;
