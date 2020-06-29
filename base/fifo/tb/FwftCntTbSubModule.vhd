-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation sub module for testing the FwftCntTb
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;

entity FwftCntTbSubModule is
   generic (
      TPD_G           : time    := 1 ns;
      GEN_SYNC_FIFO_G : boolean := false;
      SYNTH_MODE_G    : string  := "inferred";
      MEMORY_TYPE_G   : string  := "block");
   port (
      clk    : in  sl;
      rst    : in  sl;
      passed : out sl := '0';
      failed : out sl := '0');
end FwftCntTbSubModule;

architecture rtl of FwftCntTbSubModule is

   constant ADDR_WIDTH_C : positive := ite(MEMORY_TYPE_G = "distributed", 5, 9);
   constant DATA_WIDTH_C : positive := ADDR_WIDTH_C+1;

   type StateType is (
      IDLE_S,
      WRITE_S,
      WR_WAIT_S,
      READ_S,
      RD_WAIT_S,
      FAILED_S,
      PASSED_S);

   type RegType is record
      passed : sl;
      failed : sl;
      wr_en  : sl;
      din    : slv(DATA_WIDTH_C-1 downto 0);
      rd_en  : sl;
      state  : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      passed => '0',
      failed => '0',
      wr_en  => '0',
      din    => (others => '0'),
      rd_en  => '0',
      state  => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- Write Ports (wr_clk domain)
   signal wr_en         : sl                           := '0';
   signal din           : slv(DATA_WIDTH_C-1 downto 0) := (others => '0');
   signal wr_data_count : slv(ADDR_WIDTH_C-1 downto 0) := (others => '0');
   signal wr_ack        : sl                           := '0';
   signal overflow      : sl                           := '0';
   signal prog_full     : sl                           := '0';
   signal almost_full   : sl                           := '0';
   signal full          : sl                           := '0';
   signal not_full      : sl                           := '0';

   -- Read Ports (rd_clk domain)
   signal rd_en         : sl                           := '0';
   signal dout          : slv(DATA_WIDTH_C-1 downto 0) := (others => '0');
   signal rd_data_count : slv(ADDR_WIDTH_C-1 downto 0) := (others => '0');
   signal valid         : sl                           := '0';
   signal underflow     : sl                           := '0';
   signal prog_empty    : sl                           := '0';
   signal almost_empty  : sl                           := '0';
   signal empty         : sl                           := '0';

begin

   -----------------------
   -- Module to be tested
   -----------------------
   U_Fifo : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         FWFT_EN_G       => true,
         GEN_SYNC_FIFO_G => GEN_SYNC_FIFO_G,
         SYNTH_MODE_G    => SYNTH_MODE_G,
         MEMORY_TYPE_G   => MEMORY_TYPE_G,
         DATA_WIDTH_G    => DATA_WIDTH_C,
         ADDR_WIDTH_G    => ADDR_WIDTH_C)
      port map (
         -- Asynchronous Reset
         rst           => rst,
         -- Write Ports (wr_clk domain)
         wr_clk        => clk,
         wr_en         => wr_en,
         din           => din,
         wr_data_count => wr_data_count,
         wr_ack        => wr_ack,
         overflow      => overflow,
         prog_full     => prog_full,
         almost_full   => almost_full,
         full          => full,
         not_full      => not_full,
         -- Read Ports (rd_clk domain)
         rd_clk        => clk,
         rd_en         => rd_en,
         dout          => dout,
         rd_data_count => rd_data_count,
         valid         => valid,
         underflow     => underflow,
         prog_empty    => prog_empty,
         almost_empty  => almost_empty,
         empty         => empty);

   comb : process (dout, full, overflow, r, rd_data_count, rst, underflow,
                   valid, wr_data_count) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      v.wr_en := '0';
      v.rd_en := '0';

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Wait for FIFO to be ready for writes
            if (full = '0') then
               -- Next state
               v.state := WRITE_S;
            end if;
         ----------------------------------------------------------------------
         when WRITE_S =>
            -- Write to the FIFO
            v.wr_en := '1';
            v.din   := r.din + 1;
            -- Check for last write
            if (v.din = 2**ADDR_WIDTH_C) then
               -- Next state
               v.state := WR_WAIT_S;
            end if;
         ----------------------------------------------------------------------
         when WR_WAIT_S =>
            -- Allow for settling time
            v.din := r.din + 1;
            -- Check for counter roll over
            if (v.din = 0) then
               -- Check for FIFO count error
               if (wr_data_count /= 2**ADDR_WIDTH_C-1) or (rd_data_count /= 2**ADDR_WIDTH_C-1) then
                  -- Next state
                  v.state := FAILED_S;
               else
                  -- Next state
                  v.state := READ_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when READ_S =>
            -- Check for data to read
            if (valid = '1') then
               -- Write to the FIFO
               v.rd_en := '1';
               v.din   := r.din + 1;
               -- Check for last write
               if (v.din = 2**ADDR_WIDTH_C) then
                  -- Next state
                  v.state := RD_WAIT_S;
               end if;
               -- Check for data error
               if (v.din /= dout) then
                  -- Next state
                  v.state := FAILED_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when RD_WAIT_S =>
            -- Allow for settling time
            v.din := r.din + 1;
            -- Check for counter roll over
            if (v.din = 0) then
               -- Check for FIFO count error
               if (wr_data_count /= 0) or (rd_data_count /= 0) then
                  -- Next state
                  v.state := FAILED_S;
               else
                  -- Next state
                  v.state := PASSED_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when FAILED_S =>
            v.failed := '1';
         ----------------------------------------------------------------------
         when PASSED_S =>
            v.passed := '1';
      ----------------------------------------------------------------------
      end case;

      -- Check for FIFO errors
      if (overflow = '1') or (underflow = '1') then
         -- Next state
         v.state := FAILED_S;
      end if;

      -- Outputs
      rd_en  <= v.rd_en;
      wr_en  <= r.wr_en;
      din    <= r.din;
      passed <= r.passed;
      failed <= r.failed;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
