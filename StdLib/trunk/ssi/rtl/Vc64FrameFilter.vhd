-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Vc64FrameFilter.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-04
-- Last update: 2014-04-10
-- Platform   : Vivado 2013.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:   This module is used to filter out bad VC64 frames.
--
-- Note: If EN_FRAME_FILTER_G = true, then this module DOES NOT support 
--       interleaving of virtual channels during the middle of a frame transfer.
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.Vc64Pkg.all;

entity Vc64FrameFilter is
   generic (
      TPD_G             : time    := 1 ns;
      RST_ASYNC_G       : boolean := false;
      RST_POLARITY_G    : sl      := '1';  -- '1' for active HIGH reset, '0' for active LOW reset      
      EN_FRAME_FILTER_G : boolean := true);
   port (
      -- RX Frame Filter Status Signals
      vcRxDropWrite : out sl;
      vcRxTermFrame : out sl;
      -- Streaming RX Data Interface
      vcRxData      : in  Vc64DataType;
      vcRxCtrl      : out Vc64CtrlType;
      -- Streaming TX Data Interface
      vcTxCtrl      : in  Vc64CtrlType;
      vcTxData      : out Vc64DataType;
      -- Clock and Reset
      vcClk         : in  sl;
      vcRst         : in  sl := '0');   
end Vc64FrameFilter;

architecture rtl of Vc64FrameFilter is

   type StateType is (
      WAIT_FOR_SOF_S,
      WAIT_FOR_EOF_S,
      WAIT_FOR_READY_S);                  
   type RegType is record
      vcRxDropWrite : sl;
      vcRxTermFrame : sl;
      vc            : slv(3 downto 0);
      vcRxCtrl      : Vc64CtrlType;
      vcTxData      : Vc64DataType;
      state         : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      '0',
      '0',
      (others => '0'),
      VC64_CTRL_INIT_C,
      VC64_DATA_INIT_C,
      WAIT_FOR_SOF_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal din  : slv(72 downto 0);
   signal dout : slv(71 downto 0);
   signal rxReady,
      rxAlmostFull,
      rxOverflow,
      fifoRdEn,
      fifoValid,
      txValid,
      ready : sl;
   
   signal txCtrl : Vc64CtrlType;
   signal txData : Vc64DataType;
   
begin

   NO_FILTER : if (EN_FRAME_FILTER_G = false) generate

      vcTxData <= vcRxData;
      vcRxCtrl <= vcTxCtrl;

      vcRxDropWrite <= '0';
      vcRxTermFrame <= '0';
      
   end generate;

   ADD_FILTER : if (EN_FRAME_FILTER_G = true) generate

      comb : process (r, vcRst, vcRxData, vcTxCtrl) is
         variable v : RegType;
      begin
         -- Latch the current value
         v := r;

         -- Update the local RX flow control
         v.vcRxCtrl.ready      := vcTxCtrl.ready;
         v.vcRxCtrl.almostFull := vcTxCtrl.almostFull;
         if vcTxCtrl.overflow = '1' then
            v.vcRxCtrl.overflow := '1';
         end if;

         -- Reset strobe Signals
         v.vcTxData.valid := '0';
         v.vcRxDropWrite  := '0';
         v.vcRxTermFrame  := '0';

         -- State Machine
         case (r.state) is
            ----------------------------------------------------------------------
            when WAIT_FOR_SOF_S =>
               -- Check for a FIFO write
               if vcRxData.valid = '1' then
                  -- Wait for a start of frame bit
                  if vcRxData.sof = '1' then        -- (sof = 1, eof = ?, eofe = ?)
                     -- Check if the FIFO is ready 
                     if r.vcRxCtrl.ready = '1' then
                        -- Check for eof flag 
                        if vcRxData.eof = '1' then  --(sof = 1, eof = 1, eofe = ?)
                           -- Write the filtered data into the FIFO
                           v.vcTxData          := vcRxData;
                           -- Reset the overflow flag
                           v.vcRxCtrl.overflow := '0';
                        else            -- (sof = 1, eof = 0, eofe = ?)
                           -- Write the filtered data into the FIFO
                           v.vcTxData := vcRxData;
                           -- Latch the Virtual Channel pointer
                           v.vc       := vcRxData.vc;
                           -- Next state
                           v.state    := WAIT_FOR_EOF_S;
                        end if;
                     else
                        -- Strobe the error flags
                        v.vcRxDropWrite     := '1';
                        v.vcRxCtrl.overflow := '1';
                        -- Check for eof flag 
                        if vcRxData.eof = '1' then
                           v.vcRxTermFrame := '1';
                        end if;
                     end if;
                  else
                     -- Strobe the error flags
                     v.vcRxDropWrite := '1';
                     -- Check for eof flag 
                     if vcRxData.eof = '1' then
                        v.vcRxTermFrame := '1';
                     end if;
                  end if;
               end if;
            ----------------------------------------------------------------------
            when WAIT_FOR_EOF_S =>
               -- Check for a FIFO write
               if vcRxData.valid = '1' then
                  -- Check if the FIFO is ready 
                  if r.vcRxCtrl.ready = '1' then
                     -- Check for a start of frame bit
                     if vcRxData.sof = '1' then     -- error detection
                        -- Strobe the error flag
                        v.vcRxDropWrite  := '1';
                        v.vcRxTermFrame  := '1';
                        -- terminate the frame with error flag
                        v.vcTxData.valid := '1';
                        v.vcTxData.sof   := '0';
                        v.vcTxData.eof   := '1';
                        v.vcTxData.eofe  := '1';
                        -- Next state
                        v.state          := WAIT_FOR_SOF_S;
                     -- Check if the Virtual Channel pointer has changed
                     elsif r.vc /= vcRxData.vc then
                        -- Strobe the error flag
                        v.vcRxDropWrite  := '1';
                        v.vcRxTermFrame  := '1';
                        -- terminate the frame with error flag
                        v.vcTxData.valid := '1';
                        v.vcTxData.sof   := '0';
                        v.vcTxData.eof   := '1';
                        v.vcTxData.eofe  := '1';
                        -- Next state
                        v.state          := WAIT_FOR_SOF_S;
                     -- Check for eof flag 
                     elsif vcRxData.eof = '1' then  --(sof = 0, eof = 1, eofe = ?)                        
                        -- Write the filtered data into the FIFO
                        v.vcTxData          := vcRxData;
                        -- Reset the overflow flag
                        v.vcRxCtrl.overflow := '0';
                        -- Next state
                        v.state             := WAIT_FOR_SOF_S;
                     else               --(sof = 0, eof = 0, eofe = ?) 
                        -- Write the filtered data into the FIFO
                        v.vcTxData := vcRxData;
                     end if;
                  else
                     -- Next state
                     v.state := WAIT_FOR_READY_S;
                  end if;
               end if;
            ----------------------------------------------------------------------
            when WAIT_FOR_READY_S =>
               -- Check if the FIFO is ready 
               if r.vcRxCtrl.ready = '1' then
                  -- Strobe the error flags
                  v.vcRxDropWrite  := '1';
                  v.vcRxTermFrame  := '1';
                  -- terminate the frame with error flag
                  v.vcTxData.valid := '1';
                  v.vcTxData.sof   := '0';
                  v.vcTxData.eof   := '1';
                  v.vcTxData.eofe  := '1';
                  -- Next state
                  v.state          := WAIT_FOR_SOF_S;
               end if;
         ----------------------------------------------------------------------
         end case;

         -- Synchronous Reset
         if (RST_ASYNC_G = false and vcRst = RST_POLARITY_G) then
            v := REG_INIT_C;
         end if;

         -- Register the variable for next clock cycle
         rin <= v;

         -- Outputs
         vcRxCtrl.ready      <= vcTxCtrl.ready;
         vcRxCtrl.almostFull <= vcTxCtrl.almostFull;
         vcRxCtrl.overflow   <= r.vcRxCtrl.overflow;
         vcTxData            <= r.vcTxData;
         vcRxDropWrite       <= r.vcRxDropWrite;
         vcRxTermFrame       <= r.vcRxTermFrame;
         
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
