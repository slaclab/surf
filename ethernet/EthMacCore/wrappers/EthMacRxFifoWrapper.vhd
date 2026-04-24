-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for EthMacRxFifo
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

entity EthMacRxFifoWrapper is
   generic (
      TPD_G             : time                   := 1 ns;
      RST_POLARITY_G    : sl                     := '1';
      RST_ASYNC_G       : boolean                := false;
      SYNTH_MODE_G      : string                 := "inferred";
      MEMORY_TYPE_G     : string                 := "block";
      DROP_ERR_PKT_G    : boolean                := true;
      INT_PIPE_STAGES_G : natural                := 1;
      PIPE_STAGES_G     : natural                := 1;
      FIFO_ADDR_WIDTH_G : positive range 9 to 16 := 11;
      PRIM_COMMON_CLK_G : boolean                := false);
   port (
      sClk           : in  sl;
      sRst           : in  sl;
      mPrimClk       : in  sl;
      mPrimRst       : in  sl;
      phyReady       : in  sl;
      pauseThresh    : in  slv(15 downto 0);
      rxFifoDrop     : out sl;
      sAxisTValid    : in  sl;
      sAxisTData     : in  slv(127 downto 0);
      sAxisTKeep     : in  slv(15 downto 0);
      sAxisTLast     : in  sl;
      sAxisTReady    : out sl;
      sAxisSof       : in  sl;
      sAxisFrag      : in  sl;
      sAxisEofe      : in  sl;
      sAxisIpErr     : in  sl;
      sAxisTcpErr    : in  sl;
      sAxisUdpErr    : in  sl;
      sAxisPause     : out sl;
      sAxisOverflow  : out sl;
      mAxisTValid    : out sl;
      mAxisTData     : out slv(127 downto 0);
      mAxisTKeep     : out slv(15 downto 0);
      mAxisTLast     : out sl;
      mAxisTReady    : in  sl := '1';
      mAxisSof       : out sl;
      mAxisFrag      : out sl;
      mAxisEofe      : out sl;
      mAxisIpErr     : out sl;
      mAxisTcpErr    : out sl;
      mAxisUdpErr    : out sl);
end entity EthMacRxFifoWrapper;

architecture rtl of EthMacRxFifoWrapper is

   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisCtrl   : AxiStreamCtrlType   := AXI_STREAM_CTRL_INIT_C;
   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

begin

   -- The RX-side FIFO input is not backpressured by `TREADY`, so the wrapper
   -- ties the source ready high and exposes the real pause/overflow controls
   -- separately for observation in the sClk domain.
   sAxisComb : process (sAxisEofe, sAxisFrag, sAxisIpErr, sAxisSof, sAxisTData, sAxisTcpErr, sAxisTKeep, sAxisTLast, sAxisTValid, sAxisUdpErr) is
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
      axiStreamSetUserBit(INT_EMAC_AXIS_CONFIG_C, v, EMAC_IPERR_BIT_C, sAxisIpErr);
      axiStreamSetUserBit(INT_EMAC_AXIS_CONFIG_C, v, EMAC_TCPERR_BIT_C, sAxisTcpErr);
      axiStreamSetUserBit(INT_EMAC_AXIS_CONFIG_C, v, EMAC_UDPERR_BIT_C, sAxisUdpErr);
      sAxisMaster <= v;
   end process sAxisComb;

   sAxisTReady <= '1';
   sAxisPause <= sAxisCtrl.pause;
   sAxisOverflow <= sAxisCtrl.overflow;
   mAxisSlave.tReady <= mAxisTReady;

   -- Re-expand the primary output stream after the FIFO crossing.
   mAxisView : process (mAxisMaster) is
   begin
      mAxisTValid <= mAxisMaster.tValid;
      mAxisTData <= mAxisMaster.tData(127 downto 0);
      mAxisTKeep <= mAxisMaster.tKeep(15 downto 0);
      mAxisTLast <= mAxisMaster.tLast;
      mAxisSof <= axiStreamGetUserBit(INT_EMAC_AXIS_CONFIG_C, mAxisMaster, EMAC_SOF_BIT_C, 0);
      mAxisFrag <= axiStreamGetUserBit(INT_EMAC_AXIS_CONFIG_C, mAxisMaster, EMAC_FRAG_BIT_C, 0);
      mAxisEofe <= axiStreamGetUserBit(INT_EMAC_AXIS_CONFIG_C, mAxisMaster, EMAC_EOFE_BIT_C);
      mAxisIpErr <= axiStreamGetUserBit(INT_EMAC_AXIS_CONFIG_C, mAxisMaster, EMAC_IPERR_BIT_C);
      mAxisTcpErr <= axiStreamGetUserBit(INT_EMAC_AXIS_CONFIG_C, mAxisMaster, EMAC_TCPERR_BIT_C);
      mAxisUdpErr <= axiStreamGetUserBit(INT_EMAC_AXIS_CONFIG_C, mAxisMaster, EMAC_UDPERR_BIT_C);
   end process mAxisView;

   U_DUT : entity surf.EthMacRxFifo
      generic map (
         TPD_G             => TPD_G,
         RST_POLARITY_G    => RST_POLARITY_G,
         RST_ASYNC_G       => RST_ASYNC_G,
         SYNTH_MODE_G      => SYNTH_MODE_G,
         MEMORY_TYPE_G     => MEMORY_TYPE_G,
         DROP_ERR_PKT_G    => DROP_ERR_PKT_G,
         INT_PIPE_STAGES_G => INT_PIPE_STAGES_G,
         PIPE_STAGES_G     => PIPE_STAGES_G,
         FIFO_ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         PRIM_COMMON_CLK_G => PRIM_COMMON_CLK_G,
         PRIM_CONFIG_G     => INT_EMAC_AXIS_CONFIG_C,
         BYP_EN_G          => false,
         BYP_COMMON_CLK_G  => false,
         BYP_CONFIG_G      => INT_EMAC_AXIS_CONFIG_C)
      port map (
         sClk        => sClk,
         sRst        => sRst,
         phyReady    => phyReady,
         rxFifoDrop  => rxFifoDrop,
         pauseThresh => pauseThresh,
         mPrimClk    => mPrimClk,
         mPrimRst    => mPrimRst,
         sPrimMaster => sAxisMaster,
         sPrimCtrl   => sAxisCtrl,
         mPrimMaster => mAxisMaster,
         mPrimSlave  => mAxisSlave,
         mBypClk     => '0',
         mBypRst     => '0',
         sBypMaster  => AXI_STREAM_MASTER_INIT_C,
         sBypCtrl    => open,
         mBypMaster  => open,
         mBypSlave   => AXI_STREAM_SLAVE_FORCE_C);

end architecture rtl;
