-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: JESD204b multi-lane transmitter module
--              Transmitter JESD204b module.
--              Supports a subset of features from JESD204b standard.
--              Supports sub-class 1 deterministic latency.
--              Supports sub-class 0 non deterministic latency.
--              Features:
--              - Synchronization of LMFC to SYSREF
--              - Multi-lane operation (L_G: 1-32)
--
--          Warning: Scrambling support has not been tested on the TX module yet.
--
--          Note: extSampleDataArray_i should be little endian and not byte swapped
--                First sample in time:  sampleData_i(15 downto 0)
--                Second sample in time: sampleData_i(31 downto 16)
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

entity Jesd204bTx is
   generic (
      TPD_G        : time                   := 1 ns;
      -- Register sample data at input and/or output
      INPUT_REG_G  : boolean                := false;
      OUTPUT_REG_G : boolean                := false;
      -- Number of bytes in a frame
      F_G          : positive               := 2;
      -- Number of frames in a multi frame
      K_G          : positive               := 32;
      -- Number of TX lanes (1 to 32)
      L_G          : positive range 1 to 32 := 2);
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

      -- JESD
      -- Clocks and Resets
      devClk_i : in sl;
      devRst_i : in sl;

      -- SYSREF for subclass 1 fixed latency
      sysRef_i : in sl;

      -- Synchronization input combined from all receivers
      nSync_i : in slv(L_G-1 downto 0);

      -- External sample data input
      extSampleDataArray_i : in  sampleDataArray(L_G-1 downto 0);
      dacReady_o           : out slv(L_G-1 downto 0);

      -- GT is ready to transmit data after reset
      gtTxReset_o : out slv(L_G-1 downto 0);
      gtTxReady_i : in  slv(L_G-1 downto 0);

      -- Data and character inputs from GT (transceivers)
      r_jesdGtTxArr : out jesdGtTxLaneTypeArray(L_G-1 downto 0);

      -- TX Configurable Driver Ports
      txDiffCtrl   : out Slv8Array(L_G-1 downto 0);
      txPostCursor : out Slv8Array(L_G-1 downto 0);
      txPreCursor  : out Slv8Array(L_G-1 downto 0);
      txPowerDown  : out slv(L_G-1 downto 0);
      txPolarity   : out slv(L_G-1 downto 0);
      loopback     : out slv(L_G-1 downto 0);
      txEnable     : out slv(L_G-1 downto 0);
      txEnableL    : out slv(L_G-1 downto 0);

      -- Debug signals
      pulse_o : out slv(L_G-1 downto 0);
      leds_o  : out slv(1 downto 0));
end Jesd204bTx;

architecture rtl of Jesd204bTx is

   -- Internal signals

   -- Local Multi Frame Clock
   signal s_lmfc : slv(L_G-1 downto 0);

   -- Control and status from AxiLite
   ------------------------------------------------------------
   signal s_sysrefDlyTx : slv(SYSRF_DLY_WIDTH_C-1 downto 0);
   signal s_enableTx    : slv(L_G-1 downto 0);
   signal s_replEnable  : sl;
   signal s_scrEnable   : sl;
   signal s_statusTxArr : txStatuRegisterArray(L_G-1 downto 0);
   signal s_dataValid   : slv(L_G-1 downto 0);
   signal s_invertData  : slv(L_G-1 downto 0);

   -- JESD subclass selection (from AXI lite register)
   signal s_subClass      : sl;
   -- User reset (from AXI lite register)
   signal s_gtReset       : sl;
   signal s_clearErr      : sl;
   signal s_sigTypeArr    : Slv2Array(L_G-1 downto 0);
   -- Test signal control
   signal s_rampStep      : slv(PER_STEP_WIDTH_C-1 downto 0);
   signal s_squarePeriod  : slv(PER_STEP_WIDTH_C-1 downto 0);

   signal s_posAmplitude : slv(F_G*8-1 downto 0);
   signal s_negAmplitude : slv(F_G*8-1 downto 0);

   -- Data out multiplexer
   signal s_testDataArr      : sampleDataArray(L_G-1 downto 0);
   signal s_extDataArraySwap : sampleDataArray(L_G-1 downto 0);

   signal s_regSampleDataIn  : sampleDataArray(L_G-1 downto 0);
   signal s_regSampleDataOut : sampleDataArray(L_G-1 downto 0);

   signal s_sampleDataArr : sampleDataArray(L_G-1 downto 0);

   -- Sysref conditioning
   signal s_sysrefSync : sl;
   signal s_sysrefRe   : slv(L_G-1 downto 0);
   signal s_sysrefD    : sl;

   -- Sync conditioning
   signal s_nSync      : slv(L_G-1 downto 0);
   signal s_invertSync : sl;
   signal s_nSyncSync  : slv(L_G-1 downto 0);

   -- Select output
   signal s_muxOutSelArr : Slv3Array(L_G-1 downto 0);
   signal s_jesdGtTxArr  : jesdGtTxLaneTypeArray(L_G-1 downto 0);

begin

   ----------------------
   -- Input data register
   ----------------------
   GEN_REG_I : if (INPUT_REG_G = true) generate
      GEN_LANE : for i in L_G-1 downto 0 generate
         process(devClk_i)
         begin
            if rising_edge(devClk_i) then
               s_regSampleDataIn(i) <= extSampleDataArray_i(i) after TPD_G;
            end if;
         end process;
      end generate GEN_LANE;
   end generate GEN_REG_I;

   GEN_N_REG_I : if (INPUT_REG_G = false) generate
      s_regSampleDataIn <= extSampleDataArray_i;
   end generate GEN_N_REG_I;

   GEN_VALID : for i in L_G-1 downto 0 generate
      s_dataValid(i) <= s_statusTxArr(i)(1);
   end generate GEN_VALID;

   txEnable  <= s_enableTx;
   txEnableL <= not(s_enableTx);

   ---------------------
   -- AXI-Lite registers
   ---------------------
   U_Reg : entity surf.JesdTxReg
      generic map (
         TPD_G => TPD_G,
         L_G   => L_G,
         F_G   => F_G)
      port map (
         axiClk_i        => axiClk,
         axiRst_i        => axiRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave,
         -- DevClk domain
         devClk_i        => devClk_i,
         devRst_i        => devRst_i,
         sysrefRe_i      => s_sysrefRe(0),
         statusTxArr_i   => s_statusTxArr,
         muxOutSelArr_o  => s_muxOutSelArr,
         sysrefDlyTx_o   => s_sysrefDlyTx,
         enableTx_o      => s_enableTx,
         replEnable_o    => s_replEnable,
         scrEnable_o     => s_scrEnable,
         invertData_o    => s_invertData,
         subClass_o      => s_subClass,
         gtReset_o       => s_gtReset,
         clearErr_o      => s_clearErr,
         sigTypeArr_o    => s_sigTypeArr,
         posAmplitude_o  => s_posAmplitude,
         negAmplitude_o  => s_negAmplitude,
         rampStep_o      => s_rampStep,
         squarePeriod_o  => s_squarePeriod,
         invertSync_o    => s_invertSync,
         -- TX Configurable Driver Ports
         txDiffCtrl      => txDiffCtrl,
         txPostCursor    => txPostCursor,
         txPreCursor     => txPreCursor,
         txPowerDown     => txPowerDown,
         txPolarity      => txPolarity,
         loopback        => loopback);

   GEN_TEST : for i in L_G-1 downto 0 generate

      U_TestStream : entity surf.JesdTestStreamTx
         generic map (
            TPD_G => TPD_G,
            F_G   => F_G)
         port map (
            clk            => devClk_i,
            rst            => devRst_i,
            enable_i       => s_dataValid(i),
            rampStep_i     => s_rampStep,
            squarePeriod_i => s_squarePeriod,
            posAmplitude_i => s_posAmplitude,
            negAmplitude_i => s_negAmplitude,
            type_i         => s_sigTypeArr(i),
            pulse_o        => pulse_o(i),
            sampleData_o   => s_testDataArr(i));

   end generate GEN_TEST;

   -- Sample data mux
   GEN_MUX : for i in L_G-1 downto 0 generate

      -- Swap endian (the module is built to use big endian data but the interface is little endian)
      s_extDataArraySwap(i) <= endianSwapSlv(s_regSampleDataIn(i), GT_WORD_SIZE_C);

      -- Separate mux for separate lane
      process(devClk_i)
      begin
         if rising_edge(devClk_i) then
            if (s_muxOutSelArr(i) = "000") then
               s_sampleDataArr(i) <= outSampleZero(F_G, GT_WORD_SIZE_C) after TPD_G;
            elsif (s_muxOutSelArr(i) = "001") then
               s_sampleDataArr(i) <= s_extDataArraySwap(i) after TPD_G;
            elsif (s_muxOutSelArr(i) = "010") then
               s_sampleDataArr(i) <= (others => '1') after TPD_G;
            else
               s_sampleDataArr(i) <= s_testDataArr(i) after TPD_G;
            end if;
         end if;
      end process;

   end generate GEN_MUX;

   -----------------------------------------------------------
   -- SYSREF, SYNC, and LMFC
   -----------------------------------------------------------

   -- Synchronize SYSREF input to devClk_i
   Synchronizer_sysref_INST : entity surf.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => devClk_i,
         rst     => devRst_i,
         dataIn  => sysref_i,
         dataOut => s_sysrefSync);

   -- Invert/or not nSync signal (control from axil)
   s_nSync <= nSync_i when s_invertSync = '0' else not nSync_i;

   -- Synchronize nSync input to devClk_i
   Synchronizer_nsync_INST : entity surf.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => L_G)
      port map (
         clk     => devClk_i,
         rst     => devRst_i,
         dataIn  => s_nSync,
         dataOut => s_nSyncSync);

   -- Delay SYSREF input (for 1 to 256 c-c)
   U_SysrefDly : entity surf.SlvDelay
      generic map (
         TPD_G        => TPD_G,
         REG_OUTPUT_G => true,
         DELAY_G      => 2**SYSRF_DLY_WIDTH_C)
      port map (
         clk     => devClk_i,
         rst     => devRst_i,
         delay   => s_sysrefDlyTx,
         din(0)  => s_sysrefSync,
         dout(0) => s_sysrefD);

   ----------------------------
   -- Transmitter modules (L_G)
   ----------------------------
   GEN_TX : for i in L_G-1 downto 0 generate

      -- LMFC period generator aligned to SYSREF input
      U_LmfcGen : entity surf.JesdLmfcGen
         generic map (
            TPD_G => TPD_G,
            K_G   => K_G,
            F_G   => F_G)
         port map (
            clk        => devClk_i,
            rst        => devRst_i,
            nSync_i    => s_nSyncSync(i),
            sysref_i   => s_sysrefD,
            sysrefRe_o => s_sysrefRe(i),      -- Rising-edge of SYSREF OUT
            lmfc_o     => s_lmfc(i));

      -- JESD Transmitter modules (one module per Lane)
      U_JesdTxLane : entity surf.JesdTxLane
         generic map (
            TPD_G => TPD_G,
            F_G   => F_G,
            K_G   => K_G)
         port map (
            devClk_i     => devClk_i,
            devRst_i     => devRst_i,
            subClass_i   => s_subClass,        -- From AXI lite
            enable_i     => s_enableTx(i),     -- From AXI lite
            replEnable_i => s_replEnable,      -- From AXI lite
            scrEnable_i  => s_scrEnable,       -- From AXI lite
            inv_i        => s_invertData(i),   -- From AXI lite
            lmfc_i       => s_lmfc(i),
            nSync_i      => s_nSyncSync(i),
            gtTxReady_i  => gtTxReady_i(i),
            sysRef_i     => s_sysrefRe(i),
            status_o     => s_statusTxArr(i),  -- To AXI lite
            dacReady_o   => dacReady_o(i),
            sampleData_i => s_sampleDataArr(i),
            r_jesdGtTx   => s_jesdGtTxArr(i));

   end generate GEN_TX;

   ------------------
   -- Output register
   ------------------
   GEN_REG_O : if (OUTPUT_REG_G = true) generate
      GEN_LANE : for i in L_G-1 downto 0 generate
         process(devClk_i)
         begin
            if rising_edge(devClk_i) then
               r_jesdGtTxArr(i).data  <= s_jesdGtTxArr(i).data  after TPD_G;
               r_jesdGtTxArr(i).dataK <= s_jesdGtTxArr(i).dataK after TPD_G;
            end if;
         end process;
      end generate GEN_LANE;
   end generate GEN_REG_O;

   GEN_N_REG_O : if (OUTPUT_REG_G = false) generate
      r_jesdGtTxArr <= s_jesdGtTxArr;
   end generate GEN_N_REG_O;

   -- Output assignment
   gtTxReset_o <= (others => s_gtReset);
   leds_o      <= uOr(s_dataValid) & uAnd(s_nSyncSync);

end rtl;
