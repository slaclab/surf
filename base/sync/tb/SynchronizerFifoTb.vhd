-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for the SynchronizerFifo module
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


library surf;
use surf.StdRtlPkg.all;

entity SynchronizerFifoTb is end SynchronizerFifoTb;

architecture testbed of SynchronizerFifoTb is
   type TestClkType is array(4 downto 0) of time;
   constant WRITE_CLK_ARRAY_C : TestClkType := (
      5 ns,
      20 ns,
      10 ns,
      10 ns,
      3.1415926535897932384626433832795 ns);
   constant READ_CLK_ARRAY_C : TestClkType := (
      20 ns,
      5 ns,
      10 ns,
      3.1415926535897932384626433832795 ns,
      10 ns);
   constant CLK_SEL_C    : integer := 2;  --change this parameter for simulating different clock configurations
   constant WRITE_CLK_C  : time    := WRITE_CLK_ARRAY_C(CLK_SEL_C);
   constant READ_CLK_C   : time    := READ_CLK_ARRAY_C(CLK_SEL_C);
   constant MEMORY_TYPE_G: string  := "block";
   constant FWFT_EN_C    : boolean := true;
   constant DATA_WIDTH_C : integer := 8;
   constant ADDR_WIDTH_C : integer := 2;
   constant TPD_C        : time    := 1 ns;

   constant MAX_VALUE_C : slv(DATA_WIDTH_C-1 downto 0) := conv_std_logic_vector((2**8)-1, DATA_WIDTH_C);


   -- Internal signals
   signal wr_clk : sl := '0';
   signal rd_clk : sl := '0';

   -- Test signals   
   signal wr_en : sl;
   signal rd_en : sl;

   signal din  : slv(DATA_WIDTH_C-1 downto 0) := (others => '0');
   signal dout : slv(DATA_WIDTH_C-1 downto 0) := (others => '0');

   signal wr_data_count : slv(ADDR_WIDTH_C-1 downto 0) := (others => '0');
   signal rd_data_count : slv(ADDR_WIDTH_C-1 downto 0) := (others => '0');

   signal valid : sl;

   signal error     : sl;
   signal readDone  : sl;
   signal writeDone : sl;

   signal readCnt  : slv(DATA_WIDTH_C-1 downto 0) := (others => '0');
   signal writeCnt : slv(DATA_WIDTH_C-1 downto 0) := (others => '0');

   signal rst     : sl := '0';
   signal initRst : sl := '0';
   signal reset   : sl := '0';
begin
--*********************************************************************************--
   WR_CLK_Inst : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => WRITE_CLK_C,
         RST_START_DELAY_G => 1 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 0.6 us)   -- Hold reset for this long)
      port map (
         clkP => wr_clk,
         clkN => open,
         rst  => reset,
         rstL => open);

   RD_CLK_Inst : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => READ_CLK_C,
         RST_START_DELAY_G => 1 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 0.6 us)   -- Hold reset for this long)
      port map (
         clkP => rd_clk,
         clkN => open,
         rst  => open,
         rstL => open);

   rst <= reset or initRst;
   process
   begin
      initRst <= '0';
      wait for (15 us);
      wait until (rising_edge(wr_clk));
      initRst <= '1' after TPD_C;
      wait;
   end process;

--*********************************************************************************--   
   SynchronizerFifo_Inst : entity surf.SynchronizerFifo
      generic map(
         DATA_WIDTH_G => DATA_WIDTH_C,
         ADDR_WIDTH_G => ADDR_WIDTH_C)
      port map (
         rst    => rst,
         wr_clk => wr_clk,
         din    => din,
         rd_clk => rd_clk,
         valid  => valid,
         dout   => dout);        
--*********************************************************************************--   
   WRITE_PATTERN : process(rst, wr_clk)
   begin
      if rst = '1' then
         wr_en     <= '0'             after TPD_C;
         writeCnt  <= (others => '0') after TPD_C;
         din       <= (others => '0') after TPD_C;
         writeDone <= '0'             after TPD_C;
      elsif rising_edge(wr_clk) then
         wr_en <= '0' after TPD_C;
         if (writeDone = '0') then
            din   <= writeCnt after TPD_C;
            wr_en <= '1'      after TPD_C;
            if writeCnt = MAX_VALUE_C then
               writeDone <= '1' after TPD_C;
            else
               writeCnt <= writeCnt + 1 after TPD_C;
            end if;
         end if;
      end if;
   end process WRITE_PATTERN;

   READ_PATTERN : process(rd_clk, rst)
   begin
      if rst = '1' then
         error    <= '0'             after TPD_C;
         readDone <= '0'             after TPD_C;
         rd_en    <= '0'             after TPD_C;
         readCnt  <= (others => '0') after TPD_C;
      elsif rising_edge(rd_clk) then
         if valid = '1' then
            --check for an error
            if readCnt /= dout then
               error <= '1' after TPD_C;
            end if;
            --check if transfer is completed
            if dout = MAX_VALUE_C then
               readDone <= '1' after TPD_C;
            end if;
            --check if last cycle was external polled from FIFO
            if rd_en = '1' then
               readCnt <= readCnt + 1 after TPD_C;
            end if;
            --set the read enable signal
            rd_en <= '1' after TPD_C;
         else
            rd_en <= '0' after TPD_C;
         end if;
      end if;
   end process READ_PATTERN;

end testbed;
