-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Single-lane UltraScale GTH 1000BASE-X PTP composition.
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
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.PtpPkg.all;

entity GigEthGthUltraScalePtp is
   generic (
      TPD_G            : time              := 1 ns;
      AXIL_BASE_ADDR_G : slv(31 downto 0)  := (others => '0');
      -- Relative offsets allow a board to retain an existing register map.
      ETH_OFFSET_G      : slv(31 downto 0) := x"00000000";
      PTP_OFFSET_G      : slv(31 downto 0) := x"00004000";
      COMMON_CLK_G      : boolean          := false;
      PACKET_LIFETIME_G : positive         := 125000000;
      FIFO_ADDR_WIDTH_G : positive         := 9;
      INGRESS_LATENCY_G : slv(63 downto 0) := (others => '0');
      EGRESS_LATENCY_G  : slv(63 downto 0) := (others => '0');
      -- Select dedicated gtRefClk instead of the legacy sysClk125 reference.
      USE_GTREFCLK_G    : boolean := false);
   port (
      -- Host management clock domain. Cross once before local bank decode.
      axilClk        : in  sl;
      axilRst        : in  sl;
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;

      -- Continuous full-rate GMII and PHC domain; application streams use it too.
      sysClk125      : in  sl;
      sysRst125      : in  sl;
      sysClk62       : in  sl;
      extRst         : in  sl := '0';  -- Port/PCS reset only; does not reset PHC.
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

      -- Physical controls and serial interface.
      sigDet       : in  sl := '1';
      gtTxPolarity : in  sl := '0';
      gtRxPolarity : in  sl := '0';
      gtTxP        : out sl;
      gtTxN        : out sl;
      gtRxP        : in  sl;
      gtRxN        : in  sl;
      gtRefClk     : in  sl := '0');  -- Used only with USE_GTREFCLK_G.
end entity GigEthGthUltraScalePtp;

architecture rtl of GigEthGthUltraScalePtp is

   signal coreRst    : sl;
   signal coreConfig : slv(4 downto 0);
   signal coreStatus : slv(15 downto 0);
   signal gmiiTxd    : slv(7 downto 0);
   signal gmiiTxEn   : sl;
   signal gmiiTxEr   : sl;
   signal gmiiRxd    : slv(7 downto 0);
   signal gmiiRxDv   : sl;
   signal gmiiRxEr   : sl;

begin

   U_Ptp : entity surf.GigEthPtp
      generic map (
         TPD_G             => TPD_G,
         AXIL_BASE_ADDR_G  => AXIL_BASE_ADDR_G,
         ETH_OFFSET_G      => ETH_OFFSET_G,
         PTP_OFFSET_G      => PTP_OFFSET_G,
         COMMON_CLK_G      => COMMON_CLK_G,
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
         extRst            => extRst,             -- [in]
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

   U_Phy : entity surf.GigEthGthUltraScalePhy
      generic map (
         USE_GTREFCLK_G => USE_GTREFCLK_G)
      port map (
         gtRefClk     => gtRefClk,      -- [in]
         sysClk125    => sysClk125,     -- [in]
         sysClk62     => sysClk62,      -- [in]
         coreRst      => coreRst,       -- [in]
         coreConfig   => coreConfig,    -- [in]
         coreStatus   => coreStatus,    -- [out]
         gmiiTxd      => gmiiTxd,       -- [in]
         gmiiTxEn     => gmiiTxEn,      -- [in]
         gmiiTxEr     => gmiiTxEr,      -- [in]
         gmiiRxd      => gmiiRxd,       -- [out]
         gmiiRxDv     => gmiiRxDv,      -- [out]
         gmiiRxEr     => gmiiRxEr,      -- [out]
         sigDet       => sigDet,        -- [in]
         gtTxPolarity => gtTxPolarity,  -- [in]
         gtRxPolarity => gtRxPolarity,  -- [in]
         gtTxP        => gtTxP,         -- [out]
         gtTxN        => gtTxN,         -- [out]
         gtRxP        => gtRxP,         -- [in]
         gtRxN        => gtRxN);        -- [in]

end architecture rtl;
