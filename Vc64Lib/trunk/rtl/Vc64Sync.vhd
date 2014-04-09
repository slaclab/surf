-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Vc64Sync.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-08
-- Last update: 2014-04-09
-- Platform   : Vivado 2013.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:   This module is used to sync a VC64 bus 
--                either as a pass through or with pipeline register stages.
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.Vc64Pkg.all;

entity Vc64Sync is
   generic (
      TPD_G             : time                  := 1 ns;
      RST_ASYNC_G       : boolean               := false;
      RST_POLARITY_G    : sl                    := '1';  -- '1' for active HIGH reset, '0' for active LOW reset      
      IGNORE_TX_READY_G : boolean               := false;
      PIPE_STAGES_G     : integer range 0 to 16 := 1);
   port (
      -- Streaming RX Data Interface
      vcRxData : in  Vc64DataType;
      vcRxCtrl : out Vc64CtrlType;
      -- Streaming TX Data Interface
      vcTxCtrl : in  Vc64CtrlType;
      vcTxData : out Vc64DataType;
      -- Clock and Reset
      vcClk    : in  sl;
      vcRst    : in  sl := '0');
end Vc64Sync;

architecture rtl of Vc64Sync is
   
   type RegType is record
      ready    : sl;
      overflow : sl;
      rdBuffer : Vc64DataType;
      rdOut    : Vc64DataArray(0 to PIPE_STAGES_G);
   end record RegType;
   constant REG_INIT_C : RegType := (
      '0',
      '1',
      VC64_DATA_INIT_C,
      (others => VC64_DATA_INIT_C));
   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal ready,
      overflow,
      txReady : sl;
   signal rdOut : Vc64DataType;
   
begin

   ZERO_LATENCY : if (PIPE_STAGES_G = 0) generate

      vcTxData <= vcRxData;
      vcRxCtrl <= vcTxCtrl;
      
   end generate;

   PIPE_REG : if (PIPE_STAGES_G > 0) generate

      -- Outputs
      vcRxCtrl.almostFull <= not(ready);
      vcRxCtrl.ready      <= ready;
      vcRxCtrl.overflow   <= overflow;

      vcTxData.valid <= (rdOut.valid and not vcTxCtrl.almostFull);
      vcTxData.size  <= rdOut.size;
      vcTxData.vc    <= rdOut.vc;
      vcTxData.sof   <= rdOut.sof;
      vcTxData.eof   <= rdOut.eof;
      vcTxData.eofe  <= rdOut.eofe;
      vcTxData.data  <= rdOut.data;

      -- Generate the TX ready signal 
      txReady <= '1' when(IGNORE_TX_READY_G = true) else vcTxCtrl.ready;

      comb : process (r, txReady, vcRst, vcRxData, vcTxCtrl) is
         variable i : integer;
         variable j : integer;
         variable v : RegType;
      begin
         -- Latch the current value
         v := r;

         -- Reset strobe Signals
         v.overflow := '0';

         -- Check for an overflow error
         if (r.ready = '0') and (vcRxData.valid = '1') then
            v.overflow := '1';
         end if;

         -- Check the back pressure status
         if vcTxCtrl.almostFull = '0' then
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
               if (r.ready = '1') and (vcRxData.valid = '1') then
                  -- Latch the data value
                  v.rdBuffer := vcRxData;
               else
                  -- Clear the buffer
                  v.rdBuffer.valid := '0';
               end if;
            else
               -- Set the ready flag
               v.ready    := txReady;
               -- Pipeline the readout records
               v.rdOut(0) := vcRxData;
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
               if vcRxData.valid = '1' then
                  -- Check where we need to write the data
                  if r.rdOut(0).valid = '0' then
                     -- Shift the data up the pipeline
                     v.rdOut(0) := vcRxData;
                  else
                     -- Save the value in the buffer
                     v.rdBuffer := vcRxData;
                  end if;
               end if;
            else
               -- Check that we cleared the buffers
               if (r.rdOut(0).valid = '0') and (r.rdBuffer.valid = '0') then
                  -- Set the ready flag
                  v.ready := txReady;
               end if;
            end if;
         end if;

         -- Synchronous Reset
         if (RST_ASYNC_G = false and vcRst = RST_POLARITY_G) then
            v := REG_INIT_C;
         end if;

         -- Register the variable for next clock cycle
         rin <= v;

         -- Outputs
         ready    <= r.ready;
         overflow <= r.overflow;
         rdOut    <= r.rdOut(PIPE_STAGES_G);
         
      end process comb;

      seq : process (vcClk, vcRst) is
      begin
         if rising_edge(vcClk) then
            r <= rin after TPD_G;
         end if;
         -- Asynchronous Reset
         if (RST_ASYNC_G and vcRst = RST_POLARITY_G) then
            r <= REG_INIT_C after TPD_G;
         end if;
      end process seq;
      
   end generate;
   
end rtl;
