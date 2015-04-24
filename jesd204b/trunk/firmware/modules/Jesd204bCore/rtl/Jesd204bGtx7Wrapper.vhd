-------------------------------------------------------------------------------
-- Title      : JESD204b wrapper module gtx7 MGT
-------------------------------------------------------------------------------
-- File       : Jesd204bGtx7Wrapper.vhd
-- Author     : Uros Legat  <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory (Cosylab)
-- Created    : 2015-04-14
-- Last update: 2015-04-14
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
library ieee;
library unisim;
use unisim.vcomponents.all;

use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use IEEE.math_real.all;


use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.Gtx7CfgPkg.all;
use work.Jesd204bPkg.all;

entity Jesd204bGtx7Wrapper is
   generic (
      TPD_G             : time                        := 1 ns;
      
   -- GT Settings
   ----------------------------------------------------------------------------------------------
     REFCLK_FREQUENCY_G : real := 370.0E6;
     LINE_RATE_G        : real := 7.40E9;
     
   -- AXI Lite and AXI stream generics
   ----------------------------------------------------------------------------------------------
      AXI_ERROR_RESP_G  : slv(1 downto 0)             := AXI_RESP_SLVERR_C;
      AXI_PACKET_SIZE_G : natural range 1 to (2**24)  := 2**8;

   -- JESD generics
   ----------------------------------------------------------------------------------------------
      F_G            : positive := 2;
      K_G            : positive := 32;
      L_G            : positive := 2;
      GT_WORD_SIZE_G : positive := 4;
      SUB_CLASS_G    : positive := 1
   );

   port (
   -- External board reset   
      extRst       : in  sl; 
   
   -- GT Interface
   ----------------------------------------------------------------------------------------------    
   -- GT reference clock (device clock-devClkA input)
      gtClkP       : in  sl;
      gtClkN       : in  sl;

   -- GT Serial IO
      gtTxP            : out slv(0 to L_G-1);         -- GT Serial Transmit Positive (disconnected)
      gtTxN            : out slv(0 to L_G-1);         -- GT Serial Transmit Negative (disconnected)
      gtRxP            : in  slv(0 to L_G-1);         -- GT Serial Receive Positive
      gtRxN            : in  slv(0 to L_G-1);         -- GT Serial Receive Negative
      
      -- Rx clocking
      pgpRxReset       : in  sl;                    
      pgpRxClk         : in  sl;
      pgpRxMmcmReset   : out sl;
      pgpRxMmcmLocked  : in  sl;
   
   
   -- AXI interface
   ------------------------------------------------------------------------------------------------   
      axiClk  : in    sl;
      axiRst  : in    sl;  
      
      -- AXI-Lite Register Interface
      axilReadMaster  : in    AxiLiteReadMasterType;
      axilReadSlave   : out   AxiLiteReadSlaveType;
      axilWriteMaster : in    AxiLiteWriteMasterType;
      axilWriteSlave  : out   AxiLiteWriteSlaveType;
      
      -- AXI Streaming Interface
      txAxisMasterArr : out   AxiStreamMasterArray(0 to L_G-1);
      txCtrlArr       : in    AxiStreamCtrlArray(0 to L_G-1);   
      
   -- JESD
   ------------------------------------------------------------------------------------------------   

      -- SYSREF for subcalss 1 fixed latency
      sysrefP       : in    sl;
      sysrefN       : in    sl;
      
      -- Synchronisation output combined from all receivers 
      nSyncP        : out   sl;
      nSyncN        : out   sl
   );
end Jesd204bGtx7Wrapper;

architecture rtl of Jesd204bGtx7Wrapper is
  
   -- CPLL config constant
   constant QPLL_CONFIG_C     : Gtx7QPllCfgType := getGtx7QPllCfg(REFCLK_FREQUENCY_G, LINE_RATE_G);   
   constant RERCLK_PERIOD_C   : real := 1.0/REFCLK_FREQUENCY_G;
   
   -- Resets
   signal s_extRstSync       : sl;
   
   -- GT Clocking 
   signal s_refClk           : sl;
   signal s_refClkDiv2       : sl;   
   signal s_stableClock      : sl;   
   signal s_stableClk        : sl;     -- GT needs a stable clock to "boot up"

   -- User clocking
   signal s_devClk  : sl; -- Device clock also rxUsrClkIn for MGT 
   signal s_devRst  : sl; -- Reset synced to s_devClk
   
   -- JESD
   signal s_sysRef : sl;   
   signal s_nSync  : sl;  

   -- QPLL
   signal  gtCPllRefClk  : sl; 
   signal  gtCPllLock    : sl; 
   signal  qPllOutClk    : sl; 
   signal  qPllOutRefClk : sl; 
   signal  qPllLock      : sl; 
   signal  qPllRefClkLost: sl; 
   signal  qPllReset     : slv(0 to L_G-1); 
   signal  gtQPllReset   : sl;

begin

   -- Check generics TODO add others
   assert (GT_WORD_SIZE_G = 2 or GT_WORD_SIZE_G = 4) report "GT_WORD_SIZE_G must be 2 or 4" severity failure;
   assert (1 < L_G and L_G < 8)                      report "L_G must be between 1 and 8"   severity failure;

   IBUFDS_GTE2_Inst : IBUFDS_GTE2
      port map (
         I     => gtClkP,
         IB    => gtClkN,
         CEB   => '0',
         ODIV2 => s_refClkDiv2, --185 MHz 
         O     => s_refClk      --370 MHz
   );    

   BUFG_Inst : BUFG
      port map (
         I => s_refClkDiv2,
         O => s_stableClock);       

   RstSync_Inst : entity work.RstSync
      generic map(
         TPD_G => TPD_G)   
      port map (
         clk      => s_stableClock,
         asyncRst => extRst,
         syncRst  => s_extRstSync
   );          

   UserClockManager7_Inst : entity work.ClockManager7
      generic map (
         TPD_G              => TPD_G,
         TYPE_G             => "MMCM",
         INPUT_BUFG_G       => false,
         FB_BUFG_G          => true,
         NUM_CLOCKS_G       => 1,
         BANDWIDTH_G        => "OPTIMIZED",
         CLKIN_PERIOD_G     => RERCLK_PERIOD_C,
         DIVCLK_DIVIDE_G    => 1,
         CLKFBOUT_MULT_F_G  => 5.375,
         --
         CLKOUT0_DIVIDE_F_G => 5.375,
         CLKOUT0_RST_HOLD_G => 8
      )
      port map(
         clkIn     => s_stableClock,
         rstIn     => s_extRstSync,
         clkOut(0) => s_devClk,
         rstOut(0) => s_devRst
      );
      
   Gtx7QuadPll_INST: entity work.Gtx7QuadPll
   generic map (
      TPD_G               => TPD_G,
      QPLL_REFCLK_SEL_G   => "001",
      QPLL_FBDIV_G        => QPLL_CONFIG_C.QPLL_FBDIV_G,
      QPLL_FBDIV_RATIO_G  => QPLL_CONFIG_C.QPLL_FBDIV_RATIO_G,
      QPLL_REFCLK_DIV_G   => QPLL_CONFIG_C.QPLL_REFCLK_DIV_G)
   port map (
      qPllRefClk     => s_refClk,
      qPllOutClk     => qPllOutClk,
      qPllOutRefClk  => qPllOutRefClk,
      qPllLock       => qPllLock,
      qPllLockDetClk => '0',
      qPllRefClkLost => qPllRefClkLost,
      qPllPowerDown  => '0',
      qPllReset      => qPllReset(0)
   );

   Jesd204bGtx7_INST: entity work.Jesd204bGtx7
   generic map (
      TPD_G                 => TPD_G,
      
      -- CPLL Configurations (not used)
      CPLL_FBDIV_G          => 4,
      CPLL_FBDIV_45_G       => 4,
      CPLL_REFCLK_DIV_G     => 1,
      
      RXOUT_DIV_G           => QPLL_CONFIG_C.OUT_DIV_G,
      RX_CLK25_DIV_G        => QPLL_CONFIG_C.CLK25_DIV_G,
      
      -- AXI
      AXI_ERROR_RESP_G      => AXI_ERROR_RESP_G,
      AXI_PACKET_SIZE_G     => AXI_PACKET_SIZE_G,
      
      -- JESD
      F_G                   => F_G,
      K_G                   => K_G,
      L_G                   => L_G,
      GT_WORD_SIZE_G        => GT_WORD_SIZE_G,
      SUB_CLASS_G           => SUB_CLASS_G
   )
   port map (
      stableClk         => s_stableClock,

      qPllRefClkIn      => qPllOutRefClk,
      qPllClkIn         => qPllOutClk,
      qPllLockIn        => qPllLock,
      qPllRefClkLostIn  => qPllRefClkLost,
      qPllResetOut      => qPllReset, 

      gtTxP             => gtTxP,
      gtTxN             => gtTxN,
      gtRxP             => gtRxP,
      gtRxN             => gtRxN,
      devClk_i          => s_devClk, -- both same
      devClk2_i         => s_devClk, -- both same
      devRst_i          => s_devRst,
      axiClk            => axiClk,
      axiRst            => axiRst,
      axilReadMaster    => axilReadMaster,
      axilReadSlave     => axilReadSlave,
      axilWriteMaster   => axilWriteMaster,
      axilWriteSlave    => axilWriteSlave,
      txAxisMasterArr_o => txAxisMasterArr,
      txCtrlArr_i       => txCtrlArr,
      sysRef_i          => s_sysRef,
      nSync_o           => s_nSync
   );
   
   ----------------------------------------------------------------
   -- put sync and sysref on differential io buffer
   IBUFDS_rsysref_inst : IBUFDS
   generic map (
      DIFF_TERM => FALSE,
      IBUF_LOW_PWR => TRUE,
      IOSTANDARD => "DEFAULT")
   port map (
      I  => sysrefP,
      IB => sysrefN,
      O  => s_sysRef
   );
   
   OBUFDS_nsync_inst : OBUFDS
   generic map (
      IOSTANDARD => "DEFAULT",
      SLEW => "SLOW"
   )
   port map (
      I =>  s_nSync,
      O =>  nSyncP, 
      OB => nSyncN

   );

end rtl;
