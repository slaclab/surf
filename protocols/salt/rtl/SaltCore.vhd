-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: SLAC Asynchronous Logic Transceiver (SALT) Core
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;

entity SaltCore is
   generic (
      TPD_G               : time    := 1 ns;
      SIMULATION_G        : boolean := false;
      SIM_DEVICE_G        : string  := "ULTRASCALE";
      TX_ENABLE_G         : boolean := true;
      RX_ENABLE_G         : boolean := true;
      COMMON_TX_CLK_G     : boolean := false;  -- Set to true if sAxisClk and clk are the same clock
      COMMON_RX_CLK_G     : boolean := false;  -- Set to true if mAxisClk and clk are the same clock
      IODELAY_GROUP_G     : string  := "SALT_GROUP";
      REF_FREQ_G          : real    := 200.0;  -- IDELAYCTRL's REFCLK (in units of Hz)
      SLAVE_AXI_CONFIG_G  : AxiStreamConfigType;
      MASTER_AXI_CONFIG_G : AxiStreamConfigType);
   port (
      -- 1.25 Gbps LVDS TX
      txP            : out sl;
      txN            : out sl;
      -- 1.25 Gbps LVDS RX
      rxP            : in  sl;
      rxN            : in  sl;
      -- Reference Signals
      clk125MHz      : in  sl;
      rst125MHz      : in  sl;
      clk156MHz      : in  sl;
      rst156MHz      : in  sl;
      clk625MHz      : in  sl;
      -- Status Interface
      linkUp         : out sl;
      txPktSent      : out sl;
      txEofeSent     : out sl;
      rxPktRcvd      : out sl;
      rxErrDet       : out sl;
      -- Configuration Interface
      enUsrDlyCfg    : in  sl               := '0';  -- Enable User delay config
      usrDlyCfg      : in  slv(8 downto 0)  := (others => '0');  -- User delay config
      bypFirstBerDet : in  sl               := '1';  -- Set to '1' if IDELAY full scale range > 2 Unit Intervals (UI) of serial rate (example: IDELAY range 2.5ns  > 1 ns "1Gb/s" )
      minEyeWidth    : in  slv(7 downto 0)  := toSlv(80, 8);  -- Sets the minimum eye width required for locking (units of IDELAY step)
      lockingCntCfg  : in  slv(23 downto 0) := ite(SIMULATION_G, x"00_0064", x"00_FFFF");  -- Number of error-free event before state=LOCKED_S
      -- Slave Port
      sAxisClk       : in  sl;
      sAxisRst       : in  sl;
      sAxisMaster    : in  AxiStreamMasterType;
      sAxisSlave     : out AxiStreamSlaveType;
      -- Master Port
      mAxisClk       : in  sl;
      mAxisRst       : in  sl;
      mAxisMaster    : out AxiStreamMasterType;
      mAxisSlave     : in  AxiStreamSlaveType);
end SaltCore;

architecture mapping of SaltCore is

   signal txEn   : sl              := '0';
   signal txData : slv(7 downto 0) := x"00";

   signal rxEn   : sl              := '0';
   signal rxErr  : sl              := '0';
   signal rxData : slv(7 downto 0) := x"00";

   signal rxLinkUp : sl := '0';

begin

   linkUp <= rxLinkUp and not(rst125MHz);

   TX_ENABLE : if (TX_ENABLE_G = true) generate

      U_SaltTxLvds : entity surf.SaltTxLvds
         generic map(
            TPD_G        => TPD_G,
            SIM_DEVICE_G => SIM_DEVICE_G)
         port map(
            -- Clocks and Resets
            clk125MHz => clk125MHz,
            rst125MHz => rst125MHz,
            clk156MHz => clk156MHz,
            rst156MHz => rst156MHz,
            clk625MHz => clk625MHz,
            -- GMII Interface
            txEn      => txEn,
            txData    => txData,
            -- LVDS TX Port
            txP       => txP,
            txN       => txN);

      U_SaltTx : entity surf.SaltTx
         generic map(
            TPD_G              => TPD_G,
            SLAVE_AXI_CONFIG_G => SLAVE_AXI_CONFIG_G,
            COMMON_TX_CLK_G    => COMMON_TX_CLK_G)
         port map(
            -- Slave Port
            sAxisClk    => sAxisClk,
            sAxisRst    => sAxisRst,
            sAxisMaster => sAxisMaster,
            sAxisSlave  => sAxisSlave,
            -- GMII Interface
            txPktSent   => txPktSent,
            txEofeSent  => txEofeSent,
            txEn        => txEn,
            txData      => txData,
            clk         => clk125MHz,
            rst         => rst125MHz);

   end generate;

   TX_DISABLE : if (TX_ENABLE_G = false) generate

      txData     <= x"00";
      txPktSent  <= '0';
      txEofeSent <= '0';
      txEn       <= '0';
      sAxisSlave <= AXI_STREAM_SLAVE_FORCE_C;

   end generate;

   RX_ENABLE : if (RX_ENABLE_G = true) generate

      U_SaltRxLvds : entity surf.SaltRxLvds
         generic map(
            TPD_G           => TPD_G,
            SIMULATION_G    => SIMULATION_G,
            SIM_DEVICE_G    => SIM_DEVICE_G,
            IODELAY_GROUP_G => IODELAY_GROUP_G,
            REF_FREQ_G      => REF_FREQ_G)
         port map(
            -- Clocks and Resets
            clk125MHz      => clk125MHz,
            rst125MHz      => rst125MHz,
            clk156MHz      => clk156MHz,
            rst156MHz      => rst156MHz,
            clk625MHz      => clk625MHz,
            -- GMII Interface
            rxEn           => rxEn,
            rxErr          => rxErr,
            rxData         => rxData,
            rxLinkUp       => rxLinkUp,
            -- Configuration Interface
            enUsrDlyCfg    => enUsrDlyCfg,
            usrDlyCfg      => usrDlyCfg,
            bypFirstBerDet => bypFirstBerDet,
            minEyeWidth    => minEyeWidth,
            lockingCntCfg  => lockingCntCfg,
            -- LVDS RX Port
            rxP            => rxP,
            rxN            => rxN);

      U_SaltRx : entity surf.SaltRx
         generic map(
            TPD_G               => TPD_G,
            MASTER_AXI_CONFIG_G => MASTER_AXI_CONFIG_G,
            COMMON_RX_CLK_G     => COMMON_RX_CLK_G)
         port map(
            -- Master Port
            mAxisClk    => mAxisClk,
            mAxisRst    => mAxisRst,
            mAxisMaster => mAxisMaster,
            mAxisSlave  => mAxisSlave,
            -- GMII Interface
            rxLinkUp    => rxLinkUp,
            rxPktRcvd   => rxPktRcvd,
            rxErrDet    => rxErrDet,
            rxEn        => rxEn,
            rxErr       => rxErr,
            rxData      => rxData,
            clk         => clk125MHz,
            rst         => rst125MHz);

   end generate;

   RX_DISABLE : if (RX_ENABLE_G = false) generate

      rxLinkUp    <= '1';
      rxPktRcvd   <= '0';
      rxErrDet    <= '0';
      mAxisMaster <= AXI_STREAM_MASTER_INIT_C;

   end generate;

end mapping;
