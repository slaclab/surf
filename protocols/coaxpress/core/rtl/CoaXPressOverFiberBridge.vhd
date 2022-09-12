-------------------------------------------------------------------------------
-- Title      : CXP Over Fiber Protocol: http://jiia.org/wp-content/themes/jiia/pdf/standard_dl/coaxpress/CXPR-008-2021.pdf
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: CoaXPress Over Fiber Bridge
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

entity CoaXPressOverFiberBridge is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Clock and Reset
      clk      : in  sl;
      rst      : in  sl;
      -- XGMII interface
      xgmiiTxd : out slv(31 downto 0);
      xgmiiTxc : out slv(3 downto 0);
      xgmiiRxd : in  slv(31 downto 0);
      xgmiiRxc : in  slv(3 downto 0);
      -- CXP Interface
      txData   : in  slv(31 downto 0);
      txDataK  : in  slv(3 downto 0);
      rxData   : out slv(31 downto 0);
      rxDataK  : out slv(3 downto 0));
end entity CoaXPressOverFiberBridge;

architecture mapping of CoaXPressOverFiberBridge is

begin

   U_BridgeTx : entity surf.CoaXPressOverFiberBridgeTx
      generic map (
         TPD_G => TPD_G)
      port map (
         -- Clock and Reset
         clk      => clk,
         rst      => rst,
         -- XGMII interface
         xgmiiTxd => xgmiiTxd,
         xgmiiTxc => xgmiiTxc,
         -- CXP interface
         txData   => txData,
         txDataK  => txDataK);

   U_BridgeRx : entity surf.CoaXPressOverFiberBridgeRx
      generic map (
         TPD_G => TPD_G)
      port map (
         -- Clock and Reset
         clk      => clk,
         rst      => rst,
         -- XGMII interface
         xgmiiRxd => xgmiiRxd,
         xgmiiRxc => xgmiiRxc,
         -- CXP interface
         rxData   => rxData,
         rxDataK  => rxDataK);

end mapping;
