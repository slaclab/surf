-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : TxBuffer.vhd
-- Author     : Uros Legat  <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory (Cosylab)
-- Created    : 2015-08-09
-- Last update: 2015-08-09
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--       TODO Remove the commented out EACK stuff if argument accepted       
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

entity TxBuffer is
   generic (
      TPD_G                   : time     := 1 ns;
      AXI_CONFIG_G      : AxiStreamConfigType := ssiAxiStreamConfig(2);
      
      MAX_WINDOW_SIZE_G       : positive := 7;      -- 2^MAX_WINDOW_SIZE_G  = Number of segments
      -- MAX_RX_NUM_OUTS_SEG_G   : positive := 128; -- Max number out of sequence segments (EACK)
      AXIS_DATA_WIDTH_G       : positive := 16      -- 
   );
   port (
      clk_i      : in  sl;
      rst_i      : in  sl;
      
      -- Initialize (example: when the connection is lost stay in init)
      init_i     : in  sl;
      
      -- SSI input from the Application side
      appSsiMaster_i : in  SsiMasterType;
      appSsiSlave_o  : out SsiSlaveType;

      
      -- Data buffer read port
      rdAddr_i     : in  slv( (MAX_SEGMENT_SIZE_C+MAX_WINDOW_SIZE_G)-1 downto 0);
      rdData_o     : out slv(15 downto 0);
      
      -- Buffer window array input
      we_i         : in sl; -- must be one cc long
      sent_i       : in sl; -- must be one cc long
      txRdy_i      : in sl;
      
      rstHeadSt_i  : in  sl;
      dataHeadSt_i : in  sl;
      nullHeadSt_i : in  sl;

      -- Window buff size (Depends on the number of outstanding segments)
      windowSize_i   : in integer range 0 to 2 ** (MAX_WINDOW_SIZE_G-1); -- 
      
      -- Next sequence number
      nextSeqN_i     : in slv(7 downto 0);    
     
      -- Acknowledge mechanism
      ack_i         : in sl;                   -- From receiver module when a segment with valid ACK is received
      ackN_i        : in slv(7 downto 0);      -- Number being ACKed
      --eack_i        : in sl;                 -- From receiver module when a segment with valid EACK is received
      --eackSeqnArr_i : in Slv8Array(0 to MAX_RX_NUM_OUTS_SEG_G-1); -- Array of sequence numbers received out of order
      
      -- Output to TxFSM
      txData_o         : out sl;
      windowArray_o    : out WindowTypeArray(0 to 2 ** (MAX_WINDOW_SIZE_G)-1);
      bufferFull_o     : out sl;
      firstUnackAddr_o : out slv(MAX_WINDOW_SIZE_G-1 downto 0);
      lastSentAddr_o   : out slv(MAX_WINDOW_SIZE_G-1 downto 0);
      ssiBusy_o        : out sl;
      
      -- Errors (1 cc pulse)
      lenErr_o         : out sl;
      ackErr_o         : out sl
   );
end entity TxBuffer;

architecture rtl of TxBuffer is
   
   -- Init SSI bus
   constant SSI_MASTER_INIT_C : SsiMasterType := axis2SsiMaster(AXI_CONFIG_G, AXI_STREAM_MASTER_INIT_C);
   constant SSI_SLAVE_INIT_C  : SsiSlaveType  := axis2SsiSlave(AXI_CONFIG_G, AXI_STREAM_SLAVE_INIT_C, AXI_STREAM_CTRL_UNUSED_C);
   
   type stateType is (
      IDLE_S,
      ACK_S,
      --EACK_S,
      ERR_S,
      WAIT_SOF_S,
      SEG_RCV_S,
      SEG_RDY_S,
      SEG_LEN_ERR,
      WAIT_TX_S
   );
   
   type RegType is record
      -- Window control
      firstUnackAddr : slv(MAX_WINDOW_SIZE_G-1 downto 0);
      lastSentAddr   : slv(MAX_WINDOW_SIZE_G-1 downto 0);
      --eackAddr       : slv(MAX_WINDOW_SIZE_G-1 downto 0);
      --eackIndex      : integer;      
      bufferFull     : sl;
      windowArray    : WindowTypeArray(0 to 2 ** (MAX_WINDOW_SIZE_G)-1);
      ackErr         : sl;
      
      -- SSI data RX      
      segmentAddr    : slv(MAX_SEGMENT_SIZE_C downto 0); -- One address bit more to check the overflow
      segmentWe      : sl;
      txData         : sl;
      lenErr         : sl;
      ssiBusy        : sl;
      
      ssiMaster      : SsiMasterType;
      ssiSlave       : SsiSlaveType; 
      
      -- State Machine
      ackState       : StateType;
      ssiState       : StateType;     
      
   end record RegType;

   constant REG_INIT_C : RegType := (
      -- Window control   
      firstUnackAddr => (others => '0'),
      lastSentAddr   => (others => '0'),
      --eackAddr       => (others => '0'),
      --eackIndex      => 0,
      bufferFull     => '0',
      windowArray    => (0 to 127 => WINDOW_INIT_C),
      ackErr         => '0',
      
      -- SSI data RX        
      segmentAddr     => (others => '0'),
      segmentWe       => '0',
      txData          => '0',
      lenErr          => '0',
      ssiBusy         => '0',
      
      ssiMaster      => SSI_MASTER_INIT_C,     
      ssiSlave       => SSI_SLAVE_INIT_C,
      
      -- State Machine
      ackState        => IDLE_S,
      ssiState        => IDLE_S
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
   signal s_buffWAddr : slv((MAX_SEGMENT_SIZE_C+MAX_WINDOW_SIZE_G)-1  downto 0);
     
begin
   

   ----------------------------------------------------------------------------------------------
   ---------------------------------------------------------------------
   -- Combine ram write address
   s_buffWAddr <= r.lastSentAddr & r.segmentAddr(MAX_SEGMENT_SIZE_C-1 downto 0);
   ----------------------------------------------------------------------------------------------      
   -- Buffer memory 
   SimpleDualPortRam_INST: entity work.SimpleDualPortRam
   generic map (
      TPD_G          => TPD_G,
      DATA_WIDTH_G   => AXIS_DATA_WIDTH_G,
      ADDR_WIDTH_G   => (MAX_SEGMENT_SIZE_C+MAX_WINDOW_SIZE_G)
   )
   port map (
      -- Port A - Write only
      clka  => clk_i,
      wea   => r.segmentWe,
      addra => s_buffWAddr,
      dina  => r.ssiMaster.data(AXIS_DATA_WIDTH_G-1 downto 0),
      
      -- Port B - Read only 
      clkb  => clk_i,
      rstb  => rst_i,
      addrb => rdAddr_i,
      doutb => rdData_o);

   ----------------------------------------------------------------------------------------------- 
   comb : process (r, rst_i, we_i, ack_i, windowSize_i, nextSeqN_i, rstHeadSt_i, dataHeadSt_i, 
                  nullHeadSt_i, ackN_i, init_i, txRdy_i, appSsiMaster_i, sent_i) is
      
      variable v : RegType;

   begin
      v := r;
      ------------------------------------------------------------
      -- Buffer full condition
      if (  (r.lastSentAddr - r.firstUnackAddr) >= (windowSize_i-1) ) then
         v.bufferFull := '1';
      else
         v.bufferFull := '0';
      end if;
      
      ------------------------------------------------------------
      -- Write sequence and to window array
      ------------------------------------------------------------
      if (we_i = '1') then
         v.windowArray(conv_integer(r.lastSentAddr)).seqN    := nextSeqN_i;
         v.windowArray(conv_integer(r.lastSentAddr)).segType := rstHeadSt_i & nullHeadSt_i & dataHeadSt_i;
         --v.windowArray(conv_integer(r.lastSentAddr)).tDest   := (others => '0');
         --v.windowArray(conv_integer(r.lastSentAddr)).eofe    := '0';        
         --v.windowArray(conv_integer(r.lastSentAddr)).eacked  := '0';          
      else 
         v.windowArray      := r.windowArray;
      end if;
      
      ------------------------------------------------------------
      -- When buffer is sent increase lastSentAddr
      ------------------------------------------------------------
      if (sent_i = '1') then

         if r.lastSentAddr < windowSize_i then 
            v.lastSentAddr := r.lastSentAddr +1;
         else
            v.lastSentAddr := (others => '0');
         end if;
            
      else 
         v.lastSentAddr     := r.lastSentAddr;
      end if;
      
      
      ------------------------------------------------------------
      -- ACK FSM
      -- Acknowledgment mechanism to increment firstUnackAddr
      -- Place out of order flags from EACK table
      ------------------------------------------------------------      
      case r.ackState is
         ----------------------------------------------------------------------
         when IDLE_S =>
         
            -- Hold ACK address
            v.firstUnackAddr := r.firstUnackAddr;
            --v.eackAddr       := r.firstUnackAddr;
            --v.eackIndex      := 0;
            v.ackErr         := '0';
            
            
            -- Next state condition (TODO consider adding re_i = '0' if read should have priority)          
            if (ack_i = '1') then
               v.ackState    := ACK_S;
            end if;
         ----------------------------------------------------------------------
         when ACK_S =>
         
            -- Increment ACK address
            if r.firstUnackAddr < windowSize_i then 
                  v.firstUnackAddr  := r.firstUnackAddr+1;
            else
                  v.firstUnackAddr  := (others => '0');
            end if;
            
            --v.eackAddr       := r.firstUnackAddr;
           -- v.eackIndex      := 0;
            v.ackErr         := '0';
            
            -- Next state condition            
            if  r.windowArray(conv_integer(r.firstUnackAddr)).seqN = ackN_i  then
               --if eack_i = '1' then
                  -- Go back to init when the acked seqN is found            
               --   v.ackState   := EACK_S;               
               --else
                  -- Go back to init when the acked seqN is found            
                  v.ackState   := IDLE_S;
               --end if;
            elsif (r.firstUnackAddr = r.lastSentAddr and r.windowArray(conv_integer(r.firstUnackAddr)).seqN = ackN_i) then  
               -- If the acked seqN is not found go to error state
               v.ackState   := ERR_S;            
            end if;
         ----------------------------------------------------------------------
         -- when EACK_S =>
         
            -- -- Increment EACK address from firstUnackAddr to lastSentAddr
            -- if r.eackAddr < windowSize_i then 
               -- v.eackAddr  := r.eackAddr+1;
            -- else
               -- v.eackAddr  := (others => '0');
            -- end if;
            
            -- -- For every address check if the sequence number equals value from eackSeqnArr_i array.
            -- -- If it matches mark the eack field at the address and compare the next value from the table.          
            -- if  r.windowArray(conv_integer(r.eackAddr)).seqN = eackSeqnArr_i(r.eackIndex)  then
               -- v.windowArray(conv_integer(r.eackAddr)).eacked := '1';
               -- v.eackIndex := r.eackIndex + 1;               
            -- end if;
            
            -- v.firstUnackAddr  := r.firstUnackAddr;
            -- v.ackErr          := '0';
            
            -- -- Next state condition 
            -- if (r.eackAddr = r.lastSentAddr) then
               -- -- If the acked seqN is not found go to error state
               -- v.ssiState   := IDLE_S;
            -- end if;
         ----------------------------------------------------------------------
         when ERR_S =>
            -- Outputs
            v.firstUnackAddr := r.firstUnackAddr;
            --v.eackAddr       := r.firstUnackAddr;
            --v.eackIndex      := 0;
            v.ackErr         := '1';
            
            -- Next state condition            
            v.ackState   := IDLE_S;            
         ----------------------------------------------------------------------
         when others =>
             -- Outputs
            v.firstUnackAddr := r.firstUnackAddr;
            -- v.eackAddr       := r.firstUnackAddr;
            -- v.eackIndex      := 0;
            v.ackErr         := '1';

            -- Next state condition            
            v.ackState   := IDLE_S;            
      ----------------------------------------------------------------------
      end case;
      
      ------------------------------------------------------------
      -- SSI RX FSM
      -- 
      ------------------------------------------------------------
      -- Delay Master (DFF)
      v.ssiMaster    := appSsiMaster_i;
      ------------------------------------------------------------
      case r.ssiState is
         ----------------------------------------------------------------------
         when IDLE_S =>
         
            -- SSI
            v.ssiSlave.ready      := '0';
            v.ssiSlave.pause      := '1';       
            v.ssiSlave.overflow   := '0';
            
            -- Buffer write ctl
            v.segmentAddr := (others =>'0');
            v.segmentWe   := '0';

            -- txFSM
            v.txData      := '0';
            v.lenErr      := '0';
            v.ssiBusy     := '0';
            
            -- Wait until buffer is full
            if (r.bufferFull = '0') then
               v.ssiState    := WAIT_SOF_S;
            end if;
         ----------------------------------------------------------------------
         when WAIT_SOF_S =>
         
            -- SSI Ready to receive data from APP
            v.ssiSlave.ready      := '1';
            v.ssiSlave.pause      := '0';       
            v.ssiSlave.overflow   := '0';
                        
            -- Buffer write ctl
            v.segmentAddr := (others =>'0');
            v.segmentWe   := '0';
            
            -- txFSM
            v.txData      := '0';
            v.lenErr      := '0';
            v.ssiBusy     := '0';
            
            -- If other segment (NULL, or RST) is requested return to IDLE_S to
            -- check if buffer is still available (not full)
            if (we_i = '1') then
               v.ssiState    := IDLE_S;
            -- Wait until receiving the first data            
            elsif (r.ssiMaster.sof = '1' and r.ssiMaster.valid = '1') then
               
               -- First data already received at this point
               v.segmentAddr := r.segmentAddr + 1 ;
               v.ssiBusy     := '1';
               
               -- Save SSI parameters
               v.windowArray(conv_integer(r.lastSentAddr)).dest   := r.ssiMaster.dest;
               v.windowArray(conv_integer(r.lastSentAddr)).strb   := r.ssiMaster.strb;
               v.windowArray(conv_integer(r.lastSentAddr)).keep   := r.ssiMaster.keep;
               v.windowArray(conv_integer(r.lastSentAddr)).packed := r.ssiMaster.packed;
            
               v.ssiState    := SEG_RCV_S;
               
            -- If only one SSI word received (go directly to ready!)
            -- This is the case when both SOF and EOF are asserted.
            elsif (r.ssiMaster.sof = '1' and r.ssiMaster.valid = '1' and r.ssiMaster.eof = '1' ) then
            
               -- First data already received at this point
               v.segmentAddr := r.segmentAddr;  -- TODO check if it should be incremented or not
               v.ssiBusy     := '1';
            
               -- Save SSI parameters
               v.windowArray(conv_integer(r.lastSentAddr)).dest   := r.ssiMaster.dest;
               v.windowArray(conv_integer(r.lastSentAddr)).strb   := r.ssiMaster.strb;
               v.windowArray(conv_integer(r.lastSentAddr)).keep   := r.ssiMaster.keep;
               v.windowArray(conv_integer(r.lastSentAddr)).packed := r.ssiMaster.packed;
               
               v.windowArray(conv_integer(r.lastSentAddr)).eofe    := r.ssiMaster.eofe;
               v.windowArray(conv_integer(r.lastSentAddr)).segSize := r.segmentAddr; 
            
               v.ssiState    := SEG_RDY_S;
                        -- If one SSI word received
            end if;
         ----------------------------------------------------------------------
         when SEG_RCV_S =>
         
            -- SSI
            v.ssiSlave.ready      := '1';
            v.ssiSlave.pause      := '0';       
            v.ssiSlave.overflow   := '0';
            
            -- Buffer write ctl
            if (r.ssiMaster.valid = '1') then          
               v.segmentAddr := r.segmentAddr + 1 ;
               v.segmentWe   := '1';
            else
               v.segmentAddr := r.segmentAddr;
               v.segmentWe   := '0';            
            end if;   
            
            -- txFSM
            v.txData      := '0';
            v.lenErr      := '0';
            v.ssiBusy     := '1';            
            
            -- Wait until receiving EOF 
            if (r.ssiMaster.eof = '1' ) then
            
               -- Save packet eofe (error)
               v.windowArray(conv_integer(r.lastSentAddr)).eofe    := r.ssiMaster.eofe;
               v.windowArray(conv_integer(r.lastSentAddr)).segSize := r.segmentAddr;
                         
               v.ssiState    := SEG_RDY_S;        
            elsif (r.segmentAddr(MAX_SEGMENT_SIZE_C) = '1' ) then
               v.ssiState    := SEG_LEN_ERR;           
            end if;
         ----------------------------------------------------------------------            
         when SEG_RDY_S =>
         
            -- SSI
            v.ssiSlave.ready      := '0';
            v.ssiSlave.pause      := '1';       
            v.ssiSlave.overflow   := '0';
            
            v.segmentAddr := (others =>'0');
            v.segmentWe   := '0';
            
            -- Request data at txFSM
            v.txData      := '1';
            v.lenErr      := '0';
            v.ssiBusy     := '1';
            
            -- Hold request until accepted
            if (dataHeadSt_i = '1') then
               v.ssiState    := WAIT_TX_S;
            end if;
         ----------------------------------------------------------------------
         when WAIT_TX_S => 
         
            -- SSI
            v.ssiSlave.ready      := '0';
            v.ssiSlave.pause      := '1';       
            v.ssiSlave.overflow   := '0';
            
            v.segmentAddr := (others =>'0');
            v.segmentWe   := '0';
            
            -- Request data at txFSM
            v.txData      := '0';
            v.lenErr      := '0';
            v.ssiBusy     := '1';
            
            -- Wait until txFSM sends the packet 
            if (txRdy_i = '1') then
               v.ssiState    := IDLE_S;
            end if;
         ----------------------------------------------------------------------
         when SEG_LEN_ERR => 
         
            -- SSI
            v.ssiSlave.ready      := '0';
            v.ssiSlave.pause      := '1';
            -- Overflow happened (packet too big)            
            v.ssiSlave.overflow   := '1';
            
            v.segmentAddr := (others =>'0');
            v.segmentWe   := '0';
            
            -- Request data at txFSM
            v.txData      := '0';
            v.lenErr      := '1';
            v.ssiBusy     := '1';
            
            -- Go back to idle 
            v.ssiState    := IDLE_S;
         ----------------------------------------------------------------------
         when others =>
            -- Outs
            v := REG_INIT_C;

            -- Next state condition            
            v.ssiState   := IDLE_S;            
      ----------------------------------------------------------------------
      end case;

      -- Synchronous Reset and Init
      if (rst_i = '1' or init_i = '1') then
         v := REG_INIT_C;
      end if;
      
      rin <= v;
      -----------------------------------------------------------------------
   end process comb;

   seq : process (clk_i) is
   begin
      if (rising_edge(clk_i)) then
         r <= rin after TPD_G;
      end if;
   end process seq;
 
   ---------------------------------------------------------------------   
   -- Output assignment
   windowArray_o     <= r.windowArray;
   bufferFull_o      <= r.bufferFull;
   firstUnackAddr_o  <= r.firstUnackAddr;
   lastSentAddr_o    <= r.lastSentAddr;
   txData_o          <= r.txData;
   
   ssiBusy_o         <= r.ssiBusy;
   lenErr_o          <= r.lenErr;
   ackErr_o          <= r.ackErr;

   appSsiSlave_o     <= r.ssiSlave;
   ---------------------------------------------------------------------
end architecture rtl;