-------------------------------------------------------------------------------
-- File       : Monitor.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-08-09
-- Last update: 2016-01-27
-------------------------------------------------------------------------------
-- Description: 
--  Handles RSSI counters, timeouts, and statuses:
--  - Re-transmission timeout and request,
--  - NULL segment transmission (Client),
--  - NULL timeout detection (Server),
--  - Acknowledgment timeout and request,
--  - Valid segment counter,
--  - Dropped segment counter.   
-- 
--  Status register:
--    statusReg_o(0) : Connection Active          
--    statusReg_o(1) : Maximum retransmissions exceeded r.retransMax and
--    statusReg_o(2) : Null timeout reached (server) r.nullTout;
--    statusReg_o(3) : Error in acknowledgment mechanism   
--    statusReg_o(4) : SSI Frame length too long
--    statusReg_o(5) : Connection to peer timed out
--    statusReg_o(6) : Client rejected the connection (parameters out of range)
--                     Server proposed new parameters (parameters out of range)
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.RssiPkg.all;

entity Monitor is
   generic (
      TPD_G               : time     := 1 ns;
      TIMEOUT_UNIT_G      : real     := 1.0E-6; -- us
      CLK_FREQUENCY_G     : real     := 100.0E6; 
      SERVER_G            : boolean  := true;
      WINDOW_ADDR_SIZE_G  : positive := 7;
      STATUS_WIDTH_G      : positive := 6;
      CNT_WIDTH_G         : positive := 32;
      RETRANSMIT_ENABLE_G : boolean := true
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
      rxDrop_i       : in sl;
      
      --
      ackHeadSt_i    : in sl;
      rstHeadSt_i    : in sl;
      dataHeadSt_i   : in sl;
      nullHeadSt_i   : in sl;

      -- Internal Errors and Timeouts       
      lenErr_i       : in sl;      
      ackErr_i       : in sl;      
      peerConnTout_i : in sl;      
      paramReject_i  : in sl;
      
      -- Packet transmission requests
      sndResend_o     : out  sl;
      sndNull_o       : out  sl;
      sndAck_o        : out  sl;
          
      -- Connection close request
      closeRq_o    : out  sl;

      -- Internal statuses
      statusReg_o : out slv(STATUS_WIDTH_G  downto 0);
      dropCnt_o   : out slv(CNT_WIDTH_G-1  downto 0);
      validCnt_o  : out slv(CNT_WIDTH_G-1  downto 0);
      resendCnt_o : out slv(CNT_WIDTH_G-1  downto 0);
      reconCnt_o  : out slv(CNT_WIDTH_G-1  downto 0)
   );
end entity Monitor;

architecture rtl of Monitor is
   --
   constant SAMPLES_PER_TIME_C : integer := integer(TIMEOUT_UNIT_G * CLK_FREQUENCY_G);
   constant SAMPLES_PER_TIME_DIV3_C : integer := integer(TIMEOUT_UNIT_G * CLK_FREQUENCY_G)/3;
   --  
   type RegType is record
      -- Retransmission
      retransToutCnt : slv(rssiParam_i.retransTout'left + bitSize(SAMPLES_PER_TIME_C) downto 0);
      sndResend      : sl;
      sndResendD1    : sl;
      retransCnt     : slv(rssiParam_i.maxRetrans'left + bitSize(SAMPLES_PER_TIME_C) downto 0);
      retransMax     : sl;
      
      -- Null packet send/timeout
      nullToutCnt : slv(rssiParam_i.nullSegTout'left + bitSize(SAMPLES_PER_TIME_C) downto 0);      
      sndNull     : sl;
      nullTout    : sl;
      
      -- Ack packet cumulative/timeout
      ackToutCnt  : slv(rssiParam_i.nullSegTout'left + bitSize(SAMPLES_PER_TIME_C) downto 0);
      lastAckSeqN : slv(7 downto 0);      
      sndAck      : sl;
      
      -- For detecting rising edge on connActive
      connActiveD1 : sl;
      
      --
      status      : slv(STATUS_WIDTH_G - 1 downto 0);
      validCnt    : slv(CNT_WIDTH_G - 1 downto 0);
      dropCnt     : slv(CNT_WIDTH_G - 1 downto 0);
      reconCnt    : slv(CNT_WIDTH_G - 1 downto 0);
      resendCnt   : slv(CNT_WIDTH_G - 1 downto 0);
   --
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
      sndAck      => '0',
      
      -- For detecting rising edge on connActive
      connActiveD1  => '0',
      
      -- Statuses
      status      => (others=>'0'),
      validCnt    => (others=>'0'),
      dropCnt     => (others=>'0'),
      reconCnt    => (others=>'0'),
      resendCnt   => (others=>'0')   
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   signal s_status : slv(STATUS_WIDTH_G - 1 downto 0); 
   --
begin
   -- Status assignment
   s_status(0) <= r.retransMax and r.sndResend and not r.sndResendD1;
   s_status(1) <= r.nullTout;
   s_status(2) <= ackErr_i;   
   s_status(3) <= lenErr_i;
   s_status(4) <= peerConnTout_i;
   s_status(5) <= paramReject_i;   
   
   comb : process (r, rst_i, rxFlags_i, rssiParam_i, rxValid_i, rxDrop_i, dataHeadSt_i, rstHeadSt_i, nullHeadSt_i, ackHeadSt_i, 
                   connActive_i, rxLastSeqN_i, rxWindowSize_i, txBufferEmpty_i, s_status) is
      variable v : RegType;
   begin
      v := r;
      
      -- DFF the connActive for rising edge detection    
      v.connActiveD1 := connActive_i;  
        
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
          txBufferEmpty_i = '1' or
          RETRANSMIT_ENABLE_G = false -- Disable retransmissions
      ) then
         v.retransToutCnt := (others=>'0');
      else
         v.retransToutCnt := r.retransToutCnt+1;         
      end if; 
      
      -- Resend request SRFF 
      if (connActive_i = '0' or
         (rxValid_i = '1' and rxFlags_i.busy = '1') or
          dataHeadSt_i = '1' or
          rstHeadSt_i  = '1' or
          nullHeadSt_i = '1' or
          txBufferEmpty_i = '1'
      ) then
         v.sndResend := '0';  
      elsif (r.retransToutCnt >= (conv_integer(rssiParam_i.retransTout)*SAMPLES_PER_TIME_C) ) then
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
          nullHeadSt_i = '1' or
          ackHeadSt_i  = '1' or
          RETRANSMIT_ENABLE_G = false -- Disable null packet transmission  
      ) then
         v.nullToutCnt := (others=>'0');
      else
         v.nullToutCnt := r.nullToutCnt+1;         
      end if;
      
      -- Null request SRFF 
      if (connActive_i = '0' or
          dataHeadSt_i = '1' or
          rstHeadSt_i  = '1' or
          nullHeadSt_i = '1') then
          v.sndNull := '0'; 
      elsif (r.nullToutCnt >= (conv_integer(rssiParam_i.nullSegTout) * SAMPLES_PER_TIME_DIV3_C)  ) then -- send null segments if timeout/2 reached
         v.sndNull := '1';
      end if;
      
      -- Timeout not applicable
      v.nullTout := '0';
      
   -- Null timeout (Server)
   else
      -- Null timeout counter
      if (connActive_i = '0' or
         (rxValid_i = '1' and rxFlags_i.data = '1') or 
         (rxValid_i = '1' and rxFlags_i.nul  = '1') or
         (rxValid_i = '1' and rxFlags_i.ack  = '1') or
         (rxValid_i = '1' and rxFlags_i.busy = '1') or
         RETRANSMIT_ENABLE_G = false -- Disable null timeout         
      ) then
         v.nullToutCnt := (others=>'0');
      else
         v.nullToutCnt := r.nullToutCnt+1;         
      end if;
      
      -- Null timeout SRFF
      if (connActive_i = '0') then
         v.nullTout := '0'; 
      elsif (r.nullToutCnt >= (conv_integer(rssiParam_i.nullSegTout) * SAMPLES_PER_TIME_C)  ) then
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
       nullHeadSt_i  = '1' or
       rstHeadSt_i   = '1'
   ) then
      v.sndAck := '0';
      
   -- Timeout acknowledgment request
   elsif (r.ackToutCnt >= (conv_integer(rssiParam_i.cumulAckTout)* SAMPLES_PER_TIME_C)) then
      v.sndAck := '1';
      
   -- Cumulative acknowledgment request
   elsif ((rxLastSeqN_i - r.lastAckSeqN) >= rssiParam_i.maxCumAck) then
      v.sndAck := '1';
      
   -- Null segment ACK as soon as NUL received
   elsif (rxValid_i = '1' and rxFlags_i.nul  = '1') then
      v.sndAck := '1';
   end if;
   
   -- /////////////////////////////////////////////////////////
   ------------------------------------------------------------
   -- Status register and valid and drop counters
   ------------------------------------------------------------   
   -- /////////////////////////////////////////////////////////
   
   -- Register statuses until new connection is established
   if (connActive_i = '1' and r.connActiveD1 = '0') then
      v.status := (others=>'0');
   elsif (s_status /= (s_status'range => '0') ) then       
      v.status := r.status or s_status;        
   end if;
   
   -- Count valid packets
   if (connActive_i = '1' and r.connActiveD1 = '0') then
      v.validCnt := (others=>'0');
   elsif (rxValid_i = '1') then       
      v.validCnt := r.validCnt+1;        
   end if;
   
   -- Count dropped packets
   if (connActive_i = '1' and r.connActiveD1 = '0') then
      v.dropCnt := (others=>'0');
   elsif (rxDrop_i = '1') then       
      v.dropCnt := r.dropCnt+1;        
   end if;
   
   -- Count all retransmissions within the active connection
   if (connActive_i = '1' and r.connActiveD1 = '0') then
      v.resendCnt := (others=>'0');
   elsif (r.sndResend  = '1' and r.sndResendD1  = '0') then -- Rising edge       
      v.resendCnt := r.resendCnt+1;        
   end if;
   
   -- Count all reconnections from reset
   if (connActive_i = '1' and r.connActiveD1 = '0') then
      v.reconCnt := r.reconCnt+1;        
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
                  r.nullTout or  -- Close connection when null timeouts
                  ackErr_i or    -- Close if acknowledgment error occurs
                  lenErr_i;   -- Close if SSI input frame length error occurs
   statusReg_o <= r.status & connActive_i;
   dropCnt_o   <= r.dropCnt;
   validCnt_o  <= r.validCnt;
   resendCnt_o <= r.resendCnt;
   reconCnt_o  <= r.reconCnt;
   ---------------------------------------------------------------------
end architecture rtl;