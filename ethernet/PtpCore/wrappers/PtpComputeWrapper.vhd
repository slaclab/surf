-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Scalar test adapter for the production word-compute records.
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
use ieee.numeric_std.all;
library surf;
use surf.StdRtlPkg.all;
use surf.PtpComputePkg.all;

entity PtpComputeWrapper is
   generic (
      TPD_G          : time    := 1 ns;
      MEMORY_TYPE_G  : string  := "block";
      RST_POLARITY_G : sl      := '1';
      RST_ASYNC_G    : boolean := false);
   port (
      clk          : in  sl;
      rst          : in  sl;
      cancel       : in  slv(3 downto 0);
      retain       : in slv(3 downto 0) := (others => '0');
      memValid     : in  sl;
      memReady     : out sl;
      memWrite     : in  sl;
      memClient    : in  slv(1 downto 0);
      memWord      : in  slv(5 downto 0);
      memData      : in  slv(31 downto 0);
      readValid    : out sl;
      readReady    : in  sl;
      readData     : out slv(31 downto 0);
      readClient   : out slv(1 downto 0);
      readWord     : out slv(5 downto 0);
      jobValid     : in  sl;
      jobReady     : out sl;
      jobClient    : in  slv(1 downto 0);
      jobOperation : in  slv(2 downto 0);
      jobSourceA   : in slv(3 downto 0) := x"0";
      jobSourceB   : in slv(3 downto 0) := x"1";
      jobTarget    : in slv(3 downto 0) := x"2";
      jobRemainder : in slv(3 downto 0) := x"3";
      jobShift     : in slv(6 downto 0) := (others => '0');
      jobRound     : in  sl;
      jobTag       : in  slv(31 downto 0);
      resultValid  : out slv(3 downto 0);
      resultReady  : in  slv(3 downto 0);
      resultError  : out slv(3 downto 0);
      resultLess   : out slv(3 downto 0);
      resultEqual  : out slv(3 downto 0);
      resultTag    : out slv(127 downto 0));
end entity PtpComputeWrapper;

architecture mapping of PtpComputeWrapper is

   signal masters : PtpComputeMasterArray(0 to 3);

   signal slaves : PtpComputeSlaveArray(0 to 3);

begin

   -- Fixture-only scalar selection; production clients connect complete records.
   inputs : process (all) is
      variable m        : PtpComputeMasterArray(0 to 3);
      variable i        : natural range 0 to 3;
      variable j        : natural range 0 to 3;
      variable selected : natural range 0 to 3;
      variable found    : boolean;
   begin
      m := (others => PTP_COMPUTE_MASTER_INIT_C);
      i := to_integer(unsigned(memClient));
      j := to_integer(unsigned(jobClient));
      m(i).memValid := memValid;
      m(i).memWrite := memWrite;
      m(i).memWord := memWord;
      m(i).memData := memData;
      m(j).jobValid := jobValid;
      m(j).job.operation := jobOperation;
      m(j).job.sourceA := jobSourceA;
      m(j).job.sourceB := jobSourceB;
      m(j).job.target := jobTarget;
      m(j).job.remainder := jobRemainder;
      m(j).job.shift := jobShift;
      m(j).job.rounding := jobRound;
      m(j).job.tag := jobTag;
      selected := 0;
      found    := false;
      for n in 0 to 3 loop
         m(n).cancel := cancel(n);
         m(n).retain := retain(n);
         m(n).resultReady := resultReady(n);

         if not found and slaves(n).readValid = '1' then
            selected := n;
            found    := true;
         end if;

      end loop;
      m(selected).readReady := readReady;
      masters <= m;
      memReady <= slaves(i).memReady;
      jobReady <= slaves(j).jobReady;
      readValid <= slaves(selected).readValid;
      readWord <= slaves(selected).readWord;
      readData <= slaves(selected).readData;
      readClient <= toSlv(selected, 2);
   end process inputs;
   GEN_RESULTS : for i in 0 to 3 generate
      resultValid(i) <= slaves(i).resultValid;
      resultError(i) <= slaves(i).resultError;
      resultLess(i) <= slaves(i).resultLess;
      resultEqual(i) <= slaves(i).resultEqual;
      resultTag(32*i+31 downto 32*i) <= slaves(i).resultTag;
   end generate GEN_RESULTS;

   U_DUT : entity surf.PtpCompute
      generic map (
         TPD_G          => TPD_G,
         MEMORY_TYPE_G  => MEMORY_TYPE_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G)
      port map (
         clk     => clk,
         rst     => rst,
         masters => masters,
         slaves  => slaves);

end architecture mapping;
