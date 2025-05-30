-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation sub module for testing the FifoFwft modules
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

entity FifoTbSubModule is
   generic (
      TPD_G           : time                  := 1 ns;
      GEN_SYNC_FIFO_G : boolean               := false;
      MEMORY_TYPE_G   : string                := "block";
      PIPE_STAGES_G   : natural range 0 to 16 := 0);
   port (
      rst    : in  sl;
      wrClk  : in  sl;
      rdClk  : in  sl;
      passed : out sl := '0';
      failed : out sl := '0');
end FifoTbSubModule;

architecture mapping of FifoTbSubModule is

   signal wrEn      : sl := '0';
   signal aFull     : sl := '0';
   signal valid     : sl := '0';
   signal rdEn      : sl := '0';
   signal passedDet : sl := '0';
   signal failedDet : sl := '0';
   signal ready     : sl := '0';

   signal readDelay  : slv(4 downto 0) := (others => '0');
   signal writeDelay : slv(4 downto 0) := (others => '0');

   signal din   : slv(15 downto 0) := (others => '0');
   signal dout  : slv(15 downto 0) := (others => '0');
   signal check : slv(15 downto 0) := (others => '0');

begin

   process(wrClk)
   begin
      if rising_edge(wrClk) then
         wrEn <= '0' after TPD_G;
         if rst = '1' then
            din        <= (others => '1') after TPD_G;
            writeDelay <= (others => '0') after TPD_G;
         else

            writeDelay    <= writeDelay + 1 after TPD_G;
            if writeDelay <= 3 then
               if aFull = '0' then
                  wrEn <= '1'     after TPD_G;
                  din  <= din + 1 after TPD_G;
               end if;
            end if;
         end if;
      end if;
   end process;

   Fifo_Inst : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         GEN_SYNC_FIFO_G => GEN_SYNC_FIFO_G,
         MEMORY_TYPE_G   => MEMORY_TYPE_G,
         PIPE_STAGES_G   => PIPE_STAGES_G,
         FWFT_EN_G       => true,
         DATA_WIDTH_G    => 16,
         ADDR_WIDTH_G    => 10)
      port map (
         -- Resets
         rst         => rst,
         --Write Ports (wr_clk domain)
         wr_clk      => wrClk,
         wr_en       => wrEn,
         din         => din,
         almost_full => aFull,
         --Read Ports (rd_clk domain)
         rd_clk      => rdClk,
         rd_en       => rdEn,
         dout        => dout,
         valid       => valid);

   rdEn <= valid and ready;

   process(rdClk)
   begin
      if rising_edge(rdClk) then
         passed <= passedDet after TPD_G;
         failed <= failedDet after TPD_G;
         ready  <= '0'       after TPD_G;
         if rst = '1' then
            check     <= (others => '0') after TPD_G;
            readDelay <= (others => '0') after TPD_G;
         else
            readDelay                           <= readDelay + 1 after TPD_G;
            if (readDelay >= 16) and (readDelay <= 26) then
               ready <= '1' after TPD_G;
            end if;
            if rdEn = '1' then
               check <= check + 1 after TPD_G;
               if dout /= check then
                  failedDet <= '1' after TPD_G;
               end if;
               if check = 1024 then
                  passedDet <= '1' after TPD_G;
               end if;
            end if;
         end if;
      end if;
   end process;


end mapping;
