-------------------------------------------------------------------------------
-- File       : AxiI2cEeprom.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-07-11
-- Last update: 2016-07-11
-------------------------------------------------------------------------------
-- Description: Wrapper for AxiI2cEepromCore
--
-- Supported Devices:   
--    24AA01F/24LC01F/24FC01F    (1kb:   ADDR_WIDTH_G = 7)
--    24AA02F/24LC02F/24FC02F    (2kb:   ADDR_WIDTH_G = 8)
--    24AA04F/24LC04F/24FC04F    (4kb:   ADDR_WIDTH_G = 9)
--    24AA08F/24LC08F/24FC08F    (8kb:   ADDR_WIDTH_G = 10)
--    24AA16F/24LC16F/24FC16F    (16kb:  ADDR_WIDTH_G = 11)
--    24AA32F/24LC32F/24FC32F    (32kb:  ADDR_WIDTH_G = 12)
--    24AA64F/24LC64F/24FC64F    (64kb:  ADDR_WIDTH_G = 13)
--    24AA128F/24LC128F/24FC128F (128kb: ADDR_WIDTH_G = 14)
--    24AA256F/24LC256F/24FC256F (256kb: ADDR_WIDTH_G = 15)
--    24AA512F/24LC512F/24FC512F (512kb: ADDR_WIDTH_G = 16)
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

library unisim;
use unisim.vcomponents.all;

entity AxiI2cEeprom is
   generic (
      TPD_G            : time            := 1 ns;
      ADDR_WIDTH_G     : positive        := 16;
      POLL_TIMEOUT_G   : positive        := 16;
      I2C_ADDR_G       : slv(6 downto 0) := "1010000";
      I2C_SCL_FREQ_G   : real            := 100.0E+3;   -- units of Hz
      I2C_MIN_PULSE_G  : real            := 100.0E-9;   -- units of seconds
      AXI_CLK_FREQ_G   : real            := 156.25E+6;  -- units of Hz
      AXI_ERROR_RESP_G : slv(1 downto 0) := AXI_RESP_SLVERR_C);
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
end AxiI2cEeprom;

architecture mapping of AxiI2cEeprom is

   signal i2ci : i2c_in_type;
   signal i2co : i2c_out_type;
   
begin

   U_AxiI2cEepromCore : entity work.AxiI2cEepromCore
      generic map (
         TPD_G            => TPD_G,
         ADDR_WIDTH_G     => ADDR_WIDTH_G,
         POLL_TIMEOUT_G   => POLL_TIMEOUT_G,
         I2C_ADDR_G       => I2C_ADDR_G,
         I2C_SCL_FREQ_G   => I2C_SCL_FREQ_G,
         I2C_MIN_PULSE_G  => I2C_MIN_PULSE_G,
         AXI_CLK_FREQ_G   => AXI_CLK_FREQ_G,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G)      
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

   IOBUF_SCL : IOBUF
      port map (
         O  => i2ci.scl,                -- Buffer output
         IO => scl,                     -- Buffer inout port (connect directly to top-level port)
         I  => i2co.scl,                -- Buffer input
         T  => i2co.scloen);            -- 3-state enable input, high=input, low=output  

   IOBUF_SDA : IOBUF
      port map (
         O  => i2ci.sda,                -- Buffer output
         IO => sda,                     -- Buffer inout port (connect directly to top-level port)
         I  => i2co.sda,                -- Buffer input
         T  => i2co.sdaoen);            -- 3-state enable input, high=input, low=output  

end mapping;
