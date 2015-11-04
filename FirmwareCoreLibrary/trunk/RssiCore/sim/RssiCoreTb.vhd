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
   signal   txAck_i               : sl := '0';
   signal   txAckN_i              : slv(7 downto 0) := x"00";
   signal   rxAckN_i              : slv(7 downto 0) := x"20";
   signal   connActive_i          : sl := '0';
   signal   sndSyn_i              : sl := '0';
   signal   sndAck_i              : sl := '0';
   signal   sndRst_i              : sl := '0';
   signal   sndResend_i           : sl := '0';
   signal   sndNull_i             : sl := '0';
    
   signal   lenErr_o              : sl;
   signal   ackErr_o              : sl;
   
   signal   appSsiMaster_i        : SsiMasterType := axis2SsiMaster(RSSI_AXI_CONFIG_C, AXI_STREAM_MASTER_INIT_C);
   signal   appSsiSlave_o         : SsiSlaveType;
   signal   tspSsiSlave_i         : SsiSlaveType  := axis2SsiSlave(RSSI_AXI_CONFIG_C, AXI_STREAM_SLAVE_FORCE_C, AXI_STREAM_CTRL_UNUSED_C);
   signal   tspSsiMaster_o        : SsiMasterType;
   
   
   -- Internal 
   signal mAxisMaster : AxiStreamMasterType; 
   signal mAxisSlave  : AxiStreamSlaveType;
   
   signal   s_trig : sl := '0';
   
   
begin
   -- 
   appSsiMaster_i <= axis2SsiMaster(RSSI_AXI_CONFIG_C, mAxisMaster);
   mAxisSlave     <= ssi2AxisSlave(appSsiSlave_o);
   
   -- Generate clocks and resets
   DDR_ClkRst_Inst : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,     -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1000 ns)  -- Hold reset for this long)
      port map (
         clkP => clk_i,
         clkN => open,
         rst  => rst_i,
         rstL => open); 

  -----------------------------
  -- component instantiation 
  -----------------------------
  RssiCore_INST: entity work.RssiCore
   generic map (
      TPD_G          => TPD_C
   )
   port map (
      clk_i          => clk_i,
      rst_i          => rst_i,
      txAck_i        => txAck_i,
      txAckN_i       => txAckN_i,
      rxAckN_i       => rxAckN_i,
      connActive_i   => connActive_i,
      sndSyn_i       => sndSyn_i,
      sndAck_i       => sndAck_i,
      sndRst_i       => sndRst_i,
      sndResend_i    => sndResend_i,
      sndNull_i      => sndNull_i,
      lenErr_o       => lenErr_o,
      ackErr_o       => ackErr_o,
      appSsiMaster_i => appSsiMaster_i,
      appSsiSlave_o  => appSsiSlave_o,
      tspSsiSlave_i  => tspSsiSlave_i,
      tspSsiMaster_o => tspSsiMaster_o);
   
   ---------------------------------------
   
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

   --
   StimuliProcess : process
   begin
   
   wait until rst_i = '0';

   wait for CLK_PERIOD_C*200;
   
   -- Request Syn package 0
   wait for CLK_PERIOD_C*100;
   sndSyn_i <= '1';
   wait for CLK_PERIOD_C*1;
   sndSyn_i <= '0';
   
   -- Request Syn package 1
   wait for CLK_PERIOD_C*100;
   sndSyn_i <= '1';
   wait for CLK_PERIOD_C*1;
   sndSyn_i <= '0';
   
   -- Request Ack package 0
   wait for CLK_PERIOD_C*100;
   sndAck_i <= '1';
   wait for CLK_PERIOD_C*1;
   sndAck_i <= '0';
   
   -- Connection active from here on
   -----------------------------------------------------------
   wait for CLK_PERIOD_C*100;
   -- Open Connection
   connActive_i <= '1';
   -----------------------------------------------------------
   
   -- Request Ack package 1
   wait for CLK_PERIOD_C*100;
   sndAck_i <= '1';
   wait for CLK_PERIOD_C*1;
   sndAck_i <= '0';
   
   -- Request Null package 0
   wait for CLK_PERIOD_C*100;
   sndNull_i <= '1';
   wait for CLK_PERIOD_C*1;
   sndNull_i <= '0';
   
   -- Request Rst package 0
   wait for CLK_PERIOD_C*100;
   sndRst_i <= '1';
   wait for CLK_PERIOD_C*1;
   sndRst_i <= '0';
   
   -- Request Null package 1
   wait for CLK_PERIOD_C*100;
   sndNull_i <= '1';
   wait for CLK_PERIOD_C*1;
   sndNull_i <= '0';
   
   
   -- Request Rst package 1
   wait for CLK_PERIOD_C*100;
   sndRst_i <= '1';
   wait for CLK_PERIOD_C*1;
   sndRst_i <= '0';
   
   -------------------------------------------------------
   wait for CLK_PERIOD_C*100;
   -- Enable PRBS
   s_trig <= '1';
   -------------------------------------------------------
   
   -- Resend unack
   wait for CLK_PERIOD_C*5000;
   sndResend_i <= '1';
   wait for CLK_PERIOD_C*1;
   sndResend_i <= '0';
   
   -- Send Acknowledge 0
   wait for CLK_PERIOD_C*1000;
   txAck_i <= '1';
   txAckN_i <= x"81";
   wait for CLK_PERIOD_C*1;
   txAck_i <= '0';
   
   -- Resend unack
   wait for CLK_PERIOD_C*1000;
   sndResend_i <= '1';
   wait for CLK_PERIOD_C*1;
   sndResend_i <= '0';
   
   -- Send Acknowledge 1
   wait for CLK_PERIOD_C*1000;
   txAck_i <= '1';
   txAckN_i <= x"86";
   wait for CLK_PERIOD_C*1;
   txAck_i <= '0';
   
   -- Resend unack
   wait for CLK_PERIOD_C*2000;
   sndResend_i <= '1';
   wait for CLK_PERIOD_C*1;
   sndResend_i <= '0';
 
   
   -- -- Send acknowledge 1 
   -- wait for CLK_PERIOD_C*15000;
   -- txAck_i <= '1';
   -- txAckN_i <= x"85";
   -- wait for CLK_PERIOD_C*1;
   -- txAck_i <= '0';

   -- -- Send acknowledge 2 
   -- wait for CLK_PERIOD_C*15000;
   -- txAck_i <= '1';
   -- txAckN_i <= x"86";
   -- wait for CLK_PERIOD_C*1;
   -- txAck_i <= '0';
   
   
   -- -- Send Acknowledge 3
   -- wait for CLK_PERIOD_C*5000;
   -- txAck_i <= '1';
   -- txAckN_i <= x"8C";
   -- wait for CLK_PERIOD_C*1;
   -- txAck_i <= '0';
  
   wait;

   
   end process StimuliProcess;   
      
end testbed;
