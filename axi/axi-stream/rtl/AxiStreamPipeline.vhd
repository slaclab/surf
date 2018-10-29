-------------------------------------------------------------------------------
-- File       : AxiStreamPipeline.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-05-01
-- Last update: 2016-09-06
-------------------------------------------------------------------------------
-- Description:   This module is used to sync a AxiStream bus 
--                either as a pass through or with pipeline register stages.
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

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;

entity AxiStreamPipeline is
   generic (
      TPD_G         : time                  := 1 ns;
      PIPE_STAGES_G : natural range 0 to 16 := 0);
   port (
      -- Clock and Reset
      axisClk     : in  sl;
      axisRst     : in  sl;
      -- Slave Port
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;
      -- Master Port
      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType);
end AxiStreamPipeline;

architecture rtl of AxiStreamPipeline is

   constant PIPE_STAGES_C : natural := PIPE_STAGES_G+1;

   type RegType is record
      sAxisSlave  : AxiStreamSlaveType;
      mAxisMaster : AxiStreamMasterArray(0 to PIPE_STAGES_C);
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      AXI_STREAM_SLAVE_INIT_C,
      (others => AXI_STREAM_MASTER_INIT_C));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   ZERO_LATENCY : if (PIPE_STAGES_G = 0) generate

      mAxisMaster <= sAxisMaster;
      sAxisSlave  <= mAxisSlave;
      
   end generate;

   PIPE_REG : if (PIPE_STAGES_G > 0) generate
      
      comb : process (axisRst, mAxisSlave, r, sAxisMaster) is
         variable v : RegType;
         variable i : natural;
      begin
         -- Latch the current value
         v := r;

         -- Check if we need to shift register
         if (r.mAxisMaster(PIPE_STAGES_C).tValid = '0') or (mAxisSlave.tReady = '1') then
            -- Shift the data up the pipeline
            for i in PIPE_STAGES_C downto 2 loop
               v.mAxisMaster(i) := r.mAxisMaster(i-1);
            end loop;
            -- Check if the lowest cell is empty
            if r.mAxisMaster(0).tValid = '0' then
               -- Set the ready bit
               v.sAxisSlave.tReady := '1';
               -- Check if we were pulling the FIFO last clock cycle
               if r.sAxisSlave.tReady = '1' then
                  -- Shift the FIFO data
                  v.mAxisMaster(1) := sAxisMaster;
               else
                  -- Clear valid in stage 1
                  v.mAxisMaster(1).tValid := '0';
               end if;
            else
               -- Shift the lowest cell
               v.mAxisMaster(1) := r.mAxisMaster(0);
               -- Check if we were pulling the FIFO last clock cycle
               if r.sAxisSlave.tReady = '1' then
                  -- Reset the ready bit
                  v.sAxisSlave.tReady := '0';
                  -- Fill the lowest cell
                  v.mAxisMaster(0)    := sAxisMaster;
               else
                  -- Set the ready bit
                  v.sAxisSlave.tReady     := '1';
                  -- Reset the lowest cell tValid
                  v.mAxisMaster(0).tValid := '0';
               end if;
            end if;
         else
            -- Reset the ready bit
            v.sAxisSlave.tReady := '0';
            -- Check if we were pulling the FIFO last clock cycle
            if r.sAxisSlave.tReady = '1' then
               -- Fill the lowest cell
               v.mAxisMaster(0) := sAxisMaster;
            elsif r.mAxisMaster(0).tValid = '0' then
               -- Set the ready bit
               v.sAxisSlave.tReady := '1';
            end if;
            -- Check if we need to internally shift the data to remove gaps
            for i in PIPE_STAGES_C-1 downto 1 loop
               -- Check for empty cell ahead of a filled cell
               if (r.mAxisMaster(i).tValid = '0') and (r.mAxisMaster(i-1).tValid = '1') then
                  -- Shift the lowest cell
                  v.mAxisMaster(i)          := r.mAxisMaster(i-1);
                  -- Reset the flag
                  v.mAxisMaster(i-1).tValid := '0';
               end if;
            end loop;
         end if;

         -- Synchronous Reset
         if axisRst = '1' then
            v := REG_INIT_C;
         end if;

         -- Register the variable for next clock cycle
         rin <= v;

         -- Outputs
         sAxisSlave  <= r.sAxisSlave;
         mAxisMaster <= r.mAxisMaster(PIPE_STAGES_C);
         
      end process comb;

      seq : process (axisClk) is
      begin
         if rising_edge(axisClk) then
            r <= rin after TPD_G;
         end if;
      end process seq;
      
   end generate;
   
end rtl;
