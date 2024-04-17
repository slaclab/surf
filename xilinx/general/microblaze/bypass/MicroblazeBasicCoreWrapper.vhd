-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: "BYPASS" Wrapper for Microblaze Basic Core
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
use surf.AxiLitePkg.all;
use surf.SsiPkg.all;

entity MicroblazeBasicCoreWrapper is
   generic (
      TPD_G           : time    := 1 ns;
      AXIL_RESP_G     : boolean := false;
      AXIL_ADDR_MSB_G : boolean := false;   -- false = [0x00000000:0x7FFFFFFF], true = [0x80000000:0xFFFFFFFF]
      AXIL_ADDR_SEL_G : boolean := false);
   port (
      -- Master AXI-Lite Interface
      mAxilWriteMaster : out AxiLiteWriteMasterType;
      mAxilWriteSlave  : in  AxiLiteWriteSlaveType;
      mAxilReadMaster  : out AxiLiteReadMasterType;
      mAxilReadSlave   : in  AxiLiteReadSlaveType;
      -- Master AXIS Interface
      sAxisMaster      : in  AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
      sAxisSlave       : out AxiStreamSlaveType;
      -- Slave AXIS Interface
      mAxisMaster      : out AxiStreamMasterType;
      mAxisSlave       : in  AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
      -- Interrupt Interface
      interrupt        : in  slv(7 downto 0)     := (others => '0');
      -- Clock and Reset
      clk              : in  sl;
      pllLock          : in  sl                  := '1';
      rst              : in  sl);
end MicroblazeBasicCoreWrapper;

architecture mapping of MicroblazeBasicCoreWrapper is

begin

   -- Master AXI-Lite Interface
   mAxilWriteMaster <= AXI_LITE_WRITE_MASTER_INIT_C;
   mAxilReadMaster  <= AXI_LITE_READ_MASTER_INIT_C;

   -- Master AXIS Interface
   sAxisSlave <= AXI_STREAM_SLAVE_FORCE_C;

   -- Slave AXIS Interface
   mAxisMaster <= AXI_STREAM_MASTER_INIT_C;

end mapping;
