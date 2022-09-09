-------------------------------------------------------------------------------
-- Title      : CoaXPress Protocol: http://jiia.org/wp-content/themes/jiia/pdf/standard_dl/coaxpress/CXP-001-2021.pdf
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: CoaXPress RX FSM
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

entity CoaXPressRxLane is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Clock and Reset
      rxClk      : in  sl;
      rxRst      : in  sl;
      -- Config Interface
      cfgMaster  : out AxiStreamMasterType;
      -- Data Interface
      dataMaster : out AxiStreamMasterType;
      -- RX PHY Interface
      rxData     : in  slv(31 downto 0);
      rxDataK    : in  slv(3 downto 0);
      rxLinkUp   : in  sl);
end entity CoaXPressRxLane;

architecture rtl of CoaXPressRxLane is

   type StateType is (
      IDLE_S,
      TYPE_S,
      CTRL_ACK_TAG_S,
      CTRL_ACK_S);

   type RegType is record
      ackCnt     : natural range 0 to 3;
      cfgMaster  : AxiStreamMasterType;
      dataMaster : AxiStreamMasterType;
      state      : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      ackCnt     => 0,
      cfgMaster  => AXI_STREAM_MASTER_INIT_C,
      dataMaster => AXI_STREAM_MASTER_INIT_C,
      state      => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (r, rxData, rxDataK, rxLinkUp, rxRst) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobes
      v.cfgMaster.tValid  := '0';
      v.dataMaster.tValid := '0';
      v.dataMaster.tLast  := '0';

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Reset counters
            v.ackCnt := 0;

            -- Check for Start of packet indication
            if (rxDataK = x"F") and (rxData = CXP_SOF_C) then
               -- Next State
               v.state := TYPE_S;
            end if;
         ----------------------------------------------------------------------
         when TYPE_S =>
            -- Default Next State
            v.state := TYPE_S;

            -- Check for "control acknowledge with no tag"
            if (rxData = x"03_03_03_03") then
               -- Next State
               v.state := CTRL_ACK_S;

            -- Check for "control acknowledge with tag"
            elsif (rxData = x"06_06_06_06") then
               -- Next State
               v.state := CTRL_ACK_TAG_S;
            end if;
         ----------------------------------------------------------------------
         when CTRL_ACK_TAG_S =>
            -- Next State
            v.state := CTRL_ACK_S;
         ----------------------------------------------------------------------
         when CTRL_ACK_S =>
            -- Increment the counter
            v.ackCnt := r.ackCnt + 1;

            -- "Acknowledgment code" index
            if (r.ackCnt = 0) then
               -- Save the response code
               v.cfgMaster.tData(31 downto 0) := rxData;
               -- Check for Success ACK
               if (rxData = x"01_01_01_01") or (rxData = x"04_04_04_04") then
                  -- Always send ZERO for successful ACK
                  v.cfgMaster.tData(31 downto 0) := (others => '0');
               end if;

            -- "Data field" index
            elsif (r.ackCnt = 2) then
               -- Save the data field
               v.cfgMaster.tData(63 downto 32) := rxData;
               -- Forward the response
               v.cfgMaster.tValid              := '0';
               -- Next State
               v.state                         := IDLE_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Check for out of phase k char
      if (uOr(rxDataK) = '1') and (r.state /= IDLE_S) then
         -- Reset flags
         v.cfgMaster.tValid  := '0';
         v.dataMaster.tValid := '0';
         -- Next State
         v.state             := IDLE_S;
      end if;

      -- Outputs
      cfgMaster  <= r.cfgMaster;
      dataMaster <= r.dataMaster;

      -- Reset
      if (rxRst = '1') or (rxLinkUp = '0') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (rxClk) is
   begin
      if (rising_edge(rxClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
