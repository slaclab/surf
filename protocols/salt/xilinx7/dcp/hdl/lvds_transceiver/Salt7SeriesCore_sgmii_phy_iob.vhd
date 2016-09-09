--------------------------------------------------------------------------------
-- Title      : 
-- Project    : 1G/2.5G Ethernet PCS/PMA or SGMII LogiCORE
-- File       : Salt7SeriesCore_sgmii_phy_iob.vhd
-- Author     : Xilinx
--------------------------------------------------------------------------------
-- (c) Copyright 2006 Xilinx, Inc. All rights reserved.
--
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
--
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
--
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES. 

--
--
--------------------------------------------------------------------------------
-- Description:   This module contains the delay and capture primitives for SGMII 
--                serial communication over GPIO
--------------------------------------------------------------------------------


LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.std_logic_arith.ALL;
USE IEEE.std_logic_unsigned.ALL;

library unisim;
use unisim.vcomponents.all;

entity  Salt7SeriesCore_sgmii_phy_iob is 
port (
   clk625           : in  std_logic;
   clk208           : in  std_logic;
   refClk200        : in  std_logic;
   clk104           : in  std_logic;
   rst              : in  std_logic;  -- 104
   soft_tx_reset    : in  std_logic;  -- 104
   soft_rx_reset    : in  std_logic;  -- 104
   data_idly_rst    : in  std_logic;
   mon_idly_rst     : in  std_logic;

-- RX Data and Control
   data_dly_val_in  : in  std_logic_vector(4 downto 0);
   data_dly_val_out : out std_logic_vector(4 downto 0);
   mon_dly_val_in   : in  std_logic_vector(4 downto 0);
   mon_dly_val_out  : out std_logic_vector(4 downto 0); 
 
   o_rx_data_12b    : out std_logic_vector(11 downto 0); 
   o_rx_mon         : out std_logic_vector(11 downto 0);
   
   o_rx_data_6b     : out std_logic_vector(5 downto 0);
   
   pin_sgmii_rxp    : in std_logic;  
   pin_sgmii_rxn    : in std_logic;
 
-- TX Data
   tx_data_6b       : in std_logic_vector(5 downto 0);

   pin_sgmii_txp    : out std_logic;  
   pin_sgmii_txn    : out std_logic
 
   );
 end Salt7SeriesCore_sgmii_phy_iob;

architecture xilinx of Salt7SeriesCore_sgmii_phy_iob is 
 -----------------------------------------------------------------------------
-- Component declaration for the reset synchroniser
-----------------------------------------------------------------------------
component Salt7SeriesCore_reset_sync
port (
   reset_in                   : in  std_logic;
   clk                        : in  std_logic;
   reset_out                  : out std_logic
);
end component;

-- Wires and Regs

 signal clk625_inv            : std_logic;
 signal rx_ser_data_delayed   : std_logic;
 signal rx_ser_mon_delayed    : std_logic;
 signal rx_ser_data           : std_logic;
 signal rx_ser_mon            : std_logic;

 signal rx_data_stg1_i        : std_logic_vector(5 downto 0);
 signal rx_data_stg1          : std_logic_vector(11 downto 0);
 signal rx_data_stg2          : std_logic_vector(11 downto 0);
 signal rx_mon_stg1_i         : std_logic_vector(5 downto 0);
 signal rx_mon_stg1           : std_logic_vector(11 downto 0);
 signal rx_mon_stg2           : std_logic_vector(11 downto 0);

 signal tx_ser_data           : std_logic;

signal rst208_r               : std_logic;
signal rst208_r_d1            : std_logic;
signal rst208_r_d2            : std_logic;
signal soft_tx_reset_208      : std_logic;
signal soft_rx_reset_208      : std_logic;
signal soft_rx_reset_208_d1   : std_logic;
signal soft_rx_reset_208_d2   : std_logic;
signal tx_rst_208             : std_logic;
signal rx_rst_208             : std_logic;
signal rx_rst_200             : std_logic;

signal data_dly_ce            : std_logic;
signal data_dly_inc           : std_logic;
signal data_idly_actual_value : std_logic_vector(5 downto 0);
signal data_idly_requested_value : std_logic_vector(5 downto 0);
signal data_idly_requested_value_sync : std_logic_vector(5 downto 0);
signal data_dly_val_out_sync : std_logic_vector(4 downto 0);
signal mon_dly_ce             : std_logic;
signal mon_dly_inc            : std_logic;
signal mon_idly_actual_value  : std_logic_vector(5 downto 0);
signal mon_idly_requested_value : std_logic_vector(5 downto 0);
signal mon_idly_requested_value_sync : std_logic_vector(5 downto 0);
signal mon_dly_val_out_sync  : std_logic_vector(4 downto 0); 

begin 

reset_sync_rst_208 : Salt7SeriesCore_reset_sync
port map(
   clk       => clk208,
   reset_in  => rst,
   reset_out => rst208_r
);

reset_sync_soft_tx_reset_208 : Salt7SeriesCore_reset_sync
port map(
   clk       => clk208,
   reset_in  => soft_tx_reset,
   reset_out => soft_tx_reset_208
);

tx_rst_208   <= rst208_r or soft_tx_reset_208;
rx_rst_208   <= rst208_r or soft_rx_reset_208;

RstSync_Inst : entity work.RstSync
   port map (
      clk      => refClk200,
      asyncRst => rx_rst_208,
      syncRst  => rx_rst_200);

reset_sync_soft_rx_reset_208 : Salt7SeriesCore_reset_sync
port map(
   clk       => clk208,
   reset_in  => soft_rx_reset,
   reset_out => soft_rx_reset_208
);

sgmii_rx_buf_i : IBUFDS_DIFF_OUT 
generic map(
      DIFF_TERM    => TRUE,
      IBUF_LOW_PWR => FALSE
)
port map (
  I  => pin_sgmii_rxp,
  IB => pin_sgmii_rxn,
  O  => rx_ser_data,
  OB => rx_ser_mon
);

     
-- **************************************************************
-- RX Data Chain - IOB -> IDELAY -> ISERDES -> Stg1 Flops
-- **************************************************************      
-- RX Data IDELAY 

--assign data_dly_val_out = data_idly_actual_value[4:0];
-- Track requested IDELAY value
process (clk208)
begin
  if clk208'event and clk208 ='1' then 
    if (rx_rst_208 = '1') then          data_idly_requested_value <= (others => '0');
    elsif (data_idly_rst = '1') then data_idly_requested_value <= ('0' & data_dly_val_in);
    else                    data_idly_requested_value <= data_idly_requested_value;
    end if;
  end if;
end process;

U_data_idly_requested_value : entity work.SynchronizerFifo
   generic map (
      DATA_WIDTH_G => 6)
   port map (
      wr_clk => clk208,
      din    => data_idly_requested_value,
      rd_clk => refClk200,
      dout   => data_idly_requested_value_sync);   

-- Control IDELAY values via inc and ce
process (refClk200)
begin
  if refClk200'event and refClk200 ='1' then 
   if (rx_rst_200 = '1') then      
       data_idly_actual_value <= (others => '0');
       data_dly_ce  <= '0';
       data_dly_inc <= '0';
    elsif (data_idly_actual_value > data_idly_requested_value_sync) then -- need to Decrement
      data_idly_actual_value <= data_idly_actual_value - '1';
      data_dly_ce  <= '1';
      data_dly_inc <= '0';
    elsif (data_idly_actual_value < data_idly_requested_value_sync) then -- Need to Increment
      data_idly_actual_value <= data_idly_actual_value + '1';
      data_dly_ce  <= '1';
      data_dly_inc <= '1';
    else  -- No change requested, hold current values                  
      data_idly_actual_value <= data_idly_actual_value;
      data_dly_ce  <= '0';
      data_dly_inc <= '0';
    end if; 
  end if;
end process;

--   (* IODELAY_GROUP = "<iodelay_group_name>" *) 
 rx_data_idly_i : IDELAYE2 
   generic map(
      CINVCTRL_SEL          => "FALSE",          -- Enable dynamic clock inversion ("TRUE"/"FALSE")  -- This may be helpful for Async mode 
      DELAY_SRC             => "IDATAIN",           
      HIGH_PERFORMANCE_MODE => "TRUE", 
      IDELAY_TYPE           => "VARIABLE",      
      IDELAY_VALUE          => 0,              
      REFCLK_FREQUENCY      => 200.0,      
      SIGNAL_PATTERN        => "DATA",       
      PIPE_SEL              => "FALSE"             
   )
   port map (
      CNTVALUEOUT   => data_dly_val_out_sync, 
      DATAOUT       => rx_ser_data_delayed,         
      C             => refClk200,                    
      CE            => data_dly_ce,                  
      CINVCTRL      => '0',       
      CNTVALUEIN    => "00000",   
      DATAIN        => '0',          
      IDATAIN       => rx_ser_data, 
      INC           => data_dly_inc,             
      REGRST        => rx_rst_200,    
      LD            => rx_rst_200, 
      LDPIPEEN      => '0'        
   );
   
U_data_dly_val_out : entity work.SynchronizerFifo
   generic map (
      DATA_WIDTH_G => 5)
   port map (
      wr_clk => refClk200,
      din    => data_dly_val_out_sync,
      rd_clk => clk208,
      dout   => data_dly_val_out);     

clk625_inv <= not clk625;

-- RX Data ISERDES 
rx_data_iserdes_i  : ISERDESE2 
generic map (
      DATA_RATE         => "DDR",           
      DATA_WIDTH        => 6,              
      DYN_CLKDIV_INV_EN => "FALSE", -- These will be handy for Async operation
      DYN_CLK_INV_EN    => "FALSE",    
      INIT_Q1           => '0',
      INIT_Q2           => '0',
      INIT_Q3           => '0',
      INIT_Q4           => '0',
      INTERFACE_TYPE    => "NETWORKING",
      IOBDELAY          => "IFD",           
      NUM_CE            => 2,                 
      OFB_USED          => "FALSE",         
      SERDES_MODE       => "MASTER",     
      SRVAL_Q1          => '0',
      SRVAL_Q2          => '0',
      SRVAL_Q3          => '0',
      SRVAL_Q4          => '0' 
   )
   port map  (
      O     => open,                      
      Q1    => rx_data_stg1_i(5),  
      Q2    => rx_data_stg1_i(4),  
      Q3    => rx_data_stg1_i(3),  
      Q4    => rx_data_stg1_i(2),  
      Q5    => rx_data_stg1_i(1),  
      Q6    => rx_data_stg1_i(0),  
      Q7    => open,
      Q8    => open,
      -- SHIFTOUT1-SHIFTOUT2: 1-bit (each) output: Data width expansion output ports
      SHIFTOUT1  => open,
      SHIFTOUT2  => open,
      BITSLIP    => '0',         
      CE1        => '1',
      CE2        => '1',
      CLKDIVP    => '0',   
      CLK        => clk625,              
      CLKB       => clk625_inv,            
      CLKDIV     => clk208,           
      OCLK       => '0',                
      DYNCLKDIVSEL => '0',   
      DYNCLKSEL    => '0',      
      D            => '0',                     
      DDLY         => rx_ser_data_delayed, 
      OFB          => '0',                  
      OCLKB        => '0',              
      RST          => rx_rst_208,                  
      SHIFTIN1     => '0',
      SHIFTIN2     => '0' 
   );

process (clk208)
begin
  if clk208'event and clk208 ='1' then
    rst208_r_d1          <= rst208_r;
    rst208_r_d2          <= rst208_r_d1;
    soft_rx_reset_208_d1 <= soft_rx_reset_208;
    soft_rx_reset_208_d2 <= soft_rx_reset_208_d1;
  end if;
end process;

--output of serdes masked for 2 clock cycles after reset to save it from x-propogation in timing simulation.
-- 6 : 12 DEMUX
process (clk208)
begin
  if clk208'event and clk208 ='1' then 
    if (rst208_r_d2 = '1' or soft_rx_reset_208_d2 = '1' ) then 
      rx_data_stg1 <= (others => '0');
    else  
      rx_data_stg1(11 downto 6) <= rx_data_stg1_i(5 downto 0); 
      rx_data_stg1(5 downto 0)  <= rx_data_stg1(11 downto 6);
    end if;
  end if;
end process;

process (clk104)
begin
  if clk104'event and clk104 ='1' then 
    rx_data_stg2 <= rx_data_stg1;
  end if;
end process;
o_rx_data_12b <= rx_data_stg2;
o_rx_data_6b  <= rx_data_stg1(11 downto 6); 

-- **************************************************************
-- RX Monitor Chain - IOB -> IDELAY -> ISERDES -> Stg1 Flops
-- **************************************************************      
-- RX Monitor IDELAY 
--assign mon_dly_val_out = mon_idly_actual_value[4:0];
-- Track requested IDELAY value
process (clk208)
begin
  if clk208'event and clk208 ='1' then 
    if (rx_rst_208 = '1')        then mon_idly_requested_value <= (others => '0');
    elsif (mon_idly_rst = '1') then mon_idly_requested_value <= '0' & mon_dly_val_in;
    else                      mon_idly_requested_value <= mon_idly_requested_value;
    end if;
  end if;
end process;

U_mon_idly_requested_value : entity work.SynchronizerFifo
   generic map (
      DATA_WIDTH_G => 6)
   port map (
      wr_clk => clk208,
      din    => mon_idly_requested_value,
      rd_clk => refClk200,
      dout   => mon_idly_requested_value_sync);   

-- Control IDELAY values via inc and ce
process (refClk200)
begin
  if refClk200'event and refClk200 ='1' then 
   if (rx_rst_200 = '1') then    
      mon_idly_actual_value <= (others => '0');
      mon_dly_ce  <= '0';
      mon_dly_inc <= '0';
   elsif (mon_idly_actual_value > mon_idly_requested_value_sync) then -- need to Decrement
      mon_idly_actual_value <= mon_idly_actual_value - '1';
      mon_dly_ce  <= '1';
      mon_dly_inc <= '0';
   elsif (mon_idly_actual_value < mon_idly_requested_value_sync) then -- Need to Increment
      mon_idly_actual_value <= mon_idly_actual_value + '1';
      mon_dly_ce  <= '1';
      mon_dly_inc <= '1';
   else  -- No change requested, hold current values                  
      mon_idly_actual_value <= mon_idly_actual_value;
      mon_dly_ce  <= '0';
      mon_dly_inc <= '0';
   end if;
  end if;
end process;

 rx_mon_idly_i :  IDELAYE2 
   generic map (
      CINVCTRL_SEL          => "FALSE",          -- Enable dynamic clock inversion ("TRUE"/"FALSE"  -- This may be helpful for Async mode 
      DELAY_SRC             => "IDATAIN",           
      HIGH_PERFORMANCE_MODE => "TRUE", 
      IDELAY_TYPE           => "VARIABLE",      
      IDELAY_VALUE          => 0,              
      REFCLK_FREQUENCY      => 200.0,      
      SIGNAL_PATTERN        => "DATA",       
      PIPE_SEL              => "FALSE"             
   )
   port map (
      CNTVALUEOUT => mon_dly_val_out_sync, 
      DATAOUT     => rx_ser_mon_delayed,         
      C           => refClk200,                    
      CE          => mon_dly_ce,                  
      CINVCTRL    => '0',       
      CNTVALUEIN  => "00000",   
      DATAIN      => '0',          
      IDATAIN     => rx_ser_mon, 
      INC         => mon_dly_inc,             
      REGRST      => rx_rst_200,    
      LD          => rx_rst_200, --         -- 1-bit input - Load IDELAY_VALUE input
      LDPIPEEN    => '0'        
   );
   
U_mon_dly_val_out : entity work.SynchronizerFifo
   generic map (
      DATA_WIDTH_G => 5)
   port map (
      wr_clk => refClk200,
      din    => mon_dly_val_out_sync,
      rd_clk => clk208,
      dout   => mon_dly_val_out);     
     
-- RX Monitor ISERDES 
rx_mon_iserdes_i : ISERDESE2 
generic map (
      DATA_RATE         => "DDR",           
      DATA_WIDTH        => 6,              
      DYN_CLKDIV_INV_EN => "FALSE", -- These will be handy for Async operation
      DYN_CLK_INV_EN    => "FALSE",    
      INIT_Q1           => '0',
      INIT_Q2           => '0',
      INIT_Q3           => '0',
      INIT_Q4           => '0',
      INTERFACE_TYPE    => "NETWORKING",
      IOBDELAY          => "IFD",           
      NUM_CE            => 2,                 
      OFB_USED          => "FALSE",         
      SERDES_MODE       => "MASTER",     
      SRVAL_Q1          => '0',
      SRVAL_Q2          => '0',
      SRVAL_Q3          => '0',
      SRVAL_Q4          => '0'
   )
   port map (
      O   => open,                      
      Q1  => rx_mon_stg1_i(5),  
      Q2  => rx_mon_stg1_i(4),  
      Q3  => rx_mon_stg1_i(3),  
      Q4  => rx_mon_stg1_i(2),  
      Q5  => rx_mon_stg1_i(1),  
      Q6  => rx_mon_stg1_i(0),  
      Q7  => open,
      Q8  => open,
      -- SHIFTOUT1-SHIFTOUT2: 1-bit (each) output: Data width expansion output ports
      SHIFTOUT1  => open,
      SHIFTOUT2  => open,
      BITSLIP    => '0',         
      CE1        => '1',
      CE2        => '1',
      CLKDIVP    => '0',   
      CLK        => clk625,              
      CLKB       => clk625_inv,            
      CLKDIV     => clk208,           
      OCLK       => '0',                
      DYNCLKDIVSEL => '0',   
      DYNCLKSEL    => '0',      
      D            => '0',                     
      DDLY         => rx_ser_mon_delayed, 
      OFB          => '0',                  
      OCLKB        => '0',              
      RST          => rx_rst_208,                  
      SHIFTIN1     => '0',
      SHIFTIN2     => '0' 
   );

process (clk208)
begin
  if clk208'event and clk208 ='1' then 
    if (rx_rst_208 = '1') then rx_mon_stg1 <= (others => '0');
    else  
       rx_mon_stg1(11 downto 6) <= rx_mon_stg1_i(5 downto 0); 
       rx_mon_stg1(5 downto 0)  <= rx_mon_stg1(11 downto 6);
    end if;
  end if;
end process;

process (clk104)
begin
  if clk104'event and clk104 ='1' then 
    rx_mon_stg2 <= rx_mon_stg1;
  end if;
end process;

 o_rx_mon <= rx_mon_stg2;

-- **************************************************************
-- TX Data Chain - 4-bit TX Data -> OSERDES -> IOB
-- **************************************************************      

sgmii_tx_buf_i : OBUFDS 
port map (
  I   => tx_ser_data,
  O   => pin_sgmii_txp,
  OB  => pin_sgmii_txn
);

-- K7 Version
sgmii_tx_oserdes_i : OSERDESE2 
generic map(
      DATA_RATE_OQ => "DDR",   -- "SDR" or "DDR" 
      DATA_RATE_TQ => "SDR",   -- "BUF", "SDR" or "DDR" 
      DATA_WIDTH   => 6,         -- Parallel data width (2-8,10)
      INIT_OQ      => '0',         -- Initial value of OQ output (0/1
      INIT_TQ      => '0',         -- Initial value of TQ output (0/1)
      SERDES_MODE  => "MASTER", -- "MASTER" or "SLAVE" 
      SRVAL_OQ     => '0',        -- OQ output value when SR is used (0/1)
      SRVAL_TQ     => '0',        -- TQ output value when SR is used (0/1)
      TBYTE_CTL    => "FALSE",    -- Enable tristate byte operation ("TRUE" or "FALSE")
      TBYTE_SRC    => "FALSE",    -- Tristate byte source ("TRUE" or "FALSE")
      TRISTATE_WIDTH => 1      -- 3-state converter width (1 or 4)
   )
port map (
      OFB       => open,             
      OQ        => tx_ser_data,            
      
      SHIFTOUT1 => open,
      SHIFTOUT2 => open,
      TBYTEOUT  => open, 
      TFB       => open,             
      TQ        => open,              
      CLK       => clk625,          
      CLKDIV    => clk208,       
      D1        => tx_data_6b(0), 
      D2        => tx_data_6b(1),
      D3        => tx_data_6b(2),
      D4        => tx_data_6b(3),
      D5        => tx_data_6b(4),            
      D6        => tx_data_6b(5),
      D7        => '0',
      D8        => '0',
      OCE       => '1',           
      RST       => tx_rst_208,      
      SHIFTIN1  => '0',
      SHIFTIN2  => '0',
      T1        => '0',
      T2        => '0',
      T3        => '0',
      T4        => '0',
      TBYTEIN   => '0',    
      TCE       => '0'              
   );

end xilinx;



