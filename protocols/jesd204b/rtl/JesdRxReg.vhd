-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:  AXI-Lite interface for register access
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


library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.Jesd204bPkg.all;

entity JesdRxReg is
   generic (
      -- General Configurations
      TPD_G            : time                   := 1 ns;
      AXI_ADDR_WIDTH_G : positive               := 10;
      -- JESD
      -- Number of RX lanes (1 to 32)
      L_G              : positive range 1 to 32 := 2);
   port (
      -- AXI Clk
      axiClk_i : in sl;
      axiRst_i : in sl;

      -- Axi-Lite Register Interface (locClk domain)
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType;

      -- JESD devClk
      devClk_i : in sl;
      devRst_i : in sl;

      -- JESD registers
      -- Status
      sysrefRe_i    : in sl;
      statusRxArr_i : in rxStatuRegisterArray(L_G-1 downto 0);
      rawData_i     : in slv32Array(L_G-1 downto 0);

      -- Control
      sysrefDlyRx_o     : out slv(SYSRF_DLY_WIDTH_C-1 downto 0);
      enableRx_o        : out slv(L_G-1 downto 0);
      replEnable_o      : out sl;
      scrEnable_o       : out sl;
      invertData_o      : out slv(L_G-1 downto 0);
      dlyTxArr_o        : out Slv4Array(L_G-1 downto 0);  -- 1 to 16 clock cycles
      alignTxArr_o      : out alignTxArray(L_G-1 downto 0);  -- 0001, 0010, 0100, 1000
      thresoldLowArr_o  : out Slv16Array(L_G-1 downto 0);  -- Test signal threshold low
      thresoldHighArr_o : out Slv16Array(L_G-1 downto 0);  -- Test signal threshold high
      subClass_o        : out sl;
      gtReset_o         : out sl;
      clearErr_o        : out sl;
      invertSync_o      : out sl;
      linkErrMask_o     : out slv(5 downto 0);
      rxPowerDown       : out slv(L_G-1 downto 0);
      rxPolarity        : out slv(L_G-1 downto 0));
end JesdRxReg;

architecture rtl of JesdRxReg is

   type RegType is record
      -- JESD Control (RW)
      enableRx       : slv(L_G-1 downto 0);
      invertData     : slv(L_G-1 downto 0);
      commonCtrl     : slv(5 downto 0);
      linkErrMask    : slv(5 downto 0);
      sysrefDlyRx    : slv(SYSRF_DLY_WIDTH_C-1 downto 0);
      testTXItf      : Slv16Array(L_G-1 downto 0);
      testSigThr     : Slv32Array(L_G-1 downto 0);
      rxPolarity     : slv(L_G-1 downto 0);
      rxPowerDown    : slv(L_G-1 downto 0);
      -- AXI lite
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
   end record;

   constant REG_INIT_C : RegType := (
      -- JESD Control (RW)
      enableRx       => (others => '0'),
      invertData     => (others => '0'),
      commonCtrl     => "010111",
      linkErrMask    => "111111",
      sysrefDlyRx    => (others => '0'),
      testTXItf      => (others => x"0000"),
      testSigThr     => (others => x"A000_5000"),
      rxPolarity     => (others => '0'),
      rxPowerDown    => (others => '0'),
      -- AXI lite
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- Integer address
   signal s_RdAddr : natural := 0;
   signal s_WrAddr : natural := 0;

   -- Synced status signals
   signal s_statusRxArr : rxStatuRegisterArray(L_G-1 downto 0);
   signal s_rawData     : slv32Array(L_G-1 downto 0);
   signal s_statusCnt   : SlVectorArray(L_G-1 downto 0, 31 downto 0);
   signal s_adcValids   : slv(L_G-1 downto 0);

   signal sysrefDlyRx     : slv(SYSRF_DLY_WIDTH_C-1 downto 0);
   signal enableRx        : slv(L_G-1 downto 0);
   signal replEnable      : sl;
   signal scrEnable       : sl;
   signal invertData      : slv(L_G-1 downto 0);
   signal dlyTxArr        : Slv4Array(L_G-1 downto 0);
   signal alignTxArr      : alignTxArray(L_G-1 downto 0);
   signal thresoldLowArr  : Slv16Array(L_G-1 downto 0);
   signal thresoldHighArr : Slv16Array(L_G-1 downto 0);
   signal subClass        : sl;
   signal gtReset         : sl;
   signal clearErr        : sl;
   signal invertSync      : sl;
   signal linkErrMask     : slv(5 downto 0);

   signal sysRefPeriodmin : slv(15 downto 0);
   signal sysRefPeriodmax : slv(15 downto 0);

begin

   U_JesdSysrefMon : entity surf.JesdSysrefMon
      generic map (
         TPD_G => TPD_G)
      port map (
         -- SYSREF Edge detection (devClk domain)
         devClk          => devClk_i,
         sysrefEdgeDet_i => sysrefRe_i,
         -- Max/Min measurements  (axilClk domain)
         axilClk         => axiClk_i,
         statClr         => r.commonCtrl(3),
         sysRefPeriodmin => sysRefPeriodmin,
         sysRefPeriodmax => sysRefPeriodmax);

   ----------------------------------------------------------------------------------------------
   -- Data Valid Status Counter
   ----------------------------------------------------------------------------------------------
   GEN_LANES : for i in L_G-1 downto 0 generate
      s_adcValids(i) <= statusRxArr_i(i)(1);
   end generate GEN_LANES;


   U_SyncStatusVector : entity surf.SyncStatusVector
      generic map (
         TPD_G          => TPD_G,
         OUT_POLARITY_G => '1',
         CNT_RST_EDGE_G => true,
         CNT_WIDTH_G    => 32,
         WIDTH_G        => L_G)
      port map (
         -- Input Status bit Signals (wrClk domain)
         statusIn  => s_adcValids,
         -- Output Status bit Signals (rdClk domain)
         statusOut => open,
         -- Status Bit Counters Signals (rdClk domain)
         cntRstIn  => r.commonCtrl(3),
         cntOut    => s_statusCnt,
         -- Clocks and Reset Ports
         wrClk     => devClk_i,
         rdClk     => axiClk_i);

   -- Convert address to integer (lower two bits of address are always '0')
   s_RdAddr <= slvToInt(axilReadMaster.araddr(AXI_ADDR_WIDTH_G-1 downto 2));
   s_WrAddr <= slvToInt(axilWriteMaster.awaddr(AXI_ADDR_WIDTH_G-1 downto 2));

   comb : process (axiRst_i, axilReadMaster, axilWriteMaster, r, s_RdAddr,
                   s_WrAddr, s_rawData, s_statusCnt, s_statusRxArr,
                   sysRefPeriodmax, sysRefPeriodmin) is
      variable v             : RegType;
      variable axilStatus    : AxiLiteStatusType;
      variable axilWriteResp : slv(1 downto 0);
      variable axilReadResp  : slv(1 downto 0);
   begin
      -- Latch the current value
      v := r;

      ----------------------------------------------------------------------------------------------
      -- Axi-Lite interface
      ----------------------------------------------------------------------------------------------
      axiSlaveWaitTxn(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus);

      if (axilStatus.writeEnable = '1') then
         axilWriteResp := ite(axilWriteMaster.awaddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_RESP_DECERR_C);
         case (s_WrAddr) is
            when 16#00# =>              -- ADDR (0x00)
               v.enableRx := axilWriteMaster.wdata(L_G-1 downto 0);
            when 16#01# =>              -- ADDR (0x04)
               v.sysrefDlyRx := axilWriteMaster.wdata(SYSRF_DLY_WIDTH_C-1 downto 0);
            when 16#02# =>              -- ADDR (0x08)
               v.rxPolarity := axilWriteMaster.wdata(L_G-1 downto 0);
            when 16#04# =>              -- ADDR (0x10)
               v.commonCtrl := axilWriteMaster.wdata(5 downto 0);
            when 16#05# =>              -- ADDR (0x14)
               v.linkErrMask := axilWriteMaster.wdata(5 downto 0);
            when 16#06# =>              -- ADDR (0x18)
               v.invertData := axilWriteMaster.wdata(L_G-1 downto 0);
            when 16#09# =>              -- ADDR (0x24)
               v.axilReadSlave.rdata(L_G-1 downto 0) := r.rxPowerDown;
            when 16#20# to 16#2F# =>
               for i in (L_G-1) downto 0 loop
                  if (axilWriteMaster.awaddr(5 downto 2) = i) then
                     v.testTXItf(i) := axilWriteMaster.wdata(15 downto 0);
                  end if;
               end loop;
            when 16#30# to 16#3F# =>
               for i in (L_G-1) downto 0 loop
                  if (axilWriteMaster.awaddr(5 downto 2) = i) then
                     v.testSigThr(i) := axilWriteMaster.wdata(31 downto 0);
                  end if;
               end loop;
            when others =>
               axilWriteResp := AXI_RESP_DECERR_C;
         end case;
         axiSlaveWriteResponse(v.axilWriteSlave, axilWriteResp);
      end if;

      if (axilStatus.readEnable = '1') then
         axilReadResp          := ite(axilReadMaster.araddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_RESP_DECERR_C);
         v.axilReadSlave.rdata := (others => '0');
         case (s_RdAddr) is
            when 16#00# =>              -- ADDR (0x0)
               v.axilReadSlave.rdata(L_G-1 downto 0) := r.enableRx;
            when 16#01# =>              -- ADDR (0x04)
               v.axilReadSlave.rdata(SYSRF_DLY_WIDTH_C-1 downto 0) := r.sysrefDlyRx;
            when 16#02# =>              -- ADDR (0x08)
               v.axilReadSlave.rdata(L_G-1 downto 0) := r.rxPolarity;
            when 16#04# =>              -- ADDR (0x10)
               v.axilReadSlave.rdata(5 downto 0) := r.commonCtrl;
            when 16#05# =>              -- ADDR (0x14)
               v.axilReadSlave.rdata(5 downto 0) := r.linkErrMask;
            when 16#06# =>              -- ADDR (0x18)
               v.axilReadSlave.rdata(L_G-1 downto 0) := r.invertData;
            when 16#09# =>              -- ADDR (0x24)
               v.rxPowerDown := axilWriteMaster.wdata(L_G-1 downto 0);
            when 16#0A# =>              -- ADDR (0x28)
               v.axilReadSlave.rdata(15 downto 0)  := sysRefPeriodmin;
               v.axilReadSlave.rdata(31 downto 16) := sysRefPeriodmax;
            when 16#10# to 16#1F# =>
               for i in (L_G-1) downto 0 loop
                  if (axilReadMaster.araddr(5 downto 2) = i) then
                     v.axilReadSlave.rdata(RX_STAT_WIDTH_C-1 downto 0) := s_statusRxArr(i);
                  end if;
               end loop;
            when 16#20# to 16#2F# =>
               for i in (L_G-1) downto 0 loop
                  if (axilReadMaster.araddr(5 downto 2) = i) then
                     v.axilReadSlave.rdata(15 downto 0) := r.testTXItf(i);
                  end if;
               end loop;
            when 16#30# to 16#3F# =>
               for i in (L_G-1) downto 0 loop
                  if (axilReadMaster.araddr(5 downto 2) = i) then
                     v.axilReadSlave.rdata(31 downto 0) := r.testSigThr(i);
                  end if;
               end loop;
            when 16#40# to 16#4F# =>
               for i in (L_G-1) downto 0 loop
                  if (axilReadMaster.araddr(5 downto 2) = i) then
                     for j in 31 downto 0 loop
                        v.axilReadSlave.rdata(J) := s_statusCnt(i, j);
                     end loop;
                  end if;
               end loop;
            when 16#50# to 16#5F# =>
               for i in (L_G-1) downto 0 loop
                  if (axilReadMaster.araddr(5 downto 2) = i) then
                     v.axilReadSlave.rdata := s_rawData(i);
                  end if;
               end loop;
            when others =>
               axilReadResp := AXI_RESP_DECERR_C;
         end case;
         axiSlaveReadResponse(v.axilReadSlave, axilReadResp);
      end if;

      -- Reset
      if (axiRst_i = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      axilReadSlave  <= r.axilReadSlave;
      axilWriteSlave <= r.axilWriteSlave;
      rxPowerDown    <= r.rxPowerDown;
      rxPolarity     <= r.rxPolarity;

   end process comb;

   seq : process (axiClk_i) is
   begin
      if rising_edge(axiClk_i) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   -- Input assignment and synchronization
   GEN_0 : for i in L_G-1 downto 0 generate
      U_statusRxArr : entity surf.SynchronizerVector
         generic map (
            TPD_G   => TPD_G,
            WIDTH_G => RX_STAT_WIDTH_C)
         port map (
            clk     => axiClk_i,
            dataIn  => statusRxArr_i(i),
            dataOut => s_statusRxArr(i));

      U_rawData : entity surf.SynchronizerFifo
         generic map (
            TPD_G        => TPD_G,
            DATA_WIDTH_G => 32)
         port map (
            wr_clk => devClk_i,
            din    => rawData_i(i),
            rd_clk => axiClk_i,
            dout   => s_rawData(i));
   end generate GEN_0;

   -- Output assignment and synchronization
   U_sysrefDlyRx : entity surf.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => SYSRF_DLY_WIDTH_C)
      port map (
         clk     => devClk_i,
         dataIn  => r.sysrefDlyRx,
         dataOut => sysrefDlyRx);

   U_sysrefDlyRx_Pipeline : entity surf.RstPipelineVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => SYSRF_DLY_WIDTH_C)
      port map (
         clk    => devClk_i,
         rstIn  => sysrefDlyRx,
         rstOut => sysrefDlyRx_o);

   ------------------------------------------------------------

   U_enableRx : entity surf.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => L_G)
      port map (
         clk     => devClk_i,
         dataIn  => r.enableRx,
         dataOut => enableRx);

   U_enableRx_Pipeline : entity surf.RstPipelineVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => L_G)
      port map (
         clk    => devClk_i,
         rstIn  => enableRx,
         rstOut => enableRx_o);

   ------------------------------------------------------------

   U_subClass : entity surf.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => devClk_i,
         dataIn  => r.commonCtrl(0),
         dataOut => subClass);

   U_subClass_Pipeline : entity surf.RstPipeline
      generic map (
         TPD_G => TPD_G)
      port map (
         clk    => devClk_i,
         rstIn  => subClass,
         rstOut => subClass_o);

   ------------------------------------------------------------

   U_replEnable : entity surf.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => devClk_i,
         dataIn  => r.commonCtrl(1),
         dataOut => replEnable);

   U_replEnable_Pipeline : entity surf.RstPipeline
      generic map (
         TPD_G => TPD_G)
      port map (
         clk    => devClk_i,
         rstIn  => replEnable,
         rstOut => replEnable_o);

   ------------------------------------------------------------

   U_gtReset : entity surf.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => devClk_i,
         dataIn  => r.commonCtrl(2),
         dataOut => gtReset);

   U_gtReset_Pipeline : entity surf.RstPipeline
      generic map (
         TPD_G => TPD_G)
      port map (
         clk    => devClk_i,
         rstIn  => gtReset,
         rstOut => gtReset_o);

   ------------------------------------------------------------

   U_clearErr : entity surf.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => devClk_i,
         dataIn  => r.commonCtrl(3),
         dataOut => clearErr);

   U_clearErr_Pipeline : entity surf.RstPipeline
      generic map (
         TPD_G => TPD_G)
      port map (
         clk    => devClk_i,
         rstIn  => clearErr,
         rstOut => clearErr_o);

   ------------------------------------------------------------

   U_invertSync : entity surf.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => devClk_i,
         dataIn  => r.commonCtrl(4),
         dataOut => invertSync);

   U_invertSync_Pipeline : entity surf.RstPipeline
      generic map (
         TPD_G => TPD_G)
      port map (
         clk    => devClk_i,
         rstIn  => invertSync,
         rstOut => invertSync_o);

   ------------------------------------------------------------

   U_scrEnable : entity surf.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => devClk_i,
         dataIn  => r.commonCtrl(5),
         dataOut => scrEnable);

   U_scrEnable_Pipeline : entity surf.RstPipeline
      generic map (
         TPD_G => TPD_G)
      port map (
         clk    => devClk_i,
         rstIn  => scrEnable,
         rstOut => scrEnable_o);

   ------------------------------------------------------------

   U_linkErrMask : entity surf.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 6)
      port map (
         clk     => devClk_i,
         dataIn  => r.linkErrMask,
         dataOut => linkErrMask);

   U_linkErrMask_Pipeline : entity surf.RstPipelineVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 6)
      port map (
         clk    => devClk_i,
         rstIn  => linkErrMask,
         rstOut => linkErrMask_o);

   ------------------------------------------------------------

   U_invertData : entity surf.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => L_G)
      port map (
         clk     => devClk_i,
         dataIn  => r.invertData,
         dataOut => invertData);

   U_invertData_Pipeline : entity surf.RstPipelineVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => L_G)
      port map (
         clk    => devClk_i,
         rstIn  => invertData,
         rstOut => invertData_o);

   ------------------------------------------------------------

   GEN_1 : for i in L_G-1 downto 0 generate

      ------------------------------------------------------------

      U_dlyTxArr : entity surf.SynchronizerVector
         generic map (
            TPD_G   => TPD_G,
            WIDTH_G => 4)
         port map (
            clk     => devClk_i,
            dataIn  => r.testTXItf(i)(11 downto 8),
            dataOut => dlyTxArr(i));

      U_dlyTxArr_Pipeline : entity surf.RstPipelineVector
         generic map (
            TPD_G   => TPD_G,
            WIDTH_G => 4)
         port map (
            clk    => devClk_i,
            rstIn  => dlyTxArr(i),
            rstOut => dlyTxArr_o(i));

      ------------------------------------------------------------

      U_alignTxArr : entity surf.SynchronizerVector
         generic map (
            TPD_G   => TPD_G,
            WIDTH_G => GT_WORD_SIZE_C)
         port map (
            clk     => devClk_i,
            dataIn  => r.testTXItf(i) (GT_WORD_SIZE_C-1 downto 0),
            dataOut => alignTxArr(i));

      U_alignTxArr_Pipeline : entity surf.RstPipelineVector
         generic map (
            TPD_G   => TPD_G,
            WIDTH_G => GT_WORD_SIZE_C)
         port map (
            clk    => devClk_i,
            rstIn  => alignTxArr(i),
            rstOut => alignTxArr_o(i));

      ------------------------------------------------------------

      U_thresoldLowArr_A : entity surf.SynchronizerVector
         generic map (
            TPD_G   => TPD_G,
            WIDTH_G => 16)
         port map (
            clk     => devClk_i,
            dataIn  => r.testSigThr(i) (31 downto 16),
            dataOut => thresoldHighArr(i));

      U_thresoldLowArr_A_Pipeline : entity surf.RstPipelineVector
         generic map (
            TPD_G   => TPD_G,
            WIDTH_G => 16)
         port map (
            clk    => devClk_i,
            rstIn  => thresoldHighArr(i),
            rstOut => thresoldHighArr_o(i));

      ------------------------------------------------------------

      U_thresoldLowArr_B : entity surf.SynchronizerVector
         generic map (
            TPD_G   => TPD_G,
            WIDTH_G => 16)
         port map (
            clk     => devClk_i,
            dataIn  => r.testSigThr(i) (15 downto 0),
            dataOut => thresoldLowArr(i));

      U_thresoldLowArr_B_Pipeline : entity surf.RstPipelineVector
         generic map (
            TPD_G   => TPD_G,
            WIDTH_G => 16)
         port map (
            clk    => devClk_i,
            rstIn  => thresoldLowArr(i),
            rstOut => thresoldLowArr_o(i));

      ------------------------------------------------------------

   end generate GEN_1;

end rtl;
