-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: AXI-Lite Slave module controlled via REQ/ACK interface
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

entity AxiLiteSlave is
   generic (
      TPD_G       : time    := 1 ns;
      RST_ASYNC_G : boolean := false);
   port (
      axilClk         : in  sl;
      axilRst         : in  sl;
      req             : out AxiLiteReqType;
      ack             : in  AxiLiteAckType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType);
end entity AxiLiteSlave;

architecture rtl of AxiLiteSlave is

   type StateType is (
      IDLE_S,
      ACK_S);

   type RegType is record
      toggle         : sl;
      req            : AxiLiteReqType;
      axilWriteSlave : AxiLiteWriteSlaveType;
      axilReadSlave  : AxiLiteReadSlaveType;
      state          : StateType;
   end record;

   constant REG_INIT_C : RegType := (
      toggle         => '0',
      req            => AXI_LITE_REQ_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      state          => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (ack, axilReadMaster, axilRst, axilWriteMaster, r) is
      variable v         : RegType;
      variable axiStatus : AxiLiteStatusType;
      variable axiResp   : slv(1 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Determine the transaction type
      axiSlaveWaitTxn(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axiStatus);

      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check if done deasserted
            if (ack.done = '0') then
               -- Toggle the transaction select (prevent locking up in read or write direction)
               v.toggle := not(r.toggle);
               -- Check for a write request
               if (axiStatus.writeEnable = '1') and (r.toggle = '0') then
                  -- Start the write request
                  v.req.request := '1';
                  v.req.rnw     := '0';
                  v.req.address := axilWriteMaster.awaddr;
                  v.req.wrData  := axilWriteMaster.wdata;
                  -- Next state
                  v.state       := ACK_S;
               -- Check for a read request
               elsif (axiStatus.readEnable = '1') and (r.toggle = '1') then
                  -- Start the read request
                  v.req.request := '1';
                  v.req.rnw     := '1';
                  v.req.address := axilReadMaster.araddr;
                  -- Next state
                  v.state       := ACK_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when ACK_S =>
            -- Check for the acknowledgment
            if (ack.done = '1') then
               -- Reset the flag
               v.req.request := '0';
               -- Check for bus errors
               if (ack.resp = 0) then
                  -- Return good transaction
                  axiResp := AXI_RESP_OK_C;
               else
                  -- Return bad transaction
                  axiResp := AXI_RESP_SLVERR_C;
               end if;
               -- Check for a write request
               if (r.req.rnw = '0') then
                  -- Send AXI-Lite response
                  axiSlaveWriteResponse(v.axilWriteSlave, axiResp);
               -- Check for a read request
               elsif (axiStatus.readEnable = '1') then
                  -- Set the read bus
                  v.axilReadSlave.rdata := ack.rdData;
                  -- Send AXI-Lite Response
                  axiSlaveReadResponse(v.axilReadSlave, axiResp);
               end if;
               -- Next state
               v.state := IDLE_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Outputs
      axilReadSlave  <= r.axilReadSlave;
      axilWriteSlave <= r.axilWriteSlave;
      req            <= r.req;

      -- Synchronous Reset
      if (RST_ASYNC_G = false and axilRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (axilClk, axilRst) is
   begin
      if (RST_ASYNC_G and axilRst = '1') then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(axilClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
