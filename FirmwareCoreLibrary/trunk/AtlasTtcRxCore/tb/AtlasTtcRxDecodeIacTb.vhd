-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AtlasTtcRxDecodeIacTb.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory 
-- Created    : 2014-03-25
-- Last update: 2014-04-03
-- Platform   : Vivado 2013.3  
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Simulation testbed for AtlasTtcRxDecodeIacTb.vhd
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory 
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AtlasTtcRxPkg.all;
use work.Hamm32bitPkg.all;

entity AtlasTtcRxDecodeIacTb is end AtlasTtcRxDecodeIacTb;

architecture testbed of AtlasTtcRxDecodeIacTb is

   constant LOC_CLK_PERIOD_C : time := 10 ns;
   constant TPD_C            : time := LOC_CLK_PERIOD_C/4;
   
   constant NO_ERR_DATA_C : Slv32Array(0 to 3) := (
      x"000303B9",
      x"00030381",
      x"0003037E",
      x"000303B4");

   constant NO_ERR_CHECK_C : Slv7Array(0 to 3) := (
      "1000110",
      "1000111",
      "1011111",
      "0100111");     

   type StateType is (
      NO_ERROR_S,
      SBIT_S,
      DBIT_S,
      DONE_S);      
   signal state : StateType := NO_ERROR_S;

   signal locClk,
      locRst,
      validIn : sl := '0';
   signal pntr : slv(1 downto 0) := (others => '0');
   signal cnt  : slv(3 downto 0) := (others => '0');
   signal checkIn,
      check32Bit,
      encode32BitCheck : slv(6 downto 0) := (others => '0');
   signal dataIn,
      encode32Bitdata : slv(31 downto 0) := (others => '0');
   signal iac : AtlasTTCRxIacType := ATLAS_TTC_RX_IAC_INIT_C;

begin

   -- Generate clocks and resets
   ClkRst_loc : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => LOC_CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,     -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1000 ns)  -- Hold reset for this long)
      port map (
         clkP => locClk,
         clkN => open,
         rst  => locRst,
         rstL => open);  

   AtlasTtcRxDecodeIac_Inst : entity work.AtlasTtcRxDecodeIac
      generic map (
         TPD_G => TPD_C)   
      port map (
         validIn => validIn,
         dataIn  => dataIn,
         checkIn => checkIn,
         iac     => iac,
         -- Global Signals
         locClk  => locClk,
         locRst  => locRst);       

   encode32Bitdata  <= NO_ERR_DATA_C(conv_integer(pntr));
   check32Bit       <= hamming_encoder_32bit(bitReverse(encode32Bitdata));
   encode32BitCheck <= bitReverse(check32Bit);

   process(locClk)
   begin
      if rising_edge(locClk) then
         validIn <= '0' after TPD_C;
         -- Check for a reset
         if locRst = '1'then
            cnt     <= (others => '0') after TPD_C;
            pntr    <= (others => '0') after TPD_C;
            checkIn <= (others => '0') after TPD_C;
            dataIn  <= (others => '0') after TPD_C;
            state   <= NO_ERROR_S      after TPD_C;
         else
            -- Increment the counter
            cnt <= cnt + 1 after TPD_C;
            -- Check the counter
            if cnt = x"F" then
               -- Reset the counter
               cnt <= (others => '0') after TPD_C;
               -- State Machine
               case state is
                  ----------------------------------------------------------------------
                  when NO_ERROR_S =>
                     -- Send an error free pattern
                     validIn <= '1'                                after TPD_C;
                     dataIn  <= NO_ERR_DATA_C(conv_integer(pntr))  after TPD_C;
                     checkIn <= NO_ERR_CHECK_C(conv_integer(pntr)) after TPD_C;
                     -- Next State
                     state   <= SBIT_S                             after TPD_C;
                  ----------------------------------------------------------------------
                  when SBIT_S =>
                     -- Send a single bit error pattern
                     validIn   <= '1'            after TPD_C;
                     dataIn(1) <= not(dataIn(1)) after TPD_C;
                     -- Next State
                     state     <= DBIT_S         after TPD_C;
                  ----------------------------------------------------------------------
                  when DBIT_S =>
                     -- Send a double bit error pattern
                     validIn   <= '1'            after TPD_C;
                     dataIn(2) <= not(dataIn(2)) after TPD_C;
                     -- Increment the counter
                     pntr      <= pntr + 1       after TPD_C;
                     -- Check the counter value
                     if pntr = 3 then
                        -- Next State
                        state <= DONE_S after TPD_C;
                     else
                        -- Next State
                        state <= NO_ERROR_S after TPD_C;
                     end if;
                  ----------------------------------------------------------------------
                  when DONE_S =>
                     checkIn <= (others => '0') after TPD_C;
                     dataIn  <= (others => '0') after TPD_C;
               end case;
            end if;
         end if;
      end if;
   end process;

end testbed;
