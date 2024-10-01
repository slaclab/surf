-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- Block to flush AXI Stream frames, being mindfull of frame boundaries.
-- This module is designed to feed into an AxiStreamFifo using pause to determine
-- backpressure situations.
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

entity AxiStreamFlush is
   generic (
      TPD_G         : time                 := 1 ns;
      RST_ASYNC_G   : boolean              := false;
      AXIS_CONFIG_G : AxiStreamConfigType;
      SSI_EN_G      : boolean              := false);
   port (

      -- Clock and reset
      axisClk     : in  sl;
      axisRst     : in  sl;

      -- Flush enable
      flushEn     : in  sl;

      -- Slave Port
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;

      -- Master Port
      mAxisMaster : out AxiStreamMasterType;
      mAxisCtrl   : in  AxiStreamCtrlType);
end AxiStreamFlush;

architecture rtl of AxiStreamFlush is

   type StateType is ( IDLE_S, MOVE_S, FLUSH_S );

   type RegType is record
      state    : StateType;
      obMaster : AxiStreamMasterType;
      ibSlave  : AxiStreamSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state    => IDLE_S,
      obMaster => axiStreamMasterInit(AXIS_CONFIG_G),
      ibSlave  => AXI_STREAM_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (mAxisCtrl, sAxisMaster, axisRst, flushEn, r) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals
      v.ibSlave.tReady := '0';
      v.obMaster := AXI_STREAM_MASTER_INIT_C;

      case r.state is

         -- Wait for frame
         when IDLE_S =>
            if sAxisMaster.tValid = '1' then

               -- Flush is enabled
               if flushEn = '1' then
                  v.state := FLUSH_S;

               -- Allow backpressure when flush is disabled
               elsif mAxisCtrl.pause = '0' then
                  v.state := MOVE_S;
               end if;
            end if;

         -- Moving data
         when MOVE_S =>
            v.ibSlave.tReady := not mAxisCtrl.pause;

            v.obMaster := sAxisMaster;
            v.obMaster.tValid := sAxisMaster.tValid and not mAxisCtrl.pause;

            --  Flush is asserted, terminate frame
            if flushEn = '1' then
               v.obMaster.tValid := '1';
               v.obMaster.tLast  := '1';

               -- Set EOFE if enabled
               if SSI_EN_G then
                  ssiSetUserEofe ( AXIS_CONFIG_G, v.obMaster, '1');
               end if;

               v.state := FLUSH_S;

            elsif sAxisMaster.tValid = '1' and sAxisMaster.tLast = '1' then
               v.state := IDLE_S;
            end if;

         -- Flushing data
         when FLUSH_S =>
            v.ibSlave.tReady := '1';

            -- Dump until we see tlast
            if sAxisMaster.tValid = '1' and sAxisMaster.tLast = '1' then
               v.state := IDLE_S;
            end if;

         when others =>
            v.state := IDLE_S;

      end case;

      -- Combinatorial outputs before the reset
      sAxisSlave <= v.ibSlave;

      -- Reset
      if (RST_ASYNC_G = false and axisRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Registered Outputs
      mAxisMaster <= r.obMaster;

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
