-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper for Lmk048Base to handle 3-wire SPI and address mapping
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

library unisim;
use unisim.vcomponents.all;

entity Lmk048Base is
   generic (
      TPD_G             : time := 1 ns;
      CLK_PERIOD_G      : real := 6.4E-9;     -- units of seconds
      SPI_SCLK_PERIOD_G : real := 100.0E-6);  -- units of seconds
   port (
      -- 3-Wire SPI Ports
      lmkCsL          : out   sl;
      lmkSck          : out   sl;
      lmkSdio         : inout sl;
      -- AXI-Lite Interface
      axilClk         : in    sl;
      axilRst         : in    sl;
      axilReadMaster  : in    AxiLiteReadMasterType;
      axilReadSlave   : out   AxiLiteReadSlaveType;
      axilWriteMaster : in    AxiLiteWriteMasterType;
      axilWriteSlave  : out   AxiLiteWriteSlaveType);
end Lmk048Base;

architecture mapping of Lmk048Base is

   signal writeMaster : AxiLiteWriteMasterType;
   signal readMaster  : AxiLiteReadMasterType;

   signal lmkSDin  : sl;
   signal lmkSDout : sl;

begin

   process (axilReadMaster, axilWriteMaster) is
      variable wrMst : AxiLiteWriteMasterType;
      variable rdMst : AxiLiteReadMasterType;
   begin

      -- Init
      wrMst := axilWriteMaster;
      rdMst := axilReadMaster;

      -- Force the Upper SPI address bits that should always be zero
      wrMst.awaddr(31 downto 12) := (others => '0');
      rdMst.araddr(31 downto 12) := (others => '0');

      -- Outputs
      writeMaster <= wrMst;
      readMaster  <= rdMst;

   end process;

   U_LMK : entity surf.AxiSpiMaster
      generic map (
         TPD_G             => TPD_G,
         ADDRESS_SIZE_G    => 15,
         DATA_SIZE_G       => 8,
         CLK_PERIOD_G      => CLK_PERIOD_G,
         SPI_SCLK_PERIOD_G => SPI_SCLK_PERIOD_G)
      port map (
         -- AXI-Lite Interface
         axiClk         => axilClk,
         axiRst         => axilRst,
         axiReadMaster  => readMaster,
         axiReadSlave   => axilReadSlave,
         axiWriteMaster => writeMaster,
         axiWriteSlave  => axilWriteSlave,
         -- SPI Ports
         coreSclk       => lmkSck,
         coreSDin       => lmkSDin,
         coreSDout      => lmkSDout,
         coreCsb        => lmkCsL);

   U_lmkSdio : entity surf.IoBufWrapper
      port map (
         I  => '0',
         O  => lmkSDin,
         IO => lmkSdio,
         T  => lmkSDout);

end mapping;
