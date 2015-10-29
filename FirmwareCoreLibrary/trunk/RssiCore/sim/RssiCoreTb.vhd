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
   constant AXI_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(2);
   constant TPD_C            : time    := 1 ns; 

   -- Clocking
   signal   clk_i                 : sl := '0';
   signal   rst_i                 : sl := '0';
   
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
   
   signal   appSsiMaster_i        : SsiMasterType := axis2SsiMaster(AXI_CONFIG_C, AXI_STREAM_MASTER_INIT_C);
   signal   appSsiSlave_o         : SsiSlaveType;
   signal   tspSsiSlave_i         : SsiSlaveType  := axis2SsiSlave(AXI_CONFIG_C, AXI_STREAM_SLAVE_FORCE_C, AXI_STREAM_CTRL_UNUSED_C);
   signal   tspSsiMaster_o        : SsiMasterType;
   
   signal mAxisMaster : AxiStreamMasterType; 
   signal mAxisSlave  : AxiStreamSlaveType;
   
begin
   -- 
   appSsiMaster_i <= axis2SsiMaster(AXI_CONFIG_C, mAxisMaster);
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
      MASTER_AXI_STREAM_CONFIG_G => ssiAxiStreamConfig(2),
      MASTER_AXI_PIPE_STAGES_G   => 0)
   port map (
      mAxisClk        => clk_i,
      mAxisRst        => rst_i,
      mAxisMaster     => mAxisMaster,
      mAxisSlave      => mAxisSlave,
      locClk          => clk_i,
      locRst          => rst_i,
      trig            => '1',
      packetLength    => X"0000_01ff",
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
   
   connActive_i <= '1';
   
   wait;

   
   end process StimuliProcess;   
      
end testbed;
