-------------------------------------------------------------------------------
-- File       : Jesd204bTx.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-14
-- Last update: 2015-04-14
-------------------------------------------------------------------------------
-- Description: JESD204b multi-lane transmitter module
--              Transmitter JESD204b module.
--              Supports a subset of features from JESD204b standard.
--              Supports sub-class 1 deterministic latency.
--              Supports sub-class 0 non deterministic latency.
--              Features:
--              - Synchronization of LMFC to SYSREF
--              - Multi-lane operation (L_G: 1-8)
--
--          Warning: Scrambling support has not been tested on the TX module yet.
--
--          Note: extSampleDataArray_i should be little endian and not byte swapped
--                First sample in time:  sampleData_i(15 downto 0)
--                Second sample in time: sampleData_i(31 downto 16)
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
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

use work.Jesd204bPkg.all;

entity Jesd204bTx is
   generic (
      TPD_G             : time                        := 1 ns;
          
   -- AXI Lite and stream generics
      AXI_ERROR_RESP_G  : slv(1 downto 0)             := AXI_RESP_SLVERR_C;
      
   -- JESD generics
   
      -- Number of bytes in a frame
      F_G : positive := 2;
      
      -- Number of frames in a multi frame
      K_G : positive := 32;
      
      --Number of lanes (1 to 8)
      L_G : positive := 2
   );

   port (
   -- AXI interface      
      -- Clocks and Resets
      axiClk         : in    sl;
      axiRst         : in    sl;
      
      -- AXI-Lite Register Interface
      axilReadMaster  : in    AxiLiteReadMasterType;
      axilReadSlave   : out   AxiLiteReadSlaveType;
      axilWriteMaster : in    AxiLiteWriteMasterType;
      axilWriteSlave  : out   AxiLiteWriteSlaveType;
      
      -- AXI Streaming Interface
      txAxisMasterArr_i : in  AxiStreamMasterArray(L_G-1 downto 0);
      txAxisSlaveArr_o  : out AxiStreamSlaveArray(L_G-1 downto 0);   
      
   -- JESD
      -- Clocks and Resets   
      devClk_i       : in    sl;  
      devRst_i       : in    sl;
      
      -- SYSREF for subcalss 1 fixed latency
      sysRef_i       : in    sl;
      
      -- Synchronisation input combined from all receivers 
      nSync_i        : in    sl;
      
      -- External sample data input
      extSampleDataArray_i : in sampleDataArray(L_G-1 downto 0);
      
      -- GT is ready to transmit data after reset
      gtTxReset_o    : out   slv(L_G-1 downto 0); 
      gtTxReady_i    : in    slv(L_G-1 downto 0); 
      
      -- Data and character inputs from GT (transceivers)
      r_jesdGtTxArr  : out   jesdGtTxLaneTypeArray(L_G-1 downto 0);
      
      -- Debug signals
      pulse_o        : out   slv(L_G-1 downto 0);
      leds_o         : out   slv(1 downto 0)
   );
end Jesd204bTx;

architecture rtl of Jesd204bTx is
 
   -- Internal signals

   -- Local Multi Frame Clock 
   signal s_lmfc   : sl;

   -- Control and status from AxiLite
   ------------------------------------------------------------
   signal s_sysrefDlyTx  : slv(SYSRF_DLY_WIDTH_C-1 downto 0); 
   signal s_enableTx     : slv(L_G-1 downto 0);
   signal s_replEnable   : sl;
   signal s_scrEnable    : sl;
   signal s_statusTxArr  : txStatuRegisterArray(L_G-1 downto 0);
   signal s_dataValid    : slv(L_G-1 downto 0);
   signal s_swTriggerReg : slv(L_G-1 downto 0);
   signal s_invertData   : slv(L_G-1 downto 0);   
   
   -- JESD subclass selection (from AXI lite register)
   signal s_subClass    : sl;
   -- User reset (from AXI lite register)
   signal s_gtReset     : sl;
   signal s_clearErr    : sl;
   signal s_sigTypeArr  : Slv2Array(L_G-1 downto 0);
   -- Test signal control
   signal  s_rampStep      : slv(PER_STEP_WIDTH_C-1 downto 0);
   signal  s_squarePeriod  : slv(PER_STEP_WIDTH_C-1 downto 0);   
   signal  s_enableTestSig : sl;   
   
   
   signal s_posAmplitude: slv(F_G*8-1 downto 0);   
   signal s_negAmplitude: slv(F_G*8-1 downto 0);
   
   -- Data out multiplexer
   signal s_testDataArr       : sampleDataArray(L_G-1 downto 0);
   signal s_axiDataArr        : sampleDataArray(L_G-1 downto 0);
   signal s_extDataArraySwap  : sampleDataArray(L_G-1 downto 0);
   
   signal s_sampleDataArr : sampleDataArray(L_G-1 downto 0);  

   -- Sysref conditioning
   signal  s_sysrefSync : sl;
   signal  s_sysrefRe   : sl;
   signal  s_sysrefD    : sl;
   
   -- Sync conditioning
   signal  s_nSync : sl;   
   signal  s_invertSync : sl;
   signal  s_nSyncSync  : sl;
   
   -- Select output 
   signal  s_muxOutSelArr  : Slv3Array(L_G-1 downto 0);
   signal  s_testEn : slv(L_G-1 downto 0);
begin
   -- Check generics TODO add others
   assert (1 <= L_G and L_G <= 8)  report "L_G must be between 1 and 8"   severity failure;
   
   -- 
   generateValid : for I in L_G-1 downto 0 generate
      s_dataValid(I) <= s_statusTxArr(I)(1);
   end generate generateValid;
   
   -----------------------------------------------------------
   -- AXI lite registers
   -----------------------------------------------------------  
   -- axiLite register interface
   AxiLiteRegItf_INST: entity work.AxiLiteTxRegItf
   generic map (
      TPD_G            => TPD_G,
      AXI_ERROR_RESP_G => AXI_ERROR_RESP_G,
      L_G              => L_G,
      F_G   => F_G)
   port map (
      axiClk_i        => axiClk,
      axiRst_i        => axiRst,
      axilReadMaster  => axilReadMaster,
      axilReadSlave   => axilReadSlave,
      axilWriteMaster => axilWriteMaster,
      axilWriteSlave  => axilWriteSlave,
      
      -- DevClk domain
      devClk_i        => devClk_i,
      devRst_i        => devRst_i,
      statusTxArr_i   => s_statusTxArr,
      muxOutSelArr_o  => s_muxOutSelArr,
      sysrefDlyTx_o   => s_sysrefDlyTx,
      enableTx_o      => s_enableTx,
      replEnable_o    => s_replEnable,
      scrEnable_o     => s_scrEnable,
      invertData_o    => s_invertData,
      subClass_o      => s_subClass,
      gtReset_o       => s_gtReset,
      clearErr_o      => s_clearErr,
      sigTypeArr_o    => s_sigTypeArr,
      posAmplitude_o  => s_posAmplitude,
      negAmplitude_o  => s_negAmplitude,
      swTrigger_o     => s_swTriggerReg,
      rampStep_o      => s_rampStep,
      squarePeriod_o  => s_squarePeriod,
      enableTestSig_o => s_enableTestSig,
      invertSync_o    => s_invertSync,
      axisPacketSize_o=> open
   );
   
   -----------------------------------------------------------
   -- Data sources
   -----------------------------------------------------------
   
   -- AXI stream tx interface one module per lane
   generateAxiStreamLanes : for I in L_G-1 downto 0 generate
      AxiStreamLaneTx_INST: entity work.AxiStreamLaneTx
      generic map (
         TPD_G => TPD_G,
         F_G   => F_G)
      port map (
         devClk_i       => devClk_i,
         devRst_i       => devRst_i,
         txAxisMaster_i => txAxisMasterArr_i(I),
         txAxisSlave_o  => txAxisSlaveArr_o(I),
         jesdReady_i    => s_dataValid(I),
         enable_i       => s_swTriggerReg(I),
         sampleData_o   => s_axiDataArr(I));
   end generate generateAxiStreamLanes;
   
   -- Different test sihnals   
   generateTestStreamLanes : for I in L_G-1 downto 0 generate
   
      s_testEn(I) <= s_dataValid(I) and s_enableTestSig;
      
      TestStreamTx_INST: entity work.TestStreamTx
      generic map (
         TPD_G => TPD_G,
         F_G   => F_G)
      port map (
         clk           => devClk_i,
         rst           => devRst_i,
         enable_i      => s_testEn(I),
         rampStep_i    => s_rampStep,
         squarePeriod_i=> s_squarePeriod,
         posAmplitude_i=> s_posAmplitude,
         negAmplitude_i=> s_negAmplitude,
         type_i        => s_sigTypeArr(I),
         pulse_o       => pulse_o(I),
         sampleData_o  => s_testDataArr(I));
   end generate generateTestStreamLanes;
   
   -- Sample data mux
   generateMux : for I in L_G-1 downto 0 generate
      -- Swap endians (the module is built to use big endian data but the interface is little endian)
      s_extDataArraySwap(I) <= endianSwapSlv(extSampleDataArray_i(I), GT_WORD_SIZE_C);

      -- Separate mux for separate lane
      with s_muxOutSelArr(I) select 
      s_sampleDataArr(I) <= outSampleZero(F_G,GT_WORD_SIZE_C)when "000",
                            s_extDataArraySwap(I)            when "001",
                            s_axiDataArr(I)                  when "010",  
                            s_testDataArr(I)                 when others;
   end generate generateMux;

   -----------------------------------------------------------
   -- SYSREF, SYNC, and LMFC
   -----------------------------------------------------------
   
   -- Synchronise SYSREF input to devClk_i
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
      dataIn  => sysref_i,
      dataOut => s_sysrefSync
   );
   
   -- Invert/or not nSync signal (control from axil) 
   s_nSync <= nSync_i when s_invertSync = '0' else not nSync_i;
   
   -- Synchronise nSync input to devClk_i
   Synchronizer_nsync_INST: entity work.Synchronizer
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
      dataIn  => s_nSync,
      dataOut => s_nSyncSync
   );  
   
   -- Delay SYSREF input (for 1 to 32 c-c)
   SysrefDly_INST: entity work.SysrefDly
   generic map (
      TPD_G       => TPD_G,
      DLY_WIDTH_G => SYSRF_DLY_WIDTH_C)
   port map (
      clk      => devClk_i,
      rst      => devRst_i,
      dly_i    => s_sysrefDlyTx,
      sysref_i => s_sysrefSync,
      sysref_o => s_sysrefD
   );
   
   -- LMFC period generator aligned to SYSREF input
   LmfcGen_INST: entity work.LmfcGen
   generic map (
      TPD_G          => TPD_G,
      K_G            => K_G,
      F_G            => F_G)
   port map (
      clk         => devClk_i,
      rst         => devRst_i,
      nSync_i     => s_nSyncSync,
      sysref_i    => s_sysrefD,
      sysrefRe_o  => s_sysrefRe, -- Rising-edge of SYSREF OUT 
      lmfc_o      => s_lmfc 
   );
   
   -----------------------------------------------------------
   -- Transmitter modules (L_G)
   ----------------------------------------------------------- 
   
   -- JESD Transmitter modules (one module per Lane)
   generateTxLanes : for I in L_G-1 downto 0 generate
      JesdTxLane_INST: entity work.JesdTxLane
         generic map (
            TPD_G       => TPD_G,
            F_G         => F_G,
            K_G         => K_G)
         port map (
            devClk_i     => devClk_i,
            devRst_i     => devRst_i,
            subClass_i   => s_subClass,     -- From AXI lite
            enable_i     => s_enableTx(I),  -- From AXI lite
            replEnable_i => s_replEnable,   -- From AXI lite
            scrEnable_i  => s_scrEnable,    -- From AXI lite
            inv_i        => s_invertData(I),-- From AXI lite
            lmfc_i       => s_lmfc,
            nSync_i      => s_nSyncSync,
            gtTxReady_i  => gtTxReady_i(I),
            sysRef_i     => s_sysrefRe,
            status_o     => s_statusTxArr(I), -- To AXI lite
            sampleData_i => s_sampleDataArr(I),
            r_jesdGtTx   => r_jesdGtTxArr(I));
   end generate generateTxLanes;
    
   -- Output assignment
   gtTxReset_o  <= (others=> s_gtReset);
   
   leds_o <= uOr(s_dataValid) & s_nSyncSync;
   -----------------------------------------------------
end rtl;
