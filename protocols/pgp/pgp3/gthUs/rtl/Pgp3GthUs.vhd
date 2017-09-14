-------------------------------------------------------------------------------
-- File       : Pgp3GthUs.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-06-29
-- Last update: 2017-09-13
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of 'Example Project Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'Example Project Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.Pgp3Pkg.all;

library UNISIM;
use UNISIM.VCOMPONENTS.all;

entity Pgp3GthUs is
   generic (
      TPD_G                           : time                  := 1 ns;
      ----------------------------------------------------------------------------------------------
      -- PGP Settings
      ----------------------------------------------------------------------------------------------
      PGP_RX_ENABLE_G                 : boolean               := true;
      RX_ALIGN_GOOD_COUNT_G           : integer               := 128;
      RX_ALIGN_BAD_COUNT_G            : integer               := 16;
      RX_ALIGN_SLIP_WAIT_G            : integer               := 32;
      PGP_TX_ENABLE_G                 : boolean               := true;
      NUM_VC_G                        : integer range 1 to 16 := 4;
      TX_CELL_WORDS_MAX_G             : integer               := 256;  -- Number of 64-bit words per cell
      TX_SKP_INTERVAL_G               : integer               := 5000;
      TX_SKP_BURST_SIZE_G             : integer               := 8;
      TX_MUX_MODE_G                   : string                := "INDEXED";  -- Or "ROUTED"
      TX_MUX_TDEST_ROUTES_G           : Slv8Array             := (0 => "--------");  -- Only used in ROUTED mode
      TX_MUX_TDEST_LOW_G              : integer range 0 to 7  := 0;
      TX_MUX_INTERLEAVE_EN_G          : boolean               := true;
      TX_MUX_INTERLEAVE_ON_NOTVALID_G : boolean               := true);

   port (
      -- GT Clocking
      stableClk    : in  sl;            -- GT needs a stable clock to "boot up"
      stableRst    : in  sl;
      gtRefClk     : in  sl;
      -- Gt Serial IO
      pgpGtTxP     : out sl;
      pgpGtTxN     : out sl;
      pgpGtRxP     : in  sl;
      pgpGtRxN     : in  sl;
      -- Clocking
      pgpClk       : out sl;
      pgpClkRst    : out sl;
      -- Non VC Rx Signals
      pgpRxIn      : in  Pgp3RxInType;
      pgpRxOut     : out Pgp3RxOutType;
      -- Non VC Tx Signals
      pgpTxIn      : in  Pgp3TxInType;
      pgpTxOut     : out Pgp3TxOutType;
      -- Frame Transmit Interface - 1 Lane, Array of 4 VCs
      pgpTxMasters : in  AxiStreamMasterArray(NUM_VC_G-1 downto 0);
      pgpTxSlaves  : out AxiStreamSlaveArray(NUM_VC_G-1 downto 0);
      -- Frame Receive Interface - 1 Lane, Array of 4 VCs
      pgpRxMasters : out AxiStreamMasterArray(NUM_VC_G-1 downto 0);
      pgpRxCtrl    : in  AxiStreamCtrlArray(NUM_VC_G-1 downto 0));
end Pgp3GthUs;

architecture rtl of Pgp3GthUs is

   -- clocks
   signal pgpRxClkInt : sl;
   signal pgpRxRstInt : sl;
   signal pgpTxClkInt : sl;
   signal pgpTxRstInt : sl;

   -- PgpRx Signals
--   signal gtRxUserReset : sl;
   signal phyRxClk      : sl;
   signal phyRxRst      : sl;
   signal phyRxInit     : sl;
   signal phyRxActive   : sl;
   signal phyRxValid    : sl;
   signal phyRxHeader   : slv(1 downto 0);
   signal phyRxData     : slv(63 downto 0);
   signal phyRxStartSeq : sl;
   signal phyRxSlip     : sl;


   -- PgpTx Signals
--   signal gtTxUserReset : sl;
   signal phyTxActive   : sl;
   signal phyTxStart    : sl;
   signal phyTxSequence : slv(5 downto 0);
   signal phyTxData     : slv(63 downto 0);
   signal phyTxHeader   : slv(1 downto 0);


begin

   pgpClk    <= pgpTxClkInt;
   pgpClkRst <= pgpTxRstInt;

   --gtRxUserReset <= phyRxInit or pgpRxIn.resetRx;
   --gtTxUserReset <= pgpTxRst;

   U_Pgp3Core_1 : entity work.Pgp3Core
      generic map (
         TPD_G                           => TPD_G,
         NUM_VC_G                        => NUM_VC_G,
         PGP_RX_ENABLE_G                 => PGP_RX_ENABLE_G,
         RX_ALIGN_GOOD_COUNT_G           => RX_ALIGN_GOOD_COUNT_G,
         RX_ALIGN_BAD_COUNT_G            => RX_ALIGN_BAD_COUNT_G,
         RX_ALIGN_SLIP_WAIT_G            => RX_ALIGN_SLIP_WAIT_G,
         PGP_TX_ENABLE_G                 => PGP_TX_ENABLE_G,
         TX_CELL_WORDS_MAX_G             => TX_CELL_WORDS_MAX_G,
         TX_SKP_INTERVAL_G               => TX_SKP_INTERVAL_G,
         TX_SKP_BURST_SIZE_G             => TX_SKP_BURST_SIZE_G,
         TX_MUX_MODE_G                   => TX_MUX_MODE_G,
         TX_MUX_TDEST_ROUTES_G           => TX_MUX_TDEST_ROUTES_G,
         TX_MUX_TDEST_LOW_G              => TX_MUX_TDEST_LOW_G,
         TX_MUX_INTERLEAVE_EN_G          => TX_MUX_INTERLEAVE_EN_G,
         TX_MUX_INTERLEAVE_ON_NOTVALID_G => TX_MUX_INTERLEAVE_ON_NOTVALID_G)
      port map (
         pgpTxClk      => pgpTxClkInt,    -- [in]
         pgpTxRst      => pgpTxRstInt,    -- [in]
         pgpTxIn       => pgpTxIn,        -- [in]
         pgpTxOut      => pgpTxOut,       -- [out]
         pgpTxMasters  => pgpTxMasters,   -- [in]
         pgpTxSlaves   => pgpTxSlaves,    -- [out]
         phyTxActive   => phyTxActive,    -- [in]
         phyTxReady    => '1',            -- [in]
         phyTxStart    => phyTxStart,     -- [out]
         phyTxSequence => phyTxSequence,  -- [out]
         phyTxData     => phyTxData,      -- [out]
         phyTxHeader   => phyTxHeader,    -- [out]
         pgpRxClk      => pgpTxClkInt,    -- [in]
         pgpRxRst      => pgpTxRstInt,    -- [in]
         pgpRxIn       => pgpRxIn,        -- [in]
         pgpRxOut      => pgpRxOut,       -- [out]
         pgpRxMasters  => pgpRxMasters,   -- [out]
         pgpRxCtrl     => pgpRxCtrl,      -- [in]
         phyRxClk      => phyRxClk,       -- [in]
         phyRxRst      => phyRxRst,       -- [in]
         phyRxInit     => phyRxInit,      -- [out]
         phyRxActive   => phyRxActive,    -- [in]
         phyRxValid    => phyRxValid,     -- [in]
         phyRxHeader   => phyRxHeader,    -- [in]
         phyRxData     => phyRxData,      -- [in]
         phyRxStartSeq => phyRxStartSeq,  -- [in]
         phyRxSlip     => phyRxSlip);     -- [out]

   --------------------------
   -- Wrapper for GTH IP core
   --------------------------
   U_Pgp3GthCoreWrapper_2 : entity work.Pgp3GthCoreWrapper
      generic map (
         TPD_G => TPD_G)
      port map (
         stableClk      => stableClk,          -- [in]
         stableRst      => stableRst,          -- [in]
         gtRefClk       => gtRefClk,           -- [in]
         gtRxP          => pgpGtRxP,           -- [in]
         gtRxN          => pgpGtRxN,           -- [in]
         gtTxP          => pgpGtTxP,           -- [out]
         gtTxN          => pgpGtTxN,           -- [out]
         rxReset        => phyRxInit,          -- [in]
         rxUsrClkActive => open,               -- [out]
         rxResetDone    => phyRxActive,        -- [out]
         rxUsrClk       => open,               -- [out]
         rxUsrClk2      => phyRxClk,           -- [out]
         rxUsrClkRst    => phyRxRst,           -- [out]
         rxData         => phyRxData,          -- [out]
         rxDataValid    => phyRxValid,         -- [out]
         rxHeader       => phyRxHeader,        -- [out]
         rxHeaderValid  => open,               -- [out]
         rxStartOfSeq   => phyRxStartSeq,      -- [out]
         rxGearboxSlip  => phyRxSlip,          -- [in]
         rxOutClk       => open,               -- [out]
         txReset        => '0',                -- [in]
         txUsrClkActive => open,               -- [out]
         txResetDone    => phyTxActive,        -- [out]
         txUsrClk       => open,               -- [out]
         txUsrClk2      => pgpTxClkInt,        -- [out]
         txUsrClkRst    => pgpTxRstInt,        -- [out]
         txData         => phyTxData,          -- [in]
         txHeader       => phyTxHeader,        -- [in]
         txSequence     => phyTxSequence,      -- [in]
         txOutClk       => open,               -- [out]
         loopback       => pgpRxIn.loopback);  -- [in]


end rtl;
