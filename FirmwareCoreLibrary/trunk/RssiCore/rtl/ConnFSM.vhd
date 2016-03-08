-------------------------------------------------------------------------------
-- Title      : Connection FSM and parameter negotiation.
-------------------------------------------------------------------------------
-- File       : ConnFSM.vhd
-- Author     : Uros Legat  <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory (Cosylab)
-- Created    : 2015-08-09
-- Last update: 2016-01-27
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Connection establishment mechanism:
--                - Connection open/close request,
--                - Parameter negotiation,
--                - Server-client mode (More comments below).
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
      --      
      TIMEOUT_UNIT_G      : real     := 1.0E-6; -- us
      CLK_FREQUENCY_G     : real     := 100.0E6;
      -- Time the module waits for the response until it retransmits SYN segment 
      RETRANS_TOUT_G      : positive := 50;
      MAX_RETRANS_CNT_G   : positive := 2;
      --
      WINDOW_ADDR_SIZE_G  : positive := 3;
      SEGMENT_ADDR_SIZE_G  : positive := 7  -- 2^SEGMENT_ADDR_SIZE_G = Number of 64 bit wide data words
   );
   port (
      clk_i      : in  sl;
      rst_i      : in  sl;
      
      -- Connection request (open/close)
      connRq_i    : in  sl;
      closeRq_i   : in  sl;

      -- Parameters received from peer (Server)    
      rxRssiParam_i  : in  RssiParamType;
      
      -- Parameters set by high level App or generic (Client)
      appRssiParam_i  : in  RssiParamType;
      
      -- Negotiated parameters
      rssiParam_o  : out  RssiParamType;      

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

      -- FSM in closed state (indicating when to initialize seqN)      
      closed_o  : out  sl;
      
      -- 
      sndSyn_o : out sl;
      sndAck_o : out sl;
      sndRst_o : out sl;
      txAckF_o : out sl;
      --
      
      -- Window size and buffer size different for Rx and Tx
      rxBufferSize_o   : out integer range 1 to 2 ** (SEGMENT_ADDR_SIZE_G);
      rxWindowSize_o   : out integer range 1 to 2 ** (WINDOW_ADDR_SIZE_G);
      --
      txBufferSize_o   : out integer range 1 to 2 ** (SEGMENT_ADDR_SIZE_G);
      txWindowSize_o   : out integer range 1 to 2 ** (WINDOW_ADDR_SIZE_G);
      
      -- Status signals
      peerTout_o       : out sl;
      paramReject_o    : out sl     
   );
end entity ConnFSM;

architecture rtl of ConnFSM is
   --
   constant SAMPLES_PER_TIME_C : integer := integer(TIMEOUT_UNIT_G * CLK_FREQUENCY_G);
   --
   type StateType is (
      CLOSED_S,
      SEND_SYN_S,
      WAIT_SYN_S,
      LISTEN_S,
      SEND_ACK_S,
      SEND_SYN_ACK_S,
      WAIT_ACK_S,
      SEND_RST_S,
      OPEN_S
   );
     
   type RegType is record
      connActive  : sl;
      closed      : sl;
      sndSyn      : sl;
      sndAck      : sl;
      sndRst      : sl;
      txAckF      : sl;
      peerTout    : sl;
      paramReject : sl;
      
      rssiParam   : RssiParamType;
      
      --
      txBufferSize   : integer range 1 to 2 ** (SEGMENT_ADDR_SIZE_G);
      txWindowSize   : integer range 1 to 2 ** (WINDOW_ADDR_SIZE_G);
      --
      timeoutCntr    : integer range 0 to RETRANS_TOUT_G * SAMPLES_PER_TIME_C;
      resendCntr     : integer range 0 to MAX_RETRANS_CNT_G+1;
      
      ---
      state       : StateType;
      
   end record RegType;

   constant REG_INIT_C : RegType := (
      connActive  => '0',
      closed      => '1',
      sndSyn      => '0',
      sndAck      => '0',
      sndRst      => '0',
      txAckF      => '0',
      peerTout    => '0',
      paramReject => '0',
      
      rssiParam   => (others => (others =>'0')),
      
      timeoutCntr => 0,
      resendCntr  => 0,
      --
      txBufferSize=> 1,
      txWindowSize=> 1,
      
      ---
      state  => CLOSED_S
      
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
     

   
begin

   comb : process (r, rst_i, connRq_i, rxRssiParam_i, synHeadSt_i, rxFlags_i, 
                   ackHeadSt_i, rstHeadSt_i, appRssiParam_i, rxValid_i, closeRq_i) is
      variable v : RegType;
   begin
      v := r;
      
 -- /////////////////////////////////////////////////////////
      ------------------------------------------------------------
      -- Connection FSM
      -- Synchronization and parameter negotiation
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
         --  Actively open connection 
         --  Propose parameters
         --  Accept parameters from server or close connection         
         ----------------------------------------------------------------------         
         when SEND_SYN_S =>
            
            v.connActive   := '0';
            v.closed       := '0';
            v.sndSyn       := '1'; 
            v.sndAck       := '0';
            v.sndRst       := '0';
            v.txAckF       := '0';
            v.peerTout     := '0';
            v.paramReject  := '0';
            v.timeoutCntr  :=  0;
            
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
            v.timeoutCntr  := r.timeoutCntr + 1;
            --            
            if (rxValid_i = '1' and rxFlags_i.syn = '1' and rxFlags_i.ack = '1') then
               -- Check parameters
               if (
                  rxRssiParam_i.version    = appRssiParam_i.version      and -- Version match
                  rxRssiParam_i.maxOutsSeg <= (2**WINDOW_ADDR_SIZE_G)    and -- Number of segments in a window
                  rxRssiParam_i.maxSegSize <= (2**SEGMENT_ADDR_SIZE_G)*8 and -- Number of bytes
                  rxRssiParam_i.chksumEn   = appRssiParam_i.chksumEn     and -- Checksum match
                  rxRssiParam_i.timeoutUnit= appRssiParam_i.timeoutUnit      -- Timeout unit match
               ) then
               
                  -- Accept the parameters from the server                  
                  v.rssiParam := rxRssiParam_i;
                  v.txBufferSize := conv_integer(rxRssiParam_i.maxSegSize(15 downto 3)); -- Divide by 8
                  v.txWindowSize := conv_integer(rxRssiParam_i.maxOutsSeg);
                  --
                  v.state := SEND_ACK_S;
               else
                  -- Reject parameters and reset the connection
                  v.paramReject  := '1';                  
                  v.rssiParam := r.rssiParam;
                  --
                  v.state := SEND_RST_S;
               end if;
            elsif (rxValid_i = '1' and rxFlags_i.rst = '1') then
               v.state := CLOSED_S;             
            elsif (r.timeoutCntr = RETRANS_TOUT_G * SAMPLES_PER_TIME_C) then
               if (r.resendCntr >= MAX_RETRANS_CNT_G) then
                  v.peerTout := '1';
                  v.state := CLOSED_S; 
               else
                  v.closed   := '1'; -- Signal closed to reset seqN (Resend SYN with the initial seqN)
                  v.resendCntr := r.resendCntr + 1;
                  v.state    := SEND_SYN_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when SEND_ACK_S =>
            --
            v.connActive   := '0';
            v.sndSyn       := '0'; 
            v.sndAck       := '1';
            v.sndRst       := '0';
            v.txAckF       := '1';
            v.timeoutCntr  :=  0;
            v.resendCntr   :=  0;
            v.paramReject  := '0';
            --
            v.rssiParam := r.rssiParam;
            
            -- 
            if (ackHeadSt_i = '1') then
               v.state := OPEN_S;
            end if;
                        
         ----------------------------------------------------------------------
         -- Server
         --  Passively open connection. Go to listen state and wait for SYN.
         --  Check clients parameters:
         --         If valid accept parameters,
         --         If not valid propose new parameters.
         ----------------------------------------------------------------------      
          when LISTEN_S =>
            --
            v.connActive   := '0';
            v.closed       := '0';
            v.sndSyn       := '0'; 
            v.sndAck       := '0';
            v.sndRst       := '0';
            v.txAckF       := '0';
            v.peerTout     := '0';
            v.timeoutCntr  :=  0;            
            -- 
            if (rxValid_i = '1' and rxFlags_i.syn = '1') then
               -- Check parameters
               if (
                  rxRssiParam_i.version    = appRssiParam_i.version      and   -- Version equality
                  rxRssiParam_i.maxOutsSeg <= (2**WINDOW_ADDR_SIZE_G)    and   -- Number of segments in a window
                  rxRssiParam_i.maxSegSize <= (2**SEGMENT_ADDR_SIZE_G)*8 and   -- Number of bytes
                  rxRssiParam_i.timeoutUnit= appRssiParam_i.timeoutUnit        -- Timeout unit match
               ) then
               
                  -- Accept the parameters from the client                 
                  v.rssiParam := rxRssiParam_i;
                  v.txBufferSize := conv_integer(rxRssiParam_i.maxSegSize(15 downto 3)); -- Divide by 8
                  v.txWindowSize := conv_integer(rxRssiParam_i.maxOutsSeg);
                  --
                  v.state := SEND_SYN_ACK_S;
               else
                  -- Propose different parameters              
                  v.rssiParam             := rxRssiParam_i;
                  v.rssiParam.version     := appRssiParam_i.version;                  
                  v.rssiParam.maxOutsSeg  := appRssiParam_i.maxOutsSeg;
                  v.rssiParam.maxSegSize  := appRssiParam_i.maxSegSize;
                  v.rssiParam.timeoutUnit := appRssiParam_i.timeoutUnit;
                  v.txBufferSize := conv_integer(appRssiParam_i.maxSegSize);
                  v.txWindowSize := conv_integer(appRssiParam_i.maxOutsSeg);
                  --
                  v.paramReject  := '1';
                  v.state := SEND_SYN_ACK_S;
               end if;
            end if;
         ---------------------------------------------------------------------            
         when SEND_SYN_ACK_S =>
            
            v.connActive   := '0';
            v.sndSyn       := '1'; 
            v.sndAck       := '0';
            v.sndRst       := '0';
            v.txAckF       := '1';
            v.paramReject  := '0';
            v.timeoutCntr  :=  0;
            
            -- Send the Server parameters
            v.rssiParam    := r.rssiParam;

            if (synHeadSt_i = '1') then
               v.state    := WAIT_ACK_S;
            end if;
 
         when WAIT_ACK_S =>

            v.connActive   := '0';
            v.sndSyn       := '0'; 
            v.sndAck       := '0';
            v.sndRst       := '0';
            v.txAckF       := '0';
            v.paramReject  := '0';
            --            
            v.timeoutCntr  := r.timeoutCntr+1;
            
            -- 
            v.rssiParam    := r.rssiParam;
            
            if (rxValid_i = '1' and rxFlags_i.ack = '1') then
               v.state := OPEN_S;
            elsif (rxValid_i = '1' and rxFlags_i.rst = '1') then
               v.state := CLOSED_S;
            elsif (r.timeoutCntr = RETRANS_TOUT_G * SAMPLES_PER_TIME_C) then
               if (r.resendCntr >= MAX_RETRANS_CNT_G) then
                  v.peerTout := '1';
                  v.state := CLOSED_S; 
               else
                  v.closed   := '1'; -- Signal closed to reset seqN (Resend SYN with the initial seqN)
                  v.resendCntr := r.resendCntr + 1;
                  v.state    := SEND_SYN_ACK_S;
               end if;
            end if;

         ----------------------------------------------------------------------           
         -- Open connection
         --
         --
         ----------------------------------------------------------------------
         when OPEN_S =>
            --
            v.connActive   := '1';
            v.sndSyn       := '0'; 
            v.sndAck       := '0';
            v.sndRst       := '0';
            v.txAckF       := '1';
            v.paramReject  := '0';
            --
            v.timeoutCntr  :=  0;
            v.resendCntr   :=  0;
            --
            v.rssiParam := r.rssiParam;
            
            -- 
            if (rxValid_i = '1' and rxFlags_i.rst = '1') then
               v.state := SEND_RST_S;
            elsif (closeRq_i = '1') then
               v.state := SEND_RST_S;
            end if;
         
         ----------------------------------------------------------------------           
         -- Reset the connection
         -- - Send Rst segment 
         -- - Go to Closed
         ----------------------------------------------------------------------
         when SEND_RST_S =>
            --
            v.connActive   := r.connActive;
            v.sndSyn       := '0'; 
            v.sndAck       := '0';
            v.sndRst       := '1';
            v.txAckF       := '0';
            v.paramReject  := '0';
            --
            v.rssiParam := r.rssiParam;
            
            -- 
            if (rstHeadSt_i = '1') then
               v.state := CLOSED_S;
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
   rssiParam_o  <= r.rssiParam;
   connActive_o <= r.connActive;
   sndSyn_o     <= r.sndSyn; 
   sndAck_o     <= r.sndAck;
   sndRst_o     <= r.sndRst;
   txAckF_o     <= r.txAckF;
   
   -- Parameters for receiver (have to be correctly set by the app)
   rxBufferSize_o <= conv_integer(appRssiParam_i.maxSegSize(15 downto 3)); -- Divide by 8
   rxWindowSize_o <= conv_integer(appRssiParam_i.maxOutsSeg);
   -- Parameters for transmitter are received by the peer and checked by FSM 
   txBufferSize_o <= r.txBufferSize;
   txWindowSize_o <= r.txWindowSize;
   closed_o <= r.closed;
   -- 
   peerTout_o    <= r.peerTout;
   paramReject_o <= r.paramReject;
   ---------------------------------------------------------------------
end architecture rtl;