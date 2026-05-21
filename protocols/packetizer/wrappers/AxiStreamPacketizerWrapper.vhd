-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for surf.AxiStreamPacketizer
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

entity AxiStreamPacketizerWrapper is
   generic (
      TPD_G                : time            := 1 ns;
      RST_ASYNC_G          : boolean         := false;
      MAX_PACKET_BYTES_G   : integer         := 64;
      MIN_TKEEP_G          : slv(7 downto 0) := x"01";
      OUTPUT_SSI_G         : boolean         := true;
      INPUT_PIPE_STAGES_G  : integer         := 0;
      OUTPUT_PIPE_STAGES_G : integer         := 0);
   port (
      axisClk       : in  sl;
      axisRst       : in  sl;
      maxPktBytes   : in  slv(bitSize(MAX_PACKET_BYTES_G)-1 downto 0) := toSlv(MAX_PACKET_BYTES_G, bitSize(MAX_PACKET_BYTES_G));
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
      M_AXIS_TUSER  : out slv(15 downto 0);
      M_AXIS_TREADY : in  sl);
end entity AxiStreamPacketizerWrapper;

architecture rtl of AxiStreamPacketizerWrapper is

   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

begin

   ---------------
   -- Bus shims --
   ---------------
   comb : process (M_AXIS_TREADY, S_AXIS_TDATA, S_AXIS_TDEST, S_AXIS_TID,
                   S_AXIS_TKEEP, S_AXIS_TLAST, S_AXIS_TUSER, S_AXIS_TVALID,
                   mAxisMaster, sAxisSlave) is
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

      sAxisMaster <= vS;
      mAxisSlave  <= vM;

      S_AXIS_TREADY <= sAxisSlave.tReady;
      M_AXIS_TVALID <= mAxisMaster.tValid;
      M_AXIS_TDATA  <= mAxisMaster.tData(63 downto 0);
      M_AXIS_TKEEP  <= mAxisMaster.tKeep(7 downto 0);
      M_AXIS_TLAST  <= mAxisMaster.tLast;
      M_AXIS_TDEST  <= mAxisMaster.tDest(7 downto 0);
      M_AXIS_TID    <= mAxisMaster.tId(7 downto 0);
      M_AXIS_TUSER  <= mAxisMaster.tUser(15 downto 0);
   end process comb;

   ---------------------
   -- DUT instancing  --
   ---------------------
   U_DUT : entity surf.AxiStreamPacketizer
      generic map (
         TPD_G                => TPD_G,
         RST_ASYNC_G          => RST_ASYNC_G,
         MAX_PACKET_BYTES_G   => MAX_PACKET_BYTES_G,
         MIN_TKEEP_G          => MIN_TKEEP_G,
         OUTPUT_SSI_G         => OUTPUT_SSI_G,
         INPUT_PIPE_STAGES_G  => INPUT_PIPE_STAGES_G,
         OUTPUT_PIPE_STAGES_G => OUTPUT_PIPE_STAGES_G)
      port map (
         axisClk     => axisClk,
         axisRst     => axisRst,
         maxPktBytes => maxPktBytes,
         sAxisMaster => sAxisMaster,
         sAxisSlave  => sAxisSlave,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);

end architecture rtl;
