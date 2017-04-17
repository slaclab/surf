-------------------------------------------------------------------------------
-- File       : AxiI2cCxpReg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-10-21
-- Last update: 2014-10-21
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
use work.AxiI2cCxpPkg.all;
use work.I2cPkg.all;

entity AxiI2cCxpReg is
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
      status          : in  AxiI2cCxpStatusType;
      config          : out AxiI2cCxpConfigType;
      -- Global Signals
      axiClk          : in  sl;
      axiRst          : in  sl);      
end AxiI2cCxpReg;

architecture rtl of AxiI2cCxpReg is

   constant TX_INDEX_C : natural := 0;
   constant RX_INDEX_C : natural := 1;

   constant DEVICE_MAP_C : I2cAxiLiteDevArray(0 to 1) := (
      TX_INDEX_C    => MakeI2cAxiLiteDevType(
         i2cAddress => "1010000",    -- TX Memory Map
         dataSize   => 8,               -- in units of bits
         addrSize   => 8,               -- in units of bits
         endianness => '1'),            -- Big Endian  
      RX_INDEX_C    => MakeI2cAxiLiteDevType(
         i2cAddress => "1010100",    -- RX Memory Map
         dataSize   => 8,               -- in units of bits
         addrSize   => 8,               -- in units of bits
         endianness => '1'));           -- Big Endian           

   constant NUM_WRITE_REG_C : positive := 3;
   constant STATUS_SIZE_C   : positive := 2;
   constant NUM_READ_REG_C  : positive := (STATUS_SIZE_C+1);
   
   constant WRITE_REG_INIT_C : Slv32Array(0 to NUM_WRITE_REG_C-1) := (
      0 => x"00000000",                 -- config.rst
      1 => x"00000000",                 -- rollOverEn 
      2 => x"00000000");                -- cntRst 

   signal cntRst     : sl;
   signal rollOverEn : slv(STATUS_SIZE_C-1 downto 0);
   signal cntOut     : SlVectorArray(STATUS_SIZE_C-1 downto 0, STATUS_CNT_WIDTH_G-1 downto 0);

   signal regIn : AxiI2cCxpStatusType;

   signal readRegister  : Slv32Array(0 to NUM_READ_REG_C-1)  := (others => x"00000000");
   signal writeRegister : Slv32Array(0 to NUM_WRITE_REG_C-1) := (others => x"00000000");

begin

   I2cRegMasterAxiBridge_Inst : entity work.I2cRegMasterAxiBridge
      generic map (
         TPD_G               => TPD_G,
         DEVICE_MAP_G        => DEVICE_MAP_C,
         EN_USER_REG_G       => true,
         NUM_WRITE_REG_G     => (NUM_WRITE_REG_C-1),
         NUM_READ_REG_G      => (NUM_READ_REG_C-1),
         AXI_ERROR_RESP_G    => AXI_ERROR_RESP_G)      
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
   config.rst <= writeRegister(0)(0);
   rollOverEn <= writeRegister(1)(STATUS_SIZE_C-1 downto 0);
   cntRst     <= writeRegister(2)(0);

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
         statusIn(1)  => status.irq,
         statusIn(0)  => status.moduleDet,
         -- Output Status bit Signals (rdClk domain) 
         statusOut(1) => regIn.irq,
         statusOut(0) => regIn.moduleDet,
         -- Status Bit Counters Signals (rdClk domain) 
         cntRstIn     => cntRst,
         rollOverEnIn => rollOverEn,
         cntOut       => cntOut,
         -- Clocks and Reset Ports
         wrClk        => axiClk,
         rdClk        => axiClk);

   readRegister(2)(1) <= regIn.irq;
   readRegister(2)(0) <= regIn.moduleDet;

   readRegister(1)(STATUS_CNT_WIDTH_G-1 downto 0) <= muxSlVectorArray(cntOut, 1);  -- irqCnt
   readRegister(0)(STATUS_CNT_WIDTH_G-1 downto 0) <= muxSlVectorArray(cntOut, 0);  -- moduleDetCnt
   
end rtl;
