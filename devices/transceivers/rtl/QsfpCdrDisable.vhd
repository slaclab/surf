-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Used to periodically write CDR disable to the QSFP modules via AXI-Lite crossbar
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

entity QsfpCdrDisable is
   generic (
      TPD_G             : time     := 1 ns;
      SIMULATION_G      : boolean;
      PERIODIC_UPDATE_G : positive := 30;  -- Units of seconds
      QSFP_BASE_ADDR_G  : Slv32Array;  -- List of the QSFP base address offsets
      AXIL_CLK_FREQ_G   : real);        -- Units of Hz
   port (
      -- AXI-Lite Register Interface (axilClk domain)
      axilClk          : in  sl;
      axilRst          : in  sl;
      mAxilReadMaster  : out AxiLiteReadMasterType;
      mAxilReadSlave   : in  AxiLiteReadSlaveType;
      mAxilWriteMaster : out AxiLiteWriteMasterType;
      mAxilWriteSlave  : in  AxiLiteWriteSlaveType);
end QsfpCdrDisable;

architecture rtl of QsfpCdrDisable is

   constant TIMEOUT_1SEC_C : positive := ite(SIMULATION_G, 100, getTimeRatio(AXIL_CLK_FREQ_G, 1.0));

   constant NUM_CH_G : positive := QSFP_BASE_ADDR_G'length;

   type StateType is (
      IDLE_S,
      REQ_S,
      ACK_S);

   type RegType is record
      ch    : natural range 0 to NUM_CH_G-1;
      cnt   : natural range 0 to PERIODIC_UPDATE_G-1;
      timer : natural range 0 to TIMEOUT_1SEC_C;
      req   : AxiLiteReqType;
      state : StateType;
   end record;

   constant REG_INIT_C : RegType := (
      ch    => 0,
      cnt   => 0,
      timer => 0,
      req   => AXI_LITE_REQ_INIT_C,
      state => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal ack : AxiLiteAckType;

begin

   U_AxiLiteMaster : entity surf.AxiLiteMaster
      generic map (
         TPD_G => TPD_G)
      port map (
         req             => r.req,
         ack             => ack,
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilWriteMaster => mAxilWriteMaster,
         axilWriteSlave  => mAxilWriteSlave,
         axilReadMaster  => mAxilReadMaster,
         axilReadSlave   => mAxilReadSlave);

   ---------------------
   -- AXI Lite Interface
   ---------------------
   comb : process (ack, axilRst, r) is
      variable v      : RegType;
      variable regCon : AxiLiteEndPointType;
   begin
      -- Latch the current value
      v := r;

      -- Decrement the timer
      if (r.timer /= 0) then
         v.timer := r.timer -1;
      end if;

      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check for timeout
            if (r.timer = 0) then

               -- Re-arm the timer
               v.timer := TIMEOUT_1SEC_C;

               -- Check for timeout
               if (r.cnt = 0) then

                  -- Re-arm the counter
                  v.cnt := PERIODIC_UPDATE_G - 1;

                  -- Next state
                  v.state := REQ_S;

               else
                  -- Decrement the counter
                  v.cnt := r.cnt - 1;
               end if;

            end if;
         ----------------------------------------------------------------------
         when REQ_S =>
            -- Check if ready for next transaction
            if (ack.done = '0') then

               -- Setup the AXI-Lite Master request
               v.req.request := '1';
               v.req.rnw     := '0';    -- Write operation
               v.req.address := QSFP_BASE_ADDR_G(r.ch) + x"0000_0188";  -- 0x188 = 98 x 4 (Page 00h, byte 98: Tx and Rx CDR control bits)
               v.req.wrData  := x"0000_0000";  -- Turn off all the TX and RX CDR channels

               -- Next state
               v.state := ACK_S;

            end if;
         ----------------------------------------------------------------------
         when ACK_S =>
            -- Wait for DONE to set
            if (ack.done = '1') then

               -- Reset the flag
               v.req.request := '0';

               -- Check if this was last channel
               if (r.ch = NUM_CH_G-1) then

                  -- Reset the index
                  v.ch := 0;

                  -- Next state
                  v.state := IDLE_S;

               else

                  -- Increment the channel
                  v.ch := r.ch + 1;

                  -- Next state
                  v.state := REQ_S;

               end if;

            end if;
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (axilRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
