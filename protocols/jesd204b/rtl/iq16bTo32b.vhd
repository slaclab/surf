-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Converts the 16-bit I/Q data to 32-bit I/Q data
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

entity iq16bTo32b is
   generic (
      TPD_G         : time                 := 1 ns;
      SYNTH_MODE_G  : string               := "inferred";
      SYNC_STAGES_G : natural range 2 to 8 := 3);
   port (
      -- 16-bit Write Interface
      wrClk     : in  sl;
      wrRst     : in  sl;
      validIn   : in  sl;
      overflow  : out sl;
      dataInI   : in  slv(15 downto 0);
      dataInQ   : in  slv(15 downto 0);
      -- 32-bit Read Interface
      rdClk     : in  sl;
      rdRst     : in  sl;
      validOut  : out sl;
      underflow : out sl;
      dataOutI  : out slv(31 downto 0);
      dataOutQ  : out slv(31 downto 0));
end iq16bTo32b;

architecture rtl of iq16bTo32b is

   type RegType is record
      wordSel : sl;
      wrEn    : sl;
      dataI   : slv(31 downto 0);
      dataQ   : slv(31 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      wordSel => '0',
      wrEn    => '0',
      dataI   => (others => '0'),
      dataQ   => (others => '0'));

   signal r       : RegType := REG_INIT_C;
   signal rin     : RegType;
   signal s_valid : sl;


   -- attribute dont_touch      : string;
   -- attribute dont_touch of r : signal is "TRUE";

begin

   comb : process (dataInI, dataInQ, r, validIn, wrRst) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Check if data valid
      if validIn = '1' then
         if r.wordSel = '0' then
            -- Set the flags and data bus
            v.wordSel            := '1';
            v.dataI(15 downto 0) := dataInI;
            v.dataQ(15 downto 0) := dataInQ;
            v.wrEn               := '0';
         else
            -- Set the flags and data bus
            v.wordSel             := '0';
            v.dataI(31 downto 16) := dataInI;
            v.dataQ(31 downto 16) := dataInQ;
            v.wrEn                := '1';
         end if;
      else
         v := REG_INIT_C;
      end if;

      -- Synchronous Reset
      if (wrRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   U_FIFO : entity surf.Fifo
      generic map (
         TPD_G         => TPD_G,
         SYNTH_MODE_G  => SYNTH_MODE_G,
         MEMORY_TYPE_G => "distributed",
         FWFT_EN_G     => true,
         SYNC_STAGES_G => SYNC_STAGES_G,
         DATA_WIDTH_G  => 64,
         ADDR_WIDTH_G  => 5)
      port map (
         -- Asynchronous Reset
         rst                => wrRst,
         -- Write Ports (wr_clk domain)
         wr_clk             => wrClk,
         wr_en              => r.wrEn,
         din(63 downto 32)  => r.dataI,
         din(31 downto 0)   => r.dataQ,
         overflow           => overflow,
         -- Read Ports (rd_clk domain)
         rd_clk             => rdClk,
         rd_en              => s_valid,
         dout(63 downto 32) => dataOutI,
         dout(31 downto 0)  => dataOutQ,
         underflow          => underflow,
         valid              => s_valid);

   validOut <= s_valid;

   seq : process (wrClk) is
   begin
      if (rising_edge(wrClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
