-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for EthMacRxFilter
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

entity EthMacRxFilterWrapper is
   generic (
      TPD_G          : time    := 1 ns;
      RST_POLARITY_G : sl      := '1';
      RST_ASYNC_G    : boolean := false;
      FILT_EN_G      : boolean := true);
   port (
      ethClk        : in  sl;
      ethRst        : in  sl;
      sAxisTValid   : in  sl;
      sAxisTData    : in  slv(127 downto 0);
      sAxisTKeep    : in  slv(15 downto 0);
      sAxisTLast    : in  sl;
      sAxisTReady   : out sl;
      sAxisSof      : in  sl;
      sAxisFrag     : in  sl;
      sAxisEofe     : in  sl;
      mAxisTValid   : out sl;
      mAxisTData    : out slv(127 downto 0);
      mAxisTKeep    : out slv(15 downto 0);
      mAxisTLast    : out sl;
      mAxisTReady   : in  sl := '1';
      mAxisSof      : out sl;
      mAxisFrag     : out sl;
      mAxisEofe     : out sl;
      mAxisPause    : in  sl;
      dropOnPause   : in  sl;
      macAddress    : in  slv(47 downto 0);
      filtEnable    : in  sl);
end entity EthMacRxFilterWrapper;

architecture rtl of EthMacRxFilterWrapper is

   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisCtrl   : AxiStreamCtrlType   := AXI_STREAM_CTRL_INIT_C;

begin

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

   sAxisTReady <= '1';
   mAxisCtrl.pause <= mAxisPause;
   mAxisCtrl.overflow <= '0';
   mAxisCtrl.idle <= '0';

   mAxisView : process (mAxisMaster) is
   begin
      mAxisTValid <= mAxisMaster.tValid;
      mAxisTData <= mAxisMaster.tData(127 downto 0);
      mAxisTKeep <= mAxisMaster.tKeep(15 downto 0);
      mAxisTLast <= mAxisMaster.tLast;
      mAxisSof <= axiStreamGetUserBit(INT_EMAC_AXIS_CONFIG_C, mAxisMaster, EMAC_SOF_BIT_C, 0);
      mAxisFrag <= axiStreamGetUserBit(INT_EMAC_AXIS_CONFIG_C, mAxisMaster, EMAC_FRAG_BIT_C, 0);
      mAxisEofe <= axiStreamGetUserBit(INT_EMAC_AXIS_CONFIG_C, mAxisMaster, EMAC_EOFE_BIT_C);
   end process mAxisView;

   U_DUT : entity surf.EthMacRxFilter
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         FILT_EN_G      => FILT_EN_G)
      port map (
         ethClk      => ethClk,
         ethRst      => ethRst,
         sAxisMaster => sAxisMaster,
         mAxisMaster => mAxisMaster,
         mAxisCtrl   => mAxisCtrl,
         dropOnPause => dropOnPause,
         macAddress  => macAddress,
         filtEnable  => filtEnable);

end architecture rtl;
