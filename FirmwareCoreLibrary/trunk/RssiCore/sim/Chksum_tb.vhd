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
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY Chksum_tb IS
END Chksum_tb;
 
ARCHITECTURE behavior OF Chksum_tb IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT Chksum
    PORT(
         clk_i : IN  std_logic;
         rst_i : IN  std_logic;
         enable_i : IN  std_logic;
         strobe_i : IN  std_logic;
         init_i : IN  std_logic_vector(15 downto 0);
         data_i : IN  std_logic_vector(15 downto 0);
         chksum_o : OUT  std_logic_vector(15 downto 0);
         valid_o : OUT  std_logic;
         check_o : OUT  std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal clk_i : std_logic := '0';
   signal rst_i : std_logic := '0';
   signal enable_i : std_logic := '0';
   signal strobe_i : std_logic := '0';
   signal init_i : std_logic_vector(15 downto 0) := (others => '0');
   signal data_i : std_logic_vector(15 downto 0) := (others => '0');

   --Outputs
   signal chksum_o : std_logic_vector(15 downto 0);
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
      wait for clk_i_period*10;
      
      -- Calculate checksum
      init_i <= x"0000";
      data_i <= x"4500";
      enable_i <= '1';
      wait for clk_i_period;    
      strobe_i <= '1';
      wait for clk_i_period;
      data_i <= x"0030";
      wait for clk_i_period;
      data_i <= x"4422";
      wait for clk_i_period;
      data_i <= x"4000";
      wait for clk_i_period;
      data_i <= x"8006";
      wait for clk_i_period;
      data_i <= x"0000";
      wait for clk_i_period;
      data_i <= x"8c7c";
      wait for clk_i_period;
      data_i <= x"19ac";
      wait for clk_i_period;
      data_i <= x"ae24";
      wait for clk_i_period;
      data_i <= x"1e2b";
      wait for clk_i_period;
      strobe_i <= '0';
      wait for clk_i_period;
      
      -- Register chksum
      wait for clk_i_period*5;
      enable_i <= '0';
      wait for clk_i_period*5;      
      
      
      -- Check data
      init_i <= x"442E";
      data_i <= x"4500";
      wait for clk_i_period;    
      enable_i <= '1';
      strobe_i <= '1';      
      wait for clk_i_period;
      data_i <= x"0030";
      wait for clk_i_period;
      data_i <= x"4422";
      wait for clk_i_period;
      data_i <= x"4000";
      wait for clk_i_period;
      data_i <= x"8006";
      wait for clk_i_period;
      data_i <= x"0000";
      wait for clk_i_period;
      data_i <= x"8c7c";
      wait for clk_i_period;
      data_i <= x"19ac";
      wait for clk_i_period;
      data_i <= x"ae24";
      wait for clk_i_period;
      data_i <= x"1e2b";
      wait for clk_i_period;
      strobe_i <= '0';
      wait for clk_i_period*5;
      enable_i <= '0';
      wait;
   end process;

END;
