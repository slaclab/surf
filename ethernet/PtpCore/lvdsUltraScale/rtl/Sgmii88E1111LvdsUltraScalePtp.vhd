-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Independent copper PTP endpoint, LVDS SGMII PCS and Marvell management.
-- PHC uses the PCS-derived clock. PCS clock reset also resets this PHC.
-- Stable-clock reset pulses break the PCS-reset/PHC-reset feedback path.
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
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.PtpPkg.all;

entity Sgmii88E1111LvdsUltraScalePtp is
   generic (
      TPD_G             : time              := 1 ns;
      AXIL_BASE_ADDR_G  : slv(31 downto 0)  := (others => '0');
      -- Relative offsets allow a board to retain an existing register map.
      ETH_OFFSET_G      : slv(31 downto 0) := x"00000000";
      PTP_OFFSET_G      : slv(31 downto 0) := x"00004000";
      STABLE_CLK_FREQ_G : real             := 156.25E6;
      PHY_G             : natural range 0 to 31 := 7;
      PACKET_LIFETIME_G : positive         := 125000000;
      FIFO_ADDR_WIDTH_G : positive         := 9;
      INGRESS_LATENCY_G : slv(63 downto 0) := (others => '0');
      EGRESS_LATENCY_G  : slv(63 downto 0) := (others => '0'));
   port (
      -- Host management clock domain. Cross once before local bank decode.
      axilClk        : in  sl;
      axilRst        : in  sl;
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;

      -- Stable clock must run independently of the external PHY clock.
      stableClk      : in  sl;
      stableRst      : in  sl;
      phyClk         : out sl;
      phyRst         : out sl;
      localMac       : in  slv(47 downto 0);
      sAxisMaster    : in  AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
      sAxisSlave     : out AxiStreamSlaveType;
      mAxisMaster    : out AxiStreamMasterType;
      mAxisSlave     : in  AxiStreamSlaveType := AXI_STREAM_SLAVE_FORCE_C;
      phcTime        : out PtpTimeType;
      phcStatus      : out PtpPhcStatusType;
      pps            : out sl;
      irq            : out sl;
      portActive     : out sl;
      phyReady       : out sl;
      servoState     : out slv(2 downto 0);
      primaryDropped : out slv(31 downto 0);

      phyClkP        : in    sl;
      phyClkN        : in    sl;
      phyMdc         : out   sl;
      phyMdio        : inout sl;
      phyRstN        : out   sl;
      phyIrqN        : in    sl;
      sgmiiRxP       : in    sl;
      sgmiiRxN       : in    sl;
      sgmiiTxP       : out   sl;
      sgmiiTxN       : out   sl);
end entity Sgmii88E1111LvdsUltraScalePtp;

architecture rtl of Sgmii88E1111LvdsUltraScalePtp is

   signal coreRst    : sl;
   signal coreConfig : slv(4 downto 0);
   signal coreStatus : slv(15 downto 0);
   signal gmiiTxd    : slv(7 downto 0);
   signal gmiiTxEn   : sl;
   signal gmiiTxEr   : sl;
   signal gmiiRxd    : slv(7 downto 0);
   signal gmiiRxDv   : sl;
   signal gmiiRxEr   : sl;

   signal sysClk125   : sl;
   signal sysRst125   : sl;
   signal sysClkEn    : sl;
   signal pcsStatus  : slv(15 downto 0);
   signal pcsReset   : sl;
   signal coreRstSync : sl;
   signal phyResetN  : sl;
   signal mdioResetN : sl;
   signal mdioReset  : sl;
   signal mdi        : sl;
   signal mdo        : sl;
   signal linkIrq    : sl;
   signal mdioStatus : slv(3 downto 0);
   signal linkStatus : slv(3 downto 0);

   type RegType is record
      coreRstD : sl;
      count    : unsigned(4 downto 0);
      pcsReset : sl;
   end record RegType;
   constant REG_INIT_C : RegType := (
      coreRstD => '0',
      count    => (others => '0'),
      pcsReset => '1');
   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   U_Ptp : entity surf.GigEthPtp
      generic map (
         TPD_G             => TPD_G,
         AXIL_BASE_ADDR_G  => AXIL_BASE_ADDR_G,
         ETH_OFFSET_G      => ETH_OFFSET_G,
         PTP_OFFSET_G      => PTP_OFFSET_G,
         COMMON_CLK_G      => false,
         PACKET_LIFETIME_G => PACKET_LIFETIME_G,
         FIFO_ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         INGRESS_LATENCY_G => INGRESS_LATENCY_G,
         EGRESS_LATENCY_G  => EGRESS_LATENCY_G)
      port map (
         axilClk           => axilClk,            -- [in]
         axilRst           => axilRst,            -- [in]
         axiReadMaster     => axiReadMaster,      -- [in]
         axiReadSlave      => axiReadSlave,       -- [out]
         axiWriteMaster    => axiWriteMaster,     -- [in]
         axiWriteSlave     => axiWriteSlave,      -- [out]
         sysClk125         => sysClk125,          -- [in]
         sysRst125         => sysRst125,          -- [in]
         extRst            => '0',             -- [in]
         localMac          => localMac,           -- [in]
         sAxisMaster       => sAxisMaster,        -- [in]
         sAxisSlave        => sAxisSlave,         -- [out]
         mAxisMaster       => mAxisMaster,        -- [out]
         mAxisSlave        => mAxisSlave,         -- [in]
         phcTime           => phcTime,            -- [out]
         phcStatus         => phcStatus,          -- [out]
         pps               => pps,                -- [out]
         irq               => irq,                -- [out]
         portActive        => portActive,         -- [out]
         phyReady          => phyReady,           -- [out]
         servoState        => servoState,         -- [out]
         primaryDropped    => primaryDropped,     -- [out]
         coreRst           => coreRst,            -- [out]
         coreConfig        => coreConfig,         -- [out]
         coreStatus        => coreStatus,         -- [in]
         gmiiTxd           => gmiiTxd,            -- [out]
         gmiiTxEn          => gmiiTxEn,           -- [out]
         gmiiTxEr          => gmiiTxEr,           -- [out]
         gmiiRxd           => gmiiRxd,            -- [in]
         gmiiRxDv          => gmiiRxDv,           -- [in]
         gmiiRxEr          => gmiiRxEr);          -- [in]

   phyClk  <= sysClk125;
   phyRst  <= sysRst125;
   phyRstN <= phyResetN;

   -- Open-drain MDIO is a physical-I/O tri-state exception.
   phyMdio <= 'Z' when mdo = '1' else '0';

   U_PhyReset : entity surf.PwrUpRst
      generic map (
         TPD_G          => TPD_G,
         OUT_POLARITY_G => '0',
         DURATION_G     => getTimeRatio(STABLE_CLK_FREQ_G, 100.0))
      port map (
         clk    => stableClk,   -- [in]
         arst   => stableRst,   -- [in]
         rstOut => phyResetN);  -- [out]

   U_MdioWait : entity surf.PwrUpRst
      generic map (
         TPD_G          => TPD_G,
         IN_POLARITY_G  => '0',
         OUT_POLARITY_G => '0',
         DURATION_G     => getTimeRatio(STABLE_CLK_FREQ_G, 100.0))
      port map (
         clk    => stableClk,    -- [in]
         arst   => phyResetN,    -- [in]
         rstOut => mdioResetN);  -- [out]

   mdioReset <= not mdioResetN;

   U_MdiSync : entity surf.Synchronizer
      generic map (TPD_G => TPD_G)
      port map (
         clk     => stableClk,  -- [in]
         dataIn  => phyMdio,    -- [in]
         dataOut => mdi);       -- [out]

   U_IrqSync : entity surf.Synchronizer
      generic map (
         TPD_G          => TPD_G,
         OUT_POLARITY_G => '0',
         INIT_G         => "11")
      port map (
         clk     => stableClk,  -- [in]
         dataIn  => phyIrqN,    -- [in]
         dataOut => linkIrq);   -- [out]

   U_Mdio : entity surf.Sgmii88E1111Mdio
      generic map (
         TPD_G          => TPD_G,
         GIGABIT_ONLY_G => true,
         PHY_G          => PHY_G,
         DIV_G          => integer(STABLE_CLK_FREQ_G / 2.0E6))
      port map (
         clk             => stableClk,      -- [in]
         rst             => mdioReset,      -- [in]
         initDone        => mdioStatus(0),  -- [out]
         linkIsUp        => mdioStatus(1),  -- [out]
         speed_is_10_100 => mdioStatus(2),  -- [out]
         speed_is_100    => mdioStatus(3),  -- [out]
         mdi             => mdi,            -- [in]
         mdo             => mdo,            -- [out]
         mdc             => phyMdc,         -- [out]
         linkIrq         => linkIrq);       -- [in]

   -- Levels only. 10/100 is not advertised; any non-gigabit report blocks MAC.
   U_LinkSync : entity surf.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 4)
      port map (
         clk     => sysClk125,   -- [in]
         dataIn  => mdioStatus,  -- [in]
         dataOut => linkStatus); -- [out]

   -- GigEthPtp uses bit 1 as ready. LVDS PCS uses bit 0 for valid link.
   -- Preserve the other diagnostic bits; qualification is intentionally
   -- combinational so loss of readiness cannot admit another GMII frame.
   coreStatus(15 downto 2) <= pcsStatus(15 downto 2);
   coreStatus(0) <= pcsStatus(0);
   coreStatus(1) <= pcsStatus(0) and linkStatus(0) and linkStatus(1) and
                    not linkStatus(2) and not linkStatus(3) and sysClkEn and not coreRst;

   U_ResetSync : entity surf.Synchronizer
      generic map (TPD_G => TPD_G)
      port map (
         clk     => stableClk,    -- [in]
         dataIn  => coreRst,      -- [in]
         dataOut => coreRstSync); -- [out]

   -- The PCS reset also resets its MMCM/clk125 reset output. Never feed that
   -- output level back to reset: issue one finite pulse in the stable domain.
   comb : process (r, coreRstSync, stableRst) is
      variable v : RegType;
   begin
      v := r;
      v.coreRstD := coreRstSync;
      v.pcsReset := '0';
      if coreRstSync = '1' and r.coreRstD = '0' then
         v.count := (others => '1');
      elsif r.count /= 0 then
         v.count := r.count - 1;
      end if;
      if v.count /= 0 then
         v.pcsReset := '1';
      end if;
      if stableRst = '1' then
         v := REG_INIT_C;
      end if;
      rin <= v;
      pcsReset <= r.pcsReset;
   end process comb;

   seq : process (stableClk) is
   begin
      if rising_edge(stableClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_Phy : entity surf.GigEthLvdsUltraScalePhy
      port map (
         coreRst    => pcsReset,   -- [in]
         coreConfig => coreConfig, -- [in]
         coreStatus => pcsStatus,  -- [out]
         sysClk125  => sysClk125,  -- [out]
         sysRst125  => sysRst125,  -- [out]
         sysClkEn   => sysClkEn,   -- [out]
         gmiiTxd    => gmiiTxd,    -- [in]
         gmiiTxEn   => gmiiTxEn,   -- [in]
         gmiiTxEr   => gmiiTxEr,   -- [in]
         gmiiRxd    => gmiiRxd,    -- [out]
         gmiiRxDv   => gmiiRxDv,   -- [out]
         gmiiRxEr   => gmiiRxEr,   -- [out]
         sgmiiClkP  => phyClkP,    -- [in]
         sgmiiClkN  => phyClkN,    -- [in]
         sgmiiRxP   => sgmiiRxP,   -- [in]
         sgmiiRxN   => sgmiiRxN,   -- [in]
         sgmiiTxP   => sgmiiTxP,   -- [out]
         sgmiiTxN   => sgmiiTxN);  -- [out]

end architecture rtl;
