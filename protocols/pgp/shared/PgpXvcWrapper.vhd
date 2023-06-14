-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: XVC Wrapper
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

entity PgpXvcWrapper is
   generic (
      TPD_G            : time    := 1 ns;
      SIMULATION_G     : boolean := false;
      AXIS_CLK_FREQ_G  : real    := 156.25e6;
      PHY_AXI_CONFIG_G : AxiStreamConfigType);
   port (
      -- Clock and Reset (xvcClk domain)
      xvcClk      : in  sl;
      xvcRst      : in  sl;
      -- Clock and Reset (pgpClk domain)
      pgpClk      : in  sl;
      pgpRst      : in  sl;
      -- PGP Interface (pgpClk domain)
      rxlinkReady : in  sl;
      txlinkReady : in  sl;
      -- TX FIFO  (pgpClk domain)
      pgpTxMaster : out AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
      pgpTxSlave  : in  AxiStreamSlaveType;
      -- RX FIFO  (pgpClk domain)
      pgpRxMaster : in  AxiStreamMasterType;
      pgpRxCtrl   : out AxiStreamCtrlType   := AXI_STREAM_CTRL_UNUSED_C);
end PgpXvcWrapper;

architecture rtl of PgpXvcWrapper is

   signal ibXvcMaster : AxiStreamMasterType := axiStreamMasterInit(EMAC_AXIS_CONFIG_C);
   signal ibXvcSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal obXvcMaster : AxiStreamMasterType := axiStreamMasterInit(EMAC_AXIS_CONFIG_C);
   signal obXvcSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

begin

   GEN_REAL : if (SIMULATION_G = false) generate

      -----------------------------------------------------------------
      -- Xilinx Virtual Cable (XVC)
      -- https://www.xilinx.com/products/intellectual-property/xvc.html
      -----------------------------------------------------------------
      U_XVC : entity surf.UdpDebugBridgeWrapper
         generic map (
            TPD_G           => TPD_G,
            AXIS_CLK_FREQ_G => AXIS_CLK_FREQ_G)
         port map (
            -- Clock and Reset
            clk            => xvcClk,
            rst            => xvcRst,
            -- UDP XVC Interface
            obServerMaster => ibXvcMaster,
            obServerSlave  => ibXvcSlave,
            ibServerMaster => obXvcMaster,
            ibServerSlave  => obXvcSlave);

      U_VC_RX : entity surf.PgpRxVcFifo
         generic map (
            TPD_G            => TPD_G,
            PHY_AXI_CONFIG_G => PHY_AXI_CONFIG_G,
            APP_AXI_CONFIG_G => EMAC_AXIS_CONFIG_C)
         port map (
            -- PGP Interface (pgpClk domain)
            pgpClk      => pgpClk,
            pgpRst      => pgpRst,
            rxlinkReady => rxlinkReady,
            pgpRxMaster => pgpRxMaster,
            pgpRxCtrl   => pgpRxCtrl,
            -- AXIS Interface (axisClk domain)
            axisClk     => xvcClk,
            axisRst     => xvcRst,
            axisMaster  => ibXvcMaster,
            axisSlave   => ibXvcSlave);

      U_VC_TX : entity surf.PgpTxVcFifo
         generic map (
            TPD_G            => TPD_G,
            APP_AXI_CONFIG_G => EMAC_AXIS_CONFIG_C,
            PHY_AXI_CONFIG_G => PHY_AXI_CONFIG_G)
         port map (
            -- AXIS Interface (axisClk domain)
            axisClk     => xvcClk,
            axisRst     => xvcRst,
            axisMaster  => obXvcMaster,
            axisSlave   => obXvcSlave,
            -- PGP Interface (pgpClk domain)
            pgpClk      => pgpClk,
            pgpRst      => pgpRst,
            rxlinkReady => rxlinkReady,
            txlinkReady => txlinkReady,
            pgpTxMaster => pgpTxMaster,
            pgpTxSlave  => pgpTxSlave);

   end generate GEN_REAL;

end rtl;
