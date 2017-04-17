-------------------------------------------------------------------------------
-- File       : AxiI2cSfpReg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-18
-- Last update: 2015-07-20
-------------------------------------------------------------------------------
-- Description: AXI-Lite Register Acess Module
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiI2cSfpPkg.all;
use work.I2cPkg.all;

entity AxiI2cSfpReg is
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
      status          : in  AxiI2cSfpStatusType;
      config          : out AxiI2cSfpConfigType;
      -- Global Signals
      axiClk          : in  sl;
      axiRst          : in  sl);      
end AxiI2cSfpReg;

architecture rtl of AxiI2cSfpReg is

   constant DEVICE_MAP_C : I2cAxiLiteDevArray(0 to 1) := (
      0             => MakeI2cAxiLiteDevType(
         i2cAddress => "1010000",    -- Configuration PROM
         dataSize   => 8,               -- in units of bits
         addrSize   => 8,               -- in units of bits
         endianness => '1'),            -- Big endian 
      1             => MakeI2cAxiLiteDevType(
         i2cAddress => "1010001",    -- Diagnostic Monitoring 
         dataSize   => 8,               -- in units of bits
         addrSize   => 8,               -- in units of bits
         endianness => '1'));           -- Big endian   

   constant NUM_WRITE_REG_C : positive := 4;
   constant STATUS_SIZE_C   : positive := 3;
   constant NUM_READ_REG_C  : positive := (STATUS_SIZE_C+1);
   
   constant WRITE_REG_INIT_C : Slv32Array(0 to NUM_WRITE_REG_C-1) := (
      0 => x"00000000",                 -- config.txDisable
      1 => x"00000003",                 -- config.rateSel
      2 => x"00000000",                 -- rollOverEn 
      3 => x"00000000");                -- cntRst 

   signal cntRst     : sl;
   signal rollOverEn : slv(STATUS_SIZE_C-1 downto 0);
   signal cntOut     : SlVectorArray(STATUS_SIZE_C-1 downto 0, STATUS_CNT_WIDTH_G-1 downto 0);

   signal regIn : AxiI2cSfpStatusType;

   signal readRegister  : Slv32Array(0 to NUM_READ_REG_C-1)  := (others => x"00000000");
   signal writeRegister : Slv32Array(0 to NUM_WRITE_REG_C-1) := (others => x"00000000");

begin

   I2cRegMasterAxiBridge_Inst : entity work.I2cRegMasterAxiBridge
      generic map (
         TPD_G            => TPD_G,
         DEVICE_MAP_G     => DEVICE_MAP_C,
         EN_USER_REG_G    => true,
         NUM_WRITE_REG_G  => NUM_WRITE_REG_C-1,
         NUM_READ_REG_G   => NUM_READ_REG_C-1,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G)      
      port map (
         -- I2C Interface
         i2cRegMasterIn    => i2cRegMasterIn,
         i2cRegMasterOut   => i2cRegMasterOut,
         -- AXI-Lite Register Interface
         axiReadMaster     => axiReadMaster,
         axiReadSlave      => axiReadSlave,
         axiWriteMaster    => axiWriteMaster,
         axiWriteSlave     => axiWriteSlave,
         -- Optional User Read/Write Register Interface
         readRegister      => readRegister,
         writeRegisterInit => WRITE_REG_INIT_C,
         writeRegister     => writeRegister,
         -- Clock and Reset
         axiClk            => axiClk,
         axiRst            => axiRst);

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
