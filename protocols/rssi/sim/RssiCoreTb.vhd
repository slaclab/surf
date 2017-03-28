-------------------------------------------------------------------------------
-- File       : RssiCoreTb.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-10-28
-- Last update: 2015-10-28
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

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.RssiPkg.all;

library unisim;
use unisim.vcomponents.all;

entity RssiCoreTb is 

end RssiCoreTb;

architecture testbed of RssiCoreTb is

   constant CLK_PERIOD_C : time    := 6.4 ns;
   constant TPD_C        : time    := 0.64 ns;
   
   -- RSSI configuration
   constant WINDOW_ADDR_SIZE_C  : positive := 3;
   constant SEGMENT_ADDR_SIZE_C : positive := 7;
   
   constant PRBS_BYTE_WIDTH_C : positive := 16;
   constant TSP_BYTE_WIDTH_C  : positive := 16;
   
   -- Clocking
   signal   clk_i                 : sl := '0';
   signal   rst_i                 : sl := '0';
   
   -- UUT   
   signal   s_intPrbsRst : sl := '0';
   signal   s_prbsRst    : sl := '0';

   
   -- RSSI 0   
   signal   connRq0_i     : sl := '0';
   signal   closeRq0_i    : sl := '0';
   signal   inject0_i     : sl := '0';
   
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
   signal   inject1_i     : sl := '0';

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
      SERVER_G       => true,
      INIT_SEQ_N_G   => 16#40#,
      WINDOW_ADDR_SIZE_G   => WINDOW_ADDR_SIZE_C,
      SEGMENT_ADDR_SIZE_G  => SEGMENT_ADDR_SIZE_C,
      MAX_NUM_OUTS_SEG_G   => 2**WINDOW_ADDR_SIZE_C,
      MAX_SEG_SIZE_G       => (2**SEGMENT_ADDR_SIZE_C)*8,
      CLK_FREQUENCY_G      => 156.25E+6,
      
      MAX_RETRANS_CNT_G     => 1,
      MAX_CUM_ACK_CNT_G     => 10,
      
      ACK_TOUT_G            => 250,
      RETRANS_TOUT_G        => 500,
      NULL_TOUT_G           => 2000,
      
      TSP_AXIS_CONFIG_G  => ssiAxiStreamConfig(TSP_BYTE_WIDTH_C),
      APP_AXIS_CONFIG_G  => ssiAxiStreamConfig(PRBS_BYTE_WIDTH_C))
   port map (
      clk_i       => clk_i,
      rst_i       => rst_i,
      openRq_i    => connRq0_i, 
      closeRq_i   => closeRq0_i,
      inject_i    => inject0_i,
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
     
   -- Transport connection between modules
   sTspAxisMaster1 <= mTspAxisMaster0;
   mTspAxisSlave0  <= sTspAxisSlave1; 
  
   sTspAxisMaster0 <= mTspAxisMaster1;
   mTspAxisSlave1  <= sTspAxisSlave0;

   -- RSSI 1 Client      
   RssiCore1_INST: entity work.RssiCore
   generic map (
      TPD_G          => TPD_C,
      SERVER_G       => false,
      INIT_SEQ_N_G   => 16#80#,
      --
      WINDOW_ADDR_SIZE_G   => WINDOW_ADDR_SIZE_C,
      SEGMENT_ADDR_SIZE_G  => SEGMENT_ADDR_SIZE_C,
      MAX_NUM_OUTS_SEG_G   => 2**WINDOW_ADDR_SIZE_C,
      MAX_SEG_SIZE_G       => (2**SEGMENT_ADDR_SIZE_C)*8,
      CLK_FREQUENCY_G      => 156.25E+6,
      
      MAX_RETRANS_CNT_G     => 1,
      MAX_CUM_ACK_CNT_G     => 10,
      
      ACK_TOUT_G            => 250,
      RETRANS_TOUT_G        => 500,
      NULL_TOUT_G           => 2000,
      
      --
      TSP_AXIS_CONFIG_G  => ssiAxiStreamConfig(TSP_BYTE_WIDTH_C),
      APP_AXIS_CONFIG_G  => ssiAxiStreamConfig(PRBS_BYTE_WIDTH_C))
   port map (
      clk_i       => clk_i,
      rst_i       => rst_i,
      openRq_i    => connRq1_i, 
      closeRq_i   => closeRq1_i,
      inject_i    => inject1_i,
      
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
   -- sAppAxisMaster1 <= mAppAxisMaster1;
   -- mAppAxisSlave1  <= sAppAxisSlave1;
   
   -- mAppAxisSlave1  <= AXI_STREAM_SLAVE_FORCE_C;
   -- sAppAxisMaster1 <= AXI_STREAM_MASTER_INIT_C;

   ------Application side data PRBS Tx---------------------------
   s_prbsRst <= rst_i or s_intPrbsRst;
    
   SsiPrbsTx_INST: entity work.SsiPrbsTx
   generic map (
      TPD_G                      => TPD_C,

      XIL_DEVICE_G               => "ULTRASCALE",

      CASCADE_SIZE_G             => 1,
      FIFO_ADDR_WIDTH_G          => 9,
      FIFO_PAUSE_THRESH_G        => 2**8,
      PRBS_SEED_SIZE_G           => PRBS_BYTE_WIDTH_C*8,
      PRBS_TAPS_G                => (0 => 31, 1 => 6, 2 => 2, 3 => 1),
      MASTER_AXI_STREAM_CONFIG_G => ssiAxiStreamConfig(PRBS_BYTE_WIDTH_C),
      MASTER_AXI_PIPE_STAGES_G   => 1)
   port map (
      mAxisClk        => clk_i,
      mAxisRst        => s_prbsRst,
      mAxisMaster     => sAppAxisMaster0,
      mAxisSlave      => sAppAxisSlave0,
      locClk          => clk_i,
      locRst          => s_prbsRst,
      trig            => s_trig,
      packetLength    => X"0000_003f",
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
      PRBS_SEED_SIZE_G           => PRBS_BYTE_WIDTH_C*8,
      PRBS_TAPS_G                => (0 => 31, 1 => 6, 2 => 2, 3 => 1),
      SLAVE_AXI_STREAM_CONFIG_G  => ssiAxiStreamConfig(PRBS_BYTE_WIDTH_C),
      SLAVE_AXI_PIPE_STAGES_G    => 1)
   port map (
      sAxisClk        => clk_i,
      sAxisRst        => s_prbsRst,
      sAxisMaster     => mAppAxisMaster1, --mAppAxisMaster0,
      sAxisSlave      => mAppAxisSlave1,  --mAppAxisSlave0,
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
   
   -- readyToggle : process
   -- begin
   
   -- wait for CLK_PERIOD_C*200;
   -- mAppAxisSlave1  <= AXI_STREAM_SLAVE_INIT_C;
   -- wait for CLK_PERIOD_C*200;   
   -- mAppAxisSlave1  <= AXI_STREAM_SLAVE_FORCE_C;
   
   -- end process readyToggle;  
   
   
   StimuliProcess : process
   begin
   
      wait until rst_i = '0';
      connRq0_i <= '1'; -- Let the client timeout
      connRq1_i <= '1'; 
      
      wait for CLK_PERIOD_C*200;
            
      -- Connection request 0
      wait for CLK_PERIOD_C*100;
    
      
      wait for CLK_PERIOD_C*1;
      --connRq0_i <= '0';
      
      wait for CLK_PERIOD_C*1000;
      
      -- Connection request 1
      connRq1_i <= '1';
      wait for CLK_PERIOD_C*1;
      --connRq1_i <= '0';

      -------------------------------------------------------
      wait for CLK_PERIOD_C*1000;
      -- Enable PRBS
      --s_trig <= '1';
      -------------------------------------------------------
      
      -- Request connection close request
      wait for CLK_PERIOD_C*15000;
      -- Disable PRBS
     -- closeRq1_i <= '1';
      wait for CLK_PERIOD_C*1;
     -- closeRq1_i <= '0';
      
      -- Reset PRBS
      wait for CLK_PERIOD_C*100;
      --s_intPrbsRst <= '1';
      wait for CLK_PERIOD_C*200;
      --s_intPrbsRst <= '0';
      
      -- Reconnect

      -- Connection request 0


      wait for CLK_PERIOD_C*4000;  
      
      -- Connection request 1
      --connRq1_i <= '1';
      wait for CLK_PERIOD_C*1;
      --connRq1_i <= '0';
      
      -- Let the client resend SYN
      --wait for CLK_PERIOD_C*10000;
      --wait for CLK_PERIOD_C*50000;
      --connRq0_i <= '1';
      wait for CLK_PERIOD_C*1;
      --connRq0_i <= '0';    
      
      -------------------------------------------------------
      -- Wait for connection 
      wait for CLK_PERIOD_C*300;      
      -- Enable PRBS
      --s_trig <= '1';
      
      
      -------------------------------------------------------
      wait for CLK_PERIOD_C*10000;
      -- Stop PRBS
      s_trig <= '0';
      -------------------------------------------------------     
      
      
      -------------------------------------------------------
      wait for CLK_PERIOD_C*30000;
      -- Stop PRBS
      s_trig <= '1';
      -------------------------------------------------------
      
      wait for CLK_PERIOD_C*10000;
      connRq1_i <= '0'; 
      connRq0_i <= '0';       
            
      -------------------------------------------------------
      -- Inject fault into RSSI0
      wait for CLK_PERIOD_C*10000;
      -- 
      inject0_i <= '1';
      wait for CLK_PERIOD_C*20000;
      -- 
      inject0_i <= '0';

      -------------------------------------------------------
      -- Inject fault into RSSI1
      wait for CLK_PERIOD_C*10000;
      -- 
      inject1_i <= '1';
      wait for CLK_PERIOD_C*20000;
      -- 
      inject1_i <= '0';
      
      -------------------------------------------------------
      -- Inject fault into RSSI0
      wait for CLK_PERIOD_C*10000;
      -- 
      inject0_i <= '1';
      wait for CLK_PERIOD_C*20000;
      -- 
      inject0_i <= '0';

      -------------------------------------------------------
      -- Inject fault into RSSI1
      wait for CLK_PERIOD_C*10000;
      -- 
      inject1_i <= '1';
      wait for CLK_PERIOD_C*20000;
      -- 
      inject1_i <= '0';

      -------------------------------------------------------
      -- Inject fault into RSSI0 and RSSI1 Repeatedly
      wait for CLK_PERIOD_C*10000;
      -- 
      inject0_i <= '1';
      inject1_i <= '1';
      wait for CLK_PERIOD_C*20000;
      -- 
      inject0_i <= '0';
      inject1_i <= '0';      
      
      wait for CLK_PERIOD_C*1000;
      -- 
      inject0_i <= '1';
      inject1_i <= '1';
      wait for CLK_PERIOD_C*20000;
      -- 
      inject0_i <= '0';
      inject1_i <= '0';
      
      wait for CLK_PERIOD_C*10000;
      -- Stop PRBS
      s_trig <= '0';
      -------------------------------------------------------     
      
      
      -------------------------------------------------------
      wait for CLK_PERIOD_C*60000;
      -- Stop PRBS
      s_trig <= '1';
      
      ------------------------------------------------------

      wait;
   ------------------------------
   end process StimuliProcess;   
      
end testbed;
