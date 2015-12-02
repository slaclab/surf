-------------------------------------------------------------------------------
-- Title      : Handels RSSI counters and timeouts.
-------------------------------------------------------------------------------
-- File       : Monitor.vhd
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

entity Monitor is
   generic (
      TPD_G          : time     := 1 ns;
      SERVER_G       : boolean  := true;
      WINDOW_ADDR_SIZE_G  : positive := 7
      -- 
   );
   port (
      clk_i      : in  sl;
      rst_i      : in  sl;
      
      -- Connection FSM indicating active connection      
      connActive_i : in  sl;

      -- Timeout and counter values
      rssiParam_i  : in  RssiParamType;
      
      -- Flags from Rx module
      rxFlags_i    : in FlagsType;
      
      -- 
      rxLastSeqN_i   : in slv(7 downto 0);
      rxWindowSize_i : in integer range 1 to 2 ** (WINDOW_ADDR_SIZE_G);
      
      -- Do not request resend if tx buffer empty
      txBufferEmpty_i : in sl;
      
      -- Valid received packet
      rxValid_i      : in sl;
      
      --
      ackHeadSt_i    : in sl;
      rstHeadSt_i    : in sl;
      dataHeadSt_i   : in sl;
      nullHeadSt_i   : in sl;      

      -- Packet transmission requests
      sndResend_o     : out  sl;
      sndNull_o       : out  sl;
      sndAck_o        : out  sl;
      
      -- Connection close request
      closeRq_o    : out  sl   
   );
end entity Monitor;

architecture rtl of Monitor is

     
   type RegType is record
      -- Retransmission
      retransToutCnt : slv(rssiParam_i.retransTout'range);
      sndResend      : sl;
      sndResendD1    : sl;
      retransCnt     : slv(rssiParam_i.maxRetrans'range);
      retransMax     : sl;
      
      -- Null packet send/timeout
      nullToutCnt : slv(rssiParam_i.nullSegTout'range);      
      sndNull     : sl;
      nullTout    : sl;
      
      -- Ack packet cumulative/timeout
      ackToutCnt  : slv(rssiParam_i.nullSegTout'range);
      lastAckSeqN : slv(7 downto 0);      
      sndAck      : sl;
      
   end record RegType;

   constant REG_INIT_C : RegType := (
      -- Retransmission
      retransToutCnt    => (others=>'0'),
      sndResend         => '0',
      sndResendD1       => '0',
      retransCnt        => (others=>'0'),
      retransMax        => '0',
      
      -- Null packet send/timeout
      nullToutCnt => (others=>'0'),     
      sndnull     => '0',
      nullTout    => '0',
      
      -- Ack packet cumulative/timeout
      ackToutCnt  => (others=>'0'),     
      lastAckSeqN => (others=>'0'),   
      sndAck      => '0' 
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (r, rst_i, rxFlags_i, rssiParam_i, rxValid_i, dataHeadSt_i, rstHeadSt_i, nullHeadSt_i, ackHeadSt_i, 
                   connActive_i, rxLastSeqN_i, rxWindowSize_i, txBufferEmpty_i) is
      variable v : RegType;
   begin
      v := r;
      
   -- /////////////////////////////////////////////////////////
   ------------------------------------------------------------
   -- Retransmission timeout 
   ------------------------------------------------------------   
   -- /////////////////////////////////////////////////////////
   
      -- Retransmission Timeout counter
      if (connActive_i = '0' or
          r.sndResend  = '1' or
          (rxValid_i = '1' and rxFlags_i.busy = '1') or
          dataHeadSt_i = '1' or
          rstHeadSt_i  = '1' or
          nullHeadSt_i = '1' or
          txBufferEmpty_i = '1'
      ) then
         v.retransToutCnt := (others=>'0');
      else
         v.retransToutCnt := r.retransToutCnt+1;         
      end if; 
      
      -- Resend request SRFF 
      if (connActive_i = '0' or
          dataHeadSt_i = '1' or 
          rstHeadSt_i  = '1' or 
          nullHeadSt_i = '1'
      ) then
         v.sndResend := '0';  
      elsif (r.retransToutCnt >= rssiParam_i.retransTout) then
         v.sndResend := '1';
      
      end if;
      
      -- Pipeline sndResend for edge detection
      v.sndResendD1 := r.sndResend;
      
   -- /////////////////////////////////////////////////////////
   ------------------------------------------------------------
   -- Retransmission counter 
   ------------------------------------------------------------   
   -- /////////////////////////////////////////////////////////
      -- Counter of consecutive retransmissions
      -- Reset when connection is broken or a valid ACK is received
      if (connActive_i = '0' or
         (rxValid_i = '1' and rxFlags_i.ack = '1')
      ) then
         v.retransCnt := (others=>'0');
      elsif (r.sndResend  = '1' and r.sndResendD1  = '0') then -- Rising edge
         v.retransCnt := r.retransCnt+1;         
      end if;

      -- Retransmission exceeded close connection request SRFF 
      if (connActive_i = '0' or
         (rxValid_i = '1' and rxFlags_i.ack = '1')
      ) then
         v.retransMax := '0'; 
      elsif (r.retransCnt >= rssiParam_i.maxRetrans) then
         v.retransMax := '1';
      end if;
      
   -- /////////////////////////////////////////////////////////
   ------------------------------------------------------------
   -- Null Segment transmit/timeout 
   ------------------------------------------------------------   
   -- /////////////////////////////////////////////////////////
   
   -- Null Segment transmission (Client)
   if (SERVER_G = false) then
      -- Null transmission counter
      if (connActive_i = '0' or
          dataHeadSt_i = '1' or
          rstHeadSt_i  = '1' or
          nullHeadSt_i = '1'
      ) then
         v.nullToutCnt := (others=>'0');
      else
         v.nullToutCnt := r.nullToutCnt+1;         
      end if;
      
      -- Null request SRFF 
      if (connActive_i = '0' or 
          nullHeadSt_i = '1') then
         v.sndNull := '0';  
      elsif (r.nullToutCnt >= '0' & rssiParam_i.nullSegTout(rssiParam_i.nullSegTout'left downto 1)) then -- send null segments if timeout/2 reached
         v.sndNull := '1';
      end if;
      
      -- Timeout not applicable
      v.nullTout := '0';
      
   -- Null timeout (Server)
   else
      -- Null timeout counter
      if (connActive_i = '0' or
         (rxValid_i = '1' and rxFlags_i.data = '1') or 
         (rxValid_i = '1' and rxFlags_i.nul  = '1')
      ) then
         v.nullToutCnt := (others=>'0');
      else
         v.nullToutCnt := r.nullToutCnt+1;         
      end if;
      
      -- Null timeout SRFF
      if (connActive_i = '0') then
         v.nullTout := '0'; 
      elsif (r.nullToutCnt >= rssiParam_i.nullSegTout) then
         v.nullTout := '1';
      end if;

      -- Null sending not applicable
      v.sndNull := '0';
   end if;

   -- /////////////////////////////////////////////////////////
   ------------------------------------------------------------
   -- Acknowledgment cumulative/timeout 
   ------------------------------------------------------------   
   -- /////////////////////////////////////////////////////////
   
   -- Ack seqN registering when it is sent
   if (connActive_i = '0') then
      v.lastAckSeqN := rxLastSeqN_i;
   elsif (
      ackHeadSt_i  = '1' or
      dataHeadSt_i = '1' or
      rstHeadSt_i  = '1' or
      nullHeadSt_i = '1'
   ) then
      v.lastAckSeqN := rxLastSeqN_i;
   else
      v.lastAckSeqN := r.lastAckSeqN; 
   end if;    

   -- Timeout counter
   if (connActive_i = '0' or
       ackHeadSt_i  = '1' or
       dataHeadSt_i = '1' or
       rstHeadSt_i  = '1' or
       nullHeadSt_i = '1' or
      (rxLastSeqN_i - r.lastAckSeqN) = 0          
   ) then
      v.ackToutCnt := (others=>'0');
   elsif (
     (rxLastSeqN_i - r.lastAckSeqN) > 0   and 
     (rxLastSeqN_i - r.lastAckSeqN) <= rxWindowSize_i
   ) then       
      v.ackToutCnt := r.ackToutCnt+1;         
   end if; 
   
   -- Ack packet request SRFF 
   if (connActive_i  = '0' or
       ackHeadSt_i   = '1' or 
       dataHeadSt_i  = '1' or 
       nullHeadSt_i  = '1'
   ) then
      v.sndAck := '0';
      
   -- Timeout acknowledgment request
   elsif (r.ackToutCnt >= rssiParam_i.cumulAckTout) then
      v.sndAck := '1';
      
   -- Cumulative acknowledgment request
   elsif ((rxLastSeqN_i - r.lastAckSeqN) >= rssiParam_i.maxCumAck) then
      v.sndAck := '1';
   end if;
   
   -- /////////////////////////////////////////////////////////
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
   ---------------------------------------------------------------------
   sndResend_o <= r.sndResend and not r.retransMax; -- Request retransmission if max retransmissions not reached
   sndNull_o   <= r.sndNull;
   sndAck_o    <= r.sndAck;
   closeRq_o   <= (r.retransMax and r.sndResend and not r.sndResendD1) or -- Close connection when exceeded resend is requested
                  r.nullTout;   -- Close connection when null timeouts
   ---------------------------------------------------------------------
end architecture rtl;