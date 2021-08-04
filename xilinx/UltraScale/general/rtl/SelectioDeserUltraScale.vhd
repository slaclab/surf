-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PLL and Deserialization
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

library unisim;
use unisim.vcomponents.all;

entity SelectioDeserUltraScale is
   generic (
      TPD_G            : time     := 1 ns;
      SIMULATION_G     : boolean  := false;
      SIM_DEVICE_G     : string   := "ULTRASCALE";
      EXT_PLL_G        : boolean  := false;
      NUM_LANE_G       : positive := 1;
      CLKIN_PERIOD_G   : real     := 10.0;  -- 100 MHz
      DIVCLK_DIVIDE_G  : positive := 1;
      CLKFBOUT_MULT_G  : positive := 10;    -- 1 GHz = 100 MHz x 10 / 1
      CLKOUT0_DIVIDE_G : positive := 2);    -- 500 MHz = 1 GHz/2
   port (
      -- SELECTIO Ports
      rxP             : in  slv(NUM_LANE_G-1 downto 0);
      rxN             : in  slv(NUM_LANE_G-1 downto 0);
      pllClk          : out sl;
      -- External PLL Interface
      extPllClkIn     : in  sl                     := '0';
      extPllRstIn     : in  sl                     := '1';
      -- Reference Clock and Reset
      refClk          : in  sl;
      refRst          : in  sl;
      -- Deserialization Interface (deserClk domain)
      deserClk        : out sl;
      deserRst        : out sl;
      deserData       : out Slv8Array(NUM_LANE_G-1 downto 0);
      dlyLoad         : in  slv(NUM_LANE_G-1 downto 0);
      dlyCfg          : in  Slv9Array(NUM_LANE_G-1 downto 0);
      -- AXI-Lite Interface (axilClk domain)
      axilClk         : in  sl                     := '0';
      axilRst         : in  sl                     := '0';
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end SelectioDeserUltraScale;

architecture mapping of SelectioDeserUltraScale is

   signal drpRdy  : sl;
   signal drpEn   : sl;
   signal drpWe   : sl;
   signal drpAddr : slv(6 downto 0);
   signal drpDi   : slv(15 downto 0);
   signal drpDo   : slv(15 downto 0);

   signal locked  : sl := '0';
   signal clkFb   : sl := '0';
   signal clkout0 : sl := '0';

   signal clkx4 : sl := '0';
   signal clkx1 : sl := '0';
   signal reset : sl := '1';
   signal rstx1 : sl := '1';

begin

   pllClk   <= clkx4;
   deserClk <= clkx1;
   deserRst <= rstx1;

   GEN_INT_PLL : if (EXT_PLL_G = false) generate

      GEN_REAL : if (SIMULATION_G = false) generate

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
               drpDo           => drpDo);

         U_PLL : PLLE3_ADV
            generic map (
               COMPENSATION   => "INTERNAL",
               STARTUP_WAIT   => "FALSE",
               CLKIN_PERIOD   => CLKIN_PERIOD_G,
               DIVCLK_DIVIDE  => DIVCLK_DIVIDE_G,
               CLKFBOUT_MULT  => CLKFBOUT_MULT_G,
               CLKOUT0_DIVIDE => CLKOUT0_DIVIDE_G)
            port map (
               DCLK        => axilClk,
               DRDY        => drpRdy,
               DEN         => drpEn,
               DWE         => drpWe,
               DADDR       => drpAddr,
               DI          => drpDi,
               DO          => drpDo,
               PWRDWN      => '0',
               RST         => refRst,
               CLKIN       => refClk,
               CLKOUTPHYEN => '0',
               CLKFBOUT    => clkFb,
               CLKFBIN     => clkFb,
               LOCKED      => locked,
               CLKOUT0     => clkout0,
               CLKOUT1     => open);

      end generate GEN_REAL;

      GEN_SIM : if (SIMULATION_G = true) generate

         axilReadSlave  <= AXI_LITE_READ_SLAVE_EMPTY_DECERR_C;
         axilWriteSlave <= AXI_LITE_WRITE_SLAVE_EMPTY_DECERR_C;

         U_ClkRst : entity surf.ClkRst
            generic map (
               CLK_PERIOD_G      => (CLKIN_PERIOD_G*DIVCLK_DIVIDE_G*CLKOUT0_DIVIDE_G/CLKFBOUT_MULT_G)*(1.0 ns),
               RST_START_DELAY_G => 0 ns,
               RST_HOLD_TIME_G   => 1000 ns)
            port map (
               clkP => clkout0,
               rstL => locked);

      end generate GEN_SIM;

      U_Bufg640 : BUFG
         port map (
            I => clkout0,
            O => clkx4);

   end generate GEN_INT_PLL;

   GEN_EXT_PLL : if (EXT_PLL_G = true) generate
      clkx4   <= extPllClkIn;
      clkout0 <= extPllClkIn;
      locked  <= not(extPllRstIn);
   end generate GEN_EXT_PLL;

   ------------------------------------------------------------------------------------------------------
   -- clkx1 is the ISERDESE3/OSERDESE3's CLKDIV port
   -- Refer to "Figure 3-49: Sub-Optimal to Optimal Clocking Topologies for OSERDESE3" in UG949 (v2018.2)
   -- https://www.xilinx.com/support/answers/67885.html
   ------------------------------------------------------------------------------------------------------
   U_Bufg : BUFGCE_DIV
      generic map (
         BUFGCE_DIVIDE => 4)
      port map (
         I   => clkout0,
         CE  => '1',
         CLR => '0',
         O   => clkx1);

   U_reset : entity surf.RstSync
      generic map (
         TPD_G          => TPD_G,
         IN_POLARITY_G  => '0',
         OUT_POLARITY_G => '1')
      port map (
         clk      => clkx1,
         asyncRst => locked,
         syncRst  => reset);

   U_rstx1 : entity surf.RstPipeline
      generic map (
         TPD_G => TPD_G)
      port map (
         clk    => clkx1,
         rstIn  => reset,
         rstOut => rstx1);

   GEN_VEC :
   for i in NUM_LANE_G-1 downto 0 generate

      U_Lane : entity surf.SelectioDeserLaneUltraScale
         generic map (
            TPD_G        => TPD_G,
            SIM_DEVICE_G => SIM_DEVICE_G)
         port map (
            -- SELECTIO Ports
            rxP     => rxP(i),
            rxN     => rxN(i),
            -- Clock and Reset Interface
            clkx4   => clkx4,
            clkx1   => clkx1,
            rstx1   => rstx1,
            -- Delay Configuration
            dlyLoad => dlyLoad(i),
            dlyCfg  => dlyCfg(i),
            -- Output
            dataOut => deserData(i));

   end generate GEN_VEC;

end mapping;
