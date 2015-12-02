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

   -- RSSI 0   
   signal   connRq0_i     : sl := '0';
   signal   closeRq0_i    : sl := '0';
       
   signal   sAppSsiMaster0   : SsiMasterType;
   signal   sAppSsiSlave0    : SsiSlaveType;
   signal   mAppSsiMaster0   : SsiMasterType;
   signal   mAppSsiSlave0    : SsiSlaveType;

   -- RSSI 1
   signal   connRq1_i     : sl := '0';
   signal   closeRq1_i    : sl := '0';

   signal   sAppSsiMaster1       : SsiMasterType;
   signal   sAppSsiSlave1        : SsiSlaveType;
   signal   mAppSsiMaster1       : SsiMasterType;
   signal   mAppSsiSlave1        : SsiSlaveType;
   
   -- Transport
   signal   sTspSsiMaster       : SsiMasterType;
   signal   sTspSsiSlave        : SsiSlaveType;
   signal   mTspSsiMaster       : SsiMasterType;
   signal   mTspSsiSlave        : SsiSlaveType;

   -- Internal AXIStream
   signal   mAxisMaster    : AxiStreamMasterType; 
   signal   mAxisSlave     : AxiStreamSlaveType;
   signal   sAxisMaster    : AxiStreamMasterType; 
   signal   sAxisSlave     : AxiStreamSlaveType;
   
   signal   s_trig : sl := '0';
   
   -- Constants
   constant SSI_MASTER_INIT_C   : SsiMasterType := axis2SsiMaster(RSSI_AXI_CONFIG_C, AXI_STREAM_MASTER_INIT_C);
   constant SSI_SLAVE_NOTRDY_C  : SsiSlaveType  := axis2SsiSlave (RSSI_AXI_CONFIG_C, AXI_STREAM_SLAVE_INIT_C, AXI_STREAM_CTRL_INIT_C);
   constant SSI_SLAVE_RDY_C     : SsiSlaveType  := axis2SsiSlave (RSSI_AXI_CONFIG_C, AXI_STREAM_SLAVE_FORCE_C, AXI_STREAM_CTRL_UNUSED_C);   
------
begin
   -- Prbs TX
   sAppSsiMaster0 <= axis2SsiMaster(RSSI_AXI_CONFIG_C, mAxisMaster);
   mAxisSlave     <= ssi2AxisSlave(sAppSsiSlave0);
   
   -- Prbs RX
   sAxisMaster    <= ssi2AxisMaster(RSSI_AXI_CONFIG_C, mAppSsiMaster0);
   mAppSsiSlave0  <= axis2SsiSlave(RSSI_AXI_CONFIG_C, sAxisSlave, AXI_STREAM_CTRL_UNUSED_C);
   
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
      sAppSsiMaster_i => sAppSsiMaster0, -- prbs tx
      sAppSsiSlave_o  => sAppSsiSlave0,  -- prbs tx
      
      --  
      mAppSsiMaster_o => mAppSsiMaster0, -- prbs rx
      mAppSsiSlave_i  => mAppSsiSlave0,  -- prbs rx
      
      -- 
      sTspSsiMaster_i => mTspSsiMaster, --<-- From Peer
      sTspSsiSlave_o  => mTspSsiSlave,  --<-- From Peer
      
      -- 
      mTspSsiMaster_o => sTspSsiMaster, -->-- To Peer 
      mTspSsiSlave_i  => sTspSsiSlave); -->-- To Peer
   
   ---------------------------------------
   --mAppSsiSlave0 <= SSI_SLAVE_RDY_C;   
   

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
      sAppSsiMaster_i => sAppSsiMaster1, -- Loopback
      sAppSsiSlave_o  => sAppSsiSlave1,  -- Loopback
      
      -- 
      mAppSsiMaster_o => mAppSsiMaster1, -- Loopback 
      mAppSsiSlave_i  => mAppSsiSlave1,  -- Loopback 
      
      -- 
      sTspSsiMaster_i => sTspSsiMaster, --<-- From Peer
      sTspSsiSlave_o  => sTspSsiSlave,  --<-- From Peer
      
      -- 
      mTspSsiMaster_o => mTspSsiMaster, -->-- To Peer 
      mTspSsiSlave_i  => mTspSsiSlave); -->-- To Peer

   ---------------------------------------
   -- RSSI 1 Loopback connection
   sAppSsiMaster1 <= mAppSsiMaster1;
   mAppSsiSlave1  <= sAppSsiSlave1;
   
   --mAppSsiSlave1  <= SSI_SLAVE_RDY_C;
   --sAppSsiMaster1 <= SSI_MASTER_INIT_C;

   ------Application side data PRBS Tx---------------------------
    
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
      mAxisRst        => rst_i,
      mAxisMaster     => mAxisMaster,
      mAxisSlave      => mAxisSlave,
      locClk          => clk_i,
      locRst          => rst_i,
      trig            => s_trig,
      packetLength    => X"0000_00fe",
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
      FIFO_ADDR_WIDTH_G          => 9,
      FIFO_PAUSE_THRESH_G        => 2**8,
      PRBS_SEED_SIZE_G           => 32,
      PRBS_TAPS_G                => (0 => 31, 1 => 6, 2 => 2, 3 => 1),
      SLAVE_AXI_STREAM_CONFIG_G  => RSSI_AXI_CONFIG_C,
      SLAVE_AXI_PIPE_STAGES_G    => 1)
   port map (
      sAxisClk        => clk_i,
      sAxisRst        => rst_i,
      sAxisMaster     => sAxisMaster,
      sAxisSlave      => sAxisSlave,
      sAxisCtrl       => open,
      mAxisClk        => clk_i,
      mAxisRst        => rst_i,
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

   -- tspReady : process
   -- begin
      -- wait for TPD_C;
      
      -- loop
         -- wait for CLK_PERIOD_C*5;
         -- sTspSsiSlave <= SSI_SLAVE_RDY_C;
         -- wait for CLK_PERIOD_C*2;
         -- sTspSsiSlave <= SSI_SLAVE_NOTRDY_C;
      -- end loop;
   --end process;
   

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
