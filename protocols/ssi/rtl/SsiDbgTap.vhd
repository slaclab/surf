-------------------------------------------------------------------------------
-- Title      : SSI Protocol: https://confluence.slac.stanford.edu/x/0oyfD
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: SSI debug tap, intended to be connect to chipscope for debugging
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

entity SsiDbgTap is
   generic (
      TPD_G        : time     := 1 ns;
      RST_ASYNC_G  : boolean  := false;
      CNT_WIDTH_G  : positive := 16;
      AXI_CONFIG_G : AxiStreamConfigType);
   port (
      -- Slave Port
      axisClk    : in sl;
      axisRst    : in sl;
      axisMaster : in AxiStreamMasterType;
      axisSlave  : in AxiStreamSlaveType);
end SsiDbgTap;

architecture rtl of SsiDbgTap is

   type StateType is (
      IDLE_S,
      MOVE_S);

   type RegType is record
      cnt   : slv(CNT_WIDTH_G-1 downto 0);
      copy  : AxiStreamMasterType;
      state : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      cnt   => (others => '0'),
      copy  => AXI_STREAM_MASTER_INIT_C,
      state => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   attribute dont_touch      : string;
   attribute dont_touch of r : signal is "TRUE";

begin

   comb : process (axisMaster, axisRst, axisSlave, r) is
      variable v : RegType;
      variable i : natural;
   begin
      -- Latch the current value
      v := r;

      -- Check if ready to move data
      if (axisMaster.tValid = '1') and (axisSlave.tReady = '1') then
         -- State Machine
         case r.state is
            ----------------------------------------------------------------------
            when IDLE_S =>
               -- Check for SOF
               if ssiGetUserSof(AXI_CONFIG_G, axisMaster) = '1' then
                  -- Move the data
                  v.copy := axisMaster;
                  -- Reset the counter
                  v.cnt  := (others => '0');
                  -- Check for non-EOF
                  if axisMaster.tLast = '0' then
                     -- Next state
                     v.state := MOVE_S;
                  end if;
               end if;
            ----------------------------------------------------------------------
            when MOVE_S =>
               -- Move the data
               v.copy := axisMaster;
               -- Increment the counter
               v.cnt  := r.cnt + 1;
               if axisMaster.tLast = '1' then
                  -- Next state
                  v.state := IDLE_S;
               end if;
         ----------------------------------------------------------------------
         end case;
      end if;

      -- Reset
      if (RST_ASYNC_G = false and axisRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (axisClk, axisRst) is
   begin
      if (RST_ASYNC_G) and (axisRst = '1') then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(axisClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
