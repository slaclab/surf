-------------------------------------------------------------------------------
-- Title      : Synchroniser for simple TX Finite state machine
-------------------------------------------------------------------------------
-- File       : syncFsmTx.vhd 
-- Author     : Uros Legat  <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory (Cosylab)
-- Created    : 2015-04-14
-- Last update: 2015-04-14
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Finite state machine for sub-class 1 deterministic latency
--              lane synchronisation.
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.Jesd204bPkg.all;

entity syncFsmTx is
   generic (
      TPD_G            : time                := 1 ns;

      -- Number of bytes in a frame
      F_G : positive := 2;
      
      -- Number of frames in a multi frame
      K_G : positive := 32;
           
      --Transceiver word size (GTP,GTX,GTH) (2 or 4)
      GT_WORD_SIZE_G : positive := 4;
      
      --JESD204B class (0 and 1 supported)
      SUB_CLASS_G : positive := 1
   );    
   port (
      -- Clocks and Resets   
      clk            : in    sl;    
      rst            : in    sl;
      
      -- Enable the module
      enable_i       : in    sl;      

      -- Local multi frame clock
      lmfc_i         : in    sl;
   
      -- Synchronisation request
      nSync_i        : in    sl;
          
      testCntr_o     : out   slv(7 downto 0); 

      -- Synchronisation process is complete and data is valid
      dataValid_o    : out   sl
    );
end syncFsmTx;

architecture rtl of syncFsmTx is

   type stateType is (
      IDLE_S,
      SYNC_S,      
      DATA_S
   );

   type RegType is record
      -- Synchronous FSM control outputs
      dataValid   : sl;
      cnt         : slv(7 downto 0);

      -- Status Machine
      state       : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (

      dataValid    => '0',
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
            
            -- Next state condition            
            if  nSync_i = '0' then
               v.state    := SYNC_S;
            end if;
         ----------------------------------------------------------------------
         when SYNC_S =>
         
            -- Outputs
            v.cnt       := (others => '0');
            v.dataValid := '0';
            
            -- Next state condition            
            if  nSync_i = '1' and enable_i = '1' and lmfc_i = '1' then
               v.state   := DATA_S;
            elsif enable_i = '0' then  
               v.state   := IDLE_S;            
            end if;

         ----------------------------------------------------------------------
         when DATA_S =>

            -- Outputs
            v.cnt       := v.cnt+4; -- four data bytes sent in parallel
            v.dataValid := '1';
            
            -- Next state condition            
            if  nSync_i = '0' or enable_i = '0' then  
               v.state   := IDLE_S;            
            end if;
         ----------------------------------------------------------------------      
         when others =>
         
            -- Outputs
            v.cnt       := (others => '0');
            v.dataValid := '0';
            
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

end rtl;
