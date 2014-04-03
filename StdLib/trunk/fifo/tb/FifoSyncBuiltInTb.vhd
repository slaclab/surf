-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : FifoSyncBuiltInTb.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-28
-- Last update: 2013-07-29
-- Platform   : ISE 14.5
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2013 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use work.StdRtlPkg.all;

library UNISIM;
use UNISIM.VCOMPONENTS.all;

entity FifoSyncBuiltInTb is end FifoSyncBuiltInTb;

architecture testbed of FifoSyncBuiltInTb is
   constant CLOCK_PERIOD_C : time                         := 10 ns;
   constant XIL_DEVICE_C   : string                       := "7SERIES";
   constant FWFT_EN_C      : boolean                      := true;
   constant DATA_WIDTH_C   : integer                      := 11;
   constant ADDR_WIDTH_C   : integer                      := 10;
   constant MAX_VALUE_C    : slv(DATA_WIDTH_C-1 downto 0) := conv_std_logic_vector((2**DATA_WIDTH_C)-1, DATA_WIDTH_C);
   constant TPD_C          : time                         := 1 ns;
   constant INIT_C         : slv(DATA_WIDTH_C-1 downto 0) := conv_std_logic_vector(1, DATA_WIDTH_C);

   -- Internal signals
   signal clk : sl := '0';

   -- Test signals   
   signal wr_en      : sl;
   signal rd_en      : sl;
   signal din        : slv(DATA_WIDTH_C-1 downto 0) := INIT_C;
   signal dout       : slv(DATA_WIDTH_C-1 downto 0) := INIT_C;
   signal data_count : slv(ADDR_WIDTH_C-1 downto 0) := (others => '0');
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
   signal holdOff     : sl;
   signal holdOffFWFT : sl;
   signal error       : sl;
   signal readDone    : sl;
   signal writeDone   : sl;

   signal readCnt  : slv(DATA_WIDTH_C-1 downto 0) := INIT_C;
   signal writeCnt : slv(DATA_WIDTH_C-1 downto 0) := INIT_C;

   signal srst    : sl := '0';
   signal initRst : sl := '0';
   signal reset   : sl := '0';
begin
--*********************************************************************************--
   ClkRst_Inst : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => CLOCK_PERIOD_C,
         RST_START_DELAY_G => 1 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 0.6 us)   -- Hold reset for this long)
      port map (
         clkP => clk,
         clkN => open,
         rst  => reset,
         rstL => open);

   srst <= reset or initRst;
   process
   begin
      initRst <= '0';
      wait for (200 us);
      wait until (rising_edge(clk));
      initRst <= '1' after TPD_C;
      wait;
   end process;
--*********************************************************************************--   
   FifoSyncBuiltIn_Inst : entity work.FifoSyncBuiltIn
      generic map(
         XIL_DEVICE_G  => XIL_DEVICE_C,
         FWFT_EN_G     => FWFT_EN_C,
         DATA_WIDTH_G  => DATA_WIDTH_C,
         ADDR_WIDTH_G  => ADDR_WIDTH_C,
         FULL_THRES_G  => ((2**ADDR_WIDTH_C)-2),
         EMPTY_THRES_G => 2)
      port map (
         rst          => srst,
         clk          => clk,
         wr_en        => wr_en,
         rd_en        => rd_en,
         din          => din,
         dout         => dout,
         data_count   => data_count,
         wr_ack       => wr_ack,
         valid        => valid,
         overflow     => overflow,
         underflow    => underflow,
         prog_full    => prog_full,
         prog_empty   => prog_empty,
         almost_full  => almost_full,
         almost_empty => almost_empty,
         full         => full,
         empty        => empty);      
--*********************************************************************************--   
   process
   begin
      holdOff <= '1';
      wait for (20 us);
      wait until (rising_edge(clk));
      holdOff <= '0' after TPD_C;
      wait for (7*CLOCK_PERIOD_C);
      holdOff <= '1' after TPD_C;
      wait for (9*CLOCK_PERIOD_C);
      holdOff <= '0' after TPD_C;
      wait for (10*CLOCK_PERIOD_C);
      holdOff <= '1' after TPD_C;
      wait for (11*CLOCK_PERIOD_C);
      holdOff <= '0' after TPD_C;
      wait for (12*CLOCK_PERIOD_C);
      holdOff <= '1' after TPD_C;
      wait for (13*CLOCK_PERIOD_C);
      holdOff <= '0' after TPD_C;
      wait for (14*CLOCK_PERIOD_C);
      holdOff <= '1' after TPD_C;
      wait for (15*CLOCK_PERIOD_C);
      holdOff <= '0' after TPD_C;
      wait;
   end process;

   process
   begin
      holdOffFWFT <= '1';
      wait for (20 us);
      wait until (rising_edge(clk));
      holdOffFWFT <= '0' after TPD_C;
      wait;
   end process;

   FIFO_Gen : if (FWFT_EN_C = false) generate
      WRITE_PATTERN : process(clk, srst)
      begin
         if srst = '1' then
            wr_en     <= '0'    after TPD_C;
            writeCnt  <= INIT_C after TPD_C;
            din       <= INIT_C after TPD_C;
            writeDone <= '0'    after TPD_C;
         elsif rising_edge(clk) then
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

      READ_PATTERN : process(clk, srst)
      begin
         if srst = '1' then
            error    <= '0'    after TPD_C;
            readDone <= '0'    after TPD_C;
            rd_en    <= '0'    after TPD_C;
            readCnt  <= INIT_C after TPD_C;
         elsif rising_edge(clk) then
            rd_en <= '0' after TPD_C;
            if (readDone = '0') and (holdOff = '0')then
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
      WRITE_PATTERN : process(clk, srst)
      begin
         if srst = '1' then
            wr_en     <= '0'    after TPD_C;
            writeCnt  <= INIT_C after TPD_C;
            din       <= INIT_C after TPD_C;
            writeDone <= '0'    after TPD_C;
         elsif rising_edge(clk) then
            wr_en <= '0' after TPD_C;
            if (writeDone = '0') and (holdOff = '0') then
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

      READ_PATTERN : process(clk, srst)
      begin
         if srst = '1' then
            error    <= '0'    after TPD_C;
            readDone <= '0'    after TPD_C;
            readCnt  <= INIT_C after TPD_C;
         elsif rising_edge(clk) then
            if valid = '1' and holdOffFWFT = '0' then
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
