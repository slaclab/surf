-------------------------------------------------------------------------------
-- File       : AxiAds42lb69Reg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-03-20
-- Last update: 2015-05-19
-------------------------------------------------------------------------------
-- Description: AXI-Lite Register Access
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
use work.AxiAds42lb69Pkg.all;

entity AxiAds42lb69Reg is
   generic (
      TPD_G              : time                                    := 1 ns;
      ADC_CLK_FREQ_G     : real                                    := 250.0E+6;  -- units of Hz
      DMODE_INIT_G       : slv(1 downto 0)                         := "00";
      DELAY_INIT_G       : Slv5VectorArray(1 downto 0, 7 downto 0) := (others => (others => (others => '0')));
      STATUS_CNT_WIDTH_G : natural range 1 to 32                   := 32;
      AXI_ERROR_RESP_G   : slv(1 downto 0)                         := AXI_RESP_SLVERR_C);  
   port (
      -- ADC Ports
      csL            : out sl;
      sck            : out sl;
      sdi            : out sl;
      rst            : out sl;
      sdo            : in  sl;
      -- AXI-Lite Register Interface (adcClk domain)
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;
      -- Register Inputs/Outputs (Mixed domain)
      status         : in  AxiAds42lb69StatusType;
      config         : out AxiAds42lb69ConfigType;
      -- Global Signals
      adcClk         : in  sl;
      adcRst         : in  sl;
      refClk200MHz   : in  sl);      
end AxiAds42lb69Reg;

architecture rtl of AxiAds42lb69Reg is

   constant HALF_SCLK_C  : natural := getTimeRatio(ADC_CLK_FREQ_G, 10.0E+06);
   constant TIMEOUT_1S_C : natural := getTimeRatio(ADC_CLK_FREQ_G, 1.0E+00);
   
   type StateType is (
      IDLE_S,
      SCK_LOW_S,
      SCK_HIGH_S);    

   type RegType is record
      csL           : sl;
      sck           : sl;
      sdi           : sl;
      serReg        : slv(15 downto 0);
      pntr          : natural range 0 to 15;
      cnt           : natural range 0 to HALF_SCLK_C;
      timer         : natural range 0 to TIMEOUT_1S_C;
      smplCnt       : natural range 0 to 7;
      armed         : sl;
      adcSmpl       : Slv16VectorArray(1 downto 0, 7 downto 0);
      regOut        : AxiAds42lb69ConfigType;
      state         : StateType;
      axiReadSlave  : AxiLiteReadSlaveType;
      axiWriteSlave : AxiLiteWriteSlaveType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      csL           => '1',
      sck           => '1',
      sdi           => '1',
      serReg        => (others => '0'),
      pntr          => 0,
      cnt           => 0,
      timer         => 0,
      smplCnt       => 0,
      armed         => '0',
      adcSmpl       => (others => (others => (others => '0'))),
      regOut        => AXI_ADS42LB69_CONFIG_INIT_C,
      state         => IDLE_S,
      axiReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axiWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal regIn : AxiAds42lb69StatusType := AXI_ADS42LB69_STATUS_INIT_C;

begin

   -------------------------------
   -- Configuration Register
   -------------------------------  
   comb : process (adcRst, axiReadMaster, axiWriteMaster, r, regIn, sdo) is
      variable i            : integer;
      variable v            : RegType;
      variable axiStatus    : AxiLiteStatusType;
      variable axiWriteResp : slv(1 downto 0);
      variable axiReadResp  : slv(1 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Determine the transaction type
      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);

      -- Reset strobe signals
      v.regOut.delayIn.load := '0';
      v.regOut.delayIn.rst  := '0';

      -- Increment the counter
      v.timer := r.timer + 1;
      -- Check the timer for 1 second timeout
      if r.timer = TIMEOUT_1S_C then
         -- Reset the counter
         v.timer := 0;
         -- Set the flag
         v.armed := '1';
      end if;

      -- Process for collecting 8 consecutive samples after each 1 second timeout
      if r.armed = '1' then
         -- Latch the value
         v.adcSmpl(0, r.smplCnt) := regIn.adcData(0);
         v.adcSmpl(1, r.smplCnt) := regIn.adcData(1);
         -- Increment the counter   
         v.smplCnt               := r.smplCnt + 1;
         -- Check the counter value
         if r.smplCnt = 7 then
            -- Reset the counter
            v.smplCnt := 0;
            -- Reset the flag
            v.armed   := '0';
         end if;
      end if;

      if (axiStatus.writeEnable = '1') and (r.state = IDLE_S) then
         -- Check for an out of 32 bit aligned address
         axiWriteResp := ite(axiWriteMaster.awaddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_ERROR_RESP_G);
         if (axiWriteMaster.awaddr(9 downto 2) < 64) then
            v.serReg(15)          := '0';  -- Write
            v.serReg(14)          := '0';  -- Reserved
            v.serReg(13 downto 8) := axiWriteMaster.awaddr(7 downto 2);
            v.serReg(7 downto 0)  := axiWriteMaster.wdata(7 downto 0);
            v.state               := SCK_LOW_S;
         else
            -- Decode address and perform write
            case (axiWriteMaster.awaddr(9 downto 2)) is
               when x"80" =>
                  v.regOut.delayIn.load       := '1';
                  v.regOut.delayIn.rst        := '1';
                  v.regOut.delayIn.data(0, 0) := axiWriteMaster.wdata(4 downto 0);
               when x"81" =>
                  v.regOut.delayIn.load       := '1';
                  v.regOut.delayIn.rst        := '1';
                  v.regOut.delayIn.data(0, 1) := axiWriteMaster.wdata(4 downto 0);
               when x"82" =>
                  v.regOut.delayIn.load       := '1';
                  v.regOut.delayIn.rst        := '1';
                  v.regOut.delayIn.data(0, 2) := axiWriteMaster.wdata(4 downto 0);
               when x"83" =>
                  v.regOut.delayIn.load       := '1';
                  v.regOut.delayIn.rst        := '1';
                  v.regOut.delayIn.data(0, 3) := axiWriteMaster.wdata(4 downto 0);
               when x"84" =>
                  v.regOut.delayIn.load       := '1';
                  v.regOut.delayIn.rst        := '1';
                  v.regOut.delayIn.data(0, 4) := axiWriteMaster.wdata(4 downto 0);
               when x"85" =>
                  v.regOut.delayIn.load       := '1';
                  v.regOut.delayIn.rst        := '1';
                  v.regOut.delayIn.data(0, 5) := axiWriteMaster.wdata(4 downto 0);
               when x"86" =>
                  v.regOut.delayIn.load       := '1';
                  v.regOut.delayIn.rst        := '1';
                  v.regOut.delayIn.data(0, 6) := axiWriteMaster.wdata(4 downto 0);
               when x"87" =>
                  v.regOut.delayIn.load       := '1';
                  v.regOut.delayIn.rst        := '1';
                  v.regOut.delayIn.data(0, 7) := axiWriteMaster.wdata(4 downto 0);
               when x"88" =>
                  v.regOut.delayIn.load       := '1';
                  v.regOut.delayIn.rst        := '1';
                  v.regOut.delayIn.data(1, 0) := axiWriteMaster.wdata(4 downto 0);
               when x"89" =>
                  v.regOut.delayIn.load       := '1';
                  v.regOut.delayIn.rst        := '1';
                  v.regOut.delayIn.data(1, 1) := axiWriteMaster.wdata(4 downto 0);
               when x"8A" =>
                  v.regOut.delayIn.load       := '1';
                  v.regOut.delayIn.rst        := '1';
                  v.regOut.delayIn.data(1, 2) := axiWriteMaster.wdata(4 downto 0);
               when x"8B" =>
                  v.regOut.delayIn.load       := '1';
                  v.regOut.delayIn.rst        := '1';
                  v.regOut.delayIn.data(1, 3) := axiWriteMaster.wdata(4 downto 0);
               when x"8C" =>
                  v.regOut.delayIn.load       := '1';
                  v.regOut.delayIn.rst        := '1';
                  v.regOut.delayIn.data(1, 4) := axiWriteMaster.wdata(4 downto 0);
               when x"8D" =>
                  v.regOut.delayIn.load       := '1';
                  v.regOut.delayIn.rst        := '1';
                  v.regOut.delayIn.data(1, 5) := axiWriteMaster.wdata(4 downto 0);
               when x"8E" =>
                  v.regOut.delayIn.load       := '1';
                  v.regOut.delayIn.rst        := '1';
                  v.regOut.delayIn.data(1, 6) := axiWriteMaster.wdata(4 downto 0);
               when x"8F" =>
                  v.regOut.delayIn.load       := '1';
                  v.regOut.delayIn.rst        := '1';
                  v.regOut.delayIn.data(1, 7) := axiWriteMaster.wdata(4 downto 0);
               when x"90" =>
                  v.regOut.dmode := axiWriteMaster.wdata(1 downto 0);
               when others =>
                  axiWriteResp := AXI_ERROR_RESP_G;
            end case;
            -- Send AXI response
            axiSlaveWriteResponse(v.axiWriteSlave, axiWriteResp);
         end if;
      elsif (axiStatus.readEnable = '1') and (r.state = IDLE_S) then
         -- Check for an out of 32 bit aligned address
         axiReadResp          := ite(axiReadMaster.araddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_ERROR_RESP_G);
         -- Reset the register
         v.axiReadSlave.rdata := (others => '0');
         if (axiReadMaster.araddr(9 downto 2) < 64) then
            v.serReg(15)          := '1';  -- Read
            v.serReg(14)          := '0';  -- Reserved
            v.serReg(13 downto 8) := axiReadMaster.araddr(7 downto 2);
            v.serReg(7 downto 0)  := (others => '0');
            v.state               := SCK_LOW_S;
         else
            -- Decode address and assign read data
            case (axiReadMaster.araddr(9 downto 2)) is
               when x"60" =>
                  v.axiReadSlave.rdata(15 downto 0) := r.adcSmpl(0, 0);
               when x"61" =>
                  v.axiReadSlave.rdata(15 downto 0) := r.adcSmpl(0, 1);
               when x"62" =>
                  v.axiReadSlave.rdata(15 downto 0) := r.adcSmpl(0, 2);
               when x"63" =>
                  v.axiReadSlave.rdata(15 downto 0) := r.adcSmpl(0, 3);
               when x"64" =>
                  v.axiReadSlave.rdata(15 downto 0) := r.adcSmpl(0, 4);
               when x"65" =>
                  v.axiReadSlave.rdata(15 downto 0) := r.adcSmpl(0, 5);
               when x"66" =>
                  v.axiReadSlave.rdata(15 downto 0) := r.adcSmpl(0, 6);
               when x"67" =>
                  v.axiReadSlave.rdata(15 downto 0) := r.adcSmpl(0, 7);
               when x"68" =>
                  v.axiReadSlave.rdata(15 downto 0) := r.adcSmpl(1, 0);
               when x"69" =>
                  v.axiReadSlave.rdata(15 downto 0) := r.adcSmpl(1, 1);
               when x"6A" =>
                  v.axiReadSlave.rdata(15 downto 0) := r.adcSmpl(1, 2);
               when x"6B" =>
                  v.axiReadSlave.rdata(15 downto 0) := r.adcSmpl(1, 3);
               when x"6C" =>
                  v.axiReadSlave.rdata(15 downto 0) := r.adcSmpl(1, 4);
               when x"6D" =>
                  v.axiReadSlave.rdata(15 downto 0) := r.adcSmpl(1, 5);
               when x"6E" =>
                  v.axiReadSlave.rdata(15 downto 0) := r.adcSmpl(1, 6);
               when x"6F" =>
                  v.axiReadSlave.rdata(15 downto 0) := r.adcSmpl(1, 7);
               when x"7F" =>
                  v.axiReadSlave.rdata(0) := regIn.delayOut.rdy;
               when x"80" =>
                  v.axiReadSlave.rdata(4 downto 0) := regIn.delayOut.data(0, 0);
               when x"81" =>
                  v.axiReadSlave.rdata(4 downto 0) := regIn.delayOut.data(0, 1);
               when x"82" =>
                  v.axiReadSlave.rdata(4 downto 0) := regIn.delayOut.data(0, 2);
               when x"83" =>
                  v.axiReadSlave.rdata(4 downto 0) := regIn.delayOut.data(0, 3);
               when x"84" =>
                  v.axiReadSlave.rdata(4 downto 0) := regIn.delayOut.data(0, 4);
               when x"85" =>
                  v.axiReadSlave.rdata(4 downto 0) := regIn.delayOut.data(0, 5);
               when x"86" =>
                  v.axiReadSlave.rdata(4 downto 0) := regIn.delayOut.data(0, 6);
               when x"87" =>
                  v.axiReadSlave.rdata(4 downto 0) := regIn.delayOut.data(0, 7);
               when x"88" =>
                  v.axiReadSlave.rdata(4 downto 0) := regIn.delayOut.data(1, 0);
               when x"89" =>
                  v.axiReadSlave.rdata(4 downto 0) := regIn.delayOut.data(1, 1);
               when x"8A" =>
                  v.axiReadSlave.rdata(4 downto 0) := regIn.delayOut.data(1, 2);
               when x"8B" =>
                  v.axiReadSlave.rdata(4 downto 0) := regIn.delayOut.data(1, 3);
               when x"8C" =>
                  v.axiReadSlave.rdata(4 downto 0) := regIn.delayOut.data(1, 4);
               when x"8D" =>
                  v.axiReadSlave.rdata(4 downto 0) := regIn.delayOut.data(1, 5);
               when x"8E" =>
                  v.axiReadSlave.rdata(4 downto 0) := regIn.delayOut.data(1, 6);
               when x"8F" =>
                  v.axiReadSlave.rdata(4 downto 0) := regIn.delayOut.data(1, 7);
               when x"90" =>
                  v.axiReadSlave.rdata(1 downto 0) := r.regOut.dmode;
               when others =>
                  axiReadResp := AXI_ERROR_RESP_G;
            end case;
            -- Send Axi Response
            axiSlaveReadResponse(v.axiReadSlave, axiReadResp);
         end if;
      end if;

      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when IDLE_S =>
            v.csL := '1';
            v.sck := '0';
         ----------------------------------------------------------------------
         when SCK_LOW_S =>
            v.csL := '0';
            v.sck := '0';
            v.sdi := r.serReg(15-r.pntr);
            v.cnt := r.cnt + 1;
            if r.cnt = HALF_SCLK_C then
               v.cnt := 0;
               if r.pntr > 7 then
                  v.axiReadSlave.rdata(15-r.pntr) := sdo;
               end if;
               -- Next State
               v.state := SCK_HIGH_S;
            end if;
         ----------------------------------------------------------------------
         when SCK_HIGH_S =>
            v.sck := '1';
            v.cnt := r.cnt + 1;
            if r.cnt = HALF_SCLK_C then
               v.cnt  := 0;
               v.pntr := r.pntr + 1;
               if r.pntr = 15 then
                  v.pntr := 0;
                  -- Check if we need to perform a read or write response
                  if r.serReg(15) = '0' then
                     axiSlaveWriteResponse(v.axiWriteSlave);
                  else
                     axiSlaveReadResponse(v.axiReadSlave);
                  end if;
                  -- Next State
                  v.state := IDLE_S;
               else
                  -- Next State
                  v.state := SCK_LOW_S;
               end if;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Synchronous Reset
      if adcRst = '1' then
         v                     := REG_INIT_C;
         v.regOut.delayIn.load := '1';
         v.regOut.delayIn.rst  := '1';
         v.regOut.delayIn.data := DELAY_INIT_G;
         v.regOut.dmode        := DMODE_INIT_G;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      axiReadSlave  <= r.axiReadSlave;
      axiWriteSlave <= r.axiWriteSlave;
      csL           <= r.csL;
      sck           <= r.sck;
      sdi           <= r.sdi;
      
   end process comb;

   seq : process (adcClk) is
   begin
      if rising_edge(adcClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   PwrUpRst_inst : entity work.PwrUpRst
      generic map (
         TPD_G      => TPD_G,
         DURATION_G => getTimeRatio(ADC_CLK_FREQ_G, 2.0E+06))  -- 500 ns reset pulse
      port map (
         arst   => adcRst,
         clk    => adcClk,
         rstOut => rst);    

   -------------------------------            
   -- Synchronization: Outputs
   -------------------------------
   config.dmode <= r.regOut.dmode;

   GEN_CH_CONFIG :
   for ch in 0 to 1 generate
      GEN_DAT_CONFIG :
      for i in 0 to 7 generate
         SyncOut_delayIn_data : entity work.SynchronizerFifo
            generic map (
               TPD_G        => TPD_G,
               DATA_WIDTH_G => 5)
            port map (
               wr_clk => adcClk,
               din    => r.regOut.delayIn.data(ch, i),
               rd_clk => refClk200MHz,
               dout   => config.delayIn.data(ch, i));
      end generate GEN_DAT_CONFIG;
   end generate GEN_CH_CONFIG;

   SyncOut_delayIn_load : entity work.RstSync
      generic map (
         TPD_G           => TPD_G,
         RELEASE_DELAY_G => 32)   
      port map (
         clk      => refClk200MHz,
         asyncRst => r.regOut.delayIn.load,
         syncRst  => config.delayIn.load); 

   SyncOut_delayIn_rst : entity work.RstSync
      generic map (
         TPD_G           => TPD_G,
         RELEASE_DELAY_G => 16)   
      port map (
         clk      => refClk200MHz,
         asyncRst => r.regOut.delayIn.rst,
         syncRst  => config.delayIn.rst);     

   -------------------------------
   -- Synchronization: Inputs
   -------------------------------
   regIn.adcData <= status.adcData;

   SyncIn_delayOut_rdy : entity work.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => adcClk,
         dataIn  => status.delayOut.rdy,
         dataOut => regIn.delayOut.rdy);   

   GEN_CH_STATUS :
   for ch in 0 to 1 generate
      GEN_DAT_STATUS :
      for i in 0 to 7 generate
         SyncIn_delayOut_data : entity work.SynchronizerFifo
            generic map (
               TPD_G        => TPD_G,
               DATA_WIDTH_G => 5)
            port map (
               wr_clk => refClk200MHz,
               din    => status.delayOut.data(ch, i),
               rd_clk => adcClk,
               dout   => regIn.delayOut.data(ch, i));       
      end generate GEN_DAT_STATUS;
   end generate GEN_CH_STATUS;

end rtl;
