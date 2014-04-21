-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AxiSfpReg.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-18
-- Last update: 2014-04-21
-- Platform   : Vivado 2013.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiSfpPkg.all;
use work.I2cPkg.all;

entity AxiSfpReg is
   generic (
      TPD_G              : time                  := 1 ns;
      STATUS_CNT_WIDTH_G : natural range 1 to 32 := 32;
      ALLOW_TX_DISABLE_G : boolean               := false;
      AXI_ERROR_RESP_G   : slv(1 downto 0)       := AXI_RESP_SLVERR_C);
   port (
      -- I2C Register Interface
      i2cRegMasterIn  : out I2cRegMasterInType;
      i2cRegMasterOut : in  I2cRegMasterOutType;
      -- AXI-Lite Register Interface
      axiReadMaster   : in  AxiLiteReadMasterType;
      axiReadSlave    : out AxiLiteReadSlaveType;
      axiWriteMaster  : in  AxiLiteWriteMasterType;
      axiWriteSlave   : out AxiLiteWriteSlaveType;
      -- Register Inputs/Outputs
      status          : in  AxiSfpStatusType;
      config          : out AxiSfpConfigType;
      -- Global Signals
      axiClk          : in  sl;
      axiRst          : in  sl);      
end AxiSfpReg;

architecture rtl of AxiSfpReg is

   constant DEVICE_MAP_G : I2cAxiLiteDevArray(0 to 0) := (
      0             => (
         i2cAddress => "0001010000",    -- Default to the SFF-8074i standard EEPROM address (0xA0)
         i2cTenbit  => '0',
         dataSize   => 8,               -- in units of bits
         endianness => '1'));           -- Big endian  

   constant NUM_WRITE_REG_C : positive := 4;
   constant STATUS_SIZE_C   : positive := 3;
   constant NUM_READ_REG_C  : positive := (STATUS_SIZE_C+1);

   signal cntRst     : sl;
   signal rollOverEn : slv(STATUS_SIZE_C-1 downto 0);
   signal cntOut     : SlVectorArray(STATUS_SIZE_C-1 downto 0, STATUS_CNT_WIDTH_G-1 downto 0);

   signal regIn : AxiSfpStatusType;

   signal readRegister  : Slv32Array(0 to NUM_READ_REG_C)  := (others => x"00000000");
   signal writeRegister : Slv32Array(0 to NUM_WRITE_REG_C) := (others => x"00000000");

begin

   I2cRegMasterAxiBridge_Inst : entity work.I2cRegMasterAxiBridge
      generic map (
         TPD_G               => TPD_G,
         I2C_REG_ADDR_SIZE_G => 8,
         DEVICE_MAP_G        => DEVICE_MAP_G,
         NUM_WRITE_REG_G     => NUM_WRITE_REG_C,
         NUM_READ_REG_G      => NUM_READ_REG_C,
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
         -- Optional User Read/Write Register Interface
         readRegister    => readRegister,
         writeRegister   => writeRegister,
         -- Clock and Reset
         axiClk          => axiClk,
         axiRst          => axiRst);

   -------------------------------            
   -- Synchronization: Outputs
   -------------------------------
   config.txDisable <= writeRegister(0)(0) when(ALLOW_TX_DISABLE_G = true) else '0';
   config.rateSel   <= writeRegister(1)(1 downto 0);
   rollOverEn       <= writeRegister(2)(STATUS_SIZE_C-1 downto 0);
   cntRst           <= writeRegister(3)(0);

   -------------------------------
   -- Synchronization: Inputs
   ------------------------------- 
   SyncStatusVec_Inst : entity work.SyncStatusVector
      generic map (
         TPD_G          => TPD_G,
         OUT_POLARITY_G => '1',
         CNT_RST_EDGE_G => true,
         COMMON_CLK_G   => true,
         CNT_WIDTH_G    => STATUS_CNT_WIDTH_G,
         WIDTH_G        => STATUS_SIZE_C)     
      port map (
         -- Input Status bit Signals (wrClk domain)   
         statusIn(2)  => status.txFault,
         statusIn(1)  => status.moduleDetL,
         statusIn(0)  => status.rxLoss,
         -- Output Status bit Signals (rdClk domain) 
         statusOut(2) => regIn.txFault,
         statusOut(1) => regIn.moduleDetL,
         statusOut(0) => regIn.rxLoss,
         -- Status Bit Counters Signals (rdClk domain) 
         cntRstIn     => cntRst,
         rollOverEnIn => rollOverEn,
         cntOut       => cntOut,
         -- Clocks and Reset Ports
         wrClk        => axiClk,
         rdClk        => axiClk);

   readRegister(3)(2) <= regIn.txFault;
   readRegister(3)(1) <= regIn.moduleDetL;
   readRegister(3)(0) <= regIn.rxLoss;

   readRegister(2)(STATUS_CNT_WIDTH_G-1 downto 0) <= muxSlVectorArray(cntOut, 2);  -- txFaultCnt
   readRegister(1)(STATUS_CNT_WIDTH_G-1 downto 0) <= muxSlVectorArray(cntOut, 1);  -- moduleDetCnt
   readRegister(0)(STATUS_CNT_WIDTH_G-1 downto 0) <= muxSlVectorArray(cntOut, 0);  -- rxLossCnt
   
end rtl;
