-------------------------------------------------------------------------------
-- File       : SrpV3AxiLiteTb.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation testbed for AxiLiteSrpV0
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

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.EthMacPkg.all;
entity SrpV3AxiLiteTb is

end entity SrpV3AxiLiteTb;

architecture tb of SrpV3AxiLiteTb is

   constant ETH_AXIS_CONFIG_C  : AxiStreamConfigType              := ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 8);  -- Use 8 tDest bits
   constant TIMEOUT_C          : real                             := 1.0E-3;  -- In units of seconds   
   constant WINDOW_ADDR_SIZE_C : positive                         := 3;
   constant MAX_CUM_ACK_CNT_C  : positive                         := WINDOW_ADDR_SIZE_C;
   constant MAX_RETRANS_CNT_C  : positive                         := ite((WINDOW_ADDR_SIZE_C > 1), WINDOW_ADDR_SIZE_C-1, 1);
   constant AXIS_CONFIG_C      : AxiStreamConfigArray(0 downto 0) := (others => ETH_AXIS_CONFIG_C);

   constant CLK_PERIOD_C : time := 4 ns;
   constant TPD_G        : time := 1 ns;

   type StateType is (
      A_S,
      B_S,
      C_S);

   type RegType is record
      reqSize     : slv(11 downto 0);
      cnt         : slv(7 downto 0);
      tid         : slv(31 downto 0);
      addr        : slv(31 downto 0);
      sAxisMaster : AxiStreamMasterType;
      mAxisSlave  : AxiStreamSlaveType;
      state       : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      reqSize     => x"003",
      cnt         => (others => '0'),
      tid         => (others => '0'),
      addr        => (others => '0'),
      sAxisMaster => AXI_STREAM_MASTER_INIT_C,
      mAxisSlave  => AXI_STREAM_SLAVE_INIT_C,
      state       => A_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal clk : sl := '0';
   signal rst : sl := '0';

   signal debug : slv(1 downto 0) := (others => '0');

   signal axilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_EMPTY_OK_C;
   signal axilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_EMPTY_OK_C;

   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

   signal rssiObMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal rssiObSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal rssiIbMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal rssiIbSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

   signal sTspMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sTspSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal mTspMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mTspSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;


begin

   debug(0) <= '1' when (sAxisMaster.tData(63 downto 0) = x"0000_0138_0000_0003")  else '0';
   debug(1) <= '1' when (rssiObMaster.tData(63 downto 0) = x"0000_0138_0000_0003") else '0';

   -----------------------------
   -- Generate clocks and resets
   -----------------------------
   U_ClkRst0 : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,     -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1000 ns)  -- Hold reset for this long)
      port map (
         clkP => clk,
         rst  => rst);


   U_SRPv3 : entity work.SrpV3AxiLite
      generic map (
         TPD_G               => TPD_G,
         SLAVE_READY_EN_G    => true,
         GEN_SYNC_FIFO_G     => true,
         AXI_STREAM_CONFIG_G => ETH_AXIS_CONFIG_C)
      port map (
         -- AXIS Slave Interface (sAxisClk domain)
         sAxisClk         => clk,
         sAxisRst         => rst,
         sAxisMaster      => rssiObMaster,
         sAxisSlave       => rssiObSlave,
         -- AXIS Master Interface (mAxisClk domain) 
         mAxisClk         => clk,
         mAxisRst         => rst,
         mAxisMaster      => rssiIbMaster,
         mAxisSlave       => rssiIbSlave,
         -- Master AXI-Lite Interface (axilClk domain)
         axilClk          => clk,
         axilRst          => rst,
         mAxilReadMaster  => axilReadMaster,
         mAxilReadSlave   => axilReadSlave,
         mAxilWriteMaster => axilWriteMaster,
         mAxilWriteSlave  => axilWriteSlave);

   U_RssiServer : entity work.RssiCoreWrapper
      generic map (
         TPD_G               => TPD_G,
         APP_STREAMS_G       => 1,
         APP_STREAM_ROUTES_G => (
            0                => X"00"),
         CLK_FREQUENCY_G     => 156.25E+6,
         TIMEOUT_UNIT_G      => TIMEOUT_C,
         SERVER_G            => true,
         RETRANSMIT_ENABLE_G => true,
         WINDOW_ADDR_SIZE_G  => WINDOW_ADDR_SIZE_C,
         MAX_NUM_OUTS_SEG_G  => (2**WINDOW_ADDR_SIZE_C),
         PIPE_STAGES_G       => 1,
         APP_AXIS_CONFIG_G   => AXIS_CONFIG_C,
         TSP_AXIS_CONFIG_G   => EMAC_AXIS_CONFIG_C,
         MAX_RETRANS_CNT_G   => MAX_RETRANS_CNT_C,
         MAX_CUM_ACK_CNT_G   => MAX_CUM_ACK_CNT_C)
      port map (
         clk_i                => clk,
         rst_i                => rst,
         -- Application Layer Interface
         sAppAxisMasters_i(0) => rssiIbMaster,
         sAppAxisSlaves_o(0)  => rssiIbSlave,
         mAppAxisMasters_o(0) => rssiObMaster,
         mAppAxisSlaves_i(0)  => rssiObSlave,
         -- Transport Layer Interface
         sTspAxisMaster_i     => sTspMaster,
         sTspAxisSlave_o      => sTspSlave,
         mTspAxisMaster_o     => mTspMaster,
         mTspAxisSlave_i      => mTspSlave,
         -- High level  Application side interface
         openRq_i             => '1',  -- Automatically start the connection without debug SRP channel
         closeRq_i            => '0',
         inject_i             => '0',
         -- AXI-Lite Interface
         axiClk_i             => clk,
         axiRst_i             => rst);

   U_RssiClient : entity work.RssiCoreWrapper
      generic map (
         TPD_G               => TPD_G,
         APP_STREAMS_G       => 1,
         APP_STREAM_ROUTES_G => (
            0                => X"00"),
         CLK_FREQUENCY_G     => 156.25E+6,
         TIMEOUT_UNIT_G      => TIMEOUT_C,
         SERVER_G            => false,
         RETRANSMIT_ENABLE_G => true,
         WINDOW_ADDR_SIZE_G  => WINDOW_ADDR_SIZE_C,
         MAX_NUM_OUTS_SEG_G  => (2**WINDOW_ADDR_SIZE_C),
         PIPE_STAGES_G       => 1,
         APP_AXIS_CONFIG_G   => AXIS_CONFIG_C,
         TSP_AXIS_CONFIG_G   => EMAC_AXIS_CONFIG_C,
         MAX_RETRANS_CNT_G   => MAX_RETRANS_CNT_C,
         MAX_CUM_ACK_CNT_G   => MAX_CUM_ACK_CNT_C)
      port map (
         clk_i                => clk,
         rst_i                => rst,
         -- Application Layer Interface
         sAppAxisMasters_i(0) => sAxisMaster,
         sAppAxisSlaves_o(0)  => sAxisSlave,
         mAppAxisMasters_o(0) => mAxisMaster,
         mAppAxisSlaves_i(0)  => mAxisSlave,
         -- Transport Layer Interface
         sTspAxisMaster_i     => mTspMaster,
         sTspAxisSlave_o      => mTspSlave,
         mTspAxisMaster_o     => sTspMaster,
         mTspAxisSlave_i      => sTspSlave,
         -- High level  Application side interface
         openRq_i             => '1',  -- Automatically start the connection without debug SRP channel
         closeRq_i            => '0',
         inject_i             => '0',
         -- AXI-Lite Interface
         axiClk_i             => clk,
         axiRst_i             => rst);

   comb : process (r, rst, sAxisSlave) is
      variable v          : RegType;
      variable cntPattern : slv(63 downto 0);
   begin
      -- Latch the current value
      v := r;

      if (sAxisSlave.tReady = '1') then
         v.sAxisMaster.tValid := '0';
         v.sAxisMaster.tLast  := '0';
         v.sAxisMaster.tUser  := (others => '0');
         v.sAxisMaster.tKeep  := (others => '1');
      end if;

      if (v.sAxisMaster.tValid = '0') then
         -- State Machine
         case r.state is
            ----------------------------------------------------------------------
            when A_S =>
               ssiSetUserSof(ETH_AXIS_CONFIG_C, v.sAxisMaster, '1');
               v.sAxisMaster.tValid              := '1';
               v.sAxisMaster.tData(31 downto 0)  := x"0000_0003";
               v.sAxisMaster.tData(63 downto 32) := r.tid;
               v.state                           := B_S;
            ----------------------------------------------------------------------
            when B_S =>
               v.sAxisMaster.tValid              := '1';
               v.sAxisMaster.tData(31 downto 0)  := r.addr;
               v.sAxisMaster.tData(63 downto 32) := (others => '0');
               v.state                           := C_S;
            ----------------------------------------------------------------------
            when C_S =>
               v.sAxisMaster.tValid               := '1';
               v.sAxisMaster.tData(11 downto 0)   := r.reqSize;
               v.sAxisMaster.tData(127 downto 12) := (others => '0');
               v.sAxisMaster.tLast                := '1';
               v.sAxisMaster.tKeep(15 downto 0)   := x"000F";
               v.tid                              := r.tid + 1;
               v.addr                             := r.addr + 4;
               v.reqSize                          := r.reqSize + 4;
               v.state                            := A_S;

         ----------------------------------------------------------------------
         end case;
      end if;

      v.cnt               := r.cnt + 1;
      -- if r.cnt < 16 then
      v.mAxisSlave.tReady := '1';
      -- else
      -- v.mAxisSlave.tReady := '0';
      -- end if;

      -- Synchronous Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs        
      sAxisMaster <= r.sAxisMaster;
      mAxisSlave  <= r.mAxisSlave;

   end process comb;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture tb;
