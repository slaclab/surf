-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper for AxiLitePMbusMasterCore
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

library unisim;
use unisim.vcomponents.all;

entity AxiLitePMbusMaster is
   generic (
      TPD_G            : time            := 1 ns;
      I2C_ADDR_G       : slv(6 downto 0) := "1010000";
      I2C_SCL_FREQ_G   : real            := 100.0E+3;   -- units of Hz
      I2C_MIN_PULSE_G  : real            := 100.0E-9;   -- units of seconds
      AXI_CLK_FREQ_G   : real            := 156.25E+6);  -- units of Hz
   port (
      -- PMbus Ports
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
end AxiLitePMbusMaster;

architecture mapping of AxiLitePMbusMaster is

   signal i2ci : i2c_in_type;
   signal i2co : i2c_out_type;

begin

   U_Core : entity surf.AxiLitePMbusMasterCore
      generic map (
         TPD_G            => TPD_G,
         I2C_ADDR_G       => I2C_ADDR_G,
         I2C_SCL_FREQ_G   => I2C_SCL_FREQ_G,
         I2C_MIN_PULSE_G  => I2C_MIN_PULSE_G,
         AXI_CLK_FREQ_G   => AXI_CLK_FREQ_G)
      port map (
         -- I2C Interface
         i2ci            => i2ci,
         i2co            => i2co,
         -- AXI-Lite Register Interface
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave,
         -- Clocks and Resets
         axilClk         => axilClk,
         axilRst         => axilRst);

   IOBUF_SCL : entity surf.IoBufWrapper
      port map (
         O  => i2ci.scl,                -- Buffer output
         IO => scl,                     -- Buffer inout port (connect directly to top-level port)
         I  => i2co.scl,                -- Buffer input
         T  => i2co.scloen);            -- 3-state enable input, high=input, low=output

   IOBUF_SDA : entity surf.IoBufWrapper
      port map (
         O  => i2ci.sda,                -- Buffer output
         IO => sda,                     -- Buffer inout port (connect directly to top-level port)
         I  => i2co.sda,                -- Buffer input
         T  => i2co.sdaoen);            -- 3-state enable input, high=input, low=output

end mapping;
