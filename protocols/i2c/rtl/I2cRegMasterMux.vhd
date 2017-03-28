-------------------------------------------------------------------------------
-- File       : I2cRegMasterMux.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-09-21
-- Last update: 2013-11-20
-------------------------------------------------------------------------------
-- Description: Multiplexes access to a single I2cRegMaster module
-- Attached devices may also lock others out in order to execute multiple
-- transactions in a row. To do this, lockReq must be set high for the first
-- transaction and set low for the last transaction.
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
use work.I2cPkg.all;

entity I2cRegMasterMux is
   
   generic (
      TPD_G        : time                 := 1 ns;
      NUM_INPUTS_C : natural range 2 to 8 := 2);
   port (
      clk       : in  sl;
      srst      : in  sl                           := '0';
      arst      : in  sl                           := '0';
      lockReq   : in  slv(NUM_INPUTS_C-1 downto 0) := (others => '0');
      regIn     : in  I2cRegMasterInArray(0 to NUM_INPUTS_C-1);
      regOut    : out I2cRegMasterOutArray(0 to NUM_INPUTS_C-1);
      masterIn  : out I2cRegMasterInType;
      masterOut : in  I2cRegMasterOutType);

end entity I2cRegMasterMux;

architecture rtl of I2cRegMasterMux is

   type RegType is record
      locked   : sl;
      sel      : slv(log2(NUM_INPUTS_C)-1 downto 0);
      regOut   : I2cRegMasterOutArray(0 to NUM_INPUTS_C-1);
      masterIn : I2cRegMasterInType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      locked   => '0',
      sel      => (others => '0'),
      regOut   => (others => I2C_REG_MASTER_OUT_INIT_C),
      masterIn => I2C_REG_MASTER_IN_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (lockReq, masterOut, r, regIn, srst) is
      variable v      : RegType;
      variable selInt : integer;
   begin
      v := r;

      selInt := conv_integer(r.sel);

      if (r.locked = '0') then
         v.sel := r.sel + 1;            -- Increment only if no channel has a lock
      end if;

      v.masterIn.regReq := '0';

      v.regOut := (others => I2C_REG_MASTER_OUT_INIT_C);

      if (regIn(selInt).regReq = '1') then
         v.locked         := lockReq(selInt);  -- Grant lock if requested
         v.sel            := r.sel;
         v.masterIn       := regIn(selInt);
         v.regOut(selInt) := masterOut;
      end if;

      if (srst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      regOut   <= r.regOut;
      masterIn <= r.masterIn;
      
   end process comb;

   seq : process (clk, arst) is
   begin
      if (arst = '1') then
         r <= REG_INIT_C after TPD_G;
      elsif (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
