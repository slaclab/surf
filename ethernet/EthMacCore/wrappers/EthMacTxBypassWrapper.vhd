-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for EthMacTxBypass
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

entity EthMacTxBypassWrapper is
   generic (
      TPD_G          : time    := 1 ns;
      RST_POLARITY_G : sl      := '1';
      BYP_EN_G       : boolean := false);
   port (
      ethClk      : in  sl;
      ethRst      : in  sl;
      sPrimTValid : in  sl;
      sPrimTData  : in  slv(127 downto 0);
      sPrimTKeep  : in  slv(15 downto 0);
      sPrimTLast  : in  sl;
      sPrimTDest  : in  slv(7 downto 0);
      sPrimTReady : out sl;
      sPrimSof    : in  sl;
      sPrimEofe   : in  sl;
      sBypTValid  : in  sl;
      sBypTData   : in  slv(127 downto 0);
      sBypTKeep   : in  slv(15 downto 0);
      sBypTLast   : in  sl;
      sBypTDest   : in  slv(7 downto 0);
      sBypTReady  : out sl;
      sBypSof     : in  sl;
      sBypEofe    : in  sl;
      mAxisTValid : out sl;
      mAxisTData  : out slv(127 downto 0);
      mAxisTKeep  : out slv(15 downto 0);
      mAxisTLast  : out sl;
      mAxisTDest  : out slv(7 downto 0);
      mAxisTReady : in  sl := '1';
      mAxisSof    : out sl;
      mAxisEofe   : out sl);
end entity EthMacTxBypassWrapper;

architecture rtl of EthMacTxBypassWrapper is

   signal sPrimMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sPrimSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal sBypMaster  : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sBypSlave   : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

begin

   sPrimComb : process (sPrimEofe, sPrimSof, sPrimTData, sPrimTDest,
                        sPrimTKeep, sPrimTLast, sPrimTValid) is
      variable v : AxiStreamMasterType;
   begin
      v                     := AXI_STREAM_MASTER_INIT_C;
      v.tValid              := sPrimTValid;
      v.tData(127 downto 0) := sPrimTData;
      v.tKeep(15 downto 0)  := sPrimTKeep;
      v.tLast               := sPrimTLast;
      v.tDest(7 downto 0)   := sPrimTDest;
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_SOF_BIT_C, sPrimSof, 0);
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_EOFE_BIT_C, sPrimEofe);
      sPrimMaster           <= v;
   end process sPrimComb;

   sBypComb : process (sBypEofe, sBypSof, sBypTData, sBypTDest, sBypTKeep,
                       sBypTLast, sBypTValid) is
      variable v : AxiStreamMasterType;
   begin
      v                     := AXI_STREAM_MASTER_INIT_C;
      v.tValid              := sBypTValid;
      v.tData(127 downto 0) := sBypTData;
      v.tKeep(15 downto 0)  := sBypTKeep;
      v.tLast               := sBypTLast;
      v.tDest(7 downto 0)   := sBypTDest;
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_SOF_BIT_C, sBypSof, 0);
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_EOFE_BIT_C, sBypEofe);
      sBypMaster            <= v;
   end process sBypComb;

   mAxisSlave.tReady <= mAxisTReady;

   sPrimTReady <= sPrimSlave.tReady;
   sBypTReady  <= sBypSlave.tReady;

   mAxisView : process (mAxisMaster) is
   begin
      mAxisTValid <= mAxisMaster.tValid;
      mAxisTData  <= mAxisMaster.tData(127 downto 0);
      mAxisTKeep  <= mAxisMaster.tKeep(15 downto 0);
      mAxisTLast  <= mAxisMaster.tLast;
      mAxisTDest  <= mAxisMaster.tDest(7 downto 0);
      mAxisSof    <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mAxisMaster, EMAC_SOF_BIT_C, 0);
      mAxisEofe   <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mAxisMaster, EMAC_EOFE_BIT_C);
   end process mAxisView;

   U_DUT : entity surf.EthMacTxBypass
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         BYP_EN_G       => BYP_EN_G)
      port map (
         ethClk      => ethClk,
         ethRst      => ethRst,
         sPrimMaster => sPrimMaster,
         sPrimSlave  => sPrimSlave,
         sBypMaster  => sBypMaster,
         sBypSlave   => sBypSlave,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);

end architecture rtl;
