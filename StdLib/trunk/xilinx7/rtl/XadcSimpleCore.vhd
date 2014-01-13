-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : XadcSimpleCore.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-01-10
-- Last update: 2014-01-10
-- Platform   : Vivado 2013.4
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: This core only measures internal voltages and temperature
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;

library unisim;
use unisim.vcomponents.all;

entity XadcSimpleCore is
   -- Default Generic Configuration:
   -- Interface Selected = DRP
   -- XADC Operating Mode = channel_sequencer
   -- Timing Mode = Continuous
   -- DCLK Freq = 156.25 MHz
   -- Sequencer Mode = Continuous
   -- Channel Averaging = 256
   -- Enable External Mux = False
   -- No Flags enabled
   -- Only calibration, temperature, VCCINT, VCCAUX, and VBRAM are enabled channels
   generic (
      INIT_40_G          : bit_vector := x"3000";  -- config reg 0
      INIT_41_G          : bit_vector := x"210F";  -- config reg 1
      INIT_42_G          : bit_vector := x"0700";  -- config reg 2
      INIT_43_G          : bit_vector := x"0000";  -- test reg 0
      INIT_44_G          : bit_vector := x"0000";  -- test reg 1
      INIT_45_G          : bit_vector := x"0000";  -- test reg 2
      INIT_46_G          : bit_vector := x"0000";  -- test reg 3
      INIT_47_G          : bit_vector := x"0000";  -- test reg 4
      INIT_48_G          : bit_vector := x"7701";  -- Sequencer channel selection
      INIT_49_G          : bit_vector := x"0000";  -- Sequencer channel selection
      INIT_4A_G          : bit_vector := x"4700";  -- Sequencer Average selection
      INIT_4B_G          : bit_vector := x"0000";  -- Sequencer Average selection
      INIT_4C_G          : bit_vector := x"0000";  -- Sequencer Bipolar selection
      INIT_4D_G          : bit_vector := x"0000";  -- Sequencer Bipolar selection
      INIT_4E_G          : bit_vector := x"0000";  -- Sequencer Acq time selection
      INIT_4F_G          : bit_vector := x"0000";  -- Sequencer Acq time selection
      INIT_50_G          : bit_vector := x"0000";  -- Temp alarm trigger
      INIT_51_G          : bit_vector := x"0000";  -- Vccint upper alarm limit
      INIT_52_G          : bit_vector := x"0000";  -- Vccaux upper alarm limit
      INIT_53_G          : bit_vector := x"0000";  -- Temp alarm OT upper
      INIT_54_G          : bit_vector := x"0000";  -- Temp alarm reset
      INIT_55_G          : bit_vector := x"0000";  -- Vccint lower alarm limit
      INIT_56_G          : bit_vector := x"0000";  -- Vccaux lower alarm limit
      INIT_57_G          : bit_vector := x"0000";  -- Temp alarm OT reset
      INIT_58_G          : bit_vector := x"0000";  -- Vbram upper alarm limit
      INIT_59_G          : bit_vector := x"0000";  -- Reserved: Reserved for future use
      INIT_5A_G          : bit_vector := x"0000";  -- Reserved: Reserved for future use
      INIT_5B_G          : bit_vector := x"0000";  -- Reserved: Reserved for future use
      INIT_5C_G          : bit_vector := x"0000";  -- Vbram lower alarm limit
      INIT_5D_G          : bit_vector := x"0000";  -- Reserved: Reserved for future use
      INIT_5E_G          : bit_vector := x"0000";  -- Reserved: Reserved for future use
      INIT_5F_G          : bit_vector := x"0000";  -- Reserved: Reserved for future use
      SIM_DEVICE_G       : string     := "7SERIES";
      SIM_MONITOR_FILE_G : string     := "design.txt");
   port (
      -- Parallel interface
      locReq  : in  sl;
      locRnW  : in  sl;
      locAck  : out sl;
      locAddr : in  slv(6 downto 0);
      locDin  : in  slv(15 downto 0);
      locDout : out slv(15 downto 0);
      --XADC I/O ports
      vpIn    : in  sl;
      vnIn    : in  sl;
      --Global Signals
      locClk  : in  sl;
      locRst  : in  sl);            
end XadcSimpleCore;

architecture mapping of XadcSimpleCore is
   type StateType is (IDLE_S,
                      DRDY_WAIT_S,
                      HANDSHAKE_S);
   signal state : StateType        := IDLE_S;
   signal den,
      dwe,
      drdy : sl := '0';
   signal dout : slv(15 downto 0) := (others=>'0');
begin

   process(locClk)
   begin
      if rising_edge(locClk) then
         den <= '0';
         dwe <= '0';
         if locRst = '1' then
            locAck <= '0';
            locDout <= (others=>'0');
            state  <= IDLE_S;
         else
            case (state) is
               ----------------------------------------------------------------------
               when IDLE_S =>
                  if locReq = '1' then
                     den   <= '1';
                     dwe   <= not(locRnW);
                     state <= DRDY_WAIT_S;
                  end if;
                  ----------------------------------------------------------------------
               when DRDY_WAIT_S =>
                  if drdy = '1' then
                     locAck <= '1';
                     locDout <= dout;
                     state  <= HANDSHAKE_S;
                  end if;
                  ----------------------------------------------------------------------
               when HANDSHAKE_S =>
                  if locReq = '0' then
                     locAck <= '0';
                     state  <= IDLE_S;
                  end if;
                  ----------------------------------------------------------------------
            end case;
         end if;
      end if;
   end process;

   XADC_Inst : XADC
      generic map(
         INIT_40          => INIT_40_G,
         INIT_41          => INIT_41_G,
         INIT_42          => INIT_42_G,
         INIT_43          => INIT_43_G,
         INIT_44          => INIT_44_G,
         INIT_45          => INIT_45_G,
         INIT_46          => INIT_46_G,
         INIT_47          => INIT_47_G,
         INIT_48          => INIT_48_G,
         INIT_49          => INIT_49_G,
         INIT_4A          => INIT_4A_G,
         INIT_4B          => INIT_4B_G,
         INIT_4C          => INIT_4C_G,
         INIT_4D          => INIT_4D_G,
         INIT_4E          => INIT_4E_G,
         INIT_4F          => INIT_4F_G,
         INIT_50          => INIT_50_G,
         INIT_51          => INIT_51_G,
         INIT_52          => INIT_52_G,
         INIT_53          => INIT_53_G,
         INIT_54          => INIT_54_G,
         INIT_55          => INIT_55_G,
         INIT_56          => INIT_56_G,
         INIT_57          => INIT_57_G,
         INIT_58          => INIT_58_G,
         INIT_59          => INIT_59_G,
         INIT_5A          => INIT_5A_G,
         INIT_5B          => INIT_5B_G,
         INIT_5C          => INIT_5C_G,
         INIT_5D          => INIT_5D_G,
         INIT_5E          => INIT_5E_G,
         INIT_5F          => INIT_5F_G,
         SIM_DEVICE       => SIM_DEVICE_G,
         SIM_MONITOR_FILE => SIM_MONITOR_FILE_G)
      port map (
         CONVST       => '0',
         CONVSTCLK    => '0',
         DADDR        => locAddr,
         DCLK         => locClk,
         DEN          => den,
         DI           => locDin,
         DWE          => dwe,
         RESET        => locRst,
         VAUXN        => (others => '0'),
         VAUXP        => (others => '0'),
         ALM          => open,
         BUSY         => open,
         CHANNEL      => open,
         DO           => dout,
         DRDY         => drdy,
         EOC          => open,
         EOS          => open,
         JTAGBUSY     => open,
         JTAGLOCKED   => open,
         JTAGMODIFIED => open,
         OT           => open,
         MUXADDR      => open,
         VN           => vnIn,
         VP           => vpIn);   

end mapping;
