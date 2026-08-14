-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Flat cocotb harness for surf.RogueTcpStreamWrap
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

entity RogueTcpStreamFlatHarness is
   generic (
      TPD_G                      : time                        := 1 ns;
      PORT_NUM_G                 : natural range 1024 to 49151 := 9000;
      DATA_BYTES_G               : positive range 1 to 128     := 8;
      -- Channel count passed straight through to RogueTcpStreamWrap. Default 1
      -- keeps the single-channel round-trip tests unchanged; a non-power-of-two
      -- value exercises the channelMap()/CHAN_MASK_C derivation at elaboration.
      CHAN_COUNT_G               : natural range 0 to 256       := 1;
      AXIS_CLK_FREQ_HZ_G         : natural                      := 0;
      S_AXIS_PAYLOAD_RATE_KBPS_G : natural                      := 0;
      M_AXIS_PAYLOAD_RATE_KBPS_G : natural                      := 0);
   port (
      axisClk       : in  sl;
      axisRst       : in  sl;
      S_AXIS_TVALID : in  sl;
      S_AXIS_TDATA  : in  slv((DATA_BYTES_G*8)-1 downto 0);
      S_AXIS_TKEEP  : in  slv(DATA_BYTES_G-1 downto 0);
      S_AXIS_TLAST  : in  sl;
      S_AXIS_TDEST  : in  slv(7 downto 0);
      S_AXIS_TUSER  : in  slv((DATA_BYTES_G*8)-1 downto 0);
      S_AXIS_TREADY : out sl;
      M_AXIS_TVALID : out sl;
      M_AXIS_TDATA  : out slv((DATA_BYTES_G*8)-1 downto 0);
      M_AXIS_TKEEP  : out slv(DATA_BYTES_G-1 downto 0);
      M_AXIS_TLAST  : out sl;
      M_AXIS_TDEST  : out slv(7 downto 0);
      M_AXIS_TUSER  : out slv((DATA_BYTES_G*8)-1 downto 0);
      M_AXIS_TREADY : in  sl);
end entity RogueTcpStreamFlatHarness;

architecture harness of RogueTcpStreamFlatHarness is

   constant AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => DATA_BYTES_G,
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_NORMAL_C,
      TUSER_BITS_C  => 8,
      TUSER_MODE_C  => TUSER_NORMAL_C);

   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

begin

   ------------------------
   -- AXI Stream shims  --
   ------------------------
   comb : process (M_AXIS_TREADY, S_AXIS_TDATA, S_AXIS_TDEST,
                   S_AXIS_TKEEP, S_AXIS_TLAST, S_AXIS_TUSER, S_AXIS_TVALID,
                   mAxisMaster, sAxisSlave) is
      variable vS : AxiStreamMasterType;
      variable vM : AxiStreamSlaveType;
   begin
      vS                    := AXI_STREAM_MASTER_INIT_C;
      vS.tValid             := S_AXIS_TVALID;
      vS.tData((DATA_BYTES_G*8)-1 downto 0) := S_AXIS_TDATA;
      -- tStrb is intentionally not driven: AXIS_CONFIG_C sets TSTRB_EN_C =>
      -- false, so the SimLink boundary ignores it (TKEEP carries the bytemap).
      vS.tKeep(DATA_BYTES_G-1 downto 0)     := S_AXIS_TKEEP;
      vS.tLast              := S_AXIS_TLAST;
      vS.tDest(7 downto 0)  := S_AXIS_TDEST;
      vS.tUser((DATA_BYTES_G*8)-1 downto 0) := S_AXIS_TUSER;

      vM        := AXI_STREAM_SLAVE_INIT_C;
      vM.tReady := M_AXIS_TREADY;

      sAxisMaster <= vS;
      mAxisSlave  <= vM;

      S_AXIS_TREADY <= sAxisSlave.tReady;
      M_AXIS_TVALID <= mAxisMaster.tValid;
      M_AXIS_TDATA  <= mAxisMaster.tData((DATA_BYTES_G*8)-1 downto 0);
      M_AXIS_TKEEP  <= mAxisMaster.tKeep(DATA_BYTES_G-1 downto 0);
      M_AXIS_TLAST  <= mAxisMaster.tLast;
      M_AXIS_TDEST  <= mAxisMaster.tDest(7 downto 0);
      M_AXIS_TUSER  <= mAxisMaster.tUser((DATA_BYTES_G*8)-1 downto 0);
   end process comb;

   ---------------------
   -- DUT instancing  --
   ---------------------
   U_DUT : entity surf.RogueTcpStreamWrap
      generic map (
         TPD_G         => TPD_G,
         PORT_NUM_G    => PORT_NUM_G,
         SSI_EN_G      => true,
         CHAN_COUNT_G  => CHAN_COUNT_G,
         AXIS_CONFIG_G => AXIS_CONFIG_C,
         AXIS_CLK_FREQ_G       => real(AXIS_CLK_FREQ_HZ_G),
         S_AXIS_PAYLOAD_RATE_G => 1.0E+3*real(S_AXIS_PAYLOAD_RATE_KBPS_G),
         M_AXIS_PAYLOAD_RATE_G => 1.0E+3*real(M_AXIS_PAYLOAD_RATE_KBPS_G))
      port map (
         axisClk     => axisClk,     -- [in]
         axisRst     => axisRst,     -- [in]
         sAxisMaster => sAxisMaster, -- [in]
         sAxisSlave  => sAxisSlave,  -- [out]
         mAxisMaster => mAxisMaster, -- [out]
         mAxisSlave  => mAxisSlave); -- [in]

end architecture harness;
