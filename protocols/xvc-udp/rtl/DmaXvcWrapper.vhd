-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: XVC Wrapper for DMA applications (no XON/XOFF flow control)
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

entity DmaXvcWrapper is
   generic (
      TPD_G              : time     := 1 ns;
      COMMON_CLOCK_G     : boolean  := false;
      FIFO_ADDR_WIDTH_G  : positive := 9;
      FIFO_SYNTH_MODE_G  : string   := "inferred";
      FIFO_MEMORY_TYPE_G : string   := "block";
      DMA_AXIS_CONFIG_G  : AxiStreamConfigType);
   port (
      -- 156.25MHz XVC Clock/Reset (xvcClk156 domain)
      xvcClk156   : in  sl;
      xvcRst156   : in  sl;
      -- DMA Interface (dmaClk domain)
      dmaClk      : in  sl;
      dmaRst      : in  sl;
      dmaObMaster : in  AxiStreamMasterType;
      dmaObSlave  : out AxiStreamSlaveType;
      dmaIbMaster : out AxiStreamMasterType;
      dmaIbSlave  : in  AxiStreamSlaveType);
end DmaXvcWrapper;

architecture rtl of DmaXvcWrapper is

   signal ibXvcMaster : AxiStreamMasterType := axiStreamMasterInit(EMAC_AXIS_CONFIG_C);
   signal ibXvcSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

   signal obXvcMaster : AxiStreamMasterType := axiStreamMasterInit(EMAC_AXIS_CONFIG_C);
   signal obXvcSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

begin

   U_RX_FIFO : entity surf.AxiStreamFifoV2
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         VALID_THOLD_G       => 0,      -- 0 = only when frame ready
         -- FIFO configurations
         GEN_SYNC_FIFO_G     => COMMON_CLOCK_G,
         MEMORY_TYPE_G       => FIFO_MEMORY_TYPE_G,
         FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_G,
         SYNTH_MODE_G        => FIFO_SYNTH_MODE_G,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => DMA_AXIS_CONFIG_G,
         MASTER_AXI_CONFIG_G => EMAC_AXIS_CONFIG_C)
      port map (
         -- Slave Port
         sAxisClk    => dmaClk,
         sAxisRst    => dmaRst,
         sAxisMaster => dmaObMaster,
         sAxisSlave  => dmaObSlave,
         -- Master Port
         mAxisClk    => xvcClk156,
         mAxisRst    => xvcRst156,
         mAxisMaster => obXvcMaster,
         mAxisSlave  => obXvcSlave);

   -----------------------------------------------------------------
   -- Xilinx Virtual Cable (XVC)
   -- https://www.xilinx.com/products/intellectual-property/xvc.html
   -----------------------------------------------------------------
   U_XVC : entity surf.UdpDebugBridgeWrapper
      generic map (
         TPD_G => TPD_G)
      port map (
         -- Clock and Reset
         clk            => xvcClk156,
         rst            => xvcRst156,
         -- UDP XVC Interface
         obServerMaster => obXvcMaster,
         obServerSlave  => obXvcSlave,
         ibServerMaster => ibXvcMaster,
         ibServerSlave  => ibXvcSlave);

   U_TX_FIFO : entity surf.AxiStreamFifoV2
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         -- FIFO configurations
         GEN_SYNC_FIFO_G     => COMMON_CLOCK_G,
         MEMORY_TYPE_G       => FIFO_MEMORY_TYPE_G,
         FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_G,
         SYNTH_MODE_G        => FIFO_SYNTH_MODE_G,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => EMAC_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => DMA_AXIS_CONFIG_G)
      port map (
         -- Slave Port
         sAxisClk    => xvcClk156,
         sAxisRst    => xvcRst156,
         sAxisMaster => ibXvcMaster,
         sAxisSlave  => ibXvcSlave,
         -- Master Port
         mAxisClk    => dmaClk,
         mAxisRst    => dmaRst,
         mAxisMaster => dmaIbMaster,
         mAxisSlave  => dmaIbSlave);

end rtl;
