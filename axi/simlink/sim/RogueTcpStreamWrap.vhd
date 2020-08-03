-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper for Rogue Stream Module
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;

entity RogueTcpStreamWrap is
   generic (
      TPD_G         : time                        := 1 ns;
      PORT_NUM_G    : natural range 1024 to 49151 := 9000;
      SSI_EN_G      : boolean                     := true;
      CHAN_COUNT_G  : positive range 1 to 256     := 1;
      AXIS_CONFIG_G : AxiStreamConfigType);
   port (
      -- Clock and Reset
      axisClk     : in  sl;
      axisRst     : in  sl;
      -- Slave Port
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;
      -- Master Port
      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType);
end RogueTcpStreamWrap;

-- Define architecture
architecture RogueTcpStreamWrap of RogueTcpStreamWrap is

   -- Internal configuration
   constant INT_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 8,
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_NORMAL_C,
      TUSER_BITS_C  => 8,
      TUSER_MODE_C  => TUSER_NORMAL_C);

   -- Local Signals
   signal dmMasters : AxiStreamMasterArray(CHAN_COUNT_G-1 downto 0);
   signal dmSlaves  : AxiStreamSlaveArray(CHAN_COUNT_G-1 downto 0);
   signal ibMasters : AxiStreamMasterArray(CHAN_COUNT_G-1 downto 0);
   signal ibSlaves  : AxiStreamSlaveArray(CHAN_COUNT_G-1 downto 0);
   signal obMasters : AxiStreamMasterArray(CHAN_COUNT_G-1 downto 0);
   signal obSlaves  : AxiStreamSlaveArray(CHAN_COUNT_G-1 downto 0);
   signal mxMasters : AxiStreamMasterArray(CHAN_COUNT_G-1 downto 0);
   signal mxSlaves  : AxiStreamSlaveArray(CHAN_COUNT_G-1 downto 0);

begin

   assert (PORT_NUM_G + 2*(CHAN_COUNT_G-1) <= 65535)
      report "PORT_NUM_G + 2*(CHAN_COUNT_G-1) must less than or equal to 65535" severity failure;

   ----------------
   -- Inbound DEMUX
   ----------------
   GEN_DEMUX : if (CHAN_COUNT_G /= 1) generate
      U_DeMux : entity surf.AxiStreamDeMux
         generic map (
            TPD_G         => TPD_G,
            NUM_MASTERS_G => CHAN_COUNT_G)
         port map (
            -- Clock and reset
            axisClk      => axisClk,
            axisRst      => axisRst,
            sAxisMaster  => sAxisMaster,
            sAxisSlave   => sAxisSlave,
            mAxisMasters => dmMasters,
            mAxisSlaves  => dmSlaves);
   end generate;

   BYP_DEMUX : if (CHAN_COUNT_G = 1) generate
      dmMasters(0) <= sAxisMaster;
      sAxisSlave   <= dmSlaves(0);
   end generate;

   -- Channels
   U_ChanGen : for i in 0 to CHAN_COUNT_G-1 generate

      ------------------
      -- Inbound Resizer
      ------------------
      U_Ib_Resize : entity surf.AxiStreamResize
         generic map (
            -- General Configurations
            TPD_G               => TPD_G,
            -- AXI Stream Port Configurations
            SLAVE_AXI_CONFIG_G  => AXIS_CONFIG_G,
            MASTER_AXI_CONFIG_G => INT_CONFIG_C)
         port map (
            -- Clock and reset
            axisClk     => axisClk,
            axisRst     => axisRst,
            -- Slave Port
            sAxisMaster => dmMasters(i),
            sAxisSlave  => dmSlaves(i),
            -- Master Port
            mAxisMaster => ibMasters(i),
            mAxisSlave  => ibSlaves(i));

      ------------------------------------
      -- Sim Core
      ------------------------------------
      U_RogueTcpStream : entity surf.RogueTcpStream
         port map(
            clock      => axisClk,
            reset      => axisRst,
            portNum    => toSlv(PORT_NUM_G + i*2, 16),
            ssi        => toSl(SSI_EN_G),
            obValid    => obMasters(i).tValid,
            obReady    => obSlaves(i).tReady,
            obDataLow  => obMasters(i).tData(31 downto 0),
            obDataHigh => obMasters(i).tData(63 downto 32),
            obUserLow  => obMasters(i).tUser(31 downto 0),
            obUserHigh => obMasters(i).tUser(63 downto 32),
            obKeep     => obMasters(i).tKeep(7 downto 0),
            obLast     => obMasters(i).tLast,
            ibValid    => ibMasters(i).tValid,
            ibReady    => ibSlaves(i).tReady,
            ibDataLow  => ibMasters(i).tData(31 downto 0),
            ibDataHigh => ibMasters(i).tData(63 downto 32),
            ibUserLow  => ibMasters(i).tUser(31 downto 0),
            ibUserHigh => ibMasters(i).tUser(63 downto 32),
            ibKeep     => ibMasters(i).tKeep(7 downto 0),
            ibLast     => ibMasters(i).tLast);

      obMasters(i).tStrb <= (others => '1');
      obMasters(i).tDest <= (others => '0');
      obMasters(i).tId   <= (others => '0');

      obMasters(i).tKeep(AXI_STREAM_MAX_TKEEP_WIDTH_C-1 downto 8)  <= (others => '0');
      obMasters(i).tData(AXI_STREAM_MAX_TDATA_WIDTH_C-1 downto 64) <= (others => '0');
      obMasters(i).tUser(AXI_STREAM_MAX_TDATA_WIDTH_C-1 downto 64) <= (others => '0');

      -------------------
      -- Outbound Resizer
      -------------------
      U_Ob_Resize : entity surf.AxiStreamResize
         generic map (
            -- General Configurations
            TPD_G               => TPD_G,
            -- AXI Stream Port Configurations
            SLAVE_AXI_CONFIG_G  => INT_CONFIG_C,
            MASTER_AXI_CONFIG_G => AXIS_CONFIG_G)
         port map (
            -- Clock and reset
            axisClk     => axisClk,
            axisRst     => axisRst,
            -- Slave Port
            sAxisMaster => obMasters(i),
            sAxisSlave  => obSlaves(i),
            -- Master Port
            mAxisMaster => mxMasters(i),
            mAxisSlave  => mxSlaves(i));

   end generate;

   ---------------
   -- Outbound MUX
   ---------------
   GEN_MUX : if (CHAN_COUNT_G /= 1) generate
      U_Mux : entity surf.AxiStreamMux
         generic map (
            TPD_G        => TPD_G,
            NUM_SLAVES_G => CHAN_COUNT_G)
         port map (
            axisClk      => axisClk,
            axisRst      => axisRst,
            sAxisMasters => mxMasters,
            sAxisSlaves  => mxSlaves,
            mAxisMaster  => mAxisMaster,
            mAxisSlave   => mAxisSlave);
   end generate;

   BYP_MUX : if (CHAN_COUNT_G = 1) generate
      mAxisMaster <= mxMasters(0);
      mxSlaves(0) <= mAxisSlave;
   end generate;

end RogueTcpStreamWrap;
