-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : TenGigEthGtx7ClkAndRst.vhd
-- Author     : Larry Ruckman <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-02-12
-- Last update: 2015-03-25
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Gtx7 Wrapper for 10GBASE-R Ethernet
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.AxiStreamPkg.all;
use work.TenGigEthPkg.all;
use work.StdRtlPkg.all;

library unisim;
use unisim.vcomponents.all;

entity TenGigEthGtx7ClkAndRst is
   generic (
      TPD_G             : time       := 1 ns;
      REFCLK_DIV2_G     : boolean    := false;  --  FALSE: gtClkP/N = 156.25 MHz, TRUE: gtClkP/N = 312.5 MHz
      QPLL_REFCLK_SEL_G : bit_vector := "001");
   port (
      -- Clocks and Resets
      extRst        : in  sl;           -- async reset
      phyClk        : out sl;
      phyRst        : out sl;
      txClk322      : in  sl;
      txUsrClk      : out sl;
      txUsrClk2     : out sl;
      gtTxRst       : out sl;
      gtRxRst       : out sl;
      txUsrRdy      : out sl;
      rstCntDone    : out sl;
      -- MGT Ports
      gtClkP        : in  sl;
      gtClkN        : in  sl;
      -- Quad PLL Ports
      qplllock      : out sl;
      qplloutclk    : out sl;
      qplloutrefclk : out sl);      
end TenGigEthGtx7ClkAndRst;

architecture rtl of TenGigEthGtx7ClkAndRst is

   signal refClockDiv2 : sl;
   signal refClock     : sl;
   signal refClk       : sl;
   signal phyClock     : sl;
   signal phyReset     : sl;
   signal txClock      : sl;
   signal txReset      : sl;
   signal qPllLocked   : sl;
   signal txReady      : sl;
   signal rstCnt       : slv(7 downto 0) := x"00";
   signal rstPulse     : slv(3 downto 0) := "1110";

begin

   phyClk     <= phyClock;
   phyRst     <= phyReset;
   txUsrClk   <= txClock;
   txUsrClk2  <= txClock;
   qPllLock   <= qPllLocked;
   rstCntDone <= rstCnt(7);
   gtTxRst    <= rstPulse(0);
   gtRxRst    <= rstPulse(0);

   IBUFDS_GTE2_Inst : IBUFDS_GTE2
      port map (
         I     => gtClkP,
         IB    => gtClkN,
         CEB   => '0',
         ODIV2 => refClockDiv2,
         O     => refClock);  

   refClk <= refClockDiv2 when(REFCLK_DIV2_G) else refClock;

   Gtx7QuadPll_Inst : entity work.Gtx7QuadPll
      generic map (
         TPD_G               => TPD_G,
         SIM_RESET_SPEEDUP_G => "TRUE",        --Does not affect hardware
         SIM_VERSION_G       => "4.0",
         QPLL_CFG_G          => x"0680181",
         QPLL_REFCLK_SEL_G   => QPLL_REFCLK_SEL_G,
         QPLL_FBDIV_G        => "0101000000",  -- 64B/66B Encoding
         QPLL_FBDIV_RATIO_G  => '0',           -- 64B/66B Encoding
         QPLL_REFCLK_DIV_G   => 1)    
      port map (
         qPllRefClk     => refClk,             -- 156.25 MHz
         qPllOutClk     => qPllOutClk,
         qPllOutRefClk  => qPllOutRefClk,
         qPllLock       => qPllLocked,
         qPllLockDetClk => '0',                -- IP Core ties this to GND (see note below) 
         qPllRefClkLost => open,
         qPllPowerDown  => '0',
         qPllReset      => rstPulse(0));          
   ---------------------------------------------------------------------------------------------
   -- Note: GTXE2_COMMON pin gtxe2_common_0_i.QPLLLOCKDETCLK cannot be driven by a clock derived 
   --       from the same clock used as the reference clock for the QPLL, including TXOUTCLK*, 
   --       RXOUTCLK*, the output from the IBUFDS_GTE2 providing the reference clock, and any 
   --       buffered or multiplied/divided versions of these clock outputs. Please see UG476 for 
   --       more information. Source, through a clock buffer, is the same as the GT cell 
   --       reference clock.
   ---------------------------------------------------------------------------------------------
   
   CLK156_BUFG : BUFG
      port map (
         I => refClk,
         O => phyClock);          

   CLK312_BUFG : BUFG
      port map (
         I => txClk322,
         O => txClock);  
         
   Synchronizer_0 : entity work.Synchronizer
      generic map(
         TPD_G          => TPD_G,
         RST_ASYNC_G    => true,
         RST_POLARITY_G => '1',
         STAGES_G       => 4,
         INIT_G         => "1111")
      port map (
         clk     => phyClock,
         rst     => extRst,
         dataIn  => '0',
         dataOut => phyReset);         

   Synchronizer_1 : entity work.Synchronizer
      generic map(
         TPD_G          => TPD_G,
         RST_ASYNC_G    => true,
         RST_POLARITY_G => '0',
         STAGES_G       => 4,
         INIT_G         => "0000")
      port map (
         clk     => txClock,
         rst     => qPllLocked,
         dataIn  => '1',
         dataOut => txReady);           

   Synchronizer_2 : entity work.Synchronizer
      generic map(
         TPD_G          => TPD_G,
         RST_ASYNC_G    => true,
         RST_POLARITY_G => '1',
         STAGES_G       => 4,
         INIT_G         => "1111")
      port map (
         clk     => txClock,
         rst     => rstPulse(0),
         dataIn  => '0',
         dataOut => txReset);  

   process(phyClock)
   begin
      if rising_edge(phyClock) then
         -- Hold off release the GT resets until 500ns after configuration.
         -- 128 ticks at 6.4ns period will be >> 500 ns.
         if rstCnt(7) = '0' then
            rstCnt <= rstCnt + 1 after TPD_G;
         else
            rstCnt <= rstCnt after TPD_G;
         end if;
         -- Check for reset
         if phyReset = '1' then
            rstPulse <= "1110" after TPD_G;
         elsif rstCnt(7) = '1' then
            rstPulse(3)          <= '0'                  after TPD_G;
            rstPulse(2 downto 0) <= rstPulse(3 downto 1) after TPD_G;
         end if;
      end if;
   end process;

   process(txClock)
   begin
      if rising_edge(txClock) then
         if txReset = '1' then
            txUsrRdy <= '0' after TPD_G;
         else
            txUsrRdy <= txReady after TPD_G;
         end if;
      end if;
   end process;

end rtl;
