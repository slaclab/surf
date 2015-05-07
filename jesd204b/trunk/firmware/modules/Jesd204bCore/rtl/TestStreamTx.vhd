-------------------------------------------------------------------------------
-- Title      : Test Data Stream Generator
-------------------------------------------------------------------------------
-- File       : TestStreamTx.vhd
-- Author     : Uros Legat  <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory (Cosylab)
-- Created    : 2015-04-15
-- Last update: 2015-04-15
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Outputs counter as sample data stream for testing
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.jesd204bpkg.all;

entity TestStreamTx is
   generic (
      TPD_G        : time   := 1 ns;
      F_G          : positive   := 2);
   port (
      clk      : in  sl;
      rst      : in  sl;
      
      -- Enable counter      
      enable_i  : in  sl;
      
      -- Increase counter
      strobe_i  : in  sl; 
      
      -- Outs    
      sample_data_o : out slv(GT_WORD_SIZE_C*8-1 downto 0)  
   );
end entity TestStreamTx;

architecture rtl of TestStreamTx is
   
   constant SAM_IN_WORD_C    : positive := (GT_WORD_SIZE_C/F_G);

   type RegType is record
      cnt      : slv(F_G*8-1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      cnt       => (others => '0')
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
   -- 
   signal s_sample_data : slv (sample_data_o'range);
   --
begin

   comb : process (r, rst,strobe_i,enable_i) is
      variable v : RegType;
   begin
      v := r;

      -- Test Data counter 
      if (strobe_i = '1') then
         v.cnt := r.cnt + 1;       
      end if;

      if (enable_i = '0') then
         v := REG_INIT_C;
      end if;

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
   SAMPLE_DATA_GEN : for I in SAM_IN_WORD_C-1 downto 0 generate 
      s_sample_data((F_G*8*I)+(F_G*8-1) downto F_G*8*I)     <= r.cnt;
   end generate SAMPLE_DATA_GEN;  

   sample_data_o <= byteSwapSlv(s_sample_data, GT_WORD_SIZE_C);
   
---------------------------------------   
end architecture rtl;
