-------------------------------------------------------------------------------
-- Title      : DAQ for JESD ADC
-------------------------------------------------------------------------------
-- File       : AxisDaqMux.vhd
-- Author     : Uros Legat  <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory (Cosylab)
-- Created    : 2015-04-14
-- Last update: 2015-04-14
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
--              
--              
--              
--              
--              
--              
--              
--              
--              
--              
--              
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

use work.Jesd204bPkg.all;

entity AxisDaqMux is
   generic (
      TPD_G             : time                        := 1 ns;
      
      -- AXI Lite and stream generics
      AXI_ERROR_RESP_G  : slv(1 downto 0)             := AXI_RESP_SLVERR_C;
  
     --Number of data lanes (Only valid at this point is 6)
      L_G : positive := 6;

     --Number of AXIS lanes (1 to 2)
      L_AXI_G : positive := 2   
   );
   port (
     
      -- Clocks and Resets
      axiClk         : in    sl;
      axiRst         : in    sl;
     
      -- Clocks and Resets   
      devClk_i       : in    sl;    
      devRst_i       : in    sl;
      
      -- External DAQ trigger input
      trigHW_i       : in    sl;
      
      -- AXI-Lite Register Interface
      axilReadMaster  : in    AxiLiteReadMasterType;
      axilReadSlave   : out   AxiLiteReadSlaveType;
      axilWriteMaster : in    AxiLiteWriteMasterType;
      axilWriteSlave  : out   AxiLiteWriteSlaveType;
      
      -- Sample data input 
      sampleDataArr_i   : in   sampleDataArray(L_G-1 downto 0);
      dataValidVec_i    : in   slv(L_G-1 downto 0);  

      -- AXI Streaming Interface (combine two channels and send over AXI Stream)
      rxAxisMasterArr_o  : out   AxiStreamMasterArray(L_AXI_G-1 downto 0);
      rxCtrlArr_i        : in    AxiStreamCtrlArray(L_AXI_G-1 downto 0)
   );
end AxisDaqMux;

architecture rtl of AxisDaqMux is
 
 -- Internal signals

   -- DAQ signals 
   signal s_enAxi   : slv(L_AXI_G-1 downto 0);
   signal s_sampleDataArrMux : sampleDataArray(L_AXI_G-1 downto 0);
   signal s_dataValidVecMux  : slv(L_AXI_G-1 downto 0);
   signal s_axisPacketSizeReg : slv(23 downto 0);
   signal s_laneNum : IntegerArray(L_AXI_G-1 downto 0);
   signal s_muxSel  : Slv4Array(L_AXI_G-1 downto 0);
   signal s_rateDiv : slv(15 downto 0);

   -- Axi Lite interface synced to devClk
   signal sAxiReadMasterDev : AxiLiteReadMasterType;
   signal sAxiReadSlaveDev  : AxiLiteReadSlaveType;
   signal sAxiWriteMasterDev: AxiLiteWriteMasterType;
   signal sAxiWriteSlaveDev : AxiLiteWriteSlaveType;

   -- Axi Stream

   -- Trigger conditioning
   signal  s_trigHw     : sl;
   signal  s_trigSw     : sl;
   signal  s_trigComb   : sl;   

   -- Generate pause signal logic OR
   signal s_pauseVec : slv(L_AXI_G-1 downto 0);
   signal s_pause    : sl;

begin
   -- Check JESD generics
   assert (1 <= L_G and L_G <= 16)                          report "L_G must be between 1 and 16"   severity failure;
   assert (1 <= L_AXI_G and L_AXI_G <= 2)                   report "L_AXI_G must be between 1 and 2"severity failure;  
   
   -----------------------------------------------------------
   -- AXI lite
   ----------------------------------------------------------- 

   -- Synchronise axiLite interface to devClk
   AxiLiteAsync_INST: entity work.AxiLiteAsync
   generic map (
      TPD_G           => TPD_G,
      NUM_ADDR_BITS_G => 32
   )
   port map (
      -- In
      sAxiClk         => axiClk,
      sAxiClkRst      => axiRst,
      sAxiReadMaster  => axilReadMaster,
      sAxiReadSlave   => axilReadSlave,
      sAxiWriteMaster => axilWriteMaster,
      sAxiWriteSlave  => axilWriteSlave,
      
      -- Out
      mAxiClk         => devClk_i,
      mAxiClkRst      => devRst_i,
      mAxiReadMaster  => sAxiReadMasterDev,
      mAxiReadSlave   => sAxiReadSlaveDev,
      mAxiWriteMaster => sAxiWriteMasterDev,
      mAxiWriteSlave  => sAxiWriteSlaveDev
   );

   -- axiLite register interface
   AxiLiteRegItf_INST: entity work.AxiLiteDaqRegItf
   generic map (
      TPD_G            => TPD_G,
      AXI_ERROR_RESP_G => AXI_ERROR_RESP_G,
      L_AXI_G          => L_AXI_G)
   port map (
      devClk_i        => devClk_i,
      devRst_i        => devRst_i,
      axilReadMaster  => sAxiReadMasterDev,
      axilReadSlave   => sAxiReadSlaveDev,
      axilWriteMaster => sAxiWriteMasterDev,
      axilWriteSlave  => sAxiWriteSlaveDev,
      
      busy_i          => s_pause,
      
      trigSw_o         => s_trigSw,
      rateDiv_o        => s_rateDiv,
      axisPacketSize_o => s_axisPacketSizeReg,
      muxSel_o         => s_muxSel
   );
   -----------------------------------------------------------
   -- Trigger and rate
   -----------------------------------------------------------
   
   -- Synchronise external HW trigger input to devClk_i
   Synchronizer_sysref_INST: entity work.Synchronizer
   generic map (
      TPD_G          => TPD_G,
      RST_POLARITY_G => '1',
      OUT_POLARITY_G => '1',
      RST_ASYNC_G    => false,
      STAGES_G       => 2,
      BYPASS_SYNC_G  => false,
      INIT_G         => "0")
   port map (
      clk     => devClk_i,
      rst     => devRst_i,
      dataIn  => trigHW_i,
      dataOut => s_trigHw
   );
   
   -- Combine both SW and HW triggers
   s_trigComb <= s_trigHw or s_trigSw;
   
   -----------------------------------------------------------
   -- MULTIPLEXER logic
   -----------------------------------------------------------    
   comb : process (s_muxSel, sampleDataArr_i, dataValidVec_i) is
   begin
      for I in L_AXI_G-1 downto 0 loop
         -- Multiplexer
         case (s_muxSel(I)) is
            ----------------------------------------------------------------------
            when x"0" =>
               s_sampleDataArrMux(I) <= (others => '0');
               s_dataValidVecMux(I)  <= '0';
               s_enAxi(I)            <= '0';
               s_laneNum(I)          <= 0;
            ----------------------------------------------------------------------
            when x"1" =>
               s_sampleDataArrMux(I) <= sampleDataArr_i(0);
               s_dataValidVecMux(I)  <= dataValidVec_i(0);
               s_enAxi(I)            <= '1';
               s_laneNum(I)          <= 1;
            ----------------------------------------------------------------------
            when x"2" =>
               s_sampleDataArrMux(I) <= sampleDataArr_i(1);
               s_dataValidVecMux(I)  <= dataValidVec_i(1);
               s_enAxi(I)            <= '1';
               s_laneNum(I)          <= 2;
            ----------------------------------------------------------------------
            when x"3" =>
               s_sampleDataArrMux(I) <= sampleDataArr_i(2);
               s_dataValidVecMux(I)  <= dataValidVec_i(2); 
               s_enAxi(I)            <= '1';
               s_laneNum(I)          <= 3;                  
            ----------------------------------------------------------------------
            when x"4" =>
               s_sampleDataArrMux(I) <= sampleDataArr_i(3);
               s_dataValidVecMux(I)  <= dataValidVec_i(3);
               s_enAxi(I)            <= '1';
               s_laneNum(I)          <= 4;
            ----------------------------------------------------------------------
            when x"5" =>
               s_sampleDataArrMux(I) <= sampleDataArr_i(4);
               s_dataValidVecMux(I)  <= dataValidVec_i(4);
               s_enAxi(I)            <= '1';
               s_laneNum(I)          <= 5;
            ----------------------------------------------------------------------
            when x"6" =>
               s_sampleDataArrMux(I) <= sampleDataArr_i(5);
               s_dataValidVecMux(I)  <= dataValidVec_i(5);
               s_enAxi(I)            <= '1';
               s_laneNum(I)          <= 6;               
            ----------------------------------------------------------------------
            when others =>
               s_sampleDataArrMux(I) <= (others => '0');
               s_dataValidVecMux(I)  <= '0';
               s_enAxi(I)            <= '0';
               s_laneNum(I)          <= 0;
         ----------------------------------------------------------------------
         end case;
      end loop;           
      ----------------------
   end process comb;
  
   -----------------------------------------------------------
   -- AXI stream and DAQ
   ----------------------------------------------------------- 
   -- AXI stream interface one module per lane
   genPauseSignal : for I in L_AXI_G-1 downto 0 generate
         s_pauseVec(I) <= rxCtrlArr_i(I).pause;
   end generate genPauseSignal;
   
   -- Start the next AXI stream packer transfer transfer when all FIFOs are empty  
   s_pause <= uOr(s_pauseVec);

   -- AXI stream interface two parallel lanes 
   genAxiStreamLanes : for I in L_AXI_G-1 downto 0 generate
      AxiStreamDaq_INST: entity work.AxisDaq
      generic map (
         TPD_G            => TPD_G,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G)
      port map (
         enable_i       => s_enAxi(I),
         devClk_i       => devClk_i,
         devRst_i       => devRst_i,
         laneNum_i      => s_laneNum(I),
         axiNum_i       => I,        
         packetSize_i   => s_axisPacketSizeReg,
         rateDiv_i      => s_rateDiv,
         trig_i         => s_trigComb,
         rxAxisMaster_o => rxAxisMasterArr_o(I),
         pause_i        => s_pause,
         sampleData_i   => s_sampleDataArrMux(I),
         dataReady_i    => s_dataValidVecMux(I)
      );
   end generate genAxiStreamLanes;
   -----------------------------------------------------
end rtl;
