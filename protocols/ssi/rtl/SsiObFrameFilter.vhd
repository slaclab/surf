-------------------------------------------------------------------------------
-- File       : SsiObFrameFilter.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-05-02
-- Last update: 2016-10-17
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

entity SsiObFrameFilter is
   generic (
      TPD_G             : time    := 1 ns;
      VALID_THOLD_G     : natural := 1;
      EN_FRAME_FILTER_G : boolean := true;
      AXIS_CONFIG_G     : AxiStreamConfigType);        
   port (
      -- Slave Port (AXIS FIFO Read Interface)
      sAxisMaster    : in  AxiStreamMasterType;
      sTLastTUser    : in  slv(7 downto 0);
      sAxisSlave     : out AxiStreamSlaveType;
      overflow       : in  sl;
      -- Master Port  
      mAxisMaster    : out AxiStreamMasterType;
      mAxisSlave     : in  AxiStreamSlaveType;
      mAxisDropWrite : out sl;          -- Word dropped status output
      mAxisTermFrame : out sl;          -- Frame dropped status output
      -- Clock and Reset
      axisClk        : in  sl;
      axisRst        : in  sl);
end SsiObFrameFilter;

architecture rtl of SsiObFrameFilter is

   type StateType is (
      IDLE_S,
      BLOWOFF_S,
      MOVE_S,
      TERM_S);        

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

   assert (AXIS_CONFIG_G.TUSER_BITS_C >= 2) report "SsiObFrameFilter:  AXIS_CONFIG_G.TUSER_BITS_C must be >= 2" severity failure;

   NO_FILTER : if (EN_FRAME_FILTER_G = false) generate

      mAxisMaster <= sAxisMaster;
      sAxisSlave  <= mAxisSlave;

      mAxisDropWrite <= '0';
      mAxisTermFrame <= '0';
      
   end generate;

   ADD_FILTER : if (EN_FRAME_FILTER_G = true) generate

      comb : process (axisRst, mAxisSlave, overflow, r, sAxisMaster, sTLastTUser) is
         variable v    : RegType;
         variable sof  : sl;
         variable eof  : AxiStreamMasterType;
         variable eofe : sl;
      begin
         -- Latch the current value
         v := r;

         -- Reset strobe Signals
         v.wordDropped  := '0';
         v.frameDropped := '0';
         v.slave        := AXI_STREAM_SLAVE_INIT_C;
         if (mAxisSlave.tReady = '1') then
            v.master.tValid := '0';
         end if;

         -- Get the SOF status
         sof := ssiGetUserSof(AXIS_CONFIG_G, sAxisMaster);

         -- Check for FIFO caching
         if (VALID_THOLD_G = 0) then
            -- Get the EOFE status
            eofe := sTLastTUser(SSI_EOFE_C);
         else
            -- Reset the flag
            eofe := '0';
         end if;

         -- State Machine
         case (r.state) is
            ----------------------------------------------------------------------
            when IDLE_S =>
               -- Check for FIFO caching and a frame larger than the FIFO depth
               if (VALID_THOLD_G = 0) and (overflow = '1') then
                  -- Blowoff the data
                  v.slave.tReady := '1';
                  -- Next state
                  v.state        := BLOWOFF_S;
                  -- Check for non-EOF or tValid not set
                  if (sAxisMaster.tLast = '0') or (sAxisMaster.tValid = '0') then
                     -- Next state
                     v.state := BLOWOFF_S;
                  end if;
               -- Check if ready to move data
               elsif (v.master.tValid = '0') and (sAxisMaster.tValid = '1') then
                  -- Accept the data
                  v.slave.tReady := '1';
                  -- Check for SOF
                  if (sof = '1') and (eofe = '0') and (overflow = '0') then
                     -- Move the data bus
                     v.master := sAxisMaster;
                     -- Latch tDest
                     v.tDest  := sAxisMaster.tDest;
                     -- Check for no EOF
                     if (sAxisMaster.tLast = '0') then
                        -- Next state
                        v.state := MOVE_S;
                     end if;
                  else
                     -- Strobe the error flags
                     v.wordDropped  := '1';
                     v.frameDropped := sAxisMaster.tLast;
                     -- Check for non-EOF
                     if (sAxisMaster.tLast = '0') then
                        -- Next state
                        v.state := BLOWOFF_S;
                     end if;
                  end if;
               end if;
            ----------------------------------------------------------------------
            when BLOWOFF_S =>
               -- Blowoff the data
               v.slave.tReady := '1';
               -- Strobe the error flags
               v.wordDropped  := '1';
               v.frameDropped := sAxisMaster.tLast;
               -- Check for EOF
               if (sAxisMaster.tValid = '1') and (sAxisMaster.tLast = '1') then
                  -- Next state
                  v.state := IDLE_S;
               end if;
            ----------------------------------------------------------------------
            when MOVE_S =>
               -- Check if ready to move data
               if (v.master.tValid = '0') and (sAxisMaster.tValid = '1') then
                  -- Accept the data
                  v.slave.tReady := '1';
                  -- Move the data bus
                  v.master       := sAxisMaster;
                  -- Check for EOF   
                  if (sAxisMaster.tLast = '1') then
                     -- Next state
                     v.state := IDLE_S;
                  end if;
                  -- Check for SSI framing errors (repeated SOF or interleaved frame)
                  if (sof = '1') or (r.tDest /= sAxisMaster.tDest) then
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
               end if;
               -- Check for overflow event
               if (overflow = '1') then
                  -- Check if moving data
                  if (v.master.tValid = '1') then
                     -- Set the EOF flag
                     v.master.tLast := '1';
                     -- Set the EOFE flag
                     ssiSetUserEofe(AXIS_CONFIG_G, v.master, '1');
                     -- Strobe the error flags
                     v.wordDropped  := '1';
                     v.frameDropped := sAxisMaster.tLast;
                     -- Next state
                     v.state        := IDLE_S;
                  else
                     -- Next state
                     v.state := TERM_S;
                  end if;
               end if;
            ----------------------------------------------------------------------
            when TERM_S =>
               -- Check if ready to move data
               if (v.master.tValid = '0') then
                  -- Set the EOF flag
                  v.master.tValid := '1';
                  v.master.tLast  := '1';
                  -- Set the EOFE flag
                  ssiSetUserEofe(AXIS_CONFIG_G, v.master, '1');
                  -- Next state
                  v.state         := IDLE_S;
               end if;
         ----------------------------------------------------------------------
         end case;

         -- Synchronous Reset
         if (axisRst = '1') then
            v := REG_INIT_C;
         end if;

         -- Register the variable for next clock cycle
         rin <= v;

         -- Outputs
         sAxisSlave     <= v.slave;
         mAxisMaster    <= r.master;
         mAxisDropWrite <= r.wordDropped;
         mAxisTermFrame <= r.frameDropped;
         
      end process comb;

      seq : process (axisClk) is
      begin
         if rising_edge(axisClk) then
            r <= rin after TPD_G;
         end if;
      end process seq;
      
   end generate;

end rtl;
