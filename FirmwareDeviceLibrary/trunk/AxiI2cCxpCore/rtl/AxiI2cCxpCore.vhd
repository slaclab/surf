-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AxiI2cCxpCore.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-10-21
-- Last update: 2014-10-21
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: AXI-Lite interface to CXP
--
--    Note: Set the addrBits on the crossbar for this module to 12 bits wide
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.I2cPkg.all;
use work.AxiI2cCxpPkg.all;

entity AxiI2cCxpCore is
   generic (
      TPD_G              : time                  := 1 ns;
      AXI_CLK_FREQ_G     : real                  := 200.0E+6;  -- units of Hz
      I2C_SCL_FREQ_G     : real                  := 100.0E+3;  -- units of Hz
      I2C_MIN_PULSE_G    : real                  := 100.0E-9;  -- units of seconds
      STATUS_CNT_WIDTH_G : natural range 1 to 32 := 32;
      AXI_ERROR_RESP_G   : slv(1 downto 0)       := AXI_RESP_SLVERR_C);
   port (
      -- CXP Ports
      cxpIn          : in    AxiI2cCxpInType;
      cxpInOut       : inout AxiI2cCxpInOutType;
      -- AXI-Lite Register Interface
      axiReadMaster  : in    AxiLiteReadMasterType;
      axiReadSlave   : out   AxiLiteReadSlaveType;
      axiWriteMaster : in    AxiLiteWriteMasterType;
      axiWriteSlave  : out   AxiLiteWriteSlaveType;
      -- Clocks and Resets
      axiClk         : in    sl;
      axiRst         : in    sl);
end AxiI2cCxpCore;

architecture mapping of AxiI2cCxpCore is

   -- Note: PRESCALE_G = (clk_freq / (5 * i2c_freq)) - 1
   --       FILTER_G = (min_pulse_time / clk_period) + 1
   constant I2C_SCL_5xFREQ_C : real    := getRealMult(5, I2C_SCL_FREQ_G);
   constant PRESCALE_C       : natural := (getTimeRatio(AXI_CLK_FREQ_G, I2C_SCL_5xFREQ_C)) - 1;
   constant FILTER_C         : natural := natural(getRealMult(AXI_CLK_FREQ_G, I2C_MIN_PULSE_G)) + 1;

   signal i2cRegMasterIn  : I2cRegMasterInType;
   signal i2cRegMasterOut : I2cRegMasterOutType;

   signal i2ci : i2c_in_type;
   signal i2co : i2c_out_type;

   signal status : AxiI2cCxpStatusType;
   signal config : AxiI2cCxpConfigType;

   signal irqRstL : sl;
   
begin
   
   cxpInOut.scl <= i2co.scl when(i2co.scloen = '0') else 'Z';
   i2ci.scl     <= cxpInOut.scl;

   cxpInOut.sda <= i2co.sda when(i2co.sdaoen = '0') else 'Z';
   i2ci.sda     <= cxpInOut.sda;

   cxpInOut.irqRstL <= '0' when(config.rst = '1') else 'Z';  -- Open drain output
   irqRstL          <= cxpInOut.irqRstL;

   status.irq       <= not(irqRstL);
   status.moduleDet <= not(cxpIn.moduleDetL);

   AxiI2cCxpReg_Inst : entity work.AxiI2cCxpReg
      generic map(
         TPD_G              => TPD_G,
         STATUS_CNT_WIDTH_G => STATUS_CNT_WIDTH_G,
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
