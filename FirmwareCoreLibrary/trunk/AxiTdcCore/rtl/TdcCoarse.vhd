-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : TdcCoarse.vhd
-- Author     : Kurtis Nishimura  <kurtisn@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-07-21
-- Last update: 2014-07-21
-- Platform   : Vivado 2014.1
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Basic coarse TDC element using counter.
--              Least count is determined by the clock frequency.
--              Valid is pulsed when output data is updated.
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.StdRtlPkg.all;

entity TdcCoarse is
   Generic (
      TPD_G        : time := 1 ns;
      TDC_WIDTH_G  : integer := 16
   );
   Port (
      -- Clock and registered data
      -- This clock is used to run the counter.
      clk         : in  sl;
      sRst        : in  sl;
      coarseOut   : out slv(TDC_WIDTH_G-1 downto 0);
      coarseValid : out sl;
      -- Asynchronous start and stop (must be > 1 clk period)
      start       : in  sl;
      stop        : in  sl
   );
end TdcCoarse;

architecture Behavioral of TdcCoarse is

   signal startSync : sl;
   signal stopSync  : sl;

   type StateType is (IDLE_S, STARTED_S, STOPPED_S);

   type RegType is record
      output         : slv(TDC_WIDTH_G-1 downto 0);
      valid          : sl;
      runningCnt     : slv(TDC_WIDTH_G-1 downto 0);
      state          : StateType;
   end record;
   constant REG_INIT_C : RegType := (
      (others => '0'),
      '0',
      (others => '0'),
      IDLE_S
   ); 
   
   constant OVERFLOW_C : slv(TDC_WIDTH_G-1 downto 0) := (others => '1');
   
   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (sRst, startSync, stopSync, r) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset any pulsed signals
      v.valid := '0';
      
      case (r.state) is
         when IDLE_S =>
            v.runningCnt := (others => '0');
            -- Start and stop simultaneously should give 
            -- us underflow (0), as should stop before start.
            if stopSync = '1' then
               v.output := (others => '0');
               v.valid  := '1';
            -- Otherwise, we see start first, and should 
            -- begin counting.
            elsif startSync = '1' then
               v.runningCnt := r.runningCnt + 1;
               v.state      := STARTED_S;
            end if;
         when STARTED_S =>
            -- Repeated start gives overflow
            if (startSync = '1') then
               v.runningCnt := (others => '1');
            -- Otherwise, count up to max
            elsif (v.runningCnt < OVERFLOW_C) then
               v.runningCnt := r.runningCnt + 1;
            end if;
            -- Overflow, stop, or repeated start
            -- should end our counting.
            if stopSync = '1' or startSync = '1' or r.runningCnt = OVERFLOW_C then
               v.state   := STOPPED_S;
            end if;
         when STOPPED_S =>
            v.output   := r.runningCnt;
            v.valid    := '1';
            v.state    := IDLE_S;
         when others =>
            v.state := IDLE_S;
      end case;
      
      -- Synchronous Reset
      if sRst = '1' then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      coarseOut <= r.output;
      
   end process comb;
   
   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   
   -- Edge detectors for start and stop
   U_StartEdge : entity work.SynchronizerEdge
      generic map (
         TPD_G => TPD_G
      )
      port map (
         clk        => clk,
         rst        => sRst,
         dataIn     => start,
         risingEdge => startSync
      );
   U_StopEdge : entity work.SynchronizerEdge
      generic map (
         TPD_G => TPD_G
      )
      port map (
         clk        => clk,
         rst        => sRst,
         dataIn     => stop,
         risingEdge => stopSync
      );
      
end Behavioral;
