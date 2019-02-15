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

entity Pgp3Tb2 is

end entity Pgp3Tb2;

----------------------------------------------------------------------------------------------------

architecture tb of Pgp3Tb2 is

   -- component generics
   constant TPD_G               : time    := 1 ns;
   constant TX_CELL_WORDS_MAX_G : integer := PGP3_DEFAULT_TX_CELL_WORDS_MAX_C;
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
   signal axisClk : sl;                 -- [in]
   signal axisRst : sl;                 -- [in]

   -- TX
   signal pgpTxMasters0 : AxiStreamMasterArray(NUM_VC_G-1 downto 0);  -- [in]
   signal pgpTxSlaves0  : AxiStreamSlaveArray(NUM_VC_G-1 downto 0);   -- [out]

   signal pgpTxMasters1 : AxiStreamMasterArray(NUM_VC_G-1 downto 0);  -- [in]
   signal pgpTxSlaves1  : AxiStreamSlaveArray(NUM_VC_G-1 downto 0);   -- [out]

   signal pgpRxMasters0 : AxiStreamMasterArray(NUM_VC_G-1 downto 0);  -- [in]
   signal pgpRxCtrl0    : AxiStreamCtrlArray(NUM_VC_G-1 downto 0);    -- [out]

   signal pgpRxMasters1 : AxiStreamMasterArray(NUM_VC_G-1 downto 0);  -- [in]
   signal pgpRxCtrl1    : AxiStreamCtrlArray(NUM_VC_G-1 downto 0);    -- [out]


   -- Tx phy out
   signal phyTxData0   : slv(63 downto 0);
   signal phyTxHeader0 : slv(1 downto 0);

   signal phyRxData0   : slv(63 downto 0);
   signal phyRxHeader0 : slv(1 downto 0);

   signal phyTxData1   : slv(63 downto 0);
   signal phyTxHeader1 : slv(1 downto 0);

   signal phyRxData1   : slv(63 downto 0);
   signal phyRxHeader1 : slv(1 downto 0);

begin

   phyRxData1   <= phyTxData0;
   phyRxHeader1 <= phyTxHeader0;

   phyRxData0   <= phyTxData1;
   phyRxHeader0 <= phyTxHeader1;


--    process is
--    begin
--       wait for 600 us;
--       pgpTxIn.disable <= '1';
--       wait for 100 us;
--       pgpTxIn.disable <= '0';
--       wait;
--    end process;


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

   U_PrbsChannels_0 : entity work.PrbsChannels
      generic map (
         TPD_G      => TPD_G,
         CHANNELS_G => NUM_VC_G)
      port map (
         txClk     => axisClk,          -- [in]
         txRst     => axisRst,          -- [in]
         txMasters => pgpTxMasters0,    -- [out]
         txSlaves  => pgpTxSlaves0,     -- [in]
         rxClk     => axisClk,          -- [in]
         rxRst     => axisRst,          -- [in]
         rxMasters => pgpRxMasters0,    -- [in]
         rxSlaves  => open,             -- [out]
         rxCtrl    => pgpRxCtrl0,       -- [out]
         axilClk   => axisClk,              -- [in]
         axilRst   => axisRst);             -- [in]

   U_Pgp3Core_0 : entity work.Pgp3Core
      generic map (
         TPD_G    => TPD_G,
         NUM_VC_G => NUM_VC_G)
--          PGP_RX_ENABLE_G             => PGP_RX_ENABLE_G,
--          RX_ALIGN_SLIP_WAIT_G        => RX_ALIGN_SLIP_WAIT_G,
--          PGP_TX_ENABLE_G             => PGP_TX_ENABLE_G,
--          TX_CELL_WORDS_MAX_G         => TX_CELL_WORDS_MAX_G,
--          TX_MUX_MODE_G               => TX_MUX_MODE_G,
--          TX_MUX_TDEST_ROUTES_G       => TX_MUX_TDEST_ROUTES_G,
--          TX_MUX_TDEST_LOW_G          => TX_MUX_TDEST_LOW_G,
--          TX_MUX_ILEAVE_EN_G          => TX_MUX_ILEAVE_EN_G,
--          TX_MUX_ILEAVE_ON_NOTVALID_G => TX_MUX_ILEAVE_ON_NOTVALID_G,
--          EN_PGP_MON_G                => EN_PGP_MON_G,
--          AXIL_CLK_FREQ_G             => AXIL_CLK_FREQ_G)
      port map (
         pgpTxClk      => axisClk,            -- [in]
         pgpTxRst      => axisRst,            -- [in]
         pgpTxIn       => PGP3_TX_IN_INIT_C,  -- [in]
         pgpTxOut      => open,               -- [out]
         pgpTxMasters  => pgpTxMasters0,      -- [in]
         pgpTxSlaves   => pgpTxSlaves0,       -- [out]
         phyTxActive   => '1',                -- [in]
         phyTxReady    => '1',                -- [in]
         phyTxStart    => open,               -- [out]
         phyTxData     => phyTxData0,         -- [out]
         phyTxHeader   => phyTxHeader0,       -- [out]
         pgpRxClk      => axisClk,            -- [in]
         pgpRxRst      => axisRst,            -- [in]
         pgpRxIn       => PGP3_RX_IN_INIT_C,  -- [in]
         pgpRxOut      => open,               -- [out]
         pgpRxMasters  => pgpRxMasters0,      -- [out]
         pgpRxCtrl     => pgpRxCtrl0,         -- [in]
         phyRxClk      => axisClk,            -- [in]
         phyRxRst      => axisRst,            -- [in]
         phyRxInit     => open,               -- [out]
         phyRxActive   => '1',                -- [in]
         phyRxValid    => '1',                -- [in]
         phyRxHeader   => phyRxHeader0,       -- [in]
         phyRxData     => phyRxData0,         -- [in]
         phyRxStartSeq => '0',                -- [in]
         phyRxSlip     => open);              -- [out]


   U_PrbsChannels_1 : entity work.PrbsChannels
      generic map (
         TPD_G      => TPD_G,
         CHANNELS_G => NUM_VC_G)
      port map (
         txClk     => axisClk,          -- [in]
         txRst     => axisRst,          -- [in]
         txMasters => pgpTxMasters1,    -- [out]
         txSlaves  => pgpTxSlaves1,     -- [in]
         rxClk     => axisClk,          -- [in]
         rxRst     => axisRst,          -- [in]
         rxMasters => pgpRxMasters1,    -- [in]
         rxSlaves  => open,             -- [out]
         rxCtrl    => pgpRxCtrl1,       -- [out]
         axilClk   => axisClk,              -- [in]
         axilRst   => axisRst);             -- [in]


   U_Pgp3Core_1 : entity work.Pgp3Core
      generic map (
         TPD_G    => TPD_G,
         NUM_VC_G => NUM_VC_G)
--          PGP_RX_ENABLE_G             => PGP_RX_ENABLE_G,
--          RX_ALIGN_SLIP_WAIT_G        => RX_ALIGN_SLIP_WAIT_G,
--          PGP_TX_ENABLE_G             => PGP_TX_ENABLE_G,
--          TX_CELL_WORDS_MAX_G         => TX_CELL_WORDS_MAX_G,
--          TX_MUX_MODE_G               => TX_MUX_MODE_G,
--          TX_MUX_TDEST_ROUTES_G       => TX_MUX_TDEST_ROUTES_G,
--          TX_MUX_TDEST_LOW_G          => TX_MUX_TDEST_LOW_G,
--          TX_MUX_ILEAVE_EN_G          => TX_MUX_ILEAVE_EN_G,
--          TX_MUX_ILEAVE_ON_NOTVALID_G => TX_MUX_ILEAVE_ON_NOTVALID_G,
--          EN_PGP_MON_G                => EN_PGP_MON_G,
--          AXIL_CLK_FREQ_G             => AXIL_CLK_FREQ_G)
      port map (
         pgpTxClk      => axisClk,            -- [in]
         pgpTxRst      => axisRst,            -- [in]
         pgpTxIn       => PGP3_TX_IN_INIT_C,  -- [in]
         pgpTxOut      => open,               -- [out]
         pgpTxMasters  => pgpTxMasters1,      -- [in]
         pgpTxSlaves   => pgpTxSlaves1,       -- [out]
         phyTxActive   => '1',                -- [in]
         phyTxReady    => '1',                -- [in]
         phyTxStart    => open,               -- [out]
         phyTxData     => phyTxData1,         -- [out]
         phyTxHeader   => phyTxHeader1,       -- [out]
         pgpRxClk      => axisClk,            -- [in]
         pgpRxRst      => axisRst,            -- [in]
         pgpRxIn       => PGP3_RX_IN_INIT_C,  -- [in]
         pgpRxOut      => open,               -- [out]
         pgpRxMasters  => pgpRxMasters1,      -- [out]
         pgpRxCtrl     => pgpRxCtrl1,         -- [in]
         phyRxClk      => axisClk,            -- [in]
         phyRxRst      => axisRst,            -- [in]
         phyRxInit     => open,               -- [out]
         phyRxActive   => '1',                -- [in]
         phyRxValid    => '1',                -- [in]
         phyRxHeader   => phyRxHeader1,       -- [in]
         phyRxData     => phyRxData1,         -- [in]
         phyRxStartSeq => '0',                -- [in]
         phyRxSlip     => open);              -- [out]


end architecture tb;

----------------------------------------------------------------------------------------------------
