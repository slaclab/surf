-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: AXI-Lite I2C Register Master
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

entity AxiI2cRegMaster is
   generic (
      TPD_G           : time               := 1 ns;
      AXIL_PROXY_G    : boolean            := false;
      DEVICE_MAP_G    : I2cAxiLiteDevArray := I2C_AXIL_DEV_ARRAY_DEFAULT_C;
      I2C_SCL_FREQ_G  : real               := 100.0E+3;    -- units of Hz
      I2C_MIN_PULSE_G : real               := 100.0E-9;    -- units of seconds
      AXI_CLK_FREQ_G  : real               := 156.25E+6);  -- units of Hz
   port (
      -- Clocks and Resets
      axiClk         : in    sl;
      axiRst         : in    sl;
      -- AXI-Lite Register Interface
      axiReadMaster  : in    AxiLiteReadMasterType;
      axiReadSlave   : out   AxiLiteReadSlaveType;
      axiWriteMaster : in    AxiLiteWriteMasterType;
      axiWriteSlave  : out   AxiLiteWriteSlaveType;
      -- I2C Ports
      sel            : out   slv(DEVICE_MAP_G'length-1 downto 0);
      scl            : inout sl;
      sda            : inout sl);
end AxiI2cRegMaster;

architecture mapping of AxiI2cRegMaster is

   signal i2ci : i2c_in_type;
   signal i2co : i2c_out_type;

begin

   U_Core : entity surf.AxiI2cRegMasterCore
      generic map (
         TPD_G           => TPD_G,
         AXIL_PROXY_G    => AXIL_PROXY_G,
         DEVICE_MAP_G    => DEVICE_MAP_G,
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
         sel            => sel,
         i2ci           => i2ci,
         i2co           => i2co);

   IOBUF_SCL : entity surf.IoBufWrapper
      port map (
         O  => i2ci.scl,                -- Buffer output
         IO => scl,  -- Buffer inout port (connect directly to top-level port)
         I  => i2co.scl,                -- Buffer input
         T  => i2co.scloen);  -- 3-state enable input, high=input, low=output

   IOBUF_SDA : entity surf.IoBufWrapper
      port map (
         O  => i2ci.sda,                -- Buffer output
         IO => sda,  -- Buffer inout port (connect directly to top-level port)
         I  => i2co.sda,                -- Buffer input
         T  => i2co.sdaoen);  -- 3-state enable input, high=input, low=output

end mapping;
