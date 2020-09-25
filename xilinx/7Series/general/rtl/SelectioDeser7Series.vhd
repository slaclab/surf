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

entity SelectioDeser7Series is
   generic (
      TPD_G            : time     := 1 ns;
      SIMULATION_G     : boolean  := false;
      NUM_LANE_G       : positive := 1;
      IODELAY_GROUP_G  : string   := "DESER_GROUP";
      REF_FREQ_G       : real     := 300.0;  -- IDELAYCTRL's REFCLK (in units of Hz)
      INPUT_BUFG_G     : boolean  := false;
      FB_BUFG_G        : boolean  := false;
      CLKIN_PERIOD_G   : real     := 10.0;   -- 100 MHz
      DIVCLK_DIVIDE_G  : positive := 1;
      CLKFBOUT_MULT_G  : positive := 10;     -- 1 GHz = 100 MHz x 10 / 1
      CLKOUT0_DIVIDE_G : positive := 2);     -- 500 MHz = 1 GHz/2
   port (
      -- SELECTIO Ports
      rxP             : in  slv(NUM_LANE_G-1 downto 0);
      rxN             : in  slv(NUM_LANE_G-1 downto 0);
      pllClk          : out sl;
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
end SelectioDeser7Series;

architecture mapping of SelectioDeser7Series is

   signal clkx4 : sl := '0';
   signal clkx1 : sl := '0';

   signal rstx1 : sl := '1';
   signal rstx4 : sl := '1';

begin

   pllClk   <= clkx4;
   deserClk <= clkx1;
   deserRst <= rstx1;

   U_MMCM : entity surf.ClockManager7
      generic map(
         TPD_G            => TPD_G,
         SIMULATION_G     => SIMULATION_G,
         TYPE_G           => "PLL",
         INPUT_BUFG_G     => INPUT_BUFG_G,
         FB_BUFG_G        => FB_BUFG_G,
         NUM_CLOCKS_G     => 2,
         CLKIN_PERIOD_G   => CLKIN_PERIOD_G,
         DIVCLK_DIVIDE_G  => DIVCLK_DIVIDE_G,
         CLKFBOUT_MULT_G  => CLKFBOUT_MULT_G,
         CLKOUT0_DIVIDE_G => CLKOUT0_DIVIDE_G,
         CLKOUT1_DIVIDE_G => 4*CLKOUT0_DIVIDE_G)
      port map(
         clkIn           => refClk,
         rstIn           => refRst,
         -- Clock Outputs
         clkOut(0)       => clkx4,
         clkOut(1)       => clkx1,
         -- Reset Outputs
         rstOut(0)       => rstx4,
         rstOut(1)       => rstx1,
         -- AXI-Lite Port
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

   GEN_VEC :
   for i in NUM_LANE_G-1 downto 0 generate

      U_Lane : entity surf.SelectioDeserLane7Series
         generic map (
            TPD_G           => TPD_G,
            IODELAY_GROUP_G => IODELAY_GROUP_G,
            REF_FREQ_G      => REF_FREQ_G)
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
