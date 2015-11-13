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
   constant TPD_C            : time    := 1 ns; 

   -- Clocking
   signal   clk_i                 : sl := '0';
   signal   rst_i                 : sl := '0';
   
   -- UUT   
   signal   s_connActive          : sl := '0';
   
   -- RSSI 0   
   signal   s_sndSyn0              : sl := '0';
   signal   s_sndAck0              : sl := '0';
   signal   s_sndRst0              : sl := '0';
   signal   s_sndResend0           : sl := '0';
   signal   s_sndNull0             : sl := '0';

   signal   sAppSsiMaster0       : SsiMasterType;
   signal   sAppSsiSlave0        : SsiSlaveType;
   signal   mAppSsiMaster0       : SsiMasterType;
   signal   mAppSsiSlave0        : SsiSlaveType;

   -- RSSI 1
   signal   s_sndSyn1              : sl := '0';
   signal   s_sndAck1              : sl := '0';
   signal   s_sndRst1              : sl := '0';
   signal   s_sndResend1           : sl := '0';
   signal   s_sndNull1             : sl := '0';

   
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
   
   signal   s_trig : sl := '0';
   
   -- Constants
   constant SSI_MASTER_INIT_C   : SsiMasterType := axis2SsiMaster(RSSI_AXI_CONFIG_C, AXI_STREAM_MASTER_INIT_C);
   constant SSI_SLAVE_NOTRDY_C  : SsiSlaveType  := axis2SsiSlave (RSSI_AXI_CONFIG_C, AXI_STREAM_SLAVE_INIT_C, AXI_STREAM_CTRL_INIT_C);
   constant SSI_SLAVE_RDY_C     : SsiSlaveType  := axis2SsiSlave (RSSI_AXI_CONFIG_C, AXI_STREAM_SLAVE_FORCE_C, AXI_STREAM_CTRL_UNUSED_C);   
------
begin
   -- 
   sAppSsiMaster0 <= axis2SsiMaster(RSSI_AXI_CONFIG_C, mAxisMaster);
   mAxisSlave     <= ssi2AxisSlave(sAppSsiSlave0);
   
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
   RssiCore0_INST: entity work.RssiCore
   generic map (
      TPD_G          => TPD_C
   )
   port map (
      clk_i          => clk_i,
      rst_i          => rst_i,
      connActive_i   => s_connActive,
      sndSyn_i       => s_sndSyn0,
      sndAck_i       => s_sndAck0,
      sndRst_i       => s_sndRst0,
      sndResend_i    => s_sndResend0,
      sndNull_i      => s_sndNull0,
      initSeqN_i     => x"40",
      
      -- PRBS TX
      sAppSsiMaster_i => sAppSsiMaster0,
      sAppSsiSlave_o  => sAppSsiSlave0,
      
      -- PRBS RX 
      mAppSsiMaster_o => mAppSsiMaster0, -- Open for now
      mAppSsiSlave_i  => mAppSsiSlave0,  -- Open for now
      
      -- 
      sTspSsiMaster_i => mTspSsiMaster, --<-- From Peer
      sTspSsiSlave_o  => mTspSsiSlave,  --<-- From Peer
      
      -- 
      mTspSsiMaster_o => sTspSsiMaster, -->-- To Peer 
      mTspSsiSlave_i  => sTspSsiSlave); -->-- To Peer
   
   mAppSsiSlave0 <= SSI_SLAVE_RDY_C;   
      
   RssiCore1_INST: entity work.RssiCore
   generic map (
      TPD_G          => TPD_C
   )
   port map (
      clk_i          => clk_i,
      rst_i          => rst_i,
      connActive_i   => s_connActive,
      sndSyn_i       => s_sndSyn1,
      sndAck_i       => s_sndAck1,
      sndRst_i       => s_sndRst1,
      sndResend_i    => s_sndResend1,
      sndNull_i      => s_sndNull1,
      initSeqN_i     => x"80",
      
      -- PRBS TX
      sAppSsiMaster_i => sAppSsiMaster1, -- Loopback
      sAppSsiSlave_o  => sAppSsiSlave1,  -- Loopback
      
      -- PRBS RX 
      mAppSsiMaster_o => mAppSsiMaster1, -- Loopback
      mAppSsiSlave_i  => mAppSsiSlave1,  -- Loopback
      
      -- 
      sTspSsiMaster_i => sTspSsiMaster, --<-- From Peer
      sTspSsiSlave_o  => open,--sTspSsiSlave,  --<-- From Peer
      
      -- 
      mTspSsiMaster_o => mTspSsiMaster, -->-- To Peer 
      mTspSsiSlave_i  => mTspSsiSlave); -->-- To Peer

   ---------------------------------------
   -- RSSI 1 Loopback connection
   sAppSsiMaster1 <= mAppSsiMaster1;
   mAppSsiSlave1  <= sAppSsiSlave1;

   ------Application side data PRBS---------------------------
    
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
   
   tspReady : process
   begin  
      wait for CLK_PERIOD_C*1;
      sTspSsiSlave <= SSI_SLAVE_RDY_C;
      wait for CLK_PERIOD_C*2;
      sTspSsiSlave <= SSI_SLAVE_NOTRDY_C;
   end process;
   

   StimuliProcess : process
   begin
   
      wait until rst_i = '0';

      wait for CLK_PERIOD_C*200;
      
      -- Request Syn package 0
      wait for CLK_PERIOD_C*100;
      s_sndSyn0 <= '1';
      wait for CLK_PERIOD_C*1;
      s_sndSyn0 <= '0';
      
      -- Request Ack package 0
      wait for CLK_PERIOD_C*101;
      s_sndAck0 <= '1';
      wait for CLK_PERIOD_C*1;
      s_sndAck0 <= '0';
           
      -- Connection active from here on
      -----------------------------------------------------------
      wait for CLK_PERIOD_C*100;
      -- Open Connection
      s_connActive <= '1';
      -----------------------------------------------------------
      
      -- Request Ack package 0
      wait for CLK_PERIOD_C*101;
      s_sndAck0 <= '1';
      wait for CLK_PERIOD_C*1;
      s_sndAck0 <= '0';
      
      -- Request Syn package 0
      wait for CLK_PERIOD_C*102;
      s_sndNull0 <= '1';
      wait for CLK_PERIOD_C*1;
      s_sndNull0 <= '0';
      
      -- Request Rst package 0
      wait for CLK_PERIOD_C*103;
      s_sndRst0 <= '1';
      wait for CLK_PERIOD_C*1;
      s_sndRst0 <= '0';

      -------------------------------------------------------
      wait for CLK_PERIOD_C*100;
      -- Enable PRBS
      s_trig <= '1';
      -------------------------------------------------------
      
      -- Resend unack
      wait for CLK_PERIOD_C*5000;
      s_sndResend0 <= '1';
      wait for CLK_PERIOD_C*1;
      s_sndResend0 <= '0';

   wait;

   
   end process StimuliProcess;   
      
end testbed;
