-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for surf.Pgp4TxProtocol
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
use surf.SsiPkg.all;
use surf.Pgp4Pkg.all;

entity Pgp4TxProtocolWrapper is
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
end entity Pgp4TxProtocolWrapper;

architecture rtl of Pgp4TxProtocolWrapper is

   signal axisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal axisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

   signal packetizedMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal packetizedSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

   signal pgpTxIn  : Pgp4TxInType  := PGP4_TX_IN_INIT_C;
   signal pgpTxOut : Pgp4TxOutType := PGP4_TX_OUT_INIT_C;

begin

   txReady     <= axisSlave.tReady;
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

   process (txData, txEof, txEofe, txSof, txValid) is
      variable master : AxiStreamMasterType;
   begin
      master := AXI_STREAM_MASTER_INIT_C;
      if txValid = '1' then
         master.tValid             := '1';
         master.tData(63 downto 0) := txData;
         master.tKeep(7 downto 0)  := X"FF";
         master.tStrb(7 downto 0)  := X"FF";
         master.tLast              := txEof;
         axiStreamSetUserBit(PGP4_AXIS_CONFIG_C, master, SSI_SOF_C, txSof, 0);
         axiStreamSetUserBit(PGP4_AXIS_CONFIG_C, master, SSI_EOFE_C, txEofe);
      end if;
      axisMaster <= master;
   end process;

   U_Packetizer : entity surf.AxiStreamPacketizer2
      generic map (
         CRC_MODE_G     => "DATA",
         CRC_POLY_G     => PGP4_CRC_POLY_C,
         SEQ_CNT_SIZE_G => 12,
         TDEST_BITS_G   => 0)
      port map (
         axisClk     => clk,
         axisRst     => rst,
         rearbitrate => open,
         sAxisMaster => axisMaster,
         sAxisSlave  => axisSlave,
         mAxisMaster => packetizedMaster,
         mAxisSlave  => packetizedSlave);

   U_DUT : entity surf.Pgp4TxProtocol
      generic map (
         NUM_VC_G       => 1,
         SKIP_EN_G      => false,
         STARTUP_HOLD_G => 0)
      port map (
         pgpTxClk       => clk,
         pgpTxRst       => rst,
         pgpTxIn        => pgpTxIn,
         pgpTxOut       => pgpTxOut,
         pgpTxMaster    => packetizedMaster,
         pgpTxSlave     => packetizedSlave,
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
