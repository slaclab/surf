-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper for Si5394I2cCore
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

entity Si5394I2c is
   generic (
      TPD_G              : time            := 1 ns;
      MEMORY_INIT_FILE_G : string          := "none";  -- Used to initialization boot ROM
      I2C_BASE_ADDR_G    : slv(1 downto 0) := "00";    -- A[1:0] pin config
      I2C_SCL_FREQ_G     : real            := 100.0E+3;    -- units of Hz
      I2C_MIN_PULSE_G    : real            := 100.0E-9;    -- units of seconds
      AXIL_CLK_FREQ_G    : real            := 156.25E+6);  -- units of Hz
   port (
      -- I2C Ports
      scl             : inout sl;
      sda             : inout sl;
      -- Misc Interface
      irqL            : in    sl;
      lolL            : in    sl;
      losL            : in    sl;
      rstL            : out   sl;
      booting         : out   sl;
      -- AXI-Lite Register Interface
      axilReadMaster  : in    AxiLiteReadMasterType;
      axilReadSlave   : out   AxiLiteReadSlaveType;
      axilWriteMaster : in    AxiLiteWriteMasterType;
      axilWriteSlave  : out   AxiLiteWriteSlaveType;
      -- Clocks and Resets
      axilClk         : in    sl;
      axilRst         : in    sl);
end Si5394I2c;

architecture mapping of Si5394I2c is

   signal i2ci : i2c_in_type;
   signal i2co : i2c_out_type;

begin

   U_Core : entity surf.Si5394I2cCore
      generic map (
         TPD_G              => TPD_G,
         MEMORY_INIT_FILE_G => MEMORY_INIT_FILE_G,
         I2C_BASE_ADDR_G    => I2C_BASE_ADDR_G,
         I2C_SCL_FREQ_G     => I2C_SCL_FREQ_G,
         I2C_MIN_PULSE_G    => I2C_MIN_PULSE_G,
         AXIL_CLK_FREQ_G    => AXIL_CLK_FREQ_G)
      port map (
         -- I2C Interface
         i2ci            => i2ci,
         i2co            => i2co,
         -- Misc Interface
         irqL            => irqL,
         lolL            => lolL,
         losL            => losL,
         rstL            => rstL,
         booting         => booting,
         -- AXI-Lite Register Interface
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave,
         -- Clocks and Resets
         axilClk         => axilClk,
         axilRst         => axilRst);

   IOBUF_SCL : IOBUF
      port map (
         O  => i2ci.scl,                -- Buffer output
         IO => scl,  -- Buffer inout port (connect directly to top-level port)
         I  => i2co.scl,                -- Buffer input
         T  => i2co.scloen);  -- 3-state enable input, high=input, low=output

   IOBUF_SDA : IOBUF
      port map (
         O  => i2ci.sda,                -- Buffer output
         IO => sda,  -- Buffer inout port (connect directly to top-level port)
         I  => i2co.sda,                -- Buffer input
         T  => i2co.sdaoen);  -- 3-state enable input, high=input, low=output

end mapping;
