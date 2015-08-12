-------------------------------------------------------------------------------
-- Title      : Single lane data acquisition control
-------------------------------------------------------------------------------
-- File       : AxisDaq.vhd
-- Author     : Uros Legat  <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-02
-- Last update: 2015-04-29
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:   This module sends to a single virtual Channel Lane.
--                - When data is requested by trig_i = '1' (rising edge is detected on trig_i).
--                - the module sends data a packet at the time to AXI stream FIFO.
--                - Between packets the FSM waits until txCtrl_i.pause = '0'
--                  after that it is ready to receive the next trigger.
--                Note: Tx pause must indicate that the AXI stream FIFO can hold the whole data packet.
--                Note: The data transmission is enabled only if JESD data is valid dataReady_i='1'. 
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
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

entity AxisDaq is
   generic (
      -- General Configurations
      TPD_G             : time                        := 1 ns;
      AXI_ERROR_RESP_G  : slv(1 downto 0)             := AXI_RESP_SLVERR_C);
   port (
      enable_i        : in  sl;
      
      -- JESD devClk
      devClk_i          : in  sl;
      devRst_i          : in  sl;
      
      -- Lane number AXI number to be inserted into AXI stream
      laneNum_i       : integer;
      axiNum_i        : integer range 0 to 15;
   
      -- DAQ
      packetSize_i   : in  slv(23 downto 0);    
      rateDiv_i      : in  slv(15 downto 0);
      trig_i         : in  sl;
      
      -- Axi Stream
      rxAxisMaster_o  : out AxiStreamMasterType;
      pause_i         : in  sl; 
      
      sampleData_i    : in  slv((GT_WORD_SIZE_C*8)-1 downto 0);
      dataReady_i     : in  sl
   );
end AxisDaq;

architecture rtl of AxisDaq is

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
   signal s_num : slv((GT_WORD_SIZE_C*8)-1 downto 0);
   signal s_rateClk : sl;
   signal s_trigRe : sl;  
   signal s_decSampData : slv((GT_WORD_SIZE_C*8)-1 downto 0);
  
  
begin
   
   -- Rate divider module
   Decimator_INST: entity work.Decimator
   generic map (
      TPD_G => TPD_G,
      F_G => 2
   )
   port map (
      clk           => devClk_i,
      rst           => devRst_i,
      sampleData_i  => sampleData_i,
      decSampData_o => s_decSampData,
      rateDiv_i     => rateDiv_i,
      trig_i        => trig_i,
      trigRe_o      => s_trigRe,
      rateClk_o     => s_rateClk);

   
   -- Combine AXIS lane number and JESD lane number
   s_num <= intToSlv(laneNum_i,(GT_WORD_SIZE_C*4)) & intToSlv(axiNum_i,(GT_WORD_SIZE_C*4));

   comb : process (devRst_i, enable_i, r, s_num, s_decSampData, pause_i, dataReady_i, packetSize_i,s_trigRe, s_rateClk) is
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
            if (pause_i = '0' and enable_i = '1' and dataReady_i = '1' and s_trigRe = '1') then
               -- Next State
               v.state := SOF_S;
            end if;
         ----------------------------------------------------------------------
         when SOF_S =>
           
            -- Increment the counter            
            v.dataCnt := (others => '0');


            -- No data sent 
            v.txAxisMaster.tvalid  := '1';
            
            -- Insert the axi and lane number at the first packet data word (byte swapped so it is transferred correctly)
            v.txAxisMaster.tData((GT_WORD_SIZE_C*8)-1 downto 0)   := byteSwapSlv(s_num, GT_WORD_SIZE_C);   
            v.txAxisMaster.tLast   := '0';
            
            -- Set the SOF bit
            ssiSetUserSof(JESD_SSI_CONFIG_C, v.txAxisMaster, '1');

            v.state      := DATA_S;
         ----------------------------------------------------------------------
         when DATA_S =>
         
            -- Increment the counter
            -- and sample data on s_rateClk rate
            if  s_rateClk = '1' then
               v.dataCnt := r.dataCnt + 1;
               v.txAxisMaster.tvalid  := '1';
            else
               v.dataCnt := r.dataCnt;
               v.txAxisMaster.tvalid  := '0';
            end if;
            
            -- Send the JESD data 
            v.txAxisMaster.tData((GT_WORD_SIZE_C*8)-1 downto 0)   := s_decSampData;
            v.txAxisMaster.tLast := '0'; 
         
            -- Wait until the whole packet is sent
            if r.dataCnt = (packetSize_i) then
               -- Next State
               v.txAxisMaster.tvalid  := '0';
               v.state   := EOF_S;
            end if;
         ----------------------------------------------------------------------
         when EOF_S =>
         
            -- Put packet data count to zero 
            v.dataCnt := (others => '0'); 

            -- No data sent 
            v.txAxisMaster.tvalid  := '1';
            v.txAxisMaster.tData((GT_WORD_SIZE_C*8)-1 downto 0)   := (others => '0');
            -- Set the EOF(tlast) bit                
            v.txAxisMaster.tLast := '1';
            
            -- Set the EOFE bit ERROR bit
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
