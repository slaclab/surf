-------------------------------------------------------------------------------
-- Title      : RSSI Protocol: https://confluence.slac.stanford.edu/x/1IyfD
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the RssiCore
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;
use surf.SsiPkg.all;
use surf.RssiPkg.all;

entity RssiCoreTb is

end RssiCoreTb;

architecture testbed of RssiCoreTb is

   constant CLK_PERIOD_C : time := 10 ns;  -- 1 us makes it easy to count clock cycles in sim GUI
   constant TPD_G        : time := CLK_PERIOD_C/4;

   constant AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(4);

   constant AXIL_CONFIG_C : AxiLiteCrossbarMasterConfigArray(0 downto 0) := (
      0               => (
         baseAddr     => x"0000_0000",
         addrBits     => 32,
         connectivity => x"FFFF"));

   constant MAX_CNT_C       : positive := (4096/4);  -- Up to 4kB writes and 4B per word
   constant SWEEP_C         : boolean  := true;
   constant APP_ILEAVE_EN_C : boolean  := true;

   type StateType is (
      IDLE_S,
      HDR0_S,
      HDR1_S,
      HDR2_S,
      HDR3_S,
      HDR4_S,
      PAYLOAD_S);

   type RegType is record
      tid      : slv(31 downto 0);
      cnt      : slv(31 downto 0);
      sweep    : slv(31 downto 0);
      txMaster : AxiStreamMasterType;
      state    : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      tid      => x"0000_0000",
      cnt      => x"0000_0000",
      sweep    => x"0000_0000",
      txMaster => AXI_STREAM_MASTER_INIT_C,
      state    => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal clk : sl := '0';
   signal rst : sl := '0';

   constant NUM_XBAR_C : positive := 8;

   signal axilWriteMasters : AxiLiteWriteMasterArray(NUM_XBAR_C-1 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_XBAR_C-1 downto 0) := (others => AXI_LITE_WRITE_SLAVE_EMPTY_OK_C);
   signal axilReadMasters  : AxiLiteReadMasterArray(NUM_XBAR_C-1 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(NUM_XBAR_C-1 downto 0)  := (others => AXI_LITE_READ_SLAVE_EMPTY_OK_C);

   signal sSrpMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sSrpSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal mSrpMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mSrpSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

   signal tspMasters : AxiStreamMasterArray(1 downto 0);
   signal tspSlaves  : AxiStreamSlaveArray(1 downto 0);

   signal txMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal txSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal rxMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal rxSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

   signal statusReg : slv(6 downto 0);

begin

   ---------------------------
   -- Generate clock and reset
   ---------------------------
   U_ClkRst : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1 us)     -- Hold reset for this long)
      port map (
         clkP => clk,
         rst  => rst);

   ---------------------------
   -- AXI-Lite Crossbar Module
   ---------------------------
   GEN_VEC :
   for i in (NUM_XBAR_C-2) downto 0 generate
      U_XBAR : entity surf.AxiLiteCrossbar
         generic map (
            TPD_G              => TPD_G,
            NUM_SLAVE_SLOTS_G  => 1,
            NUM_MASTER_SLOTS_G => 1,
            MASTERS_CONFIG_G   => AXIL_CONFIG_C)
         port map (
            sAxiWriteMasters(0) => axilWriteMasters(i),
            sAxiWriteSlaves(0)  => axilWriteSlaves(i),
            sAxiReadMasters(0)  => axilReadMasters(i),
            sAxiReadSlaves(0)   => axilReadSlaves(i),
            mAxiWriteMasters(0) => axilWriteMasters(i+1),
            mAxiWriteSlaves(0)  => axilWriteSlaves(i+1),
            mAxiReadMasters(0)  => axilReadMasters(i+1),
            mAxiReadSlaves(0)   => axilReadSlaves(i+1),
            axiClk              => clk,
            axiClkRst           => rst);
   end generate GEN_VEC;

   ------------------
   -- SRPv3 End Point
   ------------------
   U_SRPv3 : entity surf.SrpV3AxiLite
      generic map (
         TPD_G               => TPD_G,
         SLAVE_READY_EN_G    => true,
         GEN_SYNC_FIFO_G     => true,
         AXI_STREAM_CONFIG_G => RSSI_AXIS_CONFIG_C)
      port map (
         -- Streaming Slave (Rx) Interface (sAxisClk domain)
         sAxisClk         => clk,
         sAxisRst         => rst,
         sAxisMaster      => sSrpMaster,
         sAxisSlave       => sSrpSlave,
         -- Streaming Master (Tx) Data Interface (mAxisClk domain)
         mAxisClk         => clk,
         mAxisRst         => rst,
         mAxisMaster      => mSrpMaster,
         mAxisSlave       => mSrpSlave,
         -- Master AXI-Lite Interface (axilClk domain)
         axilClk          => clk,
         axilRst          => rst,
         mAxilReadMaster  => axilReadMasters(0),
         mAxilReadSlave   => axilReadSlaves(0),
         mAxilWriteMaster => axilWriteMasters(0),
         mAxilWriteSlave  => axilWriteSlaves(0));

   --------------
   -- RSSI Server
   --------------
   U_RssiServer : entity surf.RssiCoreWrapper
      generic map (
         TPD_G             => TPD_G,
         SERVER_G          => true,     -- Server
         APP_ILEAVE_EN_G   => APP_ILEAVE_EN_C,
         APP_AXIS_CONFIG_G => (0 => RSSI_AXIS_CONFIG_C),
         TSP_AXIS_CONFIG_G => RSSI_AXIS_CONFIG_C)
      port map (
         clk_i                => clk,
         rst_i                => rst,
         openRq_i             => '1',
         -- Application Layer Interface
         sAppAxisMasters_i(0) => mSrpMaster,
         sAppAxisSlaves_o(0)  => mSrpSlave,
         mAppAxisMasters_o(0) => sSrpMaster,
         mAppAxisSlaves_i(0)  => sSrpSlave,
         -- Transport Layer Interface
         sTspAxisMaster_i     => tspMasters(0),
         sTspAxisSlave_o      => tspSlaves(0),
         mTspAxisMaster_o     => tspMasters(1),
         mTspAxisSlave_i      => tspSlaves(1));

   --------------
   -- RSSI Client
   --------------
   U_RssiClient : entity surf.RssiCoreWrapper
      generic map (
         TPD_G             => TPD_G,
         SERVER_G          => false,    -- Client
         APP_ILEAVE_EN_G   => APP_ILEAVE_EN_C,
         APP_AXIS_CONFIG_G => (0 => AXIS_CONFIG_C),
         TSP_AXIS_CONFIG_G => RSSI_AXIS_CONFIG_C)
      port map (
         clk_i                => clk,
         rst_i                => rst,
         openRq_i             => '1',
         statusReg_o          => statusReg,
         -- Application Layer Interface
         sAppAxisMasters_i(0) => txMaster,
         sAppAxisSlaves_o(0)  => txSlave,
         mAppAxisMasters_o(0) => rxMaster,
         mAppAxisSlaves_i(0)  => rxSlave,
         -- Transport Layer Interface
         sTspAxisMaster_i     => tspMasters(1),
         sTspAxisSlave_o      => tspSlaves(1),
         mTspAxisMaster_o     => tspMasters(0),
         mTspAxisSlave_i      => tspSlaves(0));

   comb : process (r, rst, statusReg, txSlave) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      if txSlave.tReady = '1' then
         v.txMaster.tValid := '0';
         v.txMaster.tLast  := '0';
         v.txMaster.tUser  := (others => '0');
      end if;

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check if ready to move data
            if (statusReg(0) = '1') then
               -- Next state
               v.state := HDR0_S;
            end if;
         ----------------------------------------------------------------------
         when HDR0_S =>
            -- Check if ready to move data
            if (v.txMaster.tValid = '0') then
               -- Move data
               v.txMaster.tValid             := '1';
               v.txMaster.tData(31 downto 0) := x"0000_0103";
               ssiSetUserSof(AXIS_CONFIG_C, v.txMaster, '1');
               -- Next state
               v.state                       := HDR1_S;
            end if;
         ----------------------------------------------------------------------
         when HDR1_S =>
            -- Check if ready to move data
            if (v.txMaster.tValid = '0') then
               -- Move data
               v.txMaster.tValid             := '1';
               v.txMaster.tData(31 downto 0) := r.tid;  -- Transaction ID
               -- Increment the counter
               v.tid                         := r.tid + 1;
               -- Next state
               v.state                       := HDR2_S;
            end if;
         ----------------------------------------------------------------------
         when HDR2_S =>
            -- Check if ready to move data
            if (v.txMaster.tValid = '0') then
               -- Move data
               v.txMaster.tValid             := '1';
               v.txMaster.tData(31 downto 0) := x"0000_0000";  -- Addr[31:0]
               -- Next state
               v.state                       := HDR3_S;
            end if;
         ----------------------------------------------------------------------
         when HDR3_S =>
            -- Check if ready to move data
            if (v.txMaster.tValid = '0') then
               -- Move data
               v.txMaster.tValid             := '1';
               v.txMaster.tData(31 downto 0) := x"0000_0000";  -- Addr[63:32]
               -- Next state
               v.state                       := HDR4_S;
            end if;
         ----------------------------------------------------------------------
         when HDR4_S =>
            -- Check if ready to move data
            if (v.txMaster.tValid = '0') then
               -- Move data
               v.txMaster.tValid := '1';
               -- Check for sweeping
               if (SWEEP_C) then
                  v.txMaster.tData(31 downto 0) := r.sweep(29 downto 0) & "11";  -- ReqSize[31:0] = varies
               else
                  v.txMaster.tData(31 downto 0) := x"0000_0FFF";  -- ReqSize[31:0] = 4kB
               end if;
               -- Next state
               v.state := PAYLOAD_S;
            end if;
         ----------------------------------------------------------------------
         when PAYLOAD_S =>
            -- Check if ready to move data
            if (v.txMaster.tValid = '0') then
               -- Move data
               v.txMaster.tValid             := '1';
               v.txMaster.tData(31 downto 0) := toSlv(4*conv_integer(r.cnt), 32);  -- Data = Address
               -- Increment the counter
               v.cnt                         := r.cnt + 1;
               -- Check for sweeping
               if (SWEEP_C) then
                  -- Check for last transfer
                  if (r.cnt = r.sweep) then
                     -- Reset the counter
                     v.cnt := x"0000_0000";
                     -- Check for max count
                     if (r.sweep = (MAX_CNT_C-1)) then
                        -- Reset the counter
                        v.sweep := x"0000_0000";
                     else
                        -- Increment the counter
                        v.sweep := r.sweep + 1;
                     end if;
                     -- Terminate the frame
                     v.txMaster.tLast := '1';
                     -- Next state
                     v.state          := HDR0_S;
                  end if;
               else
                  -- Check for last transfer
                  if (r.cnt = (MAX_CNT_C-1)) then
                     -- Reset the counter
                     v.cnt            := x"0000_0000";
                     -- Terminate the frame
                     v.txMaster.tLast := '1';
                     -- Next state
                     v.state          := HDR0_S;
                  end if;
               end if;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Registered Outputs
      txMaster <= r.txMaster;

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end testbed;
