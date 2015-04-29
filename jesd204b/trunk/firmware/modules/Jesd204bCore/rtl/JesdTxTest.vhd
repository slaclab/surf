-------------------------------------------------------------------------------
-- Title      : JesdTx simple module for testing RX
-------------------------------------------------------------------------------
-- File       : JesdTxTest.vhd
-- Author     : Uros Legat  <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory (Cosylab)
-- Created    : 2015-04-14
-- Last update: 2015-04-24
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Transmitter module for testing JESD RX module.
--              - it replaces GT core and generates a dummy data stream for JESD Rx testing.
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.Jesd204bPkg.all;

entity JesdTxTest is
   generic (
      TPD_G : time := 1 ns;

      -- Number of bytes in a frame
      F_G : positive := 2;

      -- Number of frames in a multi frame
      K_G : positive := 32;

      --Transceiver word size (GTP,GTX,GTH)
      GT_WORD_SIZE_G : positive := 4;

      --JESD204B class (0 and 1 supported)
      SUB_CLASS_G : positive := 1
      );
   port (

      -- JESD
      -- Clocks and Resets   
      devClk_i : in sl;
      devRst_i : in sl;

      -- Control and status register records
      enable_i : in  sl;

      -- Data and character output and GT signals (simple generated)
      r_jesdGtRx : out jesdGtRxLaneType;

      -- Local multi frame clock
      lmfc_i : in sl;

      -- Synchronisation request input 
      nSync_i : in sl;
      
      txDataValid_o : out sl
    );
end JesdTxTest;


architecture rtl of JesdTxTest is

   -- Internal signals

   -- Control signals from FSM
   signal s_testCntr   : slv(7 downto 0);
   signal s_dataValid  : sl;

begin

   -- Synchronisation FSM
   syncFSM_INST : entity work.syncFsmTx
      generic map (
         TPD_G          => TPD_G,
         F_G            => F_G,
         K_G            => K_G,
         GT_WORD_SIZE_G => GT_WORD_SIZE_G,
         SUB_CLASS_G    => SUB_CLASS_G)
      port map (
         clk          => devClk_i,
         rst          => devRst_i,
         enable_i     => enable_i,
         lmfc_i       => lmfc_i,
         nSync_i      => nSync_i,
         testCntr_o   => s_testCntr, 
         dataValid_o  => s_dataValid
      );
      
   -- GT output generation   
   r_jesdGtRx.dataK   <= "1111" when s_dataValid='0' else "0000";
   r_jesdGtRx.data    <= (K_CHAR_C   & K_CHAR_C   & K_CHAR_C   & K_CHAR_C)    when s_dataValid='0' else 
                         ( (s_testCntr+3) & (s_testCntr+2) & (s_testCntr+1) & (s_testCntr));
   r_jesdGtRx.dispErr <= "0000";
   r_jesdGtRx.decErr  <= "0000";
   r_jesdGtRx.rstDone <= '1';

   -- Output assignment   
   txDataValid_o  <= s_dataValid;
 --------------------------------------------
end rtl;
