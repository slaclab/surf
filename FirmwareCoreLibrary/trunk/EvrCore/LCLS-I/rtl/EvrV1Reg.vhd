-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrV1Reg.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-11
-- Last update: 2015-08-17
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
use work.Version.all;
use work.EvrV1Pkg.all;

entity EvrV1Reg is
   generic (
      TPD_G            : time            := 1 ns;
      USE_WSTRB_G      : boolean         := false;
      AXI_ERROR_RESP_G : slv(1 downto 0) := AXI_RESP_OK_C);      
   port (
      -- PCIe Interface
      irqActive      : in  sl;
      irqEnable      : out sl;
      irqReq         : out sl;
      -- AXI-Lite Interface
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;
      -- EVR Interface      
      status         : in  EvrV1StatusType;
      config         : out EvrV1ConfigType;
      -- Clock and Reset
      axiClk         : in  sl;
      axiRst         : in  sl);
end EvrV1Reg;

architecture rtl of EvrV1Reg is

   procedure Set4bitMask (
      mask   : inout slv(3 downto 0);
      addr   : in    slv(31 downto 0);
      opCode : in    slv(2 downto 0)) is
   begin
      if addr(14 downto 12) = opCode then
         case addr(3 downto 2) is
            when "00" =>
               mask := "0001";
            when "01" =>
               mask := "0010";
            when "10" =>
               mask := "0100";
            when "11" =>
               mask := "1000";
            when others =>
               mask := "0000";
         end case;
      else
         mask := "0000";
      end if;
   end procedure Set4bitMask;

   type RegType is record
      statusReg     : slv(31 downto 0);
      controlReg    : slv(31 downto 0);
      hardwareInt   : slv(31 downto 0);
      pcieIntEna    : slv(31 downto 0);
      secondsShift  : slv(31 downto 0);
      seconds       : slv(31 downto 0);
      irqClr1       : slv(31 downto 0);
      irqClr2       : slv(31 downto 0);
      dbena         : slv(3 downto 0);
      dbdis         : slv(3 downto 0);
      rdDone        : sl;
      wrDone        : sl;
      config        : EvrV1ConfigType;
      axiReadSlave  : AxiLiteReadSlaveType;
      axiWriteSlave : AxiLiteWriteSlaveType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      statusReg     => (others => '0'),
      controlReg    => (others => '0'),
      hardwareInt   => (others => '0'),
      pcieIntEna    => (others => '0'),
      secondsShift  => (others => '0'),
      seconds       => (others => '0'),
      irqClr1       => (others => '0'),
      irqClr2       => (others => '0'),
      dbena         => (others => '0'),
      dbdis         => (others => '0'),
      rdDone        => '0',
      wrDone        => '0',
      config        => EVR_V1_CONFIG_INIT_C,
      axiReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axiWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal fwVersion : slv(31 downto 0);

   -- attribute dont_touch : string;
   -- attribute dont_touch of r : signal is "true";
   
begin

   fwVersion <= "0001" & "1111" & FPGA_VERSION_C(23 downto 0);

   -------------------------------
   -- Configuration Register
   -------------------------------  
   comb : process (axiReadMaster, axiRst, axiWriteMaster, fwVersion, irqActive, r, status) is
      variable v            : RegType;
      variable axiStatus    : AxiLiteStatusType;
      variable axiWriteResp : slv(1 downto 0);
      variable axiReadResp  : slv(1 downto 0);
      variable rdPntr       : natural;
      variable wrPntr       : natural;
   begin
      -- Latch the current value
      v := r;

      -- Determine the transaction type
      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);

      -- Calculate the address pointers
      wrPntr := conv_integer(axiWriteMaster.awaddr(14 downto 2));
      rdPntr := conv_integer(axiReadMaster.araddr(14 downto 2));

      -- Reset strobing signals
      v.config.tsFifoRdEna := '0';

      -- Shift Registers
      v.irqClr2  := r.irqClr1;
      v.dbena(0) := '0';
      v.dbena(1) := r.dbena(0);
      v.dbena(2) := r.dbena(1);
      v.dbena(3) := r.dbena(2);
      v.dbdis(0) := '0';
      v.dbdis(1) := r.dbdis(0);
      v.dbdis(2) := r.dbdis(1);
      v.dbdis(3) := r.dbdis(2);

      -----------------------------
      -- AXI-Lite Write Logic
      -----------------------------      
      if (axiStatus.writeEnable = '1') then
         -- Check for alignment
         if axiWriteMaster.awaddr(1 downto 0) = "00" then
            -- Set the EVR RAM select mask
            Set4bitMask(v.config.eventRamCs(0), axiWriteMaster.awaddr, "100");
            Set4bitMask(v.config.eventRamCs(1), axiWriteMaster.awaddr, "101");
            Set4bitMask(v.config.eventRamWe(0), axiWriteMaster.awaddr, "100");
            Set4bitMask(v.config.eventRamWe(1), axiWriteMaster.awaddr, "101");
            -- Update external data/address buses
            v.config.eventRamData := axiWriteMaster.wdata;
            v.config.eventRamAddr := axiWriteMaster.awaddr(11 downto 4);
            v.config.dbRdAddr     := axiWriteMaster.awaddr(10 downto 2);
            -- Address is aligned
            axiWriteResp          := AXI_RESP_OK_C;
            case wrPntr is
               when 1 =>
                  v.controlReg := axiWriteMaster.wdata;
               when 2 =>
                  if axiWriteMaster.wdata /= x"FFFFFFFF" then
                     v.irqClr1 := axiWriteMaster.wdata;
                  else
                     v.irqClr1 := (others => '0');
                  end if;
               when 3 =>
                  v.config.intControl := axiWriteMaster.wdata;
               when 4 =>
                  v.hardwareInt := axiWriteMaster.wdata;
               when 5 =>
                  v.pcieIntEna := axiWriteMaster.wdata;
               when 8 =>
                  v.dbena(0)    := axiWriteMaster.wdata(15);
                  v.dbdis(0)    := axiWriteMaster.wdata(14);
                  v.config.dben := axiWriteMaster.wdata(12);
               when 19 =>
                  v.config.uSecDivider := axiWriteMaster.wdata;
               when 40 =>
                  v.config.intEventEn := axiWriteMaster.wdata(0);
               when 41 =>
                  v.config.intEventCount := axiWriteMaster.wdata;
               when 42 =>
                  v.config.intEventCode := axiWriteMaster.wdata(7 downto 0);
               when 43 =>
                  v.config.extEventEn := axiWriteMaster.wdata(0);
               when 44 =>
                  v.config.extEventCode := axiWriteMaster.wdata(7 downto 0);
               when 128 =>
                  v.config.pulseControl(0) := axiWriteMaster.wdata;
               when 129 =>
                  v.config.pulsePrescale(0) := axiWriteMaster.wdata;
               when 130 =>
                  v.config.pulseDelay(0) := axiWriteMaster.wdata;
               when 131 =>
                  v.config.pulseWidth(0) := axiWriteMaster.wdata;
               when 132 =>
                  v.config.pulseControl(1) := axiWriteMaster.wdata;
               when 133 =>
                  v.config.pulsePrescale(1) := axiWriteMaster.wdata;
               when 134 =>
                  v.config.pulseDelay(1) := axiWriteMaster.wdata;
               when 135 =>
                  v.config.pulseWidth(1) := axiWriteMaster.wdata;
               when 136 =>
                  v.config.pulseControl(2) := axiWriteMaster.wdata;
               when 137 =>
                  v.config.pulsePrescale(2) := axiWriteMaster.wdata;
               when 138 =>
                  v.config.pulseDelay(2) := axiWriteMaster.wdata;
               when 139 =>
                  v.config.pulseWidth(2) := axiWriteMaster.wdata;
               when 140 =>
                  v.config.pulseControl(3) := axiWriteMaster.wdata;
               when 141 =>
                  v.config.pulsePrescale(3) := axiWriteMaster.wdata;
               when 142 =>
                  v.config.pulseDelay(3) := axiWriteMaster.wdata;
               when 143 =>
                  v.config.pulseWidth(3) := axiWriteMaster.wdata;
               when 144 =>
                  v.config.pulseControl(4) := axiWriteMaster.wdata;
               when 145 =>
                  v.config.pulsePrescale(4) := axiWriteMaster.wdata;
               when 146 =>
                  v.config.pulseDelay(4) := axiWriteMaster.wdata;
               when 147 =>
                  v.config.pulseWidth(4) := axiWriteMaster.wdata;
               when 148 =>
                  v.config.pulseControl(5) := axiWriteMaster.wdata;
               when 149 =>
                  v.config.pulsePrescale(5) := axiWriteMaster.wdata;
               when 150 =>
                  v.config.pulseDelay(5) := axiWriteMaster.wdata;
               when 151 =>
                  v.config.pulseWidth(5) := axiWriteMaster.wdata;
               when 152 =>
                  v.config.pulseControl(6) := axiWriteMaster.wdata;
               when 153 =>
                  v.config.pulsePrescale(6) := axiWriteMaster.wdata;
               when 154 =>
                  v.config.pulseDelay(6) := axiWriteMaster.wdata;
               when 155 =>
                  v.config.pulseWidth(6) := axiWriteMaster.wdata;
               when 156 =>
                  v.config.pulseControl(7) := axiWriteMaster.wdata;
               when 157 =>
                  v.config.pulsePrescale(7) := axiWriteMaster.wdata;
               when 158 =>
                  v.config.pulseDelay(7) := axiWriteMaster.wdata;
               when 159 =>
                  v.config.pulseWidth(7) := axiWriteMaster.wdata;
               when 160 =>
                  v.config.pulseControl(8) := axiWriteMaster.wdata;
               when 161 =>
                  v.config.pulsePrescale(8) := axiWriteMaster.wdata;
               when 162 =>
                  v.config.pulseDelay(8) := axiWriteMaster.wdata;
               when 163 =>
                  v.config.pulseWidth(8) := axiWriteMaster.wdata;
               when 164 =>
                  v.config.pulseControl(9) := axiWriteMaster.wdata;
               when 165 =>
                  v.config.pulsePrescale(9) := axiWriteMaster.wdata;
               when 166 =>
                  v.config.pulseDelay(9) := axiWriteMaster.wdata;
               when 167 =>
                  v.config.pulseWidth(9) := axiWriteMaster.wdata;
               when 168 =>
                  v.config.pulseControl(10) := axiWriteMaster.wdata;
               when 169 =>
                  v.config.pulsePrescale(10) := axiWriteMaster.wdata;
               when 170 =>
                  v.config.pulseDelay(10) := axiWriteMaster.wdata;
               when 171 =>
                  v.config.pulseWidth(10) := axiWriteMaster.wdata;
               when 172 =>
                  v.config.pulseControl(11) := axiWriteMaster.wdata;
               when 173 =>
                  v.config.pulsePrescale(11) := axiWriteMaster.wdata;
               when 174 =>
                  v.config.pulseDelay(11) := axiWriteMaster.wdata;
               when 175 =>
                  v.config.pulseWidth(11) := axiWriteMaster.wdata;
               when 272 =>
                  if (USE_WSTRB_G = true) then
                     if (axiWriteMaster.wstrb = x"C") then
                        v.config.outputMap(0) := axiWriteMaster.wdata(31 downto 16);
                     end if;
                     if (axiWriteMaster.wstrb = x"3") then
                        v.config.outputMap(1) := axiWriteMaster.wdata(15 downto 0);
                     end if;
                  else
                     v.config.outputMap(0) := axiWriteMaster.wdata(31 downto 16);
                     v.config.outputMap(1) := axiWriteMaster.wdata(15 downto 0);
                  end if;
               when 273 =>
                  if (USE_WSTRB_G = true) then
                     if (axiWriteMaster.wstrb = x"C") then
                        v.config.outputMap(2) := axiWriteMaster.wdata(31 downto 16);
                     end if;
                     if (axiWriteMaster.wstrb = x"3") then
                        v.config.outputMap(3) := axiWriteMaster.wdata(15 downto 0);
                     end if;
                  else
                     v.config.outputMap(2) := axiWriteMaster.wdata(31 downto 16);
                     v.config.outputMap(3) := axiWriteMaster.wdata(15 downto 0);
                  end if;
               when 274 =>
                  if (USE_WSTRB_G = true) then
                     if (axiWriteMaster.wstrb = x"C") then
                        v.config.outputMap(4) := axiWriteMaster.wdata(31 downto 16);
                     end if;
                     if (axiWriteMaster.wstrb = x"3") then
                        v.config.outputMap(5) := axiWriteMaster.wdata(15 downto 0);
                     end if;
                  else
                     v.config.outputMap(4) := axiWriteMaster.wdata(31 downto 16);
                     v.config.outputMap(5) := axiWriteMaster.wdata(15 downto 0);
                  end if;
               when 275 =>
                  if (USE_WSTRB_G = true) then
                     if (axiWriteMaster.wstrb = x"C") then
                        v.config.outputMap(6) := axiWriteMaster.wdata(31 downto 16);
                     end if;
                     if (axiWriteMaster.wstrb = x"3") then
                        v.config.outputMap(7) := axiWriteMaster.wdata(15 downto 0);
                     end if;
                  else
                     v.config.outputMap(6) := axiWriteMaster.wdata(31 downto 16);
                     v.config.outputMap(7) := axiWriteMaster.wdata(15 downto 0);
                  end if;
               when 276 =>
                  if (USE_WSTRB_G = true) then
                     if (axiWriteMaster.wstrb = x"C") then
                        v.config.outputMap(8) := axiWriteMaster.wdata(31 downto 16);
                     end if;
                     if (axiWriteMaster.wstrb = x"3") then
                        v.config.outputMap(9) := axiWriteMaster.wdata(15 downto 0);
                     end if;
                  else
                     v.config.outputMap(8) := axiWriteMaster.wdata(31 downto 16);
                     v.config.outputMap(9) := axiWriteMaster.wdata(15 downto 0);
                  end if;
               when 277 =>
                  if (USE_WSTRB_G = true) then
                     if (axiWriteMaster.wstrb = x"C") then
                        v.config.outputMap(10) := axiWriteMaster.wdata(31 downto 16);
                     end if;
                     if (axiWriteMaster.wstrb = x"3") then
                        v.config.outputMap(11) := axiWriteMaster.wdata(15 downto 0);
                     end if;
                  else
                     v.config.outputMap(10) := axiWriteMaster.wdata(31 downto 16);
                     v.config.outputMap(11) := axiWriteMaster.wdata(15 downto 0);
                  end if;
               when others =>
                  null;
            end case;
         else
            axiWriteResp := AXI_ERROR_RESP_G;
         end if;
         -- Send AXI response
         axiSlaveWriteResponse(v.axiWriteSlave, axiWriteResp);
      -----------------------------
      -- AXI-Lite Read Logic
      -----------------------------      
      elsif (axiStatus.readEnable = '1') then
         -- Reset the bus
         v.axiReadSlave.rdata := (others => '0');
         -- Check for alignment
         if axiReadMaster.araddr(1 downto 0) = "00" then
            -- Set the EVR RAM select mask         
            Set4bitMask(v.config.eventRamCs(0), axiReadMaster.araddr, "100");
            Set4bitMask(v.config.eventRamCs(1), axiReadMaster.araddr, "101");
            -- Update external data/address buses
            v.config.eventRamAddr := axiReadMaster.araddr(11 downto 4);
            v.config.dbRdAddr     := axiReadMaster.araddr(10 downto 2);
            -- Address is aligned
            axiReadResp           := AXI_RESP_OK_C;
            -- Decode the read address
            case rdPntr is
               when 0 =>
                  v.axiReadSlave.rdata := r.statusReg;
               when 1 =>
                  v.axiReadSlave.rdata := r.controlReg;
               when 2 =>
                  v.axiReadSlave.rdata(31)          := '0';
                  v.axiReadSlave.rdata(30 downto 0) := status.intFlag(30 downto 0);
               when 3 =>
                  v.axiReadSlave.rdata := r.config.intControl;
               when 4 =>
                  v.axiReadSlave.rdata := r.hardwareInt;
               when 5 =>
                  v.axiReadSlave.rdata(31 downto 2) := r.pcieIntEna(31 downto 2);
                  v.axiReadSlave.rdata(1)           := irqActive;
                  v.axiReadSlave.rdata(0)           := r.pcieIntEna(0);
               when 8 =>
                  v.axiReadSlave.rdata(15)          := status.dbrx;
                  v.axiReadSlave.rdata(14)          := status.dbrdy;
                  v.axiReadSlave.rdata(13)          := status.dbcs;
                  v.axiReadSlave.rdata(12)          := r.config.dben;
                  v.axiReadSlave.rdata(11 downto 0) := status.rxSize(11 downto 0);
               when 11 =>
                  v.axiReadSlave.rdata := fwVersion;
               when 12 =>
                  v.axiReadSlave.rdata(7 downto 0)   := FPGA_VERSION_C(31 downto 24);
                  v.axiReadSlave.rdata(15 downto 8)  := FPGA_VERSION_C(23 downto 16);
                  v.axiReadSlave.rdata(23 downto 16) := FPGA_VERSION_C(15 downto 8);
                  v.axiReadSlave.rdata(31 downto 24) := FPGA_VERSION_C(7 downto 0);
               when 19 =>
                  v.axiReadSlave.rdata := r.config.uSecDivider;
               when 23 =>
                  v.axiReadSlave.rdata := r.secondsShift;
               when 24 =>
                  v.axiReadSlave.rdata := r.seconds;
               when 28 =>
                  v.axiReadSlave.rdata := status.tsFifoTsLow;
               when 29 =>
                  v.axiReadSlave.rdata := status.tsFifoTsHigh;
               when 30 =>
                  v.config.tsFifoRdEna             := '1';
                  v.axiReadSlave.rdata(7 downto 0) := status.tsFifoEventCode;
               when 40 =>
                  v.axiReadSlave.rdata(0) := r.config.intEventEn;
               when 41 =>
                  v.axiReadSlave.rdata := r.config.intEventCount;
               when 42 =>
                  v.axiReadSlave.rdata(7 downto 0) := r.config.intEventCode;
               when 43 =>
                  v.axiReadSlave.rdata(0) := r.config.extEventEn;
               when 44 =>
                  v.axiReadSlave.rdata(7 downto 0) := r.config.extEventCode;
               when 128 =>
                  v.axiReadSlave.rdata := r.config.pulseControl(0);
               when 129 =>
                  v.axiReadSlave.rdata := r.config.pulsePrescale(0);
               when 130 =>
                  v.axiReadSlave.rdata := r.config.pulseDelay(0);
               when 131 =>
                  v.axiReadSlave.rdata := r.config.pulseWidth(0);
               when 132 =>
                  v.axiReadSlave.rdata := r.config.pulseControl(1);
               when 133 =>
                  v.axiReadSlave.rdata := r.config.pulsePrescale(1);
               when 134 =>
                  v.axiReadSlave.rdata := r.config.pulseDelay(1);
               when 135 =>
                  v.axiReadSlave.rdata := r.config.pulseWidth(1);
               when 136 =>
                  v.axiReadSlave.rdata := r.config.pulseControl(2);
               when 137 =>
                  v.axiReadSlave.rdata := r.config.pulsePrescale(2);
               when 138 =>
                  v.axiReadSlave.rdata := r.config.pulseDelay(2);
               when 139 =>
                  v.axiReadSlave.rdata := r.config.pulseWidth(2);
               when 140 =>
                  v.axiReadSlave.rdata := r.config.pulseControl(3);
               when 141 =>
                  v.axiReadSlave.rdata := r.config.pulsePrescale(3);
               when 142 =>
                  v.axiReadSlave.rdata := r.config.pulseDelay(3);
               when 143 =>
                  v.axiReadSlave.rdata := r.config.pulseWidth(3);
               when 144 =>
                  v.axiReadSlave.rdata := r.config.pulseControl(4);
               when 145 =>
                  v.axiReadSlave.rdata := r.config.pulsePrescale(4);
               when 146 =>
                  v.axiReadSlave.rdata := r.config.pulseDelay(4);
               when 147 =>
                  v.axiReadSlave.rdata := r.config.pulseWidth(4);
               when 148 =>
                  v.axiReadSlave.rdata := r.config.pulseControl(5);
               when 149 =>
                  v.axiReadSlave.rdata := r.config.pulsePrescale(5);
               when 150 =>
                  v.axiReadSlave.rdata := r.config.pulseDelay(5);
               when 151 =>
                  v.axiReadSlave.rdata := r.config.pulseWidth(5);
               when 152 =>
                  v.axiReadSlave.rdata := r.config.pulseControl(6);
               when 153 =>
                  v.axiReadSlave.rdata := r.config.pulsePrescale(6);
               when 154 =>
                  v.axiReadSlave.rdata := r.config.pulseDelay(6);
               when 155 =>
                  v.axiReadSlave.rdata := r.config.pulseWidth(6);
               when 156 =>
                  v.axiReadSlave.rdata := r.config.pulseControl(7);
               when 157 =>
                  v.axiReadSlave.rdata := r.config.pulsePrescale(7);
               when 158 =>
                  v.axiReadSlave.rdata := r.config.pulseDelay(7);
               when 159 =>
                  v.axiReadSlave.rdata := r.config.pulseWidth(7);
               when 160 =>
                  v.axiReadSlave.rdata := r.config.pulseControl(8);
               when 161 =>
                  v.axiReadSlave.rdata := r.config.pulsePrescale(8);
               when 162 =>
                  v.axiReadSlave.rdata := r.config.pulseDelay(8);
               when 163 =>
                  v.axiReadSlave.rdata := r.config.pulseWidth(8);
               when 164 =>
                  v.axiReadSlave.rdata := r.config.pulseControl(9);
               when 165 =>
                  v.axiReadSlave.rdata := r.config.pulsePrescale(9);
               when 166 =>
                  v.axiReadSlave.rdata := r.config.pulseDelay(9);
               when 167 =>
                  v.axiReadSlave.rdata := r.config.pulseWidth(9);
               when 168 =>
                  v.axiReadSlave.rdata := r.config.pulseControl(10);
               when 169 =>
                  v.axiReadSlave.rdata := r.config.pulsePrescale(10);
               when 170 =>
                  v.axiReadSlave.rdata := r.config.pulseDelay(10);
               when 171 =>
                  v.axiReadSlave.rdata := r.config.pulseWidth(10);
               when 172 =>
                  v.axiReadSlave.rdata := r.config.pulseControl(11);
               when 173 =>
                  v.axiReadSlave.rdata := r.config.pulsePrescale(11);
               when 174 =>
                  v.axiReadSlave.rdata := r.config.pulseDelay(11);
               when 175 =>
                  v.axiReadSlave.rdata := r.config.pulseWidth(11);
               when 272 =>
                  v.axiReadSlave.rdata(31 downto 16) := r.config.outputMap(0);
                  v.axiReadSlave.rdata(15 downto 0)  := r.config.outputMap(1);
               when 273 =>
                  v.axiReadSlave.rdata(31 downto 16) := r.config.outputMap(2);
                  v.axiReadSlave.rdata(15 downto 0)  := r.config.outputMap(3);
               when 274 =>
                  v.axiReadSlave.rdata(31 downto 16) := r.config.outputMap(4);
                  v.axiReadSlave.rdata(15 downto 0)  := r.config.outputMap(5);
               when 275 =>
                  v.axiReadSlave.rdata(31 downto 16) := r.config.outputMap(6);
                  v.axiReadSlave.rdata(15 downto 0)  := r.config.outputMap(7);
               when 276 =>
                  v.axiReadSlave.rdata(31 downto 16) := r.config.outputMap(8);
                  v.axiReadSlave.rdata(15 downto 0)  := r.config.outputMap(9);
               when 277 =>
                  v.axiReadSlave.rdata(31 downto 16) := r.config.outputMap(10);
                  v.axiReadSlave.rdata(15 downto 0)  := r.config.outputMap(11);
               when 512 to 1023 =>
                  v.axiReadSlave.rdata := status.dbData;
               when 4096 to 5119 =>
                  case axiReadMaster.araddr(3 downto 2) is
                     when "11" =>
                        v.axiReadSlave.rdata := status.eventRamReset(0);
                     when "10" =>
                        v.axiReadSlave.rdata := status.eventRamSet(0);
                     when "01" =>
                        v.axiReadSlave.rdata := status.eventRamPulse(0);
                     when "00" =>
                        v.axiReadSlave.rdata := status.eventRamInt(0);
                     when others =>
                        v.axiReadSlave.rdata := (others => '0');
                  end case;
               when 5120 to 6143 =>
                  case axiReadMaster.araddr(3 downto 2) is
                     when "11" =>
                        v.axiReadSlave.rdata := status.eventRamReset(1);
                     when "10" =>
                        v.axiReadSlave.rdata := status.eventRamSet(1);
                     when "01" =>
                        v.axiReadSlave.rdata := status.eventRamPulse(1);
                     when "00" =>
                        v.axiReadSlave.rdata := status.eventRamInt(1);
                     when others =>
                        v.axiReadSlave.rdata := (others => '0');
                  end case;
               when others =>
                  v.axiReadSlave.rdata := x"DEADBEEF";
            end case;
         end if;
         -- Send AXI response
         axiSlaveReadResponse(v.axiReadSlave, axiReadResp);
      end if;

      -- Misc. Mapping and Logic
      v.config.evrEnable  := r.controlReg(31);
      v.config.mapRamPage := r.controlReg(8);
      v.config.irqClr     := r.irqClr1 or r.irqClr2;
      v.config.dbena      := uOr(r.dbena);
      v.config.dbdis      := uOr(r.dbdis(3 downto 1)) and not(r.config.dbena);

      -- Synchronous Reset
      if axiRst = '1' then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      axiReadSlave  <= r.axiReadSlave;
      axiWriteSlave <= r.axiWriteSlave;
      config        <= r.config;
      irqEnable     <= r.pcieIntEna(0);
      irqReq        <= (r.config.intControl(31) and status.intFlag(0) and r.config.intControl(0))  -- rxLos
                       or (r.config.intControl(31) and status.intFlag(1) and r.config.intControl(1))  -- TsFifoFull
                       or (r.config.intControl(31) and status.intFlag(2) and r.config.intControl(2))  -- heartBeatTimeOut
                       or (r.config.intControl(31) and status.intFlag(3) and r.config.intControl(3))  -- event
                       or (r.config.intControl(31) and status.intFlag(5) and r.config.intControl(5));  -- databuff   
   end process comb;

   seq : process (axiClk) is
   begin
      if rising_edge(axiClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
