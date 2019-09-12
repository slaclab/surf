-------------------------------------------------------------------------------
-- File       : SyncMinMax.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: General Purpose Max/Min monitor and synchronizer
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

use work.StdRtlPkg.all;

entity SyncMinMax is
   generic (
      TPD_G        : time     := 1 ns;
      COMMON_CLK_G : boolean  := false;
      WIDTH_G      : positive := 16);
   port (
      -- Write Interface (wrClk domain)
      wrClk   : in  sl;
      wrRst   : in  sl := '0';
      wrEn    : in  sl := '1';
      dataIn  : in  slv(WIDTH_G-1 downto 0);
      -- Read Interface (rdClk domain)
      rdClk   : in  sl;
      rdEn    : in  sl := '1';
      rstStat : in  sl;
      updated : out sl;
      dataOut : out slv(WIDTH_G-1 downto 0);
      dataMin : out slv(WIDTH_G-1 downto 0);
      dataMax : out slv(WIDTH_G-1 downto 0));
end SyncMinMax;

architecture rtl of SyncMinMax is

   type RegType is record
      update  : sl;
      dataIn  : slv(WIDTH_G-1 downto 0);
      dataMin : slv(WIDTH_G-1 downto 0);
      dataMax : slv(WIDTH_G-1 downto 0);
   end record RegType;
   constant REG_INIT_C : RegType := (
      update  => '1',
      dataIn  => (others => '0'),
      dataMin => (others => '1'),
      dataMax => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal resetStat : sl;

begin

   U_rstStat : entity work.SynchronizerOneShot
      generic map (
         TPD_G         => TPD_G,
         BYPASS_SYNC_G => COMMON_CLK_G)
      port map (
         clk     => wrClk,
         dataIn  => rstStat,
         dataOut => resetStat);

   process (dataIn, r, resetStat, wrEn, wrRst) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobes
      v.update := '0';

      -- Check for write clock enable
      if (wrEn = '1') then

         -- Set the flag
         v.update := '1';

         -- Check for min value
         if (dataIn < r.dataMin) then
            v.dataMin := dataIn;
         end if;

         -- Check for max value
         if (dataIn > r.dataMax) then
            v.dataMax := dataIn;
         end if;

      end if;

      -- Reset
      if (wrRst = '1') or (resetStat = '1') then
         v := REG_INIT_C;
      end if;

      -- Next register assignment
      rin <= v;

   end process;

   process (wrClk) is
   begin
      if (rising_edge(wrClk)) then
         r <= rin after TPD_G;
      end if;
   end process;

   U_dataOut : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         COMMON_CLK_G => COMMON_CLK_G,
         DATA_WIDTH_G => WIDTH_G)
      port map (
         -- Write Interface
         wr_clk => wrClk,
         wr_en  => wrEn,
         din    => dataIn,
         -- Read Interface
         rd_clk => rdClk,
         rd_en  => rdEn,
         dout   => dataOut);

   U_dataMin : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         COMMON_CLK_G => COMMON_CLK_G,
         DATA_WIDTH_G => WIDTH_G)
      port map (
         -- Write Interface
         wr_clk => wrClk,
         wr_en  => r.update,
         din    => r.dataMin,
         -- Read Interface
         rd_clk => rdClk,
         rd_en  => rdEn,
         dout   => dataMin);

   U_dataMax : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         COMMON_CLK_G => COMMON_CLK_G,
         DATA_WIDTH_G => WIDTH_G)
      port map (
         -- Write Interface
         wr_clk => wrClk,
         wr_en  => r.update,
         din    => r.dataMax,
         -- Read Interface
         rd_clk => rdClk,
         rd_en  => rdEn,
         valid  => updated,
         dout   => dataMax);

end rtl;
