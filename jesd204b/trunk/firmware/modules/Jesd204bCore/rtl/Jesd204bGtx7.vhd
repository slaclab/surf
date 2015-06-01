-------------------------------------------------------------------------------
-- Title      : JESD204b module containing the gtx7 MGT and both receiver and transmitter modules
-------------------------------------------------------------------------------
-- File       : Jesd204bRxGtx7.vhd
-- Author     : Uros Legat  <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory (Cosylab)
-- Created    : 2015-04-14
-- Last update: 2015-04-14
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Framework module for JESD.
--              Contains generic settings for GTX7 L_G Receivers
--              
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
library ieee;
library unisim;
use unisim.vcomponents.all;

use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.Jesd204bPkg.all;

entity Jesd204bGtx7 is
   generic (
      TPD_G             : time                        := 1 ns;
      
   -- Test tx module instead of GTX
      TEST_G            : boolean                     := false;
      
      -- Internal SYSREF SYSREF_GEN_G= TRUE else 
      -- External SYSREF
      SYSREF_GEN_G       : boolean                    := true; 
      
      SIM_G              : boolean                    := true; 
      
      
   -- GT Settings
   ----------------------------------------------------------------------------------------------     
   -- Sim Generics
      SIM_GTRESET_SPEEDUP_G : string     := "FALSE";
      SIM_VERSION_G         : string     := "4.0";
      STABLE_CLOCK_PERIOD_G : real       := 4.0E-9;  --units of seconds (default to longest timeout)      
    
      -- CPLL Settings
      CPLL_REFCLK_SEL_G     : bit_vector := "001";
      CPLL_FBDIV_G          : integer:= 4; -- use getGtx7CPllCfg to set
      CPLL_FBDIV_45_G       : integer:= 4; -- use getGtx7CPllCfg to set
      CPLL_REFCLK_DIV_G     : integer:= 1;-- use getGtx7CPllCfg to set
      
      RXOUT_DIV_G           : integer:= 4; -- use getGtx7CPllCfg or to getGtx7QPllCfg set
      RX_CLK25_DIV_G        : integer:= 4;-- use getGtx7CPllCfg or to getGtx7QPllCfg set     
      
      -- MGT Configurations
      PMA_RSV_G             : bit_vector := x"001E7080";            -- Values from coregen     
      RX_OS_CFG_G           : bit_vector := "0000010000000";        -- Values from coregen 
      RXCDR_CFG_G           : bit_vector := x"03000023ff10400020";  -- Values from coregen  
      RXDFEXYDEN_G          : sl         := '1';                    -- Values from coregen 
      RX_DFE_KL_CFG2_G      : bit_vector := X"301148AC";            -- Values from coregen 

      -- Configure PLL sources
      TX_PLL_G         : string:= "QPLL"; -- "QPLL" or "CPLL"
      RX_PLL_G         : string:= "QPLL"; -- "QPLL" or "CPLL"
     
      -- TX defaults not currently used
      TXOUT_DIV_G           : integer    := 2;
      TX_CLK25_DIV_G        : integer    := 7;
      TX_BUF_EN_G        : boolean := true;
      TX_OUTCLK_SRC_G    : string  := "OUTCLKPMA";
      TX_DLY_BYPASS_G    : sl      := '1';
      TX_PHASE_ALIGN_G   : string  := "NONE";
      TX_BUF_ADDR_MODE_G : string  := "FULL";
      
   -- AXI Lite and AXI stream generics
   ----------------------------------------------------------------------------------------------
      AXI_ERROR_RESP_G  : slv(1 downto 0)             := AXI_RESP_SLVERR_C;

   -- JESD generics
   ----------------------------------------------------------------------------------------------
      F_G            : positive := 2;
      K_G            : positive := 32;
      L_G            : positive := 2
   );

   port (
   -- GT Interface
   ----------------------------------------------------------------------------------------------
      -- GT Clocking
      stableClk        : in  sl;                      -- GT needs a stable clock to "boot up"(buffered refClkDiv2) 
      
      -- QPLL
      qPllRefClkIn     : in  sl;
      qPllClkIn        : in  sl;    
      qPllLockIn       : in  sl;     
      qPllRefClkLostIn : in  sl;     
      qPllResetOut     : out slv(L_G-1 downto 0);     
      
      -- Gt Serial IO
      gtTxP            : out slv(L_G-1 downto 0);         -- GT Serial Transmit Positive
      gtTxN            : out slv(L_G-1 downto 0);         -- GT Serial Transmit Negative
      gtRxP            : in  slv(L_G-1 downto 0);         -- GT Serial Receive Positive
      gtRxN            : in  slv(L_G-1 downto 0);         -- GT Serial Receive Negative
        
   -- User clocks and resets
   ---------------------------------------------------------------------------------------------- 
      devClk_i       : in    sl; -- Device clock also rxUsrClkIn for MGT
      devClk2_i      : in    sl; -- Device clock divided by 2 also rxUsrClk2In for MGT       
      devRst_i       : in    sl; -- 

   -- AXI interface
   ------------------------------------------------------------------------------------------------   
      axiClk         : in    sl;
      axiRst         : in    sl;  
      
      -- AXI-Lite RX Register Interface
      axilReadMasterRx  : in    AxiLiteReadMasterType;
      axilReadSlaveRx   : out   AxiLiteReadSlaveType;
      axilWriteMasterRx : in    AxiLiteWriteMasterType;
      axilWriteSlaveRx  : out   AxiLiteWriteSlaveType;
      
      -- AXI-Lite RX Register Interface
      axilReadMasterTx  : in    AxiLiteReadMasterType;
      axilReadSlaveTx   : out   AxiLiteReadSlaveType;
      axilWriteMasterTx : in    AxiLiteWriteMasterType;
      axilWriteSlaveTx  : out   AxiLiteWriteSlaveType;
      
      -- AXI Streaming Interface
      txAxisMasterArr : out   AxiStreamMasterArray(L_G-1 downto 0);
      txCtrlArr       : in    AxiStreamCtrlArray(L_G-1 downto 0);   
      
   -- JESD
   ------------------------------------------------------------------------------------------------   

      -- SYSREF for subcalss 1 fixed latency
      sysRef_i       : in    sl;

      -- Synchronisation output combined from all receivers 
      nSync_o        : out   sl;
      
      -- Debug output
      leds_o         : out   slv(1 downto 0)
   );
end Jesd204bGtx7;

architecture rtl of Jesd204bGtx7 is
 
-- Internal signals
   signal r_jesdGtRxArr : jesdGtRxLaneTypeArray(L_G-1 downto 0);       
   signal r_jesdGtTxArr : jesdGtTxLaneTypeArray(L_G-1 downto 0);  
   
   -- Rx Channel Bonding
   -- signal rxChBondLevel : slv(2 downto 0);
   signal rxChBondIn    : Slv5Array(L_G-1 downto 0);
   signal rxChBondOut   : Slv5Array(L_G-1 downto 0);

   -- GT reset
   signal s_gtRxUserReset   : slv(L_G-1 downto 0);
   signal s_gtRxReset       : slv(L_G-1 downto 0);
   
   signal s_gtTxUserReset   : slv(L_G-1 downto 0);
   signal s_gtTxReset       : slv(L_G-1 downto 0); 
   -- 
   signal s_gtTxReady       : slv(L_G-1 downto 0);
   
   -- Generated or external
   signal s_sysRef      : sl;
   signal s_nSync       : sl;   
    
   

begin
   -- Check generics TODO add others
   assert (1 < L_G and L_G < 8)                      report "L_G must be between 1 and 8"   severity failure;

   --------------------------------------------------------------------------------------------------
   -- JESD receiver core
   --------------------------------------------------------------------------------------------------  
   Jesd204b_INST: entity work.Jesd204bRx
   generic map (
      TPD_G             => TPD_G,
      TEST_G            => TEST_G,
      AXI_ERROR_RESP_G  => AXI_ERROR_RESP_G,
      F_G               => F_G,
      K_G               => K_G,
      L_G               => L_G)
   port map (
      axiClk            => axiClk,
      axiRst            => axiRst,
      axilReadMaster    => axilReadMasterRx,
      axilReadSlave     => axilReadSlaveRx,
      axilWriteMaster   => axilWriteMasterRx,
      axilWriteSlave    => axilWriteSlaveRx,
      txAxisMasterArr_o => txAxisMasterArr,
      txCtrlArr_i       => txCtrlArr,
      devClk_i          => devClk_i,
      devRst_i          => devRst_i,
      sysRef_i          => s_sysRef,
      r_jesdGtRxArr     => r_jesdGtRxArr,
      gt_reset_o        => s_gtRxUserReset,
      nSync_o           => s_nSync
   );

   --------------------------------------------------------------------------------------------------
   -- JESD transmitter core
   --------------------------------------------------------------------------------------------------  
   Jesd204bTx_INST: entity work.Jesd204bTx
   generic map (
      TPD_G            => TPD_G,

      AXI_ERROR_RESP_G => AXI_ERROR_RESP_G,
      F_G              => F_G,
      K_G              => K_G,
      L_G              => L_G)
   port map (
      axiClk            => axiClk,
      axiRst            => axiRst,
      axilReadMaster    => axilReadMasterTx,
      axilReadSlave     => axilReadSlaveTx,
      axilWriteMaster   => axilWriteMasterTx,
      axilWriteSlave    => axilWriteSlaveTx,
      rxAxisMasterArr_i => (others => AXI_STREAM_MASTER_INIT_C),
      rxAxisSlaveArr_o  => open,
      extSampleDataArray_i => (L_G-1 downto 0 => (others => '0')),
      devClk_i          => devClk_i,
      devRst_i          => devRst_i,
      sysRef_i          => s_sysRef,
      nSync_i           => s_nSync,
      gtTxReady_i       => s_gtTxReady,
      gtTxReset_o       => s_gtTxUserReset,
      r_jesdGtTxArr     => r_jesdGtTxArr,
      leds_o            => leds_o
   );

   --------------------------------------------------------------------------------------------------
   -- Generate the internal or external SYSREF depending on SYSREF_GEN_G
   --------------------------------------------------------------------------------------------------
   -- IF DEF SYSREF_GEN_G
   SELF_TEST_GEN: if SYSREF_GEN_G = true generate
      -- Generate the sysref internally
      -- Sysref period will be 8x K_G.
      SysrefGen_INST: entity work.LmfcGen
      generic map (
         TPD_G          => TPD_G,
         K_G            => 256,
         F_G            => 2)
      port map (
         clk      => devClk_i,
         rst      => devRst_i,
         nSync_i  => '0',
         sysref_i => '0',
         lmfc_o   => s_sysRef
      );
   end generate SELF_TEST_GEN;
   -- Else 
   OPER_GEN: if SYSREF_GEN_G = false generate
      s_sysRef <= sysRef_i;
   end generate OPER_GEN;

   --------------------------------------------------------------------------------------------------
   -- Generate the TX RX LOOPBACK
   --------------------------------------------------------------------------------------------------
   GT_SIM_GEN: if SIM_G = true generate
      LANES_GEN : for I in (L_G-1) downto 0  generate   
         -- RX
         r_jesdGtRxArr(I).rstDone   <= '1';
         r_jesdGtRxArr(I).data      <= r_jesdGtTxArr(I).data;
         r_jesdGtRxArr(I).dataK     <= r_jesdGtTxArr(I).dataK;
         r_jesdGtRxArr(I).decErr    <= (others => '0');
         r_jesdGtRxArr(I).dispErr   <= (others => '0');
         -- TX
         s_gtTxReady(I)             <= '1';
         --
      end generate LANES_GEN;  
   end generate GT_SIM_GEN;
   
   --------------------------------------------------------------------------------------------------
   -- Generate the GTX channels
   --------------------------------------------------------------------------------------------------
   GT_OPER_GEN: if SIM_G = false generate
      GTX7_CORE_GEN : for I in (L_G-1) downto 0  generate
         -- Channel Bonding
         Bond_Master : if (I = 0) generate
            rxChBondIn(I) <= "00000";
         end generate Bond_Master;
         Bond_Slaves : if (I /= 0) generate
            rxChBondIn(I) <= rxChBondOut(I-1);
         end generate Bond_Slaves;
         
         -- Generate GT reset from user reset and global reset
         -- devRst_i - is holding the module in reset for one minute after power-up
         -- User holds the core in reset when the JESD lane is disabled
         s_gtRxReset(I) <= s_gtRxUserReset(I) or devRst_i;
         s_gtTxReset(I) <= s_gtTxUserReset(I) or devRst_i;
         
         Gtx7Core_Inst : entity work.Gtx7Core
            generic map (
               TPD_G                    => TPD_G,
               SIM_GTRESET_SPEEDUP_G    => SIM_GTRESET_SPEEDUP_G,
               SIM_VERSION_G            => SIM_VERSION_G,
               STABLE_CLOCK_PERIOD_G    => STABLE_CLOCK_PERIOD_G,
               CPLL_REFCLK_SEL_G        => CPLL_REFCLK_SEL_G,
               CPLL_FBDIV_G             => CPLL_FBDIV_G,
               CPLL_FBDIV_45_G          => CPLL_FBDIV_45_G,
               CPLL_REFCLK_DIV_G        => CPLL_REFCLK_DIV_G,
               RXOUT_DIV_G              => RXOUT_DIV_G,
               TXOUT_DIV_G              => TXOUT_DIV_G,
               RX_CLK25_DIV_G           => RX_CLK25_DIV_G,
               TX_CLK25_DIV_G           => TX_CLK25_DIV_G,
               PMA_RSV_G                => PMA_RSV_G,
               TX_PLL_G                 => TX_PLL_G,
               RX_PLL_G                 => RX_PLL_G,
               
               -- Data width
               TX_EXT_DATA_WIDTH_G      => GT_WORD_SIZE_C*8,
               TX_INT_DATA_WIDTH_G      => GT_WORD_SIZE_C*8+GT_WORD_SIZE_C*2,
               TX_8B10B_EN_G            => true,
               
               -- Data width
               RX_EXT_DATA_WIDTH_G      => GT_WORD_SIZE_C*8,
               RX_INT_DATA_WIDTH_G      => GT_WORD_SIZE_C*8+GT_WORD_SIZE_C*2,
               RX_8B10B_EN_G            => true,
               
          
               TX_BUF_EN_G              => TX_BUF_EN_G,
               TX_OUTCLK_SRC_G          => TX_OUTCLK_SRC_G,
               TX_DLY_BYPASS_G          => TX_DLY_BYPASS_G,
               TX_PHASE_ALIGN_G         => TX_PHASE_ALIGN_G,
               TX_BUF_ADDR_MODE_G       => TX_BUF_ADDR_MODE_G,
               RX_BUF_EN_G              => true,
               RX_OUTCLK_SRC_G          => "OUTCLKPMA",
               RX_USRCLK_SRC_G          => "RXOUTCLK",    -- Not 100% sure, doesn't really matter
               RX_DLY_BYPASS_G          => '1',
               RX_DDIEN_G               => '0',
               RX_BUF_ADDR_MODE_G       => "FULL",
               RX_ALIGN_MODE_G          => "GT",          -- Default
               ALIGN_COMMA_DOUBLE_G     => "FALSE",       -- Default
               ALIGN_COMMA_ENABLE_G     => "1111111111",  -- Default
               ALIGN_COMMA_WORD_G       => 2,             -- Default
               ALIGN_MCOMMA_DET_G       => "TRUE",
               ALIGN_MCOMMA_VALUE_G     => "1010000011",  -- Default
               ALIGN_MCOMMA_EN_G        => '1',
               ALIGN_PCOMMA_DET_G       => "TRUE",
               ALIGN_PCOMMA_VALUE_G     => "0101111100",  -- Default
               ALIGN_PCOMMA_EN_G        => '1',
               SHOW_REALIGN_COMMA_G     => "FALSE",
               RXSLIDE_MODE_G           => "AUTO",
               RX_DISPERR_SEQ_MATCH_G   => "TRUE",        -- Default
               DEC_MCOMMA_DETECT_G      => "TRUE",        -- Default
               DEC_PCOMMA_DETECT_G      => "TRUE",        -- Default
               DEC_VALID_COMMA_ONLY_G   => "FALSE",       -- Default
               CBCC_DATA_SOURCE_SEL_G   => "DECODED",     -- Default
               CLK_COR_SEQ_2_USE_G      => "FALSE",       -- Default
               CLK_COR_KEEP_IDLE_G      => "FALSE",       -- Default
               CLK_COR_MAX_LAT_G        => 21,
               CLK_COR_MIN_LAT_G        => 18,
               CLK_COR_PRECEDENCE_G     => "TRUE",        -- Default
               CLK_COR_REPEAT_WAIT_G    => 0,             -- Default
               CLK_COR_SEQ_LEN_G        => 4,
               CLK_COR_SEQ_1_ENABLE_G   => "1111",        -- Default
               CLK_COR_SEQ_1_1_G        => "0110111100",
               CLK_COR_SEQ_1_2_G        => "0100011100",
               CLK_COR_SEQ_1_3_G        => "0100011100",
               CLK_COR_SEQ_1_4_G        => "0100011100",
               CLK_CORRECT_USE_G        => "TRUE",
               CLK_COR_SEQ_2_ENABLE_G   => "0000",        -- Default
               CLK_COR_SEQ_2_1_G        => "0000000000",  -- Default
               CLK_COR_SEQ_2_2_G        => "0000000000",  -- Default
               CLK_COR_SEQ_2_3_G        => "0000000000",  -- Default
               CLK_COR_SEQ_2_4_G        => "0000000000",  -- Default
               RX_CHAN_BOND_EN_G        => true,
               RX_CHAN_BOND_MASTER_G    => (i = 0),
               CHAN_BOND_KEEP_ALIGN_G   => "FALSE",       -- Default
               CHAN_BOND_MAX_SKEW_G     => 10,
               CHAN_BOND_SEQ_LEN_G      => 1,             -- Default
               CHAN_BOND_SEQ_1_1_G      => "0110111100",
               CHAN_BOND_SEQ_1_2_G      => "0111011100",
               CHAN_BOND_SEQ_1_3_G      => "0111011100",
               CHAN_BOND_SEQ_1_4_G      => "0111011100",
               CHAN_BOND_SEQ_1_ENABLE_G => "1111",        -- Default
               CHAN_BOND_SEQ_2_1_G      => "0000000000",  -- Default
               CHAN_BOND_SEQ_2_2_G      => "0000000000",  -- Default
               CHAN_BOND_SEQ_2_3_G      => "0000000000",  -- Default
               CHAN_BOND_SEQ_2_4_G      => "0000000000",  -- Default
               CHAN_BOND_SEQ_2_ENABLE_G => "0000",        -- Default
               CHAN_BOND_SEQ_2_USE_G    => "FALSE",       -- Default
               FTS_DESKEW_SEQ_ENABLE_G  => "1111",        -- Default
               FTS_LANE_DESKEW_CFG_G    => "1111",        -- Default
               FTS_LANE_DESKEW_EN_G     => "FALSE",       -- Default
               RX_OS_CFG_G              => RX_OS_CFG_G,
               RXCDR_CFG_G              => RXCDR_CFG_G,
               RX_EQUALIZER_G           => "DFE",         -- Xilinx recommends this for 8b10b
               RXDFEXYDEN_G             => RXDFEXYDEN_G,
               RX_DFE_KL_CFG2_G         => RX_DFE_KL_CFG2_G)
            port map (
               stableClkIn      => stableClk,
               cPllRefClkIn     => '0',
               cPllLockOut      => open,
               
               qPllRefClkIn     => qPllRefClkIn,
               qPllClkIn        => qPllClkIn,
               qPllLockIn       => qPllLockIn,
               qPllRefClkLostIn => qPllRefClkLostIn,
               qPllResetOut     => qPllResetOut(I),
                
               gtRxRefClkBufg   => stableClk,  -- TODO check        
               
               
               gtTxP            => gtTxP(I),
               gtTxN            => gtTxN(I),
               gtRxP            => gtRxP(I),
               gtRxN            => gtRxN(I),
               
               rxOutClkOut      => open,
               rxUsrClkIn       => devClk_i,
               rxUsrClk2In      => devClk2_i,
               rxUserRdyOut     => open,
               rxMmcmResetOut   => open,
               rxMmcmLockedIn   => '1',
               rxUserResetIn    => s_gtRxReset(I),
               rxResetDoneOut   => r_jesdGtRxArr(I).rstDone,
               rxDataValidIn    => '1',
               rxSlideIn        => '0',
               rxDataOut        => r_jesdGtRxArr(I).data,
               rxCharIsKOut     => r_jesdGtRxArr(I).dataK,
               rxDecErrOut      => r_jesdGtRxArr(I).decErr,
               rxDispErrOut     => r_jesdGtRxArr(I).dispErr,
               rxPolarityIn     => '0',
               rxBufStatusOut   => open,
               rxChBondLevelIn  => slv(to_unsigned((L_G-1-I), 3)),
               rxChBondIn       => rxChBondIn(I),
               rxChBondOut      => rxChBondOut(I),
               txOutClkOut      => open,
               txUsrClkIn       => '0',
               txUsrClk2In      => '0',
               txUserRdyOut     => open,
               txMmcmResetOut   => open,
               txMmcmLockedIn   => '1',
               txUserResetIn    => s_gtTxReset(I),
               txResetDoneOut   => s_gtTxReady(I),
               txDataIn         => r_jesdGtTxArr(I).data,
               txCharIsKIn      => r_jesdGtTxArr(I).dataK,
               txBufStatusOut   => open,
               loopbackIn       => "000"
           );
       end generate GTX7_CORE_GEN;
   -----------------------------------------
   end generate GT_OPER_GEN;    
   -----------------------------------------------------
   
   -- Output assignment
   nSync_o <= s_nSync;

end rtl;
