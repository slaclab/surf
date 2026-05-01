-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for IpV4EngineDeMux
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

entity IpV4EngineDeMuxWrapper is
   generic (
      TPD_G          : time    := 1 ns;
      RST_POLARITY_G : sl      := '1';
      RST_ASYNC_G    : boolean := false);
   port (
      clk         : in  sl;
      rst         : in  sl;
      localMac    : in  slv(47 downto 0);
      sMacTValid  : in  sl;
      sMacTData   : in  slv(127 downto 0);
      sMacTKeep   : in  slv(15 downto 0);
      sMacTLast   : in  sl;
      sMacTReady  : out sl;
      sMacSof     : in  sl;
      sMacEofe    : in  sl;
      mArpTValid  : out sl;
      mArpTData   : out slv(127 downto 0);
      mArpTKeep   : out slv(15 downto 0);
      mArpTLast   : out sl;
      mArpTReady  : in  sl := '1';
      mArpSof     : out sl;
      mArpEofe    : out sl;
      mIpv4TValid : out sl;
      mIpv4TData  : out slv(127 downto 0);
      mIpv4TKeep  : out slv(15 downto 0);
      mIpv4TLast  : out sl;
      mIpv4TReady : in  sl := '1';
      mIpv4Sof    : out sl;
      mIpv4Eofe   : out sl);
end entity IpV4EngineDeMuxWrapper;

architecture rtl of IpV4EngineDeMuxWrapper is

   signal sMacMaster  : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sMacSlave   : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal mArpMaster  : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mArpSlave   : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal mIpv4Master : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mIpv4Slave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

begin

   -- Flatten the inbound MAC frame source for direct cocotb stimulus.
   sMacComb : process (sMacEofe, sMacSof, sMacTData, sMacTKeep, sMacTLast, sMacTValid) is
      variable v : AxiStreamMasterType;
   begin
      v := AXI_STREAM_MASTER_INIT_C;
      v.tValid := sMacTValid;
      v.tData(127 downto 0) := sMacTData;
      v.tKeep(15 downto 0) := sMacTKeep;
      v.tLast := sMacTLast;
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_SOF_BIT_C, sMacSof, 0);
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_EOFE_BIT_C, sMacEofe);
      sMacMaster <= v;
   end process sMacComb;

   sMacTReady <= sMacSlave.tReady;
   mArpSlave.tReady <= mArpTReady;
   mIpv4Slave.tReady <= mIpv4TReady;

   -- Present the selected ARP output stream as a flat cocotb-facing bus.
   mArpView : process (mArpMaster) is
   begin
      mArpTValid <= mArpMaster.tValid;
      mArpTData <= mArpMaster.tData(127 downto 0);
      mArpTKeep <= mArpMaster.tKeep(15 downto 0);
      mArpTLast <= mArpMaster.tLast;
      mArpSof <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mArpMaster, EMAC_SOF_BIT_C, 0);
      mArpEofe <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mArpMaster, EMAC_EOFE_BIT_C);
   end process mArpView;

   -- Present the selected IPv4 output stream as a second flat bus.
   mIpv4View : process (mIpv4Master) is
   begin
      mIpv4TValid <= mIpv4Master.tValid;
      mIpv4TData <= mIpv4Master.tData(127 downto 0);
      mIpv4TKeep <= mIpv4Master.tKeep(15 downto 0);
      mIpv4TLast <= mIpv4Master.tLast;
      mIpv4Sof <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mIpv4Master, EMAC_SOF_BIT_C, 0);
      mIpv4Eofe <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mIpv4Master, EMAC_EOFE_BIT_C);
   end process mIpv4View;

   U_DUT : entity surf.IpV4EngineDeMux
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G)
      port map (
         localMac     => localMac,
         obMacMaster  => sMacMaster,
         obMacSlave   => sMacSlave,
         ibArpMaster  => mArpMaster,
         ibArpSlave   => mArpSlave,
         ibIpv4Master => mIpv4Master,
         ibIpv4Slave  => mIpv4Slave,
         clk          => clk,
         rst          => rst);

end architecture rtl;
