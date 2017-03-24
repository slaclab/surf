-------------------------------------------------------------------------------
-- File       : AxiDac7654Reg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-09-24
-- Last update: 2014-09-25
-------------------------------------------------------------------------------
-- Description: AXI-Lite Register Access Module
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
use work.AxiDac7654Pkg.all;

entity AxiDac7654Reg is
   generic (
      TPD_G              : time                  := 1 ns;
      STATUS_CNT_WIDTH_G : natural range 1 to 32 := 32;
      AXI_ERROR_RESP_G   : slv(1 downto 0)       := AXI_RESP_SLVERR_C);  
   port (
      -- AXI-Lite Register Interface (axiClk domain)
      axiClk         : in  sl;
      axiRst         : in  sl;
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;
      -- Register Inputs/Outputs (axiClk domain)
      status         : in  AxiDac7654StatusType;
      config         : out AxiDac7654ConfigType);      
end AxiDac7654Reg;

architecture rtl of AxiDac7654Reg is
   
   type StateType is (
      IDLE_S,
      REQ_S,
      ACK_S);    

   type RegType is record
      config        : AxiDac7654ConfigType;
      state         : StateType;
      axiReadSlave  : AxiLiteReadSlaveType;
      axiWriteSlave : AxiLiteWriteSlaveType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      AXI_DAC7654_CONFIG_INIT_C,
      IDLE_S,
      AXI_LITE_READ_SLAVE_INIT_C,
      AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal syncIn : AxiDac7654StatusType := AXI_DAC7654_STATUS_INIT_C;

begin

   -------------------------------
   -- Configuration Register
   -------------------------------  
   comb : process (axiReadMaster, axiRst, axiWriteMaster, r, syncIn) is
      variable v            : RegType;
      variable axiStatus    : AxiLiteStatusType;
      variable axiWriteResp : slv(1 downto 0);
      variable axiReadResp  : slv(1 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Determine the transaction type
      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);

      if (axiStatus.writeEnable = '1') and (r.state = IDLE_S) then
         -- Check for an out of 32 bit aligned address
         axiWriteResp := ite(axiWriteMaster.awaddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_ERROR_RESP_G);
         -- Decode address and perform write
         case (axiWriteMaster.awaddr(9 downto 2)) is
            when x"80" =>
               if axiWriteMaster.wdata(15 downto 0) /= r.config.spi.data(0) then
                  v.config.spi.data(0) := axiWriteMaster.wdata(15 downto 0);
                  v.state              := REQ_S;
               end if;
            when x"81" =>
               if axiWriteMaster.wdata(15 downto 0) /= r.config.spi.data(1) then
                  v.config.spi.data(1) := axiWriteMaster.wdata(15 downto 0);
                  v.state              := REQ_S;
               end if;
            when x"82" =>
               if axiWriteMaster.wdata(15 downto 0) /= r.config.spi.data(2) then
                  v.config.spi.data(2) := axiWriteMaster.wdata(15 downto 0);
                  v.state              := REQ_S;
               end if;
            when x"83" =>
               if axiWriteMaster.wdata(15 downto 0) /= r.config.spi.data(3) then
                  v.config.spi.data(3) := axiWriteMaster.wdata(15 downto 0);
                  v.state              := REQ_S;
               end if;
            when others =>
               axiWriteResp := AXI_ERROR_RESP_G;
         end case;
         -- Send AXI response
         axiSlaveWriteResponse(v.axiWriteSlave, axiWriteResp);
      elsif (axiStatus.readEnable = '1') and (r.state = IDLE_S) then
         -- Check for an out of 32 bit aligned address
         axiReadResp          := ite(axiReadMaster.araddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_ERROR_RESP_G);
         -- Reset the register
         v.axiReadSlave.rdata := (others => '0');
         -- Decode address and assign read data
         case (axiReadMaster.araddr(9 downto 2)) is
            when x"80" =>
               v.axiReadSlave.rdata(15 downto 0) := r.config.spi.data(0);
            when x"81" =>
               v.axiReadSlave.rdata(15 downto 0) := r.config.spi.data(1);
            when x"82" =>
               v.axiReadSlave.rdata(15 downto 0) := r.config.spi.data(2);
            when x"83" =>
               v.axiReadSlave.rdata(15 downto 0) := r.config.spi.data(3);
            when others =>
               axiReadResp := AXI_ERROR_RESP_G;
         end case;
         -- Send AXI Response
         axiSlaveReadResponse(v.axiReadSlave, axiReadResp);
      end if;

      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when IDLE_S =>
            null;
         ----------------------------------------------------------------------
         when REQ_S =>
            -- Assert the flag
            v.config.spi.req := '1';
            -- Next State
            v.state          := ACK_S;
         ----------------------------------------------------------------------
         when ACK_S =>
            -- De-assert the flag
            v.config.spi.req := '0';
            -- Check for ACK strobe
            if syncIn.spi.ack = '1' then
               -- Next State
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
   config.spi <= r.config.spi;

   -------------------------------
   -- Synchronization: Inputs
   -------------------------------
   syncIn.spi <= status.spi;

end rtl;
