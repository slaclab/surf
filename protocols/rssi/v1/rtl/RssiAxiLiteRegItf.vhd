-------------------------------------------------------------------------------
-- Title      : RSSI Protocol: https://confluence.slac.stanford.edu/x/1IyfD
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
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


library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.RssiPkg.all;

entity RssiAxiLiteRegItf is
   generic (
      -- General Configurations
      TPD_G                 : time     := 1 ns;
      COMMON_CLK_G          : boolean  := false;  -- true if axiClk_i = devClk_i
      SEGMENT_ADDR_SIZE_G   : positive := 7;  -- 2^SEGMENT_ADDR_SIZE_G = Number of 64 bit wide data words
      -- Defaults form generics
      TIMEOUT_UNIT_G        : real     := 1.0E-6;
      INIT_SEQ_N_G          : natural  := 16#80#;
      CONN_ID_G             : positive := 16#12345678#;
      VERSION_G             : positive := 1;
      HEADER_CHKSUM_EN_G    : boolean  := true;
      MAX_NUM_OUTS_SEG_G    : positive := 8;  --   <=(2**WINDOW_ADDR_SIZE_G)
      MAX_SEG_SIZE_G        : positive := 1024;   -- Number of bytes
      RETRANS_TOUT_G        : positive := 50;  -- unit depends on TIMEOUT_UNIT_G
      ACK_TOUT_G            : positive := 25;  -- unit depends on TIMEOUT_UNIT_G
      NULL_TOUT_G           : positive := 200;  -- unit depends on TIMEOUT_UNIT_G
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
      openRq_o      : out sl;
      closeRq_o     : out sl;
      mode_o        : out sl;
      injectFault_o : out sl;

      initSeqN_o     : out slv(7 downto 0);
      appRssiParam_o : out RssiParamType;
      negRssiParam_i : in  RssiParamType;

      -- Status (RO)
      frameRate_i : in Slv32Array(1 downto 0);
      bandwidth_i : in Slv64Array(1 downto 0);
      status_i    : in slv(6 downto 0);
      dropCnt_i   : in slv(31 downto 0);
      validCnt_i  : in slv(31 downto 0);
      resendCnt_i : in slv(31 downto 0);
      reconCnt_i  : in slv(31 downto 0)
      );
end RssiAxiLiteRegItf;

architecture rtl of RssiAxiLiteRegItf is

   type RegType is record
      -- Control (RW)
      control : slv(4 downto 0);

      -- Parameters (RW)
      initSeqN     : slv(7 downto 0);
      appRssiParam : RssiParamType;

      -- AXI lite
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
   --
   end record;

   constant REG_INIT_C : RegType := (
      -- Control (RW)
      control => "01000",

      -- Parameters (RW)
      initSeqN        => toSlv(INIT_SEQ_N_G, 8),
      appRssiParam    => (
         version      => toSlv(VERSION_G, 4),
         chksumEn     => "1",
         timeoutUnit  => toSlv(integer(0.0 - (ieee.math_real.log(TIMEOUT_UNIT_G)/ieee.math_real.log(10.0))), 8),
         maxOutsSeg   => toSlv(MAX_NUM_OUTS_SEG_G, 8),
         maxSegSize   => toSlv(MAX_SEG_SIZE_G, 16),
         retransTout  => toSlv(RETRANS_TOUT_G, 16),
         cumulAckTout => toSlv(ACK_TOUT_G, 16),
         nullSegTout  => toSlv(NULL_TOUT_G, 16),
         maxRetrans   => toSlv(MAX_RETRANS_CNT_G, 8),
         maxCumAck    => toSlv(MAX_CUM_ACK_CNT_G, 8),
         maxOutofseq  => toSlv(MAX_OUT_OF_SEQUENCE_G, 8),
         connectionId => toSlv(CONN_ID_G, 32)),

      -- AXI lite
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- Integer address
   signal s_RdAddr : natural := 0;
   signal s_WrAddr : natural := 0;

   -- Synced status signals
   signal s_status    : slv(status_i'range);
   signal s_dropCnt   : slv(31 downto 0);
   signal s_validCnt  : slv(31 downto 0);
   signal s_reconCnt  : slv(31 downto 0);
   signal s_resendCnt : slv(31 downto 0);

   signal dummyBit     : sl;
   signal negRssiParam : RssiParamType;

   -- attribute dont_touch                 : string;
   -- attribute dont_touch of r            : signal is "TRUE";
   -- attribute dont_touch of s_RdAddr     : signal is "TRUE";
   -- attribute dont_touch of s_WrAddr     : signal is "TRUE";
   -- attribute dont_touch of s_status     : signal is "TRUE";
   -- attribute dont_touch of s_dropCnt    : signal is "TRUE";
   -- attribute dont_touch of s_reconCnt   : signal is "TRUE";
   -- attribute dont_touch of s_resendCnt  : signal is "TRUE";
   -- attribute dont_touch of dummyBit     : signal is "TRUE";
   -- attribute dont_touch of negRssiParam : signal is "TRUE";

begin

   -- Convert address to integer (lower two bits of address are always '0')
   s_RdAddr <= conv_integer(axilReadMaster.araddr(9 downto 2));
   s_WrAddr <= conv_integer(axilWriteMaster.awaddr(9 downto 2));

   comb : process (axiRst_i, axilReadMaster, axilWriteMaster, bandwidth_i,
                   frameRate_i, negRssiParam, r, s_RdAddr, s_WrAddr, s_dropCnt,
                   s_reconCnt, s_resendCnt, s_status, s_validCnt) is
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
         axilWriteResp := ite(axilWriteMaster.awaddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_RESP_DECERR_C);
         case (s_WrAddr) is
            when 16#00# =>              -- ADDR (0)
               v.control := axilWriteMaster.wdata(4 downto 0);
            when 16#01# =>              -- ADDR (4)
               v.initSeqN := axilWriteMaster.wdata(7 downto 0);
            when 16#02# =>              -- ADDR (8)
               v.appRssiParam.version := axilWriteMaster.wdata(3 downto 0);
            when 16#03# =>              -- ADDR (12)
               v.appRssiParam.maxOutsSeg := axilWriteMaster.wdata(7 downto 0);
            when 16#04# =>              -- ADDR (16)
               v.appRssiParam.maxSegSize := axilWriteMaster.wdata(15 downto 0);
               if (unsigned(v.appRssiParam.maxSegSize) < 8) then
                  v.appRssiParam.maxSegSize := toSlv(8, v.appRssiParam.maxSegSize'length);
               elsif (unsigned(v.appRssiParam.maxSegSize) > (2**SEGMENT_ADDR_SIZE_G)*8) then
                  v.appRssiParam.maxSegSize := toSlv((2**SEGMENT_ADDR_SIZE_G)*8, v.appRssiParam.maxSegSize'length);
               end if;
            when 16#05# =>
               v.appRssiParam.retransTout := axilWriteMaster.wdata(15 downto 0);
            when 16#06# =>
               v.appRssiParam.cumulAckTout := axilWriteMaster.wdata(15 downto 0);
            when 16#07# =>
               v.appRssiParam.nullSegTout := axilWriteMaster.wdata(15 downto 0);
            when 16#08# =>
               v.appRssiParam.maxRetrans := axilWriteMaster.wdata(7 downto 0);
            when 16#09# =>
               v.appRssiParam.maxCumAck := axilWriteMaster.wdata(7 downto 0);
            when 16#0A# =>
               v.appRssiParam.maxOutofseq := axilWriteMaster.wdata(7 downto 0);
            when 16#0B# =>
               v.appRssiParam.connectionId := axilWriteMaster.wdata(31 downto 0);
            when others =>
               axilWriteResp := AXI_RESP_DECERR_C;
         end case;
         axiSlaveWriteResponse(v.axilWriteSlave, axilWriteResp);
      end if;

      if (axilStatus.readEnable = '1') then
         axilReadResp          := ite(axilReadMaster.araddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_RESP_DECERR_C);
         case (s_RdAddr) is
            when 16#00# =>              -- ADDR (0)
               v.axilReadSlave.rdata(4 downto 0) := r.control;
            when 16#01# =>              -- ADDR (4)
               v.axilReadSlave.rdata(7 downto 0) := r.initSeqN;
            when 16#02# =>              -- ADDR (8)
               v.axilReadSlave.rdata(3 downto 0)   := r.appRssiParam.version;
               v.axilReadSlave.rdata(19 downto 16) := negRssiParam.version;
            when 16#03# =>              -- ADDR (12)
               v.axilReadSlave.rdata(7 downto 0)   := r.appRssiParam.maxOutsSeg;
               v.axilReadSlave.rdata(23 downto 16) := negRssiParam.maxOutsSeg;
            when 16#04# =>              -- ADDR (16)
               v.axilReadSlave.rdata(15 downto 0)  := r.appRssiParam.maxSegSize;
               v.axilReadSlave.rdata(31 downto 16) := negRssiParam.maxSegSize;
            when 16#05# =>              -- ADDR (20)
               v.axilReadSlave.rdata(15 downto 0)  := r.appRssiParam.retransTout;
               v.axilReadSlave.rdata(31 downto 16) := negRssiParam.retransTout;
            when 16#06# =>              -- ADDR (24)
               v.axilReadSlave.rdata(15 downto 0)  := r.appRssiParam.cumulAckTout;
               v.axilReadSlave.rdata(31 downto 16) := negRssiParam.cumulAckTout;
            when 16#07# =>              -- ADDR (28)
               v.axilReadSlave.rdata(15 downto 0)  := r.appRssiParam.nullSegTout;
               v.axilReadSlave.rdata(31 downto 16) := negRssiParam.nullSegTout;
            when 16#08# =>              -- ADDR (32)
               v.axilReadSlave.rdata(7 downto 0)   := r.appRssiParam.maxRetrans;
               v.axilReadSlave.rdata(23 downto 16) := negRssiParam.maxRetrans;
            when 16#09# =>              -- ADDR (36)
               v.axilReadSlave.rdata(7 downto 0)   := r.appRssiParam.maxCumAck;
               v.axilReadSlave.rdata(23 downto 16) := negRssiParam.maxCumAck;
            when 16#0A# =>              -- ADDR (40)
               v.axilReadSlave.rdata(7 downto 0)   := r.appRssiParam.maxOutofseq;
               v.axilReadSlave.rdata(23 downto 16) := negRssiParam.maxOutofseq;
            when 16#0B# =>              -- ADDR (44)
               v.axilReadSlave.rdata(31 downto 0) := r.appRssiParam.connectionId;
            when 16#0C# =>              -- ADDR (48)
               v.axilReadSlave.rdata(31 downto 0) := negRssiParam.connectionId;
            when 16#10# =>              -- ADDR (64)
               v.axilReadSlave.rdata(status_i'range) := s_status;
            when 16#11# =>              -- ADDR (68)
               v.axilReadSlave.rdata(31 downto 0) := s_validCnt;
            when 16#12# =>              -- ADDR (72)
               v.axilReadSlave.rdata(31 downto 0) := s_dropCnt;
            when 16#13# =>              -- ADDR (76)
               v.axilReadSlave.rdata(31 downto 0) := s_resendCnt;
            when 16#14# =>              -- ADDR (80)
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
            when 16#1A# =>
               v.axilReadSlave.rdata(31 downto 0) := bandwidth_i(1)(63 downto 32);
            when others =>
               axilReadResp := AXI_RESP_DECERR_C;
         end case;
         axiSlaveReadResponse(v.axilReadSlave, axilReadResp);
      end if;

      -- Map to chksumEn
      v.appRssiParam.chksumEn(0) := v.control(3);

      -- Outputs
      axilReadSlave  <= r.axilReadSlave;
      axilWriteSlave <= r.axilWriteSlave;

      -- Reset
      if (axiRst_i = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (axiClk_i) is
   begin
      if rising_edge(axiClk_i) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_status : entity surf.SynchronizerVector
      generic map (
         TPD_G         => TPD_G,
         BYPASS_SYNC_G => COMMON_CLK_G,
         WIDTH_G       => status_i'length)
      port map (
         clk     => devClk_i,
         dataIn  => status_i,
         dataOut => s_status);

   U_validCnt : entity surf.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         COMMON_CLK_G => COMMON_CLK_G,
         DATA_WIDTH_G => validCnt_i'length)
      port map (
         wr_clk => devClk_i,
         din    => validCnt_i,
         rd_clk => axiClk_i,
         dout   => s_validCnt);

   U_dropCnt : entity surf.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         COMMON_CLK_G => COMMON_CLK_G,
         DATA_WIDTH_G => dropCnt_i'length)
      port map (
         wr_clk => devClk_i,
         din    => dropCnt_i,
         rd_clk => axiClk_i,
         dout   => s_dropCnt);

   U_resendCnt : entity surf.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         COMMON_CLK_G => COMMON_CLK_G,
         DATA_WIDTH_G => resendCnt_i'length)
      port map (
         wr_clk => devClk_i,
         din    => resendCnt_i,
         rd_clk => axiClk_i,
         dout   => s_resendCnt);

   U_reconCnt : entity surf.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         COMMON_CLK_G => COMMON_CLK_G,
         DATA_WIDTH_G => reconCnt_i'length)
      port map (
         wr_clk => devClk_i,
         din    => reconCnt_i,
         rd_clk => axiClk_i,
         dout   => s_reconCnt);

   U_SyncVecOut : entity surf.SynchronizerVector
      generic map (
         TPD_G         => TPD_G,
         BYPASS_SYNC_G => COMMON_CLK_G,
         WIDTH_G       => 5)
      port map (
         clk        => devClk_i,
         dataIn     => r.control,
         dataOut(0) => openRq_o,
         dataOut(1) => closeRq_o,
         dataOut(2) => mode_o,
         dataOut(3) => dummyBit,        -- appRssiParam_o.chksumEn(0)
         dataOut(4) => injectFault_o);

   U_initSeqN : entity surf.SynchronizerVector
      generic map (
         TPD_G         => TPD_G,
         BYPASS_SYNC_G => COMMON_CLK_G,
         WIDTH_G       => 8)
      port map (
         clk     => devClk_i,
         dataIn  => r.initSeqN,
         dataOut => initSeqN_o);

   U_RssiParamSync_In : entity surf.RssiParamSync
      generic map (
         TPD_G        => TPD_G,
         COMMON_CLK_G => COMMON_CLK_G)
      port map (
         clk         => devClk_i,
         rssiParam_i => negRssiParam_i,
         rssiParam_o => negRssiParam);

   U_RssiParamSync_Out : entity surf.RssiParamSync
      generic map (
         TPD_G        => TPD_G,
         COMMON_CLK_G => COMMON_CLK_G)
      port map (
         clk         => devClk_i,
         rssiParam_i => r.appRssiParam,
         rssiParam_o => appRssiParam_o);

end rtl;
