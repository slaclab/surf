-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: A wrapper over PLL/MMCM/DPLL to avoid coregen use.
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

library unisim;
use unisim.vcomponents.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

entity ClockManagerVersal is
   generic (
      TPD_G                  : time                       := 1 ns;
      SIMULATION_G           : boolean                    := false;
      TYPE_G                 : string                     := "PLL";  -- or "MMCM" or "DPLL"
      INPUT_BUFG_G           : boolean                    := true;
      FB_BUFG_G              : boolean                    := true;
      RST_IN_POLARITY_G      : sl                         := '1';  -- '0' for active low
      NUM_CLOCKS_G           : integer range 1 to 7       := 4;
      -- MMCM attributes
      CLKIN_PERIOD_G         : real                       := 10.0;  -- Input clock period in ns to ps resolution (i.e., 33.333 is 30 MHz)
      -- VCO Generics
      BANDWIDTH_G            : string                     := "OPTIMIZED";  -- MMCM Only: HIGH, LOW, OPTIMIZED
      DIVCLK_DIVIDE_G        : integer range 1 to 122     := 1;  -- Master division value
      CLKFBOUT_MULT_G        : integer range 4 to 432     := 42;  -- Multiply value for all CLKOUT
      CLKFBOUT_FRACT_G       : integer range 0 to 63      := 0;  -- MMCM/DPLL Only: 6-bit fraction M feedback divider
      -- Clock Output Divide
      CLKOUT0_DIVIDE_G       : integer range 2 to 511     := 2;
      CLKOUT1_DIVIDE_G       : integer range 2 to 511     := 2;
      CLKOUT2_DIVIDE_G       : integer range 2 to 511     := 2;
      CLKOUT3_DIVIDE_G       : integer range 2 to 511     := 2;
      CLKOUT4_DIVIDE_G       : integer range 2 to 511     := 2;
      CLKOUT5_DIVIDE_G       : integer range 2 to 511     := 2;
      CLKOUT6_DIVIDE_G       : integer range 2 to 511     := 2;
      -- Clock Output Phase
      CLKOUT0_PHASE_G        : real range -360.0 to 360.0 := 0.0;
      CLKOUT1_PHASE_G        : real range -360.0 to 360.0 := 0.0;
      CLKOUT2_PHASE_G        : real range -360.0 to 360.0 := 0.0;
      CLKOUT3_PHASE_G        : real range -360.0 to 360.0 := 0.0;
      CLKOUT4_PHASE_G        : real range -360.0 to 360.0 := 0.0;
      CLKOUT5_PHASE_G        : real range -360.0 to 360.0 := 0.0;
      CLKOUT6_PHASE_G        : real range -360.0 to 360.0 := 0.0;
      -- Clock Output Duty Cycle (PLL and MMCM only)
      CLKOUT0_DUTY_CYCLE_G   : real range 0.01 to 0.99    := 0.5;
      CLKOUT1_DUTY_CYCLE_G   : real range 0.01 to 0.99    := 0.5;
      CLKOUT2_DUTY_CYCLE_G   : real range 0.01 to 0.99    := 0.5;
      CLKOUT3_DUTY_CYCLE_G   : real range 0.01 to 0.99    := 0.5;
      CLKOUT4_DUTY_CYCLE_G   : real range 0.01 to 0.99    := 0.5;
      CLKOUT5_DUTY_CYCLE_G   : real range 0.01 to 0.99    := 0.5;
      CLKOUT6_DUTY_CYCLE_G   : real range 0.01 to 0.99    := 0.5;
      -- Reset Output Hold
      CLKOUT0_RST_HOLD_G     : integer range 3 to (2**24) := 3;
      CLKOUT1_RST_HOLD_G     : integer range 3 to (2**24) := 3;
      CLKOUT2_RST_HOLD_G     : integer range 3 to (2**24) := 3;
      CLKOUT3_RST_HOLD_G     : integer range 3 to (2**24) := 3;
      CLKOUT4_RST_HOLD_G     : integer range 3 to (2**24) := 3;
      CLKOUT5_RST_HOLD_G     : integer range 3 to (2**24) := 3;
      CLKOUT6_RST_HOLD_G     : integer range 3 to (2**24) := 3;
      -- Reset Output Polariy
      CLKOUT0_RST_POLARITY_G : sl                         := '1';
      CLKOUT1_RST_POLARITY_G : sl                         := '1';
      CLKOUT2_RST_POLARITY_G : sl                         := '1';
      CLKOUT3_RST_POLARITY_G : sl                         := '1';
      CLKOUT4_RST_POLARITY_G : sl                         := '1';
      CLKOUT5_RST_POLARITY_G : sl                         := '1';
      CLKOUT6_RST_POLARITY_G : sl                         := '1');
   port (
      clkIn           : in  sl;
      rstIn           : in  sl                     := '0';
      clkOut          : out slv(NUM_CLOCKS_G-1 downto 0);
      rstOut          : out slv(NUM_CLOCKS_G-1 downto 0);
      locked          : out sl;
      -- AXI-Lite Interface
      axilClk         : in  sl                     := '0';
      axilRst         : in  sl                     := '0';
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end entity ClockManagerVersal;

architecture rtl of ClockManagerVersal is

   constant RST_HOLD_C : IntegerArray(0 to 6) := (
      CLKOUT0_RST_HOLD_G, CLKOUT1_RST_HOLD_G, CLKOUT2_RST_HOLD_G, CLKOUT3_RST_HOLD_G,
      CLKOUT4_RST_HOLD_G, CLKOUT5_RST_HOLD_G, CLKOUT6_RST_HOLD_G);

   constant RST_POLARITY_C : slv(0 to 6) := (
      CLKOUT0_RST_POLARITY_G, CLKOUT1_RST_POLARITY_G, CLKOUT2_RST_POLARITY_G, CLKOUT3_RST_POLARITY_G,
      CLKOUT4_RST_POLARITY_G, CLKOUT5_RST_POLARITY_G, CLKOUT6_RST_POLARITY_G);

   signal rstInLoc   : sl;
   signal clkInLoc   : sl;
   signal lockedLoc  : sl;
   signal clkOutMmcm : slv(6 downto 0) := (others => '0');
   signal clkOutLoc  : slv(6 downto 0) := (others => '0');
   signal clkFbOut   : sl;
   signal clkFbIn    : sl;

   signal drpRdy  : sl;
   signal drpEn   : sl;
   signal drpWe   : sl;
   signal drpAddr : slv(6 downto 0);
   signal drpDi   : slv(15 downto 0);
   signal drpDo   : slv(15 downto 0) := (others => '0');
   signal drpDo01 : slv(15 downto 0) := (others => '0');

   attribute keep_hierarchy        : string;
   attribute keep_hierarchy of rtl : architecture is "yes";

begin

   assert (TYPE_G = "MMCM" or (TYPE_G = "PLL" and NUM_CLOCKS_G <= 4)or (TYPE_G = "DPLL" and NUM_CLOCKS_G <= 4))
      report "ClockManagerVersal(TYPE_G=PLL/DPLL): Cannot have more than 4 clock outputs" severity failure;

   assert (TYPE_G = "MMCM" or TYPE_G = "PLL" or TYPE_G = "DPLL")
      report "ClockManagerVersal: TYPE_G must be either PLL or MMCM or DPLL" severity failure;

   rstInLoc <= '1' when rstIn = RST_IN_POLARITY_G else '0';

   U_AxiLiteToDrp : entity surf.AxiLiteToDrp
      generic map (
         TPD_G            => TPD_G,
         COMMON_CLK_G     => true,
         EN_ARBITRATION_G => false,
         TIMEOUT_G        => 4096,
         ADDR_WIDTH_G     => 7,
         DATA_WIDTH_G     => 16)
      port map (
         -- AXI-Lite Port
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave,
         -- DRP Interface
         drpClk          => axilClk,
         drpRst          => axilRst,
         drpRdy          => drpRdy,
         drpEn           => drpEn,
         drpWe           => drpWe,
         drpAddr         => drpAddr,
         drpDi           => drpDi,
         drpDo           => drpDo01);

   drpDo01 <= to_stdLogicVector(to_bitvector(drpDo));

   MmcmGen : if (TYPE_G = "MMCM") and (SIMULATION_G = false) generate
      U_Mmcm : MMCME5
         generic map (
            -- Input Clock
            CLKIN1_PERIOD      => CLKIN_PERIOD_G,  -- Input clock period in ns to ps resolution (i.e., 33.333 is 30 MHz).
            COMPENSATION       => "AUTO",          -- Clock input compensation
            -- VCO Generics
            BANDWIDTH          => BANDWIDTH_G,     -- HIGH, LOW, OPTIMIZED
            DIVCLK_DIVIDE      => DIVCLK_DIVIDE_G,  -- Master division value
            CLKFBOUT_MULT      => CLKFBOUT_MULT_G,  -- Multiply value for all CLKOUT, (4-432)
            CLKFBOUT_FRACT     => CLKFBOUT_FRACT_G,  -- 6-bit fraction M feedback divider (0-63)
            -- Output Divide
            CLKOUT0_DIVIDE     => CLKOUT0_DIVIDE_G,
            CLKOUT1_DIVIDE     => CLKOUT1_DIVIDE_G,
            CLKOUT2_DIVIDE     => CLKOUT2_DIVIDE_G,
            CLKOUT3_DIVIDE     => CLKOUT3_DIVIDE_G,
            CLKOUT4_DIVIDE     => CLKOUT4_DIVIDE_G,
            CLKOUT5_DIVIDE     => CLKOUT5_DIVIDE_G,
            CLKOUT6_DIVIDE     => CLKOUT6_DIVIDE_G,
            -- Phase
            CLKOUT0_PHASE      => CLKOUT0_PHASE_G,
            CLKOUT1_PHASE      => CLKOUT1_PHASE_G,
            CLKOUT2_PHASE      => CLKOUT2_PHASE_G,
            CLKOUT3_PHASE      => CLKOUT3_PHASE_G,
            CLKOUT4_PHASE      => CLKOUT4_PHASE_G,
            CLKOUT5_PHASE      => CLKOUT5_PHASE_G,
            CLKOUT6_PHASE      => CLKOUT6_PHASE_G,
            -- Duty Cycle
            CLKOUT0_DUTY_CYCLE => CLKOUT0_DUTY_CYCLE_G,
            CLKOUT1_DUTY_CYCLE => CLKOUT1_DUTY_CYCLE_G,
            CLKOUT2_DUTY_CYCLE => CLKOUT2_DUTY_CYCLE_G,
            CLKOUT3_DUTY_CYCLE => CLKOUT3_DUTY_CYCLE_G,
            CLKOUT4_DUTY_CYCLE => CLKOUT4_DUTY_CYCLE_G,
            CLKOUT5_DUTY_CYCLE => CLKOUT5_DUTY_CYCLE_G,
            CLKOUT6_DUTY_CYCLE => CLKOUT6_DUTY_CYCLE_G)
         port map (
            CLKFBOUT       => clkFbOut,  -- 1-bit output: Feedback clock
            CLKFBSTOPPED   => open,     -- 1-bit output: Feedback clock stopped
            CLKINSTOPPED   => open,     -- 1-bit output: Input clock stopped
            CLKOUT0        => clkOutMmcm(0),       -- 1-bit output: CLKOUT0
            CLKOUT1        => clkOutMmcm(1),       -- 1-bit output: CLKOUT1
            CLKOUT2        => clkOutMmcm(2),       -- 1-bit output: CLKOUT2
            CLKOUT3        => clkOutMmcm(3),       -- 1-bit output: CLKOUT3
            CLKOUT4        => clkOutMmcm(4),       -- 1-bit output: CLKOUT4
            CLKOUT5        => clkOutMmcm(5),       -- 1-bit output: CLKOUT5
            CLKOUT6        => clkOutMmcm(6),       -- 1-bit output: CLKOUT6
            DO             => drpDo,    -- 16-bit output: DRP data output
            DRDY           => drpRdy,   -- 1-bit output: DRP ready
            LOCKED         => lockedLoc,           -- 1-bit output: LOCK
            LOCKED1_DESKEW => open,     -- 1-bit output: LOCK DESKEW PD1
            LOCKED2_DESKEW => open,     -- 1-bit output: LOCK DESKEW PD2
            LOCKED_FB      => open,     -- 1-bit output: LOCK FEEDBACK
            PSDONE         => open,     -- 1-bit output: Phase shift done
            CLKFB1_DESKEW  => '0',  -- 1-bit input: Secondary clock input to PD1
            CLKFB2_DESKEW  => '0',  -- 1-bit input: Secondary clock input to PD2
            CLKFBIN        => clkFbIn,  -- 1-bit input: Feedback clock
            CLKIN1         => clkInLoc,  -- 1-bit input: Primary clock
            CLKIN1_DESKEW  => '0',  -- 1-bit input: Primary clock input to PD1
            CLKIN2         => '0',
            CLKIN2_DESKEW  => '0',  -- 1-bit input: Primary clock input to PD2
            CLKINSEL       => '1',  -- 1-bit input: Clock select, High=CLKIN1 Low=CLKIN2
            DADDR          => drpAddr,  -- 7-bit input: DRP address
            DCLK           => axilClk,  -- 1-bit input: DRP clock
            DEN            => drpEn,    -- 1-bit input: DRP enable
            DI             => drpDi,    -- 16-bit input: DRP data input
            DWE            => drpWe,    -- 1-bit input: DRP write enable
            PSCLK          => '0',      -- 1-bit input: Phase shift clock
            PSEN           => '0',      -- 1-bit input: Phase shift enable
            PSINCDEC       => '0',  -- 1-bit input: Phase shift increment/decrement
            PWRDWN         => '0',      -- 1-bit input: Power-down
            RST            => rstInLoc);           -- 1-bit input: Reset
   end generate MmcmGen;

   MmcmEmu : if (TYPE_G = "MMCM") and (SIMULATION_G = true) generate
      U_Mmcm : entity surf.MmcmEmulation
         generic map (
            -- Input Clock
            CLKIN_PERIOD_G       => CLKIN_PERIOD_G,
            -- VCO Generics
            DIVCLK_DIVIDE_G      => DIVCLK_DIVIDE_G,
            CLKFBOUT_MULT_F_G    => -1.0,  -- TODO: Need to include CLKFBOUT_FRACT_G information to simulation
            -- Output Divide
            CLKOUT0_DIVIDE_F_G   => real(CLKOUT0_DIVIDE_G),
            CLKOUT1_DIVIDE_G     => CLKOUT1_DIVIDE_G,
            CLKOUT2_DIVIDE_G     => CLKOUT2_DIVIDE_G,
            CLKOUT3_DIVIDE_G     => CLKOUT3_DIVIDE_G,
            CLKOUT4_DIVIDE_G     => CLKOUT4_DIVIDE_G,
            CLKOUT5_DIVIDE_G     => CLKOUT5_DIVIDE_G,
            CLKOUT6_DIVIDE_G     => CLKOUT6_DIVIDE_G,
            -- Phase
            CLKOUT0_PHASE_G      => CLKOUT0_PHASE_G,
            CLKOUT1_PHASE_G      => CLKOUT1_PHASE_G,
            CLKOUT2_PHASE_G      => CLKOUT2_PHASE_G,
            CLKOUT3_PHASE_G      => CLKOUT3_PHASE_G,
            CLKOUT4_PHASE_G      => CLKOUT4_PHASE_G,
            CLKOUT5_PHASE_G      => CLKOUT5_PHASE_G,
            CLKOUT6_PHASE_G      => CLKOUT6_PHASE_G,
            -- Duty Cycle
            CLKOUT0_DUTY_CYCLE_G => CLKOUT0_DUTY_CYCLE_G,
            CLKOUT1_DUTY_CYCLE_G => CLKOUT1_DUTY_CYCLE_G,
            CLKOUT2_DUTY_CYCLE_G => CLKOUT2_DUTY_CYCLE_G,
            CLKOUT3_DUTY_CYCLE_G => CLKOUT3_DUTY_CYCLE_G,
            CLKOUT4_DUTY_CYCLE_G => CLKOUT4_DUTY_CYCLE_G,
            CLKOUT5_DUTY_CYCLE_G => CLKOUT5_DUTY_CYCLE_G,
            CLKOUT6_DUTY_CYCLE_G => CLKOUT6_DUTY_CYCLE_G)
         port map (
            CLKIN   => clkInLoc,
            RST     => rstInLoc,
            LOCKED  => lockedLoc,
            CLKOUT0 => clkOutMmcm(0),
            CLKOUT1 => clkOutMmcm(1),
            CLKOUT2 => clkOutMmcm(2),
            CLKOUT3 => clkOutMmcm(3),
            CLKOUT4 => clkOutMmcm(4),
            CLKOUT5 => clkOutMmcm(5),
            CLKOUT6 => clkOutMmcm(6));
      drpRdy <= '1';
      drpDo  <= (others => '1');
   end generate MmcmEmu;

   PllGen : if (TYPE_G = "PLL") and (SIMULATION_G = false) generate
      U_Pll : XPLL
         generic map (
            -- Input Clock
            CLKIN_PERIOD       => CLKIN_PERIOD_G,  -- Input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz)
            -- VCO Generics
            DIVCLK_DIVIDE      => DIVCLK_DIVIDE_G,  -- Master division value
            CLKFBOUT_MULT      => CLKFBOUT_MULT_G,  -- Multiply value for all CLKOUT, (4-43)
            -- Output Divide
            CLKOUT0_DIVIDE     => CLKOUT0_DIVIDE_G,
            CLKOUT1_DIVIDE     => CLKOUT1_DIVIDE_G,
            CLKOUT2_DIVIDE     => CLKOUT2_DIVIDE_G,
            CLKOUT3_DIVIDE     => CLKOUT3_DIVIDE_G,
            -- Phase
            CLKOUT0_PHASE      => CLKOUT0_PHASE_G,
            CLKOUT1_PHASE      => CLKOUT1_PHASE_G,
            CLKOUT2_PHASE      => CLKOUT2_PHASE_G,
            CLKOUT3_PHASE      => CLKOUT3_PHASE_G,
            -- Duty Cycle
            CLKOUT0_DUTY_CYCLE => CLKOUT0_DUTY_CYCLE_G,
            CLKOUT1_DUTY_CYCLE => CLKOUT1_DUTY_CYCLE_G,
            CLKOUT2_DUTY_CYCLE => CLKOUT2_DUTY_CYCLE_G,
            CLKOUT3_DUTY_CYCLE => CLKOUT3_DUTY_CYCLE_G)
         port map (
            RIU_RD_DATA        => open,
            RIU_VALID          => open,
            RIU_ADDR           => (others => '0'),
            RIU_CLK            => '0',
            RIU_NIBBLE_SEL     => '0',
            RIU_WR_DATA        => (others => '0'),
            RIU_WR_EN          => '0',
            CLKOUT0            => clkOutMmcm(0),   -- 1-bit output: CLKOUT0
            CLKOUT1            => clkOutMmcm(1),   -- 1-bit output: CLKOUT1
            CLKOUT2            => clkOutMmcm(2),   -- 1-bit output: CLKOUT2
            CLKOUT3            => clkOutMmcm(3),   -- 1-bit output: CLKOUT3
            CLKOUTPHY          => open,  -- 1-bit output: XPHY Logic clock
            CLKOUTPHY_CASC_OUT => open,  -- 1-bit output: XPLL CLKOUTPHY cascade output
            DO                 => drpDo,     -- 16-bit output: DRP data output
            DRDY               => drpRdy,    -- 1-bit output: DRP ready
            LOCKED             => lockedLoc,       -- 1-bit output: LOCK
            LOCKED1_DESKEW     => open,  -- 1-bit output: LOCK DESKEW PD1
            LOCKED2_DESKEW     => open,  -- 1-bit output: LOCK DESKEW PD2
            LOCKED_FB          => open,  -- 1-bit output: LOCK FEEDBACK
            PSDONE             => open,  -- 1-bit output: Phase shift done
            CLKFB1_DESKEW      => '0',  -- 1-bit input: Secondary clock input to PD1
            CLKFB2_DESKEW      => '0',  -- 1-bit input: Secondary clock input to PD2
            CLKIN              => clkInLoc,  -- 1-bit input: Primary clock
            CLKIN1_DESKEW      => '0',  -- 1-bit input: Primary clock input to PD1
            CLKIN2_DESKEW      => '0',  -- 1-bit input: Primary clock input to PD2
            CLKOUTPHYEN        => '0',  -- 1-bit input: CLKOUTPHY enable
            CLKOUTPHY_CASC_IN  => '0',  -- 1-bit input: XPLL CLKOUTPHY cascade input
            DADDR              => drpAddr,   -- 7-bit input: DRP address
            DCLK               => axilClk,   -- 1-bit input: DRP clock
            DEN                => drpEn,     -- 1-bit input: DRP enable
            DI                 => drpDi,     -- 16-bit input: DRP data input
            DWE                => drpWe,     -- 1-bit input: DRP write enable
            PSCLK              => '0',  -- 1-bit input: Phase shift clock
            PSEN               => '0',  -- 1-bit input: Phase shift enable
            PSINCDEC           => '0',  -- 1-bit input: Phase shift increment/decrement
            PWRDWN             => '0',  -- 1-bit input: Power-down
            RST                => rstInLoc);       -- 1-bit input: Reset
   end generate PllGen;

   PllEmu : if (TYPE_G = "PLL") and (SIMULATION_G = true) generate
      U_Pll : entity surf.MmcmEmulation
         generic map (
            -- Input Clock
            CLKIN_PERIOD_G       => CLKIN_PERIOD_G,
            -- VCO Generics
            DIVCLK_DIVIDE_G      => DIVCLK_DIVIDE_G,
            CLKFBOUT_MULT_F_G    => real(CLKFBOUT_MULT_G),
            -- Output Divide
            CLKOUT0_DIVIDE_F_G   => real(CLKOUT0_DIVIDE_G),
            CLKOUT1_DIVIDE_G     => CLKOUT1_DIVIDE_G,
            CLKOUT2_DIVIDE_G     => CLKOUT2_DIVIDE_G,
            CLKOUT3_DIVIDE_G     => CLKOUT3_DIVIDE_G,
            -- Phase
            CLKOUT0_PHASE_G      => CLKOUT0_PHASE_G,
            CLKOUT1_PHASE_G      => CLKOUT1_PHASE_G,
            CLKOUT2_PHASE_G      => CLKOUT2_PHASE_G,
            CLKOUT3_PHASE_G      => CLKOUT3_PHASE_G,
            -- Duty Cycle
            CLKOUT0_DUTY_CYCLE_G => CLKOUT0_DUTY_CYCLE_G,
            CLKOUT1_DUTY_CYCLE_G => CLKOUT1_DUTY_CYCLE_G,
            CLKOUT2_DUTY_CYCLE_G => CLKOUT2_DUTY_CYCLE_G,
            CLKOUT3_DUTY_CYCLE_G => CLKOUT3_DUTY_CYCLE_G)
         port map (
            CLKIN   => clkInLoc,
            RST     => rstInLoc,
            LOCKED  => lockedLoc,
            CLKOUT0 => clkOutMmcm(0),
            CLKOUT1 => clkOutMmcm(1),
            CLKOUT2 => clkOutMmcm(2),
            CLKOUT3 => clkOutMmcm(3));
      drpRdy <= '1';
      drpDo  <= (others => '1');
   end generate PllEmu;

   DPllGen : if (TYPE_G = "DPLL") and (SIMULATION_G = false) generate
      U_DPll : DPLL
         generic map (
            -- Input Clock
            CLKIN_PERIOD   => CLKIN_PERIOD_G,  -- Input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz)
            -- VCO Generics
            DIVCLK_DIVIDE  => DIVCLK_DIVIDE_G,  -- Master division value
            CLKFBOUT_MULT  => CLKFBOUT_MULT_G,  -- Multiply value for all CLKOUT, (10-400)
            CLKFBOUT_FRACT => CLKFBOUT_FRACT_G,  -- 6-bit fraction M feedback divider (0-63)
            -- Output Divide
            CLKOUT0_DIVIDE => CLKOUT0_DIVIDE_G,
            CLKOUT1_DIVIDE => CLKOUT1_DIVIDE_G,
            CLKOUT2_DIVIDE => CLKOUT2_DIVIDE_G,
            CLKOUT3_DIVIDE => CLKOUT3_DIVIDE_G,
            -- Phase
            CLKOUT0_PHASE  => CLKOUT0_PHASE_G,
            CLKOUT1_PHASE  => CLKOUT1_PHASE_G,
            CLKOUT2_PHASE  => CLKOUT2_PHASE_G,
            CLKOUT3_PHASE  => CLKOUT3_PHASE_G)
         port map (
            CLKOUT0       => clkOutMmcm(0),    -- 1-bit output: CLKOUT0
            CLKOUT1       => clkOutMmcm(1),    -- 1-bit output: CLKOUT1
            CLKOUT2       => clkOutMmcm(2),    -- 1-bit output: CLKOUT2
            CLKOUT3       => clkOutMmcm(3),    -- 1-bit output: CLKOUT3
            DO            => drpDo,     -- 16-bit output: DRP data output
            DRDY          => drpRdy,    -- 1-bit output: DRP ready
            LOCKED        => lockedLoc,        -- 1-bit output: LOCK
            LOCKED_DESKEW => open,      -- 1-bit output: LOCK DESKEW
            LOCKED_FB     => open,      -- 1-bit output: LOCK FEEDBACK
            PSDONE        => open,      -- 1-bit output: Phase shift done
            CLKFB_DESKEW  => '0',  -- 1-bit input: Secondary clock input to PD
            CLKIN         => clkInLoc,  -- 1-bit input: Primary clock
            CLKIN_DESKEW  => '0',  -- 1-bit input: Primary clock input to PD
            DADDR         => drpAddr,   -- 7-bit input: DRP address
            DCLK          => axilClk,   -- 1-bit input: DRP clock
            DEN           => drpEn,     -- 1-bit input: DRP enable
            DI            => drpDi,     -- 16-bit input: DRP data input
            DWE           => drpWe,     -- 1-bit input: DRP write enable
            PSCLK         => '0',       -- 1-bit input: Phase shift clock
            PSEN          => '0',       -- 1-bit input: Phase shift enable
            PSINCDEC      => '0',  -- 1-bit input: Phase shift increment/decrement
            PWRDWN        => '0',       -- 1-bit input: Power-down
            RST           => rstInLoc);        -- 1-bit input: Reset
   end generate DPllGen;

   DPllEmu : if (TYPE_G = "DPLL") and (SIMULATION_G = true) generate
      U_DPll : entity surf.MmcmEmulation
         generic map (
            -- Input Clock
            CLKIN_PERIOD_G       => CLKIN_PERIOD_G,
            -- VCO Generics
            DIVCLK_DIVIDE_G      => DIVCLK_DIVIDE_G,
            CLKFBOUT_MULT_F_G    => -1.0,  -- TODO: Need to include CLKFBOUT_FRACT_G information to simulation
            -- Output Divide
            CLKOUT0_DIVIDE_F_G   => real(CLKOUT0_DIVIDE_G),
            CLKOUT1_DIVIDE_G     => CLKOUT1_DIVIDE_G,
            CLKOUT2_DIVIDE_G     => CLKOUT2_DIVIDE_G,
            CLKOUT3_DIVIDE_G     => CLKOUT3_DIVIDE_G,
            -- Phase
            CLKOUT0_PHASE_G      => CLKOUT0_PHASE_G,
            CLKOUT1_PHASE_G      => CLKOUT1_PHASE_G,
            CLKOUT2_PHASE_G      => CLKOUT2_PHASE_G,
            CLKOUT3_PHASE_G      => CLKOUT3_PHASE_G,
            -- Duty Cycle
            CLKOUT0_DUTY_CYCLE_G => CLKOUT0_DUTY_CYCLE_G,
            CLKOUT1_DUTY_CYCLE_G => CLKOUT1_DUTY_CYCLE_G,
            CLKOUT2_DUTY_CYCLE_G => CLKOUT2_DUTY_CYCLE_G,
            CLKOUT3_DUTY_CYCLE_G => CLKOUT3_DUTY_CYCLE_G)
         port map (
            CLKIN   => clkInLoc,
            RST     => rstInLoc,
            LOCKED  => lockedLoc,
            CLKOUT0 => clkOutMmcm(0),
            CLKOUT1 => clkOutMmcm(1),
            CLKOUT2 => clkOutMmcm(2),
            CLKOUT3 => clkOutMmcm(3));
      drpRdy <= '1';
      drpDo  <= (others => '1');
   end generate DPllEmu;

   InputBufgGen : if (INPUT_BUFG_G) generate
      U_Bufg : BUFG
         port map (
            I => clkIn,
            O => clkInLoc);
   end generate;

   InputNoBufg : if (not INPUT_BUFG_G) generate
      clkInLoc <= clkIn;
   end generate;

   FbBufgGen : if (FB_BUFG_G) generate
      U_Bufg : BUFG
         port map (
            I => clkFbOut,
            O => clkFbIn);
   end generate;

   FbNoBufg : if (not FB_BUFG_G) generate
      clkFbIn <= clkFbOut;
   end generate;

   ClkOutGen : for i in NUM_CLOCKS_G-1 downto 0 generate
      U_Bufg : BUFG
         port map (
            I => clkOutMmcm(i),
            O => clkOutLoc(i));
      clkOut(i) <= clkOutLoc(i);
   end generate;

   locked <= lockedLoc;

   RstOutGen : for i in NUM_CLOCKS_G-1 downto 0 generate
      RstSync_1 : entity surf.RstSync
         generic map (
            TPD_G           => TPD_G,
            IN_POLARITY_G   => '0',
            OUT_POLARITY_G  => RST_POLARITY_C(i),
            BYPASS_SYNC_G   => false,
            RELEASE_DELAY_G => RST_HOLD_C(i))
         port map (
            clk      => clkOutLoc(i),
            asyncRst => lockedLoc,
            syncRst  => rstOut(i));
   end generate;

end architecture rtl;
