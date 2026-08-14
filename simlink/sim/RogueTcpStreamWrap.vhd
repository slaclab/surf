-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Reusable Rogue TCP Stream simulation interface
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
      TPD_G                    : time                                              := 1 ns;
      PORT_NUM_G               : natural range 1024 to 49151                       := 9000;
      SSI_EN_G                 : boolean                                           := true;
      CHAN_COUNT_G             : natural range 0 to 256                            := 1;
      CHAN_MASK_G              : slv(7 downto 0)                                   := x"00";  -- Overrides CHAN_COUNT_G if non-zero
      TDEST_MASK_G             : slv(7 downto 0)                                   := x"00";  -- Sets output TDEST when CHAN_COUNT_G=1
      AXIS_CONFIG_G            : AxiStreamConfigType;
      AXIS_CLK_FREQ_G          : real                                              := 0.0;  -- Units of Hz; required when pacing is enabled
      S_AXIS_PAYLOAD_RATE_G    : real                                              := 0.0;  -- HDL-to-software payload bits/s; zero bypasses
      M_AXIS_PAYLOAD_RATE_G    : real                                              := 0.0);  -- Software-to-HDL payload bits/s; zero bypasses
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

   -- The raw SimLink boundary uses a normal per-byte TKEEP bitmap and eight
   -- TUSER bits per byte.  Its data width deliberately matches AXIS_CONFIG_G,
   -- so the AxiStreamResize instances below only adapt metadata representation;
   -- they do not resize or throttle the payload data path.
   constant INT_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => AXIS_CONFIG_G.TDATA_BYTES_C,
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_NORMAL_C,
      TUSER_BITS_C  => 8,
      TUSER_MODE_C  => TUSER_NORMAL_C);

   -- Use CHAN_MASK_G to determine CHAN_COUNT_C if non-zero, else use CHAN_COUNT_G
   constant CHAN_COUNT_C : integer := ite(CHAN_MASK_G = X"00", CHAN_COUNT_G,
                                          2**conv_integer(onesCount(CHAN_MASK_G)));


   -- Generate a correct channel mask if using CHAN_COUNT_G
   constant CHAN_MASK_C : slv(7 downto 0) := ite(CHAN_MASK_G /= X"00", CHAN_MASK_G,
                                                 toSlv(2**log2(CHAN_COUNT_G)-1, 8));

   function channelMap return Slv8Array
   is
      variable vec  : slv(7 downto 0);
      variable chan : integer := 0;
      variable ret  : Slv8Array(0 to CHAN_COUNT_C-1);
   begin
      chan := 0;
      if (CHAN_COUNT_C = 1) then
         ret(0) := (others => '0');
         return ret;
      end if;

      -- CHAN_MASK_C spans ceil(log2(CHAN_COUNT_C)) bits, so it has
      -- 2**ceil(log2(CHAN_COUNT_C)) subset codes -- >= CHAN_COUNT_C, and
      -- strictly greater for non-power-of-2 counts.  Take only the first
      -- CHAN_COUNT_C matches so we never write past ret's bounds.
      for i in 0 to 255 loop
         vec := toSlv(i, 8);
         if (((CHAN_MASK_C nor vec) or CHAN_MASK_C) = X"FF") then
            if (chan < CHAN_COUNT_C) then
               ret(chan) := vec;
               chan      := chan + 1;
            end if;
         end if;
      end loop;
      return ret;
   end function channelMap;

   constant CHAN_MAP_C : Slv8Array(0 to CHAN_COUNT_C-1) := channelMap;


   -- Local Signals
   signal dmMasters : AxiStreamMasterArray(CHAN_COUNT_C-1 downto 0);
   signal dmSlaves  : AxiStreamSlaveArray(CHAN_COUNT_C-1 downto 0);
   signal ibMasters : AxiStreamMasterArray(CHAN_COUNT_C-1 downto 0);
   signal ibSlaves  : AxiStreamSlaveArray(CHAN_COUNT_C-1 downto 0);
   signal obMasters : AxiStreamMasterArray(CHAN_COUNT_C-1 downto 0);
   signal obSlaves  : AxiStreamSlaveArray(CHAN_COUNT_C-1 downto 0);
   signal mxMasters : AxiStreamMasterArray(CHAN_COUNT_C-1 downto 0);
   signal mxSlaves  : AxiStreamSlaveArray(CHAN_COUNT_C-1 downto 0);

   signal sPaceMaster : AxiStreamMasterType;
   signal sPaceSlave  : AxiStreamSlaveType;
   signal mPaceMaster : AxiStreamMasterType;
   signal mPaceSlave  : AxiStreamSlaveType;

   signal portMap : Slv16Array(CHAN_COUNT_C-1 downto 0);

begin

   -- CHAN_COUNT_G = 0 makes every channel array a null range and CHAN_MASK_C
   -- inconsistent; the derived-mask path also requires at least one channel.
   assert (CHAN_MASK_G /= X"00") or (CHAN_COUNT_G >= 1)
      report "RogueTcpStreamWrap: CHAN_COUNT_G must be >= 1 when CHAN_MASK_G is unset"
      severity failure;

   -- Pace before the demultiplexer so all S_AXIS channels share one aggregate
   -- payload-bandwidth budget.
   U_SAxisPacer : entity surf.RogueTcpStreamPacer
      generic map (
         TPD_G           => TPD_G,
         AXIS_CONFIG_G   => AXIS_CONFIG_G,
         AXIS_CLK_FREQ_G => AXIS_CLK_FREQ_G,
         PAYLOAD_RATE_G  => S_AXIS_PAYLOAD_RATE_G)
      port map (
         axisClk     => axisClk,      -- [in]
         axisRst     => axisRst,      -- [in]
         sAxisMaster => sAxisMaster,  -- [in]
         sAxisSlave  => sAxisSlave,   -- [out]
         mAxisMaster => sPaceMaster,  -- [out]
         mAxisSlave  => sPaceSlave);  -- [in]

   PORT_MAP : for i in portMap'range generate
      portMap(i) <= toSlv(PORT_NUM_G + (conv_integer(CHAN_MAP_C(i))*2), 16);
   end generate PORT_MAP;

   ----------------
   -- Inbound DEMUX
   ----------------
   GEN_DEMUX : if (CHAN_COUNT_C /= 1) generate
      U_DeMux : entity surf.AxiStreamDeMux
         generic map (
            TPD_G          => TPD_G,
            NUM_MASTERS_G  => CHAN_COUNT_C,
            MODE_G         => "ROUTED",
            TDEST_ROUTES_G => CHAN_MAP_C)
         port map (
            -- Clock and reset
            axisClk      => axisClk,
            axisRst      => axisRst,
            sAxisMaster  => sPaceMaster,
            sAxisSlave   => sPaceSlave,
            mAxisMasters => dmMasters,
            mAxisSlaves  => dmSlaves);
   end generate;

   BYP_DEMUX : if (CHAN_COUNT_C = 1) generate
      dmMasters(0) <= sPaceMaster;
      sPaceSlave   <= dmSlaves(0);
   end generate;

   -- Channels
   GEN_CHAN : for i in 0 to CHAN_COUNT_C-1 generate
      -------------------------------------------------------------------------
      -- Inbound Configuration Adapter
      --
      -- Although both sides have the same data width, retain AxiStreamResize
      -- to normalize configurations such as TUSER_FIRST_LAST_C and
      -- TKEEP_COUNT_C for the raw SimLink boundary.
      -------------------------------------------------------------------------
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
         generic map (
            TDATA_BYTES_G => AXIS_CONFIG_G.TDATA_BYTES_C)
         port map(
            clock   => axisClk,                                                     -- [in]
            reset   => axisRst,                                                     -- [in]
            portNum => portMap(i),                                                  -- [in]
            ssi     => toSl(SSI_EN_G),                                              -- [in]
            obValid => obMasters(i).tValid,                                         -- [out]
            obReady => obSlaves(i).tReady,                                          -- [in]
            obData  => obMasters(i).tData((AXIS_CONFIG_G.TDATA_BYTES_C*8)-1 downto 0), -- [out]
            obUser  => obMasters(i).tUser((AXIS_CONFIG_G.TDATA_BYTES_C*8)-1 downto 0), -- [out]
            obKeep  => obMasters(i).tKeep(AXIS_CONFIG_G.TDATA_BYTES_C-1 downto 0),   -- [out]
            obLast  => obMasters(i).tLast,                                          -- [out]
            ibValid => ibMasters(i).tValid,                                         -- [in]
            ibReady => ibSlaves(i).tReady,                                          -- [out]
            ibData  => ibMasters(i).tData((AXIS_CONFIG_G.TDATA_BYTES_C*8)-1 downto 0), -- [in]
            ibUser  => ibMasters(i).tUser((AXIS_CONFIG_G.TDATA_BYTES_C*8)-1 downto 0), -- [in]
            ibKeep  => ibMasters(i).tKeep(AXIS_CONFIG_G.TDATA_BYTES_C-1 downto 0),   -- [in]
            ibLast  => ibMasters(i).tLast);                                         -- [in]

      obMasters(i).tStrb <= (others                                          => '1');
      obMasters(i).tDest <= TDEST_MASK_G when(CHAN_COUNT_C = 1) else (others => '0');
      obMasters(i).tId   <= (others                                          => '0');

      obMasters(i).tKeep(AXI_STREAM_MAX_TKEEP_WIDTH_C-1 downto AXIS_CONFIG_G.TDATA_BYTES_C)   <= (others => '0');
      obMasters(i).tData(AXI_STREAM_MAX_TDATA_WIDTH_C-1 downto AXIS_CONFIG_G.TDATA_BYTES_C*8) <= (others => '0');
      obMasters(i).tUser(AXI_STREAM_MAX_TDATA_WIDTH_C-1 downto AXIS_CONFIG_G.TDATA_BYTES_C*8) <= (others => '0');

      -------------------------------------------------------------------------
      -- Outbound Configuration Adapter
      --
      -- Convert the normalized SimLink metadata back to AXIS_CONFIG_G without
      -- changing the data width or limiting the simulated link bandwidth.
      -------------------------------------------------------------------------
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
   GEN_MUX : if (CHAN_COUNT_C /= 1) generate
      U_Mux : entity surf.AxiStreamMux
         generic map (
            TPD_G          => TPD_G,
            NUM_SLAVES_G   => CHAN_COUNT_C,
            MODE_G         => "ROUTED",
            TDEST_ROUTES_G => CHAN_MAP_C)
         port map (
            axisClk      => axisClk,
            axisRst      => axisRst,
            sAxisMasters => mxMasters,
            sAxisSlaves  => mxSlaves,
            mAxisMaster  => mPaceMaster,
            mAxisSlave   => mPaceSlave);
   end generate;

   BYP_MUX : if (CHAN_COUNT_C = 1) generate
      mPaceMaster <= mxMasters(0);
      mxSlaves(0) <= mPaceSlave;
   end generate;

   -- Pace after the multiplexer so all M_AXIS channels share one aggregate
   -- payload-bandwidth budget.
   U_MAxisPacer : entity surf.RogueTcpStreamPacer
      generic map (
         TPD_G           => TPD_G,
         AXIS_CONFIG_G   => AXIS_CONFIG_G,
         AXIS_CLK_FREQ_G => AXIS_CLK_FREQ_G,
         PAYLOAD_RATE_G  => M_AXIS_PAYLOAD_RATE_G)
      port map (
         axisClk     => axisClk,      -- [in]
         axisRst     => axisRst,      -- [in]
         sAxisMaster => mPaceMaster,  -- [in]
         sAxisSlave  => mPaceSlave,   -- [out]
         mAxisMaster => mAxisMaster,  -- [out]
         mAxisSlave  => mAxisSlave);  -- [in]

end RogueTcpStreamWrap;
