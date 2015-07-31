-------------------------------------------------------------------------------
-- Title      : JESD204b module containing both receiver and transmitter modules
-------------------------------------------------------------------------------
-- File       : Jesd204bRxTxSim.vhd
-- Author     : Uros Legat  <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory (Cosylab)
-- Created    : 2015-04-14
-- Last update: 2015-04-14
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Framework module for JESD.
--              Note: This module is used only in simulation
--              
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

entity Jesd204bRxTxSim is
   generic (
      TPD_G             : time                        := 1 ns;
      
   -- Test tx module instead of GTX
      TEST_G            : boolean                     := false;
      
      -- Internal SYSREF SYSREF_GEN_G= TRUE else 
      -- External SYSREF
      SYSREF_GEN_G       : boolean                    := true; 
      
      SIM_G              : boolean                    := true; 
           
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
        
   -- User clocks and resets
   ---------------------------------------------------------------------------------------------- 
      devClk_i       : in    sl; -- Device clock also rxUsrClkIn for MGT
      devClk2_i      : in    sl; -- Device clock divided by 2 also rxUsrClk2In for MGT       
      devRst_i       : in    sl; -- 

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
      rxAxisMasterArr : out   AxiStreamMasterArray(L_G-1 downto 0);
      rxCtrlArr       : in    AxiStreamCtrlArray(L_G-1 downto 0);

      -- Sample data output (Use if external data acquisition core is attached)
      sampleDataArr_o   : out   sampleDataArray(L_G-1 downto 0);
      dataValidVec_o    : out   slv(L_G-1 downto 0);
      
      -- Sample data input (Use if external data generator core is attached)      
      sampleDataArr_i   : in   sampleDataArray(L_G-1 downto 0);
      
      
   -- JESD
   ------------------------------------------------------------------------------------------------   

      -- SYSREF for subcalss 1 fixed latency
      sysRef_i       : in    sl;

      -- Synchronisation output combined from all receivers 
      nSync_o        : out   sl;
      
      -- Debug output
      leds_o         : out   slv(1 downto 0)
   );
end Jesd204bRxTxSim;

architecture rtl of Jesd204bRxTxSim is
 
-- Internal signals
   signal r_jesdGtRxArr : jesdGtRxLaneTypeArray(L_G-1 downto 0);       
   signal r_jesdGtTxArr : jesdGtTxLaneTypeArray(L_G-1 downto 0);  

   -- GT reset
   signal s_gtRxUserReset   : slv(L_G-1 downto 0);
   signal s_gtRxReset       : slv(L_G-1 downto 0);
   
   signal s_gtTxUserReset   : slv(L_G-1 downto 0);
   signal s_gtTxReset       : slv(L_G-1 downto 0); 
   -- 
   signal s_gtTxReady       : slv(L_G-1 downto 0);
   
   -- Generated or external
   signal s_sysRef      : sl;
   signal s_nSync       : sl;   
    
   

begin
   -- Check generics TODO add others
   assert (1 <= L_G and L_G <= 8)                      report "L_G must be between 1 and 16"   severity failure;

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
      axilReadMaster    => axilReadMasterRx,
      axilReadSlave     => axilReadSlaveRx,
      axilWriteMaster   => axilWriteMasterRx,
      axilWriteSlave    => axilWriteSlaveRx,
      rxAxisMasterArr_o => rxAxisMasterArr,
      rxCtrlArr_i       => rxCtrlArr,
      devClk_i          => devClk_i,
      devRst_i          => devRst_i,
      sysRef_i          => s_sysRef,
      r_jesdGtRxArr     => r_jesdGtRxArr,
      gtRxReset_o       => s_gtRxUserReset,
      sampleDataArr_o   => sampleDataArr_o,
      dataValidVec_o    => dataValidVec_o,
      nSync_o           => s_nSync,
      sysRefDbg_o       => open,
      pulse_o           => open,
      leds_o            => open
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
      L_G              => L_G)
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
      nSync_i           => s_nSync,
      gtTxReady_i       => s_gtTxReady,
      gtTxReset_o       => s_gtTxUserReset,
      r_jesdGtTxArr     => r_jesdGtTxArr,
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
   end generate SELF_TEST_GEN;
   -- Else 
   OPER_GEN: if SYSREF_GEN_G = false generate
      s_sysRef <= sysRef_i;
   end generate OPER_GEN;

   --------------------------------------------------------------------------------------------------
   -- Generate the TX RX LOOPBACK
   --------------------------------------------------------------------------------------------------
   GT_SIM_GEN: if SIM_G = true generate
      LANES_GEN : for I in (L_G-1) downto 0  generate   
         -- RX
         r_jesdGtRxArr(I).rstDone   <= '1';
         r_jesdGtRxArr(I).data      <= r_jesdGtTxArr(I).data;
         r_jesdGtRxArr(I).dataK     <= r_jesdGtTxArr(I).dataK;
         r_jesdGtRxArr(I).decErr    <= (others => '0');
         r_jesdGtRxArr(I).dispErr   <= (others => '0');
         -- TX
         s_gtTxReady(I)             <= '1';
         --
      end generate LANES_GEN;  
   end generate GT_SIM_GEN;
      
   -- Output assignment
   nSync_o <= s_nSync;

end rtl;
