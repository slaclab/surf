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

entity LeapXcvrCdrDisable is
   generic (
      TPD_G             : time     := 1 ns;
      PERIODIC_UPDATE_G : positive := 30;  -- Units of seconds
      LEAP_BASE_ADDR_G  : Slv32Array;  -- List of the LEAP base address offsets
      AXIL_CLK_FREQ_G   : real);        -- Units of Hz
   port (
      -- AXI-Lite Register Interface (axilClk domain)
      axilClk          : in  sl;
      axilRst          : in  sl;
      mAxilReadMaster  : out AxiLiteReadMasterType;
      mAxilReadSlave   : in  AxiLiteReadSlaveType;
      mAxilWriteMaster : out AxiLiteWriteMasterType;
      mAxilWriteSlave  : in  AxiLiteWriteSlaveType);
end LeapXcvrCdrDisable;

architecture rtl of LeapXcvrCdrDisable is

   constant TIMEOUT_1SEC_C : natural := getTimeRatio(AXIL_CLK_FREQ_G, 1.0);

   constant NUM_CH_G   : natural := LEAP_BASE_ADDR_G'length;
   constant NUM_WORD_G : natural := 6;

   type StateType is (
      IDLE_S,
      REQ_S,
      ACK_S);

   type RegType is record
      wrd   : natural range 0 to NUM_WORD_G-1;
      ch    : natural range 0 to NUM_CH_G-1;
      cnt   : natural range 0 to PERIODIC_UPDATE_G-1;
      timer : natural range 0 to TIMEOUT_1SEC_C-1;
      req   : AxiLiteReqType;
      state : StateType;
   end record;

   constant REG_INIT_C : RegType := (
      wrd   => 0,
      ch    => 0,
      cnt   => PERIODIC_UPDATE_G-1,
      timer => TIMEOUT_1SEC_C-1,
      req   => AXI_LITE_REQ_INIT_C,
      state => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal ack : AxiLiteAckType;

   -- attribute dont_touch        : string;
   -- attribute dont_touch of r   : signal is "TRUE";
   -- attribute dont_touch of ack : signal is "TRUE";

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
      variable v : RegType;
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
               v.timer := TIMEOUT_1SEC_C - 1;

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

               -- Check the word index
               case (r.wrd) is
                  --------------------------------
                  -- Disabling the RX CDR Channels
                  --------------------------------
                  when 0 =>
                     v.req.address := LEAP_BASE_ADDR_G(r.ch) + x"0000_00AC";  -- RxLower.GlobalRxCdr=0x0AC
                     v.req.wrData  := x"0000_0001";  -- Globally turn off all RX CDR channels
                  when 1 =>
                     v.req.address := LEAP_BASE_ADDR_G(r.ch) + x"0000_00D8";  -- RxLower.RxCdrBypassMsb=0x0D8
                     v.req.wrData  := x"0000_000F";  -- Bypass RX CDR channels [11:8]
                  when 2 =>
                     v.req.address := LEAP_BASE_ADDR_G(r.ch) + x"0000_00DC";  -- RxLower.RxChDisableLsb=0x0DC
                     v.req.wrData  := x"0000_00FF";  -- Bypass RX CDR channels [7:0]
                  --------------------------------
                  -- Disabling the TX CDR Channels
                  --------------------------------
                  when 3 =>
                     v.req.address := LEAP_BASE_ADDR_G(r.ch) + x"0000_08AC";  -- TxLower.GlobalTxCdr=0x8AC
                     v.req.wrData  := x"0000_0001";  -- Globally turn off all TX CDR channels
                  when 4 =>
                     v.req.address := LEAP_BASE_ADDR_G(r.ch) + x"0000_08D8";  -- TxLower.TxCdrBypassMsb=0x0D8
                     v.req.wrData  := x"0000_000F";  -- Bypass TX CDR channels [11:8]
                  when 5 =>
                     v.req.address := LEAP_BASE_ADDR_G(r.ch) + x"0000_08DC";  -- TxLower.TxChDisableLsb=0x0DC
                     v.req.wrData  := x"0000_00FF";  -- Bypass TX CDR channels [7:0]
               end case;

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

                  -- Check the word index
                  if (r.wrd /= NUM_WORD_G-1) then

                     -- Increment the channel
                     v.wrd := r.wrd + 1;

                     -- Next state
                     v.state := REQ_S;

                  else

                     -- Reset the index
                     v.wrd := 0;

                     -- Next state
                     v.state := IDLE_S;

                  end if;

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
