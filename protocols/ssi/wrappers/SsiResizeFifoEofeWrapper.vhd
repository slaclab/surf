-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for SSI resize FIFO EOFE propagation
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

entity SsiResizeFifoEofeWrapper is
   generic (
      SLAVE_DATA_BYTES_G  : positive range 1 to 64 := 8;
      MASTER_DATA_BYTES_G : positive range 1 to 64 := 8;
      SLAVE_TKEEP_MODE_G  : natural range 0 to 2   := 0;
      MASTER_TKEEP_MODE_G : natural range 0 to 2   := 0;
      SLAVE_TUSER_MODE_G  : natural range 0 to 3   := 0;
      MASTER_TUSER_MODE_G : natural range 0 to 3   := 0;
      SLAVE_TUSER_BITS_G  : positive range 2 to 8  := 4;
      MASTER_TUSER_BITS_G : positive range 2 to 8  := 4);
   port (
      AXIS_ACLK     : in  sl;
      AXIS_ARESETN  : in  sl;
      S_AXIS_TVALID : in  sl;
      S_AXIS_TDATA  : in  slv(511 downto 0);
      S_AXIS_TKEEP  : in  slv(63 downto 0);
      S_AXIS_TLAST  : in  sl;
      S_AXIS_TDEST  : in  slv(3 downto 0);
      S_AXIS_EOFE   : in  sl;
      S_AXIS_TREADY : out sl;
      M_AXIS_TVALID : out sl;
      M_AXIS_TDATA  : out slv(511 downto 0);
      M_AXIS_TKEEP  : out slv(63 downto 0);
      M_AXIS_TLAST  : out sl;
      M_AXIS_TDEST  : out slv(3 downto 0);
      M_AXIS_EOFE   : out sl;
      M_AXIS_TREADY : in  sl);
end entity SsiResizeFifoEofeWrapper;

architecture rtl of SsiResizeFifoEofeWrapper is

   function toTKeepMode (
      modeSel : natural)
      return TKeepModeType is
   begin
      case modeSel is
         when 0 =>
            return TKEEP_NORMAL_C;
         when 1 =>
            return TKEEP_COMP_C;
         when others =>
            return TKEEP_COUNT_C;
      end case;
   end function toTKeepMode;

   function toTUserMode (
      modeSel : natural)
      return TUserModeType is
   begin
      case modeSel is
         when 0 =>
            return TUSER_NORMAL_C;
         when 1 =>
            return TUSER_FIRST_LAST_C;
         when 2 =>
            return TUSER_LAST_C;
         when others =>
            return TUSER_NONE_C;
      end case;
   end function toTUserMode;

   constant SLAVE_AXI_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(
      SLAVE_DATA_BYTES_G,
      toTKeepMode(SLAVE_TKEEP_MODE_G),
      toTUserMode(SLAVE_TUSER_MODE_G),
      4,
      SLAVE_TUSER_BITS_G);

   constant MASTER_AXI_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(
      MASTER_DATA_BYTES_G,
      toTKeepMode(MASTER_TKEEP_MODE_G),
      toTUserMode(MASTER_TUSER_MODE_G),
      4,
      MASTER_TUSER_BITS_G);

   constant SLAVE_DATA_WIDTH_C  : positive := 8*SLAVE_AXI_CONFIG_C.TDATA_BYTES_C;
   constant MASTER_DATA_WIDTH_C : positive := 8*MASTER_AXI_CONFIG_C.TDATA_BYTES_C;
   constant SLAVE_KEEP_WIDTH_C  : positive := SLAVE_AXI_CONFIG_C.TDATA_BYTES_C;
   constant MASTER_KEEP_WIDTH_C : positive := MASTER_AXI_CONFIG_C.TDATA_BYTES_C;

   signal axisRst     : sl                  := '0';
   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

begin

   axisRst <= not AXIS_ARESETN;

   S_AXIS_TREADY <= sAxisSlave.tReady;

   mAxisSlave.tReady <= M_AXIS_TREADY;

   mAxisComb : process (mAxisMaster) is
      variable tData : slv(511 downto 0);
      variable tKeep : slv(63 downto 0);
   begin
      tData := (others => '0');
      tKeep := (others => '0');

      tData(MASTER_DATA_WIDTH_C-1 downto 0) := mAxisMaster.tData(MASTER_DATA_WIDTH_C-1 downto 0);
      tKeep(MASTER_KEEP_WIDTH_C-1 downto 0) := mAxisMaster.tKeep(MASTER_KEEP_WIDTH_C-1 downto 0);

      M_AXIS_TVALID <= mAxisMaster.tValid;
      M_AXIS_TDATA  <= tData;
      M_AXIS_TKEEP  <= tKeep;
      M_AXIS_TLAST  <= mAxisMaster.tLast;
      M_AXIS_TDEST  <= mAxisMaster.tDest(3 downto 0);
      M_AXIS_EOFE   <= ssiGetUserEofe(MASTER_AXI_CONFIG_C, mAxisMaster);
   end process mAxisComb;

   sAxisComb : process (S_AXIS_EOFE, S_AXIS_TDATA, S_AXIS_TDEST, S_AXIS_TKEEP,
                        S_AXIS_TLAST, S_AXIS_TVALID) is
      variable v : AxiStreamMasterType;
   begin
      v                                      := AXI_STREAM_MASTER_INIT_C;
      v.tValid                               := S_AXIS_TVALID;
      v.tData(SLAVE_DATA_WIDTH_C-1 downto 0) := S_AXIS_TDATA(SLAVE_DATA_WIDTH_C-1 downto 0);
      v.tKeep(SLAVE_KEEP_WIDTH_C-1 downto 0) := S_AXIS_TKEEP(SLAVE_KEEP_WIDTH_C-1 downto 0);
      v.tLast                                := S_AXIS_TLAST;
      v.tDest(3 downto 0)                    := S_AXIS_TDEST;
      ssiSetUserEofe(SLAVE_AXI_CONFIG_C, v, S_AXIS_EOFE);
      sAxisMaster                            <= v;
   end process sAxisComb;

   U_AxiStreamFifoV2 : entity surf.AxiStreamFifoV2
      generic map (
         TPD_G               => 1 ns,
         MEMORY_TYPE_G       => "distributed",
         GEN_SYNC_FIFO_G     => true,
         FIFO_ADDR_WIDTH_G   => 4,
         SLAVE_AXI_CONFIG_G  => SLAVE_AXI_CONFIG_C,
         MASTER_AXI_CONFIG_G => MASTER_AXI_CONFIG_C)
      port map (
         sAxisClk    => AXIS_ACLK,
         sAxisRst    => axisRst,
         sAxisMaster => sAxisMaster,
         sAxisSlave  => sAxisSlave,
         mAxisClk    => AXIS_ACLK,
         mAxisRst    => axisRst,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);

end architecture rtl;
