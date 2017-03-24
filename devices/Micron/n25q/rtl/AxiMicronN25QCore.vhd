-------------------------------------------------------------------------------
-- File       : AxiMicronN25QCore.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-03-03
-- Last update: 2016-09-20
-------------------------------------------------------------------------------
-- Description: AXI-Lite interface to N25Q FLASH Memory IC
-------------------------------------------------------------------------------
-- Note: This module doesn't support DSPI or QSPI interface yet.
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

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

library unisim;
use unisim.vcomponents.all;

entity AxiMicronN25QCore is
   generic (
      TPD_G            : time                := 1 ns;
      MEM_ADDR_MASK_G  : slv(31 downto 0)    := x"00000000";
      AXI_CLK_FREQ_G   : real                := 200.0E+6;  -- units of Hz
      SPI_CLK_FREQ_G   : real                := 25.0E+6;   -- units of Hz
      PIPE_STAGES_G    : natural             := 0;
      AXI_CONFIG_G     : AxiStreamConfigType := ssiAxiStreamConfig(4);
      AXI_ERROR_RESP_G : slv(1 downto 0)     := AXI_RESP_SLVERR_C);     
   port (
      -- FLASH Memory Ports
      csL            : out sl;
      sck            : out sl;
      mosi           : out sl;
      miso           : in  sl;
      -- AXI-Lite Register Interface
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;
      -- AXI Streaming Interface (Optional)
      mAxisMaster    : out AxiStreamMasterType;
      mAxisSlave     : in  AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
      sAxisMaster    : in  AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
      sAxisSlave     : out AxiStreamSlaveType;
      -- Clocks and Resets
      axiClk         : in  sl;
      axiRst         : in  sl);
end AxiMicronN25QCore;

architecture mapping of AxiMicronN25QCore is

begin
   -- Check SPI_CLK_FREQ_G
   -- Note: Max. read frequency is 50 MHz
   assert (SPI_CLK_FREQ_G <= 50.0E+6)
      report "SPI_CLK_FREQ_G must be <= 50.0E+6"
      severity failure;
   -- Check AXI_CLK_FREQ_G >= 2*SPI_CLK_FREQ_G
   assert (AXI_CLK_FREQ_G >= 2.0 * SPI_CLK_FREQ_G)
      report "AXI_CLK_FREQ_G must be >= 2*SPI_CLK_FREQ_G"
      severity failure;

   AxiMicronN25QReg_Inst : entity work.AxiMicronN25QReg
      generic map(
         TPD_G            => TPD_G,
         MEM_ADDR_MASK_G  => MEM_ADDR_MASK_G,
         AXI_CLK_FREQ_G   => AXI_CLK_FREQ_G,
         SPI_CLK_FREQ_G   => SPI_CLK_FREQ_G,
         PIPE_STAGES_G    => PIPE_STAGES_G,
         AXI_CONFIG_G     => AXI_CONFIG_G,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G)
      port map(
         -- FLASH Memory Ports
         csL            => csL,
         sck            => sck,
         mosi           => mosi,
         miso           => miso,
         -- AXI-Lite Register Interface    
         axiReadMaster  => axiReadMaster,
         axiReadSlave   => axiReadSlave,
         axiWriteMaster => axiWriteMaster,
         axiWriteSlave  => axiWriteSlave,
         -- AXI Streaming Interface (Optional)
         mAxisMaster    => mAxisMaster,
         mAxisSlave     => mAxisSlave,
         sAxisMaster    => sAxisMaster,
         sAxisSlave     => sAxisSlave,
         -- Clocks and Resets
         axiClk         => axiClk,
         axiRst         => axiRst);   

end mapping;
