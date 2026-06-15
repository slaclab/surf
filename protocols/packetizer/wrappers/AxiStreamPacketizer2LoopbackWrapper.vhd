-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing AxiStreamPacketizer2/AxiStreamDepacketizer2 loopback
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
use surf.AxiStreamPacketizer2Pkg.all;

entity AxiStreamPacketizer2LoopbackWrapper is
   generic (
      TPD_G                : time                   := 1 ns;
      RST_POLARITY_G       : sl                     := '1';
      RST_ASYNC_G          : boolean                := false;
      MEMORY_TYPE_G        : string                 := "distributed";
      REG_EN_G             : boolean                := false;
      CRC_PIPELINE_G       : natural range 0 to 1   := 0;
      CRC_MODE_G           : string                 := "NONE";
      MAX_PACKET_BYTES_G   : positive               := 64;
      SEQ_CNT_SIZE_G       : positive range 4 to 16 := 16;
      TDEST_BITS_G         : natural                := 8;
      INPUT_PIPE_STAGES_G  : natural                := 0;
      OUTPUT_PIPE_STAGES_G : natural                := 1);
   port (
      axisClk       : in  sl;
      axisRst       : in  sl;
      linkGood      : in  sl;
      maxPktBytes   : in  slv(bitSize(MAX_PACKET_BYTES_G)-1 downto 0) := toSlv(MAX_PACKET_BYTES_G, bitSize(MAX_PACKET_BYTES_G));
      rearbitrate   : out sl;
      debugOut      : out slv(12 downto 0);
      S_AXIS_TVALID : in  sl;
      S_AXIS_TDATA  : in  slv(63 downto 0);
      S_AXIS_TKEEP  : in  slv(7 downto 0);
      S_AXIS_TLAST  : in  sl;
      S_AXIS_TDEST  : in  slv(7 downto 0);
      S_AXIS_TID    : in  slv(7 downto 0);
      S_AXIS_TUSER  : in  slv(63 downto 0);
      S_AXIS_TREADY : out sl;
      M_AXIS_TVALID : out sl;
      M_AXIS_TDATA  : out slv(63 downto 0);
      M_AXIS_TKEEP  : out slv(7 downto 0);
      M_AXIS_TLAST  : out sl;
      M_AXIS_TDEST  : out slv(7 downto 0);
      M_AXIS_TID    : out slv(7 downto 0);
      M_AXIS_TUSER  : out slv(63 downto 0);
      M_AXIS_TREADY : in  sl);
end entity AxiStreamPacketizer2LoopbackWrapper;

architecture rtl of AxiStreamPacketizer2LoopbackWrapper is

   signal debug          : Packetizer2DebugType := PACKETIZER2_DEBUG_INIT_C;
   signal sAppAxisMaster : AxiStreamMasterType  := AXI_STREAM_MASTER_INIT_C;
   signal sAppAxisSlave  : AxiStreamSlaveType   := AXI_STREAM_SLAVE_INIT_C;
   signal pktAxisMaster  : AxiStreamMasterType  := AXI_STREAM_MASTER_INIT_C;
   signal pktAxisSlave   : AxiStreamSlaveType   := AXI_STREAM_SLAVE_INIT_C;
   signal mAppAxisMaster : AxiStreamMasterType  := AXI_STREAM_MASTER_INIT_C;
   signal mAppAxisSlave  : AxiStreamSlaveType   := AXI_STREAM_SLAVE_INIT_C;

begin

   debugOut <= debug.initDone & debug.sof & debug.eof & debug.eofe & debug.sop &
               debug.eop & debug.packetError & debug.sofError & debug.seqError &
               debug.versionError & debug.crcModeError & debug.eofeError &
               debug.crcError;

   ---------------
   -- Bus shims --
   ---------------
   comb : process (M_AXIS_TREADY, S_AXIS_TDATA, S_AXIS_TDEST, S_AXIS_TID,
                   S_AXIS_TKEEP, S_AXIS_TLAST, S_AXIS_TUSER, S_AXIS_TVALID,
                   mAppAxisMaster, sAppAxisSlave) is
      variable vS : AxiStreamMasterType;
      variable vM : AxiStreamSlaveType;
   begin
      vS                    := AXI_STREAM_MASTER_INIT_C;
      vS.tValid             := S_AXIS_TVALID;
      vS.tData(63 downto 0) := S_AXIS_TDATA;
      vS.tStrb              := (others => '0');
      vS.tStrb(7 downto 0)  := S_AXIS_TKEEP;
      vS.tKeep              := (others => '0');
      vS.tKeep(7 downto 0)  := S_AXIS_TKEEP;
      vS.tLast              := S_AXIS_TLAST;
      vS.tDest(7 downto 0)  := S_AXIS_TDEST;
      vS.tId(7 downto 0)    := S_AXIS_TID;
      vS.tUser              := (others => '0');
      vS.tUser(63 downto 0) := S_AXIS_TUSER;

      vM        := AXI_STREAM_SLAVE_INIT_C;
      vM.tReady := M_AXIS_TREADY;

      sAppAxisMaster <= vS;
      mAppAxisSlave  <= vM;

      S_AXIS_TREADY <= sAppAxisSlave.tReady;
      M_AXIS_TVALID <= mAppAxisMaster.tValid;
      M_AXIS_TDATA  <= mAppAxisMaster.tData(63 downto 0);
      M_AXIS_TKEEP  <= mAppAxisMaster.tKeep(7 downto 0);
      M_AXIS_TLAST  <= mAppAxisMaster.tLast;
      M_AXIS_TDEST  <= mAppAxisMaster.tDest(7 downto 0);
      M_AXIS_TID    <= mAppAxisMaster.tId(7 downto 0);
      M_AXIS_TUSER  <= mAppAxisMaster.tUser(63 downto 0);
   end process comb;

   U_Packetizer : entity surf.AxiStreamPacketizer2
      generic map (
         TPD_G                => TPD_G,
         RST_POLARITY_G       => RST_POLARITY_G,
         RST_ASYNC_G          => RST_ASYNC_G,
         MEMORY_TYPE_G        => MEMORY_TYPE_G,
         REG_EN_G             => REG_EN_G,
         CRC_MODE_G           => CRC_MODE_G,
         MAX_PACKET_BYTES_G   => MAX_PACKET_BYTES_G,
         SEQ_CNT_SIZE_G       => SEQ_CNT_SIZE_G,
         TDEST_BITS_G         => TDEST_BITS_G,
         INPUT_PIPE_STAGES_G  => INPUT_PIPE_STAGES_G,
         OUTPUT_PIPE_STAGES_G => 0)
      port map (
         axisClk     => axisClk,
         axisRst     => axisRst,
         rearbitrate => rearbitrate,
         maxPktBytes => maxPktBytes,
         sAxisMaster => sAppAxisMaster,
         sAxisSlave  => sAppAxisSlave,
         mAxisMaster => pktAxisMaster,
         mAxisSlave  => pktAxisSlave);

   U_Depacketizer : entity surf.AxiStreamDepacketizer2
      generic map (
         TPD_G                => TPD_G,
         RST_POLARITY_G       => RST_POLARITY_G,
         RST_ASYNC_G          => RST_ASYNC_G,
         MEMORY_TYPE_G        => MEMORY_TYPE_G,
         REG_EN_G             => REG_EN_G,
         CRC_PIPELINE_G       => CRC_PIPELINE_G,
         CRC_MODE_G           => CRC_MODE_G,
         SEQ_CNT_SIZE_G       => SEQ_CNT_SIZE_G,
         TDEST_BITS_G         => TDEST_BITS_G,
         INPUT_PIPE_STAGES_G  => 0,
         OUTPUT_PIPE_STAGES_G => OUTPUT_PIPE_STAGES_G)
      port map (
         axisClk     => axisClk,
         axisRst     => axisRst,
         linkGood    => linkGood,
         debug       => debug,
         sAxisMaster => pktAxisMaster,
         sAxisSlave  => pktAxisSlave,
         mAxisMaster => mAppAxisMaster,
         mAxisSlave  => mAppAxisSlave);

end architecture rtl;
