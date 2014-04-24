-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AxiI2cSfpCore.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-18
-- Last update: 2014-04-21
-- Platform   : Vivado 2013.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: AXI-Lite interface to SFP
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
use work.AxiI2cSfpPkg.all;

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
   constant I2C_SCL_5xFREQ_C : real    := getRealMult(5, I2C_SCL_FREQ_G);
   constant PRESCALE_C       : natural := (getTimeRatio(AXI_CLK_FREQ_G, I2C_SCL_5xFREQ_C)) - 1;
   constant FILTER_C         : natural := natural(getRealMult(AXI_CLK_FREQ_G, I2C_MIN_PULSE_G)) + 1;

   signal i2cRegMasterIn  : I2cRegMasterInType;
   signal i2cRegMasterOut : I2cRegMasterOutType;

   signal i2ci : i2c_in_type;
   signal i2co : i2c_out_type;

   signal status : AxiI2cSfpStatusType;
   signal config : AxiI2cSfpConfigType;
   
begin
   
   sfpInOut.scl <= i2co.scl when(i2co.scloen = '0') else 'Z';
   i2ci.scl     <= sfpInOut.scl;

   sfpInOut.sda <= i2co.sda when(i2co.sdaoen = '0') else 'Z';
   i2ci.sda     <= sfpInOut.sda;

   sfpInOut.rateSel(0) <= config.rateSel(0);
   sfpInOut.rateSel(1) <= 'Z';          -- reserved for future use

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
