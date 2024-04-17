-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Writing to this module sets a timer for a delayed write response
--              Read transaction are not supported and will respond with error
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

entity AxiLiteRespTimer is
   generic (
      TPD_G       : time    := 1 ns;
      RST_ASYNC_G : boolean := false);
   port (
      -- Slave AXI-Lite Interface
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end AxiLiteRespTimer;

architecture rtl of AxiLiteRespTimer is

   type StateType is (
      IDLE_S,
      TIMER_S);

   type RegType is record
      timer          : slv(31 downto 0);
      axilWriteSlave : AxiLiteWriteSlaveType;
      axilReadSlave  : AxiLiteReadSlaveType;
      state          : StateType;
   end record;

   constant REG_INIT_C : RegType := (
      timer          => (others => '0'),
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      state          => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- attribute dont_touch      : string;
   -- attribute dont_touch of r : signal is "true";

begin

   comb : process (axilReadMaster, axilRst, axilWriteMaster, r) is
      variable v          : RegType;
      variable axilStatus : AxiLiteStatusType;
   begin
      -- Latch the current value
      v := r;

      ---------------------------------
      -- Determine the transaction type
      ---------------------------------
      axiSlaveWaitTxn(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus);

      -- Check for invalid read transaction (only write transactions supported)
      if (axilStatus.readEnable = '1') then
         -- Send the read response
         axiSlaveReadResponse(v.axilReadSlave, AXI_RESP_DECERR_C);
      end if;

      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check for write transaction
            if (axilStatus.writeEnable = '1') then

               -- Set the timer value
               v.timer := axilWriteMaster.wdata;

               -- Next state
               v.state := TIMER_S;

            end if;
         ----------------------------------------------------------------------
         when TIMER_S =>
            -- Check for timeout
            if (r.timer = 0) then

               -- Send the write response
               axiSlaveWriteResponse(v.axilWriteSlave, AXI_RESP_OK_C);

               -- Next state
               v.state := IDLE_S;

            else
               -- Decrement the counter
               v.timer := r.timer - 1;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (RST_ASYNC_G = false and axilRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Output assignment
      axilReadSlave  <= r.axilReadSlave;
      axilWriteSlave <= r.axilWriteSlave;

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
