-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AtlasTtcTxEmuSer.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-06-05
-- Last update: 2015-02-27
-- Platform   : Vivado 2014.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;

entity AtlasTtcTxEmuSer is
   generic (
      TPD_G : time := 1 ns);      
   port (
      clk     : in  sl;
      rst     : in  sl;
      chA     : in  sl;
      chB     : in  sl;
      sync    : out sl;
      emuData : out sl);
end AtlasTtcTxEmuSer;

architecture rtl of AtlasTtcTxEmuSer is

   type RegType is record
      data : sl;
      sync : sl;
      cnt  : natural range 0 to 3;
   end record;
   
   constant REG_INIT_C : RegType := (
      data => '0',
      sync => '0',
      cnt  => 0);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (chA, chB, r, rst) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals
      v.sync := '0';

      -- Increment the counter
      v.cnt := r.cnt + 1;

      -- State Machine
      case (r.cnt) is
         ----------------------------------------------------------------------
         when 0 =>
            -- Toggle the data line
            v.data := not(r.data);
         ----------------------------------------------------------------------
         when 1 =>
            -- Check Channel A logic level
            if chA = '1' then
               -- Toggle the data line
               v.data := not(r.data);
            end if;
         ----------------------------------------------------------------------
         when 2 =>
            -- Toggle the data line
            v.data := not(r.data);
         ----------------------------------------------------------------------
         when 3 =>
            -- Check Channel B logic level
            if chB = '1' then
               -- Toggle the data line
               v.data := not(r.data);
            end if;
            -- Reset the counter
            v.cnt  := 0;
            -- Send the SYNC strobe
            v.sync := '1';
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      emuData <= r.data;
      sync    <= r.sync;
      
   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
