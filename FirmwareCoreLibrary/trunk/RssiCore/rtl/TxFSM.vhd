-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : TxFSM.vhd
-- Author     : Uros Legat  <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory (Cosylab)
-- Created    : 2015-08-09
-- Last update: 2015-08-09
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--             
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.RssiPkg.all;
use work.SsiPkg.all;
use work.AxiStreamPkg.all;

entity TxFSM is
   generic (
      TPD_G              : time     := 1 ns;
      
      WINDOW_ADDR_SIZE_G  : positive := 7;      -- 2^WINDOW_ADDR_SIZE_G  = Number of segments
 
      SYN_HEADER_SIZE_G  : natural := 24;
      ACK_HEADER_SIZE_G  : natural := 8;
      EACK_HEADER_SIZE_G : natural := 8;
      RST_HEADER_SIZE_G  : natural := 8;
      NULL_HEADER_SIZE_G : natural := 8;
      DATA_HEADER_SIZE_G : natural := 8
   );
   port (
      clk_i      : in  sl;
      rst_i      : in  sl;
      
      -- Connection FSM indicating active connection
      connActive_i   : in  sl;
      
      -- Various segment requests
      txSyn_i        : in  sl;
      txAck_i        : in  sl;
      txRst_i        : in  sl;
      txData_i       : in  sl;
      txResend_i     : in  sl;
      txNull_i       : in  sl;   
      
  
      -- Data buffer read port
      rdDataAddr_o     : out  slv( (SEGMENT_ADDR_SIZE_C+WINDOW_ADDR_SIZE_G)-1 downto 0);
      rdHeaderAddr_o   : out  slv(7 downto 0);
      
      -- Buffer window array control input
      we_o         : out sl; -- must be one cc long
      sent_o       : out sl; -- must be one cc long
      
      -- Indicating that the FSM is ready to send new segment
      txRdy_o      : out sl;

      -- Initial sequence number
      initSeqN_i   : in slv(7 downto 0);

      -- Next sequence number
      nextSeqN_o   : out slv(7 downto 0);
     
      -- Inputs from txBuffer
      windowArray_i    : in WindowTypeArray(0 to 2 ** (WINDOW_ADDR_SIZE_G)-1);
      windowSize_i     : in integer range 0 to 2 ** (WINDOW_ADDR_SIZE_G-1);
      bufferFull_i     : in sl;
      firstUnackAddr_i : in slv(WINDOW_ADDR_SIZE_G-1 downto 0);
      nextSentAddr_i   : in slv(WINDOW_ADDR_SIZE_G-1 downto 0);
      lastSentAddr_i   : in slv(WINDOW_ADDR_SIZE_G-1 downto 0);
      ssiBusy_i        : in sl;
      
      -- Tx data (input to header decoder module)
      txSeqN_o     : out slv(7 downto 0);
      
      -- FSM outs for header and data flow control
      synHeadSt_o  : out  sl;
      ackHeadSt_o  : out  sl;
      dataHeadSt_o : out  sl;
      dataSt_o     : out  sl;
      rstHeadSt_o  : out  sl;
      nullHeadSt_o : out  sl;
      
      -- Checksum control
      chksumValid_i : in   sl;
      chksumEnable_o: out  sl;
      chksumStrobe_o: out  sl;
      
      headerLength_i: in   positive;
      
      -- Data mux sources
      headerData_i : in slv(RSSI_WORD_WIDTH_C*8-1 downto 0);
      chksumData_i : in slv(15 downto 0);
      bufferData_i : in slv(RSSI_WORD_WIDTH_C*8-1 downto 0);
      
      -- SSI Transport side interface
      tspSsiSlave_i  : in   SsiSlaveType;
      tspSsiMaster_o : out  SsiMasterType
      
   );
end entity TxFSM;

architecture rtl of TxFSM is
   -- Init SSI bus
   constant SSI_MASTER_INIT_C : SsiMasterType := axis2SsiMaster(RSSI_AXI_CONFIG_C, AXI_STREAM_MASTER_INIT_C);
   
   type stateType is (
      --
      INIT_S,
      CONN_S,
      --
      SYN_H_S,
      ACK_H_S,
      RST_H_S,
      NULL_H_S,
      DATA_H_S,
      DATA_S,
      DATA_SENT_S,
      --
      RST_WE_S,
      DATA_WE_S,
      NULL_WE_S,
      --
      RESEND_INIT_S,
      RESEND_S,
      RESEND_H_S,
      RESEND_DATA_S,
      RESEND_PP_S
   );
   
   type RegType is record
      -- Counters
      nextSeqN       : slv(7 downto 0);
      seqN           : slv(7 downto 0);
      headerAddr     : slv(7 downto 0);
      segmentAddr    : slv(SEGMENT_ADDR_SIZE_C downto 0);
      bufferAddr     : slv(WINDOW_ADDR_SIZE_G-1  downto 0);
      
      -- Data mux flags
      synH  : sl;
      ackH  : sl;      
      rstH  : sl;
      nullH : sl;
      dataH : sl;
      dataD : sl;

      -- Varionus controls
      txRdy    : sl;
      buffWe   : sl;
      buffSent : sl;
      chkEn    : sl;
      chkStb    : sl;
      
      -- SSI master
      ssiMaster      : SsiMasterType;
      ssiMasterD1    : SsiMasterType;
      
      -- State Machine
      State       : StateType;    
   end record RegType;

   constant REG_INIT_C : RegType := (
      --   
      nextSeqN    => (others => '0'),
      seqN        => (others => '0'),
      headerAddr  => (others => '0'),
      segmentAddr => (others => '0'),
      bufferAddr  => (others => '0'),
      
      --
      synH     => '0',      
      ackH     => '0',
      rstH     => '0',
      nullH    => '0',
      dataH    => '0',
      dataD    => '0',
      --
      txRdy    => '0',      
      buffWe   => '0',
      buffSent => '0',
      chkEn    => '0',
      chkStb    => '0',
      
      -- SSI master 
      ssiMaster   => SSI_MASTER_INIT_C,
      ssiMasterD1 => SSI_MASTER_INIT_C,
      -- State Machine
      State     => INIT_S
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
begin

   ----------------------------------------------------------------------------------------------- 
   comb : process (r, rst_i, nextSentAddr_i,lastSentAddr_i, txSyn_i, txAck_i, connActive_i, txRst_i, ssiBusy_i, initSeqN_i, windowSize_i, firstUnackAddr_i,
                   bufferFull_i, txData_i, txResend_i, txNull_i, tspSsiSlave_i, headerData_i, chksumData_i, bufferData_i, windowArray_i, chksumValid_i, headerLength_i) is
      
      variable v : RegType;

   begin
      v := r;
      
      v.ssiMasterD1 := r.ssiMaster;
      
      ------------------------------------------------------------
      -- TX FSM
      ------------------------------------------------------------      
      case r.state is
         ----------------------------------------------------------------------
         when INIT_S =>
            -- Counters
            v.nextSeqN    := initSeqN_i;
            v.seqN        := r.nextSeqN;
            
            v.headerAddr  := (others => '0');
            v.segmentAddr := (others => '0');
             
            v.bufferAddr := nextSentAddr_i;
            --
            v.synH     := '0';
            v.ackH     := '0';
            v.rstH     := '0';
            v.nullH    := '0';
            v.dataH    := '0';
            v.dataD    := '0';
            --
            v.txRdy    := '1';
            v.buffWe   := '0';
            v.buffSent := '0';
            v.chkEn    := '0';
            v.chkStb    := '0';
            
            v.ssiMaster:= SSI_MASTER_INIT_C;          
            
            -- Next state condition   
            if    (txSyn_i = '1') then
               v.state    := SYN_H_S;
               v.synH     := '1';
            elsif (txAck_i = '1') then
               v.state    := ACK_H_S;
               v.ackH     := '1';
            elsif (connActive_i = '1') then
               v.state      := CONN_S;
               -- Increase the sequence number to point to next seqN.
               --(This seqN will belong to the next Data, Null, or Rst segment).
               v.nextSeqN   := r.nextSeqN + 1;
            end if;
         ----------------------------------------------------------------------
         when CONN_S =>
            -- Counters 
            v.nextSeqN    := r.nextSeqN;
            v.seqN        := r.nextSeqN;
            
            v.headerAddr  := (others => '0');
            v.segmentAddr := (others => '0');
             
            v.bufferAddr := nextSentAddr_i;
            --
            v.synH     := '0';
            v.ackH     := '0';
            v.rstH     := '0';
            v.nullH    := '0';       
            v.dataH    := '0';
            v.dataD    := '0';
            --
            v.txRdy    := '1';
            v.buffWe   := '0';          
            v.buffSent := '0';
            v.chkEn    := '0';
            v.chkStb    := '0';
            
            v.ssiMaster:=SSI_MASTER_INIT_C;
            
            -- Next state condition   
            if    (txRst_i = '1' and bufferFull_i = '0' and ssiBusy_i = '0') then
               v.state    := RST_WE_S;
            elsif (txData_i = '1' and bufferFull_i = '0') then
               v.state    := DATA_WE_S;
            elsif (txResend_i = '1') then               
               v.state    := RESEND_INIT_S;
            elsif (txAck_i = '1') then
               v.ackH     := '1';
               v.state    := ACK_H_S;  
            elsif (txNull_i = '1' and bufferFull_i = '0' and ssiBusy_i = '0') then   
               v.state    := NULL_WE_S;         
            elsif (connActive_i = '0') then
               v.state    := INIT_S;
            end if;
         ----------------------------------------------------------------------
         -- SYN packet
         ----------------------------------------------------------------------
         when SYN_H_S =>
            -- Counters
            v.nextSeqN    := r.nextSeqN;
            v.seqN        := r.nextSeqN;
            
            v.segmentAddr := (others => '0');
            v.bufferAddr := nextSentAddr_i;
            --
            v.synH     := '1';  -- Send SYN header
            v.ackH     := '0';
            v.rstH     := '0';
            v.nullH    := '0';       
            v.dataH    := '0';
            v.dataD    := '0';
            --
            v.txRdy    := '0';
            v.buffWe   := '0';
            v.buffSent := '0';
            v.chkEn    := '1';
            
            -- SSI parameters
            v.ssiMaster.strb   := (others => '1');
            v.ssiMaster.keep   := (others => '1');
            v.ssiMaster.dest   := (others => '0');
            v.ssiMaster.eof    := '0';
            v.ssiMaster.eofe   := '0';
            
            -- SSI data (send header part)
            v.ssiMaster.data(RSSI_WORD_WIDTH_C*8-1 downto 0) := headerData_i;
            
            -- Send SOF with header address 0
            if (r.headerAddr = (r.headerAddr'range => '0')) then
               v.ssiMaster.sof   := '1';
            else
               v.ssiMaster.sof   := '0';
            end if;
            
            -- Next state condition
            -- End of header
            if (r.headerAddr = headerLength_i-1) then

              -- End checksum calculation
               v.ssiMaster.valid  := '0';

               -- Wait until checksum is and Transport layer ready
               if (tspSsiSlave_i.ready = '1' and chksumValid_i = '1') then 
                  -- Add checksum to last 16 bits
                  v.ssiMaster.data(15 downto 0) := chksumData_i;
                  v.ssiMaster.valid  := '1';                
                  v.ssiMaster.eof    := '1';
                  v.ssiMaster.eofe   := '0';

                  -- Next state            
                  v.state   := INIT_S;
               end if;
               v.headerAddr       := r.headerAddr;
               
            -- Increment address only when Slave is ready
            elsif (tspSsiSlave_i.ready = '1') then
               v.headerAddr       := r.headerAddr + 1;
               v.ssiMaster.valid  := '1';
               v.chkStb           := '1';
            else 
               v.headerAddr       := r.headerAddr;
               v.ssiMaster.valid  := '0';
               v.chkStb           := '0';  
            end if; 

         ----------------------------------------------------------------------
         -- ACK packet
         ----------------------------------------------------------------------         
         when ACK_H_S =>
            -- Counters
            v.nextSeqN    := r.nextSeqN;
            v.seqN        := r.nextSeqN;
            
            v.segmentAddr := (others => '0');
            v.bufferAddr  := nextSentAddr_i;
            v.headerAddr  := (others => '0');
            
            --
            v.synH     := '0';
            v.ackH     := '1';  -- Send ack header
            v.rstH     := '0';
            v.nullH    := '0';       
            v.dataH    := '0';
            v.dataD    := '0';
            --
            v.txRdy    := '0';
            v.buffWe   := '0';          
            v.buffSent := '0';
            v.chkEn    := '1';
            v.chkStb   := '1';            
            
            -- SSI Master init (if not ready)
            v.ssiMaster := SSI_MASTER_INIT_C;

            -- Next state condition
            if (chksumValid_i = '1' and tspSsiSlave_i.ready = '1') then
               -- Frame size is one word SOF and EOF
               v.ssiMaster.sof    := '1';
               v.ssiMaster.valid  := '1';
               v.ssiMaster.strb   := (others => '1');
               v.ssiMaster.keep   := (others => '1');
               v.ssiMaster.dest   := (others => '0');
               v.ssiMaster.eof    := '1';
               v.ssiMaster.eofe   := '0';
               v.ssiMaster.data(RSSI_WORD_WIDTH_C*8-1 downto 0) := headerData_i;
               v.ssiMaster.data(15 downto 0) := chksumData_i; -- Add header to last two bytes
            
               if  connActive_i = '0' then          
                  v.state   := INIT_S; 
               else
                  v.state   := CONN_S; 
               end if;
            end if;
         ----------------------------------------------------------------------
         -- RST packet
         ----------------------------------------------------------------------         
         when RST_WE_S =>
            -- Counters
            v.nextSeqN    := r.nextSeqN;
            v.seqN        := r.nextSeqN;
            
            v.headerAddr  := (others => '0');
            v.segmentAddr := (others => '0');
             
            v.bufferAddr := nextSentAddr_i;
            -- State control signals 
            v.synH     := '0';
            v.ackH     := '0';
            v.rstH     := '1';  -- Send reset header 
            v.nullH    := '0';       
            v.dataH    := '0';
            v.dataD    := '0';
            -- 
            v.txRdy    := '0';
            v.buffWe   := '1';  -- Update buffer seqN and Type
            v.buffSent := '0';
            v.chkEn    := '0';
            v.chkStb   := '0';
            
            -- SSI master 
            v.ssiMaster := SSI_MASTER_INIT_C;
            
            -- Next state condition
            v.state   := RST_H_S;
         ----------------------------------------------------------------------
         when RST_H_S =>
          -- 
            v.nextSeqN    := r.nextSeqN;
            v.seqN        := r.nextSeqN;

            v.segmentAddr := (others => '0');
            v.bufferAddr := nextSentAddr_i;
            v.headerAddr  := (others => '0');
            
            -- Flags
            v.synH     := '0';
            v.ackH     := '0';
            v.rstH     := '1';  -- Send reset header 
            v.nullH    := '0';       
            v.dataH    := '0';
            v.dataD    := '0';
            --
            v.txRdy    := '0';
            v.buffWe   := '0';          
            v.buffSent := '0';
            v.chkEn    := '1';
            v.chkStb   := '1';
            
            -- SSI Master init (if not ready)
            v.ssiMaster := SSI_MASTER_INIT_C;

            -- Next state condition
            if (chksumValid_i = '1' and tspSsiSlave_i.ready = '1') then -- Frame size is one word
               
               -- Increment seqN
               v.nextSeqN    := r.nextSeqN+1; -- Increment SEQ number at the end of segment transmission
               v.seqN        := r.nextSeqN+1;
               v.buffSent    := '1';          -- Increment the sent buffer
               
               -- Frame size is one word SOF and EOF
               v.ssiMaster.sof    := '1';
               v.ssiMaster.valid  := '1';
               v.ssiMaster.strb   := (others => '1');
               v.ssiMaster.keep   := (others => '1');
               v.ssiMaster.dest   := (others => '0');
               v.ssiMaster.eof    := '1';
               v.ssiMaster.eofe   := '0';
               v.ssiMaster.data(RSSI_WORD_WIDTH_C*8-1 downto 0) := headerData_i;
               v.ssiMaster.data(15 downto 0) := chksumData_i; -- Add header to last two bytes
            
               v.state   := CONN_S;
               
            end if;           
  
         ----------------------------------------------------------------------
         -- NULL packet
         ----------------------------------------------------------------------         
         when NULL_WE_S =>
            -- Counters
            v.nextSeqN    := r.nextSeqN;
            v.seqN        := r.nextSeqN;
            
            v.headerAddr  := (others => '0');
            v.segmentAddr := (others => '0');
             
            v.bufferAddr := nextSentAddr_i;
            
            -- State control signals 
            v.synH     := '0';
            v.ackH     := '0';
            v.rstH     := '0';   
            v.nullH    := '1';  -- Send null header     
            v.dataH    := '0';
            v.dataD    := '0';
            -- 
            v.txRdy    := '0';
            v.buffWe   := '1';  -- Update buffer seqN and Type 
            v.buffSent := '0';
            v.chkEn    := '0';
            v.chkStb   := '0';
            
            -- SSI master 
            v.ssiMaster := SSI_MASTER_INIT_C;
            
            -- Next state condition
            v.state   := NULL_H_S;
         ----------------------------------------------------------------------
         when NULL_H_S =>
            -- Counters
            v.nextSeqN    := r.nextSeqN;
            v.seqN        := r.nextSeqN;
            v.headerAddr  := (others => '0');
            
            v.segmentAddr := (others => '0');
            v.bufferAddr := nextSentAddr_i;
            
            -- Flags
            v.synH     := '0';
            v.ackH     := '0';
            v.rstH     := '0';  
            v.nullH    := '1';  -- Send null header 
            v.dataH    := '0';
            v.dataD    := '0';
            --
            v.txRdy    := '0';
            v.buffWe   := '0';          
            v.buffSent := '0';
            v.chkEn    := '1';
            v.chkStb   := '1';
            
            -- SSI Master init (if not ready)
            v.ssiMaster := SSI_MASTER_INIT_C;

            -- Next state condition
            if (chksumValid_i = '1' and tspSsiSlave_i.ready = '1') then -- Frame size is one word
               
               -- Increment seqN
               v.nextSeqN    := r.nextSeqN+1; -- Increment SEQ number at the end of segment transmission
               v.seqN        := r.nextSeqN+1;
               v.buffSent    := '1';          -- Increment the sent buffer
               
               v.ssiMaster.sof    := '1';
               v.ssiMaster.valid  := '1';
               v.ssiMaster.strb   := (others => '1');
               v.ssiMaster.keep   := (others => '1');
               v.ssiMaster.dest   := (others => '0');
               v.ssiMaster.eof    := '1';
               v.ssiMaster.eofe   := '0';
               v.ssiMaster.data(RSSI_WORD_WIDTH_C*8-1 downto 0) := headerData_i;
               v.ssiMaster.data(15 downto 0) := chksumData_i; -- Add header to last two bytes
            
               v.state   := CONN_S;
               
            end if;           
         ----------------------------------------------------------------------
         -- DATA packet
         ----------------------------------------------------------------------         
         when DATA_WE_S =>
            -- Counters
            v.nextSeqN    := r.nextSeqN;
            v.seqN        := r.nextSeqN;
            
            v.headerAddr  := (others => '0');
            v.segmentAddr := (others => '0');
             
            v.bufferAddr := nextSentAddr_i;
            
            -- State control signals 
            v.synH     := '0';
            v.ackH     := '0';
            v.rstH     := '0';   
            v.nullH    := '0';      
            v.dataH    := '1';  -- Send data header 
            v.dataD    := '0';
            -- 
            v.txRdy    := '0';
            v.buffWe   := '1';  -- Update buffer seqN and Type 
            v.buffSent := '0';
            v.chkEn    := '0';
            v.chkStb   := '0';
            
            -- SSI master 
            v.ssiMaster := SSI_MASTER_INIT_C;
            
            -- Next state condition
            v.state   := DATA_H_S;
         ----------------------------------------------------------------------
         when DATA_H_S =>
            -- Counters
            v.nextSeqN    := r.nextSeqN;
            v.seqN        := r.nextSeqN;
            
            v.segmentAddr := (others => '0');
            v.bufferAddr  := nextSentAddr_i;
            --
            v.synH     := '0';
            v.ackH     := '0';
            v.rstH     := '0';  
            v.nullH    := '0';  
            v.dataH    := '1';  -- Send data header 
            v.dataD    := '0';
            --
            v.txRdy    := '0';
            v.buffWe   := '0';          
            v.buffSent := '0';
            v.chkEn    := '1';
            v.chkStb   := '1';
            
            -- SSI Master init (if not ready)
            v.ssiMaster := SSI_MASTER_INIT_C;

            -- Next state condition
            if (chksumValid_i = '1' and tspSsiSlave_i.ready = '1') then -- Frame size is one word
                             
               v.ssiMaster.sof    := '1';
               v.ssiMaster.valid  := '1';
               v.ssiMaster.strb   := windowArray_i(conv_integer(r.bufferAddr)).strb;
               v.ssiMaster.keep   := windowArray_i(conv_integer(r.bufferAddr)).keep;
               v.ssiMaster.dest   := windowArray_i(conv_integer(r.bufferAddr)).dest;
               v.ssiMaster.eof    := '0';
               v.ssiMaster.eofe   := '0';
               v.ssiMaster.data(RSSI_WORD_WIDTH_C*8-1 downto 0) := headerData_i;
               v.ssiMaster.data(15 downto 0) := chksumData_i; -- Add header to last two bytes
               
               v.state        := DATA_S;
               
            end if;            
         ----------------------------------------------------------------------
         when DATA_S =>
            -- Counters
            v.nextSeqN    := r.nextSeqN;
            v.seqN        := r.nextSeqN;
            
            v.headerAddr  := (others => '0');            
            v.bufferAddr  := nextSentAddr_i;
            --
            v.synH     := '0';
            v.ackH     := '0';
            v.rstH     := '0';  
            v.nullH    := '0';  
            v.dataH    := '0';   
            v.dataD    := '1';  -- Send data
            --
            v.txRdy    := '0';
            v.buffWe   := '0';          
            v.buffSent := '0';
            v.chkEn    := '0';
            v.chkStb   := '0';
            
            -- SSI Control
             
            -- Increment segment address only when Slave is ready


            -- Other SSI parameters
            v.ssiMaster.sof    := '0';
            v.ssiMaster.strb   := windowArray_i(conv_integer(r.bufferAddr)).strb;
            v.ssiMaster.keep   := windowArray_i(conv_integer(r.bufferAddr)).keep;
            v.ssiMaster.dest   := windowArray_i(conv_integer(r.bufferAddr)).dest;

            -- SSI data (send tx budffer data). Assigned to D1 to compensate for BRAM addr data delay
            v.ssiMasterD1.data(RSSI_WORD_WIDTH_C*8-1 downto 0)  := bufferData_i;
            
            -- Next state condition
            if  (tspSsiSlave_i.ready = '1' and r.segmentAddr >= windowArray_i(conv_integer(r.bufferAddr)).segSize) then            
               -- Send EOF at the end of the segment
               v.ssiMaster.eof    := '1';
               v.ssiMaster.eofe   := windowArray_i(conv_integer(r.bufferAddr)).eofe;
               v.ssiMaster.valid  := '1';
               -- 
               v.state   := DATA_SENT_S;
            elsif (tspSsiSlave_i.ready = '1') then
               v.segmentAddr       := r.segmentAddr + 1;
               v.ssiMaster.valid  := '1';
            else 
               v.segmentAddr       := r.segmentAddr;
               v.ssiMaster.valid  := '0';              
            end if;

         -----------------------------------------------------------------------------   
         when DATA_SENT_S =>
             -- Outputs
            v.nextSeqN    := r.nextSeqN+1; -- Increment SEQ number at the end of segment transmission
            v.seqN        := r.nextSeqN+1;
            
            v.headerAddr  := (others => '0');
            v.segmentAddr := (others => '0');
             
            v.bufferAddr := nextSentAddr_i;
            --
            v.synH     := '0';
            v.ackH     := '0';
            v.rstH     := '0';
            v.nullH    := '0';       
            v.dataH    := '0';
            v.dataD    := '0';
            v.chkEn    := '0';
            v.chkStb   := '0';
            --
            v.txRdy    := '0';
            v.buffWe   := '0';         
            v.buffSent := '1';     -- Increment buffer last sent address(txBuffer)
            
            -- SSI master (Initialise - stop transmission) 
            v.ssiMaster         := SSI_MASTER_INIT_C;
            v.ssiMasterD1.data  := r.ssiMasterD1.data;
            
            -- Next state
            v.state   := CONN_S;

         ----------------------------------------------------------------------
         -- Resend all packets from the buffer
         -- Packets between firstUnackAddr_i and nextSentAddr_i
         ----------------------------------------------------------------------            
         when RESEND_INIT_S =>
            -- Start from first unack address 
            v.bufferAddr := firstUnackAddr_i;

            -- Counters
            v.nextSeqN    := r.nextSeqN; -- Never increment seqN while resending 
            v.seqN        := windowArray_i(conv_integer(r.bufferAddr)).seqN;
            
            v.headerAddr  := (others => '0');
            v.segmentAddr := (others => '0');

            -- State control signals 
            v.synH     := '0';
            v.ackH     := '0';
            v.rstH     := '0';
            v.nullH    := '0';
            v.dataH    := '0';
            v.dataD    := '0';
            -- 
            v.txRdy    := '0';
            v.buffWe   := '0'; 
            v.buffSent := '0';
            v.chkEn    := '0';
            v.chkStb   := '0';

            -- SSI master 
            v.ssiMaster := SSI_MASTER_INIT_C;
            
            -- Next state condition
            v.state   := RESEND_S;
           
         when RESEND_S =>
            -- Start from first unack address 
            v.bufferAddr := r.bufferAddr;

            -- Counters
            v.nextSeqN    := r.nextSeqN; -- Never increment seqN while resending 
            v.seqN        := windowArray_i(conv_integer(r.bufferAddr)).seqN;
            
            v.headerAddr  := (others => '0');
            v.segmentAddr := (others => '0');

            -- State control signals 
            v.synH     := '0';
            v.ackH     := '0';
            v.rstH     := windowArray_i(conv_integer(r.bufferAddr)).segType(2);  
            v.nullH    := windowArray_i(conv_integer(r.bufferAddr)).segType(1);  
            v.dataH    := windowArray_i(conv_integer(r.bufferAddr)).segType(0);
            v.dataD    := '0';
            -- 
            v.txRdy    := '0';
            v.buffWe   := '0'; 
            v.buffSent := '0';
            v.chkEn    := '0';
            v.chkStb   := '0';

            -- SSI master 
            v.ssiMaster := SSI_MASTER_INIT_C;
            
            -- Next state condition
            v.state   := RESEND_H_S;   
   
         ----------------------------------------------------------------------
         when RESEND_H_S =>
            -- Counters
            v.nextSeqN    := r.nextSeqN; -- Never increment seqN while resending
            v.seqN        := windowArray_i(conv_integer(r.bufferAddr)).seqN;
            
            v.segmentAddr := (others => '0');
            v.bufferAddr  := r.bufferAddr;
            --
            v.synH     := '0';
            v.ackH     := '0';
            v.rstH     := windowArray_i(conv_integer(r.bufferAddr)).segType(2);  
            v.nullH    := windowArray_i(conv_integer(r.bufferAddr)).segType(1);  
            v.dataH    := windowArray_i(conv_integer(r.bufferAddr)).segType(0); 
            v.dataD    := '0';
            --
            v.txRdy    := '0';
            v.buffWe   := '0';          
            v.buffSent := '0';
            v.chkEn    := '1';
            v.chkStb   := '1';
            
            -- SSI Master init (if not ready)
            v.ssiMaster := SSI_MASTER_INIT_C;
            
            -- Next state condition
            if (chksumValid_i = '1' and tspSsiSlave_i.ready = '1') then -- Frame size is one word
                             
               v.ssiMaster.sof    := '1';
               v.ssiMaster.valid  := '1';
               v.ssiMaster.strb   := windowArray_i(conv_integer(r.bufferAddr)).strb;
               v.ssiMaster.keep   := windowArray_i(conv_integer(r.bufferAddr)).keep;
               v.ssiMaster.dest   := windowArray_i(conv_integer(r.bufferAddr)).dest;
               v.ssiMaster.eof    := '0';
               v.ssiMaster.eofe   := '0';
               v.ssiMaster.data(RSSI_WORD_WIDTH_C*8-1 downto 0) := headerData_i;
               v.ssiMaster.data(15 downto 0) := chksumData_i; -- Add header to last two bytes

               if    (windowArray_i(conv_integer(r.bufferAddr)).segType(2) = '1' or
                      windowArray_i(conv_integer(r.bufferAddr)).segType(1) = '1'
               ) then
                  -- Send EOF and start sending next packet
                  v.ssiMaster.eof    := '1';
                  v.ssiMaster.eofe   := '0';
                  --
                  v.state   := RESEND_PP_S;
               -- If DATA packet start sending data
               else
                  -- Increment the RAM address here so the data will be ready next clock cycle
                  v.segmentAddr  := r.segmentAddr + 1;
                  v.state        := RESEND_DATA_S;
               end if;
            end if;               
         ----------------------------------------------------------------------         
         when RESEND_DATA_S =>
            -- Counters
            v.nextSeqN    := r.nextSeqN; -- Never increment seqN while resending
            v.seqN        := windowArray_i(conv_integer(r.bufferAddr)).seqN;
            
            v.headerAddr  := (others => '0');            
            v.bufferAddr  := r.bufferAddr;
            --
            v.synH     := '0';
            v.ackH     := '0';
            v.rstH     := '0';  
            v.nullH    := '0';  
            v.dataH    := '0';   
            v.dataD    := '1';  -- Send data
            --
            v.txRdy    := '0';
            v.buffWe   := '0';          
            v.buffSent := '0';
            v.chkEn    := '0';
            v.chkStb   := '0';
            
            -- SSI Control
             
            -- Increment segment address only when Slave is ready
            if (tspSsiSlave_i.ready = '1') then
               v.segmentAddr       := r.segmentAddr + 1;
               v.ssiMaster.valid  := '1';
            else 
               v.segmentAddr       := r.segmentAddr;
               v.ssiMaster.valid  := '0';              
            end if;

            -- Other SSI parameters
            v.ssiMaster.sof    := '0';
            v.ssiMaster.strb   := windowArray_i(conv_integer(r.bufferAddr)).strb;
            v.ssiMaster.keep   := windowArray_i(conv_integer(r.bufferAddr)).keep;
            v.ssiMaster.dest   := windowArray_i(conv_integer(r.bufferAddr)).dest;

            
            -- SSI data (send tx budffer data)
            v.ssiMaster.data(RSSI_WORD_WIDTH_C*8-1 downto 0)  := bufferData_i;
            
            -- Next state condition
            if  (tspSsiSlave_i.ready = '1' and r.segmentAddr >= windowArray_i(conv_integer(r.bufferAddr)).segSize) then            
               -- Send EOF at the end of the segment
               v.ssiMaster.eof    := '1';
               v.ssiMaster.eofe   := windowArray_i(conv_integer(r.bufferAddr)).eofe;
               v.ssiMaster.valid  := '1';
               -- 
               v.state   := RESEND_PP_S;                
                
            end if;
         ----------------------------------------------------------------------            
         when RESEND_PP_S =>
            -- Counters
            v.nextSeqN    := r.nextSeqN; -- Never increment seqN while resending 
            v.seqN        := windowArray_i(conv_integer(r.bufferAddr)).seqN;
            
            v.headerAddr  := (others => '0');
            v.segmentAddr := (others => '0');
            
            -- Increment buffer address (circulary)
            if r.bufferAddr < (windowSize_i-1) then
               v.bufferAddr := r.bufferAddr+1;
            else
               v.bufferAddr := (others => '0');
            end if;
            
            -- State control signals 
            v.rstH     := '0'; 
            v.nullH    := '0';  
            v.dataH    := '0';  
            v.nullH    := '0';      
            v.dataH    := '0'; 
            v.dataD    := '0';
            -- 
            v.txRdy    := '0';
            v.buffWe   := '0'; 
            v.buffSent := '0';
            v.chkEn    := '0';
            v.chkStb   := '0';

            -- SSI master 
            v.ssiMaster := SSI_MASTER_INIT_C;
            
            -- Next state condition
            -- Go back to CONN_S when the last sent address reached 
            if (r.bufferAddr = lastSentAddr_i) then
               v.state   := CONN_S;        
            else
               v.state   := RESEND_S;
            end if;
         ----------------------------------------------------------------------
         when others =>
            --
            v := REG_INIT_C;         
      ----------------------------------------------------------------------
      end case;
      
      -- Synchronous Reset
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
   -- Combine ram read address
   rdDataAddr_o     <= r.bufferAddr & r.segmentAddr(SEGMENT_ADDR_SIZE_C-1 downto 0);
   rdHeaderAddr_o   <= r.headerAddr;
   
   -- State assignment
   synHeadSt_o  <= r.synH;
   ackHeadSt_o  <= r.ackH;
   dataHeadSt_o <= r.dataH;
   dataSt_o     <= r.dataD;
   rstHeadSt_o  <= r.rstH;
   nullHeadSt_o <= r.nullH;
   
   chksumEnable_o <= r.chkEn;
   chksumStrobe_o <= r.chkStb;
   
   -- Next packet 
   nextSeqN_o   <= r.nextSeqN;
   txRdy_o      <= r.txRdy;
   we_o         <= r.buffWe; 
   sent_o       <= r.buffSent;
   
   -- Sequence number from buffer
   txSeqN_o     <= r.seqN;
   tspSsiMaster_o <= r.ssiMasterD1;
   
   ---------------------------------------------------------------------
end architecture rtl;