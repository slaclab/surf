-------------------------------------------------------------------------------
-- File       : JesdTxTest.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-14
-- Last update: 2015-04-24
-------------------------------------------------------------------------------
-- Description: JesdTx simple module for testing RX
--              Transmitter module for testing JESD RX module.
--              - it replaces GT core and generates a dummy data stream for JESD Rx testing.
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

entity JesdTxTest is
   generic (
      TPD_G : time := 1 ns
   );
   port (

      -- JESD
      -- Clocks and Resets   
      devClk_i       : in  sl;
      devRst_i       : in  sl;
      
      -- JESD subclass selection: '0' or '1'(default)     
      subClass_i : in sl; 

      -- Control and status register records
      enable_i       : in  sl;

      -- Local multi frame clock
      lmfc_i         : in  sl;

      -- Synchronisation request input 
      nSync_i        : in  sl;
      
      -- Lane delay inputs
      delay_i        : in  slv(3 downto 0); -- 1 to 16 clock cycles
      align_i        : in  slv(GT_WORD_SIZE_C-1 downto 0); -- 0001, 0010, 0100, 1000

      txDataValid_o  : out sl;
      
      -- Data and character output and GT signals (simple generated)
      r_jesdGtRx     : out jesdGtRxLaneType    
      
    );
end JesdTxTest;


architecture rtl of JesdTxTest is

   -- Register type
   type RegType is record
      dataD1     : slv(r_jesdGtRx.data'range);
      dataKD1    : slv(r_jesdGtRx.dataK'range);
   end record RegType;

   constant REG_INIT_C : RegType := (
      dataD1       => (others => '0'),
      dataKD1      => (others => '0')
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- Internal signals

   -- Control signals from FSM
   signal s_testCntr   : slv(7 downto 0);
   signal s_dataValid  : sl;
   signal s_align      : sl;
   signal s_lmfc_dly   : sl;
   signal s_nsync_dly  : sl;
   signal s_dataK      : slv(r_jesdGtRx.dataK'range);
   signal s_data       : slv(r_jesdGtRx.data'range);  
   signal s_data_sel   : slv(1 downto 0);
   
begin

   -- Delay lmfc input (for 1 to 16 c-c) to 
   lmfcDly_INST: entity work.SysrefDly
   generic map (
      TPD_G       => TPD_G,
      DLY_WIDTH_G => 4 
   )
   port map (
      clk      => devClk_i,
      rst      => devRst_i,
      dly_i    => delay_i,
      sysref_i => lmfc_i,
      sysref_o => s_lmfc_dly
   );
   
   -- Delay nsync input (for 1 to 16 c-c) to 
   nsyncDly_INST: entity work.SysrefDly
   generic map (
      TPD_G       => TPD_G,
      DLY_WIDTH_G => 4 
   )
   port map (
      clk      => devClk_i,
      rst      => devRst_i,
      dly_i    => delay_i,
      sysref_i => nSync_i,
      sysref_o => s_nsync_dly
   );

   -- Synchronisation FSM
   syncFSM_INST : entity work.SyncFsmTxTest
      generic map (
         TPD_G          => TPD_G)
      port map (
         clk          => devClk_i,
         rst          => devRst_i,
         enable_i     => enable_i,
         lmfc_i       => s_lmfc_dly,
         nSync_i      => s_nsync_dly,
         testCntr_o   => s_testCntr, 
         dataValid_o  => s_dataValid,
         align_o      => s_align,
         subClass_i   => subClass_i
      );
    
   comb : process (r, devRst_i,s_dataK,s_data) is
      variable v : RegType;
   begin
      v := r;
      
      -- Buffer data and char one clock cycle 
      v.dataKD1  := s_dataK;
      v.dataD1   := s_data;
      
      if (devRst_i = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;
      
   end process comb;

   seq : process (devClk_i) is
   begin
      if (rising_edge(devClk_i)) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
   
   s_data_sel <= s_dataValid & s_align;
   
   --GT output generation (depending on GT_WORD_SIZE_C)
   SIZE_4_GEN: if GT_WORD_SIZE_C = 4 generate
   ----------------------------------------------------
      with s_data_sel select
      s_dataK   <= "1111" when "00",
                   "0001" when "01",
                   "0000" when others;
                   
      with s_data_sel select                   
      s_data    <= (K_CHAR_C   & K_CHAR_C   & K_CHAR_C   & K_CHAR_C)                   when "00", 
                   ( (s_testCntr+3) & (s_testCntr+2) & (s_testCntr+1) &  R_CHAR_C)     when "01",
                   ( (s_testCntr+3) & (s_testCntr+2) & (s_testCntr+1) & (s_testCntr))  when others;
                   
      with align_i select 
      r_jesdGtRx.dataK   <= s_dataK                                     when "0001", 
                            s_dataK(2 downto 0) & r.dataKD1(3)          when "0010",
                            s_dataK(1 downto 0) & r.dataKD1(3 downto 2) when "0100",
                            s_dataK(0)          & r.dataKD1(3 downto 1) when "1000",
                            s_dataK                                     when others;

      with align_i select 
      r_jesdGtRx.data    <= s_data                                       when "0001", 
                            s_data(23 downto 0) & r.dataD1(31 downto 24) when "0010",
                            s_data(15 downto 0) & r.dataD1(31 downto 16) when "0100",
                            s_data(7 downto 0)  & r.dataD1(31 downto 8)  when "1000",
                            s_data                                       when others; 
      
      r_jesdGtRx.dispErr <= "0000";
      r_jesdGtRx.decErr  <= "0000";
      r_jesdGtRx.rstDone <= '1';
   -----------------------------------------------   
   end generate SIZE_4_GEN;

      -- GT output generation (depending on GT_WORD_SIZE_C)
   -- SIZE_2_GEN: if GT_WORD_SIZE_C = 2 generate
   -- ----------------------------------------------------
      -- s_dataK   <= "11"                     when (s_dataValid = '0' and  s_align = '0') else 
                   -- "00";
      -- s_data    <= (K_CHAR_C   & K_CHAR_C)  when (s_dataValid = '0' and  s_align = '0') else 
                   -- ((s_testCntr+1) & (s_testCntr));

      -- with align_i select 
      -- r_jesdGtRx.dataK   <= s_dataK                       when "01", 
                            -- s_dataK(0) & r.dataKD1(1)     when "10",
                            -- s_dataK                       when others;

      -- with align_i select 
      -- r_jesdGtRx.data    <= s_data                                       when "01", 
                            -- s_data(7 downto 0)  & r.dataD1(15 downto 8)  when "10",
                            -- s_data                                       when others; 
      
      -- r_jesdGtRx.dispErr <= "00";
      -- r_jesdGtRx.decErr  <= "00";
      -- r_jesdGtRx.rstDone <= '1';
   -- ----------------------------------------------- 
   -- end generate SIZE_2_GEN;
   
   
   -- Output assignment   
   txDataValid_o  <= s_dataValid;
 --------------------------------------------
end rtl;
