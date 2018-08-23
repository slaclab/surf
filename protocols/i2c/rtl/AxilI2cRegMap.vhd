-------------------------------------------------------------------------------
-- File       : I2cRegMasterAxiBridge.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-09-23
-- Last update: 2018-01-08
-------------------------------------------------------------------------------
-- Description: Maps a number of I2C devices on an I2C bus onto an AXI Bus.
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.I2cPkg.all;

entity AxilI2cRegMap is

   generic (
      TPD_G            : time    := 1 ns;
      AXIL_ADDR_SIZE_G : integer := 8;
      DEV_CFG_G        : I2cAxiLiteDevType;
      ADDR_MAP_G       : I2cAxiLiteAddrMapArray);

   port (
      axiClk : in sl;
      axiRst : in sl;

      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;

      i2cRegMasterIn  : out I2cRegMasterInType;
      i2cRegMasterOut : in  I2cRegMasterOutType);

end entity AxilI2cRegMap;

architecture rtl of I2cRegMasterAxiBridge is

   constant READ_C  : boolean := false;
   constant WRITE_C : boolean := true;

   constant ADDR_MAP_LENGTH_C : natural := ADDR_MAP_G'length;

   type RegType is record
      writeRegister  : Slv32Array(0 to NUM_WRITE_REG_G);
      axiReadSlave   : AxiLiteReadSlaveType;
      axiWriteSlave  : AxiLiteWriteSlaveType;
      i2cRegMasterIn : I2cRegMasterInType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      writeRegister  => (others => x"00000000"),
      axiReadSlave   => AXI_LITE_READ_SLAVE_INIT_C,
      axiWriteSlave  => AXI_LITE_WRITE_SLAVE_INIT_C,
      i2cRegMasterIn => I2C_REG_MASTER_IN_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;


begin

   -------------------------------------------------------------------------------------------------
   -- Main Comb Process
   -------------------------------------------------------------------------------------------------
   comb : process (axiReadMaster, axiRst, axiWriteMaster, i2cRegMasterOut, r, readRegister,
                   writeRegisterInit) is
      variable v         : RegType;
      variable devInt    : integer;
      variable axiStatus : AxiLiteStatusType;
      variable axiResp   : slv(1 downto 0);

      impure function findRegAddr (readN : boolean) return integer is
         shared variable ret : integer;
      begin
         ret := -1;
         for i in ADDR_MAP_G'range
         if (readN = READ_C) then
            if (ADDR_MAP_G(i).axilAddr(AXIL_ADDR_SIZE_G-1 downto 0) = axiReadMaster.araddr(AXIL_ADDR_SIZE_G-1 downto 0)) then
               ret := i;
            end if;
         else
            if (ADDR_MAP_G(i).axilAddr(AXIL_ADDR_SIZE_G-1 downto 0) = axiReadMaster.awaddr(AXIL_ADDR_SIZE_G-1 downto 0)) then
               ret := i;
            end if;
         end loop;
      end function;


      impure function setI2cRegMaster (i : integer) return I2cRegMasterInType is
         variable ret : I2cRegMasterInType := I2C_REG_MASTER_IN_INIT_C;
      begin
         ret.i2cAddr                                     := DEVICE_CFG_G.i2cAddress;
         ret.tenbit                                      := DEVICE_CFG_G.i2cTenbit;
         ret.regAddr                                     := ADDR_MAP_G(index).regAddr;
         ret.regWrData(DEVICE_CFG_G.dataSize-1 downto 0) := axiWriteMaster.wData(DEVICE_CFG_G.dataSize-1 downto 0);
         ret.regAddrSize                                 := toSlv(wordCount(DEVICE_CFG_G.addrSize, 8) - 1, 2);
         ret.regAddrSkip                                 := toSl(DEVICE_CFG_G.addrSize = 0);
         ret.regDataSize                                 := toSlv(wordCount(DEVICE_CFG_G.dataSize, 8) - 1, 2);
         ret.endianness                                  := DEVICE_CFG_G.endianness;
         ret.repeatStart                                 := DEVICE_CFG_G.repeatStart;
         return ret;
      end function;

   begin
      v := r;

      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);


      if (axiStatus.writeEnable = '1') then
         -- Decode address and perform write
         devInt := findRegAddr(WRITE_C);
         if (devInt /= -1) then
            v.i2cRegMasterIn        := setI2cRegMaster(devInt);
            v.i2cRegMasterIn.regOp  := '1';  -- Write
            v.i2cRegMasterIn.regReq := '1';
         else
            axiSlaveWriteResponse(v.axiWriteSlave, AXI_RESP_DECERR_C);
         end if;

      elsif (axiStatus.readEnable = '1') then
         devInt := findRegAddr(READ_C);
         if (devInt /= -1) then
            -- Send transaction to I2cRegMaster
            v.i2cRegMasterIn        := setI2cRegMaster(devInt);
            v.i2cRegMasterIn.regOp  := '0';  -- Read
            v.i2cRegMasterIn.regReq := '1';
         else
            -- Send AXI Error response
            axiSlaveReadResponse(v.axiReadSlave, AXI_RESP_DECERR_C);
         end if;

      end if;

      if (i2cRegMasterOut.regAck = '1' and r.i2cRegMasterIn.regReq = '1') then
         v.i2cRegMasterIn.regReq := '0';
         axiResp                 := ite(i2cRegMasterOut.regFail = '1', AXI_RESP_SLVERR_C, AXI_RESP_OK_C);
         if (r.i2cRegMasterIn.regOp = '1') then
            axiSlaveWriteResponse(v.axiWriteSlave, axiResp);
         else
            v.axiReadSlave.rdata := i2cRegMasterOut.regRdData;
            if (i2cRegMasterOut.regFail = '1') then
               v.axiReadSlave.rdata := X"000000" & i2cRegMasterOut.regFailCode;
            end if;
            axiSlaveReadResponse(v.axiReadSlave, axiResp);
         end if;

      end if;

      ----------------------------------------------------------------------------------------------
      -- Reset
      ----------------------------------------------------------------------------------------------
      if (axiRst = '1') then
         v               := REG_INIT_C;
         v.writeRegister := writeRegisterInit;
      end if;

      rin <= v;

      axiReadSlave   <= r.axiReadSlave;
      axiWriteSlave  <= r.axiWriteSlave;
      i2cRegMasterIn <= r.i2cRegMasterIn;
      writeRegister  <= r.writeRegister;

   end process comb;

   -------------------------------------------------------------------------------------------------
   -- Sequential Process
   -------------------------------------------------------------------------------------------------
   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;

