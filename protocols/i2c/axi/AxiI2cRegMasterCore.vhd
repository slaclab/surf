-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: AXI-Lite I2C Register Master Core
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

entity AxiI2cRegMasterCore is
   generic (
      TPD_G           : time               := 1 ns;
      AXIL_PROXY_G    : boolean            := false;
      DEVICE_MAP_G    : I2cAxiLiteDevArray := I2C_AXIL_DEV_ARRAY_DEFAULT_C;
      I2C_SCL_FREQ_G  : real               := 100.0E+3;    -- units of Hz
      I2C_MIN_PULSE_G : real               := 100.0E-9;    -- units of seconds
      AXI_CLK_FREQ_G  : real               := 156.25E+6);  -- units of Hz
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
      sel            : out slv(DEVICE_MAP_G'length-1 downto 0);
      i2ci           : in  i2c_in_type;
      i2co           : out i2c_out_type);
end AxiI2cRegMasterCore;

architecture mapping of AxiI2cRegMasterCore is

   -- Note: PRESCALE_G = (clk_freq / (5 * i2c_freq)) - 1
   --       FILTER_G = (min_pulse_time / clk_period) + 1
   constant I2C_SCL_5xFREQ_C : real    := 5.0 * I2C_SCL_FREQ_G;
   constant PRESCALE_C       : natural := (getTimeRatio(AXI_CLK_FREQ_G, I2C_SCL_5xFREQ_C)) - 1;
   constant FILTER_C         : natural := natural(AXI_CLK_FREQ_G * I2C_MIN_PULSE_G) + 1;

   signal i2cRegMasterIn  : I2cRegMasterInType;
   signal i2cRegMasterOut : I2cRegMasterOutType;

   signal proxyReadMaster  : AxiLiteReadMasterType;
   signal proxyReadSlave   : AxiLiteReadSlaveType;
   signal proxyWriteMaster : AxiLiteWriteMasterType;
   signal proxyWriteSlave  : AxiLiteWriteSlaveType;

begin

   BYP_PROXY : if (AXIL_PROXY_G = false) generate
      proxyReadMaster  <= axiReadMaster;
      axiReadSlave     <= proxyReadSlave;
      proxyWriteMaster <= axiWriteMaster;
      axiWriteSlave    <= proxyWriteSlave;
   end generate BYP_PROXY;

   GEN_PROXY : if (AXIL_PROXY_G = true) generate
      U_AxiLiteMasterProxy : entity surf.AxiLiteMasterProxy
         generic map (
            TPD_G => TPD_G)
         port map (
            -- Clocks and Resets
            axiClk          => axiClk,
            axiRst          => axiRst,
            -- AXI-Lite Register Interface
            sAxiReadMaster  => axiReadMaster,
            sAxiReadSlave   => axiReadSlave,
            sAxiWriteMaster => axiWriteMaster,
            sAxiWriteSlave  => axiWriteSlave,
            -- AXI-Lite Register Interface
            mAxiReadMaster  => proxyReadMaster,
            mAxiReadSlave   => proxyReadSlave,
            mAxiWriteMaster => proxyWriteMaster,
            mAxiWriteSlave  => proxyWriteSlave);
   end generate GEN_PROXY;

   U_I2cRegMasterAxiBridge : entity surf.I2cRegMasterAxiBridge
      generic map (
         TPD_G        => TPD_G,
         DEVICE_MAP_G => DEVICE_MAP_G)
      port map (
         -- I2C Register Interface
         i2cRegMasterIn  => i2cRegMasterIn,
         i2cRegMasterOut => i2cRegMasterOut,
         i2cSelectOut    => sel,
         -- AXI-Lite Register Interface
         axiReadMaster   => proxyReadMaster,
         axiReadSlave    => proxyReadSlave,
         axiWriteMaster  => proxyWriteMaster,
         axiWriteSlave   => proxyWriteSlave,
         -- Clocks and Resets
         axiClk          => axiClk,
         axiRst          => axiRst);

   U_I2cRegMaster : entity surf.I2cRegMaster
      generic map(
         TPD_G                => TPD_G,
         OUTPUT_EN_POLARITY_G => 0,
         FILTER_G             => FILTER_C,
         PRESCALE_G           => PRESCALE_C)
      port map (
         -- I2C Port Interface
         i2ci   => i2ci,
         i2co   => i2co,
         -- I2C Register Interface
         regIn  => i2cRegMasterIn,
         regOut => i2cRegMasterOut,
         -- Clock and Reset
         clk    => axiClk,
         srst   => axiRst);

end mapping;
