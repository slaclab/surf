-------------------------------------------------------------------------------
-- File       : AxiStreamLaneRx.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-02
-- Last update: 2015-04-29
-------------------------------------------------------------------------------
-- Description: Single lane JESD AXI stream data transmit control   
--              This module sends the data from RX JESD lane 
--                on Virtual Channel Lane.
--                - When data is requested by trigger_i = '1'.
--                - the module sends data a packet at the time to AXI stream FIFO.
--                - Between packets the FSM waits until txCtrl_i.pause = '0'
--                Note: Tx pause must indicate that the AXI stream FIFO can hold the whole data packet.
--                Note: The data transmission is enabled only if JESD data is valid dataReady_i='1'. 
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
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

use work.Jesd204bPkg.all;

entity AxiStreamLaneRx is
   generic (
      -- General Configurations
      TPD_G             : time                        := 1 ns;
      AXI_ERROR_RESP_G  : slv(1 downto 0)             := AXI_RESP_SLVERR_C);
   port (
      -- Lane number to be inserted into AXI stream
      laneNum_i       : integer range 0 to 15;
      
      -- JESD devClk
      devClk_i          : in  sl;
      devRst_i          : in  sl;
      
      -- AXI control
      packetSize_i   : in  slv(23 downto 0);
      trigger_i      : in  sl; 
      
      -- Axi Stream
      rxAxisMaster_o  : out AxiStreamMasterType;
      pause_i         : in  sl;
      

      
      -- JESD signals
      enable_i        : in  sl;      
      sampleData_i    : in  slv((GT_WORD_SIZE_C*8)-1 downto 0);
      dataReady_i     : in  sl
   );
end AxiStreamLaneRx;

architecture rtl of AxiStreamLaneRx is

   constant JESD_SSI_CONFIG_C : AxiStreamConfigType                           := ssiAxiStreamConfig(GT_WORD_SIZE_C, TKEEP_COMP_C);
   constant TSTRB_C           : slv(15 downto 0)                              := (15 downto GT_WORD_SIZE_C => '0') & ( GT_WORD_SIZE_C-1 downto 0 => '1');
   constant KEEP_C            : slv(15 downto 0)                              := (15 downto GT_WORD_SIZE_C => '0') & ( GT_WORD_SIZE_C-1 downto 0 => '1');

   type StateType is (
      IDLE_S,
      SOF_S,
      DATA_S,
      EOF_S
   );  

   type RegType is record    
      dataCnt        : slv(packetSize_i'range);
      txAxisMaster   : AxiStreamMasterType;
      state          : StateType;
   end record;
   
   constant REG_INIT_C : RegType := (
      dataCnt        => (others => '0'),
      txAxisMaster   => AXI_STREAM_MASTER_INIT_C,
      state          => IDLE_S
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (devRst_i, enable_i, r, laneNum_i, sampleData_i, pause_i, dataReady_i, packetSize_i,trigger_i) is
      variable v             : RegType;
      variable axilStatus    : AxiLiteStatusType;
      variable axilWriteResp : slv(1 downto 0);
      variable axilReadResp  : slv(1 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals
      ssiResetFlags(v.txAxisMaster);
      v.txAxisMaster.tData := (others => '0');

      -- Latch the configuration
      v.txAxisMaster.tKeep := KEEP_C;
      v.txAxisMaster.tStrb := TSTRB_C;
      
      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when IDLE_S =>
         
            -- Put packet data count to zero 
            v.dataCnt := (others => '0');  
 
            -- No data sent 
            v.txAxisMaster.tvalid  := '0';
            v.txAxisMaster.tData   := (others => '0');                
            v.txAxisMaster.tLast   := '0';
            
            -- Check if fifo and JESD is ready
            if (pause_i = '0' and enable_i = '1' and trigger_i = '1') then -- TODO later add "and dataReady_i = '1' and trigger_i = '1'"
               -- Next State
               v.state := SOF_S;
            end if;
         ----------------------------------------------------------------------
         when SOF_S =>
           
            -- Increment the counter            
            v.dataCnt := (others => '0');


            -- No data sent 
            v.txAxisMaster.tvalid  := '1';
            
            -- Insert the lane number at the first data byte
            v.txAxisMaster.tData((GT_WORD_SIZE_C*8)-1 downto 0)   := intToSlv(laneNum_i,(GT_WORD_SIZE_C*8));      
            v.txAxisMaster.tLast   := '0';
            
            -- Set the SOF bit
            ssiSetUserSof(JESD_SSI_CONFIG_C, v.txAxisMaster, '1');

            v.state      := DATA_S;
         ----------------------------------------------------------------------
         when DATA_S =>
         
            -- Increment the counter            
            v.dataCnt := r.dataCnt + 1;         
      
            -- Send the JESD data 
            v.txAxisMaster.tvalid  := '1';
            v.txAxisMaster.tData((GT_WORD_SIZE_C*8)-1 downto 0)   := sampleData_i;
            v.txAxisMaster.tLast := '0'; 
         
            -- Wait until the whole packet is sent
            if r.dataCnt = (packetSize_i-1) then
               -- Next State
               v.state   := EOF_S;
            end if;
         ----------------------------------------------------------------------
         when EOF_S =>
         
            -- Put packet data count to zero 
            v.dataCnt := (others => '0'); 

            -- No data sent 
            v.txAxisMaster.tvalid  := '1';
            v.txAxisMaster.tData((GT_WORD_SIZE_C*8)-1 downto 0)   := sampleData_i;
            -- Set the EOF(tlast) bit                
            v.txAxisMaster.tLast := '1';
            
            -- Set the EOFE bit ERROR bit TODO add JESD error later
            ssiSetUserEofe(JESD_SSI_CONFIG_C, v.txAxisMaster, '0');

            v.state := IDLE_S;

         when others => null;

      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (devRst_i = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;
      
   end process comb;

   seq : process (devClk_i) is
   begin
      if rising_edge(devClk_i) then
         r <= rin after TPD_G;
      end if;
   end process seq;
 
   -- Output assignment
   rxAxisMaster_o <= r.txAxisMaster;
    

end rtl;
