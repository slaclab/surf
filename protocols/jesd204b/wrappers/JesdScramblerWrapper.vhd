-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper — instantiates JesdAlignChGen (TX) and
--              JesdAlignFrRepCh (RX) back-to-back to exercise the inline
--              1+x^14+x^15 scrambler/descrambler round-trip.
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
use surf.Jesd204bPkg.all;

entity JesdScramblerWrapper is
   generic (
      TPD_G : time     := 1 ns;
      F_G   : positive := 2);
   port (
      clk             : in  sl;
      rst             : in  sl;
      scrEnable_i     : in  sl;
      lmfc_i          : in  sl;
      dataValid_i     : in  sl;
      replEnable_i    : in  sl;
      alignFrame_i    : in  sl;
      sampleData_i    : in  slv(GT_WORD_SIZE_C*8-1 downto 0);
      txData_o        : out slv(GT_WORD_SIZE_C*8-1 downto 0);
      txDataK_o       : out slv(GT_WORD_SIZE_C-1 downto 0);
      rxData_o        : out slv(GT_WORD_SIZE_C*8-1 downto 0);
      rxValid_o       : out sl;
      rxAlignErr_o    : out sl;
      rxPositionErr_o : out sl);
end entity JesdScramblerWrapper;

architecture rtl of JesdScramblerWrapper is

   signal txSampleData : slv(GT_WORD_SIZE_C*8-1 downto 0);
   signal txSampleK    : slv(GT_WORD_SIZE_C-1 downto 0);

begin

   ---------------------------------------------------------------------------
   -- TX scrambler (JesdAlignChGen)
   ---------------------------------------------------------------------------
   U_TX : entity surf.JesdAlignChGen
      generic map (
         TPD_G => TPD_G,
         F_G   => F_G)
      port map (
         clk          => clk,
         rst          => rst,
         enable_i     => dataValid_i,
         scrEnable_i  => scrEnable_i,
         lmfc_i       => lmfc_i,
         dataValid_i  => dataValid_i,
         sampleData_i => sampleData_i,
         sampleData_o => txSampleData,
         sampleK_o    => txSampleK);

   txData_o  <= txSampleData;
   txDataK_o <= txSampleK;

   ---------------------------------------------------------------------------
   -- RX descrambler (JesdAlignFrRepCh)
   ---------------------------------------------------------------------------
   U_RX : entity surf.JesdAlignFrRepCh
      generic map (
         TPD_G => TPD_G,
         F_G   => F_G)
      port map (
         clk               => clk,
         rst               => rst,
         replEnable_i      => replEnable_i,
         scrEnable_i       => scrEnable_i,
         alignFrame_i      => alignFrame_i,
         dataValid_i       => dataValid_i,
         dataRx_i          => txSampleData,
         chariskRx_i       => txSampleK,
         sampleData_o      => rxData_o,
         sampleDataValid_o => rxValid_o,
         alignErr_o        => rxAlignErr_o,
         positionErr_o     => rxPositionErr_o);

end architecture rtl;
