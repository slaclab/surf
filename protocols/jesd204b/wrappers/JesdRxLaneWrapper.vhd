-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper -- instantiates JesdRxLane and flattens
--              the jesdGtRxLaneType record input for cocotb injection.
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

entity JesdRxLaneWrapper is
   generic (
      TPD_G : time     := 1 ns;
      F_G   : positive := 2;
      K_G   : positive := 32);
   port (
      devClk_i        : in  sl;
      devRst_i        : in  sl;
      subClass_i      : in  sl;
      sysRef_i        : in  sl;
      clearErr_i      : in  sl;
      enable_i        : in  sl;
      replEnable_i    : in  sl;
      scrEnable_i     : in  sl;
      lmfc_i          : in  sl;
      linkErrMask_i   : in  slv(5 downto 0);
      nSyncAny_i      : in  sl;
      nSyncAnyD1_i    : in  sl;
      inv_i           : in  sl;
      -- Flattened jesdGtRxLaneType fields (Jesd204bPkg.vhd:61-68):
      gtRxData_i      : in  slv(GT_WORD_SIZE_C*8-1 downto 0);
      gtRxDataK_i     : in  slv(GT_WORD_SIZE_C-1 downto 0);
      gtRxDispErr_i   : in  slv(GT_WORD_SIZE_C-1 downto 0);
      gtRxDecErr_i    : in  slv(GT_WORD_SIZE_C-1 downto 0);
      gtRxRstDone_i   : in  sl;
      gtRxCdrStable_i : in  sl;
      -- JesdRxLane outputs:
      nSync_o         : out sl;
      dataValid_o     : out sl;
      sampleData_o    : out slv(GT_WORD_SIZE_C*8-1 downto 0);
      status_o        : out slv(RX_STAT_WIDTH_C-1 downto 0));
end entity JesdRxLaneWrapper;

architecture rtl of JesdRxLaneWrapper is

   signal s_jesdGtRx : jesdGtRxLaneType;

begin

   ---------------------------------------------------------------------------
   -- Assemble record from flat ports
   ---------------------------------------------------------------------------
   s_jesdGtRx.data      <= gtRxData_i;
   s_jesdGtRx.dataK     <= gtRxDataK_i;
   s_jesdGtRx.dispErr   <= gtRxDispErr_i;
   s_jesdGtRx.decErr    <= gtRxDecErr_i;
   s_jesdGtRx.rstDone   <= gtRxRstDone_i;
   s_jesdGtRx.cdrStable <= gtRxCdrStable_i;

   ---------------------------------------------------------------------------
   -- DUT: JesdRxLane (record input assembled above)
   ---------------------------------------------------------------------------
   U_DUT : entity surf.JesdRxLane
      generic map (
         TPD_G => TPD_G,
         F_G   => F_G,
         K_G   => K_G)
      port map (
         devClk_i      => devClk_i,
         devRst_i      => devRst_i,
         subClass_i    => subClass_i,
         sysRef_i      => sysRef_i,
         clearErr_i    => clearErr_i,
         enable_i      => enable_i,
         replEnable_i  => replEnable_i,
         scrEnable_i   => scrEnable_i,
         r_jesdGtRx    => s_jesdGtRx,
         lmfc_i        => lmfc_i,
         linkErrMask_i => linkErrMask_i,
         nSyncAny_i    => nSyncAny_i,
         nSyncAnyD1_i  => nSyncAnyD1_i,
         inv_i         => inv_i,
         nSync_o       => nSync_o,
         dataValid_o   => dataValid_o,
         sampleData_o  => sampleData_o,
         status_o      => status_o);

end architecture rtl;
