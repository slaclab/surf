-------------------------------------------------------------------------------
-- File       : RxFSM.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-11
-- Last update: 2016-06-23
-------------------------------------------------------------------------------
-- Description: Receiver FSM
--              Receiver has the following functionality:
--              Transport side FSM. Receive check and save segments to RX buffer.
--               - WAIT_SOF Waits for Transport side SOF,  
--               - CHECK Determines the segment type and checks:
--                    ACK, NULL, DATA, or RST segment
--                    1. Validates checksum (when valid), 
--                    2. Header length (number of bytes), 
--                    3. Sequence number (Only current seqN or lastSeqN+1 allowed)
--                    4. Acknowledgment number (Valid range is lastAckN to lastAckN + txWindowSize)
--               - CHECK_SYN Toggles through SYN header addresses and saves the RSSI parameters
--                    Checks the following:
--                    1. Validates checksum (when valid), 
--                    2. Validates Ack number if the ack is sent with the SYN segment
--               - DATA Receives the payload part of the DATA segment
--               - VALID Checks if next valid SEQn is received. If yes:
--                      1. increment the in order SEQn
--                      2. save seqN, type, and occupied to the window buffer at current rxBufferAddr
--                      3. increment rxBufferAddr
--               - DROP Just report dropped packet and got back to WAIT_SOF
--              Receiver side FSM. Send data to App side.
--                - CHECK_BUFFER and DATA Send the data frame to the Application  
--                  when the data at the next txSegmentAddr is ready.
--                - SENT Release the windowbuffer at txBufferAddr. 
--                       Increment txBufferAddr. 
--                       Register the received SeqN for acknowledgment.
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
use work.SsiPkg.all;
use work.AxiStreamPkg.all;

entity RxFSM is
   generic (
      TPD_G               : time     := 1 ns;
      WINDOW_ADDR_SIZE_G  : positive := 7;     -- 2^WINDOW_ADDR_SIZE_G  = Number of segments
      HEADER_CHKSUM_EN_G  : boolean  := true;
      SEGMENT_ADDR_SIZE_G : positive := 3  -- 2^SEGMENT_ADDR_SIZE_G = Number of 64 bit wide data words
   );
   port (
      clk_i      : in  sl;
      rst_i      : in  sl;
      
      -- Connection FSM indicating active connection
      connActive_i   : in  sl;
      
      -- Window size different for Rx and Tx
      rxWindowSize_i   : in integer range 1 to 2 ** (WINDOW_ADDR_SIZE_G);
      rxBufferSize_i   : in integer range 1 to 2 ** (SEGMENT_ADDR_SIZE_G);
      txWindowSize_i   : in integer range 1 to 2 ** (WINDOW_ADDR_SIZE_G);
      
      -- Last acknowledged Sequence number connected to TX module
      lastAckN_i   : in slv(7 downto 0);
           
      -- Current received seqN
      rxSeqN_o     : out slv(7 downto 0);

      -- Current received ackN
      rxAckN_o     : out slv(7 downto 0);
      
      -- Last seqN received and sent to application (this is the ackN transmitted)
      rxLastSeqN_o : out slv(7 downto 0);

      -- Valid Segment received (1 c-c)
      rxValidSeg_o : out sl;
      
      -- Segment dropped (1 c-c)
      rxDropSeg_o  : out sl;

      -- Last segment received flags (active until next segment is received)
      rxFlags_o    : out flagsType;
      
      -- Parameters received from peer SYN packet
      rxParam_o    : out RssiParamType;

      -- Checksum control
      chksumValid_i  : in   sl;
      chksumOk_i     : in   sl;
      chksumEnable_o : out  sl;
      chksumStrobe_o : out  sl;
      chksumLength_o : out  positive;

      -- Buffer write
      wrBuffWe_o     : out  sl;      
      wrBuffAddr_o   : out  slv( (SEGMENT_ADDR_SIZE_G+WINDOW_ADDR_SIZE_G)-1 downto 0);
      wrBuffData_o   : out  slv(RSSI_WORD_WIDTH_C*8-1 downto 0);      
      
      -- Buffer read
      rdBuffAddr_o   : out  slv( (SEGMENT_ADDR_SIZE_G+WINDOW_ADDR_SIZE_G)-1 downto 0);
      rdBuffData_i   : in   slv(RSSI_WORD_WIDTH_C*8-1 downto 0);
      
      -- SSI Transport side interface IN 
      tspSsiMaster_i : in  SsiMasterType;
      tspSsiSlave_o  : out SsiSlaveType;
      
      -- SSI Application side interface OUT
      appSsiMaster_o : out SsiMasterType;
      appSsiSlave_i  : in  SsiSlaveType
 
   );
end entity RxFSM;

architecture rtl of RxFSM is
   -- Init SSI bus
   constant SSI_MASTER_INIT_C   : SsiMasterType := axis2SsiMaster(RSSI_AXIS_CONFIG_C, AXI_STREAM_MASTER_INIT_C);
   constant SSI_SLAVE_NOTRDY_C  : SsiSlaveType  := axis2SsiSlave(RSSI_AXIS_CONFIG_C, AXI_STREAM_SLAVE_INIT_C, AXI_STREAM_CTRL_UNUSED_C);
   constant SSI_SLAVE_RDY_C     : SsiSlaveType  := axis2SsiSlave(RSSI_AXIS_CONFIG_C, AXI_STREAM_SLAVE_FORCE_C, AXI_STREAM_CTRL_UNUSED_C);
   
   type tspStateType is (
      --
      WAIT_SOF_S,
      CHECK_S,
      SYN_CHECK_S,
      VALID_S,
      DROP_S,
      DATA_S
   );
   
   type AppStateType is (
      --
      CHECK_BUFFER_S,
      DATA_S,
      SENT_S
   );  

   type RegType is record
      
      -- Resception buffer window
      windowArray    : WindowTypeArray(0 to 2 ** WINDOW_ADDR_SIZE_G-1);      
      
      -- Transport side FSM (Receive and check segments)
      -----------------------------------------------------------
      
      -- Counters
      inorderSeqN    : slv(7 downto 0); -- Next expected seqN
      rxHeaderAddr   : slv(7 downto 0); 
      rxSegmentAddr  : slv(SEGMENT_ADDR_SIZE_G downto 0);
      rxBufferAddr   : slv(WINDOW_ADDR_SIZE_G-1  downto 0);
      --
      segmentWe      : sl;
      
      -- Packet flags
      rxF : flagsType;
      
      -- Received RSSI parameters
      rxParam : RssiParamType;
      
      rxHeadLen : slv(7 downto 0);      
      rxSeqN    : slv(7 downto 0); -- Received seqN
      rxAckN    : slv(7 downto 0); -- Received ackN
                 
      -- 
      chkEn    : sl;
      chkStb   : sl;
      chkLen   : positive;
      --
      segValid    : sl;
      segDrop     : sl;
      --
      headerData  : slv(RSSI_WORD_WIDTH_C*8-1 downto 0);
      
      -- SSI
      tspSsiMaster   : SsiMasterType;
      tspSsiSlave    : SsiSlaveType;
            
      -- State Machine
      tspState       : TspStateType;
      
      -- Application side FSM (Send segments when next in order received)
      -----------------------------------------------------------
      txSegmentAddr  : slv(SEGMENT_ADDR_SIZE_G downto 0);
      txBufferAddr   : slv(WINDOW_ADDR_SIZE_G-1  downto 0);
      rxLastSeqN     : slv(7 downto 0);
      
      -- SSI      
      appSsiMaster   : SsiMasterType;
      appSsiSlave    : SsiSlaveType;
      
      -- State Machine
      appState       : AppStateType;
      
   end record RegType;

   constant REG_INIT_C : RegType := (
      
      -- Rx buffer window
      windowArray    => (0 to 2 ** WINDOW_ADDR_SIZE_G-1 => WINDOW_INIT_C),
      
      -- Transport side FSM (Receive and check segments)
      -----------------------------------------------------------   
      inorderSeqN    => (others => '0'), -- Next expected seqN
      rxHeaderAddr   => (others => '0'),
      rxSegmentAddr  => (others => '0'),
      rxBufferAddr   => (others => '0'),
       
      -- 
      segmentWe    => '0',
       
      -- Packet flags
      rxF => (others => ('0')),
      
      -- Received RSSI parameters
      rxParam    => RSSI_PARAM_INIT_C,

      rxHeadLen  => (others => '0'), -- Received seqN
      rxSeqN     => (others => '0'),   -- Received seqN
      rxAckN     => (others => '0'),   -- Received ackN
      
      --
      chkEn    => '0',
      chkStb   => '0',
      chkLen   => 1,
      --
      segValid    => '0',
      segDrop     => '0',
      --
      headerData  => (others => '0'),

      -- SSI 
      tspSsiMaster => SSI_MASTER_INIT_C,
      tspSsiSlave  => SSI_SLAVE_NOTRDY_C,

      -- Transport side state
      tspState => WAIT_SOF_S,
      
      -- Application side FSM (Send segments when received next in odrer received)
      -----------------------------------------------------------
      txBufferAddr  => (others => '0'),
      txSegmentAddr => (others => '0'),
      rxLastSeqN => (others => '0'),
      
      -- SSI      
      appSsiMaster => SSI_MASTER_INIT_C,
      appSsiSlave  => SSI_SLAVE_NOTRDY_C,
      
      -- Application side state            
      appState => CHECK_BUFFER_S
      
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   signal s_chksumOk : sl;
   
begin
   
  -- Override checksum check if checksum disabled
   s_chksumOk <= ite(HEADER_CHKSUM_EN_G, chksumOk_i, '1');
   
   ----------------------------------------------------------------------------------------------- 
   comb : process (r, rst_i, chksumValid_i, s_chksumOk, rxWindowSize_i, lastAckN_i, rxBufferSize_i,
                  txWindowSize_i, tspSsiMaster_i, connActive_i, rdBuffData_i, appSsiSlave_i) is
      
      variable v : RegType;

   begin
      v := r;

      ------------------------------------------------------------
      -- RX Transport side FSM:
      -- Receive the segment from the peer
      -- Check the segment:
      -- - register the parameters from SYN header
      -- - seqN, ackN
      -- - check header checksum
      -- - increment in order received SeqN
      ------------------------------------------------------------
      
      -- Pipeline the transport master
      v.tspSsiMaster := tspSsiMaster_i;  
      v.headerData := endianSwap64(tspSsiMaster_i.data(63 downto 0));
      case r.tspState is
         ----------------------------------------------------------------------
         when WAIT_SOF_S =>
         
            -- Counters to 0
            v.rxHeaderAddr  := (others => '0');
            v.rxSegmentAddr := (others => '1'); -- "-1" so the first address after increment to be 0
            v.segmentWe   := '0';
   
            -- Ready until SOF received 
            -- Also flush any dropped or non SOF segments
            v.tspSsiSlave := SSI_SLAVE_RDY_C;
            
            -- Checksum commands
            v.chkEn    := '0';
            v.chkStb   := '0';
            v.chkLen   := 1;
            --
            v.segValid   := '0';
            v.segDrop    := '0';
            
            -- Next state condition
            if (tspSsiMaster_i.sof = '1' and tspSsiMaster_i.valid = '1') then
               v.chkEn       := '1';
               v.chkStb      := '1';

               -- When SOF has been received dessert ready until package is checked 
               v.tspSsiSlave := SSI_SLAVE_RDY_C;
               
               -- If the packet is longer than one set the data flag
               if (tspSsiMaster_i.eof = '1') then
                  v.rxF.data := '0';
               else
                  v.rxF.data := '1';
               end if;
               --
               v.tspState    := CHECK_S;
               --
            end if;
         ----------------------------------------------------------------------
         when CHECK_S =>
            --
            v.segValid   := '0';
            v.segDrop    := '0';
            v.rxSegmentAddr := (others => '1');
            
            -- Hold incoming AXI stream
            v.tspSsiSlave := SSI_SLAVE_NOTRDY_C;
            
            if (r.tspSsiMaster.valid = '1' and r.tspSsiMaster.sof = '1') then
               -- Register flags, header length and SEQn
               v.rxF.syn  := r.headerData (63);
               v.rxF.ack  := r.headerData (62);
               v.rxF.eack := r.headerData (61);
               v.rxF.rst  := r.headerData (60);
               v.rxF.nul  := r.headerData (59);
               v.rxF.busy := r.headerData (56);
               
               v.rxHeadLen := r.headerData (55 downto 48);
               v.rxSeqN    := r.headerData (47 downto 40);
               v.rxAckN    := r.headerData (39 downto 32);
            end if;
            
            -- Checksum commands
            v.chkEn    := '1';
            v.chkStb   := '0';
           
            -- Syn header received (header is 3 c-c long)
            if (v.rxF.syn = '1') then
               
               -- Register SYN header word 0 parameters
               v.chkLen     := 3; -- TODO make generic
               v.rxParam.version    := r.headerData (31 downto 28);
               v.rxParam.chksumEn   := r.headerData (26 downto 26);
               v.rxParam.maxOutsSeg := r.headerData (23 downto 16);
               v.rxParam.maxSegSize := r.headerData (15 downto 0);
               
               --
               if (v.rxF.ack = '1' and v.rxAckN /= lastAckN_i) then
                  -- Acknowledgment not valid
                  v.tspState    := DROP_S;
               elsif (v.rxF.eack = '1' or v.rxF.rst = '1' or v.rxF.busy = '1') then
                  -- Wrong flags
                  v.tspState    := DROP_S;               
               else
                  -- Go to SYN_CHECK_S
                  v.tspState    := SYN_CHECK_S;
               end if;
               
            -- Segment is ACK, DATA, RST, or NULL
            elsif (v.rxF.syn = '0' and v.rxF.eack = '0' and chksumValid_i = '1') then   --              
               
               -- Check header
               if (
                  -- Checksum
                  s_chksumOk = '1'                           and
                  -- Check length
                  r.rxHeadLen = toSlv(8, 8)                  and
                  -- Check SeqN range
                  (r.rxSeqN - r.inOrderSeqN) <= 1            and
                  -- Check AckN range                  
                  (r.rxAckN - lastAckN_i)  <= txWindowSize_i
               ) then
                  -- Valid data segment
                  if (r.rxF.data = '1' and v.rxF.nul = '0' and v.rxF.rst = '0') then
                     -- Wait if the buffer full
                     -- Note: Deadlock possibility! If the peer is not accepting data!
                     if (r.windowArray(conv_integer(r.rxBufferAddr)).occupied = '0') then
                        -- Go to data segment               
                        v.tspState    := DATA_S;
                     else
                        -- Buffer is full -> drop segment
                        v.tspState    := DROP_S;                        
                     end if;                         
                  elsif (r.rxF.data = '0') then
                     -- Valid non data segment               
                     v.tspState    := VALID_S;
                  else
                     -- Error: Data is attached to NUL or RST segment  
                     v.tspState    := DROP_S;                      
                  end if;
               else
                  -- Header not valid
                  v.tspState    := DROP_S;              
               end if;
            end if;
            
         ----------------------------------------------------------------------
         when SYN_CHECK_S =>
            --
            v.segValid      := '0';
            v.segDrop       := '0';
            v.rxSegmentAddr := (others => '1');
             
            -- Ready to receive further header data
            v.tspSsiSlave := SSI_SLAVE_RDY_C;
             
            -- Get the rest of the SYN header
            if (tspSsiMaster_i.valid = '1') then
               v.chkStb      := '1';
               v.rxHeaderAddr  := r.rxHeaderAddr + 1;
            else
               v.chkStb      := '0';
               v.rxHeaderAddr  := r.rxHeaderAddr;
            end if;
            
            -- Register SYN header word 1 parameters
            if (r.rxHeaderAddr = x"01" and r.tspSsiMaster.valid = '1') then
               -- Syn parameters              
               v.rxParam.retransTout := r.headerData (63 downto 48);
               v.rxParam.cumulAckTout:= r.headerData (47 downto 32);
               v.rxParam.nullSegTout := r.headerData (31 downto 16);
               v.rxParam.maxRetrans  := r.headerData (15 downto 8);
               v.rxParam.maxCumAck   := r.headerData ( 7 downto 0);
               --
            end if;
            
            -- Register SYN header word 2 parameters
            if (r.rxHeaderAddr = x"02" ) then
               v.chkStb        := '0';
               v.rxHeaderAddr  := r.rxHeaderAddr;
               v.tspSsiSlave   := r.tspSsiSlave;
               
               if (r.tspSsiMaster.valid = '1') then
                 
                  -- Syn parameters
                  v.rxParam.maxOutofseq              := r.headerData (63 downto 56);
                  v.rxParam.timeoutUnit              := r.headerData (55 downto 48);
                  v.rxParam.connectionId(31 downto 0):= r.headerData (47 downto 16);

                  -- Tsp parameters
                  v.tspSsiSlave := SSI_SLAVE_NOTRDY_C;
               end if;
               
               -- Wait for checksum  
               if ( chksumValid_i = '1') then 
                  -- Check received data header
                  
                  if (
                     -- Checksum
                     s_chksumOk = '1' and
                     -- Check length
                     r.rxHeadLen = toSlv(24, 8)
                  ) then
                     -- Header is valid                
                     v.tspState    := VALID_S;                  
                  else
                     -- Header not valid                
                     v.tspState    := DROP_S;               
                  end if;               
               end if;
            end if;
         ----------------------------------------------------------------------
         when DATA_S =>         
            --
            v.segValid   := '0';
            v.segDrop    := '0';
            --
            v.chkEn    := '0';
            v.chkStb   := '0';
            
            -- Ready to receive further header data
            v.tspSsiSlave   := SSI_SLAVE_RDY_C;
           
            -- Write enable and segment address
            if (tspSsiMaster_i.valid = '1') then
               v.rxSegmentAddr := r.rxSegmentAddr + 1;
               v.segmentWe   := '1';
            else
               v.rxSegmentAddr := r.rxSegmentAddr;
               v.segmentWe   := '0';             
            end if;
            
            -- Wait until receiving EOF 
            if (tspSsiMaster_i.eof = '1' and tspSsiMaster_i.valid = '1') then
              
               -- Save tKeep of the last packet
               v.windowArray(conv_integer(r.rxBufferAddr)).keep   := tspSsiMaster_i.keep;
               
               -- Save packet length (+1 because it has not incremented for EOF yet)
               v.windowArray(conv_integer(r.rxBufferAddr)).segSize := conv_integer(r.rxSegmentAddr(SEGMENT_ADDR_SIZE_G-1 downto 0))+1;     
               
               -- Check EOF Error
               if (tspSsiMaster_i.eofe = '0') then
                  v.tspState    := VALID_S;
               else
                  v.tspState    := DROP_S;              
               end if;
            elsif (r.tspSsiSlave.ready = '1' and r.rxSegmentAddr > rxBufferSize_i ) then
               v.tspState    := DROP_S;
            elsif (r.tspSsiSlave.ready = '1' and r.rxSegmentAddr(SEGMENT_ADDR_SIZE_G) = '1' ) then
               v.tspState    := DROP_S;
            end if;
         ----------------------------------------------------------------------
         when VALID_S =>
            --
            v.segValid   := '1';
            v.segDrop    := '0';
            --
            v.chkEn    := '0';
            v.chkStb   := '0';
            v.segmentWe:= '0';
            --
            v.tspSsiSlave := SSI_SLAVE_NOTRDY_C;
                        
            -- Initialize when valid SYN segment received
            -- 1. Set the initial SeqN
            -- 2. Initialize the buffer address
            -- 3. Initialize window
            if (connActive_i = '0' and  r.rxF.syn = '1') then
               v.rxF.ack  := r.rxF.ack;
               v.inOrderSeqN  := r.rxSeqN;
               v.rxBufferAddr := (others => '0');
               v.windowArray  := REG_INIT_C.windowArray;
               
            -- Check if next valid SEQn is received. If yes:
            -- 1. increment the in order SEQn
            -- 2. save seqN, type, and occupied to the current buffer address
            -- 3. increase buffer
            elsif ( (r.rxF.data = '1' or r.rxF.nul = '1' or r.rxF.rst = '1' ) and
                     -- Next seqN absolute difference is one
                     r.rxSeqN - r.inOrderSeqN = 1 
                  ) then
               --
               v.windowArray(conv_integer(r.rxBufferAddr)).seqN       := r.rxSeqN;
               v.windowArray(conv_integer(r.rxBufferAddr)).segType(0) := r.rxF.data;               
               v.windowArray(conv_integer(r.rxBufferAddr)).segType(1) := r.rxF.nul;
               v.windowArray(conv_integer(r.rxBufferAddr)).segType(2) := r.rxF.rst;
               v.windowArray(conv_integer(r.rxBufferAddr)).occupied   := '1';
               --
               v.inOrderSeqN := r.rxSeqN;
               -- 
               if r.rxBufferAddr < (rxWindowSize_i-1) then
                  v.rxBufferAddr := r.rxBufferAddr +1;
               else
                  v.rxBufferAddr := (others => '0');
               end if;
               --               
            else
               v.rxBufferAddr := r.rxBufferAddr;
               v.inOrderSeqN  := r.inOrderSeqN;
            end if;

            -- Get ready to receive new packet
            v.tspState    := WAIT_SOF_S;
          
         ----------------------------------------------------------------------
         when DROP_S =>         
            --
            v.segValid   := '0';
            v.segDrop    := '1';
            --
            v.chkEn    := '0';
            v.chkStb   := '0';
            v.segmentWe:= '0';
            --
            v.tspSsiSlave := SSI_SLAVE_NOTRDY_C;
            
            -- Get ready to receive new packet
            v.tspState    := WAIT_SOF_S;
            
         ----------------------------------------------------------------------
         when others =>
            --
            v := REG_INIT_C;
           
      ----------------------------------------------------------------------
      end case;

      ------------------------------------------------------------
      -- TX Application side FSM:
      -- Transmit the segments in correct order
      -- Check the buffer if the next slot is available and send the buffer to APP
      ------------------------------------------------------------
      
      -- Reset flags 
      -- These flags will hold if not overridden
      v.appSsiMaster:= SSI_MASTER_INIT_C;  

      -- Pipeline incomming slave
      v.appSsiSlave:= appSsiSlave_i;
      
      case r.appState is
         ----------------------------------------------------------------------
         when CHECK_BUFFER_S =>
         
            -- Counters to 0
            v.txSegmentAddr := (others => '0');
            v.rxLastSeqN    := r.rxLastSeqN;
            
            --
            if connActive_i = '0' then
               v.txBufferAddr  := (others => '0');
               v.rxLastSeqN    := r.inOrderSeqN;
            -- Data segment in buffer only one word long take TKEEP and apply EOF
            elsif (r.windowArray(conv_integer(r.txBufferAddr)).occupied = '1'   and
                   r.windowArray(conv_integer(r.txBufferAddr)).segType  = "001" and   -- Data segment type
                   r.windowArray(conv_integer(r.txBufferAddr)).segSize  = 0
            ) then
               --
               v.txBufferAddr  := r.txBufferAddr;
               
               if (appSsiSlave_i.pause = '0') then
               
                  v.appSsiMaster.sof    := '1';
                  v.appSsiMaster.valid  := '1';
                  v.appSsiMaster.strb   := (others => '1');
                  v.appSsiMaster.dest   := (others => '0');
                  v.appSsiMaster.keep   := r.windowArray(conv_integer(r.txBufferAddr)).keep;
                  v.appSsiMaster.eof    := '1';
                  v.appSsiMaster.eofe   := '0';
                  v.appSsiMaster.data(RSSI_WORD_WIDTH_C*8-1 downto 0) := rdBuffData_i;
                  v.txSegmentAddr       := r.txSegmentAddr;

                  v.appState  := SENT_S;              
               end if;    
            -- Data segment in buffer longer than one word go to DATA_S
            elsif (r.windowArray(conv_integer(r.txBufferAddr)).occupied = '1' and
                   r.windowArray(conv_integer(r.txBufferAddr)).segType  = "001"  -- Data segment type          
            ) then
               --
               v.txBufferAddr  := r.txBufferAddr;
               
               if (appSsiSlave_i.pause = '0') then
               
                  v.appSsiMaster.sof    := '1';
                  v.appSsiMaster.valid  := '1';
                  v.appSsiMaster.strb   := (others => '1');
                  v.appSsiMaster.dest   := (others => '0');
                  v.appSsiMaster.eof    := '0';
                  v.appSsiMaster.eofe   := '0';
                  v.appSsiMaster.data(RSSI_WORD_WIDTH_C*8-1 downto 0) := rdBuffData_i;
                  v.txSegmentAddr       := r.txSegmentAddr + 1;

                  v.appState  := DATA_S;              
               end if;
            -- None data segment type  (Go directly to SENT_S) 
            elsif (r.windowArray(conv_integer(r.txBufferAddr)).occupied = '1') then   
               --
               v.txBufferAddr  := r.txBufferAddr;
               v.appState      := SENT_S;
               --
            else
               --
               v.txBufferAddr  := r.txBufferAddr;
               v.appSsiMaster.valid  := '0';
               v.appState      := CHECK_BUFFER_S;
            end if;
         ----------------------------------------------------------------------
         when DATA_S =>
         
            -- Counters 
            v.txBufferAddr  := r.txBufferAddr;
            v.rxLastSeqN    := r.rxLastSeqN; 
            
            -- SSI parameters
            v.appSsiMaster.sof    := '0';
            v.appSsiMaster.strb   := (others => '1');
            v.appSsiMaster.dest   := (others => '0');
            v.appSsiMaster.eof    := '0';
            v.appSsiMaster.eofe   := '0';
            v.appSsiMaster.data(RSSI_WORD_WIDTH_C*8-1 downto 0) := rdBuffData_i;
                      
            -- Next state condition
            -- When segment address reaches segment size then go to SENT_S
            if  (r.txSegmentAddr >= r.windowArray(conv_integer(r.txBufferAddr)).segSize) then

               -- Send EOF at the end of the segment
               v.appSsiMaster.valid  := '1';               
               v.appSsiMaster.eof    := '1';
               v.appSsiMaster.keep   := r.windowArray(conv_integer(r.txBufferAddr)).keep;
               v.appSsiMaster.eofe   := '0';
               v.txSegmentAddr       := r.txSegmentAddr;
               
               v.appState   := SENT_S;
               
            -- Increment segment address only when not pausing
            elsif (appSsiSlave_i.pause = '0') then
               v.appSsiMaster.valid  := '1';
               v.txSegmentAddr       := r.txSegmentAddr + 1;
            elsif (connActive_i = '0') then
               v.appSsiMaster.valid  := '0';
               v.appSsiMaster.eof    := '1';
               v.appState   := CHECK_BUFFER_S;
            else
               v.appSsiMaster.valid  := '0';
               v.txSegmentAddr       := r.txSegmentAddr;
            end if;
         ----------------------------------------------------------------------
         when SENT_S =>
            
            -- Register the sent SeqN (this means that the place has been freed and the SeqN can be Acked)
            v.rxLastSeqN    := r.windowArray(conv_integer(r.txBufferAddr)).seqN;
            
            -- Counters
            if r.txBufferAddr < (rxWindowSize_i-1) then
               v.txBufferAddr  := r.txBufferAddr+1; -- Increment once
            else
               v.txBufferAddr := (others => '0');
            end if;

            v.windowArray(conv_integer(r.txBufferAddr)).occupied := '0'; -- Release buffer
            
            v.txSegmentAddr := (others => '0');
            
            
            -- SSI parameters
            -- Init the master no SSI communication
            v.appSsiMaster := SSI_MASTER_INIT_C;
           
            -- Next state immediately
            v.appState   := CHECK_BUFFER_S;

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
      
      ---------------------------------------------------------------------
      -- Write and read ports
      wrBuffAddr_o   <= r.rxBufferAddr & r.rxSegmentAddr(SEGMENT_ADDR_SIZE_G-1 downto 0);
      wrBuffWe_o     <= r.segmentWe;
      wrBuffData_o   <= r.tspSsiMaster.data(RSSI_WORD_WIDTH_C*8-1 downto 0);
      rdBuffAddr_o   <= v.txBufferAddr & v.txSegmentAddr(SEGMENT_ADDR_SIZE_G-1 downto 0);
      
      -- Assign outputs
      rxFlags_o      <= r.rxF;
      rxSeqN_o       <= r.rxSeqN;
      rxLastSeqN_o   <= r.rxLastSeqN;
      rxAckN_o       <= r.rxAckN;
      rxValidSeg_o   <= r.segValid;
      rxDropSeg_o    <= r.segDrop;
      chksumEnable_o <= r.chkEn;
      chksumStrobe_o <= r.chkStb;
      chksumLength_o <= r.chkLen;
      rxParam_o      <= r.rxParam;    
      
      -- Transport side SSI output
      tspSsiSlave_o <= v.tspSsiSlave;
      
      -- Application side SSI output
      appSsiMaster_o <= r.appSsiMaster;      
   -----------------------------------------------------------
   end process comb;

   seq : process (clk_i) is
   begin
      if (rising_edge(clk_i)) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   ---------------------------------------------------------------------
end architecture rtl;
