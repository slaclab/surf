-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : SsiFrameFilter.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-05-02
-- Last update: 2014-05-02
-- Platform   : Vivado 2013.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:   This module is used to filter out bad SSI frames.
--
-- Note: If EN_FRAME_FILTER_G = true, then this module DOES NOT support 
--       interleaving of channels during the middle of a frame transfer.
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

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
      sAxisDropWrite : out sl;
      sAxisTermFrame : out sl;
      -- Master Port
      mAxisMaster    : out AxiStreamMasterType;
      mAxisSlave     : in  AxiStreamSlaveType;
      -- Clock and Reset
      axisClk        : in  sl;
      axisRst        : in  sl);
end SsiFrameFilter;

architecture rtl of SsiFrameFilter is

   type StateType is (
      WAIT_FOR_SOF_S,
      WAIT_FOR_EOF_S,
      WAIT_FOR_READY_S);        

   type RegType is record
      sAxisDropWrite : sl;
      sAxisTermFrame : sl;
      tDest          : slv(7 downto 0);
      tId            : slv(7 downto 0);
      mAxisMaster    : AxiStreamMasterType;
      sAxisSlave     : AxiStreamSlaveType;
      state          : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      '0',
      '0',
      (others => '0'),
      (others => '0'),
      AXI_STREAM_MASTER_INIT_C,
      AXI_STREAM_SLAVE_INIT_C,
      WAIT_FOR_SOF_S);

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

         -- Update the local RX flow control
         v.sAxisSlave := mAxisSlave;

         -- Reset strobe Signals
         ssiResetFlags(v.mAxisMaster);
         v.sAxisDropWrite := '0';
         v.sAxisTermFrame := '0';

         -- State Machine
         case (r.state) is
            ----------------------------------------------------------------------
            when WAIT_FOR_SOF_S =>
               -- Check for a FIFO write
               if sAxisMaster.tValid = '1' then
                  -- Wait for a start of frame bit
                  if ssiGetUserSof(AXIS_CONFIG_G, sAxisMaster) = '1' then  -- (sof = 1, eof = ?, eofe = ?)
                     -- Check if the FIFO is ready 
                     if r.sAxisSlave.tReady = '1' then
                        -- Check for eof flag 
                        if sAxisMaster.tLast = '1' then  --(sof = 1, eof = 1, eofe = ?)
                           -- Write the filtered data into the FIFO
                           v.mAxisMaster := sAxisMaster;
                        else            -- (sof = 1, eof = 0, eofe = ?)
                           -- Write the filtered data into the FIFO
                           v.mAxisMaster := sAxisMaster;
                           -- Latch the Virtual Channel pointer
                           v.tDest       := sAxisMaster.tDest;
                           v.tId         := sAxisMaster.tId;
                           -- Next state
                           v.state       := WAIT_FOR_EOF_S;
                        end if;
                     else
                        -- Strobe the error flags
                        v.sAxisDropWrite := '1';
                        -- Check for eof flag 
                        if sAxisMaster.tLast = '1' then
                           v.sAxisTermFrame := '1';
                        end if;
                     end if;
                  else
                     -- Strobe the error flags
                     v.sAxisDropWrite := '1';
                     -- Check for eof flag 
                     if sAxisMaster.tLast = '1' then
                        v.sAxisTermFrame := '1';
                     end if;
                  end if;
               end if;
            ----------------------------------------------------------------------
            when WAIT_FOR_EOF_S =>
               -- Check for a FIFO write
               if sAxisMaster.tValid = '1' then
                  -- Check if the FIFO is ready 
                  if r.sAxisSlave.tReady = '1' then
                     -- Check for errors
                     -- Check for a 
                     if (ssiGetUserSof(AXIS_CONFIG_G, sAxisMaster) = '1') or     -- Check for sof
                                                (r.tDest /= sAxisMaster.tDest) or  -- Check for change in tDest
                                                (r.tId /= sAxisMaster.tId) then  -- Check for change in tDest
                        -- Strobe the error flag
                        v.sAxisDropWrite     := '1';
                        v.sAxisTermFrame     := '1';
                        -- terminate the frame with error flag
                        v.mAxisMaster.tValid := '1';
                        ssiSetUserSof(AXIS_CONFIG_G, v.mAxisMaster, '0');
                        v.mAxisMaster.tLast  := '1';
                        ssiSetUserEofe(AXIS_CONFIG_G, v.mAxisMaster, '1');
                        -- Next state
                        v.state              := WAIT_FOR_SOF_S;
                     -- Check for eof flag 
                     elsif sAxisMaster.tLast = '1' then  --(sof = 0, eof = 1, eofe = ?)                        
                        -- Write the filtered data into the FIFO
                        v.mAxisMaster := sAxisMaster;
                        -- Next state
                        v.state       := WAIT_FOR_SOF_S;
                     else               --(sof = 0, eof = 0, eofe = ?) 
                        -- Write the filtered data into the FIFO
                        v.mAxisMaster := sAxisMaster;
                     end if;
                  else
                     -- Next state
                     v.state := WAIT_FOR_READY_S;
                  end if;
               end if;
            ----------------------------------------------------------------------
            when WAIT_FOR_READY_S =>
               -- Check if the FIFO is ready 
               if r.sAxisSlave.tReady = '1' then
                  -- Strobe the error flags
                  v.sAxisDropWrite     := '1';
                  v.sAxisTermFrame     := '1';
                  -- terminate the frame with error flag
                  v.mAxisMaster.tValid := '1';
                  v.mAxisMaster.tLast  := '1';
                  ssiSetUserSof(AXIS_CONFIG_G, v.mAxisMaster, '0');
                  ssiSetUserEofe(AXIS_CONFIG_G, v.mAxisMaster, '1');
                  -- Next state
                  v.state              := WAIT_FOR_SOF_S;
               end if;
         ----------------------------------------------------------------------
         end case;

         -- Synchronous Reset
         if axisRst = '1' then
            v := REG_INIT_C;
         end if;

         -- Register the variable for next clock cycle
         rin <= v;

         -- Outputs
         mAxisMaster    <= r.mAxisMaster;
         sAxisSlave     <= r.sAxisSlave;
         sAxisDropWrite <= r.sAxisDropWrite;
         sAxisTermFrame <= r.sAxisTermFrame;
         
      end process comb;

      seq : process (axisClk) is
      begin
         if rising_edge(axisClk) then
            r <= rin after TPD_G;
         end if;
      end process seq;
      
   end generate;
   
end rtl;
