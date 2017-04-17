-------------------------------------------------------------------------------
-- File       : AxiI2cQsfpReg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-24
-- Last update: 2015-07-20
-------------------------------------------------------------------------------
-- Description: AXI-Lite Register Access Module
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
use work.AxiI2cQsfpPkg.all;
use work.I2cPkg.all;

entity AxiI2cQsfpReg is
   generic (
      TPD_G              : time                  := 1 ns;
      STATUS_CNT_WIDTH_G : natural range 1 to 32 := 32;
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
      status          : in  AxiI2cQsfpStatusType;
      config          : out AxiI2cQsfpConfigType;
      -- Global Signals
      axiClk          : in  sl;
      axiRst          : in  sl);      
end AxiI2cQsfpReg;

architecture rtl of AxiI2cQsfpReg is

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

   constant NUM_WRITE_REG_C : positive := 5;
   constant STATUS_SIZE_C   : positive := 2;
   constant NUM_READ_REG_C  : positive := (STATUS_SIZE_C+1);

   signal cntRst     : sl;
   signal rollOverEn : slv(STATUS_SIZE_C-1 downto 0);
   signal cntOut     : SlVectorArray(STATUS_SIZE_C-1 downto 0, STATUS_CNT_WIDTH_G-1 downto 0);

   signal regIn : AxiI2cQsfpStatusType;

   signal readRegister  : Slv32Array(0 to NUM_READ_REG_C-1)  := (others => x"00000000");
   signal writeRegister : Slv32Array(0 to NUM_WRITE_REG_C-1) := (others => x"00000000");

begin

   I2cRegMasterAxiBridge_Inst : entity work.I2cRegMasterAxiBridge
      generic map (
         TPD_G               => TPD_G,
         DEVICE_MAP_G        => DEVICE_MAP_C,
         EN_USER_REG_G       => true,
         NUM_WRITE_REG_G     => NUM_WRITE_REG_C-1,
         NUM_READ_REG_G      => NUM_READ_REG_C-1,
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
   config.modSel <= writeRegister(0)(0);
   config.rst    <= writeRegister(1)(0);
   config.lpMode <= writeRegister(2)(0);
   rollOverEn    <= writeRegister(3)(STATUS_SIZE_C-1 downto 0);
   cntRst        <= writeRegister(4)(0);

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
         statusIn(1)  => status.modPrst,
         statusIn(0)  => status.interrupt,
         -- Output Status bit Signals (rdClk domain) 
         statusOut(1) => regIn.modPrst,
         statusOut(0) => regIn.interrupt,
         -- Status Bit Counters Signals (rdClk domain) 
         cntRstIn     => cntRst,
         rollOverEnIn => rollOverEn,
         cntOut       => cntOut,
         -- Clocks and Reset Ports
         wrClk        => axiClk,
         rdClk        => axiClk);

   readRegister(2)(1) <= regIn.modPrst;
   readRegister(2)(0) <= regIn.interrupt;

   readRegister(1)(STATUS_CNT_WIDTH_G-1 downto 0) <= muxSlVectorArray(cntOut, 1);  -- modPrstCnt
   readRegister(0)(STATUS_CNT_WIDTH_G-1 downto 0) <= muxSlVectorArray(cntOut, 0);  -- interruptCnt
   
end rtl;
