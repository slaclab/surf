-------------------------------------------------------------------------------
-- Title      : Pgp3 Transmit
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-03-30
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of <PROJECT_NAME>. It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of <PROJECT_NAME>, including this file, may be
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

entity Pgp3Tx is

   generic (
      TPD_G                    : time                  := 1 ns;
      -- PGP configuration
      NUM_VC_G                 : integer range 1 to 16 := 1;
      CELL_WORDS_MAX_G         : integer               := 256;  -- Number of 64-bit words per cell
      SKP_INTERVAL_G           : integer               := 5000;
      SKP_BURST_SIZE_G         : integer               := 8;
      -- Mux configuration
      MUX_MODE_G               : string                := "INDEXED";  -- Or "ROUTED"
      MUX_TDEST_ROUTES_G       : Slv8Array             := (0 => "--------");  -- Only used in ROUTED mode
      MUX_TDEST_LOW_G          : integer range 0 to 7  := 0;
      MUX_ILEAVE_EN_G          : boolean               := true;
      MUX_ILEAVE_ON_NOTVALID_G : boolean               := true);
   port (
      -- Transmit interface
      pgpTxClk     : in  sl;
      pgpTxRst     : in  sl;
      pgpTxIn      : in  Pgp3TxInType;
      pgpTxOut     : out Pgp3TxOutType;
      pgpTxMasters : in  AxiStreamMasterArray(NUM_VC_G-1 downto 0);
      pgpTxSlaves  : out AxiStreamSlaveArray(NUM_VC_G-1 downto 0);

      -- Status of receive and remote FIFOs (Asynchronous)
      locRxFifoCtrl  : in AxiStreamCtrlArray(NUM_VC_G-1 downto 0);
      locRxLinkReady : in sl;
      remRxFifoCtrl  : in AxiStreamCtrlArray(NUM_VC_G-1 downto 0);
      remRxLinkReady : in sl;

      -- PHY interface
      phyTxActive   : in  sl;
      phyTxReady    : in  sl;
      phyTxStart    : out sl;
      phyTxSequence : out slv(5 downto 0);
      phyTxData     : out slv(63 downto 0);
      phyTxHeader   : out slv(1 downto 0));

end entity Pgp3Tx;

architecture rtl of Pgp3Tx is

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

   signal protTxValid    : sl;
   signal protTxReady    : sl;
   signal protTxSequence : slv(5 downto 0);
   signal protTxStart    : sl;
   signal protTxData     : slv(63 downto 0);
   signal protTxHeader   : slv(1 downto 0);

begin

   -- Synchronize remote link and fifo status to tx clock
   U_Synchronizer_REM : entity work.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => pgpTxClk,                              -- [in]
         rst     => pgpTxRst,                              -- [in]
         dataIn  => remRxLinkReady,                        -- [in]
         dataOut => syncRemRxLinkReady);                   -- [out]
   REM_STATUS_SYNC : for i in NUM_VC_G-1 downto 0 generate
      U_SynchronizerVector_1 : entity work.SynchronizerVector
         generic map (
            TPD_G   => TPD_G,
            WIDTH_G => 2)
         port map (
            clk        => pgpTxClk,                        -- [in]
            rst        => pgpTxRst,                        -- [in]
            dataIn(0)  => remRxFifoCtrl(i).pause,          -- [in]
            dataIn(1)  => remRxFifoCtrl(i).overflow,       -- [in]
            dataOut(0) => syncRemRxFifoCtrl(i).pause,      -- [out]
            dataOut(1) => syncRemRxFifoCtrl(i).overflow);  -- [out]
   end generate;

   -- Synchronize local rx status
   U_Synchronizer_LOC : entity work.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => pgpTxClk,                              -- [in]
         rst     => pgpTxRst,                              -- [in]
         dataIn  => locRxLinkReady,                        -- [in]
         dataOut => syncLocRxLinkReady);                   -- [out]
   LOC_STATUS_SYNC : for i in NUM_VC_G-1 downto 0 generate
      U_SynchronizerVector_1 : entity work.SynchronizerVector
         generic map (
            TPD_G   => TPD_G,
            WIDTH_G => 2)
         port map (
            clk        => pgpTxClk,                        -- [in]
            rst        => pgpTxRst,                        -- [in]
            dataIn(0)  => locRxFifoCtrl(i).pause,          -- [in]
            dataIn(1)  => locRxFifoCtrl(i).overflow,       -- [in]
            dataOut(0) => syncLocRxFifoCtrl(i).pause,      -- [out]
            dataOut(1) => syncLocRxFifoCtrl(i).overflow);  -- [out]
   end generate;

   -- Use synchronized remote status to disable channels from mux selection
   -- All flow control overriden by pgpTxIn 'disable' and 'flowCntlDis'
   DISABLE_SEL : process (pgpTxIn, syncRemRxFifoCtrl) is
   begin
      for i in NUM_VC_G-1 downto 0 loop
         if (pgpTxIn.disable = '1') then
            disableSel(i) <= '1';
         elsif (pgpTxIn.flowCntlDis = '1') then
            disableSel(i) <= '0';
         else
            disableSel(i) <= syncRemRxFifoCtrl(i).pause or syncRemRxFifoCtrl(i).overflow;
         end if;
      end loop;
   end process;

   -- Multiplex the incomming tx streams with interleaving
   U_AxiStreamMux_1 : entity work.AxiStreamMux
      generic map (
         TPD_G                => TPD_G,
         NUM_SLAVES_G         => NUM_VC_G,
         MODE_G               => MUX_MODE_G,
         PIPE_STAGES_G        => 0,
         TDEST_LOW_G          => MUX_TDEST_LOW_G,
         ILEAVE_EN_G          => MUX_ILEAVE_EN_G,
         ILEAVE_ON_NOTVALID_G => MUX_ILEAVE_ON_NOTVALID_G,
         ILEAVE_REARB_G       => CELL_WORDS_MAX_G)
      port map (
         axisClk      => pgpTxClk,       -- [in]
         axisRst      => pgpTxRst,       -- [in]
         disableSel   => disableSel,     -- [in]
         rearbitrate  => rearbitrate,    -- [in]
         sAxisMasters => pgpTxMasters,   -- [in]
         sAxisSlaves  => pgpTxSlaves,    -- [out]
         mAxisMaster  => muxedTxMaster,  -- [out]
         mAxisSlave   => muxedTxSlave);  -- [in]

   -- Feed muxed stream to packetizer
   -- Note that the mux is doing the work of chunking
   -- Packetizer applies packet formatting and CRC
   -- rearbitrate signal doesn't really do anything (yet)
   U_AxiStreamPacketizer2_1 : entity work.AxiStreamPacketizer2
      generic map (
         TPD_G                => TPD_G,
         CRC_EN_G             => true,
         CRC_POLY_G           => X"04C11DB7",
         MAX_PACKET_BYTES_G   => CELL_WORDS_MAX_G*8*2,
         OUTPUT_SSI_G         => true,
         INPUT_PIPE_STAGES_G  => 0,
         OUTPUT_PIPE_STAGES_G => 0)
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
   U_Pgp3TxProtocol_1 : entity work.Pgp3TxProtocol
      generic map (
         TPD_G            => TPD_G,
         NUM_VC_G         => NUM_VC_G,
         SKP_INTERVAL_G   => SKP_INTERVAL_G,
         SKP_BURST_SIZE_G => SKP_BURST_SIZE_G)
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
         protTxSequence => protTxSequence,      -- [out]
         protTxData     => protTxData,          -- [out]
         protTxHeader   => protTxHeader);       -- [out]

   -- Scramble the data for 64b66b
   U_Scrambler_1 : entity work.Scrambler
      generic map (
         TPD_G            => TPD_G,
         DIRECTION_G      => "SCRAMBLER",
         DATA_WIDTH_G     => 64,
         SIDEBAND_WIDTH_G => 9,
         TAPS_G           => SCRAMBLER_TAPS_C)
      port map (
         clk                        => pgpTxClk,        -- [in]
         rst                        => pgpTxRst,        -- [in]
         inputValid                 => protTxValid,     -- [in]
         inputReady                 => protTxReady,     -- [out]
         inputData                  => protTxData,      -- [in]
         inputSideband(1 downto 0)  => protTxHeader,    -- [in]
         inputSideband(2)           => protTxStart,     -- [in]
         inputSideband(8 downto 3)  => protTxSequence,  -- [in]
         outputReady                => phyTxReady,      -- [in]
         outputData                 => phyTxData,       -- [out]
         outputSideband(1 downto 0) => phyTxHeader,     -- [out]
         outputSideband(2)          => phyTxStart,      -- [out]
         outputSideband(8 downto 3) => phyTxSequence);  -- [out]

end architecture rtl;
