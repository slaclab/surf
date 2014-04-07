-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Vc64FifoTb.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-07
-- Last update: 2014-04-07
-- Platform   : Vivado 2013.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the Vc64FifoTb module
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.Vc64Pkg.all;

entity Vc64FifoTb is end Vc64FifoTb;

architecture testbed of Vc64FifoTb is

   -- Constants
   constant WR_CLK_PERIOD_C : time := 10 ns;
   constant RD_CLK_PERIOD_C : time := 3.14 ns;  -- Test parameter
   constant TPD_C           : time := 1 ns;

   constant GEN_SYNC_FIFO_C : boolean := true;  -- Test parameter
   constant BYPASS_FIFO_C   : boolean := true;  -- Test parameter

   constant PIPE_STAGES_C : integer := 2;  -- Test parameter

   constant LAST_DATA_C       : slv(63 downto 0) := toSlv(4096, 64);  -- Test parameter
   constant READ_BUSY_THRES_C : slv(3 downto 0)  := toSlv(7, 4);      -- Test parameter

   -- Signals
   signal wrDone,
      rdDone,
      rdError,
      vcWrClk,
      vcWrRst,
      clk,
      rst,
      vcRdClk,
      vcRdRst : sl;
   signal vcWrIn  : Vc64DataType := VC64_DATA_INIT_C;
   signal vcWrOut : Vc64CtrlType;
   signal vcRdIn  : Vc64CtrlType;
   signal vcRdOut : Vc64DataType;
   signal rdCnt   : slv(3 downto 0);
   signal rdData  : slv(63 downto 0);

begin

   -- Generate clocks and resets
   ClkRst_Write : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => WR_CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,     -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 500 ns)   -- Hold reset for this long)
      port map (
         clkP => vcWrClk,
         clkN => open,
         rst  => vcWrRst,
         rstL => open); 

   ClkRst_Read : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => RD_CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,     -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 500 ns)   -- Hold reset for this long)
      port map (
         clkP => clk,
         clkN => open,
         rst  => rst,
         rstL => open); 

   vcRdClk <= vcWrClk when(GEN_SYNC_FIFO_C = true) else clk;
   vcRdRst <= vcWrRst when(GEN_SYNC_FIFO_C = true) else rst;

   -- SynchronizerOneShot (VHDL module to be tested)
   Vc64Fifo_Inst : entity work.Vc64Fifo
      generic map (
         TPD_G           => TPD_C,
         GEN_SYNC_FIFO_G => GEN_SYNC_FIFO_C,
         BYPASS_FIFO_G   => BYPASS_FIFO_C,
         PIPE_STAGES_G   => PIPE_STAGES_C)
      port map (
         -- Streaming Write Data Interface (vcWrClk domain)
         vcWrIn  => vcWrIn,
         vcWrOut => vcWrOut,
         -- Streaming Read Data Interface (vcRdClk domain)
         vcRdIn  => vcRdIn,
         vcRdOut => vcRdOut,
         -- Clocks and resets
         vcWrClk => vcWrClk,
         vcWrRst => vcWrRst,
         vcRdClk => vcRdClk,
         vcRdRst => vcRdRst);       

   -- Transmit the data pattern into the FIFO
   process(vcWrClk)
   begin
      if rising_edge(vcWrClk) then
         vcWrIn.valid <= '0' after TPD_C;
         if vcWrRst = '1' then
            wrDone      <= '0'             after TPD_C;
            vcWrIn.data <= (others => '1') after TPD_C;
         elsif (vcWrIn.data /= LAST_DATA_C) and (vcWrOut.almostFull = '0') then
            -- Increment the counter
            vcWrIn.data  <= vcWrIn.data + 1 after TPD_C;
            -- Write the value to the FIFO
            vcWrIn.valid <= '1'             after TPD_C;
         elsif vcWrIn.data = LAST_DATA_C then
            wrDone <= '1' after TPD_C;
         end if;
      end if;
   end process;

   -- Receive the data pattern into the FIFO and check if it is valid
   process(vcRdClk)
   begin
      if rising_edge(vcRdClk) then
         vcRdIn.ready <= '0' after TPD_C;
         if vcRdRst = '1' then
            rdDone  <= '0'              after TPD_C;
            rdError <= '0'              after TPD_C;
            rdCnt   <= (others => '0')  after TPD_C;
            rdData  <= (others => '0')  after TPD_C;
            vcRdIn  <= VC64_CTRL_INIT_C after TPD_C;
         else
            -- increment a counter
            rdCnt <= rdCnt + 1 after TPD_C;
            if rdCnt < READ_BUSY_THRES_C then
               -- Ready to read the FIFO
               vcRdIn.ready <= '1' after TPD_C;
            end if;
            -- Check if we were reading the FIFO
            if (vcRdIn.ready = '1') and (vcRdOut.valid = '1') then
               -- Check for an error in the data
               if vcRdOut.data /= rdData then
                  -- Error detected
                  rdError <= '1' after TPD_C;
               end if;
               -- Check for roll over
               if rdData /= LAST_DATA_C then
                  -- increment the counter
                  rdData <= rdData + 1 after TPD_C;
               end if;
            elsif rdData = LAST_DATA_C then
               rdDone <= '1' after TPD_C;
            end if;
         end if;
      end if;
   end process;

end testbed;
