-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : SsiFrameFilter.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-04
-- Last update: 2014-04-25
-- Platform   : Vivado 2013.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:   This module is used to filter out bad SSI frames.
--
-- Note: If EN_FRAME_FILTER_G = true, then this module DOES NOT support 
--       interleaving of virtual channels during the middle of a frame transfer.
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
      TPD_G            : time := 1 ns;
      AXI_STREAM_CFG_G : AxiStreamConfigType);
   port (
      -- Clock and Reset
      axiClk       : in  sl;
      axiRst       : in  sl := '0';
      -- Slave Frame Filter Status Signals
      dropWrite    : out sl;
      termFrame    : out sl;
      -- Streaming Data Slave (inbound) Interface
      ibAxisMaster : in  AxiStreamMasterType;
      ibAxisSlave  : out AxiStreamSlaveType;
      -- Streaming Data Master (outbound) Interface
      obAxisMaster : out AxiStreamMasterType;
      obAxisSlave  : in  AxiStreamSlaveType
      );   
end SsiFrameFilter;

architecture rtl of SsiFrameFilter is

   type StateType is (
      WAIT_FOR_SOF_S,
      WAIT_FOR_EOF_S,
      WAIT_FOR_READY_S);

   type RegType is record
      dropWrite    : sl;
      termFrame    : sl;
      vc           : slv(3 downto 0);
      ibAxisSlave  : Vc64CtrlType;
      obAxisMaster : Vc64DataType;
      state        : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      dropWrite    => '0',
      termFrame    => '0',
      vc           => (others => '0'),
      ibAxisSlave  => AXI_STREAM_SLAVE_INIT_C;
      obAxisMaster => AXI_STREAM_MASTER_INIT_C;
      state        => WAIT_FOR_SOF_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;


begin

   comb : process (ibAxisMaster, obAxisSlave, r, vcRst, vcTxCtrl) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Update the local RX flow control
      v.ibAxisSlave.tReady := obAxisSlave.tReady;

      -- Reset strobe Signals
      v.obAxisMaster.tValid := '0';
      v.dropWrite           := '0';
      v.termFrame           := '0';

      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when WAIT_FOR_SOF_S =>
            -- Check for a tValid
            if ibAxisMaster.tValid = '1' then
               -- Wait for a start of frame bit
               if ibAxisMaster.tUser(SSI_SOF_C) = '1' then       -- (sof = 1, eof = ?, eofe = ?)
                  -- Check if ready 
                  if obAxisSlave.tReady = '1' then
                     -- Check for eof flag 
                     if sAxisMaster.tUser(SSI_EOF_C) = '1' then  --(sof = 1, eof = 1, eofe = ?)
                        -- Write the filtered data across to the outbound side
                        v.obAxisMaster := ibAxisMaster;
                     else                                        -- (sof = 1, eof = 0, eofe = ?)
                        -- Write the filtered data downstream
                        v.mAxisMaster := ibAxisMaster;
                        -- Latch the Virtual Channel pointer
                        v.vc          := ibAxisMaster.tDest(3 downto 0);
                        -- Next state
                        v.state       := WAIT_FOR_EOF_S;
                     end if;
                     
                  end if;
               else
                  -- Strobe the error flags
                  v.dropWrite := '1';
                  -- Check for eof flag 
                  if ibAxisMaster.tUser(SSI_EOF_C) = '1' then
                     v.termFrame := '1';
                  end if;
               end if;
            end if;
         ----------------------------------------------------------------------
         when WAIT_FOR_EOF_S =>
            -- Check for an incomming write
            if ibAxisMaster.tValid = '1' then
               -- Check if downstream is ready
               if r.ibAxisSlave.tReady = '1' then
                  -- Check for a start of frame bit
                  if ibAxisMaster.tUser(SSI_SOF_C) = '1' then     -- error detection
                     -- Strobe the error flag
                     v.vcRxDropWrite                  := '1';
                     v.vcRxTermFrame                  := '1';
                     -- terminate the frame with error flag
                     v.obAxisMaster.valid             := '1';
                     v.obAxisMaster.tUser(SSI_SOF_C)  := '0';
                     v.obAxisMaster.tUser(SSI_EOF_C)  := '1';
                     v.obAxisMaster.tUser(SSI_EOFE_C) := '1';
                     -- Next state
                     v.state                          := WAIT_FOR_SOF_S;
                  -- Check if the Virtual Channel pointer has changed
                  elsif r.vc /= ibAxisMaster.vc then
                     -- Strobe the error flag
                     v.vcRxDropWrite                  := '1';
                     v.vcRxTermFrame                  := '1';
                     -- terminate the frame with error flag
                     v.obAxisMaster.valid             := '1';
                     v.obAxisMaster.tUser(SSI_SOF_C)  := '0';
                     v.obAxisMaster.tUser(SSI_EOF_C)  := '1';
                     v.obAxisMaster.tUser(SSI_EOFE_C) := '1';
                     -- Next state
                     v.state                          := WAIT_FOR_SOF_S;
                  -- Check for eof flag 
                  elsif ibAxisMaster.tUser(SSI_EOF_C) = '1' then  --(sof = 0, eof = 1, eofe = ?)                        
                     -- Write the filtered data into the FIFO
                     v.obAxisMaster         := ibAxisMaster;
                     -- Reset the overflow flag
                     v.ibAxisSlave.overflow := '0';
                     -- Next state
                     v.state                := WAIT_FOR_SOF_S;
                  else                  --(sof = 0, eof = 0, eofe = ?) 
                     -- Write the filtered data into the FIFO
                     v.obAxisMaster := ibAxisMaster;
                  end if;
               else
                  -- Next state
                  v.state := WAIT_FOR_READY_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when WAIT_FOR_READY_S =>
            -- Check if the FIFO is ready 
            if r.ibAxisSlave.ready = '1' then
               -- Strobe the error flags
               v.vcRxDropWrite                  := '1';
               v.vcRxTermFrame                  := '1';
               -- terminate the frame with error flag
               v.obAxisMaster.valid             := '1';
               v.obAxisMaster.tUser(SSI_SOF_C)  := '0';
               v.obAxisMaster.tUser(SSI_EOF_C)  := '1';
               v.obAxisMaster.tUser(SSI_EOFE_C) := '1';
               -- Next state
               v.state                          := WAIT_FOR_SOF_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Synchronous Reset
      if (axiRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      ibAxisSlave  <= r.ibAxisSlave;
      obAxisMaster <= r.obAxisMaster;
      dropWrite    <= r.dropWrite;
      termFrame    <= r.termFrame;
      
   end process comb;

   seq : process (vcClk, vcRst) is
   begin
      if rising_edge(vcClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
   
end rtl;
