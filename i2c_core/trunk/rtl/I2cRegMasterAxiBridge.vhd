-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : I2cRegMasterAxiBridge.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-09-23
-- Last update: 2014-01-31
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Maps a number of I2C devices on an I2C bus onto an AXI Bus.
-------------------------------------------------------------------------------
-- Copyright (c) 2013 SLAC National Accelerator Laboratory
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
      TPD_G               : time    := 1 ns;
      I2C_REG_ADDR_SIZE_G : integer := 8;
      DEVICE_MAP_G        : I2cAxiLiteDevArray);

   port (
      axiClk    : in sl;
      axiClkRst : in sl;

      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;

      i2cRegMasterIn  : out I2cRegMasterInType;
      i2cRegMasterOut : in  I2cRegMasterOutType);

end entity I2cRegMasterAxiBridge;

architecture rtl of I2cRegMasterAxiBridge is

   constant READ_C : boolean := false;
   constant WRITE_C : boolean := true;

   subtype I2C_DEV_AXI_ADDR_RANGE_C is natural range
      I2C_REG_ADDR_SIZE_G + bitSize(DEVICE_MAP_G'length) -1 downto I2C_REG_ADDR_SIZE_G;

   subtype I2C_REG_AXI_ADDR_RANGE_C is natural range
      I2C_REG_ADDR_SIZE_G-1 downto 0;

   type RegType is record
      axiReadSlave   : AxiLiteReadSlaveType;
      axiWriteSlave  : AxiLiteWriteSlaveType;
      i2cRegMasterIn : I2cRegMasterInType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      axiReadSlave   => AXI_READ_SLAVE_INIT_C,
      axiWriteSlave  => AXI_WRITE_SLAVE_INIT_C,
      i2cRegMasterIn => I2C_REG_MASTER_IN_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   -------------------------------------------------------------------------------------------------
   -- Main Comb Process
   -------------------------------------------------------------------------------------------------
   comb : process (axiClkRst, axiReadMaster, axiWriteMaster, i2cRegMasterOut, r) is
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
            ret.regAddr(I2C_REG_AXI_ADDR_RANGE_C) := axiWriteMaster.awaddr(I2C_REG_AXI_ADDR_RANGE_C);
         else
            ret.regAddr(I2C_REG_AXI_ADDR_RANGE_C) := axiReadMaster.araddr(I2C_REG_AXI_ADDR_RANGE_C);
         end if;

         ret.regWrData(DEVICE_MAP_G(i).dataSize-1 downto 0) :=
            axiWriteMaster.wData(DEVICE_MAP_G(i).dataSize-1 downto 0);
         
         ret.regAddrSize := conv_std_logic_vector(I2C_REG_ADDR_SIZE_G/8 - 1, 2);
         ret.regDataSize := conv_std_logic_vector(DEVICE_MAP_G(i).dataSize/8 - 1, 2);
         ret.endianness  := DEVICE_MAP_G(i).endianness;
         return ret;
      end function;
      
   begin
      v := r;

      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);


      if (axiStatus.writeEnable = '1') then
         -- Decode i2c device address and send command to I2cRegMaster
         devInt := conv_integer(axiWriteMaster.awaddr(I2C_DEV_AXI_ADDR_RANGE_C));

         v.i2cRegMasterIn        := setI2cRegMaster(devInt, WRITE_C);
         v.i2cRegMasterIn.regOp  := '1';  -- Write
         v.i2cRegMasterIn.regReq := '1';

      elsif (axiStatus.readEnable = '1') then
         devInt := conv_integer(axiReadMaster.araddr(I2C_DEV_AXI_ADDR_RANGE_C));

         -- Send transaction to I2cRegMaster
         v.i2cRegMasterIn        := setI2cRegMaster(devInt, READ_C);
         v.i2cRegMasterIn.regOp  := '0';  -- Read
         v.i2cRegMasterIn.regReq := '1';

      end if;

      if (i2cRegMasterOut.regAck = '1' and r.i2cRegMasterIn.regReq = '1') then
         v.i2cRegMasterIn.regReq := '0';
         axiResp                 := ite(i2cRegMasterOut.regFail = '1', AXI_RESP_SLVERR_C, AXI_RESP_OK_C);
         if (r.i2cRegMasterIn.regOp = '1') then
            axiSlaveWriteResponse(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiResp);
         else
            v.axiReadSlave.rdata := i2cRegMasterOut.regRdData;
            axiSlaveReadResponse(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiResp);
         end if;

      end if;

      ----------------------------------------------------------------------------------------------
      -- Reset
      ----------------------------------------------------------------------------------------------
      if (axiClkRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      axiReadSlave   <= v.axiReadSlave;
      axiWriteSlave  <= v.axiWriteSlave;
      i2cRegMasterIn <= v.i2cRegMasterIn;

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
