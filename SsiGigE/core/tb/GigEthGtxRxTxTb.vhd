library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.GigEthPkg.all;

entity GigEthGtxRxTxTb is end GigEthGtxRxTxTb;

architecture testbed of GigEthGtxRxTxTb is

   constant CLK_PERIOD_C : time := 8 ns;
   constant TPD_C        : time := CLK_PERIOD_C/4;

   signal clk,
      rst : sl := '0';

   signal gtxTxP_A : sl;
   signal gtxTxN_A : sl;
   signal gtxTxP_B : sl;
   signal gtxTxN_B : sl;
   
   signal clkP : sl;
   signal clkN : sl;
   
   signal synced_A : sl;
   signal anDone_A : sl;

   signal synced_B : sl;
   signal anDone_B : sl;

   
begin

   -- Generate clocks and resets
   ClkRst_Inst : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,     -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 745 ns)   -- Hold reset for this long)
      port map (
         clkP => clkP,
         clkN => clkN,
         rst  => rst,
         rstL => open); 
         
   U_GigEthGtx7_A : entity work.EthGtx7
   generic map (
      SIM_GTRESET_SPEEDUP_G => "TRUE"
   )
   port map (
      stableRst        => rst,
      -- Gt Serial IO
      gtTxP(0)         => gtxTxP_A,
      gtTxN(0)         => gtxTxN_A,
      gtRxP(0)         => gtxTxP_B,
      gtRxN(0)         => gtxTxP_B,
      -- Gt clocking (125 MHz)
      gtClkP           => clkP,
      gtClkN           => clkN,
      -- Input clocking
      stableClk        => clkP,
      -- Output clocking
      ethClk           => open,
      -- Link signals
      ethRxLinkSync    => synced_A,
      ethAutoNegDone   => anDone_A
   );

   U_GigEthGtx7_B : entity work.EthGtx7
   generic map (
      SIM_GTRESET_SPEEDUP_G => "TRUE"
   )
   port map (
      stableRst        => rst,
      -- Gt Serial IO
      gtTxP(0)         => gtxTxP_B,
      gtTxN(0)         => gtxTxN_B,
      gtRxP(0)         => gtxTxP_A,
      gtRxN(0)         => gtxTxP_A,
      -- Gt clocking (125 MHz)
      gtClkP           => clkP,
      gtClkN           => clkN,
      -- Input clocking
      stableClk        => clkP,
      -- Output clocking
      ethClk           => open,
      -- Link signals
      ethRxLinkSync    => synced_B,
      ethAutoNegDone   => anDone_B
   );
   
         
end testbed;
