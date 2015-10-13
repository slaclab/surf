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
      AXI_CONFIG_G       : AxiStreamConfigType := ssiAxiStreamConfig(2);
      
      MAX_WINDOW_SIZE_G  : positive := 7;      -- 2^MAX_WINDOW_SIZE_G  = Number of segments
 
      SYN_HEADER_SIZE_G  : natural := 28;
      ACK_HEADER_SIZE_G  : natural := 6;
      EACK_HEADER_SIZE_G : natural := 6;      
      RST_HEADER_SIZE_G  : natural := 6;      
      NULL_HEADER_SIZE_G : natural := 6;
      DATA_HEADER_SIZE_G : natural := 6
   );
   port (
      clk_i      : in  sl;
      rst_i      : in  sl;
      
      -- Connection FSM indicating active connection
      connActive_i : in  sl;
      
      -- Various segment requests
      txSyn_i        : in  sl;
      txAck_i        : in  sl;
      txRst_i        : in  sl;
      txData_i       : in  sl;
      txBuffResend_i : in  sl;
      txNull_i       : in  sl;     
      
  
      -- Data buffer read port
      rdAddr_o     : in  slv( (MAX_SEGMENT_SIZE_C+MAX_WINDOW_SIZE_G)-1 downto 0);
      
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
      windowArray_i    : in WindowTypeArray(0 to 2 ** (MAX_WINDOW_SIZE_G)-1);
      windowSize_i     : in integer range 0 to 2 ** (MAX_WINDOW_SIZE_G-1);
      bufferFull_i     : in sl;
      firstUnackAddr_i : in slv(MAX_WINDOW_SIZE_G-1 downto 0);
      lastSentAddr_i   : in slv(MAX_WINDOW_SIZE_G-1 downto 0);
      ssiBusy_i        : in sl;
      
      -- Tx RSSI data 
      txSeqN_o     : out slv(7 downto 0);
      txDest_o     : out slv(SSI_TDEST_BITS_C-1 downto 0);
      txEofe_o     : out sl;
      
      -- FSM outs for header and data flow control
      synHeadSt_o  : out  sl;
      ackHeadSt_o  : out  sl;
      dataHeadSt_o : out  sl;
      dataSt_o     : out  sl;
      rstHeadSt_o  : out  sl;
      nullHeadSt_o : out  sl;
      
      -- Data mux sources
      headerData_i : in slv(15 downto 0);
      chksumData_i : in slv(15 downto 0);      
      bufferData_i : in slv(15 downto 0);
      
      -- SSI Transport side interface
      tspSsiSlave_i  : in sl;
      tspSsiMaster_o : out  sl;
      
   );
end entity TxFSM;

architecture rtl of TxFSM is
   -- Init SSI bus
   constant SSI_MASTER_INIT_C : SsiMasterType := axis2SsiMaster(AXI_CONFIG_G, AXI_STREAM_MASTER_INIT_C);
   
   type stateType is (
      INIT_S,
      CONN_S
   );
   
   type RegType is record
      -- Counters
      nextSeqN       : slv(7 downto 0);
      seqN           : slv(7 downto 0);
      headerAddr     : slv(7 downto 0);
      segmentAddr    : slv(MAX_SEGMENT_SIZE_C-1 downto 0);
      bufferAddr     : slv(MAX_WINDOW_SIZE_G-1  downto 0);
      
      -- Data mux flags
      synH  : sl;
      ackH  : sl;      
      rstH  : sl;
      nullH : sl;
      dataH : sl;
      dataD : sl;
      -- Varionus controls
      chSum : sl;
      txRdy : sl;
      buffWe: sl;
      buffSent: sl;

      -- SSI master
      ssiMaster      : SsiMasterType;            
      
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
      chSum    => '0',
      txRdy    => '0',      
      buffWe   => '0',
      buffSent => '0',
      
      -- SSI master 
      ssiMaster      => SSI_MASTER_INIT_C,
      
      -- State Machine
      State    => INIT_S
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
begin

   ----------------------------------------------------------------------------------------------- 
   comb : process (r, rst_i) is
      
      variable v : RegType;

   begin
      v := r;
      
      ------------------------------------------------------------
      -- TX FSM
      ------------------------------------------------------------      
      case r.state is
         ----------------------------------------------------------------------
         when INIT_S =>
            -- 
            v.nextSeqN    := initSeqN_i;
            v.seqN        := r.nextSeqN;
            
            v.headerAddr  := (others => '0');
            v.segmentAddr := (others => '0');
             
            v.bufferAddr := lastSentAddr_i;
            --
            v.synH     := '0';
            v.ackH     := '0';
            v.rstH     := '0';
            v.nullH    := '0';       
            v.dataH    := '0';
            v.dataD    := '0';
            --
            v.chSum    := '0';
            v.txRdy    := '1';
            v.buffWe   := '0';
            v.buffSent := '0';

            v.ssiMaster:= SSI_MASTER_INIT_C;          
            
            -- Next state condition   
            if    (txSyn_i = '1') then
               v.state    := SYN_H_S;
            elsif (txAck_i = '1') then
               v.state    := ACK_H_S;
            elsif (connActive_i = '1') then
               v.state      := CONN_S;
               -- Increase the sequence number to point to next seqN.
               --(This seqn will belong to the next Data, Null, or Rst segment).
               v.nextSeqN   := r.nextSeqN + 1;
            end if;
         ----------------------------------------------------------------------
         when CONN_S =>
            -- 
            v.nextSeqN    := r.nextSeqN;
            v.seqN        := r.nextSeqN;
            
            v.headerAddr  := (others => '0');
            v.segmentAddr := (others => '0');
             
            v.bufferAddr := lastSentAddr_i;
            --
            v.synH     := '0';
            v.ackH     := '0';
            v.rstH     := '0';
            v.nullH    := '0';       
            v.dataH    := '0';
            v.dataD    := '0';
            --
            v.chSum    := '0';
            v.txRdy    := '1';
            v.buffWe   := '0';          
            v.buffSent := '0';
            
            v.ssiMaster:=SSI_MASTER_INIT_C;
            
            -- Next state condition   
            if    (txRst_i = '1'  and ssiBusy_i = '0' and bufferFull_i = '0') then
               v.state    := RST_SEQ_S;
            elsif (txData_i = '1' and ssiBusy_i = '0' and bufferFull_i = '0') then
               v.state    := DATA_SEQ_S;
            elsif (txBuffResend_i = '1') then               
               v.state    := BUF_RES_S;
            elsif (txAck_i = '1') then               
               v.state    := ACK_H_S;         
            elsif (txNull_i = '1' and ssiBusy_i = '0' and bufferFull_i = '0') then              
               v.state    := NULL_SEQ_S;         
            elsif (connActive_i = '0') then
               v.state    := INIT_S;
            end if;
         ----------------------------------------------------------------------
         -- SYN packet
         ----------------------------------------------------------------------
         when SYN_H_S =>
             -- Outputs
            v.nextSeqN    := r.nextSeqN;
            v.seqN        := r.nextSeqN;
            
            v.segmentAddr := (others => '0');
            v.bufferAddr := lastSentAddr_i;
            --
            v.synH     := '1';
            v.ackH     := '0';
            v.rstH     := '0';
            v.nullH    := '0';       
            v.dataH    := '0';
            v.dataD    := '0';
            --
            v.chSum    := '0';
            v.txRdy    := '0';
            v.buffWe   := '0';          
            v.buffSent := '0';
            
            -- SSI Control
             
            -- Increment address only when Slave is ready
            if (tspSsiSlave_i.ready = '1') then
               v.headerAddr       := r.headerAddr + 1;
               v.ssiMaster.valid  := '1';
            else 
               v.headerAddr       := r.headerAddr;
               v.ssiMaster.valid  := '0';              
            end if;

            -- Send SOF with header address 0
            if (r.headerAddr = (r.headerAddr'range <= '0')) then
               v.ssiMaster.sof  := '1';
            else
               v.ssiMaster.sof  := '0';
            end if;

            -- Other SSI parameters
            v.ssiMaster.strb   := (others => '1');
            v.ssiMaster.keep   := (others => '1');
            v.ssiMaster.dest   := (others => '0');
            v.ssiMaster.packed := '0';
            v.ssiMaster.eof    := '0';
            v.ssiMaster.eofe   := '0';
            
            -- SSI data (send header part)
            v.ssiMaster.data := headerData_i;

            -- Next state condition
            if    (r.headerAddr >= SYN_HEADER_SIZE_G) then                                      
               v.state   := SYN_CH_S;
            end if;
         ----------------------------------------------------------------------
         when SYN_CH_S =>
             -- Outputs
            v.nextSeqN    := r.nextSeqN;
            v.seqN        := r.nextSeqN;
            
            v.ssiMaster.eof    := '1';
            
            
            v.headerAddr  := (others => '0');
            v.segmentAddr := (others => '0');
             
            v.bufferAddr := lastSentAddr_i;
            --
            v.synH     := '0';
            v.ackH     := '0';
            v.rstH     := '0';
            v.nullH    := '0';       
            v.dataH    := '0';
            v.dataD    := '0';
            --
            v.chSum    := '1';
            v.txRdy    := '0';
            v.buffWe   := '0';      
            v.buffSent := '0';
            
            -- SSI parameters (Send EOF with chksum)
            v.ssiMaster.valid  := '1';
            v.ssiMaster.sof    := '0';
            v.ssiMaster.strb   := (others => '1');
            v.ssiMaster.keep   := (others => '1');
            v.ssiMaster.dest   := (others => '0');
            v.ssiMaster.packed := '0';
            v.ssiMaster.eof    := '1';
            v.ssiMaster.eofe   := '0';
            
            -- SSI data (send chksum part)
            v.ssiMaster.data  := chksumData_i;
            
            -- Next state            
            v.state   := INIT_S;       
         ----------------------------------------------------------------------
         -- ACK packet
         ----------------------------------------------------------------------         
         when ACK_H_S =>
             -- Outputs
            v.nextSeqN    := r.nextSeqN;
            v.seqN        := r.nextSeqN;
            
            v.headerAddr  := r.headerAddr + 1;
            v.segmentAddr := (others => '0');
             
            v.bufferAddr := lastSentAddr_i;
            --
            v.synH     := '0';
            v.ackH     := '1';
            v.rstH     := '0';
            v.nullH    := '0';       
            v.dataH    := '0';
            v.dataD    := '0';
            --
            v.chSum    := '0';
            v.txRdy    := '0';
            v.buffWe   := '0';
            v.buffSent := '0';
            
            -- Next state condition
            if    (r.headerAddr >= ACK_HEADER_SIZE_G) then            
                v.state   := ACK_CH_S;
            end if;
         ----------------------------------------------------------------------
         when ACK_CH_S =>
             -- Outputs
            v.nextSeqN    := r.nextSeqN;
            v.seqN        := r.nextSeqN;

            v.headerAddr  := (others => '0');
            v.segmentAddr := (others => '0');
             
            v.bufferAddr := lastSentAddr_i;
            --
            v.synH     := '0';
            v.ackH     := '0';
            v.rstH     := '0';
            v.nullH    := '0';       
            v.dataH    := '0';
            v.dataD    := '0';
            --
            v.chSum    := '1';
            v.txRdy    := '0';
            v.buffWe   := '0';
            v.buffSent := '0';            

            -- Next state
            if  connActive_i = '0' then            
               v.state   := INIT_S; 
            else
               v.state   := CONN_S;  
            end if;
         ----------------------------------------------------------------------
         -- RST packet
         ----------------------------------------------------------------------         
         when RST_SEQ_S =>
             -- Outputs
            v.nextSeqN    := r.nextSeqN + 1;
            v.seqN        := windowArray_i(r.bufferAddr).seqN;
            
            v.headerAddr  := (others => '0');
            v.segmentAddr := (others => '0');
             
            v.bufferAddr := lastSentAddr_i;
            --
            v.synH     := '0';
            v.ackH     := '0';
            v.rstH     := '0';
            v.nullH    := '0';       
            v.dataH    := '0';
            v.dataD    := '0';
            --
            v.chSum    := '0';
            v.txRdy    := '0';
            v.buffWe   := '1';
            v.buffSent := '0';

            -- Next state condition
            v.state   := RST_H_S;
         ----------------------------------------------------------------------
         when RST_H_S =>
             -- Outputs
            v.nextSeqN    := r.nextSeqN;
            v.headerAddr  := r.headerAddr + 1;
            v.segmentAddr := (others => '0');
             
            v.bufferAddr := lastSentAddr_i;
            --
            v.synH     := '0';
            v.ackH     := '0';
            v.rstH     := '1';
            v.nullH    := '0';       
            v.dataH    := '0';
            v.dataD    := '0';
            --
            v.chSum    := '0';
            v.txRdy    := '0';
            v.buffWe   := '0';
            v.buffSent := '0';

            -- Next state condition
            if    (r.headerAddr >= RST_HEADER_SIZE_G) then            
                v.state   := RST_CH_S;
            end if;            
         ----------------------------------------------------------------------
         when RST_CH_S =>
             -- Outputs
            v.nextSeqN    := r.nextSeqN;
            v.headerAddr  := (others => '0');
            v.segmentAddr := (others => '0');
             
            v.bufferAddr := lastSentAddr_i;
            --
            v.synH     := '0';
            v.ackH     := '0';
            v.rstH     := '0';
            v.nullH    := '0';       
            v.dataH    := '0';
            v.dataD    := '0';
            --
            v.chSum    := '1';
            v.txRdy    := '0';
            v.buffWe   := '0';
            v.buffSent := '1';          

            -- Next state
            v.state   := CONN_S;
            
         ----------------------------------------------------------------------
         -- NULL packet
         ----------------------------------------------------------------------         
         when NULL_SEQ_S =>
             -- Outputs
            v.nextSeqN    := r.nextSeqN + 1;
            v.headerAddr  := r.headerAddr;
            v.segmentAddr := (others => '0');
             
            v.bufferAddr := lastSentAddr_i;
            --
            v.synH     := '0';
            v.ackH     := '0';
            v.rstH     := '0';
            v.nullH    := '0';       
            v.dataH    := '0';
            v.dataD    := '0';
            --
            v.chSum    := '0';
            v.txRdy    := '0';
            v.buffWe   := '1';
            v.buffSent := '0';

            -- Next state condition
            v.state   := NULL_H_S;
         ----------------------------------------------------------------------
         when NULL_H_S =>
             -- Outputs
            v.nextSeqN    := r.nextSeqN;
            v.headerAddr  := r.headerAddr + 1;
            v.segmentAddr := (others => '0');
             
            v.bufferAddr := lastSentAddr_i;
            --
            v.synH     := '0';
            v.ackH     := '0';
            v.rstH     := '0';
            v.nullH    := '1';       
            v.dataH    := '0';
            v.dataD    := '0';
            --
            v.chSum    := '0';
            v.txRdy    := '0';
            v.buffWe   := '0';
            v.buffSent := '0';
            
            -- Next state condition
            if    (r.headerAddr >= NULL_HEADER_SIZE_G) then            
                v.state   := NULL_CH_S;
            end if;        
         ----------------------------------------------------------------------
         when NULL_CH_S =>
             -- Outputs
            v.nextSeqN    := r.nextSeqN;
            v.headerAddr  := (others => '0');
            v.segmentAddr := (others => '0');
             
            v.bufferAddr := lastSentAddr_i;
            --
            v.synH     := '0';
            v.ackH     := '0';
            v.rstH     := '0';
            v.nullH    := '0';       
            v.dataH    := '0';
            v.dataD    := '0';
            --
            v.chSum    := '1';
            v.txRdy    := '0';
            v.buffWe   := '0';         
            v.buffSent := '1';
   
            -- Next state
            v.state   := CONN_S; 

         ----------------------------------------------------------------------
         -- DATA packet
         ----------------------------------------------------------------------         
         when DATA_SEQ_S =>
             -- Outputs
            v.nextSeqN    := r.nextSeqN + 1;
            v.headerAddr  := r.headerAddr;
            v.segmentAddr := (others => '0');
             
            v.bufferAddr := lastSentAddr_i;
            --
            v.synH     := '0';
            v.ackH     := '0';
            v.rstH     := '0';
            v.nullH    := '0';       
            v.dataH    := '0';
            v.dataD    := '0';
            --
            v.chSum    := '0';
            v.txRdy    := '0';
            v.buffWe   := '1';
            v.buffSent := '0';

            -- Next state condition
            v.state   := DATA_H_S;
         ----------------------------------------------------------------------
         when DATA_H_S =>
             -- Outputs
            v.nextSeqN    := r.nextSeqN;
            v.headerAddr  := r.headerAddr + 1;
            v.segmentAddr := (others => '0');
             
            v.bufferAddr := lastSentAddr_i;
            --
            v.synH     := '0';
            v.ackH     := '0';
            v.rstH     := '0';
            v.nullH    := '0';       
            v.dataH    := '1';
            v.dataD    := '0';
            --
            v.chSum    := '0';
            v.txRdy    := '0';
            v.buffWe   := '0';
            v.buffSent := '0';
            
            -- Next state condition
            if    (r.headerAddr >= DATA_HEADER_SIZE_G) then            
                v.state   := DATA_CH_S;
            end if;            
         ----------------------------------------------------------------------
         when DATA_CH_S =>
             -- Outputs
            v.nextSeqN    := r.nextSeqN;
            v.headerAddr  := (others => '0');
            v.segmentAddr := (others => '0');
             
            v.bufferAddr := lastSentAddr_i;
            --
            v.synH     := '0';
            v.ackH     := '0';
            v.rstH     := '0';
            v.nullH    := '0';       
            v.dataH    := '0';
            v.dataD    := '0';
            --
            v.chSum    := '1';
            v.txRdy    := '0';
            v.buffWe   := '0';         
            v.buffSent := '0';
   
            -- Next state
            v.state   := DATA_S;    
         ----------------------------------------------------------------------
         when DATA_S =>
             -- Outputs
            v.nextSeqN    := r.nextSeqN;
            v.headerAddr  := (others => '0');
            v.segmentAddr := r.segmentAddr+1;
             
            v.bufferAddr := lastSentAddr_i;
            --
            v.synH     := '0';
            v.ackH     := '0';
            v.rstH     := '0';
            v.nullH    := '0';       
            v.dataH    := '0';
            v.dataD    := '1';
            --
            v.chSum    := '0';
            v.txRdy    := '0';
            v.buffWe   := '0';         
            v.buffSent := '0';
   
            -- Next state
            v.state   := DATA_SENT_S;
            
         when DATA_SENT_S =>
             -- Outputs
            v.nextSeqN    := r.nextSeqN;
            v.headerAddr  := (others => '0');
            v.segmentAddr := (others => '0');
             
            v.bufferAddr := lastSentAddr_i;
            --
            v.synH     := '0';
            v.ackH     := '0';
            v.rstH     := '0';
            v.nullH    := '0';       
            v.dataH    := '0';
            v.dataD    := '0';
            --
            v.chSum    := '0';
            v.txRdy    := '0';
            v.buffWe   := '0';         
            v.buffSent := '1';
   
            -- Next state
            v.state   := CONN_S;            

         when others =>
            -- Outputs
            v := REG_INIT_C;
         
            -- Next state condition            
            v.state   := INIT_S;            
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
   rdAddr_o     <= r.bufferAddr & r.segmentAddr;
   
   -- Output assignment
   synHeadSt_o  <= r.synH;
   ackHeadSt_o  <= r.ackH; 
   dataHeadSt_o <= r.dataH; 
   dataSt_o     <= r.dataD;
   rstHeadSt_o  <= r.rstH;
   nullHeadSt_o <= r.nullH;
   
   -- Next packet 
   nextSeqN_o   <= r.nextSeqN;

   we_o         <= v.buffWe; 
   sent_o       <= v.buffSent;
   
   -- Sequence number from buffer
   txSeqN_o     <= r.seqN;

   ---------------------------------------------------------------------
end architecture rtl;