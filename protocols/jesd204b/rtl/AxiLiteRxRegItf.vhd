-------------------------------------------------------------------------------
-- File       : AxiLiteRxRegItf.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-15
-- Last update: 2016-09-23
-------------------------------------------------------------------------------
-- Description:  AXI-Lite interface for register access 
--
--             Register decoding for JESD RX core
--               0x00 (RW)- Enable RX lanes (L_G downto 1)
--               0x01 (RW)- SYSREF delay (5 bit)
--               0x02 (RW)- Enable AXI Stream transfer (L_G downto 1)
--               0x03 (RW)- AXI stream packet size (24 bit)
--               0x04 (RW)- Common control register:
--                   bit 0: JESD Subclass (Default '1')
--                   bit 1: Enable control character replacement(Default '1')
--                   bit 2: Reset MGTs (Default '1')
--                   bit 3: Clear Registered errors (Default '0')
--                   bit 4: Invert nSync (Default '1'-inverted) 
--                   bit 5: Scrambling support enable (Default '0'- Disabled) 
--               0x05 (RW)- LinkErrorMask
--                   bit 5-0: positionErr & s_bufOvf & s_bufUnf & dispErr & decErr & s_alignErr                     
--               0x06 (RW)- Mask Enable the ADC data inversion. 1-Inverted, 0-normal.
--               0x1X (R) - Lane X status
--                   bit 0: GT Reset done
--                   bit 1: Received data valid
--                   bit 2: Received data is misaligned
--                   bit 3: Synchronisation output status 
--                   bit 4: Rx buffer overflow
--                   bit 5: Rx buffer underflow
--                   bit 6: Comma position not as expected during alignment
--                   bit 7: TX lane enabled status
--                   bit 8: SysRef detected (active only when the RX lane is enabled)
--                   bit 9: Comma (K28.5) detected
--                   bit 10-13: Disparity error
--                   bit 14-17: Not in table Error
--                   bit 18-25: Elastic buffer latency (c-c)
--                   bit 26: CDR Stable
--               0x2X (RW) - Lane X test module control
--                   bit 11-8: Lane delay (Number of JESD clock cycles)
--                   bit 3-0:  Lane alignment within one clock cycle (Valid values= "0001", "0010","0100","1000")
--               0x3X (RW) - Lane X test signal thresholds 
--                   bit 31-16: High threshold
--                   bit 15-0:  Low threshold
--               0x4X (RO) - Status valid counters 
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

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.Jesd204bPkg.all;

entity AxiLiteRxRegItf is
   generic (
      -- General Configurations
      TPD_G            : time            := 1 ns;
      AXI_ERROR_RESP_G : slv(1 downto 0) := AXI_RESP_SLVERR_C;
      AXI_ADDR_WIDTH_G : positive        := 10;
      -- JESD 
      -- Number of RX lanes (1 to 8)
      L_G              : positive        := 2
      );
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
      statusRxArr_i : in rxStatuRegisterArray(L_G-1 downto 0);
      rawData_i     : in slv32Array(L_G-1 downto 0);
      
      -- Control
      sysrefDlyRx_o     : out slv(SYSRF_DLY_WIDTH_C-1 downto 0);
      enableRx_o        : out slv(L_G-1 downto 0);
      replEnable_o      : out sl;
      scrEnable_o       : out sl;
      invertData_o      : out slv(L_G-1 downto 0);   
      dlyTxArr_o        : out Slv4Array(L_G-1 downto 0);     -- 1 to 16 clock cycles
      alignTxArr_o      : out alignTxArray(L_G-1 downto 0);  -- 0001, 0010, 0100, 1000
      thresoldLowArr_o  : out Slv16Array(L_G-1 downto 0);    -- Test signal threshold low
      thresoldHighArr_o : out Slv16Array(L_G-1 downto 0);    -- Test signal threshold high  
      axisTrigger_o     : out slv(L_G-1 downto 0);
      subClass_o        : out sl;
      gtReset_o         : out sl;
      clearErr_o        : out sl;
      invertSync_o      : out sl;
      linkErrMask_o     : out slv(5 downto 0);
      axisPacketSize_o  : out slv(23 downto 0)
      );
end AxiLiteRxRegItf;

architecture rtl of AxiLiteRxRegItf is

   type RegType is record
      -- JESD Control (RW)
      enableRx       : slv(L_G-1 downto 0);
      invertData     : slv(L_G-1 downto 0);    
      commonCtrl     : slv(5 downto 0);
      linkErrMask    : slv(5 downto 0);
      sysrefDlyRx    : slv(SYSRF_DLY_WIDTH_C-1 downto 0);
      testTXItf      : Slv16Array(L_G-1 downto 0);
      testSigThr     : Slv32Array(L_G-1 downto 0);
      axisTrigger    : slv(L_G-1 downto 0);
      axisPacketSize : slv(23 downto 0);

      -- AXI lite
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
   end record;

   constant REG_INIT_C : RegType := (
      enableRx       => (others => '0'),
      invertData     => (others => '0'),  
      commonCtrl     => "010111",
      linkErrMask    => "111111",
      sysrefDlyRx    => (others => '0'),
      testTXItf      => (others => x"0000"),
      testSigThr     => (others => x"A000_5000"),
      axisTrigger    => (others => '0'),
      axisPacketSize => AXI_PACKET_SIZE_DEFAULT_C,

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
   

begin

   ----------------------------------------------------------------------------------------------
   -- Data Valid Status Counter
   ----------------------------------------------------------------------------------------------
   GEN_LANES : for I in L_G-1 downto 0 generate
      s_adcValids(I) <= statusRxArr_i(I)(1);
   end generate GEN_LANES;


   U_SyncStatusVector : entity work.SyncStatusVector
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
                   s_WrAddr, s_statusRxArr, s_statusCnt, s_rawData) is
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
         axilWriteResp := ite(axilWriteMaster.awaddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_ERROR_RESP_G);
         case (s_WrAddr) is
            when 16#00# =>              -- ADDR (0x00)
               v.enableRx := axilWriteMaster.wdata(L_G-1 downto 0);
            when 16#01# =>              -- ADDR (0x04)
               v.sysrefDlyRx := axilWriteMaster.wdata(SYSRF_DLY_WIDTH_C-1 downto 0);
            when 16#02# =>              -- ADDR (0x08)
               v.axisTrigger := axilWriteMaster.wdata(L_G-1 downto 0);
            when 16#03# =>              -- ADDR (0x0C)
               v.axisPacketSize := axilWriteMaster.wdata(23 downto 0);
            when 16#04# =>              -- ADDR (0x10)
               v.commonCtrl := axilWriteMaster.wdata(5 downto 0);
            when 16#05# =>              -- ADDR (0x14)
               v.linkErrMask := axilWriteMaster.wdata(5 downto 0);
            when 16#06# =>              -- ADDR (0x18)
               v.invertData  := axilWriteMaster.wdata(L_G-1 downto 0);
            when 16#20# to 16#2F# =>
               for I in (L_G-1) downto 0 loop
                  if (axilWriteMaster.awaddr(5 downto 2) = I) then
                     v.testTXItf(I) := axilWriteMaster.wdata(15 downto 0);
                  end if;
               end loop;
            when 16#30# to 16#3F# =>
               for I in (L_G-1) downto 0 loop
                  if (axilWriteMaster.awaddr(5 downto 2) = I) then
                     v.testSigThr(I) := axilWriteMaster.wdata(31 downto 0);
                  end if;
               end loop;
            when others =>
               axilWriteResp := AXI_ERROR_RESP_G;
         end case;
         axiSlaveWriteResponse(v.axilWriteSlave);
      end if;

      if (axilStatus.readEnable = '1') then
         axilReadResp          := ite(axilReadMaster.araddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_ERROR_RESP_G);
         v.axilReadSlave.rdata := (others => '0');
         case (s_RdAddr) is
            when 16#00# =>              -- ADDR (0x0)
               v.axilReadSlave.rdata(L_G-1 downto 0) := r.enableRx;
            when 16#01# =>              -- ADDR (0x04)
               v.axilReadSlave.rdata(SYSRF_DLY_WIDTH_C-1 downto 0) := r.sysrefDlyRx;
            when 16#02# =>              -- ADDR (0x08)
               v.axilReadSlave.rdata(L_G-1 downto 0) := r.axisTrigger;
            when 16#03# =>              -- ADDR (0x0C)
               v.axilReadSlave.rdata(23 downto 0) := r.axisPacketSize;
            when 16#04# =>              -- ADDR (0x10)
               v.axilReadSlave.rdata(5 downto 0) := r.commonCtrl;
            when 16#05# =>              -- ADDR (0x14)
               v.axilReadSlave.rdata(5 downto 0) := r.linkErrMask;
            when 16#06# =>              -- ADDR (0x18)
               v.axilReadSlave.rdata(L_G-1 downto 0) := r.invertData;
            when 16#10# to 16#1F# =>
               for I in (L_G-1) downto 0 loop
                  if (axilReadMaster.araddr(5 downto 2) = I) then
                     v.axilReadSlave.rdata(RX_STAT_WIDTH_C-1 downto 0) := s_statusRxArr(I);
                  end if;
               end loop;
            when 16#20# to 16#2F# =>
               for I in (L_G-1) downto 0 loop
                  if (axilReadMaster.araddr(5 downto 2) = I) then
                     v.axilReadSlave.rdata(15 downto 0) := r.testTXItf(I);
                  end if;
               end loop;
            when 16#30# to 16#3F# =>
               for I in (L_G-1) downto 0 loop
                  if (axilReadMaster.araddr(5 downto 2) = I) then
                     v.axilReadSlave.rdata(31 downto 0) := r.testSigThr(I);
                  end if;
               end loop;
            when 16#40# to 16#4F# =>
               for I in (L_G-1) downto 0 loop
                  if (axilReadMaster.araddr(5 downto 2) = I) then
                     for J in 31 downto 0 loop
                        v.axilReadSlave.rdata(J) := s_statusCnt(I, J);
                     end loop;
                  end if;
               end loop;
            when 16#50# to 16#5F# =>
               for I in (L_G-1) downto 0 loop
                  if (axilReadMaster.araddr(5 downto 2) = I) then
                     v.axilReadSlave.rdata := s_rawData(I);
                  end if;
               end loop;
            when others =>
               axilReadResp := AXI_ERROR_RESP_G;
         end case;
         axiSlaveReadResponse(v.axilReadSlave);
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

   end process comb;

   seq : process (axiClk_i) is
   begin
      if rising_edge(axiClk_i) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   -- Input assignment and synchronisation
   GEN_0 : for I in L_G-1 downto 0 generate
      SyncFifo_IN0 : entity work.SynchronizerFifo
         generic map (
            TPD_G        => TPD_G,
            DATA_WIDTH_G => RX_STAT_WIDTH_C
            )
         port map (
            wr_clk => devClk_i,
            din    => statusRxArr_i(I),
            rd_clk => axiClk_i,
            dout   => s_statusRxArr(I)
            );
            
            
      SyncFifo_IN1 : entity work.SynchronizerFifo
         generic map (
            TPD_G        => TPD_G,
            DATA_WIDTH_G => 32
            )
         port map (
            wr_clk => devClk_i,
            din    => rawData_i(I),
            rd_clk => axiClk_i,
            dout   => s_rawData(I)
            );
   end generate GEN_0;
   
   
   

   -- Output assignment and synchronisation

   SyncFifo_OUT0 : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => SYSRF_DLY_WIDTH_C
         )
      port map (
         wr_clk => axiClk_i,
         din    => r.sysrefDlyRx,
         rd_clk => devClk_i,
         dout   => sysrefDlyRx_o
         );

   SyncFifo_OUT1 : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => L_G
         )
      port map (
         wr_clk => axiClk_i,
         din    => r.enableRx,
         rd_clk => devClk_i,
         dout   => enableRx_o
         );


   SyncFifo_OUT2 : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 24
         )
      port map (
         wr_clk => axiClk_i,
         din    => r.axisPacketSize,
         rd_clk => devClk_i,
         dout   => axisPacketSize_o
         );

   Sync_OUT3 : entity work.Synchronizer
      generic map (
         TPD_G => TPD_G
         )
      port map (
         clk     => devClk_i,
         rst     => devRst_i,
         dataIn  => r.commonCtrl(0),
         dataOut => subClass_o
         );

   Sync_OUT4 : entity work.Synchronizer
      generic map (
         TPD_G => TPD_G
         )
      port map (
         clk     => devClk_i,
         rst     => devRst_i,
         dataIn  => r.commonCtrl(1),
         dataOut => replEnable_o
         );

   Sync_OUT5 : entity work.Synchronizer
      generic map (
         TPD_G => TPD_G
         )
      port map (
         clk     => devClk_i,
         rst     => devRst_i,
         dataIn  => r.commonCtrl(2),
         dataOut => gtReset_o
         );

   Sync_OUT6 : entity work.Synchronizer
      generic map (
         TPD_G => TPD_G
         )
      port map (
         clk     => devClk_i,
         rst     => devRst_i,
         dataIn  => r.commonCtrl(3),
         dataOut => clearErr_o
         );

   Sync_OUT7 : entity work.Synchronizer
      generic map (
         TPD_G => TPD_G
         )
      port map (
         clk     => devClk_i,
         rst     => devRst_i,
         dataIn  => r.commonCtrl(4),
         dataOut => invertSync_o
         );

   Sync_OUT8 : entity work.Synchronizer
      generic map (
         TPD_G => TPD_G
         )
      port map (
         clk     => devClk_i,
         rst     => devRst_i,
         dataIn  => r.commonCtrl(5),
         dataOut => scrEnable_o
         );
   
   Sync_OUT9 : entity work.SynchronizerVector
      generic map (
         TPD_G => TPD_G,
         WIDTH_G => 6
         )
      port map (
         clk     => devClk_i,
         rst     => devRst_i,
         dataIn  => r.linkErrMask,
         dataOut => linkErrMask_o
         );

   SyncFifo_OUT8 : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => L_G
         )
      port map (
         wr_clk => axiClk_i,
         din    => r.axisTrigger,
         rd_clk => devClk_i,
         dout   => axisTrigger_o
         );

   SyncFifo_OUT9 : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => L_G
         )
      port map (
         wr_clk => axiClk_i,
         din    => r.invertData,
         rd_clk => devClk_i,
         dout   => invertData_o
         );      

   GEN_1 : for I in L_G-1 downto 0 generate
      SyncFifo_OUT0 : entity work.SynchronizerFifo
         generic map (
            TPD_G        => TPD_G,
            DATA_WIDTH_G => 4
            )
         port map (
            wr_clk => axiClk_i,
            din    => r.testTXItf(I) (11 downto 8),
            rd_clk => devClk_i,
            dout   => dlyTxArr_o(I)
            );

      SyncFifo_OUT1 : entity work.SynchronizerFifo
         generic map (
            TPD_G        => TPD_G,
            DATA_WIDTH_G => GT_WORD_SIZE_C
            )
         port map (
            wr_clk => axiClk_i,
            din    => r.testTXItf(I) (GT_WORD_SIZE_C-1 downto 0),
            rd_clk => devClk_i,
            dout   => alignTxArr_o(I)
            );

      SyncFifo_OUT2 : entity work.SynchronizerFifo
         generic map (
            TPD_G        => TPD_G,
            DATA_WIDTH_G => 16
            )
         port map (
            wr_clk => axiClk_i,
            din    => r.testSigThr(I) (31 downto 16),
            rd_clk => devClk_i,
            dout   => thresoldHighArr_o(I)
            );

      SyncFifo_OUT3 : entity work.SynchronizerFifo
         generic map (
            TPD_G        => TPD_G,
            DATA_WIDTH_G => 16
            )
         port map (
            wr_clk => axiClk_i,
            din    => r.testSigThr(I) (15 downto 0),
            rd_clk => devClk_i,
            dout   => thresoldLowArr_o(I)
            );
   end generate GEN_1;
---------------------------------------------------------------------
end rtl;
