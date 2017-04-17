-------------------------------------------------------------------------------
-- File       : AxiI2cMasterCore.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-22
-- Last update: 2016-09-20
-------------------------------------------------------------------------------
-- Description: AXI-Lite interface to generic I2C master controller
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
use work.I2cPkg.all;
use work.AxiI2cMasterPkg.all;

library unisim;
use unisim.vcomponents.all;

entity AxiI2cMasterCore is
   generic (
      TPD_G               : time            := 1 ns;
      DEVICE_MAP_G        : I2cAxiLiteDevArray;
      AXI_CLK_FREQ_G      : real            := 200.0E+6;  -- units of Hz
      I2C_SCL_FREQ_G      : real            := 100.0E+3;  -- units of Hz
      I2C_MIN_PULSE_G     : real            := 100.0E-9;  -- units of seconds
      I2C_REG_ADDR_SIZE_G : integer         := 8;
      AXI_ERROR_RESP_G    : slv(1 downto 0) := AXI_RESP_SLVERR_C);
   port (
      -- DAC Ports
      i2cInOut       : inout AxiI2cMasterInOutType;
      -- AXI-Lite Register Interface
      axiReadMaster  : in    AxiLiteReadMasterType;
      axiReadSlave   : out   AxiLiteReadSlaveType;
      axiWriteMaster : in    AxiLiteWriteMasterType;
      axiWriteSlave  : out   AxiLiteWriteSlaveType;
      -- Clocks and Resets
      axiClk         : in    sl;
      axiRst         : in    sl);
end AxiI2cMasterCore;

architecture mapping of AxiI2cMasterCore is

   -- Note: PRESCALE_G = (clk_freq / (5 * i2c_freq)) - 1
   --       FILTER_G = (min_pulse_time / clk_period) + 1
   constant I2C_SCL_5xFREQ_C : real    := 5.0 * I2C_SCL_FREQ_G;
   constant PRESCALE_C       : natural := (getTimeRatio(AXI_CLK_FREQ_G, I2C_SCL_5xFREQ_C)) - 1;
   constant FILTER_C         : natural := natural(AXI_CLK_FREQ_G * I2C_MIN_PULSE_G) + 1;

   signal i2cRegMasterIn  : I2cRegMasterInType;
   signal i2cRegMasterOut : I2cRegMasterOutType;

   signal i2ci : i2c_in_type;
   signal i2co : i2c_out_type;
   
begin
   
   IOBUF_SCL : IOBUF
      port map (
         O  => i2ci.scl,                -- Buffer output
         IO => i2cInOut.scl,            -- Buffer inout port (connect directly to top-level port)
         I  => i2co.scl,                -- Buffer input
         T  => i2co.scloen);            -- 3-state enable input, high=input, low=output  

   IOBUF_SDA : IOBUF
      port map (
         O  => i2ci.sda,                -- Buffer output
         IO => i2cInOut.sda,            -- Buffer inout port (connect directly to top-level port)
         I  => i2co.sda,                -- Buffer input
         T  => i2co.sdaoen);            -- 3-state enable input, high=input, low=output     

   I2cRegMasterAxiBridge_Inst : entity work.I2cRegMasterAxiBridge
      generic map (
         TPD_G               => TPD_G,
         I2C_REG_ADDR_SIZE_G => I2C_REG_ADDR_SIZE_G,
         DEVICE_MAP_G        => DEVICE_MAP_G,
         EN_USER_REG_G       => false,
         AXI_ERROR_RESP_G    => AXI_ERROR_RESP_G)      
      port map (
         -- I2C Interface
         i2cRegMasterIn  => i2cRegMasterIn,
         i2cRegMasterOut => i2cRegMasterOut,
         -- AXI-Lite Register Interface
         axiReadMaster   => axiReadMaster,
         axiReadSlave    => axiReadSlave,
         axiWriteMaster  => axiWriteMaster,
         axiWriteSlave   => axiWriteSlave,
         -- Clock and Reset
         axiClk          => axiClk,
         axiRst          => axiRst);   

   I2cRegMaster_Inst : entity work.I2cRegMaster
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
