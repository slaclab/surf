-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: JESD204b multi-lane receiver module
--              Receiver JESD204b module.
--              Supports a subset of features from JESD204b standard.
--              Supports sub-class 1 deterministic latency.
--              Supports sub-class 0 non deterministic latency.
--              Features:
--              - Synchronization of LMFC to SYSREF
--              - Multi-lane operation (L_G: 1-16)
--              - Lane alignment using RX buffers
--              - Serial lane error check
--              - Alignment character replacement and alignment check
--
--          Note: sampleDataArr_o is little endian and not byte-swapped
--                First sample in time:  sampleData_o(15 downto 0)
--                Second sample in time: sampleData_o(31 downto 16)
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
use surf.Jesd204bPkg.all;

entity Jesd204bRx is
   generic (
      TPD_G : time := 1 ns;

      GEN_ASYNC_G : boolean := false;   -- default false don't add synchronizer

      -- Test tx module instead of GTX
      TEST_G : boolean := false;

      -- JESD generics

      -- Number of bytes in a frame (1,2,or 4)
      F_G : positive := 2;

      -- Number of frames in a multi frame (32)
      K_G : positive := 32;

      -- Number of RX lanes (1 to 32)
      L_G : positive range 1 to 32 := 2);

   port (
      -- AXI interface
      -- Clocks and Resets
      axiClk : in sl;
      axiRst : in sl;

      -- AXI-Lite Register Interface
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;

      -- Sample data output (Use if external data acquisition core is attached)
      sampleDataArr_o : out sampleDataArray(L_G-1 downto 0);
      dataValidVec_o  : out slv(L_G-1 downto 0);

      -- JESD
      -- Clocks and Resets
      devClk_i : in sl;
      devRst_i : in sl;

      -- SYSREF for subclass 1 fixed latency
      sysRef_i : in sl;

      -- SYSREF output for debug
      sysRefDbg_o : out sl;

      -- Data and character inputs from GT (transceivers)
      r_jesdGtRxArr : in  jesdGtRxLaneTypeArray(L_G-1 downto 0);
      gtRxReset_o   : out slv(L_G-1 downto 0);

      rxPowerDown : out slv(L_G-1 downto 0);
      rxPolarity  : out slv(L_G-1 downto 0);

      -- Synchronization output combined from all receivers
      nSync_o : out sl;

      -- Debug signals
      pulse_o : out slv(L_G-1 downto 0);
      leds_o  : out slv(1 downto 0)
      );
end Jesd204bRx;

architecture rtl of Jesd204bRx is

-- Register
   type RegType is record
      nSyncAnyD1 : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      nSyncAnyD1 => '0'
      );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- Internal signals

   -- Local Multi Frame Clock
   signal s_lmfc : sl;

   -- Synchronization output generation
   signal s_nSyncVec     : slv(L_G-1 downto 0);
   signal s_nSyncVecEn   : slv(L_G-1 downto 0);
   signal s_dataValidVec : slv(L_G-1 downto 0);

   signal s_nSyncAll : sl;
   signal s_nSyncAny : sl;

   -- Control and status from AxiLite
   ------------------------------------------------------------
   signal s_sysrefDlyRx : slv(SYSRF_DLY_WIDTH_C-1 downto 0);
   signal s_enableRx    : slv(L_G-1 downto 0);
   signal s_replEnable  : sl;
   signal s_scrEnable   : sl;
   signal s_invertData  : slv(L_G-1 downto 0);

   -- JESD subclass selection (from AXI lite register)
   signal s_subClass : sl;
   -- User reset (from AXI lite register)
   signal s_gtReset  : sl;

   signal s_invertSync      : sl;
   signal s_clearErr        : sl;
   signal s_statusRxArr     : rxStatuRegisterArray(L_G-1 downto 0);
   signal s_thresoldHighArr : Slv16Array(L_G-1 downto 0);
   signal s_thresoldLowArr  : Slv16Array(L_G-1 downto 0);

   -- Testing registers
   signal s_dlyTxArr   : Slv4Array(L_G-1 downto 0);
   signal s_alignTxArr : alignTxArray(L_G-1 downto 0);


   signal s_sampleDataArr : sampleDataArray(L_G-1 downto 0);

   -- Sysref conditioning
   signal s_sysrefSync : sl;
   signal s_sysrefD    : sl;
   signal s_sysrefRe   : sl;

   -- Record containing GT signals
   signal s_jesdGtRxArr : jesdGtRxLaneTypeArray(L_G-1 downto 0);
   signal s_rawData     : slv32Array(L_G-1 downto 0);

   -- Generate pause signal logic OR
   signal s_linkErrMask : slv(5 downto 0);

begin

   -- Check JESD generics
   assert (((K_G * F_G) mod GT_WORD_SIZE_C) = 0) report "K_G setting is incorrect" severity failure;
   assert (F_G = 1 or F_G = 2 or (F_G = 4 and GT_WORD_SIZE_C = 4)) report "F_G setting must be 1,2,or 4*" severity failure;

   -----------------------------------------------------------
   -- AXI Lite AXI clock domain crossed
   -----------------------------------------------------------

   GEN_rawData : for i in L_G-1 downto 0 generate
      s_rawData(i) <= s_jesdGtRxArr(i).data;
   end generate GEN_rawData;

   -- axiLite register interface
   U_Reg : entity surf.JesdRxReg
      generic map (
         TPD_G => TPD_G,
         L_G   => L_G)
      port map (
         axiClk_i        => axiClk,
         axiRst_i        => axiRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave,

         -- DevClk domain
         devClk_i          => devClk_i,
         devRst_i          => devRst_i,
         sysrefRe_i        => s_sysrefRe,
         statusRxArr_i     => s_statusRxArr,
         rawData_i         => s_rawData,
         linkErrMask_o     => s_linkErrMask,
         sysrefDlyRx_o     => s_sysrefDlyRx,
         enableRx_o        => s_enableRx,
         replEnable_o      => s_replEnable,
         scrEnable_o       => s_scrEnable,
         dlyTxArr_o        => s_dlyTxArr,
         alignTxArr_o      => s_alignTxArr,
         subClass_o        => s_subClass,
         gtReset_o         => s_gtReset,
         clearErr_o        => s_clearErr,
         invertSync_o      => s_invertSync,
         invertData_o      => s_invertData,
         thresoldHighArr_o => s_thresoldHighArr,
         thresoldLowArr_o  => s_thresoldLowArr,
         rxPowerDown       => rxPowerDown,
         rxPolarity        => rxPolarity);

   -----------------------------------------------------------
   -- TEST or OPER
   -----------------------------------------------------------
   -- IF DEF TEST_G

   -- Generate TX test core if TEST_G=true is selected
   TEST_GEN : if TEST_G = true generate
      -----------------------------------------
      TX_LANES_GEN : for i in L_G-1 downto 0 generate
         JesdTxTest_INST : entity surf.JesdTxTest
            generic map (
               TPD_G => TPD_G)
            port map (
               devClk_i      => devClk_i,
               devRst_i      => devRst_i,
               enable_i      => s_enableRx(i),
               delay_i       => s_dlyTxArr(i),
               align_i       => s_alignTxArr(i),
               lmfc_i        => s_lmfc,
               nSync_i       => r.nSyncAnyD1,
               r_jesdGtRx    => s_jesdGtRxArr(i),
               subClass_i    => s_subClass,
               txDataValid_o => open);
      end generate TX_LANES_GEN;
   end generate TEST_GEN;

   -- ELSE   (not TEST_G) just connect to the input from the MGT
   GT_OPER_GEN : if TEST_G = false generate
      -----------------------------------------
      -- Use input from GTX
      s_jesdGtRxArr <= r_jesdGtRxArr;
   end generate GT_OPER_GEN;
   ----------------------------------------

   -----------------------------------------------------------
   -- SYSREF and LMFC
   -----------------------------------------------------------

   GEN_ASYNC : if (GEN_ASYNC_G = true) generate
      -- Synchronize SYSREF input to devClk_i
      Synchronizer_INST : entity surf.Synchronizer
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
   end generate;

   GEN_SYNC : if (GEN_ASYNC_G = false) generate
      process(devClk_i)
      begin
         if rising_edge(devClk_i) then
            s_sysrefSync <= sysref_i after TPD_G;
         end if;
      end process;
   end generate;

   -- Delay SYSREF input (for 1 to 256 c-c)
   U_SysrefDly : entity surf.SlvDelay
      generic map (
         TPD_G        => TPD_G,
         REG_OUTPUT_G => true,
         DELAY_G      => 2**SYSRF_DLY_WIDTH_C)
      port map (
         clk     => devClk_i,
         rst     => devRst_i,
         delay   => s_sysrefDlyRx,
         din(0)  => s_sysrefSync,
         dout(0) => s_sysrefD);

   -- LMFC period generator aligned to SYSREF input
   LmfcGen_INST : entity surf.JesdLmfcGen
      generic map (
         TPD_G => TPD_G,
         K_G   => K_G,
         F_G   => F_G)
      port map (
         clk        => devClk_i,
         rst        => devRst_i,
         --nSync_i     => '0', -- r.nSyncAnyD1,
         nSync_i    => r.nSyncAnyD1,
         sysref_i   => s_sysrefD,       -- Delayed SYSREF IN
         sysrefRe_o => s_sysrefRe,      -- Rising-edge of SYSREF OUT
         lmfc_o     => s_lmfc
         );

   -----------------------------------------------------------
   -- Receiver modules (L_G)
   -----------------------------------------------------------

   -- JESD Receiver modules (one module per Lane)
   generateRxLanes : for i in L_G-1 downto 0 generate
      JesdRx_INST : entity surf.JesdRxLane
         generic map (
            TPD_G => TPD_G,
            F_G   => F_G,
            K_G   => K_G)
         port map (
            devClk_i      => devClk_i,
            devRst_i      => devRst_i,
            sysRef_i      => s_sysrefRe,  -- Rising-edge of SYSREF
            enable_i      => s_enableRx(i),
            clearErr_i    => s_clearErr,
            linkErrMask_i => s_linkErrMask,
            replEnable_i  => s_replEnable,
            scrEnable_i   => s_scrEnable,
            inv_i         => s_invertData(i),
            status_o      => s_statusRxArr(i),
            r_jesdGtRx    => s_jesdGtRxArr(i),
            lmfc_i        => s_lmfc,
            nSyncAnyD1_i  => r.nSyncAnyD1,
            nSyncAny_i    => s_nSyncAny,
            nSync_o       => s_nSyncVec(i),
            dataValid_o   => s_dataValidVec(i),
            sampleData_o  => s_sampleDataArr(i),
            subClass_i    => s_subClass
            );
   end generate;

   -- Test signal generator
   generatePulserLanes : for i in L_G-1 downto 0 generate
      Pulser_INST : entity surf.JesdTestSigGen
         generic map (
            TPD_G => TPD_G,
            F_G   => F_G)
         port map (
            clk            => devClk_i,
            rst            => devRst_i,
            enable_i       => s_dataValidVec(i),
            thresoldLow_i  => s_thresoldLowArr(i),
            thresoldHigh_i => s_thresoldHighArr(i),
            sampleData_i   => s_sampleDataArr(i),
            testSig_o      => pulse_o(i));
   end generate;

   -- Put sync output in 'z' if not enabled
   syncVectEn : for i in L_G-1 downto 0 generate
      s_nSyncVecEn(i) <= s_nSyncVec(i) or not s_enableRx(i);
   end generate syncVectEn;

   -- Combine nSync signals from all receivers
   s_nSyncAny <= '0' when allBits (s_enableRx, '0') else uAnd(s_nSyncVecEn);

   -- DFF
   comb : process (devRst_i, s_nSyncAny) is
      variable v : RegType;
   begin
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

   -- Invert/or not nSync signal (control from axil)
   nSync_o         <= r.nSyncAnyD1 when s_invertSync = '0' else not r.nSyncAnyD1;
   gtRxReset_o     <= (others => s_gtReset);
   leds_o          <= uOr(s_dataValidVec) & s_nSyncAny;
   sysRefDbg_o     <= s_sysrefD;
   sampleDataArr_o <= s_sampleDataArr;
   dataValidVec_o  <= s_dataValidVec;

-----------------------------------------------------
end rtl;
