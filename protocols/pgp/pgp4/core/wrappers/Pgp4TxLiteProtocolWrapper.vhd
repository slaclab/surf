-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for surf.Pgp4TxLiteProtocol
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

entity Pgp4TxLiteProtocolWrapper is
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
      protTxReady  : in  sl               := '1';
      linkReady    : out sl;
      frameTx      : out sl;
      frameTxErr   : out sl;
      opCodeReady  : out sl;
      protTxValid  : out sl;
      protTxStart  : out sl;
      protTxHeader : out slv(1 downto 0);
      protTxData   : out slv(63 downto 0));
end entity Pgp4TxLiteProtocolWrapper;

architecture rtl of Pgp4TxLiteProtocolWrapper is

   signal pgpTxMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal pgpTxSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal pgpTxIn     : Pgp4TxInType        := PGP4_TX_IN_INIT_C;
   signal pgpTxOut    : Pgp4TxOutType       := PGP4_TX_OUT_INIT_C;

begin

   txReady     <= pgpTxSlave.tReady;
   linkReady   <= pgpTxOut.linkReady;
   frameTx     <= pgpTxOut.frameTx;
   frameTxErr  <= pgpTxOut.frameTxErr;
   opCodeReady <= pgpTxOut.opCodeReady;

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
   pgpTxMaster.tStrb(7 downto 0)  <= X"FF";
   pgpTxMaster.tLast              <= txEof;
   pgpTxMaster.tUser(1)           <= txSof;
   pgpTxMaster.tUser(14)          <= txEofe;

   U_DUT : entity surf.Pgp4TxLiteProtocol
      generic map (
         NUM_VC_G       => 1,
         SKIP_EN_G      => false,
         FLOW_CTRL_EN_G => false,
         STARTUP_HOLD_G => 0)
      port map (
         pgpTxClk       => clk,
         pgpTxRst       => rst,
         pgpTxIn        => pgpTxIn,
         pgpTxOut       => pgpTxOut,
         pgpTxActive    => '1',
         pgpTxMaster    => pgpTxMaster,
         pgpTxSlave     => pgpTxSlave,
         locRxFifoCtrl  => (others => AXI_STREAM_CTRL_UNUSED_C),
         locRxLinkReady => '1',
         remRxLinkReady => '1',
         phyTxActive    => '1',
         protTxReady    => protTxReady,
         protTxValid    => protTxValid,
         protTxStart    => protTxStart,
         protTxData     => protTxData,
         protTxHeader   => protTxHeader);

end architecture rtl;
