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
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
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
      TPD_G            : time                  := 1 ns;
      AXI_ERROR_RESP_G : slv(1 downto 0)       := AXI_RESP_OK_C;
      NUM_WRITE_REG_G  : integer range 1 to 32 := 1;
      NUM_READ_REG_G   : integer range 1 to 32 := 1);
   port (
      -- AXI-Lite Bus
      axiClk         : in  sl;
      axiClkRst      : in  sl;
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;
      -- User Read/Write registers
      writeRegister  : out Slv32Array(NUM_WRITE_REG_G-1 downto 0);
      readRegister   : in  Slv32Array(NUM_READ_REG_G-1 downto 0) := (others => (others => '0')));
end AxiLiteEmpty;

architecture rtl of AxiLiteEmpty is

   type RegType is record
      writeRegister : Slv32Array(NUM_WRITE_REG_G-1 downto 0);
      axiReadSlave  : AxiLiteReadSlaveType;
      axiWriteSlave : AxiLiteWriteSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      writeRegister => (others => (others => '0')),
      axiReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axiWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (axiClkRst, axiReadMaster, axiWriteMaster, r, readRegister) is
      variable v      : RegType;
      variable regCon : AxiLiteEndPointType;
      variable i      : natural;
   begin
      -- Latch the current value
      v := r;

      -- Determine the transaction type
      axiSlaveWaitTxn(regCon, axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave);

      -- Map the read registers = [0x000:0x0FF]
      for i in NUM_READ_REG_G-1 downto 0 loop
         axiSlaveRegisterR(regCon, toSlv((i*4)+0, 9), 0, readRegister(i));
      end loop;

      -- Map the write registers = [0x100:0x1FF]
      for i in NUM_WRITE_REG_G-1 downto 0 loop
         axiSlaveRegister(regCon, toSlv((i*4)+256, 9), 0, v.writeRegister(i));
      end loop;

      -- Closeout the transaction
      axiSlaveDefault(regCon, v.axiWriteSlave, v.axiReadSlave, AXI_ERROR_RESP_G);

      -- Synchronous Reset
      if (axiClkRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      axiReadSlave  <= r.axiReadSlave;
      axiWriteSlave <= r.axiWriteSlave;
      writeRegister <= r.writeRegister;
      
   end process comb;

   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
