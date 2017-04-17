-------------------------------------------------------------------------------
-- File       : RoguePgpSim.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-12-05
-- Last update: 2017-02-02
-------------------------------------------------------------------------------
-- Description: Wrapper on RogueStreamSim to simulate a PGP lane with 4
-- virtual channels
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library unisim;
use unisim.vcomponents.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.Pgp2bPkg.all;


entity RoguePgpSim is

   generic (
      TPD_G           : time                   := 1 ns;
      FIXED_LAT_G     : boolean                := false;
      RX_CLK_PERIOD_G : real                   := 8.0e-9;
      USER_ID_G       : integer range 0 to 100 := 1;
      NUM_VC_EN_G     : integer range 1 to 4   := 4);

   port (
      refClkP : in sl;
      refClkM : in sl;

      pgpTxClk     : out sl;
      pgpTxRst     : out sl;
      pgpTxIn      : in  Pgp2bTxInType := PGP2B_TX_IN_INIT_C;
      pgpTxOut     : out Pgp2bTxOutType;
      pgpTxMasters : in  AxiStreamMasterArray(NUM_VC_EN_G-1 downto 0);
      pgpTxSlaves  : out AxiStreamSlaveArray(NUM_VC_EN_G-1 downto 0);

      pgpRxClk     : out sl            := '0';  -- Used in FIXED_LAT mode
      pgpRxRst     : out sl            := '0';
      pgpRxIn      : in  Pgp2bRxInType := PGP2B_RX_IN_INIT_C;
      pgpRxOut     : out Pgp2bRxOutType;
      pgpRxMasters : out AxiStreamMasterArray(NUM_VC_EN_G-1 downto 0);
      pgpRxSlaves  : in  AxiStreamSlaveArray(NUM_VC_EN_G-1 downto 0));

end entity RoguePgpSim;

architecture sim of RoguePgpSim is

   constant RX_CLK_PERIOD_C : time := RX_CLK_PERIOD_G * (1000 ms);

   signal pgpClk : sl := '0';
   signal pgpRst : sl := '0';

   signal rxClk : sl := '0';
   signal rxRst : sl := '0';

begin

   IBUFDS_GTE2_Inst : IBUFGDS
      port map (
         I  => refClkP,
         IB => refClkM,
         O  => pgpClk);

   PwrUpRst_Inst : entity work.PwrUpRst
      generic map (
         TPD_G          => TPD_G,
         IN_POLARITY_G  => '1',
         OUT_POLARITY_G => '1',
         DURATION_G     => 50)
      port map (
         clk    => pgpClk,
         rstOut => pgpRst);

   pgpTxClk <= pgpClk;
   pgpTxRst <= pgpRst;


   -- pgpRxClk is same as pgpTxClk if not in fixed lat mode
   NORMAL : if (not FIXED_LAT_G) generate
      pgpRxClk <= pgpClk;
      pgpRxRst <= pgpRst;
      rxClk    <= pgpClk;
   end generate NORMAL;

   -- If fixed late, create an internal clock to emulate recovered clock
   FIXED_LAT : if (FIXED_LAT_G) generate
      U_ClkRst_1 : entity work.ClkRst
         generic map (
            CLK_PERIOD_G    => RX_CLK_PERIOD_C,
            CLK_DELAY_G     => 0.14159 ns,
            RST_HOLD_TIME_G => 30 ns,
            SYNC_RESET_G    => true)
         port map (
            clkP => rxClk,              -- [out]
            rst  => rxRst);             -- [out]

      pgpRxClk <= rxClk;
      pgpRxRst <= rxRst;
   end generate FIXED_LAT;

   GEN_AXIS_LANE : for i in NUM_VC_EN_G-1 downto 0 generate
      U_RogueStreamSimWrap_PGP_VC : entity work.RogueStreamSimWrap
         generic map (
            TPD_G         => TPD_G,
            DEST_ID_G     => i,
            AXIS_CONFIG_G => SSI_PGP2B_CONFIG_C)
         port map (
            clk         => pgpClk,           -- [in]
            rst         => pgpRst,           -- [in]
            sAxisClk    => pgpClk,           -- [in]
            sAxisRst    => pgpRst,           -- [in]
            sAxisMaster => pgpTxMasters(i),  -- [in]
            sAxisSlave  => pgpTxSlaves(i),   -- [out]
            mAxisClk    => rxClk,            -- [in]
            mAxisRst    => rxRst,            -- [in]
            mAxisMaster => pgpRxMasters(i),  -- [out]
            mAxisSlave  => pgpRxSlaves(i));  -- [in]
   end generate GEN_AXIS_LANE;

   U_RogueStreamSimWrap_OPCODE : entity work.RogueStreamSimWrap
      generic map (
         TPD_G         => TPD_G,
         DEST_ID_G     => 4,
         AXIS_CONFIG_G => SSI_PGP2B_CONFIG_C)
      port map (
         clk         => pgpClk,                    -- [in]
         rst         => pgpRst,                    -- [in]
         sAxisClk    => pgpClk,                    -- [in]
         sAxisRst    => pgpRst,                    -- [in]
         sAxisMaster => AXI_STREAM_MASTER_INIT_C,  -- [in]
         sAxisSlave  => open,                      -- [out]
         mAxisClk    => rxClk,                     -- [in]
         mAxisRst    => rxRst,                     -- [in]
         mAxisMaster => open,                      -- [out]
         mAxisSlave  => AXI_STREAM_SLAVE_FORCE_C,  -- [in]
         opCode      => pgpRxOut.opCode,           -- [out]
         opCodeEn    => pgpRxOut.opCodeEn,         -- [out]
         remData     => pgpRxOut.remLinkData);     -- [out]

   pgpRxOut.phyRxReady   <= '1';
   pgpRxOut.linkReady    <= '1';
   pgpRxOut.linkPolarity <= (others => '0');
   pgpRxOut.frameRx      <= '0';
   pgpRxOut.frameRxErr   <= '0';
   pgpRxOut.linkDown     <= '0';
   pgpRxOut.linkError    <= '0';
   pgpRxOut.remLinkReady <= '1';
   pgpRxOut.remOverflow  <= (others => '0');
   pgpRxOut.remPause     <= (others => '0');

   pgpTxOut.locOverflow <= (others => '0');
   pgpTxOut.locPause    <= (others => '0');
   pgpTxOut.phyTxReady  <= '1';
   pgpTxOut.linkReady   <= '1';
   pgpTxOut.frameTx     <= '0';
   pgpTxOut.frameTxErr  <= '0';
end architecture sim;
