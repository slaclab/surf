-------------------------------------------------------------------------------
-- File       : AxiLtc2270DeserBit.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-21
-- Last update: 2014-04-21
-------------------------------------------------------------------------------
-- Description: ADC DDR Deserializer
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLtc2270Pkg.all;

library unisim;
use unisim.vcomponents.all;

entity AxiLtc2270DeserBit is
   generic (
      TPD_G           : time            := 1 ns;
      DELAY_INIT_G    : slv(4 downto 0) := (others => '0');
      IODELAY_GROUP_G : string          := "AXI_LTC2270_IODELAY_GRP");
   port (
      -- ADC Data (clk domain)
      dataP        : in  sl;
      dataN        : in  sl;
      Q1           : out sl;
      Q2           : out sl;
      -- IO_Delay (refClk200MHz domain)
      delayInLoad  : in  sl;
      delayInData  : in  slv(4 downto 0);
      delayOutData : out slv(4 downto 0);
      -- Clocks
      clk          : in  sl;
      refClk200MHz : in  sl);
end AxiLtc2270DeserBit;

architecture rtl of AxiLtc2270DeserBit is
   
   signal data,
      dataDly : sl;
   
   attribute IODELAY_GROUP                  : string;
   attribute IODELAY_GROUP of IDELAYE2_inst : label is IODELAY_GROUP_G;
   
begin

   IBUFDS_Inst : IBUFDS
      port map (
         I  => dataP,
         IB => dataN,
         O  => data);                 

   IDELAYE2_inst : IDELAYE2
      generic map (
         CINVCTRL_SEL          => "FALSE",     -- Enable dynamic clock inversion (FALSE, TRUE)
         DELAY_SRC             => "IDATAIN",   -- Delay input (IDATAIN, DATAIN)
         HIGH_PERFORMANCE_MODE => "FALSE",     -- Reduced jitter ("TRUE"), Reduced power ("FALSE")
         IDELAY_TYPE           => "VAR_LOAD",  -- FIXED, VARIABLE, VAR_LOAD, VAR_LOAD_PIPE
         IDELAY_VALUE          => conv_integer(DELAY_INIT_G),  -- Input delay tap setting (0-31)
         PIPE_SEL              => "FALSE",     -- Select pipelined mode, FALSE, TRUE
         REFCLK_FREQUENCY      => 200.0,  -- IDELAYCTRL clock input frequency in MHz (190.0-210.0, 290.0-310.0).
         SIGNAL_PATTERN        => "DATA")      -- DATA, CLOCK input signal
      port map (
         CNTVALUEOUT => delayOutData,   -- 5-bit output: Counter value output
         DATAOUT     => dataDly,        -- 1-bit output: Delayed data output
         C           => refClk200MHz,   -- 1-bit input: Clock input
         CE          => '0',            -- 1-bit input: Active high enable increment/decrement input
         CINVCTRL    => '0',            -- 1-bit input: Dynamic clock inversion input
         CNTVALUEIN  => delayInData,    -- 5-bit input: Counter value input
         DATAIN      => '0',            -- 1-bit input: Internal delay data input
         IDATAIN     => data,           -- 1-bit input: Data input from the I/O
         INC         => '0',            -- 1-bit input: Increment / Decrement tap delay input
         LD          => '1',            -- 1-bit input: Load IDELAY_VALUE input
         LDPIPEEN    => '0',            -- 1-bit input: Enable PIPELINE register to load data input
         REGRST      => delayInLoad);   -- 1-bit input: Active-high reset tap-delay input

   IDDR_Inst : IDDR
      generic map (
         DDR_CLK_EDGE => "SAME_EDGE_PIPELINED",  -- "OPPOSITE_EDGE", "SAME_EDGE", or "SAME_EDGE_PIPELINED"
         INIT_Q1      => '0',           -- Initial value of Q1: '0' or '1'
         INIT_Q2      => '0',           -- Initial value of Q2: '0' or '1'
         SRTYPE       => "SYNC")        -- Set/Reset type: "SYNC" or "ASYNC" 
      port map (
         D  => dataDly,                 -- 1-bit DDR data input
         C  => clk,                     -- 1-bit clock input
         CE => '1',                     -- 1-bit clock enable input
         R  => '0',                     -- 1-bit reset
         S  => '0',                     -- 1-bit set
         Q1 => Q1,                      -- 1-bit output for positive edge of clock 
         Q2 => Q2);                     -- 1-bit output for negative edge of clock

end rtl;
