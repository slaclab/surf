-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing loopback wrapper for EthMacTxCsum
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

entity EthMacTxCsumLoopbackWrapper is
   generic (
      TPD_G          : time    := 1 ns;
      RST_POLARITY_G : sl      := '1';
      DROP_ERR_PKT_G : boolean := true;
      JUMBO_G        : boolean := false;
      ROCEV2_EN_G    : boolean := false;
      SYNTH_MODE_G   : string  := "inferred");
   port (
      ethClk       : in  sl;
      ethRst       : in  sl;
      sAxisTValid  : in  sl;
      sAxisTData   : in  slv(127 downto 0);
      sAxisTKeep   : in  slv(15 downto 0);
      sAxisTLast   : in  sl;
      sAxisTReady  : out sl;
      sAxisSof     : in  sl;
      sAxisFrag    : in  sl;
      sAxisEofe    : in  sl;
      mAxisTValid  : out sl;
      mAxisTData   : out slv(127 downto 0);
      mAxisTKeep   : out slv(15 downto 0);
      mAxisTLast   : out sl;
      mAxisTReady  : in  sl := '1';
      mAxisSof     : out sl;
      mAxisFrag    : out sl;
      mAxisEofe    : out sl;
      mAxisIpErr   : out sl;
      mAxisTcpErr  : out sl;
      mAxisUdpErr  : out sl;
      ipCsumEn     : in  sl;
      tcpCsumEn    : in  sl;
      udpCsumEn    : in  sl);
end entity EthMacTxCsumLoopbackWrapper;

architecture rtl of EthMacTxCsumLoopbackWrapper is

   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal txAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal txAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal mAxisMaster  : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;

begin

   -- Flatten the source packet stream that will be repaired by TxCsum.
   sAxisComb : process (sAxisEofe, sAxisFrag, sAxisSof, sAxisTData, sAxisTKeep, sAxisTLast, sAxisTValid) is
      variable v : AxiStreamMasterType;
   begin
      v := AXI_STREAM_MASTER_INIT_C;
      v.tValid := sAxisTValid;
      v.tData(127 downto 0) := sAxisTData;
      v.tKeep(15 downto 0) := sAxisTKeep;
      v.tLast := sAxisTLast;
      axiStreamSetUserBit(INT_EMAC_AXIS_CONFIG_C, v, EMAC_SOF_BIT_C, sAxisSof, 0);
      axiStreamSetUserBit(INT_EMAC_AXIS_CONFIG_C, v, EMAC_FRAG_BIT_C, sAxisFrag, 0);
      axiStreamSetUserBit(INT_EMAC_AXIS_CONFIG_C, v, EMAC_EOFE_BIT_C, sAxisEofe);
      sAxisMaster <= v;
   end process sAxisComb;

   sAxisTReady <= sAxisSlave.tReady;
   txAxisSlave.tReady <= '1';

   -- Present the post-checker stream to cocotb so the test can confirm the
   -- repaired packet exits without RX-side checksum errors.
   mAxisView : process (mAxisMaster) is
   begin
      mAxisTValid <= mAxisMaster.tValid;
      mAxisTData <= mAxisMaster.tData(127 downto 0);
      mAxisTKeep <= mAxisMaster.tKeep(15 downto 0);
      mAxisTLast <= mAxisMaster.tLast;
      mAxisSof <= axiStreamGetUserBit(INT_EMAC_AXIS_CONFIG_C, mAxisMaster, EMAC_SOF_BIT_C, 0);
      mAxisFrag <= axiStreamGetUserBit(INT_EMAC_AXIS_CONFIG_C, mAxisMaster, EMAC_FRAG_BIT_C, 0);
      mAxisEofe <= axiStreamGetUserBit(INT_EMAC_AXIS_CONFIG_C, mAxisMaster, EMAC_EOFE_BIT_C);
      mAxisIpErr <= axiStreamGetUserBit(INT_EMAC_AXIS_CONFIG_C, mAxisMaster, EMAC_IPERR_BIT_C);
      mAxisTcpErr <= axiStreamGetUserBit(INT_EMAC_AXIS_CONFIG_C, mAxisMaster, EMAC_TCPERR_BIT_C);
      mAxisUdpErr <= axiStreamGetUserBit(INT_EMAC_AXIS_CONFIG_C, mAxisMaster, EMAC_UDPERR_BIT_C);
   end process mAxisView;

   U_TxCsum : entity surf.EthMacTxCsum
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
         mAxisMaster => txAxisMaster,
         mAxisSlave  => txAxisSlave);

   U_RxCheck : entity surf.EthMacRxCsum
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => false,
         JUMBO_G        => JUMBO_G,
         ROCEV2_EN_G    => ROCEV2_EN_G)
      port map (
         ethClk      => ethClk,
         ethRst      => ethRst,
         ipCsumEn    => ipCsumEn,
         tcpCsumEn   => tcpCsumEn,
         udpCsumEn   => udpCsumEn,
         sAxisMaster => txAxisMaster,
         mAxisMaster => mAxisMaster);

end architecture rtl;
