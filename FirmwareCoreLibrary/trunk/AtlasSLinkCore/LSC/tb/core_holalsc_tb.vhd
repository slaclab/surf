-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : core_holalsc_tb.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory 
-- Created    : 2014-03-25
-- Last update: 2014-08-13
-- Platform   : Vivado 2013.3  
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Simulation testbed for core_holalsc.vhd
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory 
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.AtlasSLinkLscPkg.all;

library unisim;
use unisim.vcomponents.all;

entity core_holalsc_tb is end core_holalsc_tb;

architecture testbed of core_holalsc_tb is

   constant LOC_CLK_PERIOD_C : time := 10 ns;
   constant TPD_C            : time := LOC_CLK_PERIOD_C/4;

   signal sysClk,
      sysRst,
      ICLK2,
      LFF_N,
      LDOWN_N,
      TESTLED_N,
      LDERRLED_N,
      LUPLED_N,
      FLOWCTLLED_N,
      ACTIVITYLED_N,
      TLK_TXEN,
      TLK_TXER,
      TLK_RXER,
      TLK_RXDV,
      LSC_RST_N : sl := '0';
   signal cnt  : slv(2 downto 0) := (others => '0');
   signal LRL  : slv(3 downto 0) := (others => '0');
   signal TLK_TXD,
      TLK_RXD : slv(15 downto 0) := (others => '0');
   
begin

   -- Generate clocks and resets
   ClkRst_loc : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => LOC_CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,     -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 250 ns)  -- Hold reset for this long)
      port map (
         clkP => sysClk,
         clkN => open,
         rst  => sysRst,
         rstL => LSC_RST_N);  
         
   U_BUFR : BUFR
      generic map (
         BUFR_DIVIDE => "2",
         SIM_DEVICE  => "7SERIES")
      port map (
         I   => sysClk,
         CE  => '1',   
         CLR => '0', 
         O   => ICLK2);     

   holalsc_core_1 : entity work.holalsc_core
      generic map (
         SIMULATION      => 0,          -- Simulation mode
         XCLK_FREQ       => 100,        -- XCLK = 100 MHz
         USE_PLL         => 0,          -- Do not use PLL to generate ICLK_2
         USE_ICLK2       => 1,          -- use external ICLK2 input
         ACTIVITY_LENGTH => 15,         -- ACTLED duration
         FIFODEPTH       => 64,         -- LSC FIFO depth, only powers of 2
         LOG2DEPTH       => 6,          -- 2log of depth
         FULLMARGIN      => 16)         -- words left when LFF_N set
      port map (
         POWER_UP_RST_N => LSC_RST_N,
         -- S-LINK signals 
         UD             => (others => '0'),
         URESET_N       => '1',
         UTEST_N        => '1',
         UCTRL_N        => '1',
         UWEN_N         => '1',
         UCLK           => sysClk,
         LFF_N          => LFF_N,
         LRL            => LRL,
         LDOWN_N        => LDOWN_N,
         -- S-LINK LEDs 
         TESTLED_N      => TESTLED_N,
         LDERRLED_N     => LDERRLED_N,
         LUPLED_N       => LUPLED_N,
         FLOWCTLLED_N   => FLOWCTLLED_N,
         ACTIVITYLED_N  => ACTIVITYLED_N,
         -- Reference Clock
         XCLK           => sysClk,
         ICLK2_IN       => ICLK2,
         -- TLK2501 transmit ports
         TXD            => TLK_TXD,
         TX_EN          => TLK_TXEN,
         TX_ER          => TLK_TXER,
         -- TLK2501 transmit ports
         RXD            => TLK_RXD,
         RX_CLK         => sysClk,
         RX_ER          => TLK_RXER,
         RX_DV          => TLK_RXDV); 

   process(sysClk)
   begin
      if rising_edge(sysClk) then
         if sysRst = '1'then
            TLK_RXDV     <= '1' after TPD_C;         
            TLK_RXER     <= '1' after TPD_C;    
            cnt          <= (others => '0') after TPD_C;  
            TLK_RXD      <= (others => '0') after TPD_C;  
         else
            TLK_RXDV     <= '0' after TPD_C;         
            TLK_RXER     <= '0' after TPD_C;          
            cnt <= cnt + 1 after TPD_C;
            if cnt = 7 then
               TLK_RXDV     <= '1' after TPD_C;         
            end if;
         end if;
      end if;
   end process;

end testbed;
