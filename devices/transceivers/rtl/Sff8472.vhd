-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Optical Module SFF-8472 Wrapper (I2C for SFP, QSFP, etc)
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
use surf.I2cPkg.all;

entity Sff8472 is
   generic (
      TPD_G           : time := 1 ns;
      I2C_SCL_FREQ_G  : real := 100.0E+3;    -- units of Hz
      I2C_MIN_PULSE_G : real := 100.0E-9;    -- units of seconds
      AXI_CLK_FREQ_G  : real := 156.25E+6);  -- units of Hz
   port (
      -- I2C Ports
      scl             : inout sl;
      sda             : inout sl;
      -- AXI-Lite Register Interface
      axilReadMaster  : in    AxiLiteReadMasterType;
      axilReadSlave   : out   AxiLiteReadSlaveType;
      axilWriteMaster : in    AxiLiteWriteMasterType;
      axilWriteSlave  : out   AxiLiteWriteSlaveType;
      -- Clocks and Resets
      axilClk         : in    sl;
      axilRst         : in    sl);
end Sff8472;

architecture mapping of Sff8472 is

   constant DEVICE_MAP_C : I2cAxiLiteDevArray(0 to 1) := (
      0              => MakeI2cAxiLiteDevType(
         i2cAddress  => "1010000",      -- Configuration PROM
         dataSize    => 8,              -- in units of bits
         addrSize    => 8,              -- in units of bits
         endianness  => '0',            -- Little endian
         repeatStart => '0'),           -- Repeat start
      1              => MakeI2cAxiLiteDevType(  -- Enhanced interface
         i2cAddress  => "1010001",      -- Diagnostic Monitoring
         dataSize    => 8,              -- in units of bits
         addrSize    => 8,              -- in units of bits
         endianness  => '0',            -- Little endian
         repeatStart => '0'));          -- Repeat Start

begin

   U_AxiI2C : entity surf.AxiI2cRegMaster
      generic map (
         TPD_G           => TPD_G,
         DEVICE_MAP_G    => DEVICE_MAP_C,
         I2C_SCL_FREQ_G  => I2C_SCL_FREQ_G,
         I2C_MIN_PULSE_G => I2C_MIN_PULSE_G,
         AXI_CLK_FREQ_G  => AXI_CLK_FREQ_G)
      port map (
         -- I2C Ports
         scl            => scl,
         sda            => sda,
         -- AXI-Lite Register Interface
         axiReadMaster  => axilReadMaster,
         axiReadSlave   => axilReadSlave,
         axiWriteMaster => axilWriteMaster,
         axiWriteSlave  => axilWriteSlave,
         -- Clocks and Resets
         axiClk         => axilClk,
         axiRst         => axilRst);

end mapping;
