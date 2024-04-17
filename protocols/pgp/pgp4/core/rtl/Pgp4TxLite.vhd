-------------------------------------------------------------------------------
-- Title      : PGPv4: https://confluence.slac.stanford.edu/x/1dzgEQ
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Pgp4TxLite (no SOC/EOC support)
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

entity Pgp4TxLite is
   generic (
      TPD_G          : time                  := 1 ns;
      RST_ASYNC_G    : boolean               := false;
      NUM_VC_G       : integer range 1 to 16 := 1;
      SKIP_EN_G      : boolean               := false;
      FLOW_CTRL_EN_G : boolean               := false);
   port (
      -- Transmit interface
      pgpTxClk     : in  sl;
      pgpTxRst     : in  sl;
      pgpTxIn      : in  Pgp4TxInType := PGP4_TX_IN_INIT_C;
      pgpTxOut     : out Pgp4TxOutType;
      pgpTxActive  : in  sl;
      pgpTxMasters : in  AxiStreamMasterArray(NUM_VC_G-1 downto 0);
      pgpTxSlaves  : out AxiStreamSlaveArray(NUM_VC_G-1 downto 0);
      -- Status of receive and remote FIFOs (Asynchronous)
      locRxFifoCtrl  : in AxiStreamCtrlArray(NUM_VC_G-1 downto 0) := (others => AXI_STREAM_CTRL_UNUSED_C);
      locRxLinkReady : in sl                                      := '1';
      remRxFifoCtrl  : in AxiStreamCtrlArray(NUM_VC_G-1 downto 0) := (others => AXI_STREAM_CTRL_UNUSED_C);
      remRxLinkReady : in sl                                      := '1';
      -- PHY interface
      phyTxActive : in  sl;
      phyTxReady  : in  sl;
      phyTxValid  : out sl;
      phyTxStart  : out sl;
      phyTxData   : out slv(63 downto 0);
      phyTxHeader : out slv(1 downto 0));
end entity Pgp4TxLite;

architecture rtl of Pgp4TxLite is

   -- Synchronized statuses
   signal syncLocRxFifoCtrl  : AxiStreamCtrlArray(NUM_VC_G-1 downto 0) := (others => AXI_STREAM_CTRL_UNUSED_C);
   signal syncLocRxLinkReady : sl                                      := '1';
   signal syncRemRxFifoCtrl  : AxiStreamCtrlArray(NUM_VC_G-1 downto 0) := (others => AXI_STREAM_CTRL_UNUSED_C);
   signal syncRemRxLinkReady : sl                                      := '1';

   -- Pipeline signals
   signal disableSel    : slv(NUM_VC_G-1 downto 0);
   signal rearbitrate   : sl := '0';
   signal muxedTxMaster : AxiStreamMasterType;
   signal muxedTxSlave  : AxiStreamSlaveType;

   signal phyTxActiveL : sl;
   signal protTxValid  : sl;
   signal protTxReady  : sl;
   signal protTxStart  : sl;
   signal protTxData   : slv(63 downto 0);
   signal protTxHeader : slv(1 downto 0);

begin

   FLOW_CTRL_SYNC : if (FLOW_CTRL_EN_G) generate
      -- Synchronize remote link and FIFO status to tx clock
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

      -- Synchronize local rx status
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
   end generate FLOW_CTRL_SYNC;

   ------------------------------------------------------------------------
   -- Use synchronized remote status to disable channels from mux selection
   -- All flow control overridden by pgpTxIn 'disable' and 'flowCntlDis'
   ------------------------------------------------------------------------
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

   GEN_MUX : if (NUM_VC_G > 1) or (FLOW_CTRL_EN_G = true) generate
      -- Multiplex the incoming TX streams with interleaving
      U_AxiStreamMux_1 : entity surf.AxiStreamMux
         generic map (
            TPD_G                => TPD_G,
            RST_ASYNC_G          => RST_ASYNC_G,
            NUM_SLAVES_G         => NUM_VC_G,
            MODE_G               => "INDEXED",
            PIPE_STAGES_G        => 0,
            TDEST_LOW_G          => 0,
            ILEAVE_EN_G          => false,
            ILEAVE_ON_NOTVALID_G => false)
         port map (
            axisClk      => pgpTxClk,       -- [in]
            axisRst      => pgpTxRst,       -- [in]
            disableSel   => disableSel,     -- [in]
            rearbitrate  => '0',            -- [in]
            ileaveRearb  => (others=>'0'),  -- Cadence Genus doesn't support ite() init - Error   : Could not resolve complex expression. [CDFG-200] [elaborate]
            sAxisMasters => pgpTxMasters,   -- [in]
            sAxisSlaves  => pgpTxSlaves,    -- [out]
            mAxisMaster  => muxedTxMaster,  -- [out]
            mAxisSlave   => muxedTxSlave);  -- [in]
   end generate GEN_MUX;

   NO_MUX : if (NUM_VC_G = 1) and (FLOW_CTRL_EN_G = false) generate
      muxedTxMaster  <= pgpTxMasters(0);
      pgpTxSlaves(0) <= muxedTxSlave;
   end generate NO_MUX;

   ----------------------------------------------------------------------------------------
   -- Feed packets into PGP TX Protocol engine
   -- Translates Packetizer2 frames, status, and opcodes into unscrambled 64b66b characters
   ----------------------------------------------------------------------------------------
   U_Protocol : entity surf.Pgp4TxLiteProtocol
      generic map (
         TPD_G          => TPD_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         NUM_VC_G       => NUM_VC_G,
         SKIP_EN_G      => SKIP_EN_G,
         FLOW_CTRL_EN_G => FLOW_CTRL_EN_G,
         STARTUP_HOLD_G => 0)
      port map (
         pgpTxClk       => pgpTxClk,            -- [in]
         pgpTxRst       => pgpTxRst,            -- [in]
         pgpTxIn        => pgpTxIn,             -- [in]
         pgpTxOut       => pgpTxOut,            -- [out]
         pgpTxActive    => pgpTxActive,         -- [in]
         pgpTxMaster    => muxedTxMaster,       -- [in]
         pgpTxSlave     => muxedTxSlave,        -- [out]
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
