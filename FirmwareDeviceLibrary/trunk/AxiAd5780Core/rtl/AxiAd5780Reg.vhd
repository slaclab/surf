-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AxiAd5780Reg.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-18
-- Last update: 2014-04-18
-- Platform   : Vivado 2013.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
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
      axiRst         : in  sl);      
end AxiAd5780Reg;

architecture rtl of AxiAd5780Reg is

   constant STATUS_SIZE_C : positive := 1;

   type RegType is record
      cntRst        : sl;
      rollOverEn    : slv(STATUS_SIZE_C-1 downto 0);
      regOut        : AxiAd5780ConfigType;
      axiReadSlave  : AxiLiteReadSlaveType;
      axiWriteSlave : AxiLiteWriteSlaveType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      '1',
      (others => '0'),
      AXI_AD5780_CONFIG_INIT_C,
      AXI_LITE_READ_SLAVE_INIT_C,
      AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal regIn  : AxiAd5780StatusType := AXI_AD5780_STATUS_INIT_C;
   signal regOut : AxiAd5780ConfigType := AXI_AD5780_CONFIG_INIT_C;

   signal cntRst     : sl;
   signal rollOverEn : slv(STATUS_SIZE_C-1 downto 0);
   signal cntOut     : SlVectorArray(STATUS_SIZE_C-1 downto 0, STATUS_CNT_WIDTH_G-1 downto 0);

   signal dacValidCnt  : slv(STATUS_CNT_WIDTH_G-1 downto 0);
   signal dacValidRate : slv(STATUS_CNT_WIDTH_G-1 downto 0);

begin

   -------------------------------
   -- Configuration Register
   -------------------------------  
   comb : process (axiReadMaster, axiRst, axiWriteMaster, dacValidCnt, dacValidRate, r, regIn) is
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
      v.cntRst := '0';

      if (axiStatus.writeEnable = '1') then
         -- Check for an out of 32 bit aligned address
         axiWriteResp := ite(axiWriteMaster.awaddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_ERROR_RESP_G);
         -- Decode address and perform write
         case (axiWriteMaster.awaddr(9 downto 2)) is
            when x"80" =>
               v.regOut.debugMux := axiWriteMaster.wdata(0);
            when x"90" =>
               v.regOut.debugData := axiWriteMaster.wdata(17 downto 0);
            when x"F0" =>
               v.rollOverEn := axiWriteMaster.wdata(STATUS_SIZE_C-1 downto 0);
            when x"FF" =>
               v.cntRst := '1';
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
            when x"00" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := dacValidCnt;
            when x"10" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := dacValidRate;
            when x"20" =>
               v.axiReadSlave.rdata(0) := regIn.dacValid;
            when x"30" =>
               v.axiReadSlave.rdata(17 downto 0) := regIn.dacData;
            when x"80" =>
               v.axiReadSlave.rdata(0) := r.regOut.debugMux;
            when x"90" =>
               v.axiReadSlave.rdata(17 downto 0) := r.regOut.debugData;
            when x"F0" =>
               v.axiReadSlave.rdata(STATUS_SIZE_C-1 downto 0) := r.rollOverEn;
            when others =>
               axiReadResp := AXI_ERROR_RESP_G;
         end case;
         -- Send Axi Response
         axiSlaveReadResponse(v.axiReadSlave, axiReadResp);
      end if;

      -- Synchronous Reset
      if axiRst = '1' then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      axiReadSlave  <= r.axiReadSlave;
      axiWriteSlave <= r.axiWriteSlave;

      regOut <= r.regOut;

      cntRst     <= r.cntRst;
      rollOverEn <= r.rollOverEn;
      
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

   SyncStatusVec_Inst : entity work.SyncStatusVector
      generic map (
         TPD_G          => TPD_G,
         OUT_POLARITY_G => '1',
         CNT_RST_EDGE_G => true,
         COMMON_CLK_G   => true,
         CNT_WIDTH_G    => STATUS_CNT_WIDTH_G,
         WIDTH_G        => STATUS_SIZE_C)     
      port map (
         -- Input Status bit Signals (wrClk domain)   
         statusIn(0)  => status.dacValid,
         -- Output Status bit Signals (rdClk domain) 
         statusOut(0) => regIn.dacValid,
         -- Status Bit Counters Signals (rdClk domain) 
         cntRstIn     => cntRst,
         rollOverEnIn => rollOverEn,
         cntOut       => cntOut,
         -- Clocks and Reset Ports
         wrClk        => axiClk,
         rdClk        => axiClk);

   dacValidCnt <= muxSlVectorArray(cntOut, 0);

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
         trigIn          => status.dacValid,
         -- Trigger Rate Output (locClk domain)
         trigRateUpdated => open,
         trigRateOut     => dacValidRate,
         -- Clocks
         locClkEn        => '1',
         locClk          => axiClk,
         refClk          => axiClk);        

end rtl;
