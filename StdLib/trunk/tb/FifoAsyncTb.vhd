-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : FifoAsyncTb.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-11
-- Last update: 2013-09-19
-- Platform   : ISE 14.5
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2013 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;

entity FifoAsyncTb is end FifoAsyncTb;

architecture testbed of FifoAsyncTb is
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
   constant BRAM_EN_C    : boolean := true;
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

   signal wr_ack,
      valid,
      overflow,
      underflow,
      prog_full,
      prog_empty,
      almost_full,
      almost_empty,
      full,
      empty : sl;
   
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
   WR_CLK_Inst : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => WRITE_CLK_C,
         RST_START_DELAY_G => 1 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 0.6 us)   -- Hold reset for this long)
      port map (
         clkP => wr_clk,
         clkN => open,
         rst  => reset,
         rstL => open);

   RD_CLK_Inst : entity work.ClkRst
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
   FifoAsync_Inst : entity work.FifoAsync
      generic map(
         BRAM_EN_G     => BRAM_EN_C,
         FWFT_EN_G     => FWFT_EN_C,
         DATA_WIDTH_G  => DATA_WIDTH_C,
         ADDR_WIDTH_G  => ADDR_WIDTH_C,
         FULL_THRES_G  => ((2**ADDR_WIDTH_C)-2),
         EMPTY_THRES_G => 2)
      port map (
         rst           => rst,
         wr_clk        => wr_clk,
         wr_en         => wr_en,
         din           => din,
         wr_data_count => wr_data_count,
         wr_ack        => wr_ack,
         overflow      => overflow,
         prog_full     => prog_full,
         almost_full   => almost_full,
         full          => full,
         rd_clk        => rd_clk,
         rd_en         => rd_en,
         dout          => dout,
         rd_data_count => rd_data_count,
         valid         => valid,
         underflow     => underflow,
         prog_empty    => prog_empty,
         almost_empty  => almost_empty,
         empty         => empty);         
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
            if almost_full = '0' then
               din   <= writeCnt after TPD_C;
               wr_en <= '1'      after TPD_C;
               if writeCnt = MAX_VALUE_C then
                  writeDone <= '1' after TPD_C;
               end if;
               writeCnt <= writeCnt + 1 after TPD_C;
            end if;
         end if;
      end if;
   end process WRITE_PATTERN;

   FIFO_Gen : if (FWFT_EN_C = false) generate
      READ_PATTERN : process(rd_clk, rst)
      begin
         if rst = '1' then
            error    <= '0'             after TPD_C;
            readDone <= '0'             after TPD_C;
            rd_en    <= '0'             after TPD_C;
            readCnt  <= (others => '0') after TPD_C;
         elsif rising_edge(rd_clk) then
            rd_en <= '0' after TPD_C;
            if (readDone = '0') then
               if empty = '0' then
                  rd_en <= '1' after TPD_C;
               end if;
            end if;
            if valid = '1' then
               if readCnt /= dout then
                  error <= '1' after TPD_C;
               end if;
               if dout = MAX_VALUE_C then
                  readDone <= '1' after TPD_C;
               end if;
               readCnt <= readCnt + 1 after TPD_C;
            end if;
         end if;
      end process READ_PATTERN;
   end generate;

   FWFT_Gen : if (FWFT_EN_C = true) generate
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
   end generate;
   
end testbed;
