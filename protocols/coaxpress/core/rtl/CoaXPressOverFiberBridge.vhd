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
use surf.CoaXPressPkg.all;

entity CoaXPressOverFiberBridge is
   generic (
      TPD_G   : time    := 1 ns;
      LANE0_G : boolean := true);
   port (
      -- XGMII TX interface (txClk156 domain)
      txClk156   : in  sl;
      xgmiiTxd   : out slv(63 downto 0) := CXPOF_IDLE_WORD_C & CXPOF_IDLE_WORD_C;
      xgmiiTxc   : out slv(7 downto 0)  := x"FF";
      -- XGMII RX interface (rxClk156 domain)
      rxClk156   : in  sl;
      xgmiiRxd   : in  slv(63 downto 0);
      xgmiiRxc   : in  slv(7 downto 0);
      -- CXP TX interface (txClk312 domain)
      txClk312   : in  sl;
      txRst312   : in  sl;
      txLsValid  : in  sl;
      txLsData   : in  slv(7 downto 0);
      txLsDataK  : in  sl;
      txLsLaneEn : in  slv(3 downto 0);
      txLsRate   : in  sl;
      -- CXP RX interface (rxClk312 domain)
      rxClk312   : in  sl;
      rxRst312   : in  sl;
      rxData     : out slv(31 downto 0);
      rxDataK    : out slv(3 downto 0));
end entity CoaXPressOverFiberBridge;

architecture mapping of CoaXPressOverFiberBridge is

   signal txd : slv(31 downto 0);
   signal txc : slv(3 downto 0);
   signal rxd : slv(31 downto 0);
   signal rxc : slv(3 downto 0);

begin

   U_64bTo32b : entity surf.AsyncGearbox
      generic map (
         TPD_G          => TPD_G,
         SLAVE_WIDTH_G  => (64+8),
         MASTER_WIDTH_G => (32+4),
         EN_EXT_CTRL_G  => false)
      port map (
         -- input side data and flow control (slaveClk domain)
         slaveClk                 => rxClk156,
         slaveRst                 => '0',
         slaveData(31 downto 0)   => xgmiiRxd(31 downto 0),
         slaveData(35 downto 32)  => xgmiiRxc(3 downto 0),
         slaveData(67 downto 36)  => xgmiiRxd(63 downto 32),
         slaveData(71 downto 68)  => xgmiiRxc(7 downto 4),
         -- output side data and flow control (masterClk domain)
         masterClk                => rxClk312,
         masterRst                => rxRst312,
         masterData(31 downto 0)  => rxd,
         masterData(35 downto 32) => rxc);

   U_Rx : entity surf.CoaXPressOverFiberBridgeRx
      generic map (
         TPD_G => TPD_G)
      port map (
         -- Clock and Reset
         clk      => rxClk312,
         rst      => rxRst312,
         -- XGMII interface
         xgmiiRxd => rxd,
         xgmiiRxc => rxc,
         -- CXP interface
         rxData   => rxData,
         rxDataK  => rxDataK);

   GEN_TX : if (LANE0_G = true) generate

      U_Tx : entity surf.CoaXPressOverFiberBridgeTx
         generic map (
            TPD_G => TPD_G)
         port map (
            -- Clock and Reset
            clk        => txClk312,
            rst        => txRst312,
            -- XGMII interface
            xgmiiTxd   => txd,
            xgmiiTxc   => txc,
            -- CXP interface
            txLsValid  => txLsValid,
            txLsData   => txLsData,
            txLsDataK  => txLsDataK,
            txLsRate   => txLsRate,
            txLsLaneEn => txLsLaneEn);

      U_32bTo64b : entity surf.AsyncGearbox
         generic map (
            TPD_G          => TPD_G,
            SLAVE_WIDTH_G  => (32+4),
            MASTER_WIDTH_G => (64+8),
            EN_EXT_CTRL_G  => false)
         port map (
            -- input side data and flow control (slaveClk domain)
            slaveClk                 => txClk312,
            slaveRst                 => txRst312,
            slaveData(31 downto 0)   => txd,
            slaveData(35 downto 32)  => txc,
            -- output side data and flow control (masterClk domain)
            masterClk                => txClk156,
            masterRst                => '0',
            masterData(31 downto 0)  => xgmiiTxd(31 downto 0),
            masterData(35 downto 32) => xgmiiTxc(3 downto 0),
            masterData(67 downto 36) => xgmiiTxd(63 downto 32),
            masterData(71 downto 68) => xgmiiTxc(7 downto 4));

   end generate;

end mapping;
