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
use ieee.math_real.all;

entity TxBuffer is
   generic (
      TPD_G                   : time     := 1 ns;
      AXI_CONFIG_G      : AxiStreamConfigType := ssiAxiStreamConfig(2));
      
      MAX_SEGMENT_SIZE_G      : positive := 10;     -- 2^MAX_SEGMENT_SIZE_G = Number of 16bit wide data words
      MAX_WINDOW_SIZE_G       : positive := 7;    -- 2^MAX_WINDOW_SIZE_G  = Number of segments
      -- MAX_RX_NUM_OUTS_SEG_G   : positive := 128; -- Max number out of sequence segments (EACK)
      AXIS_DATA_WIDTH_G       : positive := 16   -- 
   );
   port (
      clk_i      : in  sl;
      rst_i      : in  sl;
      
      -- Initialize (example: when the connection is lost stay in init)
      init_i     : in  sl;
      
      -- SSI input from the Application side
      appAxisMaster_i : in  AxiStreamMasterType;
      appAxisSlave_o  : out AxiStreamSlaveType;
      appAxisCtrl_o   : out AxiStreamCtrlType;
      
      -- Data buffer read port
      rdAddr_i     : in  slv( (MAX_SEGMENT_SIZE_G+MAX_WINDOW_SIZE_G)-1 downto 0);
      rdData_o     : out slv(15 downto 0);
      
      -- Buffer window array input
      we_i         : in sl; -- must be one cc long
      txRdy_i      : in sl;
      
      rstHeadSt_i  : in  sl;
      dataHeadSt_i : in  sl;
      nullHeadSt_i : in  sl;

      -- Window buff size (Depends on the number of outstanding segments)
      windowSize_i   : in integer range 0 to MAX_WINDOW_SIZE_G-1; -- 
      
      -- Sequence next sequence number
      seqN_i     : in slv(7 downto 0);    
     
      -- Acknowledge mechanism
      ack_i         : in sl;                   -- From receiver module when a packet with valid ACK is received
      ackN_i        : in slv(7 downto 0);      -- Number being ACKed
      --eack_i        : in sl;                   -- From receiver module when a packet with valid EACK is received
      --eackSeqnArr_i : in Slv8Array(0 to MAX_RX_NUM_OUTS_SEG_G-1); -- Array of sequence numbers received out of order
      
      -- 
      windowArray_o    : out WindowTypeArray;
      bufferFull_o     : out sl;
      firstUnackAddr_o : out slv(MAX_WINDOW_SIZE_G-1 downto 0);
      lastSentAddr_o   : out slv(MAX_WINDOW_SIZE_G-1 downto 0)
      
   );
end entity TxBuffer;

architecture rtl of TxBuffer is
   
   type stateType is (
      IDLE_S,
      ACK_S,
      --EACK_S,
      ERR_S      
   );
   
   type RegType is record
      -- Window control
      firstUnackAddr : slv(7  downto 0);
      lastSentAddr   : slv(7  downto 0);
      eackAddr       : slv(7  downto 0);
      eackIndex      : integer;      
      bufferFull     : sl;
      windowArray    : WindowTypeArray;
      ackErr         : sl;
      
      -- SSI data RX      
      packetAddr     : slv(7  downto 0);
      packetWe       : sl;
      ssiMaster      : SsiMasterType;
      ssiSlave       : SsiMasterType; 
      
      -- State Machine
      ackState       : StateType;
      ssiState       : StateType;     
      
   end record RegType;

   constant REG_INIT_C : RegType := (
      -- Window control   
      firstUnackAddr => (others => '0'),
      lastSentAddr   => (others => '0'),
      eackAddr       => (others => '0'),
      eackIndex      => 0,
      bufferFull     => '0',
      windowArray    => (others => WINDOW_INIT_C),
      ackErr         => '0',
      
      -- SSI data RX        
      packetAddr     => (others => '0'),
      packetWe       => '0',
      
      ssiMaster      => axis2SsiMaster(SSI_CONFIG_INIT_C, AXI_STREAM_MASTER_INIT_C);     
      ssiSlave       => axis2SsiSlave(AXI_STREAM_SLAVE_INIT_C, AXI_STREAM_CTRL_UNUSED_C);
      
      -- State Machine
      ackState        => IDLE_S,
      ssiState        => IDLE_S
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
   signal s_buffWAddr : slv((MAX_SEGMENT_SIZE_G+MAX_WINDOW_SIZE_G)-1  downto 0);
   signal s_ssiMaster : SsiMasterType;
     
begin
   
   ---------------------------------------------------------------------------------------------- 
   -- Convert from SSI to Axis and back
   appAxisSlave_o <= ssi2AxisSlave(r.ssiSlave);
   appAxisCtrl_o  <= ssi2AxisCtrl(r.ssiSlave);
   
   ----------------------------------------------------------------------------------------------   
   -- Buffer memory 
   SimpleDualPortRam_INST: entity work.SimpleDualPortRam
   generic map (
      TPD_G          => TPD_G,
      DATA_WIDTH_G   => AXIS_DATA_WIDTH_G,
      ADDR_WIDTH_G   => (MAX_SEGMENT_SIZE_G+MAX_WINDOW_SIZE_G)
   port map (
      -- Port A - Write only
      clka  => clk_i,
      wea   => r.packetWe,
      addra => s_buffWAddr,
      dina  => r.ssiMaster.data(AXIS_DATA_WIDTH_G-1 downto 0),
      
      -- Port B - Read only 
      clkb  => clk_i,
      rstb  => rst_i,
      addrb => rdAddr_i,
      doutb => rdData_o);

   ----------------------------------------------------------------------------------------------- 
   comb : process (r, rst_i, we_i, ack_i, windowSize_i, seqN_i, rstHeadSt_i, dataHeadSt_i, 
                  nullHeadSt_i, ackN_i, eack_i, eackSeqnArr_i, init_i, txRdy_i) is
      
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
      -- Write to window array and increase lastSentAddr
      ------------------------------------------------------------
      if (we_i = '1' and r.bufferFull='0') then
         v.windowArray(conv_integer(r.lastSentAddr)).seqN    := seqN_i;
         v.windowArray(conv_integer(r.lastSentAddr)).segType := rstHeadSt_i & nullHeadSt_i & dataHeadSt_i;
         v.windowArray(conv_integer(r.lastSentAddr)).tDest   := (others => '0');
         --v.windowArray(conv_integer(r.lastSentAddr)).eofe    := '0';        
         --v.windowArray(conv_integer(r.lastSentAddr)).eacked  := '0';
         --v.windowArray(conv_integer(r.lastSentAddr)).sent    := '1';

         if r.lastSentAddr < windowSize_i then 
            v.lastSentAddr := r.lastSentAddr +1;
         else
            v.lastSentAddr := (others => '0');
         end if;
            
      else 
         v.windowArray      := r.windowArray;
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
            v.eackAddr       := r.firstUnackAddr;
            v.eackIndex      := 0;
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
            
            v.eackAddr       := r.firstUnackAddr;
            v.eackIndex      := 0;
            v.ackErr         := '0';
            
            -- Next state condition            
            if  r.windowArray(conv_integer(r.firstUnackAddr)).seqN = ackN_i  then
               if eack_i = '1' then
                  -- Go back to init when the acked seqN is found            
                  v.ackState   := EACK_S;               
               else
                  -- Go back to init when the acked seqN is found            
                  v.ackState   := IDLE_S;
               end if;
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
            v.eackAddr       := r.firstUnackAddr;
            v.eackIndex      := 0;
            v.ackErr         := '1';
            
            -- Next state condition            
            v.ackState   := IDLE_S;            
         ----------------------------------------------------------------------
         when others =>
             -- Outputs
            v.firstUnackAddr := r.firstUnackAddr;

            -- Next state condition            
            v.ackState   := IDLE_S;            
      ----------------------------------------------------------------------
      end case;
      
      ------------------------------------------------------------
      -- SSI RX FSM
      -- 
      ------------------------------------------------------------
      -- Convert AXIS to SSI master
      v.ssiMaster    := axis2SsiMaster(appAxisMaster_i, AXI_CONFIG_G);
      ------------------------------------------------------------
      case r.ssiState is
         ----------------------------------------------------------------------
         when IDLE_S =>
         
            -- SSI
            v.ssiSlave.ready      := '0';
            v.ssiSlave.pause      := '1';       
            v.ssiSlave.overflow   := '0';
            
            v.packetAddr := (others =>'0');
            v.packetWe   := '0';
            
            -- Wait until buffer is full
            if (r.bufferFull = '0') then
               v.ssiState    := WAIT_SOF_S;
            end if;
         ----------------------------------------------------------------------
         when WAIT_SOF_S =>
         
            -- SSI
            v.ssiSlave.ready      := '1';
            v.ssiSlave.pause      := '0';       
            v.ssiSlave.overflow   := '0';
            
            v.packetAddr := (others =>'0');
            v.packetWe   := '0';
            
            -- Wait until receiving the first data
            
            if (r.ssiMaster.sof = '1') then
               v.ssiState    := PCT_RCV_S;
               
               -- Save 
               
            end if;

         when PCT_RCV_S =>
         
            -- SSI
            v.ssiSlave.ready      := '1';
            v.ssiSlave.pause      := '0';       
            v.ssiSlave.overflow   := '0';
            
            if (r.ssiMaster.valid = '1') then          
               v.packetAddr := r.packetAddr + 1 ;
               v.packetWe   := '1';
            else
               v.packetAddr := r.packetAddr;
               v.packetWe   := '0';            
            end if;   
            
            -- Wait until receiving EOF
            if (r.ssiMaster.sof = '1') then
               v.ssiState    := EOF_S;
            end if;

            
         ----------------------------------------------------------------------
         when others =>
             -- Outputs
            v.firstUnackAddr := r.firstUnackAddr;

            -- Next state condition            
            v.ssiState   := IDLE_S;            
      ----------------------------------------------------------------------
      end case;

      -- Synchronous Reset and Init
      if (rst_i = '1' or init_i = '1') then
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
   -- Output assignment
   windowArray_o     <= r.windowArray;
   bufferFull_o      <= r.bufferFull;
   firstUnackAddr_o  <= r.firstUnackAddr;
   lastSentAddr_o    <= r.lastSentAddr;
   ---------------------------------------------------------------------
end architecture rtl;