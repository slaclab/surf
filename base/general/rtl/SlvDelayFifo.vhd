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
      -- General Configurations
      TPD_G              : time                        := 1 ns;
      DATA_WIDTH_G       : positive                    := 1;
      DELAY_BITS_G       : positive                    := 64;
      FIFO_ADDR_WIDTH_G  : positive range 1 to (2**24) := 7;
      FIFO_MEMORY_TYPE_G : string                      := "block");

   port (
      -- Timing Msg interface
      clk         : in  sl;
      rst         : in  sl;
      delay       : in  slv(DELAY_BITS_G-1 downto 0);
      inputData   : in  slv(DATA_WIDTH_G-1 downto 0);
      inputValid  : in  sl;
      outputData  : out slv(DATA_WIDTH_G-1 downto 0);
      outputValid : out sl);

end SlvDelayFifo;

architecture rtl of SlvDelayFifo is

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

begin

   Fifo_Time : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         GEN_SYNC_FIFO_G => true,
         MEMORY_TYPE_G   => FIFO_MEMORY_TYPE_G,
         FWFT_EN_G       => true,
         DATA_WIDTH_G    => DELAY_BITS_G,
         ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_G)
      port map (
         rst    => rst,
         wr_clk => clk,
         wr_en  => inputValid,
         din    => r.readoutTime,
         rd_clk => clk,
         rd_en  => r.fifoRdEn,
         dout   => fifoReadoutTime,
         valid  => fifoValid);

   Fifo_Data : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         GEN_SYNC_FIFO_G => true,
         MEMORY_TYPE_G   => FIFO_MEMORY_TYPE_G,
         FWFT_EN_G       => true,
         DATA_WIDTH_G    => DATA_WIDTH_G,
         ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_G)
      port map (
         rst    => rst,
         wr_clk => clk,
         wr_en  => inputValid,
         din    => inputData,
         rd_clk => clk,
         rd_en  => r.fifoRdEn,
         dout   => fifoReadoutData,
         valid  => open);

   comb : process (delay, fifoReadoutData, fifoReadoutTime, fifoValid, r, rst) is
      variable v : RegType;
   begin
      v := r;

      v.timeNow     := r.timeNow + 1;
      v.readoutTime := r.timeNow + delay;

      v.fifoRdEn    := '0';
      v.outputValid := '0';
      v.outputData  := fifoReadoutData;

      if (fifoValid = '1' and r.fifoRdEn = '0') then
         if (fifoReadoutTime <= r.timeNow) then
            v.fifoRdEn    := '1';
            v.outputValid := '1';
         end if;
      end if;

      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      outputData  <= r.outputData;
      outputValid <= r.outputValid;

   end process comb;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
