-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper -- instantiates JesdTxLane and flattens
--              the jesdGtTxLaneType record output for cocotb observation.
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

entity JesdTxLaneWrapper is
   generic (
      TPD_G    : time            := 1 ns;
      F_G      : positive        := 2;
      K_G      : positive        := 32;
      -- ILAS config generics (all defaulted)
      DID_G    : slv(7 downto 0) := (others => '0');
      BID_G    : slv(3 downto 0) := (others => '0');
      M_G      : slv(7 downto 0) := (others => '0');
      N_G      : slv(4 downto 0) := (others => '0');
      NPRIME_G : slv(4 downto 0) := (others => '0');
      CS_G     : slv(1 downto 0) := (others => '0');
      S_G      : slv(4 downto 0) := (others => '0');
      HD_G     : sl              := '0';
      CF_G     : slv(4 downto 0) := (others => '0'));
   port (
      devClk_i     : in  sl;
      devRst_i     : in  sl;
      subClass_i   : in  sl;
      enable_i     : in  sl;
      replEnable_i : in  sl;
      scrEnable_i  : in  sl;
      inv_i        : in  sl;
      lmfc_i       : in  sl;
      nSync_i      : in  sl;
      gtTxReady_i  : in  sl;
      sysRef_i     : in  sl;
      lid_i        : in  slv(4 downto 0);
      status_o     : out slv(TX_STAT_WIDTH_C-1 downto 0);
      dacReady_o   : out sl;
      sampleData_i : in  slv(GT_WORD_SIZE_C*8-1 downto 0);
      -- Flattened r_jesdGtTx record (jesdGtTxLaneType -> flat ports)
      gtTxData_o   : out slv(GT_WORD_SIZE_C*8-1 downto 0);
      gtTxDataK_o  : out slv(GT_WORD_SIZE_C-1 downto 0));
end entity JesdTxLaneWrapper;

architecture rtl of JesdTxLaneWrapper is

   signal s_jesdGtTx : jesdGtTxLaneType;

begin

   ---------------------------------------------------------------------------
   -- DUT: JesdTxLane (record output flattened for cocotb)
   ---------------------------------------------------------------------------
   U_DUT : entity surf.JesdTxLane
      generic map (
         TPD_G    => TPD_G,
         F_G      => F_G,
         K_G      => K_G,
         DID_G    => DID_G,
         BID_G    => BID_G,
         M_G      => M_G,
         N_G      => N_G,
         NPRIME_G => NPRIME_G,
         CS_G     => CS_G,
         S_G      => S_G,
         HD_G     => HD_G,
         CF_G     => CF_G)
      port map (
         devClk_i     => devClk_i,
         devRst_i     => devRst_i,
         subClass_i   => subClass_i,
         enable_i     => enable_i,
         replEnable_i => replEnable_i,
         scrEnable_i  => scrEnable_i,
         inv_i        => inv_i,
         lmfc_i       => lmfc_i,
         nSync_i      => nSync_i,
         gtTxReady_i  => gtTxReady_i,
         sysRef_i     => sysRef_i,
         lid_i        => lid_i,
         status_o     => status_o,
         dacReady_o   => dacReady_o,
         sampleData_i => sampleData_i,
         r_jesdGtTx   => s_jesdGtTx);

   gtTxData_o  <= s_jesdGtTx.data;
   gtTxDataK_o <= s_jesdGtTx.dataK;

end architecture rtl;
