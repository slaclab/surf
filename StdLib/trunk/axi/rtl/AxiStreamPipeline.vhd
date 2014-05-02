-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AxiStreamPipeline.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-05-01
-- Last update: 2014-05-02
-- Platform   : Vivado 2013.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:   This module is used to sync a AxiStream bus 
--                either as a pass through or with pipeline register stages.
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;

entity AxiStreamPipeline is
   generic (
      TPD_G          : time                  := 1 ns;
      RST_ASYNC_G    : boolean               := false;
      RST_POLARITY_G : sl                    := '1';  -- '1' for active HIGH reset, '0' for active LOW reset      
      PIPE_STAGES_G  : natural range 0 to 16 := 0);
   port (
      -- Slave Port
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;
      -- Master Port
      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType;
      -- Clock and Reset
      axisClk     : in  sl;
      axisRst     : in  sl := not RST_POLARITY_G);
end AxiStreamPipeline;

architecture rtl of AxiStreamPipeline is
   
   type RegType is record
      sAxisSlave  : AxiStreamSlaveType;
      readBuffer  : AxiStreamMasterType;
      mAxisMaster : AxiStreamMasterArray(0 to PIPE_STAGES_G);
   end record RegType;
   constant REG_INIT_C : RegType := (
      AXI_STREAM_SLAVE_INIT_C,
      AXI_STREAM_MASTER_INIT_C,
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
         variable i : integer;
         variable j : integer;
         variable v : RegType;
      begin
         -- Latch the current value
         v := r;

         -- Check if the master is ready for more data
         if mAxisSlave.tReady = '1' then
            -- Check that we have cleared out the readBuffer
            if r.readBuffer.tValid = '1' then
               -- Reset the ready flag
               v.sAxisSlave.tReady := '0';
               -- Pipeline the readout records
               v.mAxisMaster(0)    := r.readBuffer;
               for i in 1 to PIPE_STAGES_G loop
                  v.mAxisMaster(i) := r.mAxisMaster(i-1);
               end loop;
               -- Check for a FIFO read
               if (r.sAxisSlave.tReady = '1') and (sAxisMaster.tValid = '1') then
                  -- Latch the data value
                  v.readBuffer := sAxisMaster;
               else
                  -- Clear the buffer
                  v.readBuffer.tValid := '0';
               end if;
            else
               -- Set the ready flag
               v.sAxisSlave.tReady := mAxisSlave.tReady;
               -- Pipeline the readout records
               v.mAxisMaster(0)    := sAxisMaster;
               for i in 1 to PIPE_STAGES_G loop
                  v.mAxisMaster(i) := r.mAxisMaster(i-1);
               end loop;
            end if;
         else
            -- Check if we need to advance the pipeline
            for i in PIPE_STAGES_G downto 1 loop
               if r.mAxisMaster(i).tValid = '0' then
                  -- Shift the data up the pipeline
                  v.mAxisMaster(i)          := r.mAxisMaster(i-1);
                  -- Clear the cell that the data was shifted from
                  v.mAxisMaster(i-1).tValid := '0';
               end if;
            end loop;
            -- Check if we need to advance the lowest stage
            if r.mAxisMaster(0).tValid = '0' then
               -- Shift the data up the pipeline
               v.mAxisMaster(0)    := r.readBuffer;
               -- Clear the buffer
               v.readBuffer.tValid := '0';
            end if;
            -- Check if last cycle was pulling the FIFO
            if r.sAxisSlave.tReady = '1' then
               -- Reset the ready flag
               v.sAxisSlave.tReady := '0';
               -- Check for a FIFO read
               if sAxisMaster.tValid = '1' then
                  -- Check where we need to write the data
                  if r.mAxisMaster(0).tValid = '0' then
                     -- Shift the data up the pipeline
                     v.mAxisMaster(0) := sAxisMaster;
                  else
                     -- Save the value in the buffer
                     v.readBuffer := sAxisMaster;
                  end if;
               end if;
            else
               -- Check that we cleared the buffers
               if (r.mAxisMaster(0).tValid = '0') and (r.readBuffer.tValid = '0') then
                  -- Set the ready flag
                  v.sAxisSlave.tReady := mAxisSlave.tReady;
               end if;
            end if;
         end if;

         -- Synchronous Reset
         if (RST_ASYNC_G = false and axisRst = RST_POLARITY_G) then
            v := REG_INIT_C;
         end if;

         -- Register the variable for next clock cycle
         rin <= v;

         -- Outputs
         sAxisSlave  <= r.sAxisSlave;
         mAxisMaster <= r.mAxisMaster(PIPE_STAGES_G);
         
      end process comb;


      seq : process (axisClk, axisRst) is
      begin
         if rising_edge(axisClk) then
            r <= rin after TPD_G;
         end if;
         -- Asynchronous Reset
         if (RST_ASYNC_G and axisRst = RST_POLARITY_G) then
            r <= REG_INIT_C after TPD_G;
         end if;
      end process seq;
      
   end generate;
   
end rtl;
