-------------------------------------------------------------------------------
-- Title      : Synchroniser Finite state machine
-------------------------------------------------------------------------------
-- File       : syncFSM.vhd 
-- Author     : Uros Legat  <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory (Cosylab)
-- Created    : 2015-04-14
-- Last update: 2015-04-14
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Finite state machine for sub-class 1 deterministic latency
--              lane synchronisation.
--              It also supports sub-class 0 non deterministic mode.
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.Jesd204bPkg.all;

entity syncFSM is
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
      gtReady_i     : in    sl;
      
      -- SYSREF for subcalss 1 fixed latency
      sysRef_i       : in    sl;
          
      -- Data and character inputs from GT (transceivers)
      dataRx_i       : in    slv((GT_WORD_SIZE_G*8)-1 downto 0);       
      chariskRx_i    : in    slv(GT_WORD_SIZE_G-1 downto 0);
      
      

      
      -- Local multi frame clock
      lmfc_i         : in    sl;
      
      -- All of the RX modules are ready for synchronisation
      nSyncAll_i       : in    sl;

      -- One or more RX modules requested synchronisation
      nSyncAny_i       : in    sl;
      
      -- Combined link errors 
      linkErr_i     : in    sl;
      
   -- Synchronous FSM control outputs
   
      -- Synchronisation request
      nSync_o        : out   sl;
      
      -- Read enable for Rx Buffer.
      -- Holds buffers between first data and LMFC
      readBuff_o        : out   sl;
      
      -- First non comma (K) character detected.
      -- To indicate when to realign sample within the dataRx.
      alignFrame_o        : out   sl;   
      
      -- Ila frames are being received
      ila_o          : out   sl; 

      -- Synchronisation process is complete and data is valid
      dataValid_o    : out   sl

    );
end syncFSM;

architecture rtl of syncFSM is

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
      nSync       : sl;
      readBuff    : sl;
      alignFrame  : sl;
      Ila         : sl;
      dataValid   : sl;
      cnt         : integer;

      -- Status Machine
      state       : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      nSync        => '0',
      readBuff     => '0',
      alignFrame   => '0',
      Ila          => '0',
      dataValid    => '0',
      cnt          =>  0,

      -- Status Machine
      state        => IDLE_S
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- Internal async signals 
   signal s_kDetected : sl;

begin
   
   -- Asynchronous K character detection 
   s_kDetected <= detKcharFunc(dataRx_i, chariskRx_i, GT_WORD_SIZE_G);  

   -- State machine
   comb : process (rst, r, enable_i,sysRef_i, dataRx_i, chariskRx_i, lmfc_i, nSyncAll_i, nSyncAny_i, linkErr_i, s_kDetected, gtReady_i) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;
      
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
            
            -- Next state condition            
            if  sysRef_i = '1' and enable_i = '1' and nSyncAll_i = '0' and gtReady_i = '1' then
               v.state    := SYSREF_S;
            end if;
         ----------------------------------------------------------------------
         when SYSREF_S =>
         
            -- Outputs
            v.nSync      := '0';
            v.readBuff   := '1';
            v.alignFrame := '0';
            v.Ila        := '0';
            v.dataValid  := '0';
            
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
            
            -- Next state condition            
            if  s_kDetected = '0' then
               v.state   := HOLD_S;
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
            
            -- Next state condition            
            if  lmfc_i = '1' then
               v.state   := ALIGN_S;
            elsif linkErr_i = '1' or enable_i = '0' then  
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
            
            -- Put ILA Sequence counter to 0
            v.cnt := 0;
            
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
            
            -- Next state condition
            -- After four LMFC clocks the ILA sequence ends and relevant ADC data is being received.
            if (lmfc_i = '1') then
               v.cnt := r.cnt + 1;
            end if;
            
            -- Next state condition            
            if  r.cnt = 4 then
               v.state   := DATA_S;
            elsif nSyncAny_i = '0' or linkErr_i = '1' or enable_i = '0' then  
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
            
            -- Next state condition            
            if  nSyncAny_i = '0' or linkErr_i = '1' or enable_i = '0' then  
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
   nSync_o <= r.nSync;
   readBuff_o <= r.readBuff;   
   alignFrame_o <= r.alignFrame; 
   Ila_o <= r.Ila;        
   dataValid_o <= r.dataValid;

end rtl;
