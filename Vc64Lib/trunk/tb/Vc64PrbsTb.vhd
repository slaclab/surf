-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Vc64PrbsTb.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-07
-- Last update: 2014-04-09
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
use work.Vc64Pkg.all;

entity Vc64PrbsTb is end Vc64PrbsTb;

architecture testbed of Vc64PrbsTb is

   -- Constants
   constant CLK_PERIOD_C       : time             := 10 ns;
   constant TPD_C              : time             := CLK_PERIOD_C/4;
   constant TX_PACKET_LENGTH_C : integer          := 16;
   constant FIFO_FULL_THRES_C  : integer          := 4;
   constant BIT_ERROR_C        : slv(15 downto 0) := "1000" & "0100" & "0010" & "0001";  -- Generate errWordCnt and errbitCnt errors
   constant ADD_EOFE_C         : sl               := '1';  -- Generate errEofe error
   constant GEN_BUS_ERROR_C    : boolean          := true;

   -- Signals
   signal clk,
      txBusy,
      rxBusy,
      updatedResults,
      errMissedPacket,
      errLength,
      errDataBus,
      errEofe : sl := '0';
   signal rst  : sl               := '1';
   signal data : slv(15 downto 0) := (others => '0');
   signal errWordCnt,
      errbitCnt,
      packetLength,
      packetRate : slv(31 downto 0) := (others => '0');
   
   signal txCtrl : Vc64CtrlType := VC64_CTRL_INIT_C;
   signal txData,
      rxData,
      vcTxData : Vc64DataType := VC64_DATA_INIT_C;

begin

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
   Vc64PrbsTx_Inst : entity work.Vc64PrbsTx
      generic map (
         TPD_G              => TPD_C,
         FIFO_AFULL_THRES_G => FIFO_FULL_THRES_C)
      port map (
         -- Streaming TX Data Interface (vcTxClk domain) 
         vcTxCtrl     => txCtrl,
         vcTxData     => txData,
         vcTxClk      => clk,
         vcTxRst      => rst,
         -- Trigger Signal (locClk domain)
         trig         => '1',
         packetLength => toSlv(TX_PACKET_LENGTH_C, 32),
         busy         => txBusy,
         -- Clocks and Resets
         locClk       => clk,
         locRst       => rst);

   -- Process for mapping the VC buses and injecting bit error
   process(rst, txData)
      variable i : integer;
   begin
      if rst = '1' then
         -- Reset RX inputs
         rxData <= VC64_DATA_INIT_C;
         data   <= (others => '0');
      else
         -- Pass the signals to the RX module
         rxData.valid <= txData.valid;
         rxData.size  <= txData.size;
         rxData.vc    <= txData.vc;
         rxData.sof   <= txData.sof;
         rxData.eof   <= txData.eof;
         -- Check if we need to add EOFE
         rxData.eofe  <= txData.eof and (txData.eofe or ADD_EOFE_C);

         if txData.eof = '1' then
            -- add bit errors to last word
            for i in 15 downto 0 loop
               if BIT_ERROR_C(i) = '1' then
                  data(i) <= not(txData.data(i));
               end if;
            end loop;
            data                      <= txData.data(15 downto 0);
            rxData.data(31 downto 16) <= data;
            rxData.data(47 downto 32) <= data;
            rxData.data(63 downto 48) <= data;
         else
            data <= (others => '0');
            if GEN_BUS_ERROR_C and (txData.sof = '0') then
               rxData.data(63 downto 48) <= not txData.data(63 downto 48);
            else
               rxData.data(63 downto 48) <= txData.data(63 downto 48);
            end if;
            rxData.data(47 downto 0) <= txData.data;
         end if;
      end if;
   end process;

   -- VcPrbsRx (VHDL module to be tested)
   Vc64PrbsRx_Inst : entity work.Vc64PrbsRx
      generic map (
         TPD_G              => TPD_C,
         FIFO_AFULL_THRES_G => FIFO_FULL_THRES_C)
      port map (
         -- Streaming RX Data Interface (vcRxClk domain) 
         vcRxData        => rxData,
         vcRxCtrl        => txCtrl,
         vcRxClk         => clk,
         vcRxRst         => rst,
         -- Streaming TX Data Interface (vcTxClk domain) 
         vcTxData        => vcTxData,
         vcTxClk         => clk,
         vcTxRst         => rst,
         -- Error Detection Signals (vcRxClk domain)
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
