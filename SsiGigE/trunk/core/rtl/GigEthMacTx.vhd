---------------------------------------------------------------------------------
-- Title         : Gigabit Ethernet (1000 BASE X) MAC TX Layer
-- Project       : General Purpose Core
---------------------------------------------------------------------------------
-- File          : GigEthMacTx.vhd
-- Author        : Kurtis Nishimura, kurtisn@slac.stanford.edu
-- Created       : 05/22/2014
---------------------------------------------------------------------------------
-- Description:
-- MAC for gigabit ethernet.
-- User supplies data starting at destination MAC address
-- This module will send /S/, preamble, SOF, <user data>, FCS(CRC), /T/R/...
---------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
---------------------------------------------------------------------------------
-- Modification history:
-- 05/30/2014: created.
---------------------------------------------------------------------------------

LIBRARY ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.StdRtlPkg.all;
use work.GigEthPkg.all;

entity GigEthMacTx is 
   generic (
      TPD_G : time := 1 ns);
   port ( 
      -- 125 MHz ethernet clock in
      ethTxClk          : in sl;
      ethTxRst          : in sl := '0';
      -- User data to be sent
      userDataIn        : in slv(7 downto 0);
      userDataValid     : in sl;
      userDataFirstByte : in sl;
      userDataAck       : out sl;
      -- Data out to the GTX
      ethMacDataOut     : out EthMacDataType); 
end GigEthMacTx;

architecture rtl of GigEthMacTx is

   type StateType is (S_IDLE, S_SPD, S_PREAMBLE, S_SOF, S_FRAME_DATA, S_PAD, 
                      S_FCS_0, S_FCS_1, S_FCS_2, S_FCS_3, S_EPD, S_CAR);
   
   type RegType is record
      state         : StateType;
      oddEven       : sl;
      dataOut       : slv(7 downto 0);
      dataKOut      : sl;
      dataValidOut  : sl;
      crcDataIn     : slv(7 downto 0);
      crcDataValid  : sl;
      crcReset      : sl;
      crcByteCount  : slv(15 downto 0);
      userByteCount : slv(15 downto 0);
      preambleCount : slv(7 downto 0);
      userDataAck   : sl;
      fifoDataRdEn  : sl;
      fifoDataWrEn  : sl;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      state         => S_IDLE,
      oddEven       => '0',
      dataOut       => (others => '0'),
      dataKOut      => '0',
      dataValidOut  => '0',
      crcDataIn     => (others => '0'),
      crcDataValid  => '0',
      crcReset      => '0',
      crcByteCount  => (others => '0'),
      userByteCount => (others => '0'),
      preambleCount => (others => '0'),
      userDataAck   => '0',
      fifoDataRdEn  => '0',
      fifoDataWrEn  => '0');
   
   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal crcOut          : slv(31 downto 0);
   signal fifoDataOut     : slv(7 downto 0);
   signal fifoDataValid   : sl;
   signal fifoAlmostEmpty : sl;
   
   -- attribute dont_touch : string;
   -- attribute dont_touch of r : signal is "true";
   -- attribute dont_touch of crcOut : signal is "true";
   
begin

   -- Calculate the CRC on incoming data so we can append it as the FCS
   U_Crc32 : entity work.Crc32Parallel
      generic map (
         BYTE_WIDTH_G => 1,
         CRC_INIT_G   => x"FFFFFFFF",
         TPD_G        => TPD_G)
      port map (
         crcOut        => crcOut,
         crcClk        => ethTxClk,
         crcDataValid  => r.crcDataValid,
         crcDataWidth  => (others => '0'),
         crcIn         => r.crcDataIn,
         crcReset      => r.crcReset);

   -- Short buffer to allow for queuing up a few data words
   -- while we send preambles, etc.  Also allows calculation of the CRC in time
   -- for transmission.
   U_DataBuffer : entity work.FifoMux
      generic map (
         TPD_G              => TPD_G,
         CASCADE_SIZE_G     => 1,
         LAST_STAGE_ASYNC_G => false,
         GEN_SYNC_FIFO_G    => true,
         FWFT_EN_G          => true,
         WR_DATA_WIDTH_G    => 8,
         RD_DATA_WIDTH_G    => 8,
         ADDR_WIDTH_G       => 12)
      port map (
         rst          => ethTxRst,
         wr_clk       => ethTxClk,
         wr_en        => userDataValid,
         din          => userDataIn,
         rd_clk       => ethTxClk,
         rd_en        => r.fifoDataRdEn,
         dout         => fifoDataOut,
         valid        => fifoDataValid,
         almost_empty => fifoAlmostEmpty);
      
   comb : process(r,userDataIn,userDataValid,ethTxRst,fifoDataOut,fifoDataValid,fifoAlmostEmpty,crcOut) is
      variable v : RegType;
   begin
      v := r;

      -- Always toggle the odd/even bit
      v.oddEven := not(r.oddEven);
      
      -- Logic to handle the CRC data and reset
      -- It's out of sync with the state machine so that
      -- we can have the value ready immediately after 
      -- the user data + padding, so it's handled separately here
      if (r.state = S_IDLE) then
         v.crcDataIn    := userDataIn;
         if (userDataValid = '1') then
            v.crcByteCount := r.crcByteCount + 1;
            v.crcDataValid := '1';
            v.crcReset     := '0';
         else
            v.crcByteCount := (others => '0');
            v.crcReset     := '1';
         end if;
      else
         if (userDataValid = '1') then
            v.crcDataIn    := userDataIn;
            v.crcDataValid := '1';
            v.crcByteCount := r.crcByteCount + 1;
         elsif (r.crcByteCount < ETH_MIN_SIZE_C-4) then
            v.crcDataIn    := ETH_PAD_C;
            v.crcDataValid := '1';
            v.crcByteCount := r.crcByteCount + 1;
         else
            v.crcDataIn    := userDataIn;
            v.crcDataValid := '0';
         end if;
      end if;

      -- There is a peculiarity in the way the valid signal was previously
      -- required to be asserted for the TEMAC cores.  Due to handshaking with the 
      -- ack the first byte is repeated twice, so we want to throw away one of those
      -- here.
      v.fifoDataWrEn := userDataValid;
      
      -- The rest of the state machine just sends data 
      -- following the 1000-BASEX and Ethernet standards.
      case(r.state) is 
         -- In idle, transmit commas forever
         when S_IDLE =>
            v.fifoDataWrEn := '0';
            -- Current frame is odd, next frame will be even
            if (r.oddEven = '1') then
               v.dataOut   := (K_COM_C);
               v.dataKOut  := '1';
               -- Data is always valid but we should sync up with an even word
               -- for benefit of the 8-to-16 stage that comes after this.
               v.dataValidOut := '1';
            -- Current frame is even, next frame will be odd
            else
               v.dataOut   := (D_162_C);
               v.dataKOut  := '0';
            end if;
            v.userByteCount := (others => '0');
            v.preambleCount := (others => '0');
            v.fifoDataRdEn  := '0';
            v.userDataAck   := '0';
            if (userDataValid = '1') then
               v.state        := S_SPD;
            end if;
         -- Once we see good data, send /S/ in next even position
         when S_SPD =>
            -- Send acknowledge
            v.userDataAck   := '0';
            -- If next frame is even, transmit /S/ and move on to next state
            if (r.oddEven = '1') then
               v.dataOut   := (K_SOP_C);
               v.dataKOut  := '1';
               v.state     := S_PREAMBLE;
            -- Next frame is odd, finish the comma sequence and stay here
            else
               v.dataOut   := (D_162_C);
               v.dataKOut  := '0';
            end if;
         -- Then send the preamble
         when S_PREAMBLE =>
            v.userDataAck  := '1';
            v.dataOut       := ETH_PRE_C;
            v.dataKOut      := '0';
            v.preambleCount := r.preambleCount + 1;
            if (r.preambleCount = 6) then
               v.state := S_SOF;
            end if;
         -- Then send the ethernet SOF
         when S_SOF =>
            v.userDataAck  := '1';
            v.dataOut      := ETH_SOF_C;
            v.dataKOut     := '0';
            v.state        := S_FRAME_DATA;
            v.fifoDataRdEn := '1';
         -- Move on to the user data
         when S_FRAME_DATA =>
            if (r.userByteCount < ETH_MIN_SIZE_C-4-1) then
               v.userByteCount := r.userByteCount + 1;
            end if;
            v.dataKOut      := '0';
            v.dataOut       := fifoDataOut;
            v.fifoDataRdEn  := fifoDataValid;
            if (fifoAlmostEmpty = '1' or fifoDataValid = '0') then
               if (r.userByteCount < ETH_MIN_SIZE_C-4-1) then
                  v.state := S_PAD;
               else
                  v.state := S_FCS_0;
               end if;
            end if;
         -- If we need padding, do it here, otherwise, move on to FCS
         when S_PAD =>
            v.userByteCount := r.userByteCount + 1;
            v.dataKOut      := '0';
            v.dataOut       := ETH_PAD_C;
            v.fifoDataRdEn  := '0';
            if (r.userByteCount >= ETH_MIN_SIZE_C-4-1) then
               v.state := S_FCS_0;
            end if;
         -- Send the various bytes of FCS (CRC)
         when S_FCS_0 =>
            v.dataKOut  := '0';
            v.dataOut   := crcOut(31 downto 24);
            v.state := S_FCS_1;
         when S_FCS_1 =>
            v.dataKOut  := '0';
            v.dataOut   := crcOut(23 downto 16);
            v.state := S_FCS_2;
         when S_FCS_2 =>
            v.dataKOut  := '0';
            v.dataOut   := crcOut(15 downto 8);
            v.state := S_FCS_3;
         when S_FCS_3 =>
            v.dataKOut  := '0';
            v.dataOut   := crcOut(7 downto 0);
            v.state := S_EPD;
         -- Then send /T/
         when S_EPD =>
            v.dataKOut  := '1';
            v.dataOut   := K_EOP_C;
            v.state     := S_CAR;
         -- Send any /R/ required
         when S_CAR =>
            v.dataKOut  := '1';
            v.dataOut   := K_CAR_C;
            -- Make sure we put IDLE back on an even boundary
            if (r.oddEven = '0') then
               v.state     := S_IDLE;
            end if;
         when others =>
            v.state := S_IDLE;
      end case;
      
      -- Reset logic
      if (ethTxRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Outputs to ports
      ethMacDataOut.data      <= r.dataOut;
      ethMacDataOut.dataK     <= r.dataKOut;
      ethMacDataOut.dataValid <= r.dataValidOut;
--      userDataAck             <= r.userDataAck;
--      userDataAck             <= r.fifoDataWrEn;
      userDataAck <= userDataValid;
      
      rin <= v;

   end process;

   seq : process (ethTxClk) is
   begin
      if (rising_edge(ethTxClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;   

end rtl;
