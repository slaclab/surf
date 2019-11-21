-------------------------------------------------------------------------------
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


library surf;
use surf.StdRtlPkg.all;

entity SyncMinMax is
   generic (
      TPD_G        : time     := 1 ns;
      COMMON_CLK_G : boolean  := false;
      WIDTH_G      : positive := 16);
   port (
      -- ASYNC statistics reset
      rstStat : in  sl;
      -- Write Interface (wrClk domain)
      wrClk   : in  sl;
      wrRst   : in  sl := '0';
      wrEn    : in  sl := '1';
      dataIn  : in  slv(WIDTH_G-1 downto 0);
      -- Read Interface (rdClk domain)
      rdClk   : in  sl;
      rdEn    : in  sl := '1';
      updated : out sl;
      dataOut : out slv(WIDTH_G-1 downto 0);
      dataMin : out slv(WIDTH_G-1 downto 0);
      dataMax : out slv(WIDTH_G-1 downto 0));
end SyncMinMax;

architecture rtl of SyncMinMax is

   type RegType is record
      armed   : sl;
      update  : sl;
      dataIn  : slv(WIDTH_G-1 downto 0);
      dataMin : slv(WIDTH_G-1 downto 0);
      dataMax : slv(WIDTH_G-1 downto 0);
   end record RegType;
   constant REG_INIT_C : RegType := (
      armed   => '0',
      update  => '0',
      dataIn  => (others => '0'),
      dataMin => (others => '0'),
      dataMax => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal resetStat : sl;
   signal ls        : sl;
   signal gt        : sl;
   signal valid     : sl;
   signal data      : slv(WIDTH_G-1 downto 0);

   signal dataMinFeadback : slv(WIDTH_G-1 downto 0);
   signal dataMaxFeadback : slv(WIDTH_G-1 downto 0);

begin

   U_rstStat : entity surf.SynchronizerOneShot
      generic map (
         TPD_G         => TPD_G,
         BYPASS_SYNC_G => COMMON_CLK_G)
      port map (
         clk     => wrClk,
         dataIn  => rstStat,
         dataOut => resetStat);

   U_LessThan : entity surf.DspComparator
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => WIDTH_G)
      port map (
         clk     => wrClk,
         -- Inbound Interface
         ibValid => wrEn,
         ain     => dataIn,
         bin     => dataMinFeadback,
         -- Outbound Interface
         ls      => ls);                --  (a <  b)

   U_GreaterThan : entity surf.DspComparator
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => WIDTH_G)
      port map (
         clk     => wrClk,
         -- Inbound Interface
         ibValid => wrEn,
         ain     => dataIn,
         bin     => dataMaxFeadback,
         -- Outbound Interface
         obValid => valid,
         aout    => data,
         -- gt      => gt);                --  (a >  b)
         gtEq    => gt);  --  Using gtEq because better performance than gt in the DspComparator.vhd, and gtEq give the same result as gt with respect to this module's implementation

   process (data, gt, ls, r, resetStat, valid, wrRst) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobes
      v.update := '0';

      -- Check for write clock enable
      if (valid = '1') then

         -- Set the flag
         v.update := '1';

         -- Check if first time after reset
         if (r.armed = '0') then

            -- Set the flag
            v.armed := '1';

            -- Pass the current values to the statistics measurements
            v.dataMin := data;
            v.dataMax := data;

         else

            -- Check for min value
            if (ls = '1') then
               v.dataMin := data;
            end if;

            -- Check for max value
            if (gt = '1') then
               v.dataMax := data;
            end if;

         end if;

      end if;

      -- Outputs
      dataMinFeadback <= v.dataMin;
      dataMaxFeadback <= v.dataMax;

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

   U_dataOut : entity surf.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         COMMON_CLK_G => COMMON_CLK_G,
         DATA_WIDTH_G => WIDTH_G)
      port map (
         -- Write Interface
         wr_clk => wrClk,
         wr_en  => valid,
         din    => data,
         -- Read Interface
         rd_clk => rdClk,
         rd_en  => rdEn,
         dout   => dataOut);

   U_dataMin : entity surf.SynchronizerFifo
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

   U_dataMax : entity surf.SynchronizerFifo
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
