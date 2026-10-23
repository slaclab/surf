-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for RawEthFramerTx
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

entity RawEthFramerTxFlatWrapper is
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
      sAppTValid : in  sl;
      sAppTData  : in  slv(63 downto 0);
      sAppTKeep  : in  slv(7 downto 0);
      sAppTLast  : in  sl;
      sAppTReady : out sl;
      sAppTDest  : in  slv(7 downto 0);
      sAppSof    : in  sl;
      sAppBcf    : in  sl;
      sAppEofe   : in  sl;
      mMacTValid : out sl;
      mMacTData  : out slv(63 downto 0);
      mMacTKeep  : out slv(7 downto 0);
      mMacTLast  : out sl;
      mMacTReady : in  sl := '1';
      mMacSof    : out sl;
      mMacEofe   : out sl);
end entity RawEthFramerTxFlatWrapper;

architecture rtl of RawEthFramerTxFlatWrapper is

   signal sAppMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAppSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal mMacMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mMacSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

begin

   ---------------------------------------------------------------------------
   -- Stream flattening
   ---------------------------------------------------------------------------
   sAppComb : process (sAppBcf, sAppEofe, sAppSof, sAppTData, sAppTDest,
                       sAppTKeep, sAppTLast, sAppTValid) is
      variable v : AxiStreamMasterType;
   begin
      v                    := AXI_STREAM_MASTER_INIT_C;
      v.tValid             := sAppTValid;
      v.tData(63 downto 0) := sAppTData;
      v.tKeep(7 downto 0)  := sAppTKeep;
      v.tLast              := sAppTLast;
      v.tDest(7 downto 0)  := sAppTDest;
      ssiSetUserSof(RAW_ETH_CONFIG_INIT_C, v, sAppSof);
      ssiSetUserBcf(RAW_ETH_CONFIG_INIT_C, v, sAppBcf);
      ssiSetUserEofe(RAW_ETH_CONFIG_INIT_C, v, sAppEofe);
      sAppMaster           <= v;
   end process sAppComb;

   sAppTReady       <= sAppSlave.tReady;
   mMacSlave.tReady <= mMacTReady;

   ---------------------------------------------------------------------------
   -- Output flattening
   ---------------------------------------------------------------------------
   mMacView : process (mMacMaster) is
   begin
      mMacTValid <= mMacMaster.tValid;
      mMacTData  <= mMacMaster.tData(63 downto 0);
      mMacTKeep  <= mMacMaster.tKeep(7 downto 0);
      mMacTLast  <= mMacMaster.tLast;
      mMacSof    <= ssiGetUserSof(RAW_ETH_CONFIG_INIT_C, mMacMaster);
      mMacEofe   <= ssiGetUserEofe(RAW_ETH_CONFIG_INIT_C, mMacMaster);
   end process mMacView;

   ---------------------------------------------------------------------------
   -- DUT instantiation
   ---------------------------------------------------------------------------
   U_DUT : entity surf.RawEthFramerTx
      generic map (
         TPD_G      => TPD_G,
         ETH_TYPE_G => ETH_TYPE_G)
      port map (
         localMac    => localMac,
         remoteMac   => remoteMac,
         tDest       => tDest,
         req         => req,
         ack         => ack,
         ibMacMaster => mMacMaster,
         ibMacSlave  => mMacSlave,
         obAppMaster => sAppMaster,
         obAppSlave  => sAppSlave,
         clk         => clk,
         rst         => rst);

end architecture rtl;
