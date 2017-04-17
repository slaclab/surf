-------------------------------------------------------------------------------
-- File       : XauiReg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-07
-- Last update: 2016-10-06
-------------------------------------------------------------------------------
-- Description: AXI-Lite XAUI Register Interface
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
use work.XauiPkg.all;

entity XauiReg is
   generic (
      TPD_G            : time            := 1 ns;
      EN_AXI_REG_G     : boolean         := false;
      AXI_ERROR_RESP_G : slv(1 downto 0) := AXI_RESP_SLVERR_C);
   port (
      -- Local Configurations
      localMac       : in  slv(47 downto 0) := MAC_ADDR_INIT_C;
      -- AXI-Lite Register Interface
      axiClk         : in  sl;
      axiRst         : in  sl;
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;
      -- Configuration and Status Interface
      phyClk         : in  sl;
      phyRst         : in  sl;
      config         : out XauiConfig;
      status         : in  XauiStatus);   
end XauiReg;

architecture rtl of XauiReg is

   constant STATUS_SIZE_C : positive := 32;

   type RegType is record
      hardRst       : sl;
      cntRst        : sl;
      rollOverEn    : slv(STATUS_SIZE_C-1 downto 0);
      config        : XauiConfig;
      axiReadSlave  : AxiLiteReadSlaveType;
      axiWriteSlave : AxiLiteWriteSlaveType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      hardRst       => '0',
      cntRst        => '1',
      rollOverEn    => (others => '0'),
      config        => XAUI_CONFIG_INIT_C,
      axiReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axiWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal statusOut    : slv(STATUS_SIZE_C-1 downto 0);
   signal cntOut       : SlVectorArray(STATUS_SIZE_C-1 downto 0, 31 downto 0);
   signal localMacSync : slv(47 downto 0);
   
begin

   GEN_BYPASS : if (EN_AXI_REG_G = false) generate

      U_AxiLiteEmpty : entity work.AxiLiteEmpty
         generic map (
            TPD_G            => TPD_G,
            AXI_ERROR_RESP_G => AXI_ERROR_RESP_G)
         port map (
            axiClk         => axiClk,
            axiClkRst      => axiRst,
            axiReadMaster  => axiReadMaster,
            axiReadSlave   => axiReadSlave,
            axiWriteMaster => axiWriteMaster,
            axiWriteSlave  => axiWriteSlave);

      Sync_Config : entity work.SynchronizerVector
         generic map (
            TPD_G   => TPD_G,
            WIDTH_G => 48)
         port map (
            clk     => phyClk,
            dataIn  => localMac,
            dataOut => localMacSync);             

      process (localMacSync) is
         variable retVar : XauiConfig;
      begin
         retVar                      := XAUI_CONFIG_INIT_C;
         retVar.macConfig.macAddress := localMacSync;
         config                      <= retVar;
      end process;

   end generate;

   GEN_REG : if (EN_AXI_REG_G = true) generate
      
      SyncStatusVec_Inst : entity work.SyncStatusVector
         generic map (
            TPD_G          => TPD_G,
            OUT_POLARITY_G => '1',
            CNT_RST_EDGE_G => true,
            COMMON_CLK_G   => false,
            CNT_WIDTH_G    => 32,
            WIDTH_G        => STATUS_SIZE_C)     
         port map (
            -- Input Status bit Signals (wrClk domain)
            statusIn(0)            => status.phyReady,
            statusIn(1)            => status.macStatus.rxPauseCnt,
            statusIn(2)            => status.macStatus.txPauseCnt,
            statusIn(3)            => status.macStatus.rxCountEn,
            statusIn(4)            => status.macStatus.rxOverFlow,
            statusIn(5)            => status.macStatus.rxCrcErrorCnt,
            statusIn(6)            => status.macStatus.txCountEn,
            statusIn(7)            => status.macStatus.txUnderRunCnt,
            statusIn(8)            => status.macStatus.txNotReadyCnt,
            statusIn(9)            => status.areset,
            statusIn(10)           => status.clkLock,
            statusIn(18 downto 11) => status.statusVector,
            statusIn(24 downto 19) => status.debugVector,
            statusIn(31 downto 25) => (others => '0'),
            -- Output Status bit Signals (rdClk domain)           
            statusOut              => statusOut,
            -- Status Bit Counters Signals (rdClk domain) 
            cntRstIn               => r.cntRst,
            rollOverEnIn           => r.rollOverEn,
            cntOut                 => cntOut,
            -- Clocks and Reset Ports
            wrClk                  => phyClk,
            rdClk                  => axiClk);

      -------------------------------
      -- Configuration Register
      -------------------------------  
      comb : process (axiReadMaster, axiRst, axiWriteMaster, cntOut, localMac, r, statusOut) is
         variable v      : RegType;
         variable regCon : AxiLiteEndPointType;
         variable rdPntr : natural;
      begin
         -- Latch the current value
         v := r;

         -- Determine the transaction type
         axiSlaveWaitTxn(regCon, axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave);

         -- Reset strobe signals
         v.cntRst         := '0';
         v.config.softRst := '0';
         v.hardRst        := '0';

         -- Calculate the read pointer
         rdPntr := conv_integer(axiReadMaster.araddr(9 downto 2));

         -- Register Mapping
         axiSlaveRegisterR(regCon, "0000--------", 0, muxSlVectorArray(cntOut, rdPntr));
         axiSlaveRegisterR(regCon, x"100", 0, statusOut);
         --axiSlaveRegisterR(regCon, x"104", 0, status.macStatus.rxPauseValue);

         axiSlaveRegister(regCon, x"200", 0, v.config.macConfig.macAddress(31 downto 0));
         axiSlaveRegister(regCon, x"204", 0, v.config.macConfig.macAddress(47 downto 32));
         --axiSlaveRegister(regCon, x"208", 0, v.config.macConfig.byteSwap);

         --axiSlaveRegister(regCon, x"210", 0, v.config.macConfig.txShift);
         --axiSlaveRegister(regCon, x"214", 0, v.config.macConfig.txShiftEn);
         --axiSlaveRegister(regCon, x"218", 0, v.config.macConfig.interFrameGap);
         axiSlaveRegister(regCon, x"21C", 0, v.config.macConfig.pauseTime);

         --axiSlaveRegister(regCon, x"220", 0, v.config.macConfig.rxShift);
         --axiSlaveRegister(regCon, x"224", 0, v.config.macConfig.rxShiftEn);
         axiSlaveRegister(regCon, x"228", 0, v.config.macConfig.filtEnable);
         axiSlaveRegister(regCon, x"22C", 0, v.config.macConfig.pauseEnable);

         axiSlaveRegister(regCon, x"230", 0, v.config.configVector);

         axiSlaveRegister(regCon, x"F00", 0, v.rollOverEn);
         axiSlaveRegister(regCon, x"FF4", 0, v.cntRst);
         axiSlaveRegister(regCon, x"FF8", 0, v.config.softRst);
         axiSlaveRegister(regCon, x"FFC", 0, v.hardRst);

         -- Closeout the transaction
         axiSlaveDefault(regCon, v.axiWriteSlave, v.axiReadSlave, AXI_ERROR_RESP_G);

         -- Synchronous Reset
         if (axiRst = '1') or (v.hardRst = '1') then
            v.cntRst     := '1';
            v.rollOverEn := (others => '0');
            v.config     := XAUI_CONFIG_INIT_C;
            if (axiRst = '1') then
               v.axiReadSlave  := AXI_LITE_READ_SLAVE_INIT_C;
               v.axiWriteSlave := AXI_LITE_WRITE_SLAVE_INIT_C;
            end if;
         end if;

         -- Update the MAC address
         v.config.macConfig.macAddress := localMac;

         -- Register the variable for next clock cycle
         rin <= v;

         -- Outputs
         axiReadSlave  <= r.axiReadSlave;
         axiWriteSlave <= r.axiWriteSlave;

      end process comb;

      seq : process (axiClk) is
      begin
         if rising_edge(axiClk) then
            r <= rin after TPD_G;
         end if;
      end process seq;

      -- There is a Synchronizer one layer up for software reset
      config.softRst <= r.config.softRst;

      SyncIn_macAddress : entity work.SynchronizerFifo
         generic map (
            TPD_G        => TPD_G,
            DATA_WIDTH_G => 48)
         port map (
            wr_clk => axiClk,
            din    => r.config.macConfig.macAddress,
            rd_clk => phyClk,
            dout   => config.macConfig.macAddress); 

      SyncIn_pauseTime : entity work.SynchronizerFifo
         generic map (
            TPD_G        => TPD_G,
            DATA_WIDTH_G => 16)
         port map (
            wr_clk => axiClk,
            din    => r.config.macConfig.pauseTime,
            rd_clk => phyClk,
            dout   => config.macConfig.pauseTime);          

      SyncIn_macConfig : entity work.SynchronizerVector
         generic map (
            TPD_G    => TPD_G,
            STAGES_G => 2,
            WIDTH_G  => 5) 
         port map (
            clk        => phyClk,
            -- Input Data
            dataIn(0)  => r.config.macConfig.filtEnable,
            dataIn(1)  => r.config.macConfig.pauseEnable,
            dataIn(2)  => r.config.macConfig.ipCsumEn,
            dataIn(3)  => r.config.macConfig.tcpCsumEn,
            dataIn(4)  => r.config.macConfig.udpCsumEn,
            -- Output Data
            dataOut(0) => config.macConfig.filtEnable,
            dataOut(1) => config.macConfig.pauseEnable,
            dataOut(2) => config.macConfig.ipCsumEn,
            dataOut(3) => config.macConfig.tcpCsumEn,
            dataOut(4) => config.macConfig.udpCsumEn);  

      SyncIn_configVector : entity work.SynchronizerFifo
         generic map (
            TPD_G        => TPD_G,
            DATA_WIDTH_G => 7)
         port map (
            wr_clk => axiClk,
            din    => r.config.configVector,
            rd_clk => phyClk,
            dout   => config.configVector);    

   end generate;
   
end rtl;
