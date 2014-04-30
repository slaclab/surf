-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : SsiPrbsTb.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-29
-- Last update: 2014-04-30
-- Platform   : Vivado 2013.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the VcPrbsTx and VcPrbsRx modules
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

entity SsiPrbsTb is end SsiPrbsTb;

architecture testbed of SsiPrbsTb is

   -- Constants
   constant CLK_PERIOD_C       : time             := 10 ns;
   constant TPD_C              : time             := CLK_PERIOD_C/4;
   constant TX_PACKET_LENGTH_C : integer          := 16;
   constant FIFO_FULL_THRES_C  : integer          := 256;
   constant BIT_ERROR_C        : slv(31 downto 0) := x"00008421";  -- Generate errWordCnt and errbitCnt errors
   constant ADD_EOFE_C         : sl               := '1';          -- Generate errEofe error
   constant GEN_BUS_ERROR_C    : boolean          := true;

   constant USE_BUILT_IN_C  : boolean := false;
   constant GEN_SYNC_FIFO_C : boolean := false;
   
   constant NUMBER_WORDS_C : positive range 1 to 4 := 4;

   constant AXI_STREAM_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(NUMBER_WORDS_C*4);

   -- Signals
   signal clk,
      txBusy,
      rxBusy,
      trig,
      updatedResults,
      errMissedPacket,
      errLength,
      errDataBus,
      errEofe : sl := '0';
   signal rst : sl := '1';
   signal errWordCnt,
      errbitCnt,
      packetLength,
      packetRate : slv(31 downto 0) := (others => '0');
   
   signal mAxisMaster,
      sAxisMaster : AxiStreamMasterType;

   signal mAxisSlave,
      sAxisSlave : AxiStreamSlaveType;

   signal mAxisCtrl : AxiStreamCtrlType;
   signal sAxisCtrl : AxiStreamCtrlType;

begin

   trig <= not(rxBusy);

   -- Generate clocks and resets
   ClkRst_Inst : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,     -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 750 ns)   -- Hold reset for this long)
      port map (
         clkP => clk,
         clkN => open,
         rst  => rst,
         rstL => open); 

   -- VcPrbsTx (VHDL module to be tested)
   SsiPrbsTx_Inst : entity work.SsiPrbsTx
      generic map (
         TPD_G               => TPD_C,
         USE_BUILT_IN_G      => USE_BUILT_IN_C,
         GEN_SYNC_FIFO_G     => GEN_SYNC_FIFO_C,
         AXI_STREAM_CONFIG_G => AXI_STREAM_CONFIG_C)
      port map (
         -- Master Port (mAxisClk)
         mAxisSlave   => mAxisSlave,
         mAxisMaster  => mAxisMaster,
         mAxisClk     => clk,
         mAxisRst     => rst,
         -- Trigger Signal (locClk domain)
         trig         => trig,
         packetLength => toSlv(TX_PACKET_LENGTH_C, 32),
         busy         => txBusy,
         tDest        => (others => '0'),
         tId          => (others => '0'),
         sAxisCtrl    => mAxisCtrl,
         locClk       => clk,
         locRst       => rst);

   -- Process for mapping the VC buses and injecting bit error
   process(mAxisMaster, rst, sAxisSlave)
      variable master : AxiStreamMasterType;
      variable slave  : AxiStreamSlaveType;
      variable i      : integer;
      variable j      : integer;
   begin
      -- Latch the current value
      master := mAxisMaster;
      slave  := sAxisSlave;

      -- Check if we need to insert EOFE
      if (mAxisMaster.tLast = '1') then
         ssiSetUserEofe(AXI_STREAM_CONFIG_C,master,ADD_EOFE_C);
      else
         master.tUser := (others => '0');
      end if;

      -- Check if we need to generate bit errors
      if (mAxisMaster.tLast = '1') then
         -- Add bit errors to last word
         for i in 0 to 3 loop
            master.tData(i*32+31 downto i*32) := BIT_ERROR_C xor mAxisMaster.tData(31 downto 0);
         end loop;
      end if;

      -- Check if we need to generate a bus error
      if (GEN_BUS_ERROR_C = true) and (mAxisMaster.tLast = '1') then
         master.tData(127 downto 96) := (others => '0');
      end if;

      -- Reset
      if rst = '1' then
         master := AXI_STREAM_MASTER_INIT_C;
         slave  := AXI_STREAM_SLAVE_INIT_C;
      end if;

      -- Outputs
      sAxisMaster <= master;
      mAxisSlave  <= slave;
      
   end process;

   -- VcPrbsRx (VHDL module to be tested)
   SsiPrbsRx_Inst : entity work.SsiPrbsRx
      generic map (
         TPD_G               => TPD_C,
         USE_BUILT_IN_G      => USE_BUILT_IN_C,
         GEN_SYNC_FIFO_G     => GEN_SYNC_FIFO_C,
         AXI_STREAM_CONFIG_G => AXI_STREAM_CONFIG_C)
      port map (
         -- Streaming RX Data Interface (sAxisClk domain) 
         mAxisClk        => clk,
         sAxisClk        => clk,
         sAxisRst        => rst,
         sAxisMaster     => sAxisMaster,
         sAxisSlave      => sAxisSlave,
         sAxisCtrl       => sAxisCtrl,
         -- Error Detection Signals (sAxisClk domain)
         updatedResults  => updatedResults,
         busy            => rxBusy,
         errMissedPacket => errMissedPacket,
         errLength       => errLength,
         errDataBus      => errDataBus,
         errEofe         => errEofe,
         errWordCnt      => errWordCnt,
         errbitCnt       => errbitCnt,
         packetRate      => packetRate,
         packetLength    => packetLength);       

end testbed;
