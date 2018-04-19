-------------------------------------------------------------------------------
-- Title      : Testbench for design "AxiStreamPacketizer2"
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of SURF. It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of SURF, including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

----------------------------------------------------------------------------------------------------

entity AxiStreamPacketizer2Tb is

end entity AxiStreamPacketizer2Tb;

----------------------------------------------------------------------------------------------------

architecture tb of AxiStreamPacketizer2Tb is

   -- component generics
   constant TPD_G                : time             := 1 ns;
   constant CRC_EN_G             : boolean          := false;
   constant CRC_POLY_G           : slv(31 downto 0) := x"04C11DB7";
   constant MAX_PACKET_BYTES_G   : integer          := 256*8;
   constant OUTPUT_SSI_G         : boolean          := true;
   constant INPUT_PIPE_STAGES_G  : integer          := 0;
   constant OUTPUT_PIPE_STAGES_G : integer          := 0;
   constant NUM_CHANNELS_C       : integer          := 4;

   -- component ports
   signal axisClk                : sl;                                               -- [in]
   signal axisRst                : sl;                                               -- [in]
   signal rearbitrate            : sl;                                               -- [out]
   signal prbsTxAxisMasters      : AxiStreamMasterArray(NUM_CHANNELS_C-1 downto 0);  -- [in]
   signal prbsTxAxisSlaves       : AxiStreamSlaveArray(NUM_CHANNELS_C-1 downto 0);   -- [out]
   signal muxAxisMaster          : AxiStreamMasterType;
   signal muxAxisSlave           : AxiStreamSlaveType;
   signal packetizedAxisMaster   : AxiStreamMasterType;                              -- [out]
   signal packetizedAxisSlave    : AxiStreamSlaveType;                               -- [in]
   signal depacketizedAxisMaster : AxiStreamMasterType;                              -- [out]
   signal depacketizedAxisSlave  : AxiStreamSlaveType;                               -- [in]
   signal demuxedAxisMasters     : AxiStreamMasterArray(NUM_CHANNELS_C-1 downto 0);

   constant PACKETIZER_IN_AXIS_CFG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 8,
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 8,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 8,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

begin

   U_ClkRst_1 : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => 10 ns,
         CLK_DELAY_G       => 1 ns,
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 5 us,
         SYNC_RESET_G      => true)
      port map (
         clkP => axisClk,
         rst  => axisRst);

   PRBS_GEN : for i in 0 to NUM_CHANNELS_C-1 generate
      U_SsiPrbsTx_1 : entity work.SsiPrbsTx
         generic map (
            TPD_G                      => TPD_G,
            GEN_SYNC_FIFO_G            => true,
            PRBS_INCREMENT_G           => true,
            MASTER_AXI_STREAM_CONFIG_G => PACKETIZER_IN_AXIS_CFG_C)
         port map (
            mAxisClk     => axisClk,               -- [in]
            mAxisRst     => axisRst,               -- [in]
            mAxisMaster  => prbsTxAxisMasters(i),  -- [out]
            mAxisSlave   => prbsTxAxisSlaves(i),   -- [in]
            locClk       => axisClk,               -- [in]
            locRst       => axisRst,               -- [in]
            trig         => '1',                   -- [in]
            packetLength => X"0000FFFF",           -- [in]
            forceEofe    => '0',                   -- [in]
            busy         => open,                  -- [out]
            tDest        => toSlv(i, 8),           -- [in]
            tId          => X"00");                -- [in]
   end generate PRBS_GEN;

   U_AxiStreamMux_1 : entity work.AxiStreamMux
      generic map (
         TPD_G                    => TPD_G,
         NUM_SLAVES_G             => NUM_CHANNELS_C,
         MODE_G                   => "INDEXED",
--         TDEST_ROUTES_G           => TDEST_ROUTES_G,
--         PIPE_STAGES_G            => PIPE_STAGES_G,
--         TDEST_LOW_G              => TDEST_LOW_G,
         INTERLEAVE_EN_G          => true,
         INTERLEAVE_ON_NOTVALID_G => false,
         INTERLEAVE_MAX_TXNS_G    => 256)
      port map (
         axisClk      => axisClk,            -- [in]
         axisRst      => axisRst,            -- [in]
--         disableSel   => disableSel,    -- [in]
--         rearbitrate  => rearbitrate,   -- [in]
         sAxisMasters => prbsTxAxisMasters,  -- [in]
         sAxisSlaves  => prbsTxAxisSlaves,   -- [out]
         mAxisMaster  => muxAxisMaster,      -- [out]
         mAxisSlave   => muxAxisSlave);      -- [in]

   -- component instantiation
   U_AxiStreamPacketizer2 : entity work.AxiStreamPacketizer2
      generic map (
         TPD_G                => TPD_G,
         CRC_EN_G             => true,
         MAX_PACKET_BYTES_G   => 512*8,
         OUTPUT_SSI_G         => true,
         INPUT_PIPE_STAGES_G  => 0,
         OUTPUT_PIPE_STAGES_G => 0)
      port map (
         axisClk     => axisClk,               -- [in]
         axisRst     => axisRst,               -- [in]
         rearbitrate => rearbitrate,           -- [out]
         sAxisMaster => muxAxisMaster,         -- [in]
         sAxisSlave  => muxAxisSlave,          -- [out]
         mAxisMaster => packetizedAxisMaster,  -- [out]
         mAxisSlave  => packetizedAxisSlave);  -- [in]

   U_AxiStreamDepacketizer2_1 : entity work.AxiStreamDepacketizer2
      generic map (
         TPD_G                => TPD_G,
         CRC_EN_G             => true,
         INPUT_PIPE_STAGES_G  => 0)
      port map (
         axisClk     => axisClk,                 -- [in]
         axisRst     => axisRst,                 -- [in]
         sAxisMaster => packetizedAxisMaster,    -- [in]
         sAxisSlave  => packetizedAxisSlave,     -- [out]
         mAxisMaster => depacketizedAxisMaster,  -- [out]
         mAxisSlave  => depacketizedAxisSlave);  -- [in]

   U_AxiStreamDeMux_1 : entity work.AxiStreamDeMux
      generic map (
         TPD_G         => TPD_G,
         NUM_MASTERS_G => NUM_CHANNELS_C,
         MODE_G        => "INDEXED")
--         TDEST_ROUTES_G => TDEST_ROUTES_G,
--         PIPE_STAGES_G  => PIPE_STAGES_G,
--         TDEST_HIGH_G   => TDEST_HIGH_G,
--         TDEST_LOW_G    => TDEST_LOW_G)
      port map (
         axisClk      => axisClk,                                -- [in]
         axisRst      => axisRst,                                -- [in]
         sAxisMaster  => depacketizedAxisMaster,                 -- [in]
         sAxisSlave   => depacketizedAxisSlave,                  -- [out]
         mAxisMasters => demuxedAxisMasters,                     -- [out]
         mAxisSlaves  => (others => AXI_STREAM_SLAVE_FORCE_C));  -- [in]

--    U_SsiPrbsRx_1 : entity work.SsiPrbsRx
--       generic map (
--          TPD_G                     => TPD_G,
--          GEN_SYNC_FIFO_G           => true,
--          SLAVE_AXI_STREAM_CONFIG_G => PACKETIZER_IN_AXIS_CFG_C,
--          SLAVE_AXI_PIPE_STAGES_G   => 0)
--       port map (
--          sAxisClk    => axisClk,                 -- [in]
--          sAxisRst    => axisRst,                 -- [in]
--          sAxisMaster => depacketizedAxisMaster,  -- [in]
--          sAxisSlave  => depacketizedAxisSlave,
--          mAxisClk    => axisClk);                -- [out]


end architecture tb;

----------------------------------------------------------------------------------------------------
