-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for EthMacRxBypass
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

entity EthMacRxBypassWrapper is
   generic (
      TPD_G          : time             := 1 ns;
      RST_POLARITY_G : sl               := '1';
      RST_ASYNC_G    : boolean          := false;
      BYP_EN_G       : boolean          := false;
      BYP_ETH_TYPE_G : slv(15 downto 0) := x"0090");
   port (
      ethClk       : in  sl;
      ethRst       : in  sl;
      sAxisTValid  : in  sl;
      sAxisTData   : in  slv(127 downto 0);
      sAxisTKeep   : in  slv(15 downto 0);
      sAxisTLast   : in  sl;
      sAxisTDest   : in  slv(7 downto 0);
      sAxisTReady  : out sl;
      sAxisSof     : in  sl;
      sAxisEofe    : in  sl;
      mPrimTValid  : out sl;
      mPrimTData   : out slv(127 downto 0);
      mPrimTKeep   : out slv(15 downto 0);
      mPrimTLast   : out sl;
      mPrimTDest   : out slv(7 downto 0);
      mPrimSof     : out sl;
      mPrimEofe    : out sl;
      mBypTValid   : out sl;
      mBypTData    : out slv(127 downto 0);
      mBypTKeep    : out slv(15 downto 0);
      mBypTLast    : out sl;
      mBypTDest    : out slv(7 downto 0);
      mBypSof      : out sl;
      mBypEofe     : out sl);
end entity EthMacRxBypassWrapper;

architecture rtl of EthMacRxBypassWrapper is

   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mPrimMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mBypMaster  : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;

begin

   sAxisComb : process (sAxisEofe, sAxisSof, sAxisTData, sAxisTDest, sAxisTKeep, sAxisTLast, sAxisTValid) is
      variable v : AxiStreamMasterType;
   begin
      v := AXI_STREAM_MASTER_INIT_C;
      v.tValid := sAxisTValid;
      v.tData(127 downto 0) := sAxisTData;
      v.tKeep(15 downto 0) := sAxisTKeep;
      v.tLast := sAxisTLast;
      v.tDest(7 downto 0) := sAxisTDest;
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_SOF_BIT_C, sAxisSof, 0);
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_EOFE_BIT_C, sAxisEofe);
      sAxisMaster <= v;
   end process sAxisComb;

   sAxisTReady <= '1';

   mPrimView : process (mPrimMaster) is
   begin
      mPrimTValid <= mPrimMaster.tValid;
      mPrimTData <= mPrimMaster.tData(127 downto 0);
      mPrimTKeep <= mPrimMaster.tKeep(15 downto 0);
      mPrimTLast <= mPrimMaster.tLast;
      mPrimTDest <= mPrimMaster.tDest(7 downto 0);
      mPrimSof <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mPrimMaster, EMAC_SOF_BIT_C, 0);
      mPrimEofe <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mPrimMaster, EMAC_EOFE_BIT_C);
   end process mPrimView;

   mBypView : process (mBypMaster) is
   begin
      mBypTValid <= mBypMaster.tValid;
      mBypTData <= mBypMaster.tData(127 downto 0);
      mBypTKeep <= mBypMaster.tKeep(15 downto 0);
      mBypTLast <= mBypMaster.tLast;
      mBypTDest <= mBypMaster.tDest(7 downto 0);
      mBypSof <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mBypMaster, EMAC_SOF_BIT_C, 0);
      mBypEofe <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mBypMaster, EMAC_EOFE_BIT_C);
   end process mBypView;

   U_DUT : entity surf.EthMacRxBypass
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         BYP_EN_G       => BYP_EN_G,
         BYP_ETH_TYPE_G => BYP_ETH_TYPE_G)
      port map (
         ethClk      => ethClk,
         ethRst      => ethRst,
         sAxisMaster => sAxisMaster,
         mPrimMaster => mPrimMaster,
         mBypMaster  => mBypMaster);

end architecture rtl;
