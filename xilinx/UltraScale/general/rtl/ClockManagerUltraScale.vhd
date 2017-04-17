-------------------------------------------------------------------------------
-- File       : ClockManagerUltraScale.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-09
-- Last update: 2016-08-24
-------------------------------------------------------------------------------
-- Description: A wrapper over MMCM/PLL to avoid coregen use.
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

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

entity ClockManagerUltraScale is
   generic (
      TPD_G                  : time                             := 1 ns;
      TYPE_G                 : string                           := "MMCM";  -- or "PLL"
      INPUT_BUFG_G           : boolean                          := true;
      FB_BUFG_G              : boolean                          := true;
      RST_IN_POLARITY_G      : sl                               := '1';     -- '0' for active low
      NUM_CLOCKS_G           : integer range 1 to 7;
      AXI_ERROR_RESP_G       : slv(1 downto 0)                  := AXI_RESP_DECERR_C;
      -- MMCM attributes
      BANDWIDTH_G            : string                           := "OPTIMIZED";
      CLKIN_PERIOD_G         : real                             := 10.0;    -- Input period in ns );
      DIVCLK_DIVIDE_G        : integer range 1 to 106           := 1;
      CLKFBOUT_MULT_F_G      : real range 1.0 to 64.0           := 1.0;
      CLKFBOUT_MULT_G        : integer range 2 to 64            := 5;
      CLKOUT0_DIVIDE_F_G     : real range 1.0 to 128.0          := 1.0;
      CLKOUT0_DIVIDE_G       : integer range 1 to 128           := 1;
      CLKOUT1_DIVIDE_G       : integer range 1 to 128           := 1;
      CLKOUT2_DIVIDE_G       : integer range 1 to 128           := 1;
      CLKOUT3_DIVIDE_G       : integer range 1 to 128           := 1;
      CLKOUT4_DIVIDE_G       : integer range 1 to 128           := 1;
      CLKOUT5_DIVIDE_G       : integer range 1 to 128           := 1;
      CLKOUT6_DIVIDE_G       : integer range 1 to 128           := 1;
      CLKOUT0_PHASE_G        : real range -360.0 to 360.0       := 0.0;
      CLKOUT1_PHASE_G        : real range -360.0 to 360.0       := 0.0;
      CLKOUT2_PHASE_G        : real range -360.0 to 360.0       := 0.0;
      CLKOUT3_PHASE_G        : real range -360.0 to 360.0       := 0.0;
      CLKOUT4_PHASE_G        : real range -360.0 to 360.0       := 0.0;
      CLKOUT5_PHASE_G        : real range -360.0 to 360.0       := 0.0;
      CLKOUT6_PHASE_G        : real range -360.0 to 360.0       := 0.0;
      CLKOUT0_DUTY_CYCLE_G   : real range 0.01 to 0.99          := 0.5;
      CLKOUT1_DUTY_CYCLE_G   : real range 0.01 to 0.99          := 0.5;
      CLKOUT2_DUTY_CYCLE_G   : real range 0.01 to 0.99          := 0.5;
      CLKOUT3_DUTY_CYCLE_G   : real range 0.01 to 0.99          := 0.5;
      CLKOUT4_DUTY_CYCLE_G   : real range 0.01 to 0.99          := 0.5;
      CLKOUT5_DUTY_CYCLE_G   : real range 0.01 to 0.99          := 0.5;
      CLKOUT6_DUTY_CYCLE_G   : real range 0.01 to 0.99          := 0.5;
      CLKOUT0_RST_HOLD_G     : integer range 3 to positive'high := 3;
      CLKOUT1_RST_HOLD_G     : integer range 3 to positive'high := 3;
      CLKOUT2_RST_HOLD_G     : integer range 3 to positive'high := 3;
      CLKOUT3_RST_HOLD_G     : integer range 3 to positive'high := 3;
      CLKOUT4_RST_HOLD_G     : integer range 3 to positive'high := 3;
      CLKOUT5_RST_HOLD_G     : integer range 3 to positive'high := 3;
      CLKOUT6_RST_HOLD_G     : integer range 3 to positive'high := 3;
      CLKOUT0_RST_POLARITY_G : sl                               := '1';
      CLKOUT1_RST_POLARITY_G : sl                               := '1';
      CLKOUT2_RST_POLARITY_G : sl                               := '1';
      CLKOUT3_RST_POLARITY_G : sl                               := '1';
      CLKOUT4_RST_POLARITY_G : sl                               := '1';
      CLKOUT5_RST_POLARITY_G : sl                               := '1';
      CLKOUT6_RST_POLARITY_G : sl                               := '1');
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
end entity ClockManagerUltraScale;

architecture rtl of ClockManagerUltraScale is

   constant RST_HOLD_C : IntegerArray(0 to 6) := (
      CLKOUT0_RST_HOLD_G, CLKOUT1_RST_HOLD_G, CLKOUT2_RST_HOLD_G, CLKOUT3_RST_HOLD_G,
      CLKOUT4_RST_HOLD_G, CLKOUT5_RST_HOLD_G, CLKOUT6_RST_HOLD_G);

   constant RST_POLARITY_C : slv(0 to 6) := (
      CLKOUT0_RST_POLARITY_G, CLKOUT1_RST_POLARITY_G, CLKOUT2_RST_POLARITY_G, CLKOUT3_RST_POLARITY_G,
      CLKOUT4_RST_POLARITY_G, CLKOUT5_RST_POLARITY_G, CLKOUT6_RST_POLARITY_G);

   constant CLKOUT0_DIVIDE_F_C : real := ite(CLKOUT0_DIVIDE_F_G = 1.0, real(CLKOUT0_DIVIDE_G), CLKOUT0_DIVIDE_F_G);
   constant CLKFBOUT_MULT_F_C  : real := ite(CLKFBOUT_MULT_F_G = 1.0, real(CLKFBOUT_MULT_G), CLKFBOUT_MULT_F_G);

   signal rstInLoc   : sl;
   signal clkInLoc   : sl;
   signal lockedLoc  : sl;
   signal clkOutMmcm : slv(6 downto 0);
   signal clkOutLoc  : slv(6 downto 0);
   signal clkFbOut   : sl;
   signal clkFbIn    : sl;

   signal drpRdy  : sl;
   signal drpEn   : sl;
   signal drpWe   : sl;
   signal drpAddr : slv(6 downto 0);
   signal drpDi   : slv(15 downto 0);
   signal drpDo   : slv(15 downto 0);

   attribute keep_hierarchy        : string;
   attribute keep_hierarchy of rtl : architecture is "yes";

begin
   
   assert (TYPE_G = "MMCM" or (TYPE_G = "PLL" and NUM_CLOCKS_G < 2))
      report "ClockManager7: Cannot have 2 clocks if TYPE_G is PLL" severity failure;

   assert(TYPE_G = "MMCM" or TYPE_G = "PLL")
      report "ClockManger7: TYPE_G must be either MMCM or PLL" severity failure;
   
   rstInLoc <= '1' when rstIn = RST_IN_POLARITY_G else '0';

   U_AxiLiteToDrp : entity work.AxiLiteToDrp
      generic map (
         TPD_G            => TPD_G,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G,
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

   MmcmGen : if (TYPE_G = "MMCM") generate
      U_Mmcm : MMCME3_ADV
         generic map (
            BANDWIDTH          => BANDWIDTH_G,
            CLKOUT4_CASCADE    => "FALSE",
            STARTUP_WAIT       => "FALSE",
            CLKIN1_PERIOD      => CLKIN_PERIOD_G,
            DIVCLK_DIVIDE      => DIVCLK_DIVIDE_G,
            CLKFBOUT_MULT_F    => CLKFBOUT_MULT_F_C,
            CLKOUT0_DIVIDE_F   => CLKOUT0_DIVIDE_F_C,
            CLKOUT1_DIVIDE     => CLKOUT1_DIVIDE_G,
            CLKOUT2_DIVIDE     => CLKOUT2_DIVIDE_G,
            CLKOUT3_DIVIDE     => CLKOUT3_DIVIDE_G,
            CLKOUT4_DIVIDE     => CLKOUT4_DIVIDE_G,
            CLKOUT5_DIVIDE     => CLKOUT5_DIVIDE_G,
            CLKOUT6_DIVIDE     => CLKOUT6_DIVIDE_G,
            CLKOUT0_PHASE      => CLKOUT0_PHASE_G,
            CLKOUT1_PHASE      => CLKOUT1_PHASE_G,
            CLKOUT2_PHASE      => CLKOUT2_PHASE_G,
            CLKOUT3_PHASE      => CLKOUT3_PHASE_G,
            CLKOUT4_PHASE      => CLKOUT4_PHASE_G,
            CLKOUT5_PHASE      => CLKOUT5_PHASE_G,
            CLKOUT6_PHASE      => CLKOUT6_PHASE_G,
            CLKOUT0_DUTY_CYCLE => CLKOUT0_DUTY_CYCLE_G,
            CLKOUT1_DUTY_CYCLE => CLKOUT1_DUTY_CYCLE_G,
            CLKOUT2_DUTY_CYCLE => CLKOUT2_DUTY_CYCLE_G,
            CLKOUT3_DUTY_CYCLE => CLKOUT3_DUTY_CYCLE_G,
            CLKOUT4_DUTY_CYCLE => CLKOUT4_DUTY_CYCLE_G,
            CLKOUT5_DUTY_CYCLE => CLKOUT5_DUTY_CYCLE_G,
            CLKOUT6_DUTY_CYCLE => CLKOUT6_DUTY_CYCLE_G)
         port map (
            DCLK     => axilClk,
            DRDY     => drpRdy,
            DEN      => drpEn,
            DWE      => drpWe,
            DADDR    => drpAddr,
            DI       => drpDi,
            DO       => drpDo,
            CDDCREQ  => '0',
            PSCLK    => '0',
            PSEN     => '0',
            PSINCDEC => '0',
            PWRDWN   => '0',
            RST      => rstInLoc,
            CLKIN1   => clkInLoc,
            CLKIN2   => '0',
            CLKINSEL => '1',
            CLKFBOUT => clkFbOut,
            CLKFBIN  => clkFbIn,
            LOCKED   => lockedLoc,
            CLKOUT0  => clkOutMmcm(0),
            CLKOUT1  => clkOutMmcm(1),
            CLKOUT2  => clkOutMmcm(2),
            CLKOUT3  => clkOutMmcm(3),
            CLKOUT4  => clkOutMmcm(4),
            CLKOUT5  => clkOutMmcm(5),
            CLKOUT6  => clkOutMmcm(6));
   end generate MmcmGen;

   PllGen : if (TYPE_G = "PLL") generate
      U_Pll : PLLE3_ADV
         generic map (
            STARTUP_WAIT       => "FALSE",
            CLKIN_PERIOD       => CLKIN_PERIOD_G,
            DIVCLK_DIVIDE      => DIVCLK_DIVIDE_G,
            CLKFBOUT_MULT      => CLKFBOUT_MULT_G,
            CLKOUT0_DIVIDE     => CLKOUT0_DIVIDE_G,
            CLKOUT1_DIVIDE     => CLKOUT1_DIVIDE_G,
            CLKOUT0_PHASE      => CLKOUT0_PHASE_G,
            CLKOUT1_PHASE      => CLKOUT1_PHASE_G,
            CLKOUT0_DUTY_CYCLE => CLKOUT0_DUTY_CYCLE_G,
            CLKOUT1_DUTY_CYCLE => CLKOUT1_DUTY_CYCLE_G)
         port map (
            DCLK        => axilClk,
            DRDY        => drpRdy,
            DEN         => drpEn,
            DWE         => drpWe,
            DADDR       => drpAddr,
            DI          => drpDi,
            DO          => drpDo,
            PWRDWN      => '0',
            RST         => rstInLoc,
            CLKIN       => clkInLoc,
            CLKOUTPHYEN => '0',
            CLKFBOUT    => clkFbOut,
            CLKFBIN     => clkFbIn,
            LOCKED      => lockedLoc,
            CLKOUT0     => clkOutMmcm(0),
            CLKOUT1     => clkOutMmcm(1));
   end generate;

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
      clkFbOut <= clkFbIn;
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
      RstSync_1 : entity work.RstSync
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
