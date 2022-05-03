-------------------------------------------------------------------------------
-- Title      : CoaXPress Protocol: http://jiia.org/wp-content/themes/jiia/pdf/standard_dl/coaxpress/CXP-001-2021.pdf
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: CoaXPress TX FSM
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
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;
use surf.CoaXPressPkg.all;
use surf.Code8b10bPkg.all;

entity CoaXPressTxFsm is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Clock and Reset
      txClk      : in  sl;
      txRst      : in  sl;
      -- Config Interface
      cfgMaster  : in  AxiStreamMasterType;
      cfgSlave   : out AxiStreamSlaveType;
      -- Trigger Interface
      txTrig     : in  sl;
      txTrigDrop : out sl;
      -- TX PHY Interface
      txStrobe   : out sl;
      txData     : out slv(7 downto 0);
      txDataK    : out sl);
end entity CoaXPressTxFsm;

architecture rtl of CoaXPressTxFsm is

   constant CXP_TRIG_K_C : slv(5 downto 0) := "000111";
   constant CXP_TX_IDLE_C : Slv8Array(3 downto 0) := (
      0 => CXP_IDLE_C(7 downto 0),
      1 => CXP_IDLE_C(15 downto 8),
      2 => CXP_IDLE_C(23 downto 16),
      3 => CXP_IDLE_C(31 downto 24));

   constant TX_DLY_C : Slv8Array(9 downto 0) := (
      0 => toSlv(0*24, 8),
      1 => toSlv(1*24, 8),
      2 => toSlv(2*24, 8),
      3 => toSlv(3*24, 8),
      4 => toSlv(4*24, 8),
      5 => toSlv(5*24, 8),
      6 => toSlv(6*24, 8),
      7 => toSlv(7*24, 8),
      8 => toSlv(8*24, 8),
      9 => toSlv(9*24, 8));

   type StateType is (
      SOF_S,
      PAYLOAD_S,
      EOF_S);

   type RegType is record
      -- Heartbeat
      heartbeat    : sl;
      heartbeatCnt : natural range 0 to 9;
      -- Trigger
      txTrig       : sl;
      txTrigDrop   : sl;
      txTrigCnt    : natural range 0 to 6;
      txTrigData   : Slv8Array(5 downto 0);
      -- IDLE
      txIdle       : sl;
      txIdleCnt    : natural range 0 to 4;
      -- TX PHY
      txStrobe     : sl;
      txData       : slv(7 downto 0);
      txDataK      : sl;
      -- Config
      cfgSlave     : AxiStreamSlaveType;
      stateCnt     : slv(1 downto 0);
      state        : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      -- Heartbeat
      heartbeat    => '0',
      heartbeatCnt => 9,
      -- Trigger
      txTrig       => '0',
      txTrigDrop   => '0',
      txTrigCnt    => 6,
      txTrigData   => (0 => K_28_2_C, 1 => K_28_4_C, 2 => K_28_4_C, 3 to 5 => x"00"),
      -- IDLE
      txIdle       => '1',
      txIdleCnt    => 4,
      -- TX PHY
      txStrobe     => '0',
      txData       => K_28_5_C,
      txDataK      => '1',
      -- Config
      cfgSlave     => AXI_STREAM_SLAVE_INIT_C,
      stateCnt     => "00",
      state        => SOF_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (cfgMaster, r, txRst, txTrig) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobes
      v.heartbeat  := '0';
      v.txStrobe   := '0';
      v.txTrigDrop := '0';
      v.cfgSlave   := AXI_STREAM_SLAVE_INIT_C;

      -- Check for heartbeat event
      if (r.heartbeatCnt = 0) then

         -- Pre-set the counter
         v.heartbeatCnt := 9;

         -- Set the flag
         v.heartbeat := '1';

      else
         -- Decrement the counter
         v.heartbeatCnt := r.heartbeatCnt - 1;
      end if;

      -- Keep a delayed copy
      v.txTrig := txTrig;

      -- Check for trigger rising edge
      if (r.txTrig = '0') and (v.txTrig = '1') then

         -- Check if not moving trigger message
         if (r.txTrigCnt = 6) then

            -- Reset the counter
            v.txTrigCnt := 0;

            -- Set the trigger delay
            for i in 3 to 5 loop
               v.txTrigData(i) := TX_DLY_C(9-v.heartbeatCnt);
            end loop;

         else
            -- Set the flag
            v.txTrigDrop := '1';
         end if;

      end if;

      -- Check for heartbeat
      if (r.heartbeat = '1') then

         -- Update the strobe
         v.txStrobe := '1';

         -- Check if moving trigger message
         if (r.txTrigCnt /= 6) then

            -- Increment the counter
            v.txTrigCnt := r.txTrigCnt + 1;

            -- Update the TX data
            v.txData  := r.txTrigData(r.txTrigCnt);
            v.txDataK := CXP_TRIG_K_C(r.txTrigCnt);

         -- Check if moving idle message
         elsif (r.txIdleCnt /= 4) then

            -- Increment the counter
            v.txIdleCnt := r.txIdleCnt + 1;

            -- Update the TX data
            v.txData  := CXP_TX_IDLE_C(r.txIdleCnt);
            v.txDataK := CXP_IDLE_K_C(r.txIdleCnt);

         -- Check if moving config message
         elsif (cfgMaster.tValid = '1') and (r.txIdle = '0') then

            -- State Machine
            case (r.state) is
               ----------------------------------------------------------------------
               when SOF_S =>
                  -- Update the TX data
                  v.txData  := K_27_7_C;
                  v.txDataK := '1';

                  -- Increment the counter
                  v.stateCnt := r.stateCnt + 1;

                  -- Increment the counter
                  if (r.stateCnt = 3) then
                     -- Next state
                     v.state := PAYLOAD_S;
                  end if;
               ----------------------------------------------------------------------
               when PAYLOAD_S =>
                  -- Accept the data
                  v.cfgSlave.tReady := '1';

                  -- Update the TX data
                  v.txData  := cfgMaster.tData(7 downto 0);
                  v.txDataK := '0';

                  -- Check for last byte
                  if (cfgMaster.tLast = '1') then
                     -- Next state
                     v.state := EOF_S;
                  end if;
               ----------------------------------------------------------------------
               when EOF_S =>
                  -- Update the TX data
                  v.txData  := K_29_7_C;
                  v.txDataK := '1';

                  -- Increment the counter
                  v.stateCnt := r.stateCnt + 1;

                  -- Increment the counter
                  if (r.stateCnt = 3) then

                     -- Set the flag
                     v.txIdle := '1';

                     -- Next state
                     v.state := SOF_S;

                  end if;
            ----------------------------------------------------------------------
            end case;

         -- Insert the IDLE
         else

            -- Reset flag
            v.txIdle := '0';

            -- Preset the counter
            v.txIdleCnt := 1;

            -- Update the TX data
            v.txData  := CXP_TX_IDLE_C(0);
            v.txDataK := CXP_IDLE_K_C(0);

         end if;

      end if;

      -- Outputs
      cfgSlave   <= v.cfgSlave;
      txStrobe   <= r.txStrobe;
      txData     <= r.txData;
      txDataK    <= r.txDataK;
      txTrigDrop <= r.txTrigDrop;

      -- Reset
      if (txRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (txClk) is
   begin
      if (rising_edge(txClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
