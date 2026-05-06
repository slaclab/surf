-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for IgmpV2Engine
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

entity IgmpV2EngineWrapper is
   generic (
      TPD_G          : time    := 1 ns;
      RST_POLARITY_G : sl      := '1';
      RST_ASYNC_G    : boolean := false;
      CLK_FREQ_G     : real    := 10.0);
   port (
      clk         : in  sl;
      rst         : in  sl;
      localIp     : in  slv(31 downto 0);
      igmpIp0     : in  slv(31 downto 0);
      igmpIp1     : in  slv(31 downto 0);
      sAxisTValid : in  sl;
      sAxisTData  : in  slv(127 downto 0);
      sAxisTKeep  : in  slv(15 downto 0);
      sAxisTLast  : in  sl;
      sAxisTReady : out sl;
      sAxisSof    : in  sl;
      sAxisEofe   : in  sl;
      mAxisTValid : out sl;
      mAxisTData  : out slv(127 downto 0);
      mAxisTKeep  : out slv(15 downto 0);
      mAxisTLast  : out sl;
      mAxisTReady : in  sl := '1';
      mAxisSof    : out sl;
      mAxisEofe   : out sl);
end entity IgmpV2EngineWrapper;

architecture rtl of IgmpV2EngineWrapper is

   signal igmpIp      : Slv32Array(1 downto 0);
   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

begin

   igmpIp(0) <= igmpIp0;
   igmpIp(1) <= igmpIp1;

   -- Flatten the IGMP pseudo-header stream presented by cocotb.
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

   sAxisTReady       <= sAxisSlave.tReady;
   mAxisSlave.tReady <= mAxisTReady;

   -- Re-expand the outbound IGMP report pseudo-header stream for checks.
   mAxisView : process (mAxisMaster) is
   begin
      mAxisTValid <= mAxisMaster.tValid;
      mAxisTData  <= mAxisMaster.tData(127 downto 0);
      mAxisTKeep  <= mAxisMaster.tKeep(15 downto 0);
      mAxisTLast  <= mAxisMaster.tLast;
      mAxisSof    <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mAxisMaster, EMAC_SOF_BIT_C, 0);
      mAxisEofe   <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mAxisMaster, EMAC_EOFE_BIT_C);
   end process mAxisView;

   U_DUT : entity surf.IgmpV2Engine
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         IGMP_GRP_SIZE  => 2,
         CLK_FREQ_G     => CLK_FREQ_G)
      port map (
         localIp      => localIp,
         igmpIp       => igmpIp,
         ibIgmpMaster => sAxisMaster,
         ibIgmpSlave  => sAxisSlave,
         obIgmpMaster => mAxisMaster,
         obIgmpSlave  => mAxisSlave,
         clk          => clk,
         rst          => rst);

end architecture rtl;
