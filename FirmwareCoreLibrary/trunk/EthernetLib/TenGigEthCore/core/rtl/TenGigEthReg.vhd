-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : TenGigEthReg.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-02-20
-- Last update: 2015-09-08
-- Platform   : Vivado 2014.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Ethernet Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Ethernet Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.TenGigEthPkg.all;

entity TenGigEthReg is
   generic (
      TPD_G            : time            := 1 ns;
      AXI_ERROR_RESP_G : slv(1 downto 0) := AXI_RESP_SLVERR_C);
   port (
      -- Local Configurations
      localMac       : in  slv(47 downto 0) := MAC_ADDR_INIT_C;
      -- Clocks and resets
      clk            : in  sl;
      rst            : in  sl;
      -- AXI-Lite Register Interface
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;
      -- Configuration and Status Interface
      config         : out TenGigEthConfig;
      status         : in  TenGigEthStatus);   
end TenGigEthReg;

architecture rtl of TenGigEthReg is

   constant STATUS_SIZE_C : positive := 19;

   type RegType is record
      hardRst       : sl;
      cntRst        : sl;
      rollOverEn    : slv(STATUS_SIZE_C-1 downto 0);
      config        : TenGigEthConfig;
      axiReadSlave  : AxiLiteReadSlaveType;
      axiWriteSlave : AxiLiteWriteSlaveType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      hardRst       => '0',
      cntRst        => '1',
      rollOverEn    => (others => '0'),
      config        => TEN_GIG_ETH_CONFIG_INIT_C,
      axiReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axiWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal statusOut : slv(STATUS_SIZE_C-1 downto 0);
   signal cntOut    : SlVectorArray(STATUS_SIZE_C-1 downto 0, 31 downto 0);
   
begin

   SyncStatusVec_Inst : entity work.SyncStatusVector
      generic map (
         TPD_G          => TPD_G,
         OUT_POLARITY_G => '1',
         CNT_RST_EDGE_G => false,
         COMMON_CLK_G   => true,
         CNT_WIDTH_G    => 32,
         WIDTH_G        => STATUS_SIZE_C)     
      port map (
         -- Input Status bit Signals (wrClk domain)
         statusIn(0)  => status.phyReady,
         statusIn(1)  => status.macStatus.rxPauseCnt,
         statusIn(2)  => status.macStatus.txPauseCnt,
         statusIn(3)  => status.macStatus.rxCountEn,
         statusIn(4)  => status.macStatus.rxOverFlow,
         statusIn(5)  => status.macStatus.rxCrcErrorCnt,
         statusIn(6)  => status.macStatus.txCountEn,
         statusIn(7)  => status.macStatus.txUnderRunCnt,
         statusIn(8)  => status.macStatus.txNotReadyCnt,
         statusIn(9)  => status.txDisable,
         statusIn(10) => status.sigDet,
         statusIn(11) => status.txFault,
         statusIn(12) => status.gtTxRst,
         statusIn(13) => status.gtRxRst,
         statusIn(14) => status.rstCntDone,
         statusIn(15) => status.qplllock,
         statusIn(16) => status.txRstdone,
         statusIn(17) => status.rxRstdone,
         statusIn(18) => status.txUsrRdy,
         -- Output Status bit Signals (rdClk domain)           
         statusOut    => statusOut,
         -- Status Bit Counters Signals (rdClk domain) 
         cntRstIn     => r.cntRst,
         rollOverEnIn => r.rollOverEn,
         cntOut       => cntOut,
         -- Clocks and Reset Ports
         wrClk        => clk,
         rdClk        => clk);

   -------------------------------
   -- Configuration Register
   -------------------------------  
   comb : process (axiReadMaster, axiWriteMaster, cntOut, localMac, r, rst, status, statusOut) is
      variable v         : RegType;
      variable axiStatus : AxiLiteStatusType;
      variable rdPntr    : natural;

      -- Wrapper procedures to make calls cleaner.
      procedure axiSlaveRegisterW (addr : in slv; offset : in integer; reg : inout slv) is
      begin
         axiSlaveRegister(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus, addr, offset, reg);
      end procedure;

      procedure axiSlaveRegisterR (addr : in slv; offset : in integer; reg : in slv) is
      begin
         axiSlaveRegister(axiReadMaster, v.axiReadSlave, axiStatus, addr, offset, reg);
      end procedure;

      procedure axiSlaveRegisterW (addr : in slv; offset : in integer; reg : inout sl) is
      begin
         axiSlaveRegister(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus, addr, offset, reg);
      end procedure;

      procedure axiSlaveRegisterR (addr : in slv; offset : in integer; reg : in sl) is
      begin
         axiSlaveRegister(axiReadMaster, v.axiReadSlave, axiStatus, addr, offset, reg);
      end procedure;

      procedure axiSlaveDefault (
         axiResp : in slv(1 downto 0)) is
      begin
         axiSlaveDefault(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus, axiResp);
      end procedure;
      
   begin
      -- Latch the current value
      v := r;

      -- Determine the transaction type
      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);

      -- Reset strobe signals
      v.cntRst         := '0';
      v.config.softRst := '0';
      v.hardRst        := '0';

      -- Calculate the read pointer
      rdPntr := conv_integer(axiReadMaster.araddr(9 downto 2));

      -- Register Mapping
      axiSlaveRegisterR("0000--------", 0, muxSlVectorArray(cntOut, rdPntr));
      axiSlaveRegisterR(x"100", 0, statusOut);
      --axiSlaveRegisterR(x"104", 0, status.macStatus.rxPauseValue);
      axiSlaveRegisterR(x"108", 0, status.core_status);

      axiSlaveRegisterW(x"200", 0, v.config.macConfig.macAddress(31 downto 0));
      axiSlaveRegisterW(x"204", 0, v.config.macConfig.macAddress(47 downto 32));
      --axiSlaveRegisterW(x"208", 0, v.config.macConfig.byteSwap);

      --axiSlaveRegisterW(x"210", 0, v.config.macConfig.txShift);
      --axiSlaveRegisterW(x"214", 0, v.config.macConfig.txShiftEn);
      axiSlaveRegisterW(x"218", 0, v.config.macConfig.interFrameGap);
      axiSlaveRegisterW(x"21C", 0, v.config.macConfig.pauseTime);

      --axiSlaveRegisterW(x"220", 0, v.config.macConfig.rxShift);
      --axiSlaveRegisterW(x"224", 0, v.config.macConfig.rxShiftEn);
      axiSlaveRegisterW(x"228", 0, v.config.macConfig.filtEnable);
      axiSlaveRegisterW(x"22C", 0, v.config.macConfig.pauseEnable);

      axiSlaveRegisterW(x"230", 0, v.config.pma_pmd_type);
      axiSlaveRegisterW(x"234", 0, v.config.pma_loopback);
      axiSlaveRegisterW(x"238", 0, v.config.pma_reset);
      axiSlaveRegisterW(x"23C", 0, v.config.pcs_loopback);
      axiSlaveRegisterW(x"240", 0, v.config.pcs_reset);

      axiSlaveRegisterW(x"F00", 0, v.rollOverEn);
      axiSlaveRegisterW(x"FF4", 0, v.cntRst);
      axiSlaveRegisterW(x"FF8", 0, v.config.softRst);
      axiSlaveRegisterW(x"FFC", 0, v.hardRst);

      axiSlaveDefault(AXI_ERROR_RESP_G);

      -- Synchronous Reset
      if (rst = '1') or (v.hardRst = '1') then
         v.cntRst     := '1';
         v.rollOverEn := (others => '0');
         v.config     := TEN_GIG_ETH_CONFIG_INIT_C;
         if (rst = '1') then
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
      config        <= r.config;

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
