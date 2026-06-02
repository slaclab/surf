-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for RawEthFramerRx
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
use surf.RawEthFramerPkg.all;

entity RawEthFramerRxFlatWrapper is
   generic (
      TPD_G      : time             := 1 ns;
      ETH_TYPE_G : slv(15 downto 0) := x"0010");
   port (
      clk        : in  sl;
      rst        : in  sl;
      localMac   : in  slv(47 downto 0);
      remoteMac  : in  slv(47 downto 0);
      req        : out sl;
      ack        : in  sl;
      tDest      : out slv(7 downto 0);
      sMacTValid : in  sl;
      sMacTData  : in  slv(63 downto 0);
      sMacTKeep  : in  slv(7 downto 0);
      sMacTLast  : in  sl;
      sMacTReady : out sl;
      sMacSof    : in  sl;
      sMacEofe   : in  sl;
      mAppTValid : out sl;
      mAppTData  : out slv(63 downto 0);
      mAppTKeep  : out slv(7 downto 0);
      mAppTLast  : out sl;
      mAppTReady : in  sl := '1';
      mAppTDest  : out slv(7 downto 0);
      mAppSof    : out sl;
      mAppBcf    : out sl;
      mAppEofe   : out sl);
end entity RawEthFramerRxFlatWrapper;

architecture rtl of RawEthFramerRxFlatWrapper is

   signal sMacMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sMacSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal mAppMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAppSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

begin

   ---------------------------------------------------------------------------
   -- Stream flattening
   ---------------------------------------------------------------------------
   sMacComb : process (sMacEofe, sMacSof, sMacTData, sMacTKeep, sMacTLast,
                       sMacTValid) is
      variable v : AxiStreamMasterType;
   begin
      v                    := AXI_STREAM_MASTER_INIT_C;
      v.tValid             := sMacTValid;
      v.tData(63 downto 0) := sMacTData;
      v.tKeep(7 downto 0)  := sMacTKeep;
      v.tLast              := sMacTLast;
      ssiSetUserSof(RAW_ETH_CONFIG_INIT_C, v, sMacSof);
      ssiSetUserEofe(RAW_ETH_CONFIG_INIT_C, v, sMacEofe);
      sMacMaster           <= v;
   end process sMacComb;

   sMacTReady       <= sMacSlave.tReady;
   mAppSlave.tReady <= mAppTReady;

   ---------------------------------------------------------------------------
   -- Output flattening
   ---------------------------------------------------------------------------
   mAppView : process (mAppMaster) is
   begin
      mAppTValid <= mAppMaster.tValid;
      mAppTData  <= mAppMaster.tData(63 downto 0);
      mAppTKeep  <= mAppMaster.tKeep(7 downto 0);
      mAppTLast  <= mAppMaster.tLast;
      mAppTDest  <= mAppMaster.tDest(7 downto 0);
      mAppSof    <= ssiGetUserSof(RAW_ETH_CONFIG_INIT_C, mAppMaster);
      mAppBcf    <= ssiGetUserBcf(RAW_ETH_CONFIG_INIT_C, mAppMaster);
      mAppEofe   <= ssiGetUserEofe(RAW_ETH_CONFIG_INIT_C, mAppMaster);
   end process mAppView;

   ---------------------------------------------------------------------------
   -- DUT instantiation
   ---------------------------------------------------------------------------
   U_DUT : entity surf.RawEthFramerRx
      generic map (
         TPD_G      => TPD_G,
         ETH_TYPE_G => ETH_TYPE_G)
      port map (
         localMac    => localMac,
         remoteMac   => remoteMac,
         tDest       => tDest,
         req         => req,
         ack         => ack,
         obMacMaster => sMacMaster,
         obMacSlave  => sMacSlave,
         ibAppMaster => mAppMaster,
         ibAppSlave  => mAppSlave,
         clk         => clk,
         rst         => rst);

end architecture rtl;
