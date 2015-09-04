-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AtlasTtcRxClkMon.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-03-14
-- Last update: 2014-06-03
-- Platform   : Vivado 2013.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: This module monitors the clock.
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AtlasTtcRxPkg.all;

library unisim;
use unisim.vcomponents.all;

entity AtlasTtcRxClkMon is
   generic (
      TPD_G             : time    := 1 ns;
      EN_LOL_PORT_G     : boolean := true;
      EN_SIG_DET_PORT_G : boolean := true;
      USE_DSP48_G       : string  := "no");  -- "no" for no DSP48 implementation, "yes" to use DSP48 slices      
   port (
      -- Status Monitoring
      clkLocked       : out sl;
      freqLocked      : out sl;
      cdrLocked       : out sl;
      sigLocked       : out sl;
      freqMeasured    : out slv(31 downto 0);  -- units of Hz  
      ignoreSigLocked : in  sl;
      ignoreCdrLocked : in  sl;
      lockedP         : out sl;
      lockedN         : out sl;
      -- Optional External Ports
      lostLinkP       : in  sl := '0';  -- From ADN2816 IC (inverted copy of LOL) 
      lostLinkN       : in  sl := '1';  -- From ADN2816 IC (inverted copy of LOL)     
      sigDetP         : in  sl := '0';  -- From Fiber Optic Module
      sigDetN         : in  sl := '1';  -- From Fiber Optic Module      
      -- Global Signals
      refClk200MHz    : in  sl;
      locClk          : in  sl;
      locRst          : in  sl);
end AtlasTtcRxClkMon;

architecture rtl of AtlasTtcRxClkMon is

   signal lockStatus,
      lostStatus,
      lockStatusSync,
      lockStatusSyncDet,
      sigDet,
      sigDetSync,
      sigDetSyncDet,
      locked,
      clkLock,
      freqLock : sl := '0';
   
begin

   ------------------------------
   -- Configure the status inputs
   ------------------------------
   GEN_SIG_DET_FALSE : if (EN_SIG_DET_PORT_G = false) generate
      
      sigDet     <= '1';
      sigDetSync <= '1';
      
   end generate;

   GEN_SIG_DET_TRUE : if (EN_SIG_DET_PORT_G = true) generate
      
      IBUFDS_0 : IBUFDS
         generic map (
            DIFF_TERM => true)
         port map (
            I  => sigDetP,
            IB => sigDetN,
            O  => sigDet); 

      Debouncer_0 : entity work.Debouncer
         generic map (
            TPD_G             => TPD_G,
            INPUT_POLARITY_G  => '1',
            OUTPUT_POLARITY_G => '1',
            FILTER_SIZE_G     => 16,
            FILTER_INIT_G     => X"0000",
            SYNCHRONIZE_G     => true)   
         port map (
            clk => locClk,
            i   => sigDet,
            o   => sigDetSync);        

   end generate;

   GEN_LOCKED_FALSE : if (EN_LOL_PORT_G = false) generate
      
      lostStatus     <= '0';
      lockStatus     <= '1';
      lockStatusSync <= '1';

   end generate;

   GEN_LOCKED_TRUE : if (EN_LOL_PORT_G = true) generate
      
      IBUFDS_1 : IBUFDS
         generic map (
            DIFF_TERM => true)
         port map (
            I  => lostLinkP,
            IB => lostLinkN,
            O  => lostStatus); 

      lockStatus <= not(lostStatus);

      Debouncer_1 : entity work.Debouncer
         generic map (
            TPD_G             => TPD_G,
            INPUT_POLARITY_G  => '1',
            OUTPUT_POLARITY_G => '1',
            FILTER_SIZE_G     => 16,
            FILTER_INIT_G     => X"0000",
            SYNCHRONIZE_G     => true)   
         port map (
            clk => locClk,
            i   => lockStatus,
            o   => lockStatusSync);             

   end generate;

   SyncClockFreq_Inst : entity work.SyncClockFreq
      generic map (
         TPD_G             => TPD_G,
         USE_DSP48_G       => USE_DSP48_G,
         REF_CLK_FREQ_G    => ATLAS_TTC_RX_REF_CLK_FREQ_C,
         REFRESH_RATE_G    => ATLAS_TTC_RX_REFRESH_RATE_C,
         CLK_LOWER_LIMIT_G => ATLAS_TTC_RX_CLK_LOWER_LIMIT_C,
         CLK_UPPER_LIMIT_G => ATLAS_TTC_RX_CLK_UPPER_LIMIT_C,
         CNT_WIDTH_G       => 32)   
      port map (
         -- Frequency Measurement and Monitoring Outputs (locClk domain)
         freqOut => freqMeasured,
         locked  => locked,
         -- Clocks
         clkIn   => locClk,
         locClk  => locClk,
         refClk  => refClk200MHz);      

   lockStatusSyncDet <= lockStatusSync or ignoreCdrLocked;
   sigDetSyncDet     <= sigDetSync or ignoreSigLocked;

   freqLock <= locked and lockStatusSyncDet and sigDetSyncDet and not(locRst);

   PwrUpRst_Inst : entity work.PwrUpRst
      generic map (
         TPD_G          => TPD_G,
         IN_POLARITY_G  => '0',
         OUT_POLARITY_G => '0',
         USE_DSP48_G    => USE_DSP48_G,
         DURATION_G     => ATLAS_TTC_RX_LOCK_RST_DURATION_C)
      port map (
         arst   => freqLock,
         clk    => locClk,
         rstOut => clkLock);     

   -----------------
   -- Status Outputs 
   -----------------
   clkLocked  <= clkLock;
   freqLocked <= freqLock;
   cdrLocked  <= lockStatusSync;
   sigLocked  <= sigDetSync;

   OBUFDS_Inst : OBUFDS
      port map (
         I  => clkLock,
         O  => lockedP,
         OB => lockedN);         

end rtl;
