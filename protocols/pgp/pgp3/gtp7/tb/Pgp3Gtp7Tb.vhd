-------------------------------------------------------------------------------
-- Title      : PGPv3: https://confluence.slac.stanford.edu/x/OndODQ
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for Pgp3Gtp7
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


library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.Pgp3Pkg.all;

entity Pgp3Gtp7Tb is end Pgp3Gtp7Tb;

architecture testbed of Pgp3Gtp7Tb is

   constant CLK_PERIOD_C : time := 4 ns;
   constant TPD_G        : time := CLK_PERIOD_C/4;

   signal gtClkP : sl := '0';
   signal gtClkN : sl := '1';

   signal stableClk : sl := '0';
   signal stableRst : sl := '1';

   signal loopP : sl := '0';
   signal loopN : sl := '1';

   signal pgpClk : sl := '0';
   signal pgpRst : sl := '1';

   signal pgpRxIn  : Pgp3RxInType  := PGP3_RX_IN_INIT_C;
   signal pgpRxOut : Pgp3RxOutType := PGP3_RX_OUT_INIT_C;

   signal pgpTxIn  : Pgp3TxInType  := PGP3_TX_IN_INIT_C;
   signal pgpTxOut : Pgp3TxOutType := PGP3_TX_OUT_INIT_C;

   signal pgpTxMasters : AxiStreamMasterArray(3 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal pgpTxSlaves  : AxiStreamSlaveArray(3 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);

   signal pgpRxMasters : AxiStreamMasterArray(3 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal pgpRxCtrl    : AxiStreamCtrlArray(3 downto 0)   := (others => AXI_STREAM_CTRL_UNUSED_C);

begin

   -----------------------------
   -- Generate clocks and resets
   -----------------------------
   U_ClkRst : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1000 ns)  -- Hold reset for this long)
      port map (
         clkP => gtClkP,
         clkN => gtClkN,
         rst  => stableRst);

   -----------------------
   -- PGP Core for ARTIX-7
   -----------------------
   U_PGP : entity surf.Pgp3Gtp7Wrapper
      generic map (
         TPD_G               => TPD_G,
         SIM_PLL_EMULATION_G => true,
         NUM_LANES_G         => 1,
         NUM_VC_G            => 4,
         RATE_G              => "6.25Gbps",
         REFCLK_FREQ_G       => 250.0E+6)
      port map (
         -- Stable Clock and Reset
         stableClk         => stableClk,
         stableRst         => stableRst,
         -- Gt Serial IO
         pgpGtTxP(0)       => loopP,
         pgpGtTxN(0)       => loopN,
         pgpGtRxP(0)       => loopP,
         pgpGtRxN(0)       => loopN,
         -- GT Clocking
         pgpRefClkP        => gtClkP,
         pgpRefClkN        => gtClkN,
         pgpRefClkDiv2Bufg => stableClk,
         -- Clocking
         pgpClk(0)         => pgpClk,
         pgpClkRst(0)      => pgpRst,
         -- Non VC TX Signals
         pgpTxIn(0)        => pgpTxIn,
         pgpTxOut(0)       => pgpTxOut,
         -- Non VC RX Signals
         pgpRxIn(0)        => pgpRxIn,
         pgpRxOut(0)       => pgpRxOut,
         -- Frame Transmit Interface
         pgpTxMasters      => pgpTxMasters,
         pgpTxSlaves       => pgpTxSlaves,
         -- Frame Receive Interface
         pgpRxMasters      => pgpRxMasters,
         pgpRxCtrl         => pgpRxCtrl);

end testbed;
