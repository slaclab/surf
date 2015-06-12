-------------------------------------------------------------------------------
-- Title      : JESD204b receiver module containing the GTH Ultrascale MGT
-------------------------------------------------------------------------------
-- File       : Jesd204bRxGthUltra.vhd
-- Author     : Uros Legat  <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory (Cosylab)
-- Created    : 2015-04-14
-- Last update: 2015-04-14
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Wrapper module for JESD receiver.
--              GTH coregen generated core 2 GTH modules
--              Note: Intended only for two serial lanes L_G=2.
--                    7.4 GHz lane rate and 370MHz reference, Freerunning clk 185 MHz
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

entity Jesd204bRxGthUltra is
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
      L_G            : positive := 2
   );

   port (
   -- GT Interface
   ----------------------------------------------------------------------------------------------     
      -- GT Clocking
      stableClk        : in  sl;                      -- GT needs a stable clock to "boot up"(buffered refClkDiv2) 
      refClk           : in  sl;                      -- GT Reference clock directly from GT GTH diff. input buffer   
      -- Gt Serial IO
      gtTxP            : out slv(L_G-1 downto 0);         -- GT Serial Transmit Positive
      gtTxN            : out slv(L_G-1 downto 0);         -- GT Serial Transmit Negative
      gtRxP            : in  slv(L_G-1 downto 0);         -- GT Serial Receive Positive
      gtRxN            : in  slv(L_G-1 downto 0);         -- GT Serial Receive Negative
        
   -- User clocks and resets
   ---------------------------------------------------------------------------------------------- 
      devClk_i       : in    sl; -- Device clock also rxUsrClkIn for MGT
      devClk2_i      : in    sl; -- Device clock divided by 2 also rxUsrClk2In for MGT       
      devRst_i       : in    sl; -- 

   -- AXI interface
   ------------------------------------------------------------------------------------------------   
      axiClk         : in    sl;
      axiRst         : in    sl;  
      
      -- AXI-Lite Register Interface
      axilReadMaster  : in    AxiLiteReadMasterType;
      axilReadSlave   : out   AxiLiteReadSlaveType;
      axilWriteMaster : in    AxiLiteWriteMasterType;
      axilWriteSlave  : out   AxiLiteWriteSlaveType;
      
      -- AXI Streaming Interface
      txAxisMasterArr : out   AxiStreamMasterArray(L_G-1 downto 0);
      txCtrlArr       : in    AxiStreamCtrlArray(L_G-1 downto 0);   
      
   -- JESD
   ------------------------------------------------------------------------------------------------   

      -- SYSREF for subcalss 1 fixed latency
      sysRef_i       : in    sl;
      
      -- SYSREF out when it is generated internally SYSREF_GEN_G=True     
      sysRef_o       : out    sl;

      -- Synchronisation output combined from all receivers 
      nSync_o        : out   sl;
      
      -- Out to led
      leds_o    : out   slv(1 downto 0);
      
      -- Out to led     
      qPllLock_o : out sl      
   );
end Jesd204bRxGthUltra;

architecture rtl of Jesd204bRxGthUltra is
---------------------------------------   
   component gthultrascalejesdcoregen
      port (
         gtwiz_userclk_tx_active_in : in std_logic_vector(0 downto 0);
         gtwiz_userclk_rx_active_in : in std_logic_vector(0 downto 0);
         gtwiz_reset_clk_freerun_in : in std_logic_vector(0 downto 0);
         gtwiz_reset_all_in : in std_logic_vector(0 downto 0);
         gtwiz_reset_tx_pll_and_datapath_in : in std_logic_vector(0 downto 0);
         gtwiz_reset_tx_datapath_in : in std_logic_vector(0 downto 0);
         gtwiz_reset_rx_pll_and_datapath_in : in std_logic_vector(0 downto 0);
         gtwiz_reset_rx_datapath_in : in std_logic_vector(0 downto 0);
         gtwiz_reset_rx_cdr_stable_out : out std_logic_vector(0 downto 0);
         gtwiz_reset_tx_done_out : out std_logic_vector(0 downto 0);
         gtwiz_reset_rx_done_out : out std_logic_vector(0 downto 0);
         gtwiz_userdata_tx_in : in std_logic_vector(63 downto 0);
         gtwiz_userdata_rx_out : out std_logic_vector(63 downto 0);
         gtrefclk00_in : in std_logic_vector(0 downto 0);
         qpll0outclk_out : out std_logic_vector(0 downto 0);
         qpll0lock_out : out std_logic_vector(0 downto 0);
         qpll0outrefclk_out : out std_logic_vector(0 downto 0);
         gthrxn_in : in std_logic_vector(1 downto 0);
         gthrxp_in : in std_logic_vector(1 downto 0);
         rx8b10ben_in : in std_logic_vector(1 downto 0);
         rxcommadeten_in : in std_logic_vector(1 downto 0);
         rxmcommaalignen_in : in std_logic_vector(1 downto 0);
         rxpcommaalignen_in : in std_logic_vector(1 downto 0);
         rxpolarity_in : in std_logic_vector(1 downto 0);
         rxusrclk_in : in std_logic_vector(1 downto 0);
         rxusrclk2_in : in std_logic_vector(1 downto 0);
         tx8b10ben_in : in std_logic_vector(1 downto 0);
         txctrl0_in : in std_logic_vector(31 downto 0);
         txctrl1_in : in std_logic_vector(31 downto 0);
         txctrl2_in : in std_logic_vector(15 downto 0);
         txpolarity_in : in std_logic_vector(1 downto 0);
         txusrclk_in : in std_logic_vector(1 downto 0);
         txusrclk2_in : in std_logic_vector(1 downto 0);
         gthtxn_out : out std_logic_vector(1 downto 0);
         gthtxp_out : out std_logic_vector(1 downto 0);
         rxbyteisaligned_out : out std_logic_vector(1 downto 0);
         rxbyterealign_out : out std_logic_vector(1 downto 0);
         rxcommadet_out : out std_logic_vector(1 downto 0);
         rxctrl0_out : out std_logic_vector(31 downto 0);
         rxctrl1_out : out std_logic_vector(31 downto 0);
         rxctrl2_out : out std_logic_vector(15 downto 0);
         rxctrl3_out : out std_logic_vector(15 downto 0);
         rxoutclk_out : out std_logic_vector(1 downto 0);
         rxpmaresetdone_out : out std_logic_vector(1 downto 0);
         txoutclk_out : out std_logic_vector(1 downto 0);
         txpmaresetdone_out : out std_logic_vector(1 downto 0)
      );
   end component;
-------------------------------------

-- Internal signals
   signal r_jesdGtRxArr : jesdGtRxLaneTypeArray(L_G-1 downto 0);       

   -- Rx Channel Bonding
   -- signal rxChBondLevel : slv(2 downto 0);
   signal rxChBondIn    : Slv5Array(L_G-1 downto 0);
   signal rxChBondOut   : Slv5Array(L_G-1 downto 0);

   -- GT reset
   signal s_gtUserReset   : slv(L_G-1 downto 0);
   signal s_gtReset       : sl;
   
   -- Generated or external
   signal s_sysRef      : sl;

   -- GT signals
   signal s_rxctrl0 : slv(31 downto 0);
   signal s_rxctrl1 : slv(31 downto 0);
   signal s_rxctrl2 : slv(15 downto 0);
   signal s_rxctrl3 : slv(15 downto 0);

   signal s_data  : slv(63 downto 0);   

   signal s_devClkVec : slv(1 downto 0);
   signal s_devClk2Vec : slv(1 downto 0);
   
   signal s_rxDone : sl;
   
begin
 
   --------------------------------------------------------------------------------------------------
   -- JESD receiver core
   --------------------------------------------------------------------------------------------------  
   Jesd204b_INST: entity work.Jesd204bRx
   generic map (
      TPD_G             => TPD_G,
      TEST_G            => TEST_G,
      AXI_ERROR_RESP_G  => AXI_ERROR_RESP_G,
      F_G               => F_G,
      K_G               => K_G,
      L_G               => L_G)
   port map (
      axiClk            => axiClk,
      axiRst            => axiRst,
      axilReadMaster    => axilReadMaster,
      axilReadSlave     => axilReadSlave,
      axilWriteMaster   => axilWriteMaster,
      axilWriteSlave    => axilWriteSlave,
      txAxisMasterArr_o => txAxisMasterArr,
      txCtrlArr_i       => txCtrlArr,
      devClk_i          => devClk_i,
      devRst_i          => devRst_i,
      sysRef_i          => s_sysRef,
      r_jesdGtRxArr     => r_jesdGtRxArr,
      gt_reset_o        => s_gtUserReset,
      nSync_o           => nSync_o,
      leds_o            => leds_o
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
      sysRef_o <= '0';
   end generate OPER_GEN;
   
   --------------------------------------------------------------------------------------------------
   -- GTH signals assignments. Only for L_G = 2
   --------------------------------------------------------------------------------------------------
   s_gtReset <= devRst_i or uOr(s_gtUserReset);

   r_jesdGtRxArr(0).data      <= s_data(31 downto 0);
   r_jesdGtRxArr(1).data      <= s_data(63 downto 32);
   
   r_jesdGtRxArr(0).dataK     <= s_rxctrl0(3  downto  0);
   r_jesdGtRxArr(1).dataK     <= s_rxctrl0(19 downto 16);
   
   r_jesdGtRxArr(0).dispErr   <= s_rxctrl1(3  downto  0);   
   r_jesdGtRxArr(1).dispErr   <= s_rxctrl1(19 downto 16);   
   
   r_jesdGtRxArr(0).decErr   <= s_rxctrl3(3  downto  0);   
   r_jesdGtRxArr(1).decErr   <= s_rxctrl3(12 downto  9);

   r_jesdGtRxArr(0).rstDone  <= s_rxDone;  
   r_jesdGtRxArr(1).rstDone  <= s_rxDone;
   
   s_devClkVec   <= devClk_i & devClk_i;
   s_devClk2Vec  <= devClk2_i & devClk2_i;
   
   -- debug
   --qPllLock_o <= s_rxDone;
      
   --------------------------------------------------------------------------------------------------
   -- Include Core from Coregen Vivado 15.1 
   --------------------------------------------------------------------------------------------------
   GT_OPER_GEN: if TEST_G = false generate
      GthUltrascaleJesdCoregen_INST: GthUltrascaleJesdCoregen
      port map (
         -- Clocks
         gtwiz_userclk_tx_active_in(0)        => '1',
         gtwiz_userclk_rx_active_in(0)        => '1',
         gtwiz_reset_clk_freerun_in(0)        => stableClk,
         
         gtwiz_reset_all_in(0)                   => s_gtReset,
         gtwiz_reset_tx_pll_and_datapath_in(0)   => s_gtReset,
         gtwiz_reset_tx_datapath_in(0)           => s_gtReset,
         gtwiz_reset_rx_pll_and_datapath_in(0)   => s_gtReset,
         gtwiz_reset_rx_datapath_in(0)           => s_gtReset,
         gtwiz_reset_rx_cdr_stable_out        => open,
         gtwiz_reset_tx_done_out              => open,
         gtwiz_reset_rx_done_out(0)           => s_rxDone,
         gtwiz_userdata_tx_in                 => (s_data'range =>'0'),
         gtwiz_userdata_rx_out                => s_data,
         gtrefclk00_in(0)                     => refClk,
         qpll0outclk_out                      => open,
         qpll0outrefclk_out                   => open,
         gthrxn_in                            => gtRxN,
         gthrxp_in                            => gtRxP,
         qpll0lock_out(0)                     => qPllLock_o,

         tx8b10ben_in                         => "11",
         txctrl0_in                           => X"0000_0000",
         txctrl1_in                           => X"0000_0000",
         txctrl2_in                           => X"0000",
         txpolarity_in                        => "00",
         txusrclk_in                          => s_devClkVec,
         txusrclk2_in                         => s_devClk2Vec,
         gthtxn_out                           => gtTxN,
         gthtxp_out                           => gtTxP,
         txoutclk_out                         => open,
         txpmaresetdone_out                   => open,
         
         -- RX settings
         rx8b10ben_in                         => "11",
         rxcommadeten_in                      => "11",
         rxmcommaalignen_in                   => "11",
         rxpcommaalignen_in                   => "11",
         rxpolarity_in                        => "11",  -- TODO Check Changed to '1' after receiving weird data (sometimes ok sometimes wrong)
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
