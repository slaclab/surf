-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation testbed for SrpV3AxiLite
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
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

library ruckus;
use ruckus.BuildInfoPkg.all;

entity SrpV3AxiLiteTb is

end entity SrpV3AxiLiteTb;

architecture tb of SrpV3AxiLiteTb is

   constant GET_BUILD_INFO_C : BuildInfoRetType := toBuildInfo(BUILD_INFO_C);
   constant MOD_BUILD_INFO_C : BuildInfoRetType := (
      buildString => GET_BUILD_INFO_C.buildString,
      fwVersion   => x"1234_5678",      -- force FW version
      gitHash     => x"1111_2222_3333_4444_5555_6666_7777_8888_9999_AAAA");  -- Force githash
   constant SIM_BUILD_INFO_C : slv(2239 downto 0) := toSlv(MOD_BUILD_INFO_C);

   constant CLK_PERIOD_C : time := 10 ns;
   constant TPD_G        : time := CLK_PERIOD_C/4;

   constant MAX_TID_C : natural := 3;

   constant AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(32);

   constant NUM_AXIL_MASTERS_C : natural := 1;

   constant VERSION_INDEX_C : natural := 0;

   constant AXIL_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXIL_MASTERS_C-1 downto 0) := genAxiLiteConfig(NUM_AXIL_MASTERS_C, x"0000_0000", 16, 12);

   type StateType is (
      REQ_S,
      RESP_S);

   type RegType is record
      tid         : slv(31 downto 0);
      sAxisMaster : AxiStreamMasterType;
      mAxisSlave  : AxiStreamSlaveType;
      state       : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      tid         => (others => '0'),
      sAxisMaster => AXI_STREAM_MASTER_INIT_C,
      mAxisSlave  => AXI_STREAM_SLAVE_INIT_C,
      state       => REQ_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal clk : sl := '0';
   signal rst : sl := '1';

   signal axilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_EMPTY_DECERR_C;
   signal axilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_EMPTY_DECERR_C;

   signal axilWriteMasters : AxiLiteWriteMasterArray(NUM_AXIL_MASTERS_C-1 downto 0) := (others => AXI_LITE_WRITE_MASTER_INIT_C);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0)  := (others => AXI_LITE_WRITE_SLAVE_EMPTY_DECERR_C);
   signal axilReadMasters  : AxiLiteReadMasterArray(NUM_AXIL_MASTERS_C-1 downto 0)  := (others => AXI_LITE_READ_MASTER_INIT_C);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0)   := (others => AXI_LITE_READ_SLAVE_EMPTY_DECERR_C);

   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

begin

   ---------------------------
   -- Generate clock and reset
   ---------------------------
   U_ClkRst : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1000 ns)  -- Hold reset for this long)
      port map (
         clkP => clk,
         rst  => rst);

   ----------------------
   -- Module Being Tested
   ----------------------
   U_SRPv3 : entity surf.SrpV3AxiLite
      generic map (
         TPD_G               => TPD_G,
         SLAVE_READY_EN_G    => true,
         GEN_SYNC_FIFO_G     => true,
         AXI_STREAM_CONFIG_G => AXIS_CONFIG_C)
      port map (
         -- AXIS Slave Interface (sAxisClk domain)
         sAxisClk         => clk,
         sAxisRst         => rst,
         sAxisMaster      => sAxisMaster,
         sAxisSlave       => sAxisSlave,
         -- AXIS Master Interface (mAxisClk domain)
         mAxisClk         => clk,
         mAxisRst         => rst,
         mAxisMaster      => mAxisMaster,
         mAxisSlave       => mAxisSlave,
         -- Master AXI-Lite Interface (axilClk domain)
         axilClk          => clk,
         axilRst          => rst,
         mAxilReadMaster  => axilReadMaster,
         mAxilReadSlave   => axilReadSlave,
         mAxilWriteMaster => axilWriteMaster,
         mAxilWriteSlave  => axilWriteSlave);

   ---------------------------
   -- AXI-Lite Crossbar Module
   ---------------------------
   U_XBAR : entity surf.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXIL_MASTERS_C,
         MASTERS_CONFIG_G   => AXIL_CONFIG_C)
      port map (
         axiClk              => clk,
         axiClkRst           => rst,
         sAxiWriteMasters(0) => axilWriteMaster,
         sAxiWriteSlaves(0)  => axilWriteSlave,
         sAxiReadMasters(0)  => axilReadMaster,
         sAxiReadSlaves(0)   => axilReadSlave,
         mAxiWriteMasters    => axilWriteMasters,
         mAxiWriteSlaves     => axilWriteSlaves,
         mAxiReadMasters     => axilReadMasters,
         mAxiReadSlaves      => axilReadSlaves);

   ---------------------------
   -- AXI-Lite: Version Module
   ---------------------------
   U_AxiVersion : entity surf.AxiVersion
      generic map (
         TPD_G        => TPD_G,
         BUILD_INFO_G => SIM_BUILD_INFO_C)
      port map (
         axiClk         => clk,
         axiRst         => rst,
         axiReadMaster  => axilReadMasters(VERSION_INDEX_C),
         axiReadSlave   => axilReadSlaves(VERSION_INDEX_C),
         axiWriteMaster => axilWriteMasters(VERSION_INDEX_C),
         axiWriteSlave  => axilWriteSlaves(VERSION_INDEX_C));

   comb : process (mAxisMaster, r, rst, sAxisSlave) is
      variable v          : RegType;
      variable cntPattern : slv(63 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- AXI stream Flow control
      v.mAxisSlave.tReady := '0';
      if (sAxisSlave.tReady = '1') then
         v.sAxisMaster.tValid := '0';
      end if;

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when REQ_S =>
            -- Check if ready to move data
            if (v.sAxisMaster.tValid = '0') then

               -- Send 1 word frame
               v.sAxisMaster.tValid := '1';
               v.sAxisMaster.tLast  := '1';
               v.sAxisMaster.tKeep  := resize(x"000F_FFFF", AXI_STREAM_MAX_TKEEP_WIDTH_C);
               ssiSetUserSof(AXIS_CONFIG_C, v.sAxisMaster, '1');

               -- Format the frame
               v.sAxisMaster.tData((0*32)+31 downto (0*32)) := x"0000_0003";
               v.sAxisMaster.tData((1*32)+31 downto (1*32)) := r.tid;
               v.sAxisMaster.tData((2*32)+31 downto (2*32)) := (others => '0');
               v.sAxisMaster.tData((3*32)+31 downto (3*32)) := (others => '0');
               v.sAxisMaster.tData((4*32)+31 downto (4*32)) := x"0000_0007";

               -- Toggle between AxiVersion.FwVersion and unmapped error response
               v.sAxisMaster.tData(64+16) := r.tid(0);

               -- Check for last TID
               if r.tid = MAX_TID_C then
                  -- Preset the value
                  v.tid   := (others => '0');
                  -- Next State
                  v.state := RESP_S;
               else
                  -- Increment the counter
                  v.tid := r.tid + 1;
               end if;

            end if;
         ----------------------------------------------------------------------
         when RESP_S =>
            -- Check for response
            if (mAxisMaster.tValid = '1') then

               -- Accept the data
               v.mAxisSlave.tReady := '1';

            end if;
      ----------------------------------------------------------------------
      end case;

      -- Outputs
      mAxisSlave  <= v.mAxisSlave;
      sAxisMaster <= r.sAxisMaster;

      -- Synchronous Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;


   end process comb;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture tb;
