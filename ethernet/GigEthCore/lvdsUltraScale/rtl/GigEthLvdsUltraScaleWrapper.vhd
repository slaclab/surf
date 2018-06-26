-------------------------------------------------------------------------------
-- File       : GigEthLvdsUltraScaleWrapper.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper for SGMII/LVDS Ethernet
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

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.AxiLitePkg.all;
use work.EthMacPkg.all;
use work.GigEthPkg.all;

library unisim;
use unisim.vcomponents.all;

entity GigEthLvdsUltraScaleWrapper is
   generic (
      TPD_G              : time                             := 1 ns;
      NUM_LANE_G         : natural range 1 to 4             := 1;
      -- Clocking Configurations
      USE_REFCLK_G       : boolean                          := false;  --  FALSE: sgmiiClkP/N,  TRUE: sgmiiRefClk
      CLKIN_PERIOD_G     : real                             := 1.6;
      DIVCLK_DIVIDE_G    : positive                         := 2;
      CLKFBOUT_MULT_F_G  : real                             := 2.0;
      -- AXI-Lite Configurations
      EN_AXI_REG_G       : boolean                          := false;
      -- AXI Streaming Configurations
      AXIS_CONFIG_G      : AxiStreamConfigArray(3 downto 0) := (others => AXI_STREAM_CONFIG_INIT_C)
   );
   port (
      -- Local Configurations
      localMac            : in  Slv48Array(NUM_LANE_G-1 downto 0)              := (others => MAC_ADDR_INIT_C);
      -- Streaming DMA Interface
      dmaClk              : in  slv(NUM_LANE_G-1 downto 0);
      dmaRst              : in  slv(NUM_LANE_G-1 downto 0);
      dmaIbMasters        : out AxiStreamMasterArray(NUM_LANE_G-1 downto 0);
      dmaIbSlaves         : in  AxiStreamSlaveArray(NUM_LANE_G-1 downto 0);
      dmaObMasters        : in  AxiStreamMasterArray(NUM_LANE_G-1 downto 0);
      dmaObSlaves         : out AxiStreamSlaveArray(NUM_LANE_G-1 downto 0);
      -- Slave AXI-Lite Interface
      axiLiteClk          : in  slv(NUM_LANE_G-1 downto 0)                     := (others => '0');
      axiLiteRst          : in  slv(NUM_LANE_G-1 downto 0)                     := (others => '0');
      axiLiteReadMasters  : in  AxiLiteReadMasterArray(NUM_LANE_G-1 downto 0)  := (others => AXI_LITE_READ_MASTER_INIT_C);
      axiLiteReadSlaves   : out AxiLiteReadSlaveArray(NUM_LANE_G-1 downto 0);
      axiLiteWriteMasters : in  AxiLiteWriteMasterArray(NUM_LANE_G-1 downto 0) := (others => AXI_LITE_WRITE_MASTER_INIT_C);
      axiLiteWriteSlaves  : out AxiLiteWriteSlaveArray(NUM_LANE_G-1 downto 0);
      -- Misc. Signals
      extRst              : in  sl                                             := '0';
      phyClk              : out sl;
      phyRst              : out sl;
      phyReady            : out slv(NUM_LANE_G-1 downto 0);
      sigDet              : in  slv(NUM_LANE_G-1 downto 0)                     := (others => '1');
      mmcmLocked          : out sl;
      speed_is_10_100     : in  slv(NUM_LANE_G-1 downto 0)                     := (others => '0');
      speed_is_100        : in  slv(NUM_LANE_G-1 downto 0)                     := (others => '1');
      -- MGT Clock Port
      sgmiiRefClk         : in  sl                                             := '0';
      sgmiiClkP           : in  sl                                             := '1';
      sgmiiClkN           : in  sl                                             := '0';
      -- MGT Ports
      sgmiiTxP            : out slv(NUM_LANE_G-1 downto 0);
      sgmiiTxN            : out slv(NUM_LANE_G-1 downto 0);
      sgmiiRxP            : in  slv(NUM_LANE_G-1 downto 0);
      sgmiiRxN            : in  slv(NUM_LANE_G-1 downto 0)
   );
end GigEthLvdsUltraScaleWrapper;

architecture mapping of GigEthLvdsUltraScaleWrapper is

   -- reset is asserted for 2*RST_DURATION_C
   constant RST_DURATION_C : natural range 0 to ((2**30)-1) := 156250000;

   constant NUM_CLOCKS_C   : natural := 3;

   signal sgmiiClk     : sl;
   signal refClk       : sl;
   signal refRst       : sl := '1';
   signal sysClk12NB   : sl;
   signal sysClk125    : sl;
   signal sysRst125    : sl;
   signal sysClk312    : sl;
   signal sysRst312    : sl;
   signal sysClk625    : sl;
   signal sysRst625    : sl;
   signal sysClkNB     : slv(6 downto 0);
   signal sysClkB      : slv(6 downto 0);
   signal sysRst       : slv(6 downto 0);
   signal locked       : sl;
   signal clkFb        : sl;
   signal extRstSync   : sl;
   signal refCE        : sl := '0';
   signal refRstCnt    : natural range 0 to RST_DURATION_C := RST_DURATION_C;

begin

   phyClk <= sysClk125;
   phyRst <= sysRst125;

   -----------------------------
   -- Select the Reference Clock
   -----------------------------
   IBUFGDS_SGMII : IBUFGDS
      generic map (
         DIFF_TERM    => FALSE,
         IBUF_LOW_PWR => FALSE
      )
      port map (
         I     => sgmiiClkP,
         IB    => sgmiiClkN,
         O     => sgmiiClk
      );

   refClk <= sgmiiClk when(USE_REFCLK_G = false) else sgmiiRefClk;

   -----------------
   -- Power Up Reset
   -- Timing is a bit tight for the PwrUpRst entity.
   -- Use a variant that counts at a sub-harmonic
   -- This must be accompanied by an XDC which relaxes
   -- timing by means of a multicyle path.
   -----------------
   U_RstSync : entity work.RstSync
      generic map (
         TPD_G           => TPD_G,
         IN_POLARITY_G   => '1',
         OUT_POLARITY_G  => '1'
      )
      port map (
         clk            => refClk,
         asyncRst       => extRst,
         syncRst        => extRstSync
      );

   -- don't reset refCE in order to reduce possible
   -- timing problems. This leads to uncertainty of
   -- 1 clock in the final delay which shouldn't be
   -- an issue.
   process (refClk)
   begin
      if ( rising_edge(refClk) ) then
         refCE <= not refCE;
      end if;
   end process;

   process (refClk)
   begin
      if ( rising_edge(refClk) ) then
         if ( extRstSync = '1' ) then
            refRst    <= '1' after TPD_G;
            refRstCnt <=  0  after TPD_G;
         else
            if ( refCE = '1' ) then
               if ( refRstCnt = RST_DURATION_C ) then
                  refRst    <= '0' after TPD_G;
               else
                  refRstCnt <= refRstCnt + 1 after TPD_G;
               end if;
            end if;
         end if;
      end if;
   end process;

   ----------------
   -- Clock Manager
   ----------------

   -- Generate clocks from the reference
   --  625, 312 and 125 MHz for the PCS/PMA.
   --  125MHz also is output as a general 'system clock'.
   --
   -- We also generate 12.5MHz and 1.25 MHz (the latter by
   -- cascading dividers 4+6) for different ethernet speeds.
   -- The Ethernet MAC is run at 125, 12.5 or 1.25 depending
   -- on the speed the (external) PHY has negotiated.
   -- In case this PHY indeed does support different speeds
   -- then additional (external) logic must be able to
   -- retrieve the actual speed from the PHY and set the
   -- 'speed_is_10_100/speed_is_100' signals so that we
   -- can run the MAC at the matching clock...

   -- since we don't care about a skew between the external
   -- reference and what we generate here we can omit
   -- the BUFG in the feedback chain.
   U_MMCM : MMCME3_BASE
      generic map(
         CLKOUT0_DIVIDE_F   => 5.0,
         CLKOUT1_DIVIDE     => 2,
         CLKOUT2_DIVIDE     => 1,
         CLKOUT3_DIVIDE     => 50,
         CLKOUT4_DIVIDE     => 50,
         CLKOUT4_CASCADE    => "TRUE",
         CLKOUT6_DIVIDE     => 10,
         CLKFBOUT_MULT_F    => CLKFBOUT_MULT_F_G,
         DIVCLK_DIVIDE      => DIVCLK_DIVIDE_G,
         CLKIN1_PERIOD      => CLKIN_PERIOD_G
      )
      port map (
         CLKIN1             => refClk,
         RST                => refRst,
         CLKFBIN            => clkFb,
         CLKFBOUT           => clkFb,
         CLKOUT0            => sysClkNB(0),
         CLKOUT1            => sysClkNB(1),
         CLKOUT2            => sysClkNB(2),
         CLKOUT3            => sysClkNB(3),
         CLKOUT4            => sysClkNB(4),
         CLKOUT5            => sysClkNB(5),
         CLKOUT6            => sysClkNB(6),
         LOCKED             => locked,
         PWRDWN             => '0'
      );

   GEN_BUFG : for i in 0 to NUM_CLOCKS_C - 1 generate
      U_BUFG_125 : BUFG
         port map (
            I                  => sysClkNB(i),
            O                  => sysClkB(i)
         );

      U_RESET    : entity work.RstSync
         generic map (
            TPD_G              => TPD_G,
            IN_POLARITY_G      => '0'
         )
         port map (
            clk                => sysClkB(i),
            asyncRst           => locked,
            syncRst            => sysRst(i)
         );
   end generate;

   sysClk125 <= sysClkB(0);
   sysRst125 <= sysRst (0);
   sysClk312 <= sysClkB(1);
   sysRst312 <= sysRst (1);
   sysClk625 <= sysClkB(2);
   sysRst625 <= sysRst (2);

   mmcmLocked <= locked;

   --------------
   -- Ethernet 'lanes' (in case multiple ethernets can share a common clock -- however, due to tight timing
   --                   they should probably all fit into the same clock region)
   --------------
   GEN_LANE : for i in 0 to NUM_LANE_G-1 generate
      signal ethClk      : sl;
      signal ethRst      : sl;
      signal speed_is_10 : sl;
   begin

      speed_is_10 <= speed_is_10_100(i) and not speed_is_100(i);

      -- clock mux to select the MAC core clock according to the
      -- desired speed.
      -- Note that an appropriate XDC is required (declaring physically
      -- exclusive clock groups) for correct timing of such a mux.

      -- Since the cascaded divider has a higher delay we route it
      -- through a single buffer only (have not found any spec that
      -- says how much phase shift the cascading actually introduces)
      -- hoping to balance things a bit.

      U_BUFGMUX_CASC : entity work.GigEthLvdsClockMux
         port map (
            clk125p0 => sysClkNB(0),
            clk12p50 => sysClkNB(3),
            clk1p250 => sysClkNB(4),
            sel12p50 => speed_is_10_100(i),
            sel1p250 => speed_is_10,
            O        => ethClk
         );

      -- Generate reset synchronous to the currently selected clock
      U_RESET    : entity work.RstSync
         generic map (
            TPD_G              => TPD_G,
            IN_POLARITY_G      => '0'
         )
         port map (
            clk                => ethClk,
            asyncRst           => locked,
            syncRst            => ethRst
         );

      U_GigEthLvdsUltraScale : entity work.GigEthLvdsUltraScale
         generic map (
            TPD_G            => TPD_G,
            -- AXI-Lite Configurations
            EN_AXI_REG_G     => EN_AXI_REG_G,
            -- AXI Streaming Configurations
            AXIS_CONFIG_G    => AXIS_CONFIG_G(i)
         )
         port map (
            -- Local Configurations
            localMac           => localMac(i),
            -- Streaming DMA Interface
            dmaClk             => dmaClk(i),
            dmaRst             => dmaRst(i),
            dmaIbMaster        => dmaIbMasters(i),
            dmaIbSlave         => dmaIbSlaves(i),
            dmaObMaster        => dmaObMasters(i),
            dmaObSlave         => dmaObSlaves(i),
            -- Slave AXI-Lite Interface
            axiLiteClk         => axiLiteClk(i),
            axiLiteRst         => axiLiteRst(i),
            axiLiteReadMaster  => axiLiteReadMasters(i),
            axiLiteReadSlave   => axiLiteReadSlaves(i),
            axiLiteWriteMaster => axiLiteWriteMasters(i),
            axiLiteWriteSlave  => axiLiteWriteSlaves(i),
            -- PHY + MAC signals
            ethClk             => ethClk,
            ethRst             => ethRst,
            sysClk625          => sysClk625,
            sysClk312          => sysClk312,
            sysClk125          => sysClk125,
            sysRst125          => sysRst125,
            extRst             => refRst,
            phyReady           => phyReady(i),
            sigDet             => sigDet(i),
            mmcmLocked         => locked,
            speed_is_10_100    => speed_is_10_100(i),
            speed_is_100       => speed_is_100(i),
            -- MGT Ports
            sgmiiTxP           => sgmiiTxP(i),
            sgmiiTxN           => sgmiiTxN(i),
            sgmiiRxP           => sgmiiRxP(i),
            sgmiiRxN           => sgmiiRxN(i)
         );

   end generate GEN_LANE;

end mapping;
