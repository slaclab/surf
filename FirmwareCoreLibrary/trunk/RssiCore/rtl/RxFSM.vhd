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
           
      -- Last seqN received in order
      rxSeqN_o     : out slv(7 downto 0);
      
      -- Last seqN acked by peer
      rxAckN_o     : out slv(7 downto 0);
      
      -- Valid Segment received (1 c-c)
      rxValidSeg_o : out sl;
      
      -- Segment dropped (1 c-c)
      rxDropSeg_o  : out sl;
      
      -- Last segment received flags (active until next segment is received)
      rxSyn_o      : out sl;           
      rxAck_o      : out sl;
      rxRst_o      : out sl;
      rxData_o     : out sl;
      rxNull_o     : out sl;
      rxBusy_o     : out sl;
     
      -- Checksum control
      chksumValid_i : in   sl;
      chksumEnable_o: out  sl;
      chksumStrobe_o: out  sl;

      -- Buffer write  
      wrBuffAddr_o   : out  slv( (SEGMENT_ADDR_SIZE_C+WINDOW_ADDR_SIZE_G)-1 downto 0);
      wrBuffData_o   : out   slv(RSSI_WORD_WIDTH_C*8-1 downto 0);      
      
      -- Buffer read
      rdBuffAddr_o   : out  slv( (SEGMENT_ADDR_SIZE_C+WINDOW_ADDR_SIZE_G)-1 downto 0);
      rdBuffData_i   : in   slv(RSSI_WORD_WIDTH_C*8-1 downto 0);
      
      -- SSI Transport side interface IN 
      tspSsiMaster_i : in  SsiMasterType;
      tspSsiSlave_o  : out SsiSlaveType;
      
      -- SSI Application side interface OUT
      tspSsiMaster_o : out SsiMasterType;
      tspSsiSlave_o  : in  SsiSlaveType;
      
      
   );
end entity RxFSM;

architecture rtl of RxFSM is
   -- Init SSI bus
   constant SSI_MASTER_INIT_C : SsiMasterType := axis2SsiMaster(RSSI_AXI_CONFIG_C, AXI_STREAM_MASTER_INIT_C);
   constant SSI_SLAVE_NOTRDY_C  : SsiSlaveType  := axis2SsiSlave(RSSI_AXI_CONFIG_C, AXI_STREAM_SLAVE_INIT_C, AXI_STREAM_CTRL_INIT_C);
   constant SSI_SLAVE_RDY_C  : SsiSlaveType  := axis2SsiSlave(RSSI_AXI_CONFIG_C, AXI_STREAM_SLAVE_FORCE_C, AXI_STREAM_CTRL_UNUSED_C);
   
   type tspStateType is (
      --
      WAIT_SOF_S,
      CHECK_S,
      VALID_S,
      DROP_S,
      DATA_WE_S,
   );
   
   type RegType is record
      
      -- Transport side FSM (Receive and check segments)
      
      -- Counters
      nextSeqN       : slv(7 downto 0);
      seqN           : slv(7 downto 0);
      segmentAddr    : slv(SEGMENT_ADDR_SIZE_C downto 0);
      bufferAddr     : slv(WINDOW_ADDR_SIZE_G-1  downto 0);
      
      -- Packet flags
      synF  : sl;
      ackF  : sl;
      eackF : sl;
      rstF  : sl;
      nullF : sl;
      dataF : sl;
      busyF : sl;

      -- Various controls
      txRdy    : sl;
      buffWe   : sl;
      buffSent : sl;
      chkEn    : sl;
      chkStb   : sl;
      
      -- SSI master
      tspSsiSlave   : SsiSlaveType;
            
      -- State Machine
      tspState       : TspStateType;    
   end record RegType;

   constant REG_INIT_C : RegType := (
      --   
      nextSeqN    => (others => '0'),
      seqN        => (others => '0'),
      segmentAddr => (others => '0'),
      bufferAddr  => (others => '0'),
      
      --
      synF     => '0',
      ackF     => '0',
      eackF    => '0',
      rstF     => '0',
      nullF    => '0',
      dataF    => '0',
      busyF    => '0',
      --
      txRdy    => '0',
      buffWe   => '0',
      buffSent => '0',
      chkEn    => '0',
      chkStb   => '0',
      
      -- SSI master 
      tspMaster => SSI_MASTER_INIT_C,

      -- State Machine
      tspState  => WAIT_SOF_S
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
begin

   ----------------------------------------------------------------------------------------------- 
   comb : process (r, rst_i, ) is
      
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
      case r.tspState is
         ----------------------------------------------------------------------
         when WAIT_SOF_S =>
         
         
            
            
            v.tspSsiSlave := SSI_SLAVE_RDY_C;
            
            -- Next state condition   
            if    (tspSsiMaster_i.sof = '1' and tspSsiMaster_i.valid = '1') then
               v.tspSsiSlave := SSI_SLAVE_NOTRDY_C;
               v.tspState    := CHECK_S;
            end if;
         ----------------------------------------------------------------------
         when CHECK_S =>
            -- Register flags 
            v.synF  := tspSsiMaster_i.data ()
            v.ackF  := 
            v.eackF := 
            v.rstF  := 
            v.nullF := 
            v.dataF := '0';
            v.busyF := 
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