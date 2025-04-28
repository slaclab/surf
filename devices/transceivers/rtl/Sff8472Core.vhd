-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Optical Module SFF-8472 Core (I2C for SFP, QSFP, etc)
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
use surf.I2cPkg.all;

entity Sff8472Core is
   generic (
      TPD_G           : time    := 1 ns;
      AXIL_PROXY_G    : boolean := false;
      I2C_SCL_FREQ_G  : real    := 100.0E+3;    -- units of Hz
      I2C_MIN_PULSE_G : real    := 100.0E-9;    -- units of seconds
      AXI_CLK_FREQ_G  : real    := 156.25E+6);  -- units of Hz
   port (
      -- Clocks and Resets
      axiClk         : in  sl;
      axiRst         : in  sl;
      -- AXI-Lite Register Interface
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;
      -- I2C Ports
      i2ci           : in  i2c_in_type;
      i2co           : out i2c_out_type);
end Sff8472Core;

architecture mapping of Sff8472Core is

   constant SFF8472_I2C_CONFIG_C : I2cAxiLiteDevArray(0 to 1) := (
      0              => MakeI2cAxiLiteDevType(
         i2cAddress  => "1010000",      -- 2 wire address 1010000X (A0h)
         dataSize    => 8,              -- in units of bits
         addrSize    => 8,              -- in units of bits
         endianness  => '0',            -- Little endian
         repeatStart => '1'),           -- No repeat start
      1              => MakeI2cAxiLiteDevType(
         i2cAddress  => "1010001",      -- 2 wire address 1010001X (A2h)
         dataSize    => 8,              -- in units of bits
         addrSize    => 8,              -- in units of bits
         endianness  => '0',            -- Little endian
         repeatStart => '1'));          -- Repeat Start

begin

   U_Core : entity surf.AxiI2cRegMasterCore
      generic map (
         TPD_G           => TPD_G,
         AXIL_PROXY_G    => AXIL_PROXY_G,
         DEVICE_MAP_G    => SFF8472_I2C_CONFIG_C,
         I2C_SCL_FREQ_G  => I2C_SCL_FREQ_G,
         I2C_MIN_PULSE_G => I2C_MIN_PULSE_G,
         AXI_CLK_FREQ_G  => AXI_CLK_FREQ_G)
      port map (
         -- Clocks and Resets
         axiClk         => axiClk,
         axiRst         => axiRst,
         -- AXI-Lite Register Interface
         axiReadMaster  => axiReadMaster,
         axiReadSlave   => axiReadSlave,
         axiWriteMaster => axiWriteMaster,
         axiWriteSlave  => axiWriteSlave,
         -- I2C Ports
         i2ci           => i2ci,
         i2co           => i2co);

end mapping;
