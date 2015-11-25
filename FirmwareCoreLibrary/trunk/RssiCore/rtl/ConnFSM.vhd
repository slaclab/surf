-------------------------------------------------------------------------------
-- Title      : Connection and parameter negotiation.
-------------------------------------------------------------------------------
-- File       : ConnFSM.vhd
-- Author     : Uros Legat  <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory (Cosylab)
-- Created    : 2015-08-09
-- Last update: 2015-08-09
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Calculates and checks the RUDP packet checksum.
--              Checksum for IP/UDP/TCP/RUDP.       
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.RssiPkg.all;

entity ConnFSM is
   generic (
      TPD_G        : time     := 1 ns;
      SERVER_G     : boolean  := true;
      
      WINDOW_ADDR_SIZE_G  : positive := 7;
      
      -- Adjustible parameters
      
      -- Transmitter
      MAX_TX_NUM_OUTS_SEG_G  : positive := 8;
      MAX_TX_SEG_SIZE_G      : positive := (2**SEGMENT_ADDR_SIZE_C)*8; -- Number of bytes
      
      -- Receiver
      MAX_RX_NUM_OUTS_SEG_G  : positive := 8;
      MAX_RX_SEG_SIZE_G      : positive := (2**SEGMENT_ADDR_SIZE_C)*8  -- Number of bytes
   );
   port (
      clk_i      : in  sl;
      rst_i      : in  sl;
      
      -- Connection request (open/close)
      connRq_i    : in  sl;
      closeRq_i   : in  sl;
          
      -- Parameters received from peer      
      rxRssiParam_i  : in  RssiParamType;
      
      -- Parameters set by high level App
      appRssiParam_i  : in  RssiParamType;
      
      -- Negotiated parameters
      rssiParam_o  : in  RssiParamType;      

      -- Flags from Rx module
      rxFlags_i    : in FlagsType;
      
      -- Valid received packet
      rxValid_i     : in sl;
      
      synHeadSt_i   : in sl;
      ackHeadSt_i   : in sl;
      rstHeadSt_i   : in sl;    

      --
      -- Connection FSM indicating active connection      
      connActive_o : out sl;      
      
      -- 
      sndSyn_o : out sl;
      sndAck_o : out sl;
      sndRst_o : out sl;
      txAckF_o : out sl;
      --
      
      -- Window size and buffer size different for Rx and Tx
      rxBufferSize_o   : out integer range 0 to 2 ** (SEGMENT_ADDR_SIZE_C-1);
      rxWindowSize_o   : out integer range 0 to 2 ** (WINDOW_ADDR_SIZE_G-1);
      --
      txBufferSize_o   : out integer range 0 to 2 ** (SEGMENT_ADDR_SIZE_C-1);
      txWindowSize_o   : out integer range 0 to 2 ** (WINDOW_ADDR_SIZE_G-1);
      
      
      
   );
end entity ConnFSM;

architecture rtl of ConnFSM is
   
   type StateType is (
      CLOSED_S,
      SEND_SYN_S,
      WAIT_SYN_S,
      LISTEN_S,
      SEND_ACK_S,
      SEND_SVN_ACK_S,
      WAIT_ACK_S,
      OPEN_S
   );
     
   type RegType is record
      connActive  : sl;
      sndSyn      : sl;
      sndAck      : sl;
      sndRst      : sl;
      txAckF      : sl;
      
      rssiParam   : RssiParamType;
      
      rxWindowSize : 
      
      ---
      state       : StateType;
      
   end record RegType;

   constant REG_INIT_C : RegType := (
      connActive  => '0',
      sndSyn      => '0',
      sndAck      => '0',
      sndRst      => '0',
      txAckF      => '0',
      
      rssiParam   => (others => '0'),
      
      ---
      state  => CLOSED_S
      
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
     

   
begin

   comb : process (r, rst_i, connRq_i, rxRssiParam_i, synHeadSt_i, ackHeadSt_i, rstHeadSt_i) is
      variable v : RegType;
   begin
      v := r;
      
 -- /////////////////////////////////////////////////////////
      ------------------------------------------------------------
      -- Connection FSM
      -- Synchronisation and parameter negotiation
      ------------------------------------------------------------
      -- /////////////////////////////////////////////////////////
      
      case r.state is
         ----------------------------------------------------------------------
         when CLOSED_S =>
         
            -- Initialize parameters
            v := REG_INIT_C;
                        
            -- Next state condition
            -- Initiated by high level App and depends on whether it is a 
            -- server or client.
            if (connRq_i = '1' and SERVER_G = true) then
               v.state    := LISTEN_S;  -- Server Passive open
            elsif (connRq_i = '1' and SERVER_G = false) then
               v.state    := SEND_SYN_S;-- Client Active open
            end if;
         ----------------------------------------------------------------------
         -- Client
         -- 
         --         
         ----------------------------------------------------------------------         
         when SEND_SYN_S =>
            
            v.connActive   := '0';
            v.sndSyn       := '1'; 
            v.sndAck       := '0';
            v.sndRst       := '0';
            v.txAckF       := '0';
            
            -- Send the Client proposed parameters
            v.rssiParam    := appRssiParam_i;

            if (synHeadSt_i = '1') then
               v.state    := WAIT_SYN_S;
            end if;
        
         ----------------------------------------------------------------------
         when WAIT_SYN_S =>

            v.connActive   := '0';
            v.sndSyn       := '0'; 
            v.sndAck       := '0';
            v.sndRst       := '0';
            v.txAckF       := '0';
                        
            if (rxValid_i = '1' and rxFlags_i.syn = '1' and rxFlags_i.ack = '1') then
               -- Check parameters
               if (
                  rxRssiParam_i.version    = appRssiParam_i.version     and
                  rxRssiParam_i.maxOutsSeg < (2**WINDOW_ADDR_SIZE_G)    and -- Number of segments in a window
                  rxRssiParam_i.maxSegSize < (2**SEGMENT_ADDR_SIZE_C)*8 and -- Number of bytes
               ) then
               
                  -- Accept the parameters from the server                  
                  v.rssiParam := rxRssiParam_i;
                  --
                  v.state := SEND_ACK_S;
               else
                  -- Reject parameters and reset the connection               
                  v.rssiParam := r.rssiParam;
                  --
                  v.state := SEND_RST_S;
               end if;
            end if;

         ----------------------------------------------------------------------
         when others =>
            
            v   := REG_INIT_C;            
      ----------------------------------------------------------------------
      end case;

      if (rst_i = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;
      -----------------------------------------------------------
   end process comb;

   seq : process (clk_i) is
   begin
      if (rising_edge(clk_i)) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
   ------------------------------------------------------------------------------
   -- Output assignment
   -- Parameters for receiver (have to be correctly set by the app)
   rxBufferSize_o <= conv_integer(appRssiParam_i.maxSegSize);
   rxWindowSize_o <= conv_integer(appRssiParam_i.maxOutsSeg);
   -- Parameters for transmitter are received by the peer and checked by FSM 
   txBufferSize_o <= conv_integer(r.rssiParam.maxSegSize);
   txWindowSize_o <= conv_integer(r.rssiParam.maxOutsSeg);   

   ---------------------------------------------------------------------
end architecture rtl;