-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for surf.AxiStreamBatcher
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

entity AxiStreamBatcherWrapper is
   generic (
      TPD_G                        : time                  := 1 ns;
      VERSION_G                    : positive range 1 to 2 := 2;
      DATA_BYTES_G                 : positive range 2 to 8 := 8;
      MAX_NUMBER_SUB_FRAMES_G      : positive              := 32;
      SUPER_FRAME_BYTE_THRESHOLD_G : natural               := 8192;
      MAX_CLK_GAP_G                : natural               := 256;
      INPUT_PIPE_STAGES_G          : natural               := 0;
      OUTPUT_PIPE_STAGES_G         : natural               := 1);
   port (
      axisClk                 : in  sl;
      axisRst                 : in  sl;
      forceTerm               : in  sl;
      superFrameByteThreshold : in  slv(31 downto 0);
      maxSubFrames            : in  slv(15 downto 0);
      maxClkGap               : in  slv(31 downto 0);
      idle                    : out sl;
      S_AXIS_TVALID           : in  sl;
      S_AXIS_TDATA            : in  slv(8*DATA_BYTES_G-1 downto 0);
      S_AXIS_TKEEP            : in  slv(DATA_BYTES_G-1 downto 0);
      S_AXIS_TLAST            : in  sl;
      S_AXIS_TDEST            : in  slv(7 downto 0);
      S_AXIS_TID              : in  slv(7 downto 0);
      S_AXIS_TUSER            : in  slv(8*DATA_BYTES_G-1 downto 0);
      S_AXIS_TREADY           : out sl;
      M_AXIS_TVALID           : out sl;
      M_AXIS_TDATA            : out slv(8*DATA_BYTES_G-1 downto 0);
      M_AXIS_TKEEP            : out slv(DATA_BYTES_G-1 downto 0);
      M_AXIS_TLAST            : out sl;
      M_AXIS_TDEST            : out slv(7 downto 0);
      M_AXIS_TID              : out slv(7 downto 0);
      M_AXIS_TUSER            : out slv(8*DATA_BYTES_G-1 downto 0);
      M_AXIS_TREADY           : in  sl);
end entity AxiStreamBatcherWrapper;

architecture rtl of AxiStreamBatcherWrapper is

   constant AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => DATA_BYTES_G,
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_NORMAL_C,
      TUSER_BITS_C  => 8,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

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
      vS                                      := AXI_STREAM_MASTER_INIT_C;
      vS.tValid                              := S_AXIS_TVALID;
      vS.tData                               := (others => '0');
      vS.tData(8*DATA_BYTES_G-1 downto 0)    := S_AXIS_TDATA;
      vS.tStrb                               := (others => '0');
      vS.tStrb(DATA_BYTES_G-1 downto 0)      := S_AXIS_TKEEP;
      vS.tKeep                               := (others => '0');
      vS.tKeep(DATA_BYTES_G-1 downto 0)      := S_AXIS_TKEEP;
      vS.tLast                               := S_AXIS_TLAST;
      vS.tDest                               := (others => '0');
      vS.tDest(7 downto 0)                   := S_AXIS_TDEST;
      vS.tId                                 := (others => '0');
      vS.tId(7 downto 0)                     := S_AXIS_TID;
      vS.tUser                               := (others => '0');
      vS.tUser(8*DATA_BYTES_G-1 downto 0)    := S_AXIS_TUSER;

      vM        := AXI_STREAM_SLAVE_INIT_C;
      vM.tReady := M_AXIS_TREADY;

      sAxisMaster <= vS;
      mAxisSlave  <= vM;

      S_AXIS_TREADY <= sAxisSlave.tReady;
      M_AXIS_TVALID <= mAxisMaster.tValid;
      M_AXIS_TDATA  <= mAxisMaster.tData(8*DATA_BYTES_G-1 downto 0);
      M_AXIS_TKEEP  <= mAxisMaster.tKeep(DATA_BYTES_G-1 downto 0);
      M_AXIS_TLAST  <= mAxisMaster.tLast;
      M_AXIS_TDEST  <= mAxisMaster.tDest(7 downto 0);
      M_AXIS_TID    <= mAxisMaster.tId(7 downto 0);
      M_AXIS_TUSER  <= mAxisMaster.tUser(8*DATA_BYTES_G-1 downto 0);
   end process comb;

   ---------------------
   -- DUT instancing  --
   ---------------------
   U_DUT : entity surf.AxiStreamBatcher
      generic map (
         TPD_G                        => TPD_G,
         VERSION_G                    => VERSION_G,
         MAX_NUMBER_SUB_FRAMES_G      => MAX_NUMBER_SUB_FRAMES_G,
         SUPER_FRAME_BYTE_THRESHOLD_G => SUPER_FRAME_BYTE_THRESHOLD_G,
         MAX_CLK_GAP_G                => MAX_CLK_GAP_G,
         AXIS_CONFIG_G                => AXIS_CONFIG_C,
         INPUT_PIPE_STAGES_G          => INPUT_PIPE_STAGES_G,
         OUTPUT_PIPE_STAGES_G         => OUTPUT_PIPE_STAGES_G)
      port map (
         axisClk                 => axisClk,                    -- [in]
         axisRst                 => axisRst,                    -- [in]
         forceTerm               => forceTerm,                  -- [in]
         superFrameByteThreshold => superFrameByteThreshold,    -- [in]
         maxSubFrames            => maxSubFrames,               -- [in]
         maxClkGap               => maxClkGap,                  -- [in]
         idle                    => idle,                       -- [out]
         sAxisMaster             => sAxisMaster,                -- [in]
         sAxisSlave              => sAxisSlave,                 -- [out]
         mAxisMaster             => mAxisMaster,                -- [out]
         mAxisSlave              => mAxisSlave);                -- [in]

end architecture rtl;
