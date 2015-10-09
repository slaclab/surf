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
      TPD_G                   : time     := 1 ns;
      AXI_CONFIG_G      : AxiStreamConfigType := ssiAxiStreamConfig(2);
      
      MAX_SEGMENT_SIZE_G      : positive := 10;     -- 2^MAX_SEGMENT_SIZE_G = Number of 16bit wide data words
      MAX_WINDOW_SIZE_G       : positive := 7;      -- 2^MAX_WINDOW_SIZE_G  = Number of segments
 
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
      rdAddr_o     : in  slv( (MAX_SEGMENT_SIZE_G+MAX_WINDOW_SIZE_G)-1 downto 0);
      
      -- Buffer window array input
      we_o         : out sl; -- must be one cc long
      
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
      
      -- FSM outs for header and data flow control
      synHeadSt_o  : out  sl;
      ackHeadSt_o  : out  sl;
      dataHeadSt_o : out  sl;
      dataSt_o     : out  sl;
      rstHeadSt_o  : out  sl;
      nullHeadSt_o : out  sl
      
   );
end entity TxFSM;

architecture rtl of TxFSM is
   
   type stateType is (
      INIT_S,
      CONN_ACT_S
   );
   
   type RegType is record
      -- Counters
      nextSeqN       : slv(7 downto 0);
      headerAddr     : slv(7 downto 0);
      segmentAddr    : slv(MAX_SEGMENT_SIZE_G-1 downto 0);
      bufferAddr    : slv(MAX_WINDOW_SIZE_G-1  downto 0);
      
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
      
      -- State Machine
      State       : StateType;    
   end record RegType;

   constant REG_INIT_C : RegType := (
      --   
      nextSeqN    => (others => '0'),
      headerAddr  => (others => '0'),
      segmentAddr => (others => '0'),
      bufferAddr => (others => '0'),
      
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
            
            
            -- Next state condition   
            if    (txSyn_i = '1') then
               v.state    := SYN_H_S;
            elsif (txAck_i = '1') then
               v.state    := ACK_H_S;
            elsif (connActive_i = '1') then
               v.state    := CONN_S;
            end if;
         ----------------------------------------------------------------------
         when CONN_S =>
            -- 
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
            v.txRdy    := '1';
            v.buffWe   := '0';          
            
            -- Next state condition   
            if    (txRst_i = '1'  and ssiBusy_i = '0') then
               v.state    := RST_SEQ_S;
            elsif (txData_i = '1' and ssiBusy_i = '0') then
               v.state    := DATA_SEQ_S;
            elsif (txBuffResend_i = '1') then               
               v.state    := BUF_RES_S;
            elsif (txAck_i = '1') then               
               v.state    := ACK_H_S;         
            elsif (txNull_i = '1' and ssiBusy_i = '0') then              
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
            v.headerAddr  := r.headerAddr + 1;
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
            
            
            -- Next state condition
            if    (r.headerAddr >= SYN_HEADER_SIZE_G) then            
                v.state   := SYN_CH_S;
            end if;
         ----------------------------------------------------------------------
         when SYN_CH_S =>
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
            
            
            -- Next state            
            v.state   := INIT_S;       
         ----------------------------------------------------------------------
         -- ACK packet
         ----------------------------------------------------------------------         
         when ACK_H_S =>
             -- Outputs
            v.nextSeqN    := r.nextSeqN;
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

            -- Next state condition
            if    (r.headerAddr >= ACK_HEADER_SIZE_G) then            
                v.state   := ACK_CH_S;
            end if;
         ----------------------------------------------------------------------
         when ACK_CH_S =>
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

            -- Next state condition
            v.state   := RST_H_S;
         when RST_H_S =>
             -- Outputs
            v.nextSeqN    := r.nextSeqN;
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

            -- Next state condition
            if    (r.headerAddr >= ACK_HEADER_SIZE_G) then            
                v.state   := ACK_CH_S;
            end if;            
         ----------------------------------------------------------------------
         when ACK_CH_S =>
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

            -- Next state
            if  connActive_i = '0' then            
               v.state   := INIT_S; 
            else
               v.state   := CONN_S;  
            end if;


            
         when others =>
             -- Outputs
            v.firstUnackAddr := ;
            
            -- Next state condition            
            v.state   := INIT_S;            
      ----------------------------------------------------------------------
      end case;
      
      -- Synchronous Reset and Init
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
 
   ----------------------------------------------------------------------------------------------
   ---------------------------------------------------------------------
   -- Combine ram write address
   -- Output assignment

   ---------------------------------------------------------------------
end architecture rtl;