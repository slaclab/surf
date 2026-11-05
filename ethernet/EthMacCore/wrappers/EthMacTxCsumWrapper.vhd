-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for EthMacTxCsum with direct output
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
use surf.EthMacPkg.all;

entity EthMacTxCsumWrapper is
   generic (
      TPD_G          : time    := 1 ns;
      RST_POLARITY_G : sl      := '1';
      DROP_ERR_PKT_G : boolean := true;
      JUMBO_G        : boolean := false;
      ROCEV2_EN_G    : boolean := false;
      SYNTH_MODE_G   : string  := "inferred");
   port (
      ethClk      : in  sl;
      ethRst      : in  sl;
      sAxisTValid : in  sl;
      sAxisTData  : in  slv(127 downto 0);
      sAxisTKeep  : in  slv(15 downto 0);
      sAxisTLast  : in  sl;
      sAxisTReady : out sl;
      sAxisSof    : in  sl;
      sAxisFrag   : in  sl;
      sAxisEofe   : in  sl;
      mAxisTValid : out sl;
      mAxisTData  : out slv(127 downto 0);
      mAxisTKeep  : out slv(15 downto 0);
      mAxisTLast  : out sl;
      mAxisTReady : in  sl := '1';
      mAxisSof    : out sl;
      mAxisFrag   : out sl;
      mAxisEofe   : out sl;
      ipCsumEn    : in  sl;
      tcpCsumEn   : in  sl;
      udpCsumEn   : in  sl);
end entity EthMacTxCsumWrapper;

architecture rtl of EthMacTxCsumWrapper is

   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

begin

   -- Flatten the source packet stream that will be repaired by TxCsum.
   sAxisComb : process (sAxisEofe, sAxisFrag, sAxisSof, sAxisTData, sAxisTKeep,
                        sAxisTLast, sAxisTValid) is
      variable v : AxiStreamMasterType;
   begin
      v                     := AXI_STREAM_MASTER_INIT_C;
      v.tValid              := sAxisTValid;
      v.tData(127 downto 0) := sAxisTData;
      v.tKeep(15 downto 0)  := sAxisTKeep;
      v.tLast               := sAxisTLast;
      axiStreamSetUserBit(INT_EMAC_AXIS_CONFIG_C, v, EMAC_SOF_BIT_C, sAxisSof, 0);
      axiStreamSetUserBit(INT_EMAC_AXIS_CONFIG_C, v, EMAC_FRAG_BIT_C, sAxisFrag, 0);
      axiStreamSetUserBit(INT_EMAC_AXIS_CONFIG_C, v, EMAC_EOFE_BIT_C, sAxisEofe);
      sAxisMaster           <= v;
   end process sAxisComb;

   sAxisTReady       <= sAxisSlave.tReady;
   mAxisSlave.tReady <= mAxisTReady;

   -- Present the TxCsum output directly so EOFE and backpressure are visible
   -- without an RX checker rewriting the sideband bits.
   mAxisView : process (mAxisMaster) is
   begin
      mAxisTValid <= mAxisMaster.tValid;
      mAxisTData  <= mAxisMaster.tData(127 downto 0);
      mAxisTKeep  <= mAxisMaster.tKeep(15 downto 0);
      mAxisTLast  <= mAxisMaster.tLast;
      mAxisSof    <= axiStreamGetUserBit(INT_EMAC_AXIS_CONFIG_C, mAxisMaster, EMAC_SOF_BIT_C, 0);
      mAxisFrag   <= axiStreamGetUserBit(INT_EMAC_AXIS_CONFIG_C, mAxisMaster, EMAC_FRAG_BIT_C, 0);
      mAxisEofe   <= axiStreamGetUserBit(INT_EMAC_AXIS_CONFIG_C, mAxisMaster, EMAC_EOFE_BIT_C);
   end process mAxisView;

   U_DUT : entity surf.EthMacTxCsum
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         DROP_ERR_PKT_G => DROP_ERR_PKT_G,
         JUMBO_G        => JUMBO_G,
         ROCEV2_EN_G    => ROCEV2_EN_G,
         SYNTH_MODE_G   => SYNTH_MODE_G)
      port map (
         ethClk      => ethClk,
         ethRst      => ethRst,
         ipCsumEn    => ipCsumEn,
         tcpCsumEn   => tcpCsumEn,
         udpCsumEn   => udpCsumEn,
         sAxisMaster => sAxisMaster,
         sAxisSlave  => sAxisSlave,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);

end architecture rtl;
