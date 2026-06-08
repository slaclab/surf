-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing EthMac import/export loopback wrapper
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

entity EthMacImportExportLoopbackWrapper is
   generic (
      TPD_G          : time   := 1 ns;
      RST_POLARITY_G : sl     := '1';
      PHY_TYPE_G     : string := "XGMII";
      SYNTH_MODE_G   : string := "inferred");
   port (
      ethClk         : in  sl;
      ethRst         : in  sl;
      ethClkEn       : in  sl := '1';
      phyReady       : in  sl;
      sAxisTValid    : in  sl;
      sAxisTData     : in  slv(127 downto 0);
      sAxisTKeep     : in  slv(15 downto 0);
      sAxisTLast     : in  sl;
      sAxisTDest     : in  slv(7 downto 0);
      sAxisTReady    : out sl;
      sAxisSof       : in  sl;
      sAxisEofe      : in  sl;
      mAxisTValid    : out sl;
      mAxisTData     : out slv(127 downto 0);
      mAxisTKeep     : out slv(15 downto 0);
      mAxisTLast     : out sl;
      mAxisTDest     : out slv(7 downto 0);
      mAxisTReady    : in  sl := '1';
      mAxisSof       : out sl;
      mAxisEofe      : out sl;
      rxCountEn      : out sl;
      rxCrcError     : out sl;
      txCountEn      : out sl;
      txUnderRun     : out sl;
      txLinkNotReady : out sl);
end entity EthMacImportExportLoopbackWrapper;

architecture rtl of EthMacImportExportLoopbackWrapper is

   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;

   signal xlgmiiTxd : slv(127 downto 0) := (others => '0');
   signal xlgmiiTxc : slv(15 downto 0)  := (others => '0');
   signal xgmiiTxd  : slv(63 downto 0)  := (others => '0');
   signal xgmiiTxc  : slv(7 downto 0)   := (others => '0');
   signal gmiiTxEn  : sl                := '0';
   signal gmiiTxEr  : sl                := '0';
   signal gmiiTxd   : slv(7 downto 0)   := (others => '0');

begin

   -- Flatten the source stream for the export-side stimulus path.
   sAxisComb : process (sAxisEofe, sAxisSof, sAxisTData, sAxisTDest,
                        sAxisTKeep, sAxisTLast, sAxisTValid) is
      variable v : AxiStreamMasterType;
   begin
      v                     := AXI_STREAM_MASTER_INIT_C;
      v.tValid              := sAxisTValid;
      v.tData(127 downto 0) := sAxisTData;
      v.tKeep(15 downto 0)  := sAxisTKeep;
      v.tLast               := sAxisTLast;
      v.tDest(7 downto 0)   := sAxisTDest;
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_SOF_BIT_C, sAxisSof, 0);
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_EOFE_BIT_C, sAxisEofe);
      sAxisMaster           <= v;
   end process sAxisComb;

   sAxisTReady <= sAxisSlave.tReady;

   -- Export the recovered AXIS frame from the import-side DUT.
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

   -- Generate the PHY-coded stream from a clean AXIS packet source.
   U_Tx : entity surf.EthMacTxExport
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         PHY_TYPE_G     => PHY_TYPE_G,
         SYNTH_MODE_G   => SYNTH_MODE_G)
      port map (
         ethClkEn       => ethClkEn,
         ethClk         => ethClk,
         ethRst         => ethRst,
         macObMaster    => sAxisMaster,
         macObSlave     => sAxisSlave,
         xlgmiiTxd      => xlgmiiTxd,
         xlgmiiTxc      => xlgmiiTxc,
         xgmiiTxd       => xgmiiTxd,
         xgmiiTxc       => xgmiiTxc,
         gmiiTxEn       => gmiiTxEn,
         gmiiTxEr       => gmiiTxEr,
         gmiiTxd        => gmiiTxd,
         phyReady       => phyReady,
         txCountEn      => txCountEn,
         txUnderRun     => txUnderRun,
         txLinkNotReady => txLinkNotReady);

   -- Feed the generated PHY stream into the import-side DUT under test.
   U_Rx : entity surf.EthMacRxImport
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         PHY_TYPE_G     => PHY_TYPE_G,
         SYNTH_MODE_G   => SYNTH_MODE_G)
      port map (
         ethClkEn    => ethClkEn,
         ethClk      => ethClk,
         ethRst      => ethRst,
         macIbMaster => mAxisMaster,
         xlgmiiRxd   => xlgmiiTxd,
         xlgmiiRxc   => xlgmiiTxc,
         xgmiiRxd    => xgmiiTxd,
         xgmiiRxc    => xgmiiTxc,
         gmiiRxDv    => gmiiTxEn,
         gmiiRxEr    => gmiiTxEr,
         gmiiRxd     => gmiiTxd,
         phyReady    => phyReady,
         rxCountEn   => rxCountEn,
         rxCrcError  => rxCrcError);

end architecture rtl;
