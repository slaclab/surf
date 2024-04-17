-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
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


library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiAds42lb69Pkg.all;

entity AxiAds42lb69Reg is
   generic (
      TPD_G              : time              := 1 ns;
      SIM_SPEEDUP_G      : boolean           := false;
      ADC_CLK_FREQ_G     : real              := 250.00E+6; -- units of Hz
      DMODE_INIT_G       : slv(1 downto 0)   := "00");
   port (
      -- AXI-Lite Register Interface (axiClk domain)
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
      axiClk         : in  sl;
      axiRst         : in  sl
   );
end AxiAds42lb69Reg;

architecture rtl of AxiAds42lb69Reg is

   constant TIMEOUT_1S_C : natural := ite(SIM_SPEEDUP_G, 1000, getTimeRatio(ADC_CLK_FREQ_G, 1.0E+00));

   type RegType is record
      adcSmpl       : Slv16VectorArray(1 downto 0, 7 downto 0);
      regOut        : AxiAds42lb69ConfigType;
      axiReadSlave  : AxiLiteReadSlaveType;
      axiWriteSlave : AxiLiteWriteSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      adcSmpl       => (others => (others => (others => '0'))),
      regOut        => AXI_ADS42LB69_CONFIG_INIT_C,
      axiReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axiWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   type AdcType is record
      timer         : natural range 0 to TIMEOUT_1S_C;
      smplCnt       : natural range 0 to 7;
      armed         : sl;
   end record AdcType;

   constant ADC_INIT_C : AdcType := (
      timer         => 0,
      smplCnt       => 0,
      armed         => '0');

   signal r    : RegType := REG_INIT_C;
   signal rin  : RegType;
   signal ra   : AdcType := ADC_INIT_C;
   signal rain : AdcType;

   signal regIn : AxiAds42lb69StatusType := AXI_ADS42LB69_STATUS_INIT_C;

begin



   -------------------------------
   -- Configuration Register
   -------------------------------
   comb : process (axiRst, adcRst, axiReadMaster, axiWriteMaster, r, ra, regIn) is
      variable v            : RegType;
      variable va           : AdcType;
      variable axiStatus    : AxiLiteStatusType;
      variable axiWriteResp : slv(1 downto 0);
      variable axiReadResp  : slv(1 downto 0);
   begin
      -- Latch the current value
      v := r;
      va := ra;

      -- Determine the transaction type
      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);

      -- Reset strobe signals
      v.regOut.delayIn.load := (others=>(others=>'0'));
      v.regOut.delayIn.rst  := '0';

      -- Increment the counter (ADC clock domain)
      va.timer := ra.timer + 1;
      -- Check the timer for 1 second timeout
      if ra.timer = TIMEOUT_1S_C then
         -- Reset the counters
         va.timer := 0;
         va.smplCnt := 0;
         -- Set the flag
         va.armed := '1';
      end if;
      -- Count ADC samples (ADC clock domain)
      if ra.armed = '1' then
         va.smplCnt := ra.smplCnt + 1;
         if ra.smplCnt = 7 then
            va.armed := '0';
         end if;
      end if;

      -- Store last 8 samples read from ADCs
      for ch in 1 downto 0 loop
         if (regIn.adcValid(ch) = '1') then
            v.adcSmpl(ch, 0) := regIn.adcData(ch);
            v.adcSmpl(ch, 1) := r.adcSmpl(ch, 0);
            v.adcSmpl(ch, 2) := r.adcSmpl(ch, 1);
            v.adcSmpl(ch, 3) := r.adcSmpl(ch, 2);
            v.adcSmpl(ch, 4) := r.adcSmpl(ch, 3);
            v.adcSmpl(ch, 5) := r.adcSmpl(ch, 4);
            v.adcSmpl(ch, 6) := r.adcSmpl(ch, 5);
            v.adcSmpl(ch, 7) := r.adcSmpl(ch, 6);
         end if;
      end loop;

      if (axiStatus.writeEnable = '1') then
         -- Check for an out of 32 bit aligned address
         axiWriteResp := ite(axiWriteMaster.awaddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_RESP_DECERR_C);
         -- Decode address and perform write
         case (axiWriteMaster.awaddr(9 downto 2)) is
            when x"80" =>
               v.regOut.delayIn.load(0)(0) := '1';
               v.regOut.delayIn.rst        := '1';
               v.regOut.delayIn.data       := axiWriteMaster.wdata(8 downto 0);
            when x"81" =>
               v.regOut.delayIn.load(0)(1) := '1';
               v.regOut.delayIn.rst        := '1';
               v.regOut.delayIn.data       := axiWriteMaster.wdata(8 downto 0);
            when x"82" =>
               v.regOut.delayIn.load(0)(2) := '1';
               v.regOut.delayIn.rst        := '1';
               v.regOut.delayIn.data       := axiWriteMaster.wdata(8 downto 0);
            when x"83" =>
               v.regOut.delayIn.load(0)(3) := '1';
               v.regOut.delayIn.rst        := '1';
               v.regOut.delayIn.data       := axiWriteMaster.wdata(8 downto 0);
            when x"84" =>
               v.regOut.delayIn.load(0)(4) := '1';
               v.regOut.delayIn.rst        := '1';
               v.regOut.delayIn.data       := axiWriteMaster.wdata(8 downto 0);
            when x"85" =>
               v.regOut.delayIn.load(0)(5) := '1';
               v.regOut.delayIn.rst        := '1';
               v.regOut.delayIn.data       := axiWriteMaster.wdata(8 downto 0);
            when x"86" =>
               v.regOut.delayIn.load(0)(6) := '1';
               v.regOut.delayIn.rst        := '1';
               v.regOut.delayIn.data       := axiWriteMaster.wdata(8 downto 0);
            when x"87" =>
               v.regOut.delayIn.load(0)(7) := '1';
               v.regOut.delayIn.rst        := '1';
               v.regOut.delayIn.data       := axiWriteMaster.wdata(8 downto 0);
            when x"88" =>
               v.regOut.delayIn.load(1)(0) := '1';
               v.regOut.delayIn.rst        := '1';
               v.regOut.delayIn.data       := axiWriteMaster.wdata(8 downto 0);
            when x"89" =>
               v.regOut.delayIn.load(1)(1) := '1';
               v.regOut.delayIn.rst        := '1';
               v.regOut.delayIn.data       := axiWriteMaster.wdata(8 downto 0);
            when x"8A" =>
               v.regOut.delayIn.load(1)(2) := '1';
               v.regOut.delayIn.rst        := '1';
               v.regOut.delayIn.data       := axiWriteMaster.wdata(8 downto 0);
            when x"8B" =>
               v.regOut.delayIn.load(1)(3) := '1';
               v.regOut.delayIn.rst        := '1';
               v.regOut.delayIn.data       := axiWriteMaster.wdata(8 downto 0);
            when x"8C" =>
               v.regOut.delayIn.load(1)(4) := '1';
               v.regOut.delayIn.rst        := '1';
               v.regOut.delayIn.data       := axiWriteMaster.wdata(8 downto 0);
            when x"8D" =>
               v.regOut.delayIn.load(1)(5) := '1';
               v.regOut.delayIn.rst        := '1';
               v.regOut.delayIn.data       := axiWriteMaster.wdata(8 downto 0);
            when x"8E" =>
               v.regOut.delayIn.load(1)(6) := '1';
               v.regOut.delayIn.rst        := '1';
               v.regOut.delayIn.data       := axiWriteMaster.wdata(8 downto 0);
            when x"8F" =>
               v.regOut.delayIn.load(1)(7) := '1';
               v.regOut.delayIn.rst        := '1';
               v.regOut.delayIn.data       := axiWriteMaster.wdata(8 downto 0);
            when x"90" =>
               v.regOut.dmode := axiWriteMaster.wdata(1 downto 0);
            when x"91" =>
               v.regOut.invert := axiWriteMaster.wdata(1 downto 0);
            when x"92" =>
               v.regOut.convert := axiWriteMaster.wdata(1 downto 0);
            when others =>
               axiWriteResp := AXI_RESP_DECERR_C;
         end case;
         -- Send AXI response
         axiSlaveWriteResponse(v.axiWriteSlave, axiWriteResp);
      elsif (axiStatus.readEnable = '1') then
         -- Check for an out of 32 bit aligned address
         axiReadResp          := ite(axiReadMaster.araddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_RESP_DECERR_C);
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
               v.axiReadSlave.rdata(9 downto 0) := regIn.delayOut.data(0, 0);
            when x"81" =>
               v.axiReadSlave.rdata(9 downto 0) := regIn.delayOut.data(0, 1);
            when x"82" =>
               v.axiReadSlave.rdata(9 downto 0) := regIn.delayOut.data(0, 2);
            when x"83" =>
               v.axiReadSlave.rdata(9 downto 0) := regIn.delayOut.data(0, 3);
            when x"84" =>
               v.axiReadSlave.rdata(9 downto 0) := regIn.delayOut.data(0, 4);
            when x"85" =>
               v.axiReadSlave.rdata(9 downto 0) := regIn.delayOut.data(0, 5);
            when x"86" =>
               v.axiReadSlave.rdata(9 downto 0) := regIn.delayOut.data(0, 6);
            when x"87" =>
               v.axiReadSlave.rdata(9 downto 0) := regIn.delayOut.data(0, 7);
            when x"88" =>
               v.axiReadSlave.rdata(9 downto 0) := regIn.delayOut.data(1, 0);
            when x"89" =>
               v.axiReadSlave.rdata(9 downto 0) := regIn.delayOut.data(1, 1);
            when x"8A" =>
               v.axiReadSlave.rdata(9 downto 0) := regIn.delayOut.data(1, 2);
            when x"8B" =>
               v.axiReadSlave.rdata(9 downto 0) := regIn.delayOut.data(1, 3);
            when x"8C" =>
               v.axiReadSlave.rdata(9 downto 0) := regIn.delayOut.data(1, 4);
            when x"8D" =>
               v.axiReadSlave.rdata(9 downto 0) := regIn.delayOut.data(1, 5);
            when x"8E" =>
               v.axiReadSlave.rdata(9 downto 0) := regIn.delayOut.data(1, 6);
            when x"8F" =>
               v.axiReadSlave.rdata(9 downto 0) := regIn.delayOut.data(1, 7);
            when x"90" =>
               v.axiReadSlave.rdata(1 downto 0) := r.regOut.dmode;
            when x"91" =>
               v.axiReadSlave.rdata(1 downto 0) := r.regOut.invert;
            when x"92" =>
               v.axiReadSlave.rdata(1 downto 0) := r.regOut.convert;
            when others =>
               axiReadResp := AXI_RESP_DECERR_C;
         end case;
         -- Send Axi Response
         axiSlaveReadResponse(v.axiReadSlave, axiReadResp);
      end if;

      -- Synchronous Reset
      if axiRst = '1' then
         v              := REG_INIT_C;
         v.regOut.dmode := DMODE_INIT_G;
      end if;
      -- Synchronous Reset
      if adcRst = '1' then
         va             := ADC_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;
      rain <= va;

      -- Outputs
      axiReadSlave   <= r.axiReadSlave;
      axiWriteSlave  <= r.axiWriteSlave;
      config         <= r.regOut;

   end process comb;

   seq : process (axiClk) is
   begin
      if rising_edge(axiClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   seqa : process (adcClk) is
   begin
      if rising_edge(adcClk) then
         ra <= rain after TPD_G;
      end if;
   end process seqa;

   -------------------------------
   -- Synchronization
   -------------------------------

   GEN_ADC_SMPL :
   for ch in 0 to 1 generate
      SyncOut_delayIn_data : entity surf.SynchronizerFifo
         generic map (
            TPD_G        => TPD_G,
            DATA_WIDTH_G => 16)
         port map (
            wr_clk   => adcClk,
            wr_en    => ra.armed,
            din      => status.adcData(ch),
            rd_clk   => axiClk,
            rd_en    => regIn.adcValid(ch),
            valid    => regIn.adcValid(ch),
            dout     => regIn.adcData(ch)
         );
   end generate;

   regIn.delayOut <= status.delayOut;

end rtl;
