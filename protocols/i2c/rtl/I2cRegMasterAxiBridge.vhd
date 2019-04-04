-------------------------------------------------------------------------------
-- File       : I2cRegMasterAxiBridge.vhd
-- Company    : SLAC National Accelerator Laboratory
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

entity I2cRegMasterAxiBridge is

   generic (
      TPD_G            : time                   := 1 ns;
      DEVICE_MAP_G     : I2cAxiLiteDevArray     := I2C_AXIL_DEV_ARRAY_DEFAULT_C);
   port (
      axiClk : in sl;
      axiRst : in sl;

      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;

      i2cSelectOut    : out slv(DEVICE_MAP_G'length-1 downto 0);
      i2cRegMasterIn  : out I2cRegMasterInType;
      i2cRegMasterOut : in  I2cRegMasterOutType);

end entity I2cRegMasterAxiBridge;

architecture rtl of I2cRegMasterAxiBridge is

   constant READ_C  : boolean := false;
   constant WRITE_C : boolean := true;

   constant DEVICE_MAP_LENGTH_C : natural := DEVICE_MAP_G'length;

   -- Number of device register space address bits maped into axi bus is determined by
   -- the maximum address size of all the devices.
   constant I2C_REG_ADDR_SIZE_C : natural := maxAddrSize(DEVICE_MAP_G);

   constant I2C_REG_AXI_ADDR_LOW_C  : natural := 2;
   constant I2C_REG_AXI_ADDR_HIGH_C : natural :=
      ite(I2C_REG_ADDR_SIZE_C = 0,
          2,
          I2C_REG_AXI_ADDR_LOW_C + I2C_REG_ADDR_SIZE_C-1);

   subtype I2C_REG_AXI_ADDR_RANGE_C is natural range
      I2C_REG_AXI_ADDR_HIGH_C downto I2C_REG_AXI_ADDR_LOW_C;

   -- Number of device address bits mapped into axi bus space is determined by number of devices
   constant I2C_DEV_AXI_ADDR_LOW_C : natural := I2C_REG_AXI_ADDR_HIGH_C + 1;
   constant I2C_DEV_AXI_ADDR_HIGH_C : natural := ite(
      (DEVICE_MAP_LENGTH_C = 1),
      I2C_DEV_AXI_ADDR_LOW_C,
      (I2C_DEV_AXI_ADDR_LOW_C + log2(DEVICE_MAP_LENGTH_C) - 1));

   subtype I2C_DEV_AXI_ADDR_RANGE_C is natural range
      I2C_DEV_AXI_ADDR_HIGH_C downto I2C_DEV_AXI_ADDR_LOW_C;

   type RegType is record
      axiReadSlave   : AxiLiteReadSlaveType;
      axiWriteSlave  : AxiLiteWriteSlaveType;
      i2cSelectOut   : slv(DEVICE_MAP_G'length-1 downto 0);
      i2cRegMasterIn : I2cRegMasterInType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      axiReadSlave   => AXI_LITE_READ_SLAVE_INIT_C,
      axiWriteSlave  => AXI_LITE_WRITE_SLAVE_INIT_C,
      i2cSelectOut   => (others=>'0'),
      i2cRegMasterIn => I2C_REG_MASTER_IN_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   -------------------------------------------------------------------------------------------------
   -- Main Comb Process
   -------------------------------------------------------------------------------------------------
   comb : process (axiReadMaster, axiRst, axiWriteMaster, i2cRegMasterOut, r) is
      variable v         : RegType;
      variable devInt    : integer;
      variable axiStatus : AxiLiteStatusType;
      variable axiResp   : slv(1 downto 0);

      impure function setI2cRegMaster (i : integer; readN : boolean) return I2cRegMasterInType is
         variable ret : I2cRegMasterInType := I2C_REG_MASTER_IN_INIT_C;
      begin
         ret.i2cAddr := DEVICE_MAP_G(i).i2cAddress;
         ret.tenbit  := DEVICE_MAP_G(i).i2cTenbit;

         if (readN = READ_C) then
            ret.regAddr(I2C_REG_ADDR_SIZE_C-1 downto 0) := axiReadMaster.araddr(I2C_REG_AXI_ADDR_RANGE_C);
         else
            ret.regAddr(I2C_REG_ADDR_SIZE_C-1 downto 0) := axiWriteMaster.awaddr(I2C_REG_AXI_ADDR_RANGE_C);
         end if;

         ret.regWrData(DEVICE_MAP_G(i).dataSize-1 downto 0) := axiWriteMaster.wData(DEVICE_MAP_G(i).dataSize-1 downto 0);

         ret.regAddrSize := toSlv(wordCount(DEVICE_MAP_G(i).addrSize, 8) - 1, 2);
         ret.regAddrSkip := toSl(DEVICE_MAP_G(i).addrSize = 0);
         ret.regDataSize := toSlv(wordCount(DEVICE_MAP_G(i).dataSize, 8) - 1, 2);
         ret.endianness  := DEVICE_MAP_G(i).endianness;
         ret.repeatStart := DEVICE_MAP_G(i).repeatStart;
         return ret;
      end function;

   begin
      v := r;

      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);
      
      if (axiStatus.writeEnable = '1') then
      
            -- I2C Address Space
            -- Decode i2c device address and send command to I2cRegMaster
            devInt := conv_integer(axiWriteMaster.awaddr(I2C_DEV_AXI_ADDR_RANGE_C));

            v.i2cRegMasterIn        := setI2cRegMaster(devInt, WRITE_C);
            v.i2cRegMasterIn.regOp  := '1';  -- Write
            v.i2cRegMasterIn.regReq := '1';
            v.i2cSelectOut(devInt)  := '1';

      elsif (axiStatus.readEnable = '1') then
            -- I2C Address Space
            -- Decode i2c device address and send command to I2cRegMaster
            devInt := conv_integer(axiReadMaster.araddr(I2C_DEV_AXI_ADDR_RANGE_C));

            -- Send transaction to I2cRegMaster
            v.i2cRegMasterIn        := setI2cRegMaster(devInt, READ_C);
            v.i2cRegMasterIn.regOp  := '0';  -- Read
            v.i2cRegMasterIn.regReq := '1';
            v.i2cSelectOut(devInt)  := '1';

      end if;

      if (i2cRegMasterOut.regAck = '1' and r.i2cRegMasterIn.regReq = '1') then
         v.i2cRegMasterIn.regReq := '0';
         v.i2cSelectOut          := (others=>'0');
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
      end if;

      rin <= v;

      axiReadSlave   <= r.axiReadSlave;
      axiWriteSlave  <= r.axiWriteSlave;
      i2cSelectOut   <= r.i2cSelectOut;
      i2cRegMasterIn <= r.i2cRegMasterIn;

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

