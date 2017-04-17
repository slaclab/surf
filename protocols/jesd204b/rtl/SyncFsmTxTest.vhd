-------------------------------------------------------------------------------
-- File       : syncFsmTx.vhd 
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-14
-- Last update: 2015-04-14
-------------------------------------------------------------------------------
-- Description: Synchronizer for simple TX Finite state machine
--              Finite state machine for sub-class 1 deterministic latency
--              lane synchronization.
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
use work.Jesd204bPkg.all;

entity SyncFsmTxTest is
   generic (
      TPD_G       : time     := 1 ns);    
   port (
      -- Clocks and Resets   
      clk            : in    sl;    
      rst            : in    sl;
      
      -- Enable the module
      enable_i       : in    sl;
      
      -- JESD subclass selection: '0' or '1'(default)     
      subClass_i     : in sl;
      
      -- Local multi frame clock
      lmfc_i         : in    sl;
   
      -- Synchronisation request
      nSync_i        : in    sl;
          
      testCntr_o     : out   slv(7 downto 0); 

      -- Synchronisation process is complete start sending data 
      dataValid_o    : out   sl;
      -- First data
      align_o        : out   sl
   );
end SyncFsmTxTest;

architecture rtl of SyncFsmTxTest is

   type stateType is (
      IDLE_S,
      SYNC_S,
      ALIGN_S,     
      DATA_S
   );

   type RegType is record
      -- Synchronous FSM control outputs
      dataValid   : sl;
      align       : sl;      
      cnt         : slv(7 downto 0);
      
      -- Status Machine
      state       : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      dataValid    => '0',
      align        => '0',
      cnt          =>  (others => '0'),

      -- Status Machine
      state        => IDLE_S
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin
   
   -- State machine
   comb : process (rst, r, enable_i, lmfc_i, nSync_i) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;
      
      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
         
            -- Outputs
            v.cnt       := (others => '0');
            v.dataValid := '0';
            v.align     := '0';
            
            -- Next state condition            
            if  nSync_i = '0' then
               v.state    := SYNC_S;
            end if;
         ----------------------------------------------------------------------
         when SYNC_S =>
         
            -- Outputs
            v.cnt       := (others => '0');
            v.dataValid := '0';
            v.align     := '0';
            
            -- Next state condition
            if  subClass_i = '1' then
               if  nSync_i = '1' and enable_i = '1' and lmfc_i = '1' then
                  v.state   := ALIGN_S;                             
               elsif enable_i = '0' then  
                  v.state   := IDLE_S;            
               end if;
            else  
               if  nSync_i = '1' and enable_i = '1' then
                  v.state   := ALIGN_S;                             
               elsif enable_i = '0' then  
                  v.state   := IDLE_S;            
               end if;
            end if; 
         ----------------------------------------------------------------------
         when ALIGN_S =>
                  
            -- Outputs
            v.cnt       := (others => '0');
            v.dataValid := '0';
            v.align     := '1';
                       
            -- Next state condition            
            v.state   := DATA_S;       
         ----------------------------------------------------------------------
         when DATA_S =>

            -- Outputs
            v.cnt       := r.cnt+GT_WORD_SIZE_C; -- two or four data bytes sent in parallel
            v.dataValid := '1';
            v.align     := '0';
            
            -- Next state condition            
            if  nSync_i = '0' or enable_i = '0' then  
               v.state   := IDLE_S;            
            end if;
         ----------------------------------------------------------------------      
         when others =>
         
            -- Outputs
            v.cnt       := (others => '0');
            v.dataValid := '0';
            v.align     := '0';
            
            -- Next state condition            
            v.state   := IDLE_S;            
      ----------------------------------------------------------------------
      end case;

      -- Synchronous Reset
      if rst = '1' then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;
      
   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
   -- Output assignment
   testCntr_o  <= r.cnt;     
   dataValid_o <= r.dataValid;
   align_o     <= r.align;
----------------------------------------------
end rtl;
