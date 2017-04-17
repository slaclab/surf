-------------------------------------------------------------------------------
-- File       : AxiI2cSfpCore.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-18
-- Last update: 2016-09-20
-------------------------------------------------------------------------------
-- Description: AXI-Lite interface to SFP
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

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.I2cPkg.all;
use work.AxiI2cSfpPkg.all;

library unisim;
use unisim.vcomponents.all;

entity AxiI2cSfpCore is
   generic (
      TPD_G              : time                  := 1 ns;
      AXI_CLK_FREQ_G     : real                  := 200.0E+6;  -- units of Hz
      I2C_SCL_FREQ_G     : real                  := 100.0E+3;  -- units of Hz
      I2C_MIN_PULSE_G    : real                  := 100.0E-9;  -- units of seconds
      STATUS_CNT_WIDTH_G : natural range 1 to 32 := 32;
      ALLOW_TX_DISABLE_G : boolean               := false;
      AXI_ERROR_RESP_G   : slv(1 downto 0)       := AXI_RESP_SLVERR_C);
   port (
      -- SFP Ports
      sfpIn          : in    AxiI2cSfpInType;
      sfpInOut       : inout AxiI2cSfpInOutType;
      sfpOut         : out   AxiI2cSfpOutType;
      -- AXI-Lite Register Interface
      axiReadMaster  : in    AxiLiteReadMasterType;
      axiReadSlave   : out   AxiLiteReadSlaveType;
      axiWriteMaster : in    AxiLiteWriteMasterType;
      axiWriteSlave  : out   AxiLiteWriteSlaveType;
      -- Clocks and Resets
      axiClk         : in    sl;
      axiRst         : in    sl);
end AxiI2cSfpCore;

architecture mapping of AxiI2cSfpCore is

   -- Note: PRESCALE_G = (clk_freq / (5 * i2c_freq)) - 1
   --       FILTER_G = (min_pulse_time / clk_period) + 1
   constant I2C_SCL_5xFREQ_C : real    := 5.0 * I2C_SCL_FREQ_G;
   constant PRESCALE_C       : natural := (getTimeRatio(AXI_CLK_FREQ_G, I2C_SCL_5xFREQ_C)) - 1;
   constant FILTER_C         : natural := natural(AXI_CLK_FREQ_G * I2C_MIN_PULSE_G) + 1;

   signal i2cRegMasterIn  : I2cRegMasterInType;
   signal i2cRegMasterOut : I2cRegMasterOutType;

   signal i2ci : i2c_in_type;
   signal i2co : i2c_out_type;

   signal status : AxiI2cSfpStatusType;
   signal config : AxiI2cSfpConfigType;
   
begin

   IOBUF_SCL : IOBUF
      port map (
         O  => i2ci.scl,                -- Buffer output
         IO => sfpInOut.scl,            -- Buffer inout port (connect directly to top-level port)
         I  => i2co.scl,                -- Buffer input
         T  => i2co.scloen);            -- 3-state enable input, high=input, low=output  

   IOBUF_SDA : IOBUF
      port map (
         O  => i2ci.sda,                -- Buffer output
         IO => sfpInOut.sda,            -- Buffer inout port (connect directly to top-level port)
         I  => i2co.sda,                -- Buffer input
         T  => i2co.sdaoen);            -- 3-state enable input, high=input, low=output  

   IOBUF_RATE0 : IOBUF
      port map (
         O  => open,                    -- Buffer output
         IO => sfpInOut.rateSel(0),     -- Buffer inout port (connect directly to top-level port)
         I  => config.rateSel(0),       -- Buffer input
         T  => '0');                    -- 3-state enable input, high=input, low=output    

   IOBUF_RATE1 : IOBUF                  -- Reserved for future use
      port map (
         O  => open,                    -- Buffer output
         IO => sfpInOut.rateSel(1),     -- Buffer inout port (connect directly to top-level port)
         I  => '0',                     -- Buffer input
         T  => '1');                    -- 3-state enable input, high=input, low=output           

   sfpOut.txDisable <= config.txDisable;

   status.rxLoss     <= sfpIn.rxLoss;
   status.moduleDetL <= sfpIn.moduleDetL;
   status.txFault    <= sfpIn.txFault;

   AxiI2cSfpReg_Inst : entity work.AxiI2cSfpReg
      generic map(
         TPD_G              => TPD_G,
         STATUS_CNT_WIDTH_G => STATUS_CNT_WIDTH_G,
         ALLOW_TX_DISABLE_G => ALLOW_TX_DISABLE_G,
         AXI_ERROR_RESP_G   => AXI_ERROR_RESP_G)
      port map(
         -- I2C Register Interface
         i2cRegMasterIn  => i2cRegMasterIn,
         i2cRegMasterOut => i2cRegMasterOut,
         -- AXI-Lite Register Interface
         axiReadMaster   => axiReadMaster,
         axiReadSlave    => axiReadSlave,
         axiWriteMaster  => axiWriteMaster,
         axiWriteSlave   => axiWriteSlave,
         -- Register Inputs/Outputs
         status          => status,
         config          => config,
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
