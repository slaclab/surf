--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   11:56:10 04/16/2015
-- Design Name:   
-- Module Name:   D:/CSL/DBMS_new/FPGA-2015/test_JESD/Jesd204bTb.vhd
-- Project Name:  test_JESD
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: Jesd204b
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
 
use work.stdrtlpkg.all;
use work.jesd204bpkg.all;

use ieee.numeric_std.all;
 
entity jesd204btb is
end jesd204btb;
 
architecture behavior of jesd204btb is 
 
    -- Component Declaration for the Unit Under Test (UUT)
    component jesd204b
    port(
         devClk_i       : in  std_logic;
         devRst_i       : in  std_logic;
         sysRef_i       : in  std_logic;
         dataRx_i       : in  slv32array(0 to 1);
         chariskRx_i    : in  slv4array(0 to 1);
         nSync_o        : out std_logic;
         r_ctrlRegArr   : in  ctrlRegArrType(0 to 1);
         r_statRegArr   : out statRegArrType(0 to 1);
         dataValid_o    : out std_logic;
         sysrefDly_i    : in  slv(4 downto 0);
         sampleData_o   : out Slv32Array(0 to 1)
        );
    end component;

   --Inputs
   signal devClk_i      : std_logic   := '0';
   signal devRst_i      : std_logic   := '1';
   signal sysRef_i      : std_logic   := '0';
   signal dataRx_i      : Slv32Array(0 to 1):= (others=>(others=>'0'));
   signal chariskRx_i   : Slv4Array(0 to 1):= (others=>(others=>'0'));
   signal sysrefDly_i   : slv(4 downto 0):= "11111";
   signal r_ctrlRegArr  : ctrlRegArrType(0 to 1) := ( ('0', "0000"), ('0', "0000") );

 	--Outputs
   signal nSync_o : std_logic;
   signal r_statRegArr : statRegArrType(0 to 1);
   signal dataValid_o : std_logic;
   signal sampleData_o : Slv32Array(0 to 1);
 
   constant clk_period : time := 10 ns;
 
begin
 
	-- Instantiate the Unit Under Test (UUT)
   uut: Jesd204b port map (
          devClk_i => devClk_i,
          devRst_i => devRst_i,
          sysRef_i => sysRef_i,
          dataRx_i => dataRx_i,
          chariskRx_i => chariskRx_i,
          nSync_o => nSync_o,
          r_ctrlRegArr => r_ctrlRegArr,
          r_statRegArr => r_statRegArr,
          dataValid_o => dataValid_o,
          sampleData_o => sampleData_o,
          sysrefDly_i => sysrefDly_i
   );

   -- Clock process definitions
   devClk_i_process :process
   begin
		devClk_i <= '0';
		wait for clk_period/2;
		devClk_i <= '1';
		wait for clk_period/2;
   end process;
 

   -- Lane 1
   lane_1_proc: process
   begin
   
      dataRx_i(0)    <=  x"00_00_00_00"; 
      chariskRx_i(0) <=  "0000";
      
      -- hold reset state for 100 ns.
      wait for 100 ns;	
      devRst_i <= '0';
      wait for clk_period*50;
      
      -- Enable the RX module
      r_ctrlRegArr(0).enable <= '1';
      r_ctrlRegArr(1).enable <= '1';
      
      wait for clk_period/2;
      
      wait for clk_period*10;
      
      -- Start sending Comma 
      dataRx_i(0)    <=  x"BC_BC_BC_BC"; 
      chariskRx_i(0) <=  "1111";
      
      -- 
      wait until nSync_o = '1';
      
      -- Adjust the Lane delay
      wait for clk_period*17; 
      
      -- ILA start
      
      -- Multi frame 1
      dataRx_i(0)    <=  x"01_00_1C_BC"; 
      chariskRx_i(0) <=  "0011";
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";   
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";   
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";

      -- Multi frame 2            
      wait for clk_period;      
      dataRx_i(0)    <=  x"01_00_1C_7C"; 
      chariskRx_i(0) <=  "0011";   
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";   
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";   
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";

      -- Multi frame 3 
      wait for clk_period;      
      dataRx_i(0)    <=  x"01_00_1C_7C"; 
      chariskRx_i(0) <=  "0011";   
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";   
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";   
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";

      -- Multi frame 4 
      wait for clk_period;      
      dataRx_i(0)    <=  x"01_00_1C_7C"; 
      chariskRx_i(0) <=  "0011";   
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";   
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";   
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";
      
      -- Start of data
      wait for clk_period;      
      dataRx_i(0)    <=  x"00_01_00_7C"; 
      chariskRx_i(0) <=  "0001";
      wait for clk_period;      
      dataRx_i(0)    <=  x"00_01_00_02"; 
      chariskRx_i(0) <=  "0001";

----------------------------------------------------------------- End of first sync      
      wait for clk_period*100;     
      
      -- Disable the RX modules
      r_ctrlRegArr(0).enable <= '0';
      r_ctrlRegArr(1).enable <= '0';
      
      -- Start sending Comma 
      dataRx_i(0)    <=  x"BC_BC_BC_BC"; 
      chariskRx_i(0) <=  "1111"; 

      wait for clk_period*100;      

      -- Enable the RX modules
      r_ctrlRegArr(0).enable <= '1';
      r_ctrlRegArr(1).enable <= '1';

----------------------------------------------------------------- Start of second sync      

      wait until nSync_o = '1';
      
      -- Adjust the Lane delay
      wait for clk_period*26; 
      
      -- ILA start
      
      -- Multi frame 1
      dataRx_i(0)    <=  x"01_00_1C_BC"; 
      chariskRx_i(0) <=  "0011";
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";   
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";   
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";

      -- Multi frame 2            
      wait for clk_period;      
      dataRx_i(0)    <=  x"01_00_1C_7C"; 
      chariskRx_i(0) <=  "0011";   
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";   
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";   
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";

      -- Multi frame 3 
      wait for clk_period;      
      dataRx_i(0)    <=  x"01_00_1C_7C"; 
      chariskRx_i(0) <=  "0011";   
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";   
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";   
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";

      -- Multi frame 4 
      wait for clk_period;      
      dataRx_i(0)    <=  x"01_00_1C_7C"; 
      chariskRx_i(0) <=  "0011";   
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";   
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";   
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";      
      wait for clk_period;
      dataRx_i(0)    <=  x"02_00_01_00"; 
      chariskRx_i(0) <=  "0000";
      wait for clk_period;
      dataRx_i(0)    <=  x"01_00_02_00"; 
      chariskRx_i(0) <=  "0000";
      
      -- Start of data
      wait for clk_period;      
      dataRx_i(0)    <=  x"00_01_00_7C"; 
      chariskRx_i(0) <=  "0001";
      wait for clk_period;      
      dataRx_i(0)    <=  x"00_01_00_02"; 
      chariskRx_i(0) <=  "0001";

      
      wait;
   end process;
   
----------------------------------------------------------------- Lane 2
   lane_2_proc: process
   begin
      dataRx_i(1)    <=  x"00_00_00_00"; 
      chariskRx_i(1) <=  "0000";
      
      wait for 100 ns;	

      wait for clk_period*50;
      
     
      wait for clk_period/2;
      
      wait for clk_period*10;
      
      -- Start sending Comma 
      dataRx_i(1)    <=  x"BC_BC_BC_BC"; 
      chariskRx_i(1) <=  "1111";
      
      wait until nSync_o = '1';
      
      -- Adjust the Lane delay
      wait for clk_period*21; 
      
      -- ILA start
      
      -- Multi frame 1
      dataRx_i(1)    <=  x"01_00_1C_BC"; 
      chariskRx_i(1) <=  "0011";
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";   
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";   
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";

      -- Multi frame 2            
      wait for clk_period;      
      dataRx_i(1)    <=  x"01_00_1C_7C"; 
      chariskRx_i(1) <=  "0011";   
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";   
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";   
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";

      -- Multi frame 3 
      wait for clk_period;      
      dataRx_i(1)    <=  x"01_00_1C_7C"; 
      chariskRx_i(1) <=  "0011";   
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";   
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";   
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";

      -- Multi frame 4 
      wait for clk_period;      
      dataRx_i(1)    <=  x"01_00_1C_7C"; 
      chariskRx_i(1) <=  "0011";   
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";   
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";   
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";
      
      -- Start of data
      wait for clk_period;      
      dataRx_i(1)    <=  x"00_01_00_7C"; 
      chariskRx_i(1) <=  "0001";
      wait for clk_period;      
      dataRx_i(1)    <=  x"00_01_00_02"; 
      chariskRx_i(1) <=  "0001";
      
      ----------------------------------------------------------------- End of first sync      
      wait for clk_period*100;     
      
      -- Disable the RX modules
      
      -- Start sending Comma 
      dataRx_i(1)    <=  x"BC_BC_BC_BC"; 
      chariskRx_i(1) <=  "1111"; 

      wait for clk_period*100;      

      -- Enable the RX modules

----------------------------------------------------------------- Start of second sync      

      wait until nSync_o = '1';
  
            -- Adjust the Lane delay
      wait for clk_period*18; 
      
      -- ILA start
      
      -- Multi frame 1
      dataRx_i(1)    <=  x"01_00_1C_BC"; 
      chariskRx_i(1) <=  "0011";
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";   
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";   
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";

      -- Multi frame 2            
      wait for clk_period;      
      dataRx_i(1)    <=  x"01_00_1C_7C"; 
      chariskRx_i(1) <=  "0011";   
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";   
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";   
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";

      -- Multi frame 3 
      wait for clk_period;      
      dataRx_i(1)    <=  x"01_00_1C_7C"; 
      chariskRx_i(1) <=  "0011";   
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";   
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";   
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";

      -- Multi frame 4 
      wait for clk_period;      
      dataRx_i(1)    <=  x"01_00_1C_7C"; 
      chariskRx_i(1) <=  "0011";   
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";   
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";   
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";      
      wait for clk_period;
      dataRx_i(1)    <=  x"02_00_01_00"; 
      chariskRx_i(1) <=  "0000";
      wait for clk_period;
      dataRx_i(1)    <=  x"01_00_02_00"; 
      chariskRx_i(1) <=  "0000";
      
      -- Start of data
      wait for clk_period;      
      dataRx_i(1)    <=  x"00_01_00_7C"; 
      chariskRx_i(1) <=  "0001";
      wait for clk_period;      
      dataRx_i(1)    <=  x"00_01_00_02"; 
      chariskRx_i(1) <=  "0001";
      
      wait;
   end process;
   
   -- Generate SYSREF 
   rysref_proc: process
   begin
      wait for clk_period*60;
      sysRef_i <= '1';
      wait for clk_period*4;      
      sysRef_i <= '0';
   end process;

END;
