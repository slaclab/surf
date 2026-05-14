-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for SsiPrbsTx/SsiPrbsRx loopback testing
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
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

entity SsiPrbsWrapper is
   generic (
      PRBS_SEED_SIZE_G : positive := 32;
      DATA_BYTES_G     : positive := 16);
   port (
      fastClk         : in  sl;
      fastRst         : in  sl;
      slowClk         : in  sl;
      slowRst         : in  sl;
      trig            : in  sl;
      packetLength    : in  slv(31 downto 0);
      forceEofe       : in  sl;
      updated         : out sl;
      txBusy          : out sl;
      errMissedPacket : out sl;
      errLength       : out sl;
      errDataBus      : out sl;
      errEofe         : out sl;
      errWordCnt      : out slv(31 downto 0);
      rxPacketLength  : out slv(31 downto 0));
end entity SsiPrbsWrapper;

architecture rtl of SsiPrbsWrapper is

   function PrbsAxiStreamConfig (
      dataBytes : natural;
      tKeepMode : TKeepModeType := TKEEP_COMP_C)
      return AxiStreamConfigType is
      variable ret : AxiStreamConfigType;
   begin
      ret.TDATA_BYTES_C := dataBytes;
      ret.TUSER_BITS_C  := 4;
      ret.TDEST_BITS_C  := SSI_TDEST_BITS_C;
      ret.TID_BITS_C    := SSI_TID_BITS_C;
      ret.TKEEP_MODE_C  := tKeepMode;
      ret.TSTRB_EN_C    := SSI_TSTRB_EN_C;
      ret.TUSER_MODE_C  := TUSER_FIRST_LAST_C;
      return ret;
   end function;

   constant TPD_C               : time                := 10 ns/12;
   constant STATUS_CNT_WIDTH_C  : natural             := 32;
   constant TX_PACKET_LENGTH_C  : slv(31 downto 0)    := toSlv(64, 32);
   constant MEMORY_TYPE_C       : string              := "block";
   constant GEN_SYNC_FIFO_C     : boolean             := false;
   constant CASCADE_SIZE_C      : natural             := 1;
   constant FIFO_ADDR_WIDTH_C   : natural             := 9;
   constant FIFO_PAUSE_THRESH_C : natural             := 2**8;
   constant PRBS_SEED_SIZE_C    : natural             := PRBS_SEED_SIZE_G;
   constant PRBS_TAPS_C         : NaturalArray        := (0 => 31, 1 => 6, 2 => 2, 3 => 1);
   constant FORCE_EOFE_C        : sl                  := '0';
   constant AXI_STREAM_CONFIG_C : AxiStreamConfigType := PrbsAxiStreamConfig(DATA_BYTES_G, TKEEP_COMP_C);
   constant AXI_PIPE_STAGES_C   : natural             := 1;

   signal axisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal axisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

begin

   U_SsiPrbsTx : entity surf.SsiPrbsTx
      generic map (
         TPD_G                      => TPD_C,
         AXI_EN_G                   => '0',
         MEMORY_TYPE_G              => MEMORY_TYPE_C,
         GEN_SYNC_FIFO_G            => GEN_SYNC_FIFO_C,
         CASCADE_SIZE_G             => CASCADE_SIZE_C,
         FIFO_ADDR_WIDTH_G          => FIFO_ADDR_WIDTH_C,
         FIFO_PAUSE_THRESH_G        => FIFO_PAUSE_THRESH_C,
         PRBS_SEED_SIZE_G           => PRBS_SEED_SIZE_C,
         PRBS_TAPS_G                => PRBS_TAPS_C,
         MASTER_AXI_STREAM_CONFIG_G => AXI_STREAM_CONFIG_C,
         MASTER_AXI_PIPE_STAGES_G   => AXI_PIPE_STAGES_C)
      port map (
         mAxisClk     => slowClk,
         mAxisRst     => slowRst,
         mAxisMaster  => axisMaster,
         mAxisSlave   => axisSlave,
         locClk       => fastClk,
         locRst       => fastRst,
         trig         => trig,
         packetLength => packetLength,
         forceEofe    => forceEofe,
         busy         => txBusy,
         tDest        => (others => '0'),
         tId          => (others => '0'));

   U_SsiPrbsRx : entity surf.SsiPrbsRx
      generic map (
         TPD_G                     => TPD_C,
         STATUS_CNT_WIDTH_G        => STATUS_CNT_WIDTH_C,
         MEMORY_TYPE_G             => MEMORY_TYPE_C,
         GEN_SYNC_FIFO_G           => GEN_SYNC_FIFO_C,
         CASCADE_SIZE_G            => CASCADE_SIZE_C,
         FIFO_ADDR_WIDTH_G         => FIFO_ADDR_WIDTH_C,
         FIFO_PAUSE_THRESH_G       => FIFO_PAUSE_THRESH_C,
         PRBS_SEED_SIZE_G          => PRBS_SEED_SIZE_C,
         PRBS_TAPS_G               => PRBS_TAPS_C,
         SLAVE_AXI_STREAM_CONFIG_G => AXI_STREAM_CONFIG_C,
         SLAVE_AXI_PIPE_STAGES_G   => AXI_PIPE_STAGES_C)
      port map (
         sAxisClk        => slowClk,
         sAxisRst        => slowRst,
         sAxisMaster     => axisMaster,
         sAxisSlave      => axisSlave,
         sAxisCtrl       => open,
         axiClk          => slowClk,
         axiRst          => slowRst,
         axiReadMaster   => AXI_LITE_READ_MASTER_INIT_C,
         axiReadSlave    => open,
         axiWriteMaster  => AXI_LITE_WRITE_MASTER_INIT_C,
         updatedResults  => updated,
         busy            => open,
         errMissedPacket => errMissedPacket,
         errLength       => errLength,
         errDataBus      => errDataBus,
         errEofe         => errEofe,
         errWordCnt      => errWordCnt,
         packetLength    => rxPacketLength);

end architecture rtl;
