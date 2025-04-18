-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: AXI-Lite interface to AD5541 DAC IC
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
use ieee.numeric_std.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

entity AxiAd5541Core is
   generic (
      TPD_G             : time := 1 ns;
      AXIL_CLK_PERIOD_G : real := 1/(200.0E+6);  -- In units of s, default 200 MHz
      SPI_SCLK_PERIOD_G : real := 1/(1.0E+6)  -- In units of s, default 1 MHz
      );
   port (
      -- DAC Ports
      dacSclk        : out sl;
      dacSdi         : out sl;
      dacCsL         : out sl;
      dacLdacL       : out sl;
      -- AXI-Lite Register Interface
      axiClk         : in  sl;
      axiRst         : in  sl;
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType
      );
end AxiAd5541Core;

architecture mapping of AxiAd5541Core is
begin
   U_AxiSpiMaster : entity surf.AxiSpiMaster
      generic map (
         TPD_G             => TPD_G,
         CPOL_G            => '1',      -- SDIN sampled on falling edge
         ADDRESS_SIZE_G    => 0,
         DATA_SIZE_G       => 16,
         MODE_G            => "WO",     -- "WO" (write only)
         CLK_PERIOD_G      => AXIL_CLK_PERIOD_G,
         SPI_SCLK_PERIOD_G => SPI_SCLK_PERIOD_G
         )
      port map (
         -- AXI-Lite Register Interface
         axiClk         => axiClk,
         axiRst         => axiRst,
         axiReadMaster  => axiReadMaster,
         axiReadSlave   => axiReadSlave,
         axiWriteMaster => axiWriteMaster,
         axiWriteSlave  => axiWriteSlave,
         -- SPI Ports
         coreSclk       => dacSclk,
         coreSDin       => '0',
         coreSDout      => dacSdi,
         coreCsb        => dacCsL
         );

   -- The LDAC_L signal of the DAC is tied low to load the data to the DAC on the rising edge of the CS_L
   dacLdacL <= '0';

end mapping;
