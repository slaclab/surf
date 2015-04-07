-------------------------------------------------------------------------------
-- Title         : Ethernet Interface Module, 8-bit word receive
-- Project       : General Gigabit Ethernet for SSI
-------------------------------------------------------------------------------
-- File          : GigEthUdpFrameRx.vhd
-- Author        : Kurtis Nishimura
-- Created       : 09/05/2014
-------------------------------------------------------------------------------
-- Description:
-- Translates 8-bit Rx data into 32-bit SSI data.
-- Protocol assumes first word of any packet is a header with the following 
-- bit definitions:
--   Word0[31:28] - lane[3:0]
--   Word0[27:24] - vc[3:0]
--   Word0[23]    - continuation bit (message continues next packet)
--   Word0[22:0]  - reserved
-- Other words are payload data.
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 09/05/2014: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
Library Unisim;
USE ieee.std_logic_1164.ALL;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.StdRtlPkg.all;
use work.EthClientPackage.all;

entity GigEthUdpFrameRx is 
   generic (
      TPD_G : time := 1 ns);
   port ( 
      -- Ethernet clock & reset
      gtpClk         : in  sl;                -- 125Mhz master clock
      gtpClkRst      : in  sl;                -- Synchronous reset input

      -- User Receive Interface (connection out to user interfaces)
      userRxValid    : out sl;
      userRxData     : out slv(31 downto 0);  -- Ethernet RX Data
      userRxSOF      : out sl;                -- Ethernet RX Start of Frame
      userRxEOF      : out sl;                -- Ethernet RX End of Frame
      userRxEOFE     : out sl;                -- Ethernet RX End of Frame Error
      userRxVc       : out slv(1  downto 0);  -- Ethernet RX Virtual Channel

      -- UDP Block Receive Interface (connection from MAC)
      udpRxValid     : in  sl;
      udpRxData      : in  slv(7  downto 0);
      udpRxGood      : in  sl;
      udpRxError     : in  sl;
      udpRxCount     : in  slv(15 downto 0));
end GigEthUdpFrameRx;

architecture GigEthUdpFrameRx of GigEthUdpFrameRx is 
   type StateType is (IDLE_S, READ_S, HEAD_S, BYTE_S, DUMP_S);

   type RegType is record
      continueBit  : sl;
      firstWord    : sl;
      rdataFifoRd  : sl;
      rcountFifoRd : sl;
      rxFifoData   : slv(31 downto 0);
      rxFifoSof    : sl;
      rxFifoEof    : sl;
      rxFifoEofe   : sl;
      rxFifoVc     : slv(1 downto 0);
      rxFifoValid  : sl;
      rxFirst      : sl;
      rxLast       : sl;
      rxCount      : slv(15 downto 0);
      byteCount    : slv(1 downto 0);
      state        : StateType;
   end record;
   constant REG_INIT_C : RegType := (
      continueBit  => '0',
      firstWord    => '0',
      rdataFifoRd  => '0',
      rcountFifoRd => '0',
      rxFifoData   => (others => '0'),
      rxFifoSof    => '0',
      rxFifoEof    => '0',
      rxFifoEofe   => '0',
      rxFifoVc     => (others => '0'),
      rxFifoValid  => '0',
      rxFirst      => '0',
      rxLast       => '0',
      rxCount      => (others => '0'),
      byteCount    => (others => '0'),
      state        => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
   -- Interfaces to the FIFOs
   signal rdataFifoDout   : slv(7 downto 0);
   signal udpRxGoodError  : sl;
   signal rcountFifoEmpty : sl;
   signal rcountFifoError : sl;
   signal rcountFifoGood  : sl;
   signal rcountFifoDout  : slv(15 downto 0);

   -- attribute dont_touch : string;
   -- attribute dont_touch of r : signal is "true";
   
begin

   ---------------------------
   --- Receive
   ---------------------------

   -- Receiver Data Fifo (8 x 16k)
   U_RxDataFifo : entity work.FifoMux
      generic map (
         TPD_G              => TPD_G,
         LAST_STAGE_ASYNC_G => false,
         RST_POLARITY_G     => '1',
         GEN_SYNC_FIFO_G    => true,
         FWFT_EN_G          => true,
         WR_DATA_WIDTH_G    => 8,
         RD_DATA_WIDTH_G    => 8,
         ADDR_WIDTH_G       => 14)
      port map (
         -- Resets
         rst           => gtpClkRst,
         --Write Ports (wr_clk domain)
         wr_clk        => gtpClk,
         wr_en         => udpRxValid,
         din           => udpRxData,
         full          => open,
         --Read Ports (rd_clk domain)
         rd_clk        => gtpClk,
         rd_en         => r.rdataFifoRd,
         dout          => rdataFifoDout,
         rd_data_count => open,
         empty         => open);           
   
   -- Receiver Data Count Fifo (18x1k)
   U_RxCntFifo : entity work.FifoMux
      generic map (
         TPD_G              => TPD_G,
         LAST_STAGE_ASYNC_G => false,
         RST_POLARITY_G     => '1',
         GEN_SYNC_FIFO_G    => true,
         FWFT_EN_G          => true,
         WR_DATA_WIDTH_G    => 18,
         RD_DATA_WIDTH_G    => 18,
         ADDR_WIDTH_G       => 14)
      port map (
         -- Resets
         rst               => gtpClkRst,
         --Write Ports (wr_clk domain)
         wr_clk            => gtpClk,
         wr_en             => udpRxGoodError,
         din(17)           => udpRxError,
         din(16)           => udpRxGood,
         din(15 downto 0)  => udpRxCount,
         full              => open,
         --Read Ports (rd_clk domain)
         rd_clk            => gtpClk,
         rd_en             => r.rcountFifoRd,
         dout(17)          => rcountFifoError,
         dout(16)          => rcountFifoGood,
         dout(15 downto 0) => rcountFifoDout,
         rd_data_count     => open,
         empty             => rcountFifoEmpty);
         
   udpRxGoodError <= udpRxError or udpRxGood;

   
   comb : process (r,rcountFifoEmpty, rcountFifoDout, rcountFifoError, 
                   rcountFifoGood, rdataFifoDout, gtpClkRst)
      variable v : RegType;
   begin
      v := r;
      
      -- Reset any pulsed signals
      -- None to reset

      -- State outputs & next state choices
      case (r.state) is
         -- Monitor for a complete packet (by monitoring rcountFifoEmpty)
         when IDLE_S =>
            v.rdataFifoRd := '0';
            v.byteCount   := (others => '0');
            v.rxFifoValid := '0';
            v.rxFifoSof   := '0';
            v.rxFifoEof   := '0';            
            -- FWFT is enabled so valid count data coincides with empty = '0'
            if (rcountFifoEmpty = '0') then
               v.rcountFifoRd := '1';
               v.rxCount      := rcountFifoDout;
               v.state        := READ_S;
            end if;
         -- Begin reading
         when READ_S =>
            -- Disable the count read so that we only read one packet at a time
            v.rcountFifoRd := '0';
            -- Check some simple error conditions.  If any of these are seen, 
            -- dump the frame.  The following errors are supported:
            -- 1) Frame has an error from UDP block
            -- 2) Frame is smaller than 2x 32-bit words (header + at least one payload)
            -- 3) Frame is not a multiple of 4 bytes
            if (rcountFifoError = '1' or r.rxCount < 8 or r.rxCount(1 downto 0) /= "00") then
               v.state := DUMP_S;
            -- TODO: 4) Error conditions regarding split frames should go here.
            -- Otherwise we appear to have a valid frame
            else
               -- Checks for mid-frame data should go here
               v.firstWord   := '1';               
               -- Enable the data read and decrement the read counter
               v.rdataFifoRd  := '1';
               v.rxCount      := r.rxCount - 1;
               v.state        := HEAD_S;
            end if;
         -- Parse data from the header
         -- Assume data is coming in network order (most signif byte first)
         when HEAD_S =>
            v.rdataFifoRd := '1';
            v.rxCount     := r.rxCount - 1;
            v.byteCount   := r.byteCount + 1;
            -- Move on to the next state after we finish reading first word
            if (r.byteCount = 3) then
               v.state       := BYTE_S;
            end if;
            -- Interpret first 32-bit word
            case (r.byteCount) is
               when "00" => --Bits 31:24 - lane[3:0] & vc[3:0]
                  v.rxFifoVc := rdataFifoDout(1 downto 0);
               when "01" => --Bits 23:16 - continuation & zero[6:0]
                  v.continueBit := rdataFifoDout(7);
               when "10" => --Bits 15:8 - reserved
               when "11" => --Bits 7:0 - reserved
               when others =>
            end case;
         -- Parse payload data and reorder for SSI compatibility
         when BYTE_S =>
            v.rxCount     := r.rxCount - 1;
            v.byteCount   := r.byteCount + 1;
            -- Send words on the last byte
            if (r.byteCount = 3) then
               v.rxFifoValid := '1';
               if (r.firstWord = '1') then
                  v.rxFifoSof := '1';
                  v.firstWord := '0';
               else
                  v.rxFifoSof := '0';
               end if;
            else
               v.rxFifoValid := '0';
            end if;
            -- If we're reading the last word now, set EOF based on 
            -- the continuation bit.
            if (r.rxCount = 0) then
               v.rdataFifoRd := '0';
               v.rxFifoEof   := not(r.continueBit);
               v.state       := IDLE_S;
            -- Otherwise, keep on reading and stay in this state
            else
               v.rdataFifoRd := '1';
            end if;
            -- Shuffle data to match SSI byte and word order
            case (r.bytecount) is
               when "00" => 
                  v.rxFifoData(31 downto 24) := rdataFifoDout;
               when "01" =>
                  v.rxFifoData(23 downto 16) := rdataFifoDout;
               when "10" =>
                  v.rxFifoData(15 downto 8) := rdataFifoDout;
               when "11" =>     
                  v.rxFifoData(7 downto 0) := rdataFifoDout;
               when others =>
            end case;
         -- Error state, dump all data from fifo
         -- corresponding to this packet
         when DUMP_S  =>
            v.rxFifoSof    := '0';
            v.rxFifoEof    := '0';
            v.rxFifoData   := (others => '0');
            v.rxFifoVc     := (others => '0');
            v.rxFifoValid  := '0';

            v.rdataFifoRd  := '1';
            v.rxCount      := r.rxCount - 1;
            if (v.rxCount = 0) then
               v.state := IDLE_S;
            end if;
      end case;
            
      -- Synchronous reset
      if gtpClkRst = '1' then
         v := REG_INIT_C;
      end if;
      
      -- Set up variable for next clock cycle
      rin <= v;
      
      -- Outputs to ports
      userRxValid    <= r.rxFifoValid;
      userRxData     <= r.rxFifoData;
      userRxSOF      <= r.rxFifoSof;
      userRxEOF      <= r.rxFifoEof;
      userRxEOFE     <= r.rxFifoEofe;
      userRxVc       <= r.rxFifoVc;
      
   end process;
   
   seq : process (gtpClk) is
   begin
      if rising_edge(gtpClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end GigEthUdpFrameRx;
