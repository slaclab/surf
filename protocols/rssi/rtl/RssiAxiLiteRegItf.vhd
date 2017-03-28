-------------------------------------------------------------------------------
-- File       : RssiAxiLiteRegItf.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-15
-- Last update: 2016-01-19
-------------------------------------------------------------------------------
-- Description:  Register decoding for RSSI core
--               0x00 (RW)- Control register [4:0]:
--                   bit 0: Open connection request (Default '0')
--                   bit 1: Close connection request (Default '0')
--                   bit 2: Mode (Default '0'):
--                            - '0': Use internal parameters from generics  
--                            - '1': Use parameters from Axil 
--                   bit 3: Header checksum enable (Default '1')
--                   bit 4: Inject fault to the next packet header checksum (Default '0')
--                            Acts on rising edge - injects exactly one fault in next segment (ACK, NULL, or DATA)
--               0x01 (RW)- Initial sequence number [7:0] (Default x"80")
--               0x02 (RW)- Version register [3:0](Default x"1")
--               0x03 (RW)- Maximum out standing segments [7:0](Default "008"):
--                            Defines the max number of segments in the RSSI receiver buffer
--               0x04 (RW)- Maximum segment size [15:0](Default x"0400")
--                            Defines the size of segment buffer! Number of bytes!
--               0x05 (RW)- Retransmission timeout [15:0](Default 50)
--                            Unit depends on TIMEOUT_UNIT_G
--               0x06 (RW)- Cumulative acknowledgment timeout [15:0](Default 50)
--                            Unit depends on TIMEOUT_UNIT_G
--               0x07 (RW)- Null segment timeout [15:0](Default 50)
--                            Unit depends on TIMEOUT_UNIT_G
--                            Server: Close connection if Null segment missed!
--                            Client: Transmit Null segment when nullSegTout/2 reached!
--               0x08 (RW)- Maximum number of retransmissions [7:0](Default x"02")
--                            How many times segments are retransmitted before the connection gets broken.
--               0x09 (RW)- Maximum cumulative acknowledgments [7:0](Default x"03")
--                            When more than maxCumAck are received and not acknowledged the 
--                            ACK packet will be sent to acknowledge the received packets. Even though the 
--                            cumulative acknowledgment timeout has not been reached yet!
--               0x0A (RW)- Max out of sequence segments (EACK) [7:0](Default x"03")
--                            Currently not used TBD
--               0x0B (RW)- Connection ID [31:0](Default x"12345678")
--                            Every connection should have unique connection ID.
--               Statuses
--               0x10 (R)- Status register [5:0]:
--                   bit(0) : Connection Active          
--                   bit(1) : Maximum retransmissions exceeded retransMax
--                   bit(2) : Null timeout reached (server) r.nullTout
--                   bit(3) : Error in acknowledgment mechanism   
--                   bit(4) : SSI Frame length too long
--                   bit(5) : Connection to peer timed out
--                   bit(6) : Parameters from peer rejected (Client) or new proposed(Server) 
--                0x11 (R)- Number of valid segments [31:0]:
--                   The value rests to 0 when new connection open is requested.
--                0x12 (R)- Number of dropped segments [31:0]:
--                   The value rests to 0 when new connection open is requested.
--                0x13 (R)- Counts all retransmission requests within the active connection [31:0]:
--                   The value rests to 0 when new connection open is requested.
--                0x14 (R)- Counts all reconnections from reset [31:0]:
--                   The value rests to 0 when module is reset.
------------------------------------------------------------------------------
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
use work.AxiLitePkg.all;
use work.RssiPkg.all;

entity RssiAxiLiteRegItf is
generic (
   -- General Configurations
   TPD_G                : time            := 1 ns;
   AXI_ERROR_RESP_G     : slv(1 downto 0) := AXI_RESP_SLVERR_C;
   SEGMENT_ADDR_SIZE_G  : positive        := 3;  -- 2^SEGMENT_ADDR_SIZE_G = Number of 64 bit wide data words
   -- Defaults form generics
   TIMEOUT_UNIT_G   : real     := 1.0E-6;
   INIT_SEQ_N_G     : natural  := 16#80#;
   CONN_ID_G   : positive := 16#12345678#;
   VERSION_G   : positive := 1;
   HEADER_CHKSUM_EN_G : boolean  := true;
   MAX_NUM_OUTS_SEG_G  : positive := 8; --   <=(2**WINDOW_ADDR_SIZE_G)
   MAX_SEG_SIZE_G      : positive := 1024;  -- Number of bytes
   RETRANS_TOUT_G        : positive := 50;  -- unit depends on TIMEOUT_UNIT_G  
   ACK_TOUT_G            : positive := 25;  -- unit depends on TIMEOUT_UNIT_G  
   NULL_TOUT_G           : positive := 200; -- unit depends on TIMEOUT_UNIT_G  
   MAX_RETRANS_CNT_G     : positive := 2;
   MAX_CUM_ACK_CNT_G     : positive := 3;
   MAX_OUT_OF_SEQUENCE_G : natural  := 3);
      
port (
   -- AXI Clk
   axiClk_i : in sl;
   axiRst_i : in sl;

   -- Axi-Lite Register Interface (locClk domain)
   axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   axilReadSlave   : out AxiLiteReadSlaveType;
   axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   axilWriteSlave  : out AxiLiteWriteSlaveType;

   -- Rssi Clk
   devClk_i : in sl;
   devRst_i : in sl;

   -- Registers
   -- Control (RW)   
   openRq_o       : out sl;
   closeRq_o      : out sl;
   mode_o         : out sl;
   injectFault_o  : out sl;
   
   initSeqN_o     : out slv(7 downto 0);
   appRssiParam_o : out RssiParamType;
   
   -- Status (RO)
   frameRate_i    : in Slv32Array(1 downto 0);   
   bandwidth_i    : in Slv64Array(1 downto 0);   
   status_i       : in slv(6 downto 0);  
   dropCnt_i      : in slv(31 downto 0);
   validCnt_i     : in slv(31 downto 0);
   resendCnt_i    : in slv(31 downto 0);
   reconCnt_i     : in slv(31 downto 0)
);   
end RssiAxiLiteRegItf;

architecture rtl of RssiAxiLiteRegItf is

  type RegType is record
   -- Control (RW)
   control       : slv(4 downto 0);
   
   -- Parameters (RW)  
   initSeqN      : slv(7 downto 0);
   version       : slv(3 downto 0);
   maxOutsSeg    : slv(7 downto 0);       
   maxSegSize    : slv(15 downto 0);
   retransTout   : slv(15 downto 0);
   cumulAckTout  : slv(15 downto 0);
   nullSegTout   : slv(15 downto 0);      
   maxRetrans    : slv(7 downto 0);
   maxCumAck     : slv(7 downto 0);
   maxOutofseq   : slv(7 downto 0);
   connectionId  : slv(31 downto 0);
   
   -- AXI lite
   axilReadSlave  : AxiLiteReadSlaveType;
   axilWriteSlave : AxiLiteWriteSlaveType;
   --
  end record;
  
   constant REG_INIT_C : RegType := (
      control     => "01000",
      initSeqN     => toSlv(INIT_SEQ_N_G, 8),
      version      => toSlv(VERSION_G, 4),
      maxOutsSeg   => toSlv(MAX_NUM_OUTS_SEG_G, 8),
      maxSegSize   => toSlv((2**SEGMENT_ADDR_SIZE_G)*RSSI_WORD_WIDTH_C, 16),
      retransTout  => toSlv(RETRANS_TOUT_G, 16),
      cumulAckTout => toSlv(ACK_TOUT_G, 16),
      nullSegTout  => toSlv(NULL_TOUT_G, 16),
      maxRetrans   => toSlv(MAX_RETRANS_CNT_G, 8),
      maxCumAck    => toSlv(MAX_CUM_ACK_CNT_G, 8),
      maxOutofseq  => toSlv(MAX_OUT_OF_SEQUENCE_G, 8),
      connectionId => toSlv(CONN_ID_G, 32),
      
      -- AXI lite      
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- Integer address
   signal s_RdAddr : natural := 0;
   signal s_WrAddr : natural := 0;

  -- Synced status signals
   signal s_status   : slv(status_i'range);  
   signal s_dropCnt  : slv(31 downto 0);
   signal s_validCnt : slv(31 downto 0);
   signal s_reconCnt : slv(31 downto 0);
   signal s_resendCnt: slv(31 downto 0);
   
begin

  -- Convert address to integer (lower two bits of address are always '0')
  s_RdAddr <= conv_integer(axilReadMaster.araddr(9 downto 2));
  s_WrAddr <= conv_integer(axilWriteMaster.awaddr(9 downto 2));

   comb : process (axiRst_i, axilReadMaster, axilWriteMaster, bandwidth_i, frameRate_i, r, s_RdAddr,
                   s_WrAddr, s_dropCnt, s_reconCnt, s_resendCnt, s_status, s_validCnt) is
      variable v             : RegType;
      variable axilStatus    : AxiLiteStatusType;
      variable axilWriteResp : slv(1 downto 0);
      variable axilReadResp  : slv(1 downto 0);
   begin
    -- Latch the current value
    v := r;

    ----------------------------------------------------------------------------------------------
    -- Axi-Lite interface
    ----------------------------------------------------------------------------------------------
    axiSlaveWaitTxn(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus);

    if (axilStatus.writeEnable = '1') then
      axilWriteResp := ite(axilWriteMaster.awaddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_ERROR_RESP_G);
      case (s_WrAddr) is
        when 16#00# =>                  -- ADDR (0)
          v.control     := axilWriteMaster.wdata(4 downto 0);
        when 16#01# =>                  -- ADDR (4)
          v.initSeqN    := axilWriteMaster.wdata(7 downto 0);
        when 16#02# =>                  -- ADDR (8)
          v.version     := axilWriteMaster.wdata(3 downto 0);
        when 16#03# =>                  -- ADDR (12)
          v.maxOutsSeg  := axilWriteMaster.wdata(7 downto 0);
        when 16#04# =>                  -- ADDR (16)
          v.maxSegSize  := axilWriteMaster.wdata(15 downto 0);
        when 16#05# =>                  
          v.retransTout := axilWriteMaster.wdata(15 downto 0);
        when 16#06# =>                  
          v.cumulAckTout:= axilWriteMaster.wdata(15 downto 0);
        when 16#07# =>                  
          v.nullSegTout := axilWriteMaster.wdata(15 downto 0);
        when 16#08# =>                  
          v.maxRetrans  := axilWriteMaster.wdata(7 downto 0);
        when 16#09# =>                  
          v.maxCumAck   := axilWriteMaster.wdata(7 downto 0);
        when 16#0A# =>                  
          v.maxOutofseq := axilWriteMaster.wdata(7 downto 0);
        when 16#0B# =>                  
          v.connectionId:= axilWriteMaster.wdata(31 downto 0);
        when others =>
          axilWriteResp := AXI_ERROR_RESP_G;
      end case;
      axiSlaveWriteResponse(v.axilWriteSlave);
    end if;

    if (axilStatus.readEnable = '1') then
      axilReadResp          := ite(axilReadMaster.araddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_ERROR_RESP_G);
      v.axilReadSlave.rdata := (others => '0');
      case (s_RdAddr) is
        when 16#00# =>                  -- ADDR (0)
          v.axilReadSlave.rdata(4 downto 0) := r.control;
        when 16#01# =>                  -- ADDR (4)
          v.axilReadSlave.rdata(7 downto 0) := r.initSeqN;
        when 16#02# =>                  -- ADDR (8)
          v.axilReadSlave.rdata(3 downto 0) := r.version;
        when 16#03# =>                  -- ADDR (12)
          v.axilReadSlave.rdata(7 downto 0) := r.maxOutsSeg;
        when 16#04# =>                  -- ADDR (16)
          v.axilReadSlave.rdata(15 downto 0) := r.maxSegSize;
        when 16#05# =>                  -- ADDR (20)
          v.axilReadSlave.rdata(15 downto 0) := r.retransTout;
        when 16#06# =>                  -- ADDR (24)
          v.axilReadSlave.rdata(15 downto 0) := r.cumulAckTout;
        when 16#07# =>                  -- ADDR (28)
          v.axilReadSlave.rdata(15 downto 0) := r.nullSegTout;
        when 16#08# =>                  -- ADDR (32)
          v.axilReadSlave.rdata(7 downto 0) := r.maxRetrans;
        when 16#09# =>                  -- ADDR (36)
          v.axilReadSlave.rdata(7 downto 0) := r.maxCumAck;
        when 16#0A# =>                  -- ADDR (40)
          v.axilReadSlave.rdata(7 downto 0) := r.maxOutofseq;
        when 16#0B# =>                  -- ADDR (44)
          v.axilReadSlave.rdata(31 downto 0) := r.connectionId;
        when 16#10# =>                  -- ADDR (64)
          v.axilReadSlave.rdata(status_i'range)  := s_status;
        when 16#11# =>                  -- ADDR (68)
          v.axilReadSlave.rdata(31 downto 0) := s_validCnt;          
        when 16#12# =>                  -- ADDR (72)
          v.axilReadSlave.rdata(31 downto 0) := s_dropCnt;
        when 16#13# =>                  -- ADDR (76)
          v.axilReadSlave.rdata(31 downto 0) := s_resendCnt;          
        when 16#14# =>                  -- ADDR (80)
          v.axilReadSlave.rdata(31 downto 0) := s_reconCnt;  
        when 16#15# =>                  
          v.axilReadSlave.rdata(31 downto 0) := frameRate_i(0);  
        when 16#16# =>                  
          v.axilReadSlave.rdata(31 downto 0) := frameRate_i(1);
        when 16#17# =>                  
          v.axilReadSlave.rdata(31 downto 0) := bandwidth_i(0)(31 downto 0);  
        when 16#18# =>                  
          v.axilReadSlave.rdata(31 downto 0) := bandwidth_i(0)(63 downto 32);    
        when 16#19# =>                  
          v.axilReadSlave.rdata(31 downto 0) := bandwidth_i(1)(31 downto 0);  
        when 16#20# =>                  
          v.axilReadSlave.rdata(31 downto 0) := bandwidth_i(1)(63 downto 32);              
        when others =>
          axilReadResp := AXI_ERROR_RESP_G;
      end case;
      axiSlaveReadResponse(v.axilReadSlave);
    end if;

    -- Reset
    if (axiRst_i = '1') then
      v := REG_INIT_C;
    end if;

    -- Register the variable for next clock cycle
    rin <= v;

    -- Outputs
    axilReadSlave  <= r.axilReadSlave;
    axilWriteSlave <= r.axilWriteSlave;
    
  end process comb;

  seq : process (axiClk_i) is
  begin
    if rising_edge(axiClk_i) then
      r <= rin after TPD_G;
    end if;
  end process seq; 

   -- Input assignment and synchronization
   SyncFifo_IN0 : entity work.SynchronizerFifo
   generic map (
      TPD_G        => TPD_G,
      DATA_WIDTH_G => status_i'length
   )
   port map (
      wr_clk => devClk_i,
      din    => status_i,
      rd_clk => axiClk_i,
      dout   => s_status
   );

   SyncFifo_IN1 : entity work.SynchronizerFifo
   generic map (
      TPD_G        => TPD_G,
      DATA_WIDTH_G => validCnt_i'length
   )
   port map (
      wr_clk => devClk_i,
      din    => validCnt_i,
      rd_clk => axiClk_i,
      dout   => s_validCnt
   );   
   
   SyncFifo_IN2 : entity work.SynchronizerFifo
   generic map (
      TPD_G        => TPD_G,
      DATA_WIDTH_G => dropCnt_i'length
   )
   port map (
      wr_clk => devClk_i,
      din    => dropCnt_i,
      rd_clk => axiClk_i,
      dout   => s_dropCnt
   );
  
   SyncFifo_IN3 : entity work.SynchronizerFifo
   generic map (
      TPD_G        => TPD_G,
      DATA_WIDTH_G => resendCnt_i'length
   )
   port map (
      wr_clk => devClk_i,
      din    => resendCnt_i,
      rd_clk => axiClk_i,
      dout   => s_resendCnt
   );   
   
   SyncFifo_IN4 : entity work.SynchronizerFifo
   generic map (
      TPD_G        => TPD_G,
      DATA_WIDTH_G => reconCnt_i'length
   )
   port map (
      wr_clk => devClk_i,
      din    => reconCnt_i,
      rd_clk => axiClk_i,
      dout   => s_reconCnt
   );

  -- Output assignment and synchronization
  Sync_OUT0 : entity work.Synchronizer
   generic map (
      TPD_G        => TPD_G
   )
   port map (
      dataIn    => r.control(0),
      clk       => devClk_i,
      dataOut   => openRq_o
   );
   
   Sync_OUT1 : entity work.Synchronizer
   generic map (
      TPD_G        => TPD_G
   )
    port map (
      dataIn    => r.control(1),
      clk       => devClk_i,
      dataOut   => closeRq_o
   );
   
   Sync_OUT2 : entity work.Synchronizer
   generic map (
      TPD_G        => TPD_G
   )
    port map (
      dataIn    => r.control(2),
      clk       => devClk_i,
      dataOut   => mode_o
   );
   
   Sync_OUT3 : entity work.Synchronizer
   generic map (
      TPD_G        => TPD_G
   )
    port map (
      dataIn    => r.control(3),
      clk       => devClk_i,
      dataOut   => appRssiParam_o.chksumEn(0)
   );
   
   Sync_OUT4 : entity work.Synchronizer
   generic map (
      TPD_G        => TPD_G
   )
    port map (
      dataIn    => r.control(4),
      clk       => devClk_i,
      dataOut   => injectFault_o
   );
   
   SyncFifo_OUT5 : entity work.SynchronizerFifo
   generic map (
      TPD_G        => TPD_G,
      DATA_WIDTH_G => 8
   )
   port map (
      wr_clk => axiClk_i,
      din    => r.initSeqN,
      rd_clk => devClk_i,
      dout   => initSeqN_o
   );
   
   SyncFifo_OUT6 : entity work.SynchronizerFifo
   generic map (
      TPD_G        => TPD_G,
      DATA_WIDTH_G => 4
   )
   port map (
      wr_clk => axiClk_i,
      din    => r.version,
      rd_clk => devClk_i,
      dout   => appRssiParam_o.version
   );
   
   SyncFifo_OUT7 : entity work.SynchronizerFifo
   generic map (
      TPD_G        => TPD_G,
      DATA_WIDTH_G => 8
   )
   port map (
      wr_clk => axiClk_i,
      din    => r.maxOutsSeg,
      rd_clk => devClk_i,
      dout   => appRssiParam_o.maxOutsSeg
   );
   
   SyncFifo_OUT8 : entity work.SynchronizerFifo
   generic map (
      TPD_G        => TPD_G,
      DATA_WIDTH_G => 16
   )
   port map (
      wr_clk => axiClk_i,
      din    => r.maxSegSize,
      rd_clk => devClk_i,
      dout   => appRssiParam_o.maxSegSize
   );
   
   SyncFifo_OUT9 : entity work.SynchronizerFifo
   generic map (
      TPD_G        => TPD_G,
      DATA_WIDTH_G => 16
   )
   port map (
      wr_clk => axiClk_i,
      din    => r.retransTout,
      rd_clk => devClk_i,
      dout   => appRssiParam_o.retransTout
   );
   
   SyncFifo_OUT10 : entity work.SynchronizerFifo
   generic map (
      TPD_G        => TPD_G,
      DATA_WIDTH_G => 16
   )
   port map (
      wr_clk => axiClk_i,
      din    => r.cumulAckTout,
      rd_clk => devClk_i,
      dout   => appRssiParam_o.cumulAckTout
   );
   
   SyncFifo_OUT11 : entity work.SynchronizerFifo
   generic map (
      TPD_G        => TPD_G,
      DATA_WIDTH_G => 16
   )
   port map (
      wr_clk => axiClk_i,
      din    => r.nullSegTout,
      rd_clk => devClk_i,
      dout   => appRssiParam_o.nullSegTout
   );
   
   SyncFifo_OUT12 : entity work.SynchronizerFifo
   generic map (
      TPD_G        => TPD_G,
      DATA_WIDTH_G => 8
   )
   port map (
      wr_clk => axiClk_i,
      din    => r.maxRetrans,
      rd_clk => devClk_i,
      dout   => appRssiParam_o.maxRetrans
   );
   
   SyncFifo_OUT13 : entity work.SynchronizerFifo
   generic map (
      TPD_G        => TPD_G,
      DATA_WIDTH_G => 8
   )
   port map (
      wr_clk => axiClk_i,
      din    => r.maxCumAck,
      rd_clk => devClk_i,
      dout   => appRssiParam_o.maxCumAck
   );
   
   SyncFifo_OUT14 : entity work.SynchronizerFifo
   generic map (
      TPD_G        => TPD_G,
      DATA_WIDTH_G => 8
   )
   port map (
      wr_clk => axiClk_i,
      din    => r.maxOutofseq,
      rd_clk => devClk_i,
      dout   => appRssiParam_o.maxOutofseq
   );
    
   SyncFifo_OUT15 : entity work.SynchronizerFifo
   generic map (
      TPD_G        => TPD_G,
      DATA_WIDTH_G => 32
   )
   port map (
      wr_clk => axiClk_i,
      din    => r.connectionId,
      rd_clk => devClk_i,
      dout   => appRssiParam_o.connectionId
   );
   
   appRssiParam_o.timeoutUnit <= toSlv(integer(0.0 - (ieee.math_real.log(TIMEOUT_UNIT_G)/ieee.math_real.log(10.0))), 8); 
---------------------------------------------------------------------
end rtl;
