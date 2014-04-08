-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Vc64FifoRdCtrl.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-08
-- Last update: 2014-04-08
-- Platform   : Vivado 2013.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.Vc64Pkg.all;

entity Vc64FifoRdCtrl is
   generic (
      TPD_G         : time                  := 1 ns;
      PIPE_STAGES_G : integer range 0 to 16 := 0);  -- Used to add pipeline stages to the output ports to help with meeting timing
   port (
      -- FIFO Read Interface
      fifoValid : in  sl;
      fifoReady : out sl;
      fifoData  : in  Vc64DataType;
      -- Streaming TX Data Interface
      vcTxCtrl  : in  Vc64CtrlType;
      vcTxData  : out Vc64DataType;
      vcTxClk   : in  sl;
      vcTxRst   : in  sl := '0');
end Vc64FifoRdCtrl;

architecture rtl of Vc64FifoRdCtrl is
   
   type RegType is record
      ready    : sl;
      rdBuffer : Vc64DataType;
      rdOut    : Vc64DataArray(0 to PIPE_STAGES_G);
   end record RegType;
   constant REG_INIT_C : RegType := (
      '0',
      VC64_DATA_INIT_C,
      (others => VC64_DATA_INIT_C));
   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal ready : sl;
   signal rdOut : Vc64DataArray(0 to PIPE_STAGES_G);
   
begin

   -- Outputs
   fifoReady <= ready;
   vcTxData  <= rdOut(PIPE_STAGES_G);

   ZERO_LATENCY : if (PIPE_STAGES_G = 0) generate

      rdOut(0) <= fifoData;
      ready    <= vcTxCtrl.ready;
      
   end generate;

   PIPE_REG : if (PIPE_STAGES_G > 0) generate
      
      comb : process (fifoData, fifoValid, r, vcTxCtrl, vcTxRst) is
         variable i : integer;
         variable j : integer;
         variable v : RegType;
      begin
         -- Latch the current value
         v := r;

         -- Check the external ready signal
         if vcTxCtrl.ready = '1' then
            -- Check that we have cleared out the rdBuffer
            if r.rdBuffer.valid = '1' then
               -- Reset the ready flag
               v.ready    := '0';
               -- Pipeline the readout records
               v.rdOut(0) := r.rdBuffer;
               for i in 1 to PIPE_STAGES_G loop
                  v.rdOut(i) := r.rdOut(i-1);
               end loop;
               -- Check for a FIFO read
               if (r.ready = '1') and (fifoValid = '1') then
                  -- Latch the data value
                  v.rdBuffer := fifoData;
               else
                  -- Clear the buffer
                  v.rdBuffer.valid := '0';
               end if;
            else
               -- Set the ready flag
               v.ready    := '1';
               -- Pipeline the readout records
               v.rdOut(0) := fifoData;
               for i in 1 to PIPE_STAGES_G loop
                  v.rdOut(i) := r.rdOut(i-1);
               end loop;
            end if;
         else
            -- Check if we need to advance the pipeline
            for i in PIPE_STAGES_G downto 1 loop
               if r.rdOut(i).valid = '0' then
                  -- Shift the data up the pipeline
                  v.rdOut(i)   := r.rdOut(i-1);
                  -- Clear the cell that the data was shifted from
                  v.rdOut(i-1) := VC64_DATA_INIT_C;
               end if;
            end loop;
            -- Check if we need to advance the lowest stage
            if r.rdOut(0).valid = '0' then
               -- Shift the data up the pipeline
               v.rdOut(0)       := r.rdBuffer;
               -- Clear the buffer
               v.rdBuffer.valid := '0';
            end if;
            -- Check if last cycle was pulling the FIFO
            if r.ready = '1' then
               -- Reset the ready flag
               v.ready := '0';
               -- Check for a FIFO read
               if fifoValid = '1' then
                  -- Check where we need to write the data
                  if r.rdOut(0).valid = '0' then
                     -- Shift the data up the pipeline
                     v.rdOut(0) := fifoData;
                  else
                     -- Save the value in the buffer
                     v.rdBuffer := fifoData;
                  end if;
               end if;
            else
               -- Check that we cleared the buffers
               if (r.rdOut(0).valid = '0') and (r.rdBuffer.valid = '0') then
                  -- Set the ready flag
                  v.ready := '1';
               end if;
            end if;
         end if;

         -- Reset
         if (vcTxRst = '1') then
            v := REG_INIT_C;
         end if;

         -- Register the variable for next clock cycle
         rin <= v;

         -- Outputs
         ready <= r.ready;
         rdOut <= r.rdOut;
         
      end process comb;

      seq : process (vcTxClk) is
      begin
         if rising_edge(vcTxClk) then
            r <= rin after TPD_G;
         end if;
      end process seq;
      
   end generate;
   
end rtl;
