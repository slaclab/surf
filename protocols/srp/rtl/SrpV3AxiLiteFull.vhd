-------------------------------------------------------------------------------
-- File       : SrpV3AxiLite.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-03-22
-- Last update: 2016-04-25
-------------------------------------------------------------------------------
-- Description: SLAC Register Protocol Version 3, AXI-Lite Interface
--
-- Documentation: https://confluence.slac.stanford.edu/x/cRmVD
--
-- Note: This module only supports 32-bit aligned addresses and 32-bit transactions.  
--       For non 32-bit aligned addresses or non 32-bit transactions, use
--       the SrpV3Axi.vhd module with the AxiToAxiLite.vhd bridge
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.AxiLitePkg.all;
use work.AxiPkg.all;

entity SrpV3AxiLiteFull is
   generic (
      TPD_G               : time                    := 1 ns;
      PIPE_STAGES_G       : natural range 0 to 16   := 0;
      FIFO_PAUSE_THRESH_G : positive range 1 to 511 := 256;
      SLAVE_READY_EN_G    : boolean                 := false;
      GEN_SYNC_FIFO_G     : boolean                 := false;
      ALTERA_SYN_G        : boolean                 := false;
      ALTERA_RAM_G        : string                  := "M9K";
      AXIL_CLK_FREQ_G     : real                    := 156.25E+6;  -- units of Hz
      AXI_STREAM_CONFIG_G : AxiStreamConfigType     := ssiAxiStreamConfig(2));
   port (
      -- AXIS Slave Interface (sAxisClk domain) 
      sAxisClk         : in  sl;
      sAxisRst         : in  sl;
      sAxisMaster      : in  AxiStreamMasterType;
      sAxisSlave       : out AxiStreamSlaveType;
      sAxisCtrl        : out AxiStreamCtrlType;
      -- AXIS Master Interface (mAxisClk domain) 
      mAxisClk         : in  sl;
      mAxisRst         : in  sl;
      mAxisMaster      : out AxiStreamMasterType;
      mAxisSlave       : in  AxiStreamSlaveType;
      -- Master AXI-Lite Interface (axilClk domain)
      axilClk          : in  sl;
      axilRst          : in  sl;
      mAxilWriteMaster : out AxiLiteWriteMasterType;
      mAxilWriteSlave  : in  AxiLiteWriteSlaveType;
      mAxilReadMaster  : out AxiLiteReadMasterType;
      mAxilReadSlave   : in  AxiLiteReadSlaveType);
end SrpV3AxiLiteFull;

architecture rtl of SrpV3AxiLiteFull is

   signal axiReadMaster  : AxiReadMasterType;
   signal axiReadSlave   : AxiReadSlaveType;
   signal axiWriteMaster : AxiWriteMasterType;
   signal axiWriteSlave  : AxiWriteSlaveType;

begin

   U_SrpV3Axi_1 : entity work.SrpV3Axi
      generic map (
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => PIPE_STAGES_G,
         FIFO_PAUSE_THRESH_G => FIFO_PAUSE_THRESH_G,
         SLAVE_READY_EN_G    => SLAVE_READY_EN_G,
         GEN_SYNC_FIFO_G     => GEN_SYNC_FIFO_G,
         ALTERA_SYN_G        => ALTERA_SYN_G,
         ALTERA_RAM_G        => ALTERA_RAM_G,
         AXI_CLK_FREQ_G      => AXIL_CLK_FREQ_G,
         AXI_CONFIG_G        => (32, 4, 1, 0),
--          AXI_BURST_G         => AXI_BURST_G,
--          AXI_CACHE_G         => AXI_CACHE_G,
--          ACK_WAIT_BVALID_G   => ACK_WAIT_BVALID_G,
         AXI_STREAM_CONFIG_G => AXI_STREAM_CONFIG_G)
      port map (
         sAxisClk       => sAxisClk,        -- [in]
         sAxisRst       => sAxisRst,        -- [in]
         sAxisMaster    => sAxisMaster,     -- [in]
         sAxisSlave     => sAxisSlave,      -- [out]
         sAxisCtrl      => sAxisCtrl,       -- [out]
         mAxisClk       => mAxisClk,        -- [in]
         mAxisRst       => mAxisRst,        -- [in]
         mAxisMaster    => mAxisMaster,     -- [out]
         mAxisSlave     => mAxisSlave,      -- [in]
         axiClk         => axilClk,         -- [in]
         axiRst         => axilRst,         -- [in]
         axiWriteMaster => axiWriteMaster,  -- [out]
         axiWriteSlave  => axiWriteSlave,   -- [in]
         axiReadMaster  => axiReadMaster,   -- [out]
         axiReadSlave   => axiReadSlave);   -- [in]

   U_AxiToAxiLite_1 : entity work.AxiToAxiLite
      generic map (
         TPD_G => TPD_G)
      port map (
         axiClk          => axilClk,          -- [in]
         axiClkRst       => axilRst,          -- [in]
         axiReadMaster   => axiReadMaster,    -- [in]
         axiReadSlave    => axiReadSlave,     -- [out]
         axiWriteMaster  => axiWriteMaster,   -- [in]
         axiWriteSlave   => axiWriteSlave,    -- [out]
         axilReadMaster  => mAxilReadMaster,   -- [out]
         axilReadSlave   => mAxilReadSlave,    -- [in]
         axilWriteMaster => mAxilWriteMaster,  -- [out]
         axilWriteSlave  => mAxilWriteSlave);  -- [in]

end rtl;
