-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: 32-bit cocotb-facing wrapper for direct SrpV3Core regressions
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;
use surf.SrpV3Pkg.all;

entity SrpV3CoreNarrowWrapper is
   port (
      AXIS_ACLK        : in  std_logic;
      AXIS_ARESETN     : in  std_logic;
      S_AXIS_TVALID    : in  std_logic;
      S_AXIS_TDATA     : in  std_logic_vector(31 downto 0);
      S_AXIS_TKEEP     : in  std_logic_vector(3 downto 0);
      S_AXIS_TLAST     : in  std_logic;
      S_AXIS_TDEST     : in  std_logic_vector(3 downto 0);
      S_AXIS_TID       : in  std_logic_vector(0 downto 0);
      S_AXIS_TUSER     : in  std_logic_vector(1 downto 0);
      S_AXIS_TREADY    : out std_logic;
      M_AXIS_TVALID    : out std_logic;
      M_AXIS_TDATA     : out std_logic_vector(31 downto 0);
      M_AXIS_TKEEP     : out std_logic_vector(3 downto 0);
      M_AXIS_TLAST     : out std_logic;
      M_AXIS_TDEST     : out std_logic_vector(3 downto 0);
      M_AXIS_TID       : out std_logic_vector(0 downto 0);
      M_AXIS_TUSER     : out std_logic_vector(1 downto 0);
      M_AXIS_TREADY    : in  std_logic;
      RD_AXIS_TVALID   : in  std_logic;
      RD_AXIS_TDATA    : in  std_logic_vector(31 downto 0);
      RD_AXIS_TKEEP    : in  std_logic_vector(3 downto 0);
      RD_AXIS_TLAST    : in  std_logic;
      RD_AXIS_TUSER    : in  std_logic_vector(1 downto 0);
      RD_AXIS_TREADY   : out std_logic;
      WR_AXIS_TVALID   : out std_logic;
      WR_AXIS_TDATA    : out std_logic_vector(31 downto 0);
      WR_AXIS_TKEEP    : out std_logic_vector(3 downto 0);
      WR_AXIS_TLAST    : out std_logic;
      WR_AXIS_TUSER    : out std_logic_vector(1 downto 0);
      WR_AXIS_TREADY   : in  std_logic;
      SRP_REQ_REQUEST  : out std_logic;
      SRP_REQ_REM_VER  : out std_logic_vector(7 downto 0);
      SRP_REQ_OPCODE   : out std_logic_vector(1 downto 0);
      SRP_REQ_PROT     : out std_logic_vector(2 downto 0);
      SRP_REQ_TID      : out std_logic_vector(31 downto 0);
      SRP_REQ_ADDR     : out std_logic_vector(63 downto 0);
      SRP_REQ_REQ_SIZE : out std_logic_vector(31 downto 0);
      SRP_ACK_DONE     : in  std_logic;
      SRP_ACK_RESP     : in  std_logic_vector(7 downto 0));
end entity SrpV3CoreNarrowWrapper;

architecture rtl of SrpV3CoreNarrowWrapper is

   constant TPD_C         : time                := 10 ns / 4;
   constant AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(4);

   signal axisRst : sl := '0';

   signal sAxisMaster  : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave   : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal mAxisMaster  : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlave   : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal rdAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal rdAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal wrAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal wrAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

   signal srpReq : SrpV3ReqType := SRPV3_REQ_INIT_C;
   signal srpAck : SrpV3AckType := SRPV3_ACK_INIT_C;

begin

   axisRst <= not AXIS_ARESETN;

   srpAck.done     <= SRP_ACK_DONE;
   srpAck.respCode <= SRP_ACK_RESP;

   SRP_REQ_REQUEST  <= srpReq.request;
   SRP_REQ_REM_VER  <= srpReq.remVer;
   SRP_REQ_OPCODE   <= srpReq.opCode;
   SRP_REQ_PROT     <= srpReq.prot;
   SRP_REQ_TID      <= srpReq.tid;
   SRP_REQ_ADDR     <= srpReq.addr;
   SRP_REQ_REQ_SIZE <= srpReq.reqSize;

   U_ShimLayerSlave : entity surf.SlaveAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "S_AXIS",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 0,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => 2,
         TID_WIDTH       => 1,
         TDEST_WIDTH     => 4,
         TDATA_NUM_BYTES => 4)
      port map (
         S_AXIS_ACLK    => AXIS_ACLK,
         S_AXIS_ARESETN => AXIS_ARESETN,
         S_AXIS_TVALID  => S_AXIS_TVALID,
         S_AXIS_TDATA   => S_AXIS_TDATA,
         S_AXIS_TKEEP   => S_AXIS_TKEEP,
         S_AXIS_TLAST   => S_AXIS_TLAST,
         S_AXIS_TDEST   => S_AXIS_TDEST,
         S_AXIS_TID     => S_AXIS_TID,
         S_AXIS_TUSER   => S_AXIS_TUSER,
         S_AXIS_TREADY  => S_AXIS_TREADY,
         axisClk        => open,
         axisRst        => open,
         axisMaster     => sAxisMaster,
         axisSlave      => sAxisSlave);

   U_ShimLayerMaster : entity surf.MasterAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "M_AXIS",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 0,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => 2,
         TID_WIDTH       => 1,
         TDEST_WIDTH     => 4,
         TDATA_NUM_BYTES => 4)
      port map (
         M_AXIS_ACLK    => AXIS_ACLK,
         M_AXIS_ARESETN => AXIS_ARESETN,
         M_AXIS_TVALID  => M_AXIS_TVALID,
         M_AXIS_TDATA   => M_AXIS_TDATA,
         M_AXIS_TKEEP   => M_AXIS_TKEEP,
         M_AXIS_TLAST   => M_AXIS_TLAST,
         M_AXIS_TDEST   => M_AXIS_TDEST,
         M_AXIS_TID     => M_AXIS_TID,
         M_AXIS_TUSER   => M_AXIS_TUSER,
         M_AXIS_TREADY  => M_AXIS_TREADY,
         axisClk        => open,
         axisRst        => open,
         axisMaster     => mAxisMaster,
         axisSlave      => mAxisSlave);

   U_ReadShim : entity surf.SlaveAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "RD_AXIS",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 0,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => 2,
         TID_WIDTH       => 1,
         TDEST_WIDTH     => 1,
         TDATA_NUM_BYTES => 4)
      port map (
         S_AXIS_ACLK    => AXIS_ACLK,
         S_AXIS_ARESETN => AXIS_ARESETN,
         S_AXIS_TVALID  => RD_AXIS_TVALID,
         S_AXIS_TDATA   => RD_AXIS_TDATA,
         S_AXIS_TKEEP   => RD_AXIS_TKEEP,
         S_AXIS_TLAST   => RD_AXIS_TLAST,
         S_AXIS_TDEST   => "0",
         S_AXIS_TID     => "0",
         S_AXIS_TUSER   => RD_AXIS_TUSER,
         S_AXIS_TREADY  => RD_AXIS_TREADY,
         axisClk        => open,
         axisRst        => open,
         axisMaster     => rdAxisMaster,
         axisSlave      => rdAxisSlave);

   U_WriteShim : entity surf.MasterAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "WR_AXIS",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 0,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => 2,
         TID_WIDTH       => 1,
         TDEST_WIDTH     => 1,
         TDATA_NUM_BYTES => 4)
      port map (
         M_AXIS_ACLK    => AXIS_ACLK,
         M_AXIS_ARESETN => AXIS_ARESETN,
         M_AXIS_TVALID  => WR_AXIS_TVALID,
         M_AXIS_TDATA   => WR_AXIS_TDATA,
         M_AXIS_TKEEP   => WR_AXIS_TKEEP,
         M_AXIS_TLAST   => WR_AXIS_TLAST,
         M_AXIS_TDEST   => open,
         M_AXIS_TID     => open,
         M_AXIS_TUSER   => WR_AXIS_TUSER,
         M_AXIS_TREADY  => WR_AXIS_TREADY,
         axisClk        => open,
         axisRst        => open,
         axisMaster     => wrAxisMaster,
         axisSlave      => wrAxisSlave);

   U_DUT : entity surf.SrpV3Core
      generic map (
         TPD_G               => TPD_C,
         SLAVE_READY_EN_G    => true,
         GEN_SYNC_FIFO_G     => true,
         AXI_STREAM_CONFIG_G => AXIS_CONFIG_C)
      port map (
         sAxisClk    => AXIS_ACLK,
         sAxisRst    => axisRst,
         sAxisMaster => sAxisMaster,
         sAxisSlave  => sAxisSlave,
         sAxisCtrl   => open,
         mAxisClk    => AXIS_ACLK,
         mAxisRst    => axisRst,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave,
         srpClk      => AXIS_ACLK,
         srpRst      => axisRst,
         srpReq      => srpReq,
         srpAck      => srpAck,
         srpWrMaster => wrAxisMaster,
         srpWrSlave  => wrAxisSlave,
         srpRdMaster => rdAxisMaster,
         srpRdSlave  => rdAxisSlave);

end architecture rtl;
