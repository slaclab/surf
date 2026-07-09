-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for EthMacTxPause
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

entity EthMacTxPauseWrapper is
   generic (
      TPD_G           : time                    := 1 ns;
      RST_POLARITY_G  : sl                      := '1';
      RST_ASYNC_G     : boolean                 := false;
      PAUSE_EN_G      : boolean                 := true;
      PAUSE_512BITS_G : natural range 1 to 1024 := 8);
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
      mAxisTReady  : in  sl;
      mAxisSof     : out sl;
      mAxisFrag    : out sl;
      mAxisEofe    : out sl;
      clientPause  : in  sl;
      rxPauseReq   : in  sl;
      rxPauseValue : in  slv(15 downto 0);
      phyReady     : in  sl;
      pauseEnable  : in  sl;
      pauseTime    : in  slv(15 downto 0);
      macAddress   : in  slv(47 downto 0);
      pauseTx      : out sl);
end entity EthMacTxPauseWrapper;

architecture rtl of EthMacTxPauseWrapper is

   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

begin

   -- Flatten the source-side EMAC stream for cocotb.
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

   -- Flatten the DUT output so the pause-frame payload and pass-through data
   -- can be inspected without record access.
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

   U_DUT : entity surf.EthMacTxPause
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => RST_POLARITY_G,
         RST_ASYNC_G     => RST_ASYNC_G,
         PAUSE_EN_G      => PAUSE_EN_G,
         PAUSE_512BITS_G => PAUSE_512BITS_G)
      port map (
         ethClk       => ethClk,
         ethRst       => ethRst,
         sAxisMaster  => sAxisMaster,
         sAxisSlave   => sAxisSlave,
         mAxisMaster  => mAxisMaster,
         mAxisSlave   => mAxisSlave,
         clientPause  => clientPause,
         rxPauseReq   => rxPauseReq,
         rxPauseValue => rxPauseValue,
         phyReady     => phyReady,
         pauseEnable  => pauseEnable,
         pauseTime    => pauseTime,
         macAddress   => macAddress,
         pauseTx      => pauseTx);

end architecture rtl;
