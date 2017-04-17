-------------------------------------------------------------------------------
-- Title      : Testbench for design "AxiStreamPacketizer2"
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
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
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.Pgp3Pkg.all;

----------------------------------------------------------------------------------------------------

entity Pgp3Tb is

end entity Pgp3Tb;

----------------------------------------------------------------------------------------------------

architecture tb of Pgp3Tb is

   -- component generics
   constant TPD_G               : time    := 1 ns;
   constant TX_CELL_WORDS_MAX_G : integer := 256;
   constant NUM_VC_G            : integer := 4;
   constant SKP_INTERVAL_G      : integer := 5000;
   constant SKP_BURST_SIZE_G    : integer := 8;

   constant MUX_MODE_G                   : string               := "INDEXED";  -- Or "ROUTED"
   constant MUX_TDEST_ROUTES_G           : Slv8Array            := (0 => "--------");  -- Only used in ROUTED mode
   constant MUX_TDEST_LOW_G              : integer range 0 to 7 := 0;
   constant MUX_INTERLEAVE_EN_G          : boolean              := true;
   constant MUX_INTERLEAVE_ON_NOTVALID_G : boolean              := false;

   constant PACKETIZER_IN_AXIS_CFG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 8,
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 8,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 8,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   constant RX_AXIS_CFG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 4,
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 8,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 2,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   -- Clocking
   signal rxClk : sl;
   signal rxRst : sl;

   signal axisClk : sl;                 -- [in]
   signal axisRst : sl;                 -- [in]

   -- TX
   signal pgpTxIn        : Pgp3TxInType := PGP3_TX_IN_INIT_C;
   signal pgpTxOut       : Pgp3TxOutType;
   signal pgpTxMasters   : AxiStreamMasterArray(NUM_VC_G-1 downto 0);  -- [in]
   signal pgpTxSlaves    : AxiStreamSlaveArray(NUM_VC_G-1 downto 0);   -- [out]
   signal pgpTxCtrl      : AxiStreamCtrlArray(NUM_VC_G-1 downto 0);
   -- status from rx to tx
   signal locRxLinkReady : sl;
   signal remRxFifoCtrl  : AxiStreamCtrlArray(NUM_VC_G-1 downto 0);
   signal remRxLinkReady : sl;
   -- Tx phy out
   signal phyTxData      : slv(63 downto 0);
   signal phyTxHeader    : slv(1 downto 0);

   signal phyRxData   : slv(63 downto 0);
   signal phyRxHeader : slv(1 downto 0);

   signal pgpRxIn      : Pgp3RxInType                            := PGP3_RX_IN_INIT_C;
   signal pgpRxOut     : Pgp3RxOutType;
   signal pgpRxMasters : AxiStreamMasterArray(NUM_VC_G-1 downto 0);
   signal pgpRxCtrl    : AxiStreamCtrlArray(NUM_VC_G-1 downto 0) := (others => AXI_STREAM_CTRL_UNUSED_C);

begin

   process is
   begin
      wait for 600 us;
      pgpTxIn.disable <= '1';
      wait for 100 us;
      pgpTxIn.disable <= '0';
      wait;
   end process;
              

   U_ClkRst_1 : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => 10 ns,
         CLK_DELAY_G       => 1 ns,
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 5 us,
         SYNC_RESET_G      => true)
      port map (
         clkP => axisClk,
         rst  => axisRst);

   PRBS_GEN : for i in 0 to NUM_VC_G-1 generate
      U_SsiPrbsTx_1 : entity work.SsiPrbsTx
         generic map (
            TPD_G                      => TPD_G,
            GEN_SYNC_FIFO_G            => true,
            PRBS_INCREMENT_G           => true,
            MASTER_AXI_STREAM_CONFIG_G => PACKETIZER_IN_AXIS_CFG_C)
         port map (
            mAxisClk     => axisClk,          -- [in]
            mAxisRst     => axisRst,          -- [in]
            mAxisMaster  => pgpTxMasters(i),  -- [out]
            mAxisSlave   => pgpTxSlaves(i),   -- [in]
            locClk       => axisClk,          -- [in]
            locRst       => axisRst,          -- [in]
            trig         => '1',              -- [in]
            packetLength => X"0000FFFF",      -- [in]
            forceEofe    => '0',              -- [in]
            busy         => open,             -- [out]
            tDest        => toSlv(i, 8),      -- [in]
            tId          => X"00");           -- [in]
   end generate PRBS_GEN;

   -------------------------------------------------------------------------------------------------
   -- PGP3 Transmit
   -------------------------------------------------------------------------------------------------
   U_Pgp3Tx_1 : entity work.Pgp3Tx
      generic map (
         TPD_G                        => TPD_G,
         NUM_VC_G                     => NUM_VC_G,
         TX_CELL_WORDS_MAX_G          => TX_CELL_WORDS_MAX_G,
         SKP_INTERVAL_G               => SKP_INTERVAL_G,
         SKP_BURST_SIZE_G             => SKP_BURST_SIZE_G,
         MUX_MODE_G                   => MUX_MODE_G,
         MUX_TDEST_ROUTES_G           => MUX_TDEST_ROUTES_G,
         MUX_TDEST_LOW_G              => MUX_TDEST_LOW_G,
         MUX_INTERLEAVE_EN_G          => MUX_INTERLEAVE_EN_G,
         MUX_INTERLEAVE_ON_NOTVALID_G => MUX_INTERLEAVE_ON_NOTVALID_G)
      port map (
         pgpTxClk       => axisClk,         -- [in]
         pgpTxRst       => axisRst,         -- [in]
         pgpTxIn        => pgpTxIn,         -- [in]
         pgpTxOut       => pgpTxOut,        -- [out]
         pgpTxMasters   => pgpTxMasters,    -- [in]
         pgpTxSlaves    => pgpTxSlaves,     -- [out]
         pgpTxCtrl      => pgpTxCtrl,       -- [out]
         locRxFifoCtrl  => pgpRxCtrl,       -- [in]
         locRxLinkReady => locRxLinkReady,  -- [in]
         remRxFifoCtrl  => remRxFifoCtrl,   -- [in]
         remRxLinkReady => remRxLinkReady,  -- [in]
         phyTxReady     => '1',             -- [in]
         phyTxData      => phyTxData,       -- [out]
         phyTxHeader    => phyTxHeader);    -- [out]

   phyRxHeader <= phyTxHeader;
   phyRxData   <= phyTxData;

   U_Pgp3Rx_1 : entity work.Pgp3Rx
      generic map (
         TPD_G    => TPD_G,
         NUM_VC_G => NUM_VC_G)
      port map (
         pgpRxClk         => axisClk,         -- [in]
         pgpRxRst         => axisRst,         -- [in]
         pgpRxIn          => pgpRxIn,         -- [in]
         pgpRxOut         => pgpRxOut,        -- [out]
         pgpRxMasters     => pgpRxMasters,    -- [out]
         pgpRxCtrl        => pgpRxCtrl,       -- [in]
         remRxFifoCtrl    => remRxFifoCtrl,   -- [out]
         remRxLinkReady   => remRxLinkReady,  -- [out]
         locRxLinkReady   => locRxLinkReady,  -- [out]
         phyRxClk         => '0',             -- [in]
         phyRxReady       => '1',             -- [in]
         phyRxInit        => open,            -- [out]
         phyRxHeaderValid => '1',             -- [in]
         phyRxHeader      => phyRxHeader,     -- [in]
         phyRxDataValid   => "11",            -- [in]
         phyRxData        => phyRxData,       -- [in]
         phyRxStartSeq    => '0',             -- [in]
         phyRxSlip        => open);           -- [out]


   U_ClkRst_2 : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => 40 ns,
         CLK_DELAY_G       => 1 ns,
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 5 us,
         SYNC_RESET_G      => true)
      port map (
         clkP => rxClk,
         rst  => rxRst);


   RX_BUFERS : for i in NUM_VC_G-1 downto 0 generate
      U_AxiStreamFifoV2_1 : entity work.AxiStreamFifoV2
         generic map (
            TPD_G               => TPD_G,
            SLAVE_READY_EN_G    => false,
--            VALID_THOLD_G          => VALID_THOLD_G,
--            VALID_BURST_MODE_G     => VALID_BURST_MODE_G,
            BRAM_EN_G           => false,
            GEN_SYNC_FIFO_G     => false,
            FIFO_ADDR_WIDTH_G   => 5,
--            FIFO_FIXED_THRESH_G    => FIFO_FIXED_THRESH_G,
            FIFO_PAUSE_THRESH_G => 16,
            INT_WIDTH_SELECT_G  => "WIDE",
            SLAVE_AXI_CONFIG_G  => PGP3_AXIS_CONFIG_C,
            MASTER_AXI_CONFIG_G => RX_AXIS_CFG_C)
         port map (
            sAxisClk    => axisClk,                    -- [in]
            sAxisRst    => axisRst,                    -- [in]
            sAxisMaster => pgpRxMasters(i),            -- [in]
            sAxisSlave  => open,                       -- [out]
            sAxisCtrl   => pgpRxCtrl(i),               -- [out]
            mAxisClk    => rxClk,                      -- [in]
            mAxisRst    => rxRst,                      -- [in]
            mAxisMaster => open,                       -- [out]
            mAxisSlave  => AXI_STREAM_SLAVE_FORCE_C);  -- [in]
   end generate RX_BUFERS;

end architecture tb;

----------------------------------------------------------------------------------------------------
