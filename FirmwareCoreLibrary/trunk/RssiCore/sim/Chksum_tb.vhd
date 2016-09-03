------------------------------------------------------------------------------
-- This file is part of 'Reliable SLAC Streaming Interface Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'Reliable SLAC Streaming Interface Core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   14:59:52 09/10/2015
-- Design Name:   
-- Module Name:   D:/CSL/SLAC/RSSI/proj/Chksum_tb.vhd
-- Project Name:  rssi
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: Chksum
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- This testbench has been automatically generated using types std_logic and
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation 
-- simulation model.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
 
-- uncomment the following library declaration if using
-- arithmetic functions with signed or unsigned values
--use ieee.numeric_std.all;
 
entity chksum_tb is
end chksum_tb;
 
architecture behavior of chksum_tb is 
 
    -- component declaration for the unit under test (uut)
 
    component chksum
    port(
         clk_i : in  std_logic;
         rst_i : in  std_logic;
         enable_i : in  std_logic;
         strobe_i : in  std_logic;
         length_i   : in positive; 
         init_i : in  std_logic_vector(15 downto 0);
         data_i : in  std_logic_vector(63 downto 0);
         chksum_o : out  std_logic_vector(15 downto 0);
         --chksumreg_o : out  std_logic_vector(15 downto 0);
         valid_o : out  std_logic;
         check_o : out  std_logic
        );
    end component;
    

   --Inputs
   signal clk_i : std_logic := '0';
   signal rst_i : std_logic := '0';
   signal enable_i : std_logic := '0';
   signal strobe_i : std_logic := '0';
   signal init_i : std_logic_vector(15 downto 0) := (others => '0');
   signal data_i : std_logic_vector(63 downto 0) := (others => '0');

   --Outputs
   signal chksum_o : std_logic_vector(15 downto 0);
   --signal chksumReg_o : std_logic_vector(15 downto 0);
   signal valid_o : std_logic;
   signal check_o : std_logic;

   -- Clock period definitions
   constant clk_i_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: Chksum PORT MAP (
          clk_i => clk_i,
          rst_i => rst_i,
          enable_i => enable_i,
          strobe_i => strobe_i,
          init_i => init_i,
          data_i => data_i,
          chksum_o => chksum_o,
          length_i => 3,
          --chksumReg_o => chksumReg_o,
          valid_o => valid_o,
          check_o => check_o
        );

   -- Clock process definitions
   clk_i_process :process
   begin
		clk_i <= '0';
		wait for clk_i_period/2;
		clk_i <= '1';
		wait for clk_i_period/2;
   end process;
 

   -- Stimulus process
   stim_proc: process
   begin		
      -- hold reset state for 100 ns.
      rst_i <= '1';
      wait for 100 ns;	
      rst_i <= '0';
      enable_i <= '1';
      wait for clk_i_period*10;
      strobe_i <= '1';
      -- Calculate checksum
      init_i <= x"0000";
      --data_i <= x"4500" & x"0030" & x"4422" & x"4000";
      --data_i <= x"ffff" & x"ffff" & x"0000" & x"0001";
      data_i <= x"ffff" & x"ffff" & x"ffff" & x"ffff";
      wait for clk_i_period;
      --data_i <= x"8006" & x"0000" & x"8c7c" & x"19ac";
      --data_i <= x"0000" & x"0000" & x"0000" & x"0000";
      data_i <= x"ffff" & x"ffff" & x"ffff" & x"ffff";
      wait for clk_i_period;
      --data_i <= x"ae24" & x"1e2b" & x"0000" & x"0000";
      --data_i <= x"0000" & x"0000" & x"0000" & x"0000";
      data_i <= x"ffff" & x"0008" & x"0000" & x"0000";
      wait for clk_i_period;
      wait for clk_i_period;
      strobe_i <= '0';
      wait for clk_i_period*20;
      
      
      
      -- Check data
      init_i <= x"fff7";      
      enable_i <= '0';
      wait for clk_i_period;      
      enable_i <= '1';      
      

      wait for clk_i_period;
      --data_i <= x"4500" & x"0030" & x"4422" & x"4000";
      --data_i <= x"ffff" & x"ffff" & x"0000" & x"0001";
      data_i <= x"ffff" & x"ffff" & x"ffff" & x"ffff";
      strobe_i <= '1';    
      wait for clk_i_period;
      --data_i <= x"8006" & x"0000" & x"8c7c" & x"19ac";
      --data_i <= x"0000" & x"0000" & x"0000" & x"0000";
      data_i <= x"ffff" & x"ffff" & x"ffff" & x"ffff";
      wait for clk_i_period;
      --data_i <= x"ae24" & x"1e2b" & x"0000" & x"442E";
      ---data_i <= x"0000" & x"0000" & x"0000" & x"0000";
      data_i <= x"ffff" & x"0008" & x"0000" & x"0000";
      wait for clk_i_period;
      strobe_i <= '0';
      wait for clk_i_period*5;
      wait;
   end process;

END;
