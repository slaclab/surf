-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for surf.Pgp4Tx direct transmit testing
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.Pgp4Pkg.all;

entity Pgp4TxDirectWrapper is
   port (
      clk        : in  sl;
      rst        : in  sl;
      txValid    : in  sl;
      txReady    : out sl;
      txData     : in  slv(63 downto 0);
      txSof      : in  sl;
      txEof      : in  sl;
      txEofe     : in  sl;
      phyTxValid : out sl;
      phyTxReady : in  sl;
      phyTxData  : out slv(65 downto 0));
end entity Pgp4TxDirectWrapper;

architecture rtl of Pgp4TxDirectWrapper is

   signal pgpTxIn : Pgp4TxInType := (
      disable     => '0',
      flowCntlDis => '1',
      resetTx     => '0',
      skpInterval => (others => '0'),
      opCodeEn    => '0',
      opCodeData  => (others => '0'),
      locData     => (others => '0'));

   signal pgpTxMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal pgpTxSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

begin

   ---------------------------------------------------------------------------
   -- Flat test-facing transmit stimulus
   ---------------------------------------------------------------------------
   txReady                        <= pgpTxSlave.tReady;
   pgpTxMaster.tValid             <= txValid;
   pgpTxMaster.tData(63 downto 0) <= txData;
   pgpTxMaster.tKeep(7 downto 0)  <= X"FF";
   pgpTxMaster.tUser(1)           <= txSof;
   pgpTxMaster.tUser(14)          <= txEofe;
   pgpTxMaster.tLast              <= txEof;

   ---------------------------------------------------------------------------
   -- DUT hookup
   ---------------------------------------------------------------------------
   U_DUT : entity surf.Pgp4Tx
      generic map (
         NUM_VC_G          => 1,
         SKIP_EN_G         => false,
         CELL_WORDS_MAX_G  => 4,
         RX_CRC_PIPELINE_G => 0,
         PGP_COMMON_CLK_G  => true,
         MUX_MODE_G        => "INDEXED",
         MUX_TDEST_LOW_G   => 0)
      port map (
         pgpTxClk         => clk,
         pgpTxRst         => rst,
         pgpTxIn          => pgpTxIn,
         pgpTxOut         => open,
         pgpTxMasters(0)  => pgpTxMaster,
         pgpTxSlaves(0)   => pgpTxSlave,
         locRxFifoCtrl(0) => AXI_STREAM_CTRL_UNUSED_C,
         locRxLinkReady   => '1',
         remRxFifoCtrl(0) => AXI_STREAM_CTRL_UNUSED_C,
         remRxLinkReady   => '1',
         phyTxActive      => '1',
         phyTxReady       => phyTxReady,
         phyTxValid       => phyTxValid,
         phyTxStart       => open,
         phyTxData        => phyTxData(63 downto 0),
         phyTxHeader      => phyTxData(65 downto 64));

end architecture rtl;
