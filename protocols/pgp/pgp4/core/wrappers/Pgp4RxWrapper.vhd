-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for surf.Pgp4Rx
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

entity Pgp4RxWrapper is
   port (
      clk          : in  sl;
      rst          : in  sl;
      txValid      : in  sl;
      txReady      : out sl;
      txData       : in  slv(63 downto 0);
      txSof        : in  sl;
      txEof        : in  sl;
      txEofe       : in  sl;
      opCodeEn     : in  sl               := '0';
      opCodeData   : in  slv(47 downto 0) := (others => '0');
      linkReady    : out sl;
      linkError    : out sl;
      frameRx      : out sl;
      frameRxErr   : out sl;
      rxOpCodeEn   : out sl;
      rxOpCodeData : out slv(47 downto 0);
      rxValid      : out sl;
      rxLast       : out sl;
      rxData       : out slv(63 downto 0);
      rxDest       : out slv(7 downto 0);
      rxUser       : out slv(15 downto 0));
end entity Pgp4RxWrapper;

architecture rtl of Pgp4RxWrapper is

   signal pgpTxIn     : Pgp4TxInType        := PGP4_TX_IN_INIT_C;
   signal pgpTxMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal pgpTxSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal phyTxValid  : sl;
   signal phyTxData   : slv(63 downto 0);
   signal phyTxHeader : slv(1 downto 0);

   signal pgpRxOut    : Pgp4RxOutType       := PGP4_RX_OUT_INIT_C;
   signal pgpRxMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;

begin

   txReady <= pgpTxSlave.tReady;

   pgpTxIn.disable     <= '0';
   pgpTxIn.flowCntlDis <= '1';
   pgpTxIn.resetTx     <= '0';
   pgpTxIn.skpInterval <= (others => '0');
   pgpTxIn.opCodeEn    <= opCodeEn;
   pgpTxIn.opCodeData  <= opCodeData;
   pgpTxIn.locData     <= (others => '0');

   pgpTxMaster.tValid             <= txValid;
   pgpTxMaster.tData(63 downto 0) <= txData;
   pgpTxMaster.tKeep(7 downto 0)  <= X"FF";
   pgpTxMaster.tUser(1)           <= txSof;
   pgpTxMaster.tUser(14)          <= txEofe;
   pgpTxMaster.tLast              <= txEof;

   linkReady    <= pgpRxOut.linkReady;
   linkError    <= pgpRxOut.linkError;
   frameRx      <= pgpRxOut.frameRx;
   frameRxErr   <= pgpRxOut.frameRxErr;
   rxOpCodeEn   <= pgpRxOut.opCodeEn;
   rxOpCodeData <= pgpRxOut.opCodeData;
   rxValid      <= pgpRxMaster.tValid;
   rxLast       <= pgpRxMaster.tLast;
   rxData       <= pgpRxMaster.tData(63 downto 0);
   rxDest       <= pgpRxMaster.tDest(7 downto 0);
   rxUser       <= pgpRxMaster.tUser(15 downto 0);

   U_TX : entity surf.Pgp4Tx
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
         phyTxReady       => '1',
         phyTxValid       => phyTxValid,
         phyTxStart       => open,
         phyTxData        => phyTxData,
         phyTxHeader      => phyTxHeader);

   U_RX : entity surf.Pgp4Rx
      generic map (
         NUM_VC_G          => 1,
         SKIP_EN_G         => false,
         RX_CRC_PIPELINE_G => 0)
      port map (
         pgpRxClk        => clk,
         pgpRxRst        => rst,
         pgpRxIn         => PGP4_RX_IN_INIT_C,
         pgpRxOut        => pgpRxOut,
         pgpRxMasters(0) => pgpRxMaster,
         pgpRxCtrl(0)    => AXI_STREAM_CTRL_UNUSED_C,
         remRxFifoCtrl   => open,
         remRxLinkReady  => open,
         locRxLinkReady  => open,
         phyRxClk        => clk,
         phyRxRst        => rst,
         phyRxInit       => open,
         phyRxActive     => '1',
         phyRxValid      => phyTxValid,
         phyRxData       => phyTxData,
         phyRxHeader     => phyTxHeader,
         phyRxStartSeq   => '0',
         phyRxSlip       => open);

end architecture rtl;
