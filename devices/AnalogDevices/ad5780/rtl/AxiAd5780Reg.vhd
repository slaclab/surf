-------------------------------------------------------------------------------
-- File       : AxiAd5780Reg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-18
-- Last update: 2016-09-20
-------------------------------------------------------------------------------
-- Description: AXI-Lite interface to AD5780 DAC IC
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
use work.AxiAd5780Pkg.all;

entity AxiAd5780Reg is
   generic (
      TPD_G              : time                  := 1 ns;
      STATUS_CNT_WIDTH_G : natural range 1 to 32 := 32;
      USE_DSP48_G        : string                := "no";  -- "no" for no DSP48 implementation, "yes" to use DSP48 slices      
      AXI_CLK_FREQ_G     : real                  := 200.0E+6;  -- units of Hz
      SPI_CLK_FREQ_G     : real                  := 25.0E+6;   -- units of Hz      
      AXI_ERROR_RESP_G   : slv(1 downto 0)       := AXI_RESP_SLVERR_C);
   port (
      -- AXI-Lite Register Interface
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;
      -- Register Inputs/Outputs
      status         : in  AxiAd5780StatusType;
      config         : out AxiAd5780ConfigType;
      -- Global Signals
      axiClk         : in  sl;
      axiRst         : in  sl;
      dacRst         : out sl);      
end AxiAd5780Reg;

architecture rtl of AxiAd5780Reg is

   constant DOUBLE_SCK_FREQ_C      : real             := SPI_CLK_FREQ_G * 2.0E+0;
   constant HALF_SCK_PERIOD_C      : natural          := (getTimeRatio(AXI_CLK_FREQ_G, DOUBLE_SCK_FREQ_C))-1;
   constant HALF_SCK_PERIOD_INIT_C : slv(31 downto 0) := toSlv(HALF_SCK_PERIOD_C, 32);

   type RegType is record
      dacRst        : sl;
      regOut        : AxiAd5780ConfigType;
      axiReadSlave  : AxiLiteReadSlaveType;
      axiWriteSlave : AxiLiteWriteSlaveType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      '1',
      AXI_AD5780_CONFIG_INIT_C,
      AXI_LITE_READ_SLAVE_INIT_C,
      AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal regIn  : AxiAd5780StatusType := AXI_AD5780_STATUS_INIT_C;
   signal regOut : AxiAd5780ConfigType := AXI_AD5780_CONFIG_INIT_C;

   signal dacRefreshRate : slv(STATUS_CNT_WIDTH_G-1 downto 0);

begin

   -------------------------------
   -- Configuration Register
   -------------------------------  
   comb : process (axiReadMaster, axiRst, axiWriteMaster, dacRefreshRate, r, regIn) is
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
      v.dacRst := '0';

      if (axiStatus.writeEnable = '1') then
         -- Check for an out of 32 bit aligned address
         axiWriteResp := ite(axiWriteMaster.awaddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_ERROR_RESP_G);
         -- Decode address and perform write
         case (axiWriteMaster.awaddr(9 downto 2)) is
            when x"80" =>
               v.regOut.debugMux := axiWriteMaster.wdata(0);
            when x"90" =>
               v.regOut.debugData := axiWriteMaster.wdata(17 downto 0);
            when x"A0" =>
               v.regOut.sdoDisable := axiWriteMaster.wdata(0);
               v.dacRst            := '1';
            when x"A1" =>
               v.regOut.binaryOffset := axiWriteMaster.wdata(0);
               v.dacRst              := '1';
            when x"A2" =>
               v.regOut.dacTriState := axiWriteMaster.wdata(0);
               v.dacRst             := '1';
            when x"A3" =>
               v.regOut.opGnd := axiWriteMaster.wdata(0);
               v.dacRst       := '1';
            when x"A4" =>
               v.regOut.rbuf := axiWriteMaster.wdata(0);
               v.dacRst      := '1';
            when x"A5" =>
               v.regOut.halfSckPeriod := axiWriteMaster.wdata;
               v.dacRst               := '1';
            when x"FE" =>
               v.dacRst := '1';
            when others =>
               axiWriteResp := AXI_ERROR_RESP_G;
         end case;
         -- Send AXI response
         axiSlaveWriteResponse(v.axiWriteSlave, axiWriteResp);
      end if;

      if (axiStatus.readEnable = '1') then
         -- Check for an out of 32 bit aligned address
         axiReadResp          := ite(axiReadMaster.araddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_ERROR_RESP_G);
         -- Decode address and assign read data
         v.axiReadSlave.rdata := (others => '0');
         case (axiReadMaster.araddr(9 downto 2)) is
            when x"10" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := dacRefreshRate;
            when x"30" =>
               v.axiReadSlave.rdata(17 downto 0) := regIn.dacData;
            when x"80" =>
               v.axiReadSlave.rdata(0) := r.regOut.debugMux;
            when x"90" =>
               v.axiReadSlave.rdata(17 downto 0) := r.regOut.debugData;
            when x"A0" =>
               v.axiReadSlave.rdata(0) := r.regOut.sdoDisable;
            when x"A1" =>
               v.axiReadSlave.rdata(0) := r.regOut.binaryOffset;
            when x"A2" =>
               v.axiReadSlave.rdata(0) := r.regOut.dacTriState;
            when x"A3" =>
               v.axiReadSlave.rdata(0) := r.regOut.opGnd;
            when x"A4" =>
               v.axiReadSlave.rdata(0) := r.regOut.rbuf;
            when x"A5" =>
               v.axiReadSlave.rdata := r.regOut.halfSckPeriod;
            when others =>
               axiReadResp := AXI_ERROR_RESP_G;
         end case;
         -- Send Axi Response
         axiSlaveReadResponse(v.axiReadSlave, axiReadResp);
      end if;

      -- Synchronous Reset
      if axiRst = '1' then
         v                      := REG_INIT_C;
         v.regOut.halfSckPeriod := HALF_SCK_PERIOD_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      axiReadSlave  <= r.axiReadSlave;
      axiWriteSlave <= r.axiWriteSlave;

      regOut <= r.regOut;

      dacRst <= r.dacRst;
      
   end process comb;

   seq : process (axiClk) is
   begin
      if rising_edge(axiClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   -------------------------------            
   -- Synchronization: Outputs
   -------------------------------
   config <= regOut;

   -------------------------------
   -- Synchronization: Inputs
   ------------------------------- 
   regIn.dacData <= status.dacData;

   SyncTrigRate_Inst : entity work.SyncTrigRate
      generic map (
         TPD_G          => TPD_G,
         COMMON_CLK_G   => true,
         IN_POLARITY_G  => '1',
         REF_CLK_FREQ_G => AXI_CLK_FREQ_G,
         REFRESH_RATE_G => 1.0E+0,
         USE_DSP48_G    => USE_DSP48_G,
         CNT_WIDTH_G    => STATUS_CNT_WIDTH_G)     
      port map (
         -- Trigger Input (locClk domain)
         trigIn          => status.dacUpdated,
         -- Trigger Rate Output (locClk domain)
         trigRateUpdated => open,
         trigRateOut     => dacRefreshRate,
         -- Clocks
         locClkEn        => '1',
         locClk          => axiClk,
         refClk          => axiClk);        

end rtl;
