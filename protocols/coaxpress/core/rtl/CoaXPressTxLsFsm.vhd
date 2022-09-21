-------------------------------------------------------------------------------
-- Title      : CoaXPress Protocol: http://jiia.org/wp-content/themes/jiia/pdf/standard_dl/coaxpress/CXP-001-2021.pdf
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: CoaXPress TX Low Speed FSM
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

entity CoaXPressTxLsFsm is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Clock and Reset
      txClk      : in  sl;              -- 312.5 MHz clock
      txRst      : in  sl;
      -- Config Interface
      cfgMaster  : in  AxiStreamMasterType;
      cfgSlave   : out AxiStreamSlaveType;
      -- Trigger Interface
      txTrig     : in  sl;
      txTrigDrop : out sl;
      -- TX PHY Interface
      txRate     : in  sl;
      txStrobe   : out sl;
      txData     : out slv(7 downto 0);
      txDataK    : out sl);
end entity CoaXPressTxLsFsm;

architecture rtl of CoaXPressTxLsFsm is

   function genTxDly return Slv8Array is
      variable retVar : Slv8Array(149 downto 0);
      variable i      : natural;
   begin
      for i in 0 to 149 loop
         retVar(i) := toSlv(getTimeRatio(i*(240.0/150.0), 1.0), 8);
      end loop;
      return retVar;
   end function;

   constant CXP_TRIG_K_C : slv(5 downto 0)         := "000111";
   constant TX_DLY_C     : Slv8Array(149 downto 0) := genTxDly;

   type RegType is record
      -- Heartbeat
      heartbeat    : sl;
      heartbeatCnt : slv(7 downto 0);
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
   end record RegType;

   constant REG_INIT_C : RegType := (
      -- Heartbeat
      heartbeat    => '0',
      heartbeatCnt => (others => '0'),
      -- Trigger
      txTrig       => '0',
      txTrigDrop   => '0',
      txTrigCnt    => 6,
      txTrigData   => (0 => K_28_2_C, 1 => K_28_4_C, 2 => K_28_4_C, 3 => x"00", 4 => x"00", 5 => x"00"),
      -- IDLE
      txIdle       => '1',
      txIdleCnt    => 4,
      -- TX PHY
      txStrobe     => '0',
      txData       => K_28_5_C,
      txDataK      => '1',
      -- Config
      cfgSlave     => AXI_STREAM_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   attribute rom_style               : string;
   attribute rom_style of TX_DLY_C   : constant is "distributed";
   attribute rom_extract             : string;
   attribute rom_extract of TX_DLY_C : constant is "TRUE";
   attribute syn_keep                : string;
   attribute syn_keep of TX_DLY_C    : constant is "TRUE";

   attribute dont_touch      : string;
   attribute dont_touch of r : signal is "TRUE";

begin

   comb : process (cfgMaster, r, txRate, txRst, txTrig) is
      variable v   : RegType;
      variable idx : natural;
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

         -- txRate=0: 20.83 Mbps (48ns UI)
         if (txRate = '0') then

            -- 149 = (10b x 312.5MHz / 20.833333Mbps)-1
            v.heartbeatCnt := toSlv(149, 8);

         else
            -- 74 = (10b x 312.5MHz / 41.666666Mbps)-1
            v.heartbeatCnt := toSlv(74, 8);

         end if;

         -- Set the flag
         v.heartbeat := '1';

      else
         -- Decrement the counter
         v.heartbeatCnt := r.heartbeatCnt - 1;
      end if;

      -- Update trig delay index variable
      if (txRate = '0') then
         idx := conv_integer(v.heartbeatCnt);
      else
         idx := 2*conv_integer(v.heartbeatCnt);
      end if;

      -- Keep a delayed copy
      v.txTrig := txTrig;

      -- Check for trigger edge
      if (r.txTrig /= v.txTrig) then

         -- Check if not moving trigger message
         if (r.txTrigCnt = 6) then

            -- Reset the counter
            v.txTrigCnt := 0;

            -- Check for rising edge
            if (r.txTrig = '0') and (v.txTrig = '1') then
               -- Trigger packet indication - LinkTrigger0
               v.txTrigData(0) := K_28_2_C;
               v.txTrigData(1) := K_28_4_C;
               v.txTrigData(2) := K_28_4_C;

            -- Else falling edge
            else
               -- Trigger packet indication - LinkTrigger1
               v.txTrigData(0) := K_28_4_C;
               v.txTrigData(1) := K_28_2_C;
               v.txTrigData(2) := K_28_2_C;
            end if;

            -- Set the trigger delay
            for i in 3 to 5 loop
               v.txTrigData(i) := TX_DLY_C(149-idx);
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

            -- Accept the data
            v.cfgSlave.tReady := '1';

            -- Send the configuration message
            v.txData  := cfgMaster.tData(7 downto 0);
            v.txDataK := cfgMaster.tUser(0);

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
