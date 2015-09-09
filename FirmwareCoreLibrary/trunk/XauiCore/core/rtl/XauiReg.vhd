-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : XauiReg.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-07
-- Last update: 2015-09-08
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
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

   constant STATUS_SIZE_C : positive := 25;

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

   signal statusOut : slv(STATUS_SIZE_C-1 downto 0);
   signal cntOut    : SlVectorArray(STATUS_SIZE_C-1 downto 0, 31 downto 0);
   
begin

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
         statusIn(1)            => status.phyStatus.rxPauseReq,
         statusIn(2)            => status.phyStatus.rxPauseSet,
         statusIn(3)            => status.phyStatus.rxCountEn,
         statusIn(4)            => status.phyStatus.rxOverFlow,
         statusIn(5)            => status.phyStatus.rxCrcError,
         statusIn(6)            => status.phyStatus.txCountEn,
         statusIn(7)            => status.phyStatus.txUnderRun,
         statusIn(8)            => status.phyStatus.txLinkNotReady,
         statusIn(9)            => status.areset,
         statusIn(10)           => status.clkLock,
         statusIn(18 downto 11) => status.statusVector,
         statusIn(24 downto 19) => status.debugVector,
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
   comb : process (axiReadMaster, axiRst, axiWriteMaster, cntOut, localMac, r, status, statusOut) is
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
      axiSlaveRegisterR(x"104", 0, status.phyStatus.rxPauseValue);

      axiSlaveRegisterW(x"200", 0, v.config.phyConfig.macAddress(31 downto 0));
      axiSlaveRegisterW(x"204", 0, v.config.phyConfig.macAddress(47 downto 32));
      axiSlaveRegisterW(x"208", 0, v.config.phyConfig.byteSwap);

      axiSlaveRegisterW(x"210", 0, v.config.phyConfig.txShift);
      axiSlaveRegisterW(x"214", 0, v.config.phyConfig.txShiftEn);
      axiSlaveRegisterW(x"218", 0, v.config.phyConfig.txInterFrameGap);
      axiSlaveRegisterW(x"21C", 0, v.config.phyConfig.txPauseTime);

      axiSlaveRegisterW(x"220", 0, v.config.phyConfig.rxShift);
      axiSlaveRegisterW(x"224", 0, v.config.phyConfig.rxShiftEn);

      axiSlaveRegisterW(x"230", 0, v.config.configVector);

      axiSlaveRegisterW(x"F00", 0, v.rollOverEn);
      axiSlaveRegisterW(x"FF4", 0, v.cntRst);
      axiSlaveRegisterW(x"FF8", 0, v.config.softRst);
      axiSlaveRegisterW(x"FFC", 0, v.hardRst);

      axiSlaveDefault(AXI_ERROR_RESP_G);

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
      v.config.phyConfig.macAddress := localMac;

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
         din    => r.config.phyConfig.macAddress,
         rd_clk => phyClk,
         dout   => config.phyConfig.macAddress); 

   SyncIn_phyConfig : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 31)
      port map (
         wr_clk             => axiClk,
         din(0)             => r.config.phyConfig.byteSwap,
         din(4 downto 1)    => r.config.phyConfig.txShift,
         din(5)             => r.config.phyConfig.txShiftEn,
         din(9 downto 6)    => r.config.phyConfig.txInterFrameGap,
         din(25 downto 10)  => r.config.phyConfig.txPauseTime,
         din(29 downto 26)  => r.config.phyConfig.rxShift,
         din(30)            => r.config.phyConfig.rxShiftEn,
         rd_clk             => phyClk,
         dout(0)            => config.phyConfig.byteSwap,
         dout(4 downto 1)   => config.phyConfig.txShift,
         dout(5)            => config.phyConfig.txShiftEn,
         dout(9 downto 6)   => config.phyConfig.txInterFrameGap,
         dout(25 downto 10) => config.phyConfig.txPauseTime,
         dout(29 downto 26) => config.phyConfig.rxShift,
         dout(30)           => config.phyConfig.rxShiftEn);            

   SyncIn_configVector : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 7)
      port map (
         wr_clk => axiClk,
         din    => r.config.configVector,
         rd_clk => phyClk,
         dout   => config.configVector);    

end rtl;
