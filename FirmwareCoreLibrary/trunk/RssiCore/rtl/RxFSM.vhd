-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : RxFSM.vhd
-- Author     : Uros Legat  <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory (Cosylab)
-- Created    : 2015-06-11
-- Last update: 2015-06-11
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

entity RxFSM is
   generic (
      TPD_G               : time     := 1 ns;
      WINDOW_ADDR_SIZE_G  : positive := 7     -- 2^WINDOW_ADDR_SIZE_G  = Number of segments
   );
   port (
      clk_i      : in  sl;
      rst_i      : in  sl;
      
      -- Connection FSM indicating active connection
      connActive_i   : in  sl;
      
      -- Window size different for Rx and Tx
      rxWindowSize_i   : in integer range 0 to 2 ** (WINDOW_ADDR_SIZE_G-1);
      txWindowSize_i   : in integer range 0 to 2 ** (WINDOW_ADDR_SIZE_G-1);
      
      -- Last unacknowledged Sequence number connected to TX module
      nextAckN_i   : in slv(7 downto 0);
          
      -- Current received seqN
      rxSeqN_o     : out slv(7 downto 0);
      
      -- Current received ackN
      rxAckN_o     : out slv(7 downto 0);
      
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
      wrBuffAddr_o   : out  slv( (SEGMENT_ADDR_SIZE_C+WINDOW_ADDR_SIZE_G)-1 downto 0);
      wrBuffData_o   : out  slv(RSSI_WORD_WIDTH_C*8-1 downto 0);      
      
      -- Buffer read
      rdBuffAddr_o   : out  slv( (SEGMENT_ADDR_SIZE_C+WINDOW_ADDR_SIZE_G)-1 downto 0);
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
   constant SSI_MASTER_INIT_C   : SsiMasterType := axis2SsiMaster(RSSI_AXI_CONFIG_C, AXI_STREAM_MASTER_INIT_C);
   constant SSI_SLAVE_NOTRDY_C  : SsiSlaveType  := axis2SsiSlave(RSSI_AXI_CONFIG_C, AXI_STREAM_SLAVE_INIT_C, AXI_STREAM_CTRL_INIT_C);
   constant SSI_SLAVE_RDY_C     : SsiSlaveType  := axis2SsiSlave(RSSI_AXI_CONFIG_C, AXI_STREAM_SLAVE_FORCE_C, AXI_STREAM_CTRL_UNUSED_C);
   
   type tspStateType is (
      --
      WAIT_SOF_S,
      CHECK_S,
      SYN_CHECK_S,
      VALID_S,
      DROP_S,
      DATA_PP_S
   );
   
   type RegType is record
      
      -- Transport side FSM (Receive and check segments)
      
      -- Counters
      nextSeqN       : slv(7 downto 0); -- Next expected seqN
      headerAddr     : slv(7 downto 0); 
      segmentAddr    : slv(SEGMENT_ADDR_SIZE_C downto 0);
      bufferAddr     : slv(WINDOW_ADDR_SIZE_G-1  downto 0);
      
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
      
      -- SSI master
      tspSsiMaster   : SsiMasterType;
            
      -- State Machine
      tspState       : TspStateType;    
   end record RegType;

   constant REG_INIT_C : RegType := (
      --   
      nextSeqN    => (others => '0'), -- Next expected seqN
      headerAddr  => (others => '0'),
      segmentAddr => (others => '0'),
      bufferAddr  => (others => '0'),
            
      -- Packet flags
      rxF => (others => ('0')),
      
      -- Received RSSI parameters
      rxParam    => (others => (others => '0')),

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

      -- SSI master 
      tspSsiMaster => SSI_MASTER_INIT_C,

      -- State Machine
      tspState => WAIT_SOF_S
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
begin

   ----------------------------------------------------------------------------------------------- 
   comb : process (r, rst_i, chksumValid_i, chksumOk_i, rxWindowSize_i, nextAckN_i, 
                  txWindowSize_i, tspSsiMaster_i, connActive_i) is
      
      variable v : RegType;

   begin
      v := r;

      ------------------------------------------------------------
      -- RX Transport side FSM:
      -- Receive the segment from the peer
      -- Check the segment:
      -- - seqN, ackN
      -- - 
      ------------------------------------------------------------
      
      -- Pipeline the transport master
      v.tspSsiMaster := tspSsiMaster_i;  
      
      case r.tspState is
         ----------------------------------------------------------------------
         when WAIT_SOF_S =>
         
            -- Counters to 0
            v.headerAddr  := (others => '0');
            v.segmentAddr := (others => '0');
            v.bufferAddr  := (others => '0');
            
            -- Set the initial sequence number
            -- when SYN segment received
            if (connActive_i = '0') then
               v.nextSeqN    := r.rxSeqN+1;
            else
               v.nextSeqN    := r.nextSeqN;
            end if;
            
            -- Ready until SOF received
            tspSsiSlave_o <= SSI_SLAVE_RDY_C;
            
            -- Checksum commands
            v.chkEn    := '0';
            v.chkStb   := '0';
            v.chkLen   := 1;
            --
            v.segValid   := '0';
            v.segDrop    := '0';
            
            -- Next state condition
            if    (tspSsiMaster_i.sof = '1' and tspSsiMaster_i.valid = '1') then
               v.chkEn       := '1';
               v.chkStb      := '1';

               -- When SOF has been received dessert ready until package is checked 
               tspSsiSlave_o <= SSI_SLAVE_NOTRDY_C;
               
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
            
            -- Hold incoming AXI stream
            tspSsiSlave_o <= SSI_SLAVE_NOTRDY_C;
         
            -- Register flags, header length and SEQn
            v.rxF.syn  := r.tspSsiMaster.data (63);
            v.rxF.ack  := r.tspSsiMaster.data (62);
            v.rxF.eack := r.tspSsiMaster.data (61);
            v.rxF.rst  := r.tspSsiMaster.data (60);
            v.rxF.nul  := r.tspSsiMaster.data (59);
            v.rxF.busy := r.tspSsiMaster.data (56);
            
            v.rxHeadLen := r.tspSsiMaster.data (55 downto 48);
            v.rxSeqN    := r.tspSsiMaster.data (47 downto 40);
            v.rxAckN    := r.tspSsiMaster.data (39 downto 32);
            
            -- Checksum commands
            v.chkEn    := '1';
            v.chkStb   := '0';
           
            -- Syn header received (header is 3 c-c long)
            if (v.rxF.syn = '1') then
               
               -- Register SYN header word 0 parameters
               v.chkLen     := 3; -- TODO make generic
               v.rxParam.version    := r.tspSsiMaster.data (31 downto 28);
               v.rxParam.maxOutsSeg := r.tspSsiMaster.data (23 downto 16);
               
               -- Go to SYN_CHECK_S
               v.tspState    := SYN_CHECK_S;
               
            -- Segment is ACK, DATA, RST, or NULL
            elsif (v.rxF.syn = '0' and v.rxF.eack = '0' and chksumValid_i = '1') then   --              
               
               -- Check received data header
               if (
                  -- Checksum
                  chksumOk_i = '1'                           and
                  -- Check length
                  r.rxHeadLen = toSlv(8, 8)                  and
                  -- Check SeqN AckN range
                  r.rxSeqN    >= r.nextSeqN                  and 
                  r.rxSeqN    <  r.nextSeqN + rxWindowSize_i and
                  r.rxAckN    >= nextAckN_i                  and
                  r.rxAckN    <  nextAckN_i + txWindowSize_i
               ) then
                  -- Header is valid                
                  v.tspState    := VALID_S;                  
               else
                  -- Header not valid                
                  v.tspState    := DROP_S;               
               end if;           
            end if;
            
         ----------------------------------------------------------------------
         when SYN_CHECK_S =>
                     --
            v.segValid   := '0';
            v.segDrop    := '0';
            
            -- Get the rest of the SYN header
            tspSsiSlave_o <= SSI_SLAVE_RDY_C;
            
            if (tspSsiMaster_i.valid = '1') then
               v.chkStb      := '1';
               v.headerAddr  := r.headerAddr + 1;
            else
               v.chkStb      := '0';
               v.headerAddr  := r.headerAddr;
            end if;
            
            -- Register SYN header word 1 parameters
            if (r.headerAddr = x"01" ) then
               -- Syn parameters              
               v.rxParam.maxSegSize  := r.tspSsiMaster.data (63 downto 48);
               v.rxParam.retransTout := r.tspSsiMaster.data (47 downto 32);
               v.rxParam.cumulAckTout:= r.tspSsiMaster.data (31 downto 16);
               v.rxParam.nullSegTout := r.tspSsiMaster.data (15 downto 0);
            end if;
            
            -- Register SYN header word 2 parameters
            if (r.headerAddr = x"02" ) then
               v.chkStb      := '0';
               v.headerAddr  := r.headerAddr;
               tspSsiSlave_o <= SSI_SLAVE_NOTRDY_C;
               
               if (r.tspSsiMaster.valid = '1') then
                  -- Syn parameters
                  v.rxParam.maxRetrans  := r.tspSsiMaster.data (63 downto 56);
                  v.rxParam.maxCumAck   := r.tspSsiMaster.data (55 downto 48);
                  v.rxParam.maxOutofseq := r.tspSsiMaster.data (47 downto 40);
                  v.rxParam.maxAutoRst  := r.tspSsiMaster.data (39 downto 32);
                  v.rxParam.connectionId:= r.tspSsiMaster.data (31 downto 16);
               end if;
               
               -- Wait for checksum
               if ( chksumValid_i = '1') then 
                  -- Check received data header
                  if (
                     -- Checksum
                     chksumOk_i = '1' and
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
         when VALID_S =>
            --
            v.segValid   := '1';
            v.segDrop    := '0';
            --
            v.chkEn    := '0';
            v.chkStb   := '0';
            --
            tspSsiSlave_o <= SSI_SLAVE_NOTRDY_C;
            
            -- Next state condition
            if (r.rxF.syn = '0' and r.rxF.eack = '0' and r.rxF.data = '1') then
               -- Valid data packet received
               v.tspState    := DATA_PP_S;
            else
               -- Get ready to receive new packet
               v.tspState    := WAIT_SOF_S;
            end if;
 
         ----------------------------------------------------------------------
         when DROP_S =>         
            --
            v.segValid   := '0';
            v.segDrop    := '1';
            --
            v.chkEn    := '0';
            v.chkStb   := '0';
            --
            tspSsiSlave_o <= SSI_SLAVE_NOTRDY_C;
            
            -- Get ready to receive new packet
            v.tspState    := WAIT_SOF_S;
            
         ----------------------------------------------------------------------
         when others =>
            --
            v := REG_INIT_C;
            --
            tspSsiSlave_o <= SSI_SLAVE_NOTRDY_C;            
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
   -- Write and read ports
   wrBuffAddr_o   <= r.bufferAddr & r.segmentAddr(SEGMENT_ADDR_SIZE_C-1 downto 0);
   wrBuffData_o   <= (others =>'0');
   rdBuffAddr_o   <= (others =>'0');
   
   -- Assign outputs
   rxFlags_o      <= r.rxF;
   rxSeqN_o       <= r.rxSeqN;
   rxAckN_o       <= r.rxAckN;
   rxValidSeg_o   <= r.segValid;
   rxDropSeg_o    <= r.segDrop;
   chksumEnable_o <= r.chkEn;
   chksumStrobe_o <= r.chkStb;
   chksumLength_o <= r.chkLen;
   rxParam_o      <= r.rxParam;
   
   -- Temporaty !!!!!!!!!!!!!
   appSsiMaster_o <= SSI_MASTER_INIT_C;
   ---------------------------------------------------------------------
end architecture rtl;