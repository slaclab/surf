-------------------------------------------------------------------------------
-- Title      : JESD204b Gth wrapper for ADC/DAC Demo board
-------------------------------------------------------------------------------
-- File       : Jesd204bGthWrapper.vhd
-- Author     : Uros Legat  <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory (Cosylab)
-- Created    : 2015-04-14
-- Last update: 2015-04-14
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Wrapper module for 6 lane JESD receiver nad 2 lane JESD transmitter
--              GTH coregen generated core 6 GTH modules
--              Note: 7.4 GHz lane rate and 370MHz reference, Freerunning clk 185 MHz
--                    If different amount of lanes or freq is required the Core has to be regenerated 
--                    by Xilinx Coregen.               
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
library ieee;
library unisim;
use unisim.vcomponents.all;

use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.Jesd204bPkg.all;

entity Jesd204bGthWrapper is
   generic (
      TPD_G             : time                        := 1 ns;
      
   -- Test tx module instead of GTX
      TEST_G            : boolean                     := false;
      
      -- Internal SYSREF SYSREF_GEN_G= TRUE else 
      -- External SYSREF
      SYSREF_GEN_G        : boolean                    := false; 
      
   -- AXI Lite and AXI stream generics
   ----------------------------------------------------------------------------------------------
      AXI_ERROR_RESP_G  : slv(1 downto 0)             := AXI_RESP_SLVERR_C;

   -- JESD generics
   ----------------------------------------------------------------------------------------------
      F_G            : positive := 2;
      K_G            : positive := 32;
      L_RX_G         : positive := 6;
      L_TX_G         : positive := 2   
   );

   port (
   -- GT Interface
   ----------------------------------------------------------------------------------------------     
      -- GT Clocking
      stableClk        : in  sl;                      -- GT needs a stable clock to "boot up"(buffered refClkDiv2) 
      refClk           : in  sl;                      -- GT Reference clock directly from GT GTH diff. input buffer   
      -- Gt Serial IO
      gtTxP            : out slv(L_RX_G-1 downto 0);         -- GT Serial Transmit Positive
      gtTxN            : out slv(L_RX_G-1 downto 0);         -- GT Serial Transmit Negative
      gtRxP            : in  slv(L_RX_G-1 downto 0);         -- GT Serial Receive Positive
      gtRxN            : in  slv(L_RX_G-1 downto 0);         -- GT Serial Receive Negative
        
   -- User clocks and resets
   ---------------------------------------------------------------------------------------------- 
      devClk_i       : in    sl; -- Device clock also rxUsrClkIn for MGT
      devClk2_i      : in    sl; -- Device clock divided by 2 also rxUsrClk2In for MGT       
      devRst_i       : in    sl; -- 
      
      devClkActive_i : in    sl:= '1';  -- devClk_i MCMM locked

   -- AXI interface
   ------------------------------------------------------------------------------------------------   
      axiClk         : in    sl;
      axiRst         : in    sl;  
      
      -- AXI-Lite RX Register Interface
      axilReadMasterRx  : in    AxiLiteReadMasterType;
      axilReadSlaveRx   : out   AxiLiteReadSlaveType;
      axilWriteMasterRx : in    AxiLiteWriteMasterType;
      axilWriteSlaveRx  : out   AxiLiteWriteSlaveType;
      
      -- AXI-Lite RX Register Interface
      axilReadMasterTx  : in    AxiLiteReadMasterType;
      axilReadSlaveTx   : out   AxiLiteReadSlaveType;
      axilWriteMasterTx : in    AxiLiteWriteMasterType;
      axilWriteSlaveTx  : out   AxiLiteWriteSlaveType;
      
      -- AXI Streaming Interface
      rxAxisMasterArr : out   AxiStreamMasterArray(L_RX_G-1 downto 0);
      rxCtrlArr       : in    AxiStreamCtrlArray(L_RX_G-1 downto 0);
      
      -- Sample data output (Use if external data acquisition core is attached)
      sampleDataArr_o   : out   sampleDataArray(L_RX_G-1 downto 0);
      dataValidVec_o    : out   slv(L_RX_G-1 downto 0);
      
      -- Sample data input (Use if external data generator core is attached)      
      sampleDataArr_i   : in   sampleDataArray(L_TX_G-1 downto 0);      
      
   -- JESD
   ------------------------------------------------------------------------------------------------   

      -- SYSREF for subcalss 1 fixed latency
      sysRef_i       : in    sl;
      
      -- SYSREF out when it is generated internally SYSREF_GEN_G=True     
      sysRef_o       : out    sl;

      -- Synchronisation output combined from all receivers to be connected to ADC chips
      nSync_o        : out   sl;

      -- Synchronisation in to transmitter core from DAC chips 
      nSync_i        : in   sl;
      
      
      -- Out to led
      ledsRx_o    : out   slv(1 downto 0);
      ledsTx_o    : out   slv(1 downto 0);
  
      -- Debug pulses for latency test
      rxPulse_o   : out   slv(L_RX_G-1 downto 0);
      txPulse_o   : out   slv(L_TX_G-1 downto 0);
      
      -- Out to led     
      qPllLock_o : out sl      
   );
end Jesd204bGthWrapper;

architecture rtl of Jesd204bGthWrapper is
---------------------------------------   
component gthultrascalejesdcoregen
  port (
    gtwiz_userclk_tx_reset_in : in std_logic_vector(0 downto 0);
    gtwiz_userclk_tx_active_in : in std_logic_vector(0 downto 0);
    gtwiz_userclk_rx_active_in : in std_logic_vector(0 downto 0);
    gtwiz_buffbypass_tx_reset_in : in std_logic_vector(0 downto 0);
    gtwiz_buffbypass_tx_start_user_in : in std_logic_vector(0 downto 0);
    gtwiz_buffbypass_tx_done_out : out std_logic_vector(0 downto 0);
    gtwiz_buffbypass_tx_error_out : out std_logic_vector(0 downto 0);
    gtwiz_reset_clk_freerun_in : in std_logic_vector(0 downto 0);
    gtwiz_reset_all_in : in std_logic_vector(0 downto 0);
    gtwiz_reset_tx_pll_and_datapath_in : in std_logic_vector(0 downto 0);
    gtwiz_reset_tx_datapath_in : in std_logic_vector(0 downto 0);
    gtwiz_reset_rx_pll_and_datapath_in : in std_logic_vector(0 downto 0);
    gtwiz_reset_rx_datapath_in : in std_logic_vector(0 downto 0);
    gtwiz_reset_rx_cdr_stable_out : out std_logic_vector(0 downto 0);
    gtwiz_reset_tx_done_out : out std_logic_vector(0 downto 0);
    gtwiz_reset_rx_done_out : out std_logic_vector(0 downto 0);
    gtwiz_userdata_tx_in : in std_logic_vector(191 downto 0);
    gtwiz_userdata_rx_out : out std_logic_vector(191 downto 0);
    drpclk_in : in std_logic_vector(5 downto 0);
    gthrxn_in : in std_logic_vector(5 downto 0);
    gthrxp_in : in std_logic_vector(5 downto 0);
    gtrefclk0_in : in std_logic_vector(5 downto 0);
    rx8b10ben_in : in std_logic_vector(5 downto 0);
    rxcommadeten_in : in std_logic_vector(5 downto 0);
    rxmcommaalignen_in : in std_logic_vector(5 downto 0);
    rxpcommaalignen_in : in std_logic_vector(5 downto 0);
    rxpolarity_in : in std_logic_vector(5 downto 0);
    rxusrclk_in : in std_logic_vector(5 downto 0);
    rxusrclk2_in : in std_logic_vector(5 downto 0);
    tx8b10ben_in : in std_logic_vector(5 downto 0);
    txctrl0_in : in std_logic_vector(95 downto 0);
    txctrl1_in : in std_logic_vector(95 downto 0);
    txctrl2_in : in std_logic_vector(47 downto 0);
    txpolarity_in : in std_logic_vector(5 downto 0);
    txusrclk_in : in std_logic_vector(5 downto 0);
    txusrclk2_in : in std_logic_vector(5 downto 0);
    gthtxn_out : out std_logic_vector(5 downto 0);
    gthtxp_out : out std_logic_vector(5 downto 0);
    rxbyteisaligned_out : out std_logic_vector(5 downto 0);
    rxbyterealign_out : out std_logic_vector(5 downto 0);
    rxcommadet_out : out std_logic_vector(5 downto 0);
    rxctrl0_out : out std_logic_vector(95 downto 0);
    rxctrl1_out : out std_logic_vector(95 downto 0);
    rxctrl2_out : out std_logic_vector(47 downto 0);
    rxctrl3_out : out std_logic_vector(47 downto 0);
    rxoutclk_out : out std_logic_vector(5 downto 0);
    rxpmaresetdone_out : out std_logic_vector(5 downto 0);
    txoutclk_out : out std_logic_vector(5 downto 0);
    txpmaresetdone_out : out std_logic_vector(5 downto 0)
  );
end component;
-------------------------------------

-- Internal signals
   signal r_jesdGtRxArr : jesdGtRxLaneTypeArray(L_RX_G-1 downto 0);       
   signal r_jesdGtTxArr : jesdGtTxLaneTypeArray(L_TX_G-1 downto 0);
   
   -- GT reset
   signal s_gtRxUserReset   : slv(L_RX_G-1 downto 0);
   signal s_gtRxReset       : sl;
   
   signal s_gtTxUserReset   : slv(L_TX_G-1 downto 0);
   signal s_gtTxReset       : sl; 
   
   -- Generated or external
   signal s_sysRef, s_sysRefDbg      : sl;

   -- GT signals
   signal s_rxctrl0 : slv((16* L_RX_G-1) downto 0);
   signal s_rxctrl1 : slv((16* L_RX_G-1) downto 0);
   signal s_rxctrl2 : slv((8* L_RX_G-1)  downto 0);
   signal s_rxctrl3 : slv((8* L_RX_G-1)  downto 0);

   signal s_rxData    : slv((8*GT_WORD_SIZE_C * L_RX_G-1) downto 0); 
   signal s_txData    : slv((8*GT_WORD_SIZE_C * L_RX_G-1) downto 0); 
   signal s_txDataK   : slv(8* L_RX_G-1 downto 0);
   
   
   signal s_devClkVec    : slv(L_RX_G-1 downto 0);
   signal s_devClk2Vec   : slv(L_RX_G-1 downto 0);
   signal s_stableClkVec : slv(L_RX_G-1 downto 0);
   signal s_gtRefClkVec  : slv(L_RX_G-1 downto 0);   
   signal s_rxDone     : sl;
   signal s_txDone       : sl;
   signal s_gtTxReady    : slv(L_TX_G-1 downto 0);

   -- Turn off realignment once aligned
   signal s_dataValidVec : slv(L_RX_G-1 downto 0);
   signal s_allignEnVec : slv(L_RX_G-1 downto 0);

begin
    -- Output assignment
   dataValidVec_o <= s_dataValidVec;

   --------------------------------------------------------------------------------------------------
   -- JESD receiver core
   --------------------------------------------------------------------------------------------------  
   Jesd204bRx_INST: entity work.Jesd204bRx
   generic map (
      TPD_G             => TPD_G,
      TEST_G            => TEST_G,
      AXI_ERROR_RESP_G  => AXI_ERROR_RESP_G,
      F_G               => F_G,
      K_G               => K_G,
      L_G               => L_RX_G)
   port map (
      axiClk            => axiClk,
      axiRst            => axiRst,
      axilReadMaster    => axilReadMasterRx,
      axilReadSlave     => axilReadSlaveRx,
      axilWriteMaster   => axilWriteMasterRx,
      axilWriteSlave    => axilWriteSlaveRx,
      rxAxisMasterArr_o => rxAxisMasterArr,
      rxCtrlArr_i       => rxCtrlArr,
      devClk_i          => devClk_i,
      devRst_i          => devRst_i,
      sysRef_i          => s_sysRef,
      sysRefDbg_o       => s_sysRefDbg,
      r_jesdGtRxArr     => r_jesdGtRxArr,
      gtRxReset_o       => s_gtRxUserReset,
      sampleDataArr_o   => sampleDataArr_o,
      dataValidVec_o    => s_dataValidVec,
      nSync_o           => nSync_o,
      pulse_o           => rxPulse_o,
      leds_o            => ledsRx_o
   );

   --------------------------------------------------------------------------------------------------
   -- JESD transmitter core
   --------------------------------------------------------------------------------------------------  
   Jesd204bTx_INST: entity work.Jesd204bTx
   generic map (
      TPD_G            => TPD_G,

      AXI_ERROR_RESP_G => AXI_ERROR_RESP_G,
      F_G              => F_G,
      K_G              => K_G,
      L_G              => L_TX_G)
   port map (
      axiClk            => axiClk,
      axiRst            => axiRst,
      axilReadMaster    => axilReadMasterTx,
      axilReadSlave     => axilReadSlaveTx,
      axilWriteMaster   => axilWriteMasterTx,
      axilWriteSlave    => axilWriteSlaveTx,
      txAxisMasterArr_i => (others => AXI_STREAM_MASTER_INIT_C),
      txAxisSlaveArr_o  => open,
      extSampleDataArray_i => sampleDataArr_i,
      devClk_i          => devClk_i,
      devRst_i          => devRst_i,
      sysRef_i          => s_sysRef,
      nSync_i           => nSync_i,
      gtTxReady_i       => s_gtTxReady,
      gtTxReset_o       => s_gtTxUserReset,
      r_jesdGtTxArr     => r_jesdGtTxArr,
      pulse_o           => txPulse_o,
      leds_o            => ledsTx_o
   );
   
   
   --------------------------------------------------------------------------------------------------
   -- Generate the internal or external SYSREF depending on SYSREF_GEN_G
   --------------------------------------------------------------------------------------------------
   -- IF DEF SYSREF_GEN_G
   SELF_TEST_GEN: if SYSREF_GEN_G = true generate
      -- Generate the sysref internally
      -- Sysref period will be 8x K_G.
      SysrefGen_INST: entity work.LmfcGen
      generic map (
         TPD_G          => TPD_G,
         K_G            => 256,
         F_G            => 2)
      port map (
         clk      => devClk_i,
         rst      => devRst_i,
         nSync_i  => '0',
         sysref_i => '0',
         lmfc_o   => s_sysRef
      );
      sysRef_o <= s_sysRef;
   end generate SELF_TEST_GEN;
   -- Else 
   OPER_GEN: if SYSREF_GEN_G = false generate
      s_sysRef <= sysRef_i;
      sysRef_o <= s_sysRefDbg;
   end generate OPER_GEN;
  
   --------------------------------------------------------------------------------------------------
   -- GTH RX signals assignments. For L_TX_G = 2
   --------------------------------------------------------------------------------------------------
   s_gtTxReset <= devRst_i or uOr(s_gtTxUserReset);

   s_txData  <= r_jesdGtTxArr(0).data & r_jesdGtTxArr(1).data & x"00000000_00000000_00000000_00000000";
   --s_txData  <=   r_jesdGtTxArr(0).data & r_jesdGtTxArr(1).data & 
   --               r_jesdGtTxArr(0).data & r_jesdGtTxArr(1).data & 
   --               r_jesdGtTxArr(0).data & r_jesdGtTxArr(1).data;
   
   s_txDataK <= x"0" & r_jesdGtTxArr(0).dataK & X"0" & r_jesdGtTxArr(1).dataK & x"00_00_00_00";   
   --s_txDataK <= x"0" & r_jesdGtTxArr(0).dataK & X"0" & r_jesdGtTxArr(1).dataK & 
   --             x"0" & r_jesdGtTxArr(0).dataK & X"0" & r_jesdGtTxArr(1).dataK & 
   --             x"0" & r_jesdGtTxArr(0).dataK & X"0" & r_jesdGtTxArr(1).dataK;
                
   s_gtTxReady <= s_txDone & s_txDone;
   
   --------------------------------------------------------------------------------------------------
   -- GTH RX signals assignments. For L_RX_G = 6
   --------------------------------------------------------------------------------------------------

   s_gtRxReset <= devRst_i or uOr(s_gtRxUserReset);
   
   RX_LANES_GEN : for I in L_RX_G-1 downto 0 generate
      r_jesdGtRxArr(I).data      <= s_rxData(I*(GT_WORD_SIZE_C*8)+31 downto I*(GT_WORD_SIZE_C*8));
      
      r_jesdGtRxArr(I).dataK     <= s_rxctrl0(I*16+GT_WORD_SIZE_C-1  downto  I*16);
      
      r_jesdGtRxArr(I).dispErr   <= s_rxctrl1(I*16+GT_WORD_SIZE_C-1  downto  I*16); 
      
      r_jesdGtRxArr(I).decErr    <= s_rxctrl3(I*8+GT_WORD_SIZE_C-1  downto  I*8); 

      r_jesdGtRxArr(I).rstDone   <= s_rxDone;
   
      s_devClkVec(I)    <= devClk_i;
      s_devClk2Vec(I)   <= devClk2_i;
      s_stableClkVec(I) <= stableClk;
      s_gtRefClkVec(I)  <= refClk;
      
      -- Disable comma alignment when data valid
      s_allignEnVec(I)  <= not s_dataValidVec(I);   
      
   end generate RX_LANES_GEN; 
   qPllLock_o <= s_rxDone;
   
   --------------------------------------------------------------------------------------------------
   -- Include Core from Coregen Vivado 15.1 
   -- Coregen settings:
   -- - Lane rate 7.4 GHz
   -- - Reference freq 184 MHz
   -- - 8b10b enabled
   -- - 32b/40b word datapath
   -- - Comma detection has to be enabled to any byte boundary - IMPORTANT
    --------------------------------------------------------------------------------------------------
   GT_OPER_GEN: if TEST_G = false generate
      GthUltrascaleJesdCoregen_INST: GthUltrascaleJesdCoregen
      port map (
         -- Clocks
         gtwiz_userclk_tx_reset_in(0)         => s_gtTxReset,
         gtwiz_userclk_tx_active_in(0)        => devClkActive_i,
         gtwiz_userclk_rx_active_in(0)        => devClkActive_i,
         
         gtwiz_buffbypass_tx_reset_in(0)      => s_gtTxReset,
         gtwiz_buffbypass_tx_start_user_in(0) => s_gtTxReset,
         gtwiz_buffbypass_tx_done_out         => open,
         gtwiz_buffbypass_tx_error_out        => open,

         gtwiz_reset_clk_freerun_in(0)        => stableClk,
         
         gtwiz_reset_all_in(0)                   => '0',
         gtwiz_reset_tx_pll_and_datapath_in(0)   => s_gtTxReset,
         gtwiz_reset_tx_datapath_in(0)           => s_gtTxReset,
         gtwiz_reset_rx_pll_and_datapath_in(0)   => s_gtRxReset,
         gtwiz_reset_rx_datapath_in(0)           => s_gtRxReset,
         gtwiz_reset_rx_cdr_stable_out        => open,
         gtwiz_reset_tx_done_out(0)           => s_txDone,
         gtwiz_reset_rx_done_out(0)           => s_rxDone,
         gtwiz_userdata_tx_in                 => s_txData,
         gtwiz_userdata_rx_out                => s_rxData,
         drpclk_in                            => s_stableClkVec,
         gthrxn_in                            => gtRxN,
         gthrxp_in                            => gtRxP,
         gtrefclk0_in                         => s_gtRefClkVec,

         tx8b10ben_in                         => "111111",
         txctrl0_in                           => X"0000_0000_0000_0000_0000_0000",
         txctrl1_in                           => X"0000_0000_0000_0000_0000_0000",
         txctrl2_in                           => s_txDataK,
         txpolarity_in                        => "000000",  -- TODO Check
         txusrclk_in                          => s_devClkVec,
         txusrclk2_in                         => s_devClk2Vec,
         gthtxn_out                           => gtTxN,
         gthtxp_out                           => gtTxP,
         txoutclk_out                         => open,
         txpmaresetdone_out                   => open,
         
         -- RX settings
         rx8b10ben_in                         => "111111",
         rxcommadeten_in                      => "111111",
         rxmcommaalignen_in                   => s_allignEnVec,
         rxpcommaalignen_in                   => s_allignEnVec,
         rxpolarity_in                        => "111111",  -- TODO Check
         rxusrclk_in                          => s_devClkVec,
         rxusrclk2_in                         => s_devClk2Vec,

         rxbyteisaligned_out                  => open,
         rxbyterealign_out                    => open,
         rxcommadet_out                       => open,
         rxctrl0_out                          => s_rxctrl0, -- x"000" & r_jesdGtRxArr(1).dataK & X"000" & r_jesdGtRxArr(0).dataK,
         rxctrl1_out                          => s_rxctrl1, -- x"000" & r_jesdGtRxArr(1).dispErr & X"000" & r_jesdGtRxArr(0).dispErr,
         rxctrl2_out                          => s_rxctrl2, -- open -- comma detected on corresponding byte
         rxctrl3_out                          => s_rxctrl3, -- x"0" & r_jesdGtRxArr(1).decErr & X"0" & r_jesdGtRxArr(0).decErr,
         rxoutclk_out                         => open,
         rxpmaresetdone_out                   => open
     );   
   -----------------------------------------
   end generate GT_OPER_GEN;    
   -----------------------------------------------------
end rtl;
