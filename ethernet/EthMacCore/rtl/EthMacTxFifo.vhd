-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Inbound FIFO buffers
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

entity EthMacTxFifo is
   generic (
      TPD_G             : time                := 1 ns;
      PRIM_COMMON_CLK_G : boolean             := false;
      PRIM_CONFIG_G     : AxiStreamConfigType := INT_EMAC_AXIS_CONFIG_C;
      BYP_EN_G          : boolean             := false;
      BYP_COMMON_CLK_G  : boolean             := false;
      BYP_CONFIG_G      : AxiStreamConfigType := INT_EMAC_AXIS_CONFIG_C;
      SYNTH_MODE_G      : string              := "inferred");  -- Synthesis mode for internal RAMs
   port (
      -- Master Clock and Reset
      mClk        : in  sl;
      mRst        : in  sl;
      -- Primary Interface
      sPrimClk    : in  sl;
      sPrimRst    : in  sl;
      sPrimMaster : in  AxiStreamMasterType;
      sPrimSlave  : out AxiStreamSlaveType;
      mPrimMaster : out AxiStreamMasterType;
      mPrimSlave  : in  AxiStreamSlaveType;
      -- Bypass interface
      sBypClk     : in  sl;
      sBypRst     : in  sl;
      sBypMaster  : in  AxiStreamMasterType;
      sBypSlave   : out AxiStreamSlaveType;
      mBypMaster  : out AxiStreamMasterType;
      mBypSlave   : in  AxiStreamSlaveType);
end EthMacTxFifo;

architecture mapping of EthMacTxFifo is

begin

   PRIM_FIFO_BYPASS : if ((PRIM_COMMON_CLK_G = true) and (PRIM_CONFIG_G = INT_EMAC_AXIS_CONFIG_C)) generate
      mPrimMaster <= sPrimMaster;
      sPrimSlave  <= mPrimSlave;
   end generate;

   PRIM_FIFO : if ((PRIM_COMMON_CLK_G = false) or (PRIM_CONFIG_G /= INT_EMAC_AXIS_CONFIG_C)) generate
      U_Fifo : entity surf.AxiStreamFifoV2
         generic map (
            -- General Configurations
            TPD_G               => TPD_G,
            INT_PIPE_STAGES_G   => 0,
            PIPE_STAGES_G       => 1,
            SLAVE_READY_EN_G    => true,
            VALID_THOLD_G       => 1,
            -- FIFO configurations
            SYNTH_MODE_G        => SYNTH_MODE_G,
            MEMORY_TYPE_G       => "distributed",
            GEN_SYNC_FIFO_G     => PRIM_COMMON_CLK_G,
            CASCADE_SIZE_G      => 1,
            FIFO_ADDR_WIDTH_G   => 4,
            -- AXI Stream Port Configurations
            SLAVE_AXI_CONFIG_G  => PRIM_CONFIG_G,
            MASTER_AXI_CONFIG_G => INT_EMAC_AXIS_CONFIG_C)
         port map (
            sAxisClk    => sPrimClk,
            sAxisRst    => sPrimRst,
            sAxisMaster => sPrimMaster,
            sAxisSlave  => sPrimSlave,
            mAxisClk    => mClk,
            mAxisRst    => mRst,
            mAxisMaster => mPrimMaster,
            mAxisSlave  => mPrimSlave);
   end generate;

   BYP_DISABLED : if (BYP_EN_G = false) generate
      sBypSlave  <= AXI_STREAM_SLAVE_FORCE_C;
      mBypMaster <= AXI_STREAM_MASTER_INIT_C;
   end generate;

   BYP_ENABLED : if (BYP_EN_G = true) generate

      BYP_FIFO_BYPASS : if ((BYP_COMMON_CLK_G = true) and (BYP_CONFIG_G = INT_EMAC_AXIS_CONFIG_C)) generate
         mBypMaster <= sBypMaster;
         sBypSlave  <= mBypSlave;
      end generate;

      BYP_FIFO : if ((BYP_COMMON_CLK_G = false) or (BYP_CONFIG_G /= INT_EMAC_AXIS_CONFIG_C)) generate
         U_Fifo : entity surf.AxiStreamFifoV2
            generic map (
               -- General Configurations
               TPD_G               => TPD_G,
               INT_PIPE_STAGES_G   => 0,
               PIPE_STAGES_G       => 1,
               SLAVE_READY_EN_G    => true,
               VALID_THOLD_G       => 1,
               -- FIFO configurations
               SYNTH_MODE_G        => SYNTH_MODE_G,
               MEMORY_TYPE_G       => "distributed",
               GEN_SYNC_FIFO_G     => BYP_COMMON_CLK_G,
               CASCADE_SIZE_G      => 1,
               FIFO_ADDR_WIDTH_G   => 4,
               -- AXI Stream Port Configurations
               SLAVE_AXI_CONFIG_G  => BYP_CONFIG_G,
               MASTER_AXI_CONFIG_G => INT_EMAC_AXIS_CONFIG_C)
            port map (
               sAxisClk    => sBypClk,
               sAxisRst    => sBypRst,
               sAxisMaster => sBypMaster,
               sAxisSlave  => sBypSlave,
               mAxisClk    => mClk,
               mAxisRst    => mRst,
               mAxisMaster => mBypMaster,
               mAxisSlave  => mBypSlave);
      end generate;

   end generate;

end mapping;
