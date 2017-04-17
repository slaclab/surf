-------------------------------------------------------------------------------
-- File       : Chksum.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-08-09
-- Last update: 2015-08-09
-------------------------------------------------------------------------------
-- Description: Calculates and checks the RUDP packet checksum.
--              Checksum for IP/UDP/TCP/RUDP.
--              Works with 64-bit word     
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

entity Chksum is
   generic (
      TPD_G          : time     := 1 ns;
      -- 
      DATA_WIDTH_G   : positive := 64;
      CSUM_WIDTH_G   : positive := 16      
   );
   port (
      clk_i      : in  sl;
      rst_i      : in  sl;
      
      -- Enables and initializes the calculations.
      -- enable_i <= '1' enables the calculation.
      --                 the checksum value holds as long as enabled.
      -- enable_i <= '0' initializes the calculation.
      enable_i   : in  sl;
      
      -- Has to indicate valid data and defines the number of calculation clock cycles.
      strobe_i   : in  sl;
      
      -- Length of checksumed data
      length_i   : in positive;      
      
      -- Initial value of the sum
      -- Calculation: init_i = (others=>'0')
      -- Validation:  init_i = Checksum value
      init_i : in  slv(CSUM_WIDTH_G-1 downto 0);
      
      -- Fixed to 2 octets (standard specification)
      data_i  : in  slv(DATA_WIDTH_G-1 downto 0);
     
      -- Direct out 1 c-c delay
      chksum_o  : out slv(CSUM_WIDTH_G-1 downto 0);
      
      -- Indicates when the module is ready and the checksum is valid
      valid_o : out sl;
      -- Indicates if the calculated checksum is ok (valid upon valid_o='1')
      check_o : out sl
   );
end entity Chksum;

architecture rtl of Chksum is

   constant RATIO_C : positive := DATA_WIDTH_G/CSUM_WIDTH_G;
   
   type RegType is record
      sum    : slv(CSUM_WIDTH_G+4 downto 0);
      chksum : slv(CSUM_WIDTH_G downto 0);
      lenCnt : natural;
      valid  : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      sum      => (others=>'0'),
      chksum   => (others=>'0'),
      lenCnt   => 0,
      valid    => '0'
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
   signal s_dataWordSum : slv(CSUM_WIDTH_G+1 downto 0);
     

   
begin
   -- TODO make it generic
   --data_i((CSUM_WIDTH_G-1)+(CSUM_WIDTH_G*I) downto CSUM_WIDTH_G*I);   
   s_dataWordSum <=   "00"& data_i(63 downto 48) +
                            data_i(47 downto 32) +
                            data_i(31 downto 16) +
                            data_i(15 downto 0);
                     


   comb : process (r, rst_i, enable_i, init_i, data_i, strobe_i, length_i, s_dataWordSum) is
      variable v : RegType;
   begin
      v := r;
      
      -- Cumulative sum of the data_i while enabled
      if ( enable_i = '0')   then
         v.sum    := ("00000" & init_i);
         v.lenCnt := 0;
         v.valid  := '0';
      elsif ( r.lenCnt >= length_i)   then
         v.sum    := r.sum;
         v.lenCnt := r.lenCnt;
         v.valid  := '1';         
      elsif ( strobe_i = '1')  then
         -- Add new word sum
         v.sum    := r.sum + s_dataWordSum;
         v.lenCnt := r.lenCnt +1;
         v.valid  := '0';          
      else
         v.sum    := r.sum;
         v.lenCnt := r.lenCnt;
         v.valid  := '0';
      end if;
                
      -- Add the sum carry bits
      v.chksum  := '0' & r.sum(CSUM_WIDTH_G-1 downto 0)  +  r.sum(CSUM_WIDTH_G+4 downto CSUM_WIDTH_G);
      -- Add the checksum carry bit     
      v.chksum(CSUM_WIDTH_G-1 downto 0) := v.chksum(CSUM_WIDTH_G-1 downto 0) + v.chksum(CSUM_WIDTH_G);
      
      -- Checksum output (calculated with 2 c-c delay towards data)
      -- Ones complement
      chksum_o <= not r.chksum(CSUM_WIDTH_G-1 downto 0);
      
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
   valid_o  <= r.valid;
   check_o  <= '1' when (not r.chksum(CSUM_WIDTH_G-1 downto 0)) = (r.chksum'range => '0') else '0';
   ---------------------------------------------------------------------
end architecture rtl;