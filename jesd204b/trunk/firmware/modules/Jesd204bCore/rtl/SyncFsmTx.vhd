-------------------------------------------------------------------------------
-- Title      : Synchroniser TX Finite state machine
-------------------------------------------------------------------------------
-- File       : syncFsmTx.vhd 
-- Author     : Uros Legat  <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory (Cosylab)
-- Created    : 2015-04-14
-- Last update: 2015-04-14
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Finite state machine for sub-class 1 and sub-class 0 deterministic latency
--              lane synchronisation.
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.Jesd204bPkg.all;

entity SyncFsmTx is
   generic (
      TPD_G       : time     := 1 ns;
      --JESD204B class (0 and 1 supported)
      
      -- Number of multi-frames in ILA sequence (4-255)
      NUM_ILAS_MF_G : positive := 4;
      
      SUB_CLASS_G : natural := 1);    
   port (
      -- Clocks and Resets   
      clk            : in  sl;    
      rst            : in  sl;
      
      -- Enable the module
      enable_i       : in  sl;      

      -- Local multi frame clock
      lmfc_i         : in  sl;
   
      -- Synchronisation request
      nSync_i        : in  sl;
      
      -- GT is ready to transmit data after reset
      gtTxReady_i    : in  sl;
      
      -- SYSREF for subcalss 1 fixed latency
      sysRef_i       : in  sl; 

      -- Synchronisation process is complete start sending data 
      dataValid_o    : out sl;
      
      -- Initial lane synchronisation sequence indicator
      ila_o          : out sl
   );
end SyncFsmTx;

architecture rtl of SyncFsmTx is

   type stateType is (
      IDLE_S,
      SYNC_S,
      ILA_S,     
      DATA_S
   );

   type RegType is record
      -- Synchronous FSM control outputs
      dataValid   : sl;
      ila       : sl;
      -- Count       
      cnt         : slv(7 downto 0);
      
      -- Status Machine
      state       : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      dataValid    => '0',
      ila        => '0',
      cnt          =>  (others => '0'),

      -- Status Machine
      state        => IDLE_S
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin
   
   -- State machine
   comb : process (rst, r, enable_i, lmfc_i, nSync_i, gtTxReady_i, sysRef_i) is
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
            v.ila       := '0';
            
            -- Next state condition (depending on subclass)
            if  SUB_CLASS_G = 1 then
               if  sysRef_i = '1' and enable_i = '1' and gtTxReady_i = '1' then
                  v.state    := SYNC_S;
               end if;
            else  
               if  enable_i = '1' and gtTxReady_i = '1' then
                  v.state    := SYNC_S;
               end if;            
            end if;
         ----------------------------------------------------------------------
         when SYNC_S =>
         
            -- Outputs
            v.cnt       := (others => '0');
            v.dataValid := '0';
            v.ila       := '0';
            
            -- Next state condition
            if  nSync_i = '1' and lmfc_i = '1' then
               v.state   := ILA_S;                             
            elsif enable_i = '0' then  
               v.state   := IDLE_S;            
            end if;
         ----------------------------------------------------------------------
         when ILA_S =>
                  
            -- Outputs
            v.dataValid := '0';
            v.ila       := '1';
            
            -- Increase lmfc counter.
            if (lmfc_i = '1') then
               v.cnt := r.cnt + 1;
            end if;
 
            -- Next state condition
            -- After NUM_ILAS_MF_G LMFC clocks the ILA sequence ends and relevant ADC data is being received.            
            if  v.cnt = NUM_ILAS_MF_G then
               v.state   := DATA_S;
            elsif nSync_i = '0' or enable_i = '0' then  
               v.state   := IDLE_S;           
            end if;
         ----------------------------------------------------------------------
         when DATA_S =>

            -- Outputs
            v.cnt       := r.cnt+GT_WORD_SIZE_C; -- two or four data bytes sent in parallel
            v.dataValid := '1';
            v.ila       := '0';
            
            -- Next state condition            
            if  nSync_i = '0' or enable_i = '0' then  
               v.state   := IDLE_S;            
            end if;
         ----------------------------------------------------------------------      
         when others =>
         
            -- Outputs
            v.cnt       := (others => '0');
            v.dataValid := '0';
            v.ila       := '0';
            
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
   dataValid_o <= r.dataValid;
   ila_o       <= r.ila;
----------------------------------------------
end rtl;
