-------------------------------------------------------------------------------
-- Title      : Calculates and checks the RUDP packet checksum.
-------------------------------------------------------------------------------
-- File       : Chksum.vhd
-- Author     : Uros Legat  <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory (Cosylab)
-- Created    : 2015-08-09
-- Last update: 2015-08-09
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Calculates and checks the RUDP packet checksum.
--                     
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;

entity Chksum is
   generic (
      TPD_G        : time     := 1 ns;
      -- Data with is 16 for IP/UDP/TCP/RUDP
      DATA_WIDTH_G : positive := 16    
   );
   port (
      clk_i      : in  sl;
      rst_i      : in  sl;
      
      -- Enables and initialises the calculations.
      -- enable_i <= '1' enables the calculation.
      -- enable_i <= '0' initialises the calculation, registers hold
      -- the checksum value until the next calculation.
      enable_i   : in  sl;
      
      -- Has to indicate valid data and defines the number of calculation clock cycles.
      strobe_i   : in  sl;      
      
      -- Initial value of the sum
      -- Calculation: init_i = (others=>'0')
      -- Validation:  init_i = Checksum value
      init_i : in  slv(DATA_WIDTH_G-1 downto 0);
      
      -- Fixed to 2 octets (standard specification)
      data_i  : in  slv(DATA_WIDTH_G-1 downto 0);

      -- Checksum output (registered until new value is generated)
      chksum_o  : out slv(DATA_WIDTH_G-1 downto 0);
      -- Indicates when the module is ready and the checksum is valid
      valid_o : out sl;
      -- Indicates if the calculated checksum is ok (valid upon valid_o='1')
      check_o : out sl
   );
end entity Chksum;

architecture rtl of Chksum is
  
   type RegType is record
      sum  : slv(DATA_WIDTH_G downto 0);
      chksum : slv(DATA_WIDTH_G-1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      sum      => (others=>'0'),
      chksum   => (others=>'0')
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
begin
   
   comb : process (r, rst_i, enable_i, init_i, data_i, strobe_i) is
      variable v : RegType;
   begin
      v := r;
      
      -- Cumulative sum of the data_i while enabled
      if ( enable_i = '0')   then
         v.sum := ('0' & init_i);
      elsif ( strobe_i = '1')   then
         -- Add carry bit to the 16 bit value
         v.sum := ('0' & r.sum(DATA_WIDTH_G-1 downto 0)) + r.sum(DATA_WIDTH_G) + data_i;
      else
         v.sum := r.sum;
      end if;
            
      -- Register/keep the checksum when disabled otherwise
      -- calculate the ones complement (bitwise negate) 
      if ( enable_i = '1')   then
         v.chksum := not r.sum(DATA_WIDTH_G-1 downto 0);
      else
         v.chksum := r.chksum;
      end if;
      
      if (rst_i = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;
      -----------------------------------------------------------
   end process comb;

   seq : process (clk_i) is
   begin
      if (rising_edge(clk_i)) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   ---------------------------------------------------------------------
   -- Output assignment
   chksum_o <= r.chksum;
   valid_o  <= not enable_i;
   check_o  <= '1' when r.chksum = (r.chksum'range => '0') else '0';
   ---------------------------------------------------------------------
end architecture rtl;