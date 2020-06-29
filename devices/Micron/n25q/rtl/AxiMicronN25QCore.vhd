-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
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


library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

library unisim;
use unisim.vcomponents.all;

entity AxiMicronN25QCore is
   generic (
      TPD_G              : time             := 1 ns;
      EN_PASSWORD_LOCK_G : boolean          := false;
      PASSWORD_LOCK_G    : slv(31 downto 0) := x"DEADBEEF";
      MEM_ADDR_MASK_G    : slv(31 downto 0) := x"00000000";
      AXI_CLK_FREQ_G     : real             := 200.0E+6;  -- units of Hz
      SPI_CLK_FREQ_G     : real             := 25.0E+6);  -- units of Hz
   port (
      -- FLASH Memory Ports
      csL            : out sl;
      sck            : out sl;
      mosi           : out sl;
      miso           : in  sl;
      -- Shared SPI Interface
      busyIn         : in  sl := '0';
      busyOut        : out sl;
      -- AXI-Lite Register Interface
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;
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

   AxiMicronN25QReg_Inst : entity surf.AxiMicronN25QReg
      generic map(
         TPD_G              => TPD_G,
         EN_PASSWORD_LOCK_G => EN_PASSWORD_LOCK_G,
         PASSWORD_LOCK_G    => PASSWORD_LOCK_G,
         MEM_ADDR_MASK_G    => MEM_ADDR_MASK_G,
         AXI_CLK_FREQ_G     => AXI_CLK_FREQ_G,
         SPI_CLK_FREQ_G     => SPI_CLK_FREQ_G)
      port map(
         -- FLASH Memory Ports
         csL            => csL,
         sck            => sck,
         mosi           => mosi,
         miso           => miso,
         -- Shared SPI Interface
         busyIn         => busyIn,
         busyOut        => busyOut,
         -- AXI-Lite Register Interface
         axiReadMaster  => axiReadMaster,
         axiReadSlave   => axiReadSlave,
         axiWriteMaster => axiWriteMaster,
         axiWriteSlave  => axiWriteSlave,
         -- Clocks and Resets
         axiClk         => axiClk,
         axiRst         => axiRst);

end mapping;
