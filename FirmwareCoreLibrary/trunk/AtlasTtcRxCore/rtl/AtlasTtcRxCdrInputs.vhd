-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AtlasTtcRxCdrInputs.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-03-19
-- Last update: 2015-02-27
-- Platform   : Vivado 2014.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: This module monitors the errors detections.
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AtlasTtcRxPkg.all;

library unisim;
use unisim.vcomponents.all;

entity AtlasTtcRxCdrInputs is
   generic (
      TPD_G           : time   := 1 ns;
      IODELAY_GROUP_G : string := "atlas_ttc_rx_delay_group";
      XIL_DEVICE_G    : string := "7SERIES");      
   port (
      -- CDR Signals
      clkP           : in  sl;          -- From ADN2816 IC
      clkN           : in  sl;          -- From ADN2816 IC
      clk            : out sl;
      dataP          : in  sl;          -- From ADN2816 IC
      dataN          : in  sl;          -- From ADN2816 IC   
      data           : out sl;
      -- Emulation Trigger Signals
      clkSel         : in  sl := '0';
      emuSel         : in  sl := '0';
      emuClk         : in  sl;
      emuData        : in  sl;
      -- Serial Data Signals
      serDataRising  : out sl;
      serDataFalling : out sl;
      -- Delay CTRL (refClk200MHz domain)
      delayIn        : in  AtlasTTCRxDelayInType;
      delayOut       : out AtlasTTCRxDelayOutType;
      -- Clock Signals
      refClk200MHz   : in  sl;
      clkSync        : in  sl;          -- Sync strobe
      locClk40MHz    : out sl;
      locClk80MHz    : out sl;
      locClk160MHz   : out sl);
end AtlasTtcRxCdrInputs;

architecture rtl of AtlasTtcRxCdrInputs is

   signal clock,
      locClock,
      serRising,
      serFalling,
      ttcRxData,
      ttcRxDataDly : sl;
   
   signal divClk : slv(1 downto 0);

   attribute IODELAY_GROUP                    : string;
   attribute IODELAY_GROUP of IDELAYCTRL_Inst : label is IODELAY_GROUP_G;
   attribute IODELAY_GROUP of IDELAYE2_inst   : label is IODELAY_GROUP_G;

begin

   locClk160MHz <= locClock;
   clk          <= locClock;

   data           <= ttcRxData  when(emuSel = '0') else emuData;
   serDataRising  <= serRising  when(emuSel = '0') else emuData;
   serDataFalling <= serFalling when(emuSel = '0') else emuData;

   IBUFGDS_Inst : IBUFGDS
      generic map (
         DIFF_TERM => true)
      port map (
         I  => clkP,
         IB => clkN,
         O  => clock);     

   BUFG_160MHz : BUFGMUX
      port map (
         O  => locClock,                -- 1-bit output: Clock output
         I0 => clock,                   -- 1-bit input: Clock input (S=0)
         I1 => emuClk,                  -- 1-bit input: Clock input (S=1)
         S  => clkSel);                 -- 1-bit input: Clock select           

   BUFR_0 : BUFR
      generic map (
         BUFR_DIVIDE => "4",
         SIM_DEVICE  => XIL_DEVICE_G)
      port map (
         I   => locClock,  -- 1-bit input: Clock buffer input driven by an IBUFG, MMCM or local interconnect
         CE  => '1',                    -- 1-bit input: Active high, clock enable input
         CLR => clkSync,                -- 1-bit input: ACtive high reset input
         O   => divClk(0));             -- 1-bit output: Clock output port

   BUFG_40MHz : BUFG
      port map (
         I => divClk(0),
         O => locClk40MHz); 

   BUFR_1 : BUFR
      generic map (
         BUFR_DIVIDE => "2",
         SIM_DEVICE  => XIL_DEVICE_G)
      port map (
         I   => locClock,  -- 1-bit input: Clock buffer input driven by an IBUFG, MMCM or local interconnect
         CE  => '1',                    -- 1-bit input: Active high, clock enable input
         CLR => clkSync,                -- 1-bit input: ACtive high reset input
         O   => divClk(1));             -- 1-bit output: Clock output port

   BUFG_80MHz : BUFG
      port map (
         I => divClk(1),
         O => locClk80MHz);          

   IBUFDS_Inst : IBUFDS
      generic map (
         DIFF_TERM => true)
      port map (
         I  => dataP,
         IB => dataN,
         O  => ttcRxData); 

   IDELAYE2_inst : IDELAYE2
      generic map (
         CINVCTRL_SEL          => "FALSE",     -- Enable dynamic clock inversion (FALSE, TRUE)
         DELAY_SRC             => "IDATAIN",   -- Delay input (IDATAIN, DATAIN)
         HIGH_PERFORMANCE_MODE => "FALSE",     -- Reduced jitter ("TRUE"), Reduced power ("FALSE")
         IDELAY_TYPE           => "VAR_LOAD",  -- FIXED, VARIABLE, VAR_LOAD, VAR_LOAD_PIPE
         IDELAY_VALUE          => 0,    -- Input delay tap setting (0-31)
         PIPE_SEL              => "FALSE",     -- Select pipelined mode, FALSE, TRUE
         REFCLK_FREQUENCY      => 200.0,  -- IDELAYCTRL clock input frequency in MHz (190.0-210.0, 290.0-310.0).
         SIGNAL_PATTERN        => "DATA")      -- DATA, CLOCK input signal

      port map (
         CNTVALUEOUT => delayOut.data,  -- 5-bit output: Counter value output
         DATAOUT     => ttcRxDataDly,   -- 1-bit output: Delayed data output
         C           => refClk200MHz,   -- 1-bit input: Clock input
         CE          => '0',            -- 1-bit input: Active high enable increment/decrement input
         CINVCTRL    => '0',            -- 1-bit input: Dynamic clock inversion input
         CNTVALUEIN  => delayIn.data,   -- 5-bit input: Counter value input
         DATAIN      => '0',            -- 1-bit input: Internal delay data input
         IDATAIN     => ttcRxData,      -- 1-bit input: Data input from the I/O
         INC         => '0',            -- 1-bit input: Increment / Decrement tap delay input
         LD          => '1',            -- 1-bit input: Load IDELAY_VALUE input
         LDPIPEEN    => '0',            -- 1-bit input: Enable PIPELINE register to load data input
         REGRST      => delayIn.load);  -- 1-bit input: Active-high reset tap-delay input

   IDDR_Inst : IDDR
      generic map (
         DDR_CLK_EDGE => "SAME_EDGE_PIPELINED",  -- "OPPOSITE_EDGE", "SAME_EDGE", or "SAME_EDGE_PIPELINED"
         INIT_Q1      => '0',           -- Initial value of Q1: '0' or '1'
         INIT_Q2      => '0',           -- Initial value of Q2: '0' or '1'
         SRTYPE       => "SYNC")        -- Set/Reset type: "SYNC" or "ASYNC" 
      port map (
         D  => ttcRxDataDly,            -- 1-bit DDR data input
         C  => locClock,                -- 1-bit clock input
         CE => '1',                     -- 1-bit clock enable input
         R  => '0',                     -- 1-bit reset
         S  => '0',                     -- 1-bit set
         Q1 => serRising,               -- 1-bit output for positive edge of clock 
         Q2 => serFalling);             -- 1-bit output for negative edge of clock

   IDELAYCTRL_Inst : IDELAYCTRL
      port map (
         RDY    => delayOut.rdy,        -- 1-bit output: Ready output
         REFCLK => refClk200MHz,        -- 1-bit input: Reference clock input
         RST    => delayIn.rst);        -- 1-bit input: Active high reset input

end rtl;
