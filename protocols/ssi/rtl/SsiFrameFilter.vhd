-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : SsiFrameFilter.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-05-02
-- Last update: 2015-09-01
-- Platform   :
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:   This module is used to filter out bad SSI frames.
--
-- Note: If EN_FRAME_FILTER_G = true, then this module DOES NOT support 
--       interleaving of channels during the middle of a frame transfer.
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

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

entity SsiFrameFilter is
   generic (
      -- General Configurations
      TPD_G             : time    := 1 ns;
      EN_FRAME_FILTER_G : boolean := true;
      -- AXI Stream Port Configurations
      AXIS_CONFIG_G     : AxiStreamConfigType);      
   port (
      -- Slave Port
      sAxisMaster    : in  AxiStreamMasterType;
      sAxisSlave     : out AxiStreamSlaveType;
      sAxisDropWrite : out sl;          -- Word dropped status output
      sAxisTermFrame : out sl;          -- Frame dropped status output
      -- Master Port
      mAxisMaster    : out AxiStreamMasterType;
      mAxisSlave     : in  AxiStreamSlaveType;
      -- Clock and Reset
      axisClk        : in  sl;
      axisRst        : in  sl);
end SsiFrameFilter;

architecture rtl of SsiFrameFilter is

   type StateType is (
      IDLE_S,
      MOVE_S);        

   type RegType is record
      wordDropped  : sl;
      frameDropped : sl;
      tDest        : slv(7 downto 0);
      master       : AxiStreamMasterType;
      slave        : AxiStreamSlaveType;
      state        : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      wordDropped  => '0',
      frameDropped => '0',
      tDest        => x"00",
      master       => AXI_STREAM_MASTER_INIT_C,
      slave        => AXI_STREAM_SLAVE_INIT_C,
      state        => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
begin

   NO_FILTER : if (EN_FRAME_FILTER_G = false) generate

      mAxisMaster <= sAxisMaster;
      sAxisSlave  <= mAxisSlave;

      sAxisDropWrite <= '0';
      sAxisTermFrame <= '0';
      
   end generate;

   ADD_FILTER : if (EN_FRAME_FILTER_G = true) generate

      comb : process (axisRst, mAxisSlave, r, sAxisMaster) is
         variable v : RegType;
      begin
         -- Latch the current value
         v := r;

         -- Reset strobe Signals
         v.wordDropped  := '0';
         v.frameDropped := '0';
         v.slave        := AXI_STREAM_SLAVE_INIT_C;
         if mAxisSlave.tReady = '1' then
            v.master.tValid := '0';
         end if;

         -- Check if ready to move data
         if (v.master.tValid = '0') and (sAxisMaster.tValid = '1') then
            -- Accept the data
            v.slave.tReady := '1';
            -- Move the data bus
            v.master       := sAxisMaster;
            -- State Machine
            case (r.state) is
               ----------------------------------------------------------------------
               when IDLE_S =>
                  -- Check for SOF
                  if ssiGetUserSof(AXIS_CONFIG_G, sAxisMaster) = '1' then
                     -- Latch tDest
                     v.tDest := sAxisMaster.tDest;
                     -- Check for no EOF
                     if sAxisMaster.tLast = '0' then
                        -- Next state
                        v.state := MOVE_S;
                     end if;
                  else
                     -- Blow off the data
                     v.master.tValid := '0';
                     -- Strobe the error flags
                     v.wordDropped   := '1';
                     -- Check for EOF flag 
                     if sAxisMaster.tLast = '1' then
                        v.frameDropped := '1';
                     end if;
                  end if;
               ----------------------------------------------------------------------
               when MOVE_S =>
                  -- Force the tDest
                  v.master.tDest := r.tDest;
                  -- Check for EOF   
                  if sAxisMaster.tLast = '1' then
                     -- Next state
                     v.state := IDLE_S;
                  end if;
                  -- Check for SSI framing errors
                  if (ssiGetUserSof(AXIS_CONFIG_G, sAxisMaster) = '1') or   -- Check for invalid SOF
                                       (r.tDest /= sAxisMaster.tDest) then  -- Check for change in tDest
                     -- Set the EOF flag
                     v.master.tLast := '1';
                     -- Set the EOFE flag
                     ssiSetUserEofe(AXIS_CONFIG_G, v.master, '1');
                     -- Strobe the error flags
                     v.wordDropped  := '1';
                     v.frameDropped := sAxisMaster.tLast;
                     -- Next state
                     v.state        := IDLE_S;
                  end if;
            ----------------------------------------------------------------------
            end case;
         end if;

         -- Synchronous Reset
         if axisRst = '1' then
            v := REG_INIT_C;
         end if;

         -- Register the variable for next clock cycle
         rin <= v;

         -- Outputs
         sAxisSlave     <= v.slave;
         mAxisMaster    <= r.master;
         sAxisDropWrite <= r.wordDropped;
         sAxisTermFrame <= r.frameDropped;
         
      end process comb;

      seq : process (axisClk) is
      begin
         if rising_edge(axisClk) then
            r <= rin after TPD_G;
         end if;
      end process seq;
      
   end generate;

end rtl;
