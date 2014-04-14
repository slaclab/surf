-------------------------------------------------------------------------------
-- Title         : AXI Lite Empty End Point
-- File          : AxiLiteEmpty.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 03/10/2014
-------------------------------------------------------------------------------
-- Description:
-- Empty slave endpoint for AXI Lite bus.
-- Absorbs writes and returns zeros on reads.
-- Supports a configurable number of write and read vectors.
-------------------------------------------------------------------------------
-- Copyright (c) 2014 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 03/10/2014: created.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

entity AxiLiteEmpty is
   generic (
      TPD_G           : time                  := 1 ns;
      NUM_WRITE_REG_G : integer range 1 to 32 := 1;
      NUM_READ_REG_G  : integer range 1 to 32 := 1
   );
   port (

      -- Local Bus
      axiClk                   : in  sl;
      axiClkRst                : in  sl;
      axiReadMaster            : in  AxiLiteReadMasterType;
      axiReadSlave             : out AxiLiteReadSlaveType;
      axiWriteMaster           : in  AxiLiteWriteMasterType;
      axiWriteSlave            : out AxiLiteWriteSlaveType;

      -- Write registers
      writeRegister            : out Slv32Array(NUM_WRITE_REG_G-1 downto 0);
      readRegister             : in  Slv32Array(NUM_READ_REG_G-1 downto 0) := (others=>(others=>'0'))
   );
end AxiLiteEmpty;

architecture STRUCTURE of AxiLiteEmpty is

   type RegType is record
      writeRegister     : Slv32Array(NUM_WRITE_REG_G-1 downto 0);
      axiReadSlave      : AxiLiteReadSlaveType;
      axiWriteSlave     : AxiLiteWriteSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      writeRegister    => (others=>(others=>'0')),
      axiReadSlave     => AXI_LITE_READ_SLAVE_INIT_C,
      axiWriteSlave    => AXI_LITE_WRITE_SLAVE_INIT_C
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   -- Sync
   process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process;

   -- Async
   process (axiClkRst, axiReadMaster, axiWriteMaster, r, readRegister ) is
      variable v         : RegType;
      variable axiStatus : AxiLiteStatusType;
   begin
      v := r;

      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);

      -- Write
      if (axiStatus.writeEnable = '1') then

         -- Write registers: 0x100
         if axiWriteMaster.awaddr(8) = '1' and axiWriteMaster.awaddr(7 downto 2) < NUM_WRITE_REG_G then
            v.writeRegister(conv_integer(axiWriteMaster.awaddr(7 downto 2))) := axiWriteMaster.wdata;
         end if;

         -- Send Axi response
         axiSlaveWriteResponse(v.axiWriteSlave);

      end if;

      -- Read
      if (axiStatus.readEnable = '1') then
         v.axiReadSlave.rdata := (others => '0');

         -- Write registers: 0x100
         if axiReadMaster.araddr(8) = '1' and axiReadMaster.araddr(7 downto 2) < NUM_WRITE_REG_G then
            v.axiReadSlave.rdata := r.writeRegister(conv_integer(axiReadMaster.araddr(7 downto 2)));

         -- Read Registers: 0x000
         elsif axiReadMaster.araddr(8) = '0' and axiReadMaster.araddr(7 downto 2) < NUM_READ_REG_G then
            v.axiReadSlave.rdata := readRegister(conv_integer(axiReadMaster.araddr(7 downto 2)));
         end if;

         -- Send Axi Response
         axiSlaveReadResponse(v.axiReadSlave);

      end if;

      -- Reset
      if (axiClkRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Next register assignment
      rin <= v;

      -- Outputs
      axiReadSlave  <= r.axiReadSlave;
      axiWriteSlave <= r.axiWriteSlave;
      writeRegister <= r.writeRegister;
      
   end process;

end architecture STRUCTURE;

