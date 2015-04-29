-------------------------------------------------------------------------------
-- Title      : JESD204b module
-------------------------------------------------------------------------------
-- File       : Jesd204b.vhd
-- Author     : Uros Legat  <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory (Cosylab)
-- Created    : 2015-04-14
-- Last update: 2015-04-14
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Module supports a subset of features from JESD204b standard.
--              information.
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

use work.Jesd204bPkg.all;

entity Jesd204b is
   generic (
      TPD_G             : time                        := 1 ns;
      
   -- Test tx module instead of GTX
      TEST_G            : boolean                     := true;
      
   -- AXI Lite and stream generics
      AXI_ERROR_RESP_G  : slv(1 downto 0)             := AXI_RESP_SLVERR_C;
      AXI_PACKET_SIZE_G : natural range 1 to (2**24)  :=2**8;
      
   -- JESD generics
   
      -- Number of bytes in a frame
      F_G : positive := 2;
      
      -- Number of frames in a multi frame
      K_G : positive := 32;
      
      --Number of lanes (1 to 8)
      L_G : positive := 2;
      
      --Transceiver word size (GTP,GTX,GTH) (2 or 4 supported)
      GT_WORD_SIZE_G : positive := 4;
      
      --JESD204B class (0 and 1 supported)
      SUB_CLASS_G : positive := 1
   );

   port (
   -- AXI interface      
      -- Clocks and Resets
      axiClk         : in    sl;
      axiRst         : in    sl;
      
      -- AXI-Lite Register Interface
      axilReadMaster  : in    AxiLiteReadMasterType;
      axilReadSlave   : out   AxiLiteReadSlaveType;
      axilWriteMaster : in    AxiLiteWriteMasterType;
      axilWriteSlave  : out   AxiLiteWriteSlaveType;
      
      -- AXI Streaming Interface
      txAxisMasterArr_o  : out   AxiStreamMasterArray(L_G-1 downto 0);
      txCtrlArr_i        : in    AxiStreamCtrlArray(L_G-1 downto 0);   
      
   -- JESD
      -- Clocks and Resets   
      devClk_i       : in    sl;    
      devRst_i       : in    sl;
      
      -- SYSREF for subcalss 1 fixed latency
      sysRef_i       : in    sl;

      -- Data and character inputs from GT (transceivers)
      r_jesdGtRxArr  : in   jesdGtRxLaneTypeArray(L_G-1 downto 0);
      gt_reset_o     : out  slv(L_G-1 downto 0);    

      -- Synchronisation output combined from all receivers 
      nSync_o        : out   sl
   );
end Jesd204b;

architecture rtl of Jesd204b is
 
-- Register
   type RegType is record
      nSyncAllD1 : sl;
      nSyncAnyD1 : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      nSyncAllD1  => '0',
      nSyncAnyD1  => '0'
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

-- Internal signals

-- Local Multi Frame Clock 
signal s_lmfc   : sl;

-- Synchronisation output generation
signal s_nSyncVec       : slv(L_G-1 downto 0);
signal s_dataValidVec   : slv(L_G-1 downto 0);

signal s_nSyncAll   : sl;
signal s_nSyncAny   : sl;

-- Control and status from AxiLie
signal s_sysrefDlyRx  : slv(SYSRF_DLY_WIDTH_C-1 downto 0); 
signal s_enableRx     : slv(L_G-1 downto 0);
signal s_statusRxArr  : Slv8Array(L_G-1 downto 0);

-- Axi Lite interface synced to devClk
signal sAxiReadMasterDev : AxiLiteReadMasterType;
signal sAxiReadSlaveDev  : AxiLiteReadSlaveType;
signal sAxiWriteMasterDev: AxiLiteWriteMasterType;
signal sAxiWriteSlaveDev : AxiLiteWriteSlaveType;

-- Axi Stream
signal s_sampleDataArr : AxiTxDataType(L_G-1 downto 0);

-- Sysref conditioning
signal  s_sysrefSync : sl;
signal  s_sysrefD    : sl;

-- Record containing GT signals
signal s_jesdGtRxArr : jesdGtRxLaneTypeArray(L_G-1 downto 0);



begin
   -- Check generics TODO add others
   assert (GT_WORD_SIZE_G = 2 or GT_WORD_SIZE_G = 4) report "GT_WORD_SIZE_G must be 2 or 4" severity failure;
   assert (1 < L_G and L_G < 8)                      report "L_G must be between 1 and 8"   severity failure;

   -- AXI stream interface one module per lane
   generateAxiStreamLanes : for I in L_G-1 downto 0 generate
      AxiStreamLaneTx_INST: entity work.AxiStreamLaneTx
      generic map (
         TPD_G             => TPD_G,
         AXI_ERROR_RESP_G  => AXI_ERROR_RESP_G,
         AXI_PACKET_SIZE_G => AXI_PACKET_SIZE_G,
         
         GT_WORD_SIZE_G    => GT_WORD_SIZE_G)
      port map (
         devClk_i       => devClk_i,
         devRst_i       => devRst_i,
         txAxisMaster_o => txAxisMasterArr_o(I),
         txCtrl_i       => txCtrlArr_i(I),
         enable_i       => s_enableRx(I),
         sampleData_i   => s_sampleDataArr(I),
         dataReady_i    => s_dataValidVec(I)
      );
   end generate generateAxiStreamLanes;

   -- Synchronise axiLite interface to devClk
   AxiLiteAsync_INST: entity work.AxiLiteAsync
   generic map (
      TPD_G           => TPD_G,
      NUM_ADDR_BITS_G => 32
   )
   port map (
      -- In
      sAxiClk         => axiClk,
      sAxiClkRst      => axiRst,
      sAxiReadMaster  => axilReadMaster,
      sAxiReadSlave   => axilReadSlave,
      sAxiWriteMaster => axilWriteMaster,
      sAxiWriteSlave  => axilWriteSlave,
      
      -- Out
      mAxiClk         => devClk_i,
      mAxiClkRst      => devRst_i,
      mAxiReadMaster  => sAxiReadMasterDev,
      mAxiReadSlave   => sAxiReadSlaveDev,
      mAxiWriteMaster => sAxiWriteMasterDev,
      mAxiWriteSlave  => sAxiWriteSlaveDev
   );

   -- axiLite register interface
   AxiLiteRegItf_INST: entity work.AxiLiteRegItf
   generic map (
      TPD_G            => TPD_G,
      AXI_ERROR_RESP_G => AXI_ERROR_RESP_G,
      L_G              => L_G)
   port map (
      devClk_i        => devClk_i,
      devRst_i        => devRst_i,
      axilReadMaster  => sAxiReadMasterDev,
      axilReadSlave   => sAxiReadSlaveDev,
      axilWriteMaster => sAxiWriteMasterDev,
      axilWriteSlave  => sAxiWriteSlaveDev,
      statusRxArr_i   => s_statusRxArr,
      sysrefDlyRx_o   => s_sysrefDlyRx,
      enableRx_o      => s_enableRx
   );
  
   -- LMFC period generator aligned to SYSREF input
   -------------------------------------------------------------------------
   LmfcGen_INST: entity work.LmfcGen
   generic map (
      TPD_G          => TPD_G,
      K_G            => K_G,
      F_G            => F_G,
      GT_WORD_SIZE_G => GT_WORD_SIZE_G)
   port map (
      clk      => devClk_i,
      rst      => devRst_i,
      nSync_i  => r.nSyncAllD1,
      sysref_i => s_sysrefD,
      lmfc_o   => s_lmfc 
   );

   -- IF DEF
   
   -- Generate TX test core if TEST_G=true is selected
   GenerateTest: if TEST_G = true generate
   -----------------------------------------
      GenerateTxLanes : for I in L_G-1 downto 0 generate    
         JesdTxSimple_INST: entity work.JesdTxTest
            generic map (
               TPD_G          => TPD_G,
               F_G            => F_G,
               K_G            => K_G,
               GT_WORD_SIZE_G => GT_WORD_SIZE_G,
               SUB_CLASS_G    => SUB_CLASS_G)
            port map (
               devClk_i      => devClk_i,
               devRst_i      => devRst_i,
               enable_i      => s_enableRx(I),
               r_jesdGtRx    => s_jesdGtRxArr(I),
               lmfc_i        => s_lmfc,
               nSync_i       => r.nSyncAllD1,
               txDataValid_o => open);
      end generate GenerateTxLanes;
      
      -- Sysref connected to enable (rsysref works on rising edge)
      s_sysrefSync <= s_enableRx(0) or s_enableRx(1);

   ----------------------------------------       
   end generate GenerateTest;
   
   -- ELSE   
   
   GenerateOper: if TEST_G = false generate
   -----------------------------------------
      -- Use input from GTX
      s_jesdGtRxArr <= r_jesdGtRxArr;
      
      -- Synchronise SYSREF input to devClk_i
      Synchronizer_INST: entity work.Synchronizer
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => '1',
         OUT_POLARITY_G => '1',
         RST_ASYNC_G    => false,
         STAGES_G       => 2,
         BYPASS_SYNC_G  => false,
         INIT_G         => "0")
      port map (
         clk     => devClk_i,
         rst     => devRst_i,
         dataIn  => sysref_i,
         dataOut => s_sysrefSync
      );
   -----------------------------------------
   end generate GenerateOper;

   -- Delay SYSREF input (for 1 to 32 c-c)
   SysrefDly_INST: entity work.SysrefDly
   generic map (
      TPD_G       => TPD_G,
      DLY_WIDTH_G => SYSRF_DLY_WIDTH_C 
   )
   port map (
      clk      => devClk_i,
      rst      => devRst_i,
      dly_i    => s_sysrefDlyRx,
      sysref_i => s_sysrefSync,
      sysref_o => s_sysrefD
   );
   
   
   -- JESD Receiver modules (one module per Lane)
   generateRxLanes : for I in L_G-1 downto 0 generate    
      JesdRx_INST: entity work.JesdRx
      generic map (
         TPD_G          => TPD_G,
         F_G            => F_G,
         K_G            => K_G,
         GT_WORD_SIZE_G => GT_WORD_SIZE_G,
         SUB_CLASS_G    => SUB_CLASS_G)
      port map (
         devClk_i     => devClk_i,
         devRst_i     => devRst_i,
         sysRef_i     => s_sysrefD,
         enable_i     => s_enableRx(I),
         status_o     => s_statusRxArr(I),
         r_jesdGtRx   => s_jesdGtRxArr(I),
         lmfc_i       => s_lmfc,
         nSyncAll_i   => r.nSyncAllD1,
         nSyncAny_i   => r.nSyncAnyD1,
         nSync_o      => s_nSyncVec(I),
         dataValid_o  => s_dataValidVec(I),
         sampleData_o => s_sampleDataArr(I)
      );
   end generate;
   
   -- Combine nSync signals from all receivers
   s_nSyncAll <= uOr(s_nSyncVec);
   s_nSyncAny <= uAnd(s_nSyncVec);
   
   -- DFF
   comb : process (r, devRst_i, s_nSyncAll, s_nSyncAny) is
      variable v : RegType;
   begin
      v.nSyncAllD1 := s_nSyncAll;
      v.nSyncAnyD1 := s_nSyncAny;
      
      if (devRst_i = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;
   end process comb;

   seq : process (devClk_i) is
   begin
      if (rising_edge(devClk_i)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   -- Output assignment
   nSync_o     <= r.nSyncAllD1;
   gt_reset_o  <= not s_enableRx;
   -----------------------------------------------------
end rtl;
