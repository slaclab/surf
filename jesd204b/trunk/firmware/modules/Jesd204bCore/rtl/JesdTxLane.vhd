-------------------------------------------------------------------------------
-- Title      : JesdTx transmit single lane module
-------------------------------------------------------------------------------
-- File       : JesdTxLane.vhd
-- Author     : Uros Legat  <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory (Cosylab)
-- Created    : 2015-04-14
-- Last update: 2015-04-24
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Transmitter for JESD204b standard.
--              Supports sub-class 1 deterministic latency.
--              Supports sub-class 0 non deterministic latency
--              Features:
--              - Synchronisation FSM
--              - Comma transmission
--              - ILA Sequence generation
--              - Control character generation:
--                   - A(K28.3) - x"7C" - End of multi-frame
--                   - F(K28.7) - x"FC" - Inserted at the end of the frame
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.Jesd204bPkg.all;

entity JesdTxLane is
   generic (
      TPD_G       : time      := 1 ns;
      F_G         : positive  := 2;
      K_G         : positive  := 32;
      SUB_CLASS_G : natural   := 1
   );
   port (

      -- JESD
      -- Clocks and Resets   
      devClk_i       : in  sl;
      devRst_i       : in  sl;

      -- Control and status register records
      enable_i       : in  sl;

      -- Local multi frame clock
      lmfc_i         : in  sl;

      -- Synchronisation request input 
      nSync_i        : in  sl;
           
      -- GT is ready to transmit data after reset
      gtTxReady_i    : in  sl;
      
      -- SYSREF for subcalss 1 fixed latency
      sysRef_i       : in    sl;

      -- Status of the transmitter
      status_o       : out slv(TX_STAT_WIDTH_C-1 downto 0);
      
      -- Sample data input      
      sampleData_i  : in  slv((GT_WORD_SIZE_C*8)-1 downto 0);
      
      -- Data and character output and GT signals
      r_jesdGtTx     : out jesdGtTxLaneType
   );
end JesdTxLane;

architecture rtl of JesdTxLane is

   -- Internal signals

   -- Control signals from FSM
   signal s_dataValid  : sl;
   signal s_ila        : sl;
   
   -- Data-path
   signal s_sampleDataMux  : slv(r_jesdGtTx.data'range);
   signal s_sampleKMux     : slv(r_jesdGtTx.dataK'range);
   signal s_ilaDataMux     : slv(r_jesdGtTx.data'range);
   signal s_ilaKMux        : slv(r_jesdGtTx.dataK'range);
   signal s_commaDataMux   : slv(r_jesdGtTx.data'range);
   signal s_commaKMux      : slv(r_jesdGtTx.dataK'range);

   signal s_data_sel       : slv(1 downto 0);
   
begin
     
   -- Synchronisation FSM
   syncFSM_INST : entity work.SyncFsmTx
      generic map (
      TPD_G         => TPD_G,
      NUM_ILAS_MF_G => 4,
      SUB_CLASS_G   => SUB_CLASS_G)
      port map (
         clk          => devClk_i,
         rst          => devRst_i,
         enable_i     => enable_i,
         gtTxReady_i  => gtTxReady_i,
         lmfc_i       => lmfc_i,
         nSync_i      => nSync_i,
         sysRef_i     => sysRef_i, 
         dataValid_o  => s_dataValid,
         ila_o        => s_ila
      );    

   ----------------------------------------------------   
   -- Comma character generation
   COMMA_GEN : for I in GT_WORD_SIZE_C-1 downto 0 generate
      s_commaDataMux(I*8+7 downto I*8) <= K_CHAR_C;   
      s_commaKMux(I)    <= '1';
   end generate COMMA_GEN;
   
   ----------------------------------------------------     
   -- Initial Synchronisation Data Sequence (ILAS)
   ilasGen_INST: entity work.IlasGen
   generic map (
      TPD_G => TPD_G,
      F_G   => F_G)
   port map (
      clk        => devClk_i,
      rst        => devRst_i,
      enable_i   => enable_i,
      ilas_i     => s_ila,
      lmfc_i     => lmfc_i,
      ilasData_o => s_ilaDataMux,
      ilasK_o    => s_ilaKMux);
      
   ----------------------------------------------------     
   -- Sample data with added synchronisation characters TODO
   AlignChGen_INST: entity work.AlignChGen
   generic map (
      TPD_G => TPD_G,
      F_G   => F_G)
   port map (
      clk          => devClk_i,
      rst          => devRst_i,
      enable_i     => enable_i,
      lmfc_i       => lmfc_i,
      dataValid_i  => s_dataValid,
      sampleData_i => sampleData_i,
      sampleData_o => s_sampleDataMux,
      sampleK_o    => s_sampleKMux);
 
   ----------------------------------------------------
   -- Output multiplexers   
   s_data_sel <= s_dataValid & s_ila;

   with s_data_sel select
   r_jesdGtTx.dataK     <= s_commaKMux    when "00",
                           s_ilaKMux      when "01",
                           s_sampleKMux   when "10",
                           s_commaKMux    when others;
                
   with s_data_sel select                   
   r_jesdGtTx.data      <= s_commaDataMux       when "00", 
                           s_ilaDataMux         when "01",
                           s_sampleDataMux      when "10",
                           s_commaDataMux       when others;
                              
   -- Output assignment   
   status_o  <= nSync_i & s_dataValid & s_ila & gtTxReady_i;
 --------------------------------------------
end rtl;
