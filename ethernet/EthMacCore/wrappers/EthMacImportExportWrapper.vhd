-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper exposing the EthMacTxExport transmit pins
--              and the EthMacRxImport receive pins separately, so the bench
--              drives and observes each PHY side with its own line model.
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

entity EthMacImportExportWrapper is
   generic (
      TPD_G          : time   := 1 ns;
      RST_POLARITY_G : sl     := '1';
      PHY_TYPE_G     : string := "XGMII";
      SYNTH_MODE_G   : string := "inferred");
   port (
      ethClk         : in  sl;
      ethRst         : in  sl;
      ethClkEn       : in  sl := '1';
      txPhyReady     : in  sl;
      rxPhyReady     : in  sl;
      -- Export AXIS input
      sAxisTValid    : in  sl;
      sAxisTData     : in  slv(127 downto 0);
      sAxisTKeep     : in  slv(15 downto 0);
      sAxisTLast     : in  sl;
      sAxisTReady    : out sl;
      sAxisSof       : in  sl;
      sAxisEofe      : in  sl;
      -- Import AXIS output (the importer has no backpressure)
      mAxisTValid    : out sl;
      mAxisTData     : out slv(127 downto 0);
      mAxisTKeep     : out slv(15 downto 0);
      mAxisTLast     : out sl;
      mAxisSof       : out sl;
      mAxisEofe      : out sl;
      -- Export PHY pins
      xgmiiTxd       : out slv(63 downto 0);
      xgmiiTxc       : out slv(7 downto 0);
      gmiiTxEn       : out sl;
      gmiiTxEr       : out sl;
      gmiiTxd        : out slv(7 downto 0);
      -- Import PHY pins
      xgmiiRxd       : in  slv(63 downto 0) := x"0707070707070707";
      xgmiiRxc       : in  slv(7 downto 0)  := x"FF";
      gmiiRxDv       : in  sl               := '0';
      gmiiRxEr       : in  sl               := '0';
      gmiiRxd        : in  slv(7 downto 0)  := (others => '0');
      -- Status
      rxCountEn      : out sl;
      rxCrcError     : out sl;
      txCountEn      : out sl;
      txUnderRun     : out sl;
      txLinkNotReady : out sl);
end entity EthMacImportExportWrapper;

architecture rtl of EthMacImportExportWrapper is

   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;

begin

   -- Flatten the export-side AXIS source.
   sAxisComb : process (sAxisEofe, sAxisSof, sAxisTData, sAxisTKeep,
                        sAxisTLast, sAxisTValid) is
      variable v : AxiStreamMasterType;
   begin
      v                     := AXI_STREAM_MASTER_INIT_C;
      v.tValid              := sAxisTValid;
      v.tData(127 downto 0) := sAxisTData;
      v.tKeep(15 downto 0)  := sAxisTKeep;
      v.tLast               := sAxisTLast;
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_SOF_BIT_C, sAxisSof, 0);
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_EOFE_BIT_C, sAxisEofe);
      sAxisMaster           <= v;
   end process sAxisComb;

   sAxisTReady <= sAxisSlave.tReady;

   -- Re-expand the import-side AXIS stream.
   mAxisView : process (mAxisMaster) is
   begin
      mAxisTValid <= mAxisMaster.tValid;
      mAxisTData  <= mAxisMaster.tData(127 downto 0);
      mAxisTKeep  <= mAxisMaster.tKeep(15 downto 0);
      mAxisTLast  <= mAxisMaster.tLast;
      mAxisSof    <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mAxisMaster, EMAC_SOF_BIT_C, 0);
      mAxisEofe   <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mAxisMaster, EMAC_EOFE_BIT_C);
   end process mAxisView;

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
         xlgmiiTxd      => open,
         xlgmiiTxc      => open,
         xgmiiTxd       => xgmiiTxd,
         xgmiiTxc       => xgmiiTxc,
         gmiiTxEn       => gmiiTxEn,
         gmiiTxEr       => gmiiTxEr,
         gmiiTxd        => gmiiTxd,
         phyReady       => txPhyReady,
         txCountEn      => txCountEn,
         txUnderRun     => txUnderRun,
         txLinkNotReady => txLinkNotReady);

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
         xlgmiiRxd   => (others => '0'),
         xlgmiiRxc   => (others => '0'),
         xgmiiRxd    => xgmiiRxd,
         xgmiiRxc    => xgmiiRxc,
         gmiiRxDv    => gmiiRxDv,
         gmiiRxEr    => gmiiRxEr,
         gmiiRxd     => gmiiRxd,
         phyReady    => rxPhyReady,
         rxCountEn   => rxCountEn,
         rxCrcError  => rxCrcError);

end architecture rtl;
