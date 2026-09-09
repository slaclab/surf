-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Flat cocotb harness for RogueTcpStreamPacer
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

entity RogueTcpStreamPacerFlatHarness is
   generic (
      TPD_G              : time                    := 1 ns;
      DATA_BYTES_G       : positive range 1 to 128 := 8;
      AXIS_CLK_FREQ_HZ_G : positive                := 100;      -- Clock rate in Hz
      -- Payload rate in bits/s (not kbits/s).  The pacer test exercises
      -- sub-kbit/s rates for fixed-point-credit resolution, so this harness
      -- keeps bit/s granularity.  RogueTcpStreamFlatHarness takes kbit/s
      -- instead because multi-Gbit/s link rates overflow a 32-bit natural.
      PAYLOAD_RATE_BPS_G : natural                 := 0;
      TKEEP_COUNT_G      : boolean                 := false);
   port (
      axisClk       : in  sl;
      axisRst       : in  sl;
      S_AXIS_TVALID : in  sl;
      S_AXIS_TDATA  : in  slv((DATA_BYTES_G*8)-1 downto 0);
      S_AXIS_TKEEP  : in  slv(DATA_BYTES_G-1 downto 0);
      S_AXIS_TLAST  : in  sl;
      S_AXIS_TREADY : out sl;
      M_AXIS_TVALID : out sl;
      M_AXIS_TDATA  : out slv((DATA_BYTES_G*8)-1 downto 0);
      M_AXIS_TKEEP  : out slv(DATA_BYTES_G-1 downto 0);
      M_AXIS_TLAST  : out sl;
      M_AXIS_TREADY : in  sl);
end entity RogueTcpStreamPacerFlatHarness;

architecture harness of RogueTcpStreamPacerFlatHarness is

   constant BASE_AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => DATA_BYTES_G,
      TDEST_BITS_C  => 0,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_NORMAL_C,
      TUSER_BITS_C  => 0,
      TUSER_MODE_C  => TUSER_NONE_C);

   function axisConfig return AxiStreamConfigType is
      variable ret : AxiStreamConfigType := BASE_AXIS_CONFIG_C;
   begin
      if TKEEP_COUNT_G then
         ret.TKEEP_MODE_C := TKEEP_COUNT_C;
      end if;
      return ret;
   end function axisConfig;

   constant AXIS_CONFIG_C : AxiStreamConfigType := axisConfig;

   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

begin

   sAxisMaster.tValid                                      <= S_AXIS_TVALID;
   sAxisMaster.tData((DATA_BYTES_G*8)-1 downto 0)          <= S_AXIS_TDATA;
   sAxisMaster.tKeep(DATA_BYTES_G-1 downto 0)              <= S_AXIS_TKEEP;
   sAxisMaster.tLast                                       <= S_AXIS_TLAST;
   sAxisMaster.tData(AXI_STREAM_MAX_TDATA_WIDTH_C-1 downto DATA_BYTES_G*8) <= (others => '0');
   sAxisMaster.tKeep(AXI_STREAM_MAX_TKEEP_WIDTH_C-1 downto DATA_BYTES_G)   <= (others => '0');
   sAxisMaster.tStrb                                       <= (others => '1');
   sAxisMaster.tDest                                       <= (others => '0');
   sAxisMaster.tId                                         <= (others => '0');
   sAxisMaster.tUser                                       <= (others => '0');

   mAxisSlave.tReady <= M_AXIS_TREADY;

   S_AXIS_TREADY <= sAxisSlave.tReady;
   M_AXIS_TVALID <= mAxisMaster.tValid;
   M_AXIS_TDATA  <= mAxisMaster.tData((DATA_BYTES_G*8)-1 downto 0);
   M_AXIS_TKEEP  <= mAxisMaster.tKeep(DATA_BYTES_G-1 downto 0);
   M_AXIS_TLAST  <= mAxisMaster.tLast;

   U_DUT : entity surf.RogueTcpStreamPacer
      generic map (
         TPD_G           => TPD_G,
         AXIS_CONFIG_G   => AXIS_CONFIG_C,
         AXIS_CLK_FREQ_G => real(AXIS_CLK_FREQ_HZ_G),
         PAYLOAD_RATE_G  => real(PAYLOAD_RATE_BPS_G))
      port map (
         axisClk     => axisClk,      -- [in]
         axisRst     => axisRst,      -- [in]
         sAxisMaster => sAxisMaster,  -- [in]
         sAxisSlave  => sAxisSlave,   -- [out]
         mAxisMaster => mAxisMaster,  -- [out]
         mAxisSlave  => mAxisSlave);  -- [in]

end architecture harness;
