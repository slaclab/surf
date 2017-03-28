-------------------------------------------------------------------------------
-- File       : LmfcGen.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-15
-- Last update: 2015-04-15
-------------------------------------------------------------------------------
-- Description: LMFC Generator
--              Local Multi Frame Clock Generator
--              Periodically outputs one clock cycle pulse (LMFC).
--              Synchronizes with the rising edge of sysref_i if sync is requested 
--              by any of the on-board JESD receivers.
--              Outputs first pulse 2 c-c after sysref_i='1'
--              Period determined by F_G*K_G/GT_WORD_SIZE_C.
--              (Example: 2*32/4 = 16)
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
use work.jesd204bpkg.all;

entity LmfcGen is
   generic (
      TPD_G        : time   := 1 ns;
      K_G          : positive   := 32;
      F_G          : positive   := 2);
   port (
      clk      : in  sl;
      rst      : in  sl;
      
      -- Synchronisation inputs
      nSync_i  : in  sl; 
      sysref_i : in  sl;
      
      -- Outs
      sysrefRe_o : out sl;      
      lmfc_o     : out sl  
   );
end entity LmfcGen;

architecture rtl of LmfcGen is
   
   constant PERIOD_C    : positive := ((K_G * F_G)/GT_WORD_SIZE_C)-1;
   constant CNT_WIDTH_C : positive := bitSize(PERIOD_C);

   type RegType is record
      sysrefD1 : sl;
      cnt      : slv(CNT_WIDTH_C-1 downto 0);
      lmfc     : sl;
      sysrefRe : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      sysrefD1  => '0',
      cnt       => (others => '0'),
      lmfc      => '0',
      sysrefRe  => '0'
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
begin

   comb : process (r, rst,sysref_i,nSync_i) is
      variable v : RegType;
   begin
      v := r;
      
      -- Delay sysref for one clock cycle 
      v.sysrefD1 := sysref_i;
      
      -- Detect rising edge on sysref
      v.sysrefRe := sysref_i and not r.sysrefD1; 
      

      -- Period counter 

      -- LMFC is aligned to sysref on rising edge of sysref_i. 
      -- The alignment is only done when nSync_i=‘0‘    
      if (r.sysrefRe = '1' and nSync_i = '0' ) then
         v.cnt  := (others => '0');
         v.lmfc := '1';
      elsif (r.cnt = PERIOD_C) then
         v.cnt  := (others => '0');
         v.lmfc := '1';
      else 
         v.cnt := r.cnt + 1;
         v.lmfc := '0';         
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
   lmfc_o       <= r.lmfc;
   sysrefRe_o   <= r.sysrefRe;
---------------------------------------   
end architecture rtl;
