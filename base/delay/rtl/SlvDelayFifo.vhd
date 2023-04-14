-------------------------------------------------------------------------------
-- Title      : FIFO-Based Delay Block
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Delays a logic vector by writing entries into a FIFO, and
-- reading them some number of cycles later. The delay is determined by the
-- delay input.
--
-- Note that the underlying FIFO has a minimum delay of 4 cycles, so a delay
-- of less than 4 is not possible.
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library".
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

entity SlvDelayFifo is
   generic (
      TPD_G              : time     := 1 ns;
      RST_ASYNC_G        : boolean  := false;
      DATA_WIDTH_G       : positive := 1;
      DELAY_BITS_G       : positive := 64;
      FIFO_ADDR_WIDTH_G  : positive := 7;
      FIFO_MEMORY_TYPE_G : string   := "block");
   port (
      -- Clock and Reset
      clk         : in  sl;
      rst         : in  sl;
      -- Configuration Interface
      delay       : in  slv(DELAY_BITS_G-1 downto 0);
      -- Input Interface
      inputData   : in  slv(DATA_WIDTH_G-1 downto 0);
      inputValid  : in  sl;
      inputAFull  : out sl;             -- FIFO almost full
      -- Output Interface
      outputData  : out slv(DATA_WIDTH_G-1 downto 0);
      outputValid : out sl);
end SlvDelayFifo;

architecture rtl of SlvDelayFifo is

   constant FIFO_MIN_LAT_C : positive := 4;  -- FIFO's minimum latency
   constant FIFO_WIDTH_C   : natural  := DELAY_BITS_G + DATA_WIDTH_G;

   subtype DATA_FIELD_C is natural range DATA_WIDTH_G-1 downto 0;
   subtype DELAY_FIELD_C is natural range (DELAY_BITS_G+DATA_WIDTH_G)-1 downto DATA_WIDTH_G;

   type RegType is record
      timeNow     : slv(DELAY_BITS_G-1 downto 0);
      readoutTime : slv(DELAY_BITS_G-1 downto 0);
      fifoRdEn    : sl;
      outputData  : slv(DATA_WIDTH_G-1 downto 0);
      outputValid : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      timeNow     => (others => '0'),
      readoutTime => (others => '0'),
      fifoRdEn    => '0',
      outputData  => (others => '0'),
      outputValid => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal fifoReadoutTime : slv(DELAY_BITS_G-1 downto 0);
   signal fifoReadoutData : slv(DATA_WIDTH_G-1 downto 0);
   signal fifoValid       : sl;
   signal fifoRdEn        : sl;
   signal fifoDin         : slv(FIFO_WIDTH_C-1 downto 0);
   signal fifoDout        : slv(FIFO_WIDTH_C-1 downto 0);

begin

   assert (DELAY_BITS_G >= log2(FIFO_MIN_LAT_C))
      report "DELAY_BITS_G must be >= log2(FIFO_MIN_LAT_C)"
      severity failure;

   U_DelayFifo : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_ASYNC_G     => RST_ASYNC_G,
         GEN_SYNC_FIFO_G => true,
         MEMORY_TYPE_G   => FIFO_MEMORY_TYPE_G,
         FWFT_EN_G       => true,
         DATA_WIDTH_G    => FIFO_WIDTH_C,
         ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_G)
      port map (
         rst         => rst,
         -- Write Ports
         wr_clk      => clk,
         wr_en       => inputValid,
         almost_full => inputAFull,
         din         => fifoDin,
         -- Read Ports
         rd_clk      => clk,
         rd_en       => fifoRdEn,
         dout        => fifoDout,
         valid       => fifoValid);

   fifoDin(DATA_FIELD_C)  <= inputData;
   fifoDin(DELAY_FIELD_C) <= r.readoutTime;

   fifoReadoutData <= fifoDout(DATA_FIELD_C);
   fifoReadoutTime <= fifoDout(DELAY_FIELD_C);

   comb : process (delay, fifoReadoutData, fifoReadoutTime, fifoValid, r, rst) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Increment the local timestamp
      v.timeNow := r.timeNow + 1;

      -- Check delay configuration less than FIFO's minimum latency
      if (delay < FIFO_MIN_LAT_C) then
         -- Enforce minimum delay
         v.readoutTime := r.timeNow + FIFO_MIN_LAT_C;
      else
         -- Calculate the readout time
         v.readoutTime := r.timeNow + delay;
      end if;

      -- Reset Strobes
      v.fifoRdEn    := '0';
      v.outputValid := '0';

      -- Register the FIFO output
      v.outputData := fifoReadoutData;

      -- Check for Data
      if (fifoValid = '1') then
         -- Check if readout time equals current time
         if (fifoReadoutTime = r.timeNow) then
            -- Read the FIFO
            v.fifoRdEn    := '1';
            -- Set the output valid flag
            v.outputValid := '1';
         end if;
      end if;

      -- Outputs
      fifoRdEn    <= v.fifoRdEn;        -- combinatorial output
      outputData  <= r.outputData;
      outputValid <= r.outputValid;

      -- Reset
      if (RST_ASYNC_G = false and rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (clk, rst) is
   begin
      if (RST_ASYNC_G and rst = '1') then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
