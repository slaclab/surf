-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : RssiCoreTb.vhd
-- Author     : Uros Legat  <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-10-28
-- Last update: 2015-10-28
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the RssiCore
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.RssiPkg.all;

library unisim;
use unisim.vcomponents.all;

entity RssiCoreTb is 

end RssiCoreTb;

architecture testbed of RssiCoreTb is

   constant CLK_PERIOD_C : time    := 10   ns;
   constant TPD_C        : time    := 1 ns; 

   -- Clocking
   signal   clk_i                 : sl := '0';
   signal   rst_i                 : sl := '0';
   
   -- UUT   
   signal   s_intPrbsRst : sl := '0';
   signal   s_prbsRst    : sl := '0';
   
   
   
   -- RSSI 0   
   signal   connRq0_i     : sl := '0';
   signal   closeRq0_i    : sl := '0';
   
   signal   sAppAxisMaster0      : AxiStreamMasterType;
   signal   sAppAxisSlave0       : AxiStreamSlaveType;
   signal   mAppAxisMaster0      : AxiStreamMasterType;
   signal   mAppAxisSlave0       : AxiStreamSlaveType;

   signal   sTspAxisMaster0      : AxiStreamMasterType;
   signal   sTspAxisSlave0       : AxiStreamSlaveType;
   signal   mTspAxisMaster0      : AxiStreamMasterType;
   signal   mTspAxisSlave0       : AxiStreamSlaveType;   

   -- RSSI 1
   signal   connRq1_i     : sl := '0';
   signal   closeRq1_i    : sl := '0';

   signal   sAppAxisMaster1      : AxiStreamMasterType;
   signal   sAppAxisSlave1       : AxiStreamSlaveType;
   signal   mAppAxisMaster1      : AxiStreamMasterType;
   signal   mAppAxisSlave1       : AxiStreamSlaveType;

   signal   sTspAxisMaster1      : AxiStreamMasterType;
   signal   sTspAxisSlave1       : AxiStreamSlaveType;
   signal   mTspAxisMaster1      : AxiStreamMasterType;
   signal   mTspAxisSlave1       : AxiStreamSlaveType;  
     
   signal   s_trig : sl := '0';
     
------
begin
  
   -- Generate clocks and resets
   DDR_ClkRst_Inst : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 1 ns,     -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1000 ns)  -- Hold reset for this long)
      port map (
         clkP => clk_i,
         clkN => open,
         rst  => rst_i,
         rstL => open); 

  -----------------------------
  -- component instantiation 
  -----------------------------
  
   -- RSSI 0 Server
   RssiCore0_INST: entity work.RssiCore
   generic map (
      TPD_G          => TPD_C,
      SERVER_G       => true
   )
   port map (
      clk_i       => clk_i,
      rst_i       => rst_i,
      connRq_i    => connRq0_i, 
      closeRq_i   => closeRq0_i,
      initSeqN_i  => x"40",
      
      -- 
      sAppAxisMaster_i => sAppAxisMaster0, -- prbs tx
      sAppAxisSlave_o  => sAppAxisSlave0,  -- prbs tx
      
      --  
      mAppAxisMaster_o => mAppAxisMaster0, -- prbs rx
      mAppAxisSlave_i  => mAppAxisSlave0,  -- prbs rx
      
      -- 
      sTspAxisMaster_i => sTspAxisMaster0, --<-- From Peer
      sTspAxisSlave_o  => sTspAxisSlave0,  --<-- From Peer
      
      -- 
      mTspAxisMaster_o => mTspAxisMaster0, -->-- To Peer 
      mTspAxisSlave_i  => mTspAxisSlave0); -->-- To Peer
   
   ---------------------------------------
      -- /////////////////////////////////////////////////////////
   ------------------------------------------------------------
   -- Transport fifos
   ------------------------------------------------------------
   -- /////////////////////////////////////////////////////////  

   Transport_fifo0: entity work.AxiStreamFifo
   generic map (
      TPD_G               => TPD_C,
      SLAVE_READY_EN_G    => true,
      VALID_THOLD_G       => 1,
      BRAM_EN_G           => true,
      XIL_DEVICE_G        => "ULTRASCALE",

      CASCADE_SIZE_G      => 1,
      FIFO_ADDR_WIDTH_G   => 4,
      FIFO_FIXED_THRESH_G => true,
      FIFO_PAUSE_THRESH_G => 1,

      SLAVE_AXI_CONFIG_G  => RSSI_AXI_CONFIG_C,
      MASTER_AXI_CONFIG_G => RSSI_AXI_CONFIG_C)
   port map (
      sAxisClk        => clk_i,
      sAxisRst        => rst_i,
      sAxisMaster     => mTspAxisMaster0,
      sAxisSlave      => mTspAxisSlave0,
      sAxisCtrl       => open,
      --
      mAxisClk        => clk_i,
      mAxisRst        => rst_i,
      mAxisMaster     => sTspAxisMaster1,
      mAxisSlave      => sTspAxisSlave1,
      mTLastTUser     => open);
   
   --
   Transport_fifo1: entity work.AxiStreamFifo
   generic map (
      TPD_G               => TPD_C,
      SLAVE_READY_EN_G    => true,
      VALID_THOLD_G       => 1,
      BRAM_EN_G           => true,
      XIL_DEVICE_G        => "ULTRASCALE",

      CASCADE_SIZE_G      => 1,
      FIFO_ADDR_WIDTH_G   => 4,
      FIFO_FIXED_THRESH_G => true,
      FIFO_PAUSE_THRESH_G => 1,

      SLAVE_AXI_CONFIG_G  => RSSI_AXI_CONFIG_C,
      MASTER_AXI_CONFIG_G => RSSI_AXI_CONFIG_C)
   port map (
      sAxisClk        => clk_i,
      sAxisRst        => rst_i,
      sAxisMaster     => mTspAxisMaster1,
      sAxisSlave      => mTspAxisSlave1,
      sAxisCtrl       => open,
      --
      mAxisClk        => clk_i,
      mAxisRst        => rst_i,
      mAxisMaster     => sTspAxisMaster0,
      mAxisSlave      => sTspAxisSlave0,
      mTLastTUser     => open);
   
   -- Transport connection between modules
   -- sTspAxisMaster1 <= mTspAxisMaster0;
   -- mTspAxisSlave0  <= sTspAxisSlave1; 
   
   
   -- sTspAxisMaster0 <= mTspAxisMaster1;
   -- mTspAxisSlave1  <= sTspAxisSlave0;

   
   
   -- RSSI 1 Client      
   RssiCore1_INST: entity work.RssiCore
   generic map (
      TPD_G          => TPD_C,
      SERVER_G       => false      
   )
   port map (
      clk_i       => clk_i,
      rst_i       => rst_i,
      connRq_i    => connRq1_i, 
      closeRq_i   => closeRq1_i,
      initSeqN_i  => x"80",
           
      -- 
      sAppAxisMaster_i => sAppAxisMaster1, -- Loopback
      sAppAxisSlave_o  => sAppAxisSlave1,  -- Loopback
      
      -- 
      mAppAxisMaster_o => mAppAxisMaster1, -- Loopback 
      mAppAxisSlave_i  => mAppAxisSlave1,  -- Loopback 
      
      -- 
      sTspAxisMaster_i => sTspAxisMaster1, --<-- From Peer
      sTspAxisSlave_o  => sTspAxisSlave1,  --<-- From Peer
      
      -- 
      mTspAxisMaster_o => mTspAxisMaster1, -->-- To Peer 
      mTspAxisSlave_i  => mTspAxisSlave1); -->-- To Peer

   ---------------------------------------
   -- RSSI 1 Loopback connection
   sAppAxisMaster1 <= mAppAxisMaster1;
   mAppAxisSlave1  <= sAppAxisSlave1;
   
   --mAppAxisSlave1  <= AXI_STREAM_SLAVE_FORCE_C;
   --sAppAxisMaster1 <= AXI_STREAM_MASTER_INIT_C;

   ------Application side data PRBS Tx---------------------------
   s_prbsRst <= rst_i or s_intPrbsRst;
    
   SsiPrbsTx_INST: entity work.SsiPrbsTx
   generic map (
      TPD_G                      => TPD_C,

      XIL_DEVICE_G               => "ULTRASCALE",

      CASCADE_SIZE_G             => 1,
      FIFO_ADDR_WIDTH_G          => 9,
      FIFO_PAUSE_THRESH_G        => 2**8,
      PRBS_SEED_SIZE_G           => 32,
      PRBS_TAPS_G                => (0 => 31, 1 => 6, 2 => 2, 3 => 1),
      MASTER_AXI_STREAM_CONFIG_G => RSSI_AXI_CONFIG_C,
      MASTER_AXI_PIPE_STAGES_G   => 1)
   port map (
      mAxisClk        => clk_i,
      mAxisRst        => s_prbsRst,
      mAxisMaster     => sAppAxisMaster0,
      mAxisSlave      => sAppAxisSlave0,
      locClk          => clk_i,
      locRst          => s_prbsRst,
      trig            => s_trig,
      packetLength    => X"0000_00ff",
      forceEofe       => '0',
      busy            => open,
      tDest           => X"00",
      tId             => X"00"
      --axilReadMaster  => ,
      --axilReadSlave   => ,
      --axilWriteMaster => ,
      --axilWriteSlave  => 
   );
   
   ------Application side data PRBS Rx---------------------------
   SsiPrbsRx_INST: entity work.SsiPrbsRx
   generic map (
      TPD_G                      => TPD_C,

      XIL_DEVICE_G               => "ULTRASCALE",
      CASCADE_SIZE_G             => 1,
      FIFO_ADDR_WIDTH_G          => 4,
      FIFO_PAUSE_THRESH_G        => 1,
      PRBS_SEED_SIZE_G           => 32,
      PRBS_TAPS_G                => (0 => 31, 1 => 6, 2 => 2, 3 => 1),
      SLAVE_AXI_STREAM_CONFIG_G  => RSSI_AXI_CONFIG_C,
      SLAVE_AXI_PIPE_STAGES_G    => 1)
   port map (
      sAxisClk        => clk_i,
      sAxisRst        => s_prbsRst,
      sAxisMaster     => mAppAxisMaster0,
      sAxisSlave      => mAppAxisSlave0,
      sAxisCtrl       => open,
      mAxisClk        => clk_i,
      mAxisRst        => s_prbsRst,
      --mAxisMaster     => mAxisMaster,
      --mAxisSlave      => mAxisSlave,
      --axiClk          => clk_i,
      --axiRst          => rst_i,
      --axiReadMaster   => axiReadMaster,
      --axiReadSlave    => axiReadSlave,
      --axiWriteMaster  => axiWriteMaster,
      --axiWriteSlave   => axiWriteSlave,
      updatedResults  => open,
      errorDet        => open,
      busy            => open,
      errMissedPacket => open,
      errLength       => open,
      errDataBus      => open,
      errEofe         => open,
      errWordCnt      => open,
      errbitCnt       => open,
      packetRate      => open,
      packetLength    => open);

   StimuliProcess : process
   begin
   
      wait until rst_i = '0';

      wait for CLK_PERIOD_C*200;
      
      
      -- Connection request 0
      wait for CLK_PERIOD_C*100;
      connRq0_i <= '1';
      wait for CLK_PERIOD_C*1;
      connRq0_i <= '0';
      
      -- Connection request 1
      connRq1_i <= '1';
      wait for CLK_PERIOD_C*1;
      connRq1_i <= '0';

      -------------------------------------------------------
      wait for CLK_PERIOD_C*1000;
      -- Enable PRBS
      s_trig <= '1';
      -------------------------------------------------------
      
      -- Request Ack package 0
      wait for CLK_PERIOD_C*15000;
      closeRq1_i <= '1';
      wait for CLK_PERIOD_C*1;
      closeRq1_i <= '0';
      
      -- Reset PRBS
      wait for CLK_PERIOD_C*100;
      s_intPrbsRst <= '1';
      wait for CLK_PERIOD_C*16;
      s_intPrbsRst <= '0';
      
      -- Reconnect

      -- Connection request 0
      wait for CLK_PERIOD_C*2000;
      connRq0_i <= '1';
      wait for CLK_PERIOD_C*1;
      connRq0_i <= '0';

      wait for CLK_PERIOD_C*100;      
      -- Connection request 1
      connRq1_i <= '1';
      wait for CLK_PERIOD_C*1;
      connRq1_i <= '0';
      
      -------------------------------------------------------
      wait for CLK_PERIOD_C*50000;
      -- Stop PRBS
      s_trig <= '0';
      -------------------------------------------------------     
      
      
      -------------------------------------------------------
      wait for CLK_PERIOD_C*50000;
      -- Stop PRBS
      s_trig <= '1';
      -------------------------------------------------------

      wait;
   ------------------------------
   end process StimuliProcess;   
      
end testbed;
