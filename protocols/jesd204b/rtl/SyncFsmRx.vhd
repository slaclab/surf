-------------------------------------------------------------------------------
-- File       : SyncFsmRx.vhd 
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-14
-- Last update: 2015-04-14
-------------------------------------------------------------------------------
-- Description: Synchronizer Finite state machine
--              Finite state machine for sub-class 1 deterministic latency
--              lane synchronization.
--              It also supports sub-class 0 non deterministic mode.
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

entity SyncFsmRx is
   generic (
      TPD_G: time    := 1 ns;

      -- Number of bytes in a frame
      F_G : positive := 2;
      
      -- Number of frames in a multi frame
      K_G : positive := 32;
      
      -- Number of multi-frames in ILA sequence (4-255)
      NUM_ILAS_MF_G : positive := 4
   );    
   port (
      -- Clocks and Resets   
      clk            : in    sl;    
      rst            : in    sl;
      
      -- Enable the module
      enable_i       : in    sl;      
      gtReady_i      : in    sl;
      
      -- JESD subclass selection: '0' or '1'(default)     
      subClass_i : in sl; 
      
      -- SYSREF for subcalss 1 fixed latency
      sysRef_i       : in    sl;
          
      -- Data and character inputs from GT (transceivers)
      dataRx_i       : in    slv((GT_WORD_SIZE_C*8)-1 downto 0);       
      chariskRx_i    : in    slv(GT_WORD_SIZE_C-1 downto 0);
      
      -- Local multi frame clock
      lmfc_i         : in    sl;
          
      -- One or more RX modules requested synchronisation
      nSyncAny_i     : in    sl;
      nSyncAnyD1_i   : in    sl;
      
      -- Combined link errors 
      linkErr_i      : in    sl;
      
   -- Synchronous FSM control outputs
   
      -- Synchronisation request
      nSync_o        : out   sl;
      
      -- Elastic buffer latency in clock cycles
      buffLatency_o      : out   slv(7 downto 0); 
      
      -- Read enable for Rx Buffer.
      -- Holds buffers between first data and LMFC
      readBuff_o     : out   sl;
      
      -- First non comma (K) character detected.
      -- To indicate when to realign sample within the dataRx.
      alignFrame_o   : out   sl;   
      
      -- Ila frames are being received
      ila_o          : out   sl;
      
      -- K detected
      kDetected_o    : out   sl;
      
      -- sysref received     
      sysref_o       : out   sl;

      -- Synchronisation process is complete and data is valid
      dataValid_o    : out   sl

    );
end SyncFsmRx;

architecture rtl of SyncFsmRx is

   type stateType is (
      IDLE_S,
      SYSREF_S,      
      SYNC_S,
      HOLD_S,
      ALIGN_S,
      ILA_S,
      DATA_S
   );

   type RegType is record
      -- Synchronous FSM control outputs
      kDetectRegD1: sl;
      kDetectRegD2: sl;
      kDetectRegD3: sl;
      
      nSync       : sl;
      readBuff    : sl;
      alignFrame  : sl;
      Ila         : sl;
      dataValid   : sl;
      sysref      : sl;
      cnt         : slv(7 downto 0);
     cntLatency  : slv(7 downto 0);

      -- Status Machine
      state       : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      kDetectRegD1 => '0',
      kDetectRegD2 => '0',
      kDetectRegD3 => '0',
   
      nSync        => '0',
      readBuff     => '0',
      alignFrame   => '0',
      Ila          => '0',
      dataValid    => '0',
      sysref       => '0',
      cnt          =>  (others => '0'),
      cntLatency   =>  (others => '0'),
     
      -- Status Machine
      state        => IDLE_S
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
   signal s_kDetected : sl;
   signal s_kStable   : sl;

begin

   s_kDetected <= detKcharFunc(dataRx_i, chariskRx_i, GT_WORD_SIZE_C);
      -- Comma detected if detected in three consecutive clock cycles
   s_kStable   <= s_kDetected and r.kDetectRegD1 and r.kDetectRegD2 and r.kDetectRegD3;
   
   -- State machine
   comb : process (rst, r, enable_i,sysRef_i, dataRx_i,subClass_i, chariskRx_i, lmfc_i, nSyncAnyD1_i, nSyncAny_i, linkErr_i, gtReady_i, s_kDetected, s_kStable) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;
      
      -- Comma detected pipeline
      v.kDetectRegD1 := detKcharFunc(dataRx_i, chariskRx_i, GT_WORD_SIZE_C);       
      v.kDetectRegD2 := r.kDetectRegD1;
      v.kDetectRegD3 := r.kDetectRegD2;      

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
         
            -- Outputs
            v.nSync      := '0';
            v.readBuff   := '1';
            v.alignFrame := '0';
            v.Ila        := '0';
            v.dataValid  := '0';
            v.sysref     := '0';
            v.cntLatency := (others => '0');
            
            -- Next state condition (depending on subclass)
            if  subClass_i = '1' then
               if  sysRef_i = '1' and enable_i = '1' and nSyncAnyD1_i = '0' and gtReady_i = '1' and s_kStable = '1' then
                  v.state    := SYSREF_S;
               end if;
            else  
               if  enable_i = '1' and gtReady_i = '1' and s_kStable = '1' then
                  v.state    := SYSREF_S;
               end if;        
            end if;
         ----------------------------------------------------------------------
         when SYSREF_S =>
         
            -- Outputs
            v.nSync      := '0';
            v.readBuff   := '1';
            v.alignFrame := '0';
            v.Ila        := '0';
            v.dataValid  := '0';
            v.sysref     := '1';
            v.cntLatency := (others => '0');
            
            -- Next state condition            
            if  s_kDetected = '1' and lmfc_i = '1' then
               v.state   := SYNC_S;
            elsif enable_i = '0' then  
               v.state   := IDLE_S;            
            end if;
         ----------------------------------------------------------------------
         when SYNC_S =>
         
            -- Outputs
            v.nSync      := '1';
            v.readBuff   := '1';
            v.alignFrame := '0';
            v.Ila        := '0';
            v.dataValid  := '0';
            v.sysref     := '1';
            v.cntLatency := (others => '0');
            
            -- Next state condition
            if  s_kDetected = '0' then
               v.state   := HOLD_S;
               -- v.readBuff   := '0'; -- TODO this signal has to be applied one c-c earlier for simulation
                                       -- But in hardware that is not the case. This should be investigated.        
            elsif enable_i = '0' then  
               v.state   := IDLE_S;            
            end if;
         ----------------------------------------------------------------------
         when HOLD_S =>
         
            -- Outputs
            v.nSync      := '1';
            v.readBuff   := '0';
            v.alignFrame := '0';
            v.Ila        := '0';
            v.dataValid  := '0';
            v.sysref     := '1';
            v.cntLatency := r.cntLatency + 1;
            
            -- Next state condition            
            if  lmfc_i = '1' then
               v.state   := ALIGN_S;
            elsif enable_i = '0' then  
               v.state   := IDLE_S;        
            end if;

         ----------------------------------------------------------------------
         when ALIGN_S =>
                  
            -- Outputs
            v.nSync      := '1';
            v.readBuff   := '1';
            v.alignFrame := '1';
            v.Ila        := '1';
            v.dataValid  := '0';
            v.sysref     := '1';
            v.cntLatency := r.cntLatency;
            
            -- Put ILA Sequence counter to 0
            v.cnt := (others => '0');
            
            -- Next state condition            
            v.state   := ILA_S; 

         ----------------------------------------------------------------------
         when ILA_S =>
                     -- Outputs
            v.nSync      := '1';
            v.readBuff   := '1';
            v.alignFrame := '0';
            v.Ila        := '1';
            v.dataValid  := '0';
            v.sysref     := '1';
            v.cntLatency := r.cntLatency;
            
            -- Increase lmfc counter.
            if (lmfc_i = '1') then
               v.cnt := r.cnt + 1;
            end if;
            
            -- Next state condition
            -- After NUM_ILAS_MF_G LMFC clocks the ILA sequence ends and relevant ADC data is being received.            
            if  r.cnt = NUM_ILAS_MF_G then
               v.state   := DATA_S;
            elsif enable_i = '0' or s_kStable = '1' then  
               v.state   := IDLE_S;           
            end if;
         ----------------------------------------------------------------------
         when DATA_S =>
            -- Outputs
            v.nSync      := '1';
            v.readBuff   := '1';
            v.alignFrame := '0';
            v.Ila        := '0';
            v.dataValid  := '1';
            v.sysref     := '1';
            v.cntLatency := r.cntLatency;
            
            -- Next state condition
            if  nSyncAny_i = '0' or linkErr_i = '1' or enable_i = '0' or s_kStable = '1' or gtReady_i = '0' then  
               v.state   := IDLE_S;            
            end if;
         ----------------------------------------------------------------------      
         when others =>
            -- Outputs
            v.nSync      := '0';
            v.readBuff   := '0';
            v.alignFrame := '0';
            v.Ila        := '0';
            v.dataValid  := '0';
            v.sysref     := '0';
            v.cntLatency := (others => '0');
            
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
   nSync_o      <= r.nSync;
   readBuff_o   <= r.readBuff;   
   alignFrame_o <= r.alignFrame; 
   Ila_o        <= r.Ila;        
   dataValid_o  <= r.dataValid;
   kDetected_o  <= s_kStable;
   sysref_o     <= r.sysref;
   buffLatency_o<= r.cntLatency;
end rtl;
