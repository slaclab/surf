-------------------------------------------------------------------------------
-- File       : AxiXcf128Reg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-18
-- Last update: 2015-01-13
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
use work.AxiXcf128Pkg.all;

entity AxiXcf128Reg is
   generic (
      TPD_G            : time            := 1 ns;
      AXI_CLK_FREQ_G   : real            := 200.0E+6;  -- units of Hz      
      AXI_ERROR_RESP_G : slv(1 downto 0) := AXI_RESP_SLVERR_C);
   port (
      -- AXI-Lite Register Interface
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;
      -- Register Inputs/Outputs
      status         : in  AxiXcf128StatusType;
      config         : out AxiXcf128ConfigType;
      -- Global Signals
      axiClk         : in  sl;
      axiRst         : in  sl);      
end AxiXcf128Reg;

architecture rtl of AxiXcf128Reg is

   constant MAX_CNT_C : natural := (getTimeRatio(AXI_CLK_FREQ_G, 10.0E+6))-1;

   type stateType is (
      IDLE_S,
      CMD_LOW_S,
      CMD_HIGH_S,
      WAIT_S,
      DATA_LOW_S,
      DATA_HIGH_S);

   type RegType is record
      dataReg       : slv(15 downto 0);
      wrData        : Slv16Array(0 to 1);
      RnW           : sl;
      cnt           : natural range 0 to MAX_CNT_C;
      config        : AxiXcf128ConfigType;
      state         : StateType;
      axiReadSlave  : AxiLiteReadSlaveType;
      axiWriteSlave : AxiLiteWriteSlaveType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      (others => '0'),
      (others => (others => '0')),
      '0',
      0,
      AXI_XCF128_CONFIG_INIT_C,
      IDLE_S,
      AXI_LITE_READ_SLAVE_INIT_C,
      AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   -------------------------------
   -- Configuration Register
   -------------------------------  
   comb : process (axiReadMaster, axiRst, axiWriteMaster, r, status) is
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
      -- *** place holder ***

      if (axiStatus.writeEnable = '1') and (r.state = IDLE_S) then
         -- Check for an out of 32 bit aligned address
         if axiWriteMaster.awaddr(1 downto 0) /= "00" then
            -- Send AXI response
            axiSlaveWriteResponse(v.axiWriteSlave, AXI_ERROR_RESP_G);
         else
            -- Check the write address
            if axiWriteMaster.awaddr(3 downto 2) = 0 then
               -- Set the write data bus
               v.wrData(1) := axiWriteMaster.wdata(31 downto 16);
               v.wrData(0) := axiWriteMaster.wdata(15 downto 0);
               -- Send AXI response
               axiSlaveWriteResponse(v.axiWriteSlave);
            elsif axiWriteMaster.awaddr(3 downto 2) = 1 then
               -- Set the RnW
               v.RnW         := axiWriteMaster.wdata(31);
               -- Set the address bus
               v.config.addr := axiWriteMaster.wdata(22 downto 0);
               -- Next state
               v.state       := CMD_LOW_S;
            else
               -- Send AXI response
               axiSlaveWriteResponse(v.axiWriteSlave, AXI_ERROR_RESP_G);
            end if;
         end if;
      elsif (axiStatus.readEnable = '1') and (r.state = IDLE_S) then
         -- Check for an out of 32 bit aligned address
         axiReadResp          := ite(axiReadMaster.araddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_ERROR_RESP_G);
         -- Reset the register
         v.axiReadSlave.rdata := (others => '0');
         -- Check the read address
         if axiReadMaster.araddr(3 downto 2) = 0 then
            -- Get the write data bus
            v.axiReadSlave.rdata(15 downto 0) := r.config.data;
         elsif axiReadMaster.araddr(3 downto 2) = 1 then
            -- Get the address bus
            v.axiReadSlave.rdata(22 downto 0) := r.config.addr;
         elsif axiReadMaster.araddr(3 downto 2) = 2 then
            -- Get the read data bus
            v.axiReadSlave.rdata(15 downto 0) := r.dataReg;
         else
            axiReadResp := AXI_ERROR_RESP_G;
         end if;
         -- Send AXI Response
         axiSlaveReadResponse(v.axiReadSlave, axiReadResp);
      end if;

      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when IDLE_S =>
            v.config.ceL      := '1';
            v.config.oeL      := '1';
            v.config.weL      := '1';
            v.config.tristate := '1';
         ----------------------------------------------------------------------
         when CMD_LOW_S =>
            v.config.ceL      := '0';
            v.config.oeL      := '1';
            v.config.weL      := '0';
            v.config.tristate := '0';
            v.config.data     := r.wrData(1);
            -- Increment the counter
            v.cnt             := r.cnt + 1;
            -- Check the counter 
            if r.cnt = MAX_CNT_C then
               -- Reset the counter
               v.cnt   := 0;
               -- Next state
               v.state := CMD_HIGH_S;
            end if;
         ----------------------------------------------------------------------
         when CMD_HIGH_S =>
            v.config.ceL      := '1';
            v.config.oeL      := '1';
            v.config.weL      := '1';
            v.config.tristate := '0';
            v.config.data     := r.wrData(1);
            -- Increment the counter
            v.cnt             := r.cnt + 1;
            -- Check the counter 
            if r.cnt = MAX_CNT_C then
               -- Reset the counter
               v.cnt   := 0;
               -- Next state
               v.state := WAIT_S;
            end if;
         ----------------------------------------------------------------------
         when WAIT_S =>
            v.config.ceL      := '1';
            v.config.oeL      := '1';
            v.config.weL      := '1';
            v.config.tristate := '1';
            v.config.data     := r.wrData(0);
            -- Increment the counter
            v.cnt             := r.cnt + 1;
            -- Check the counter 
            if r.cnt = MAX_CNT_C then
               -- Reset the counter
               v.cnt   := 0;
               -- Next state
               v.state := DATA_LOW_S;
            end if;
         ----------------------------------------------------------------------
         when DATA_LOW_S =>
            v.config.ceL      := '0';
            v.config.oeL      := not(r.RnW);
            v.config.weL      := r.RnW;
            v.config.tristate := r.RnW;
            v.config.data     := r.wrData(0);
            -- Increment the counter
            v.cnt             := r.cnt + 1;
            -- Check the counter 
            if r.cnt = MAX_CNT_C then
               -- Reset the counter
               v.cnt     := 0;
               -- Latch the data bus value
               v.dataReg := status.data;
               -- Next state
               v.state   := DATA_HIGH_S;
            end if;
         ----------------------------------------------------------------------
         when DATA_HIGH_S =>
            v.config.ceL      := '1';
            v.config.oeL      := '1';
            v.config.weL      := '1';
            v.config.tristate := r.RnW;
            v.config.data     := r.wrData(0);
            -- Increment the counter
            v.cnt             := r.cnt + 1;
            -- Check the counter 
            if r.cnt = MAX_CNT_C then
               -- Reset the counter
               v.cnt   := 0;
               -- Send AXI Response
               axiSlaveReadResponse(v.axiReadSlave);
               -- Next state
               v.state := IDLE_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Synchronous Reset
      if axiRst = '1' then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      axiReadSlave  <= r.axiReadSlave;
      axiWriteSlave <= r.axiWriteSlave;

      config <= r.config;
      
   end process comb;

   seq : process (axiClk) is
   begin
      if rising_edge(axiClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
end rtl;
