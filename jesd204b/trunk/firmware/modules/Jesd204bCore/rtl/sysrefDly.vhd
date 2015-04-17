-------------------------------------------------------------------------------
-- Title      : Delay sysref signal 
-------------------------------------------------------------------------------
-- File       : SysrefDly.vhd
-- Author     : Uros Legat  <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory (Cosylab)
-- Created    : 2015-04-15
-- Last update: 2015-04-15
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Delay sysref signal to align timing on two different receiver devices (FPGA, DAC). 
--              The receiver devices in this core are already aligned and separate delay for separate 
--              RX modules is not necessary.
--              
--              Delays the sysref for 1 to 2^DLY_WIDTH_G clock cycles.
--              
--              
-------------------------------------------------------------------------------
-- Copyright (c) 2013 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.Jesd204bPkg.all;

entity SysrefDly is
   generic (
      TPD_G        : time       := 1 ns;
      DLY_WIDTH_G  : positive   := 5 -- number of bits in the delay setting (2**DLY_WIDTH_G is the max size of delay)
   );
   port (
      clk      : in  sl;
      rst      : in  sl;
      
      dly_i    : in  slv(DLY_WIDTH_G-1 downto 0);
      
      -- Synchronisation input
      sysref_i : in  sl; 
      
      -- Synchronisation delayed input      
      sysref_o  : out sl  
   );
end entity SysrefDly;

architecture rtl of SysrefDly is
   
   type RegType is record
      shft      : slv(2**DLY_WIDTH_G-1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      shft       => (others => '0')
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
   --! Internal signals
   signal s_index : integer;   
   
begin

   comb : process (r, rst,sysref_i) is
      variable v : RegType;
   begin
      v := r;
      
      -- Delay sysref for one clock cycle 
      v.shft := r.shft(2**DLY_WIDTH_G-2 downto 0) & sysref_i;
      
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;
      
   end process comb;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
   -- Output assignment
   sysref_o <= varIndexOutFunc(r.shft, dly_i);

end architecture rtl;
