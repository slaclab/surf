-------------------------------------------------------------------------------
-- Title         : Ethernet Interface Module, 8-bit word receive
-- Project       : General Gigabit Ethernet for SSI
-------------------------------------------------------------------------------
-- File          : GigEthUdpFrameTx.vhd
-- Author        : Kurtis Nishimura
-- Created       : 09/16/2014
-------------------------------------------------------------------------------
-- Description:
-- Translates 32-bit SSI data into 8-bit UDP data.
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

entity GigEthUdpFrameTx is 
   generic (
      TPD_G      : time := 1 ns;
      EN_JUMBO_G : boolean := false);
   port ( 
      -- Ethernet clock & reset
      gtpClk         : in  sl;               -- 125Mhz master clock
      gtpClkRst      : in  sl;               -- Synchronous reset input

      -- User Transmit Interface
      userTxValid    : in  sl;
      userTxReady    : out sl;
      userTxData     : in  slv(31 downto 0); -- Ethernet TX Data
      userTxSOF      : in  sl;               -- Ethernet TX Start of Frame
      userTxEOF      : in  sl;               -- Ethernet TX End of Frame
      userTxVc       : in  slv(1  downto 0); -- Ethernet TX Virtual Channel

      -- UDP Block Transmit Interface (connection to MAC)
      udpTxValid     : out sl;
      udpTxFast      : out sl;
      udpTxReady     : in  sl;
      udpTxData      : out slv(7  downto 0);
      udpTxLength    : out slv(15 downto 0));
end GigEthUdpFrameTx;

architecture GigEthUdpFrameTx of GigEthUdpFrameTx is 
   type StateType is (IDLE_S, WAIT_S, HEAD_S, BYTE_S);
   
   type RegType is record
      udpTxValid     : sl;
      udpTxData      : slv(7 downto 0);
      udpTxLength    : slv(15 downto 0);
      tdataFifoDin   : slv(34 downto 0);
      tdataFifoWr    : sl;
      tcountFifoDin  : slv(12 downto 0);
      tcountFifoWr   : sl;
      tdataCount     : slv(11 downto 0);
      tdataFifoRd    : sl;
      tcountFifoRd   : sl;
      byteCount      : slv( 1 downto 0);
      txCount        : slv(11 downto 0);
      continueBit    : sl;
      state          : StateType;
   end record;
   constant REG_INIT_C : RegType := (
      udpTxValid    => '0',
      udpTxData     => (others => '0'),
      udpTxLength   => (others => '0'),
      tdataFifoDin  => (others => '0'),
      tdataFifoWr   => '0',
      tcountFifoDin => (others => '0'),
      tcountFifoWr  => '0',
      tdataCount    => x"002",  --Pre-counts the header
      tdataFifoRd   => '0',
      tcountFifoRd  => '0',
      byteCount     => (others => '0'),
      txCount       => (others => '0'),
      continueBit   => '0',
      state         => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
   -- Signals from the FIFOs
   signal tdataFifoFull     : std_logic;
   signal tdataFifoAFull    : std_logic;   
   signal tdataFifoDout     : std_logic_vector(34 downto 0);
   signal tcountFifoFull    : std_logic;
   signal tcountFifoAFull   : std_logic;
   signal tcountFifoDout    : std_logic_vector(12 downto 0);
   signal tcountFifoEmpty   : std_logic;
   
   -- Jumbo frame cutoff sizes (in 32-bit words)
   --------------------------------------------------
   -- Officially 1500 bytes, 1440 to be conservative, divided by 4 = 360 (0x168)
   constant TX_REG_SIZE_C   : std_logic_vector(11 downto 0) := x"168"; --Was 2BB
   -- Officially 9k bytes, but hardware dependent, let's go with 5k / 4 = 1250 (0x4E2)
   constant TX_JUMBO_SIZE_C : std_logic_vector(11 downto 0) := x"4E2"; --Was F9F
   -- Decide between regular and jumbo
   constant TX_BREAK_SIZE_C : std_logic_vector(11 downto 0) := ite(EN_JUMBO_G, TX_JUMBO_SIZE_C, TX_REG_SIZE_C);   
   
   -- attribute dont_touch : string;
   -- attribute dont_touch of r : signal is "true";
   -- attribute dont_touch of tdataFifoFull : signal is "true";
   -- attribute dont_touch of tdataFifoAFull : signal is "true";
   
begin

   ---------------------------
   --- Transmit
   ---------------------------
   
   -- Transmitter data fifo (19x8k)
   U_TxDataFifo : entity work.FifoMux
      generic map (
         TPD_G              => TPD_G,
         LAST_STAGE_ASYNC_G => false,
         RST_POLARITY_G     => '1',
         GEN_SYNC_FIFO_G    => true,
         FWFT_EN_G          => true,
         WR_DATA_WIDTH_G    => 35,
         RD_DATA_WIDTH_G    => 35,
         ADDR_WIDTH_G       => 13,
         FULL_THRES_G       => 7000)
      port map (
         -- Resets
         rst           => gtpClkRst,
         --Write Ports (wr_clk domain)
         wr_clk        => gtpClk,
         wr_en         => r.tdataFifoWr,
         din           => r.tdataFifoDin,
         full          => tdataFifoFull,
         almost_full   => tdataFifoAFull,
         --Read Ports (rd_clk domain)
         rd_clk        => gtpClk,
         rd_en         => r.tdataFifoRd,
         dout          => tdataFifoDout,
         empty         => open);            
   
   -- Transmitter Data Count Fifo (13x1k)
   U_TxCntFifo : entity work.FifoMux
      generic map (
         TPD_G              => TPD_G,
         LAST_STAGE_ASYNC_G => false,
         RST_POLARITY_G     => '1',
         GEN_SYNC_FIFO_G    => true,
         FWFT_EN_G          => true,
         WR_DATA_WIDTH_G    => 13,
         RD_DATA_WIDTH_G    => 13,
         ADDR_WIDTH_G       => 10,
         FULL_THRES_G       => 900)
      port map (
         -- Resets
         rst           => gtpClkRst,
         --Write Ports (wr_clk domain)
         wr_clk        => gtpClk,
         wr_en         => r.tcountFifoWr,
         din           => r.tcountFifoDin,
         full          => tcountFifoFull,
         almost_full   => tcountFifoAFull,
         --Read Ports (rd_clk domain)
         rd_clk        => gtpClk,
         rd_en         => r.tcountFifoRd,
         dout          => tcountFifoDout,
         empty         => tcountFifoEmpty);           

   ------------------------------
   -- Transmit state machine   
   ------------------------------
   comb : process (r,userTxSOF,userTxVc,userTxData,userTxValid,tdataFifoAFull,
                   tcountFifoAFull, tcountFifoEmpty, userTxEOF, tdataFifoDout,
                   tcountFifoDout, gtpClkRst, udpTxReady)
      variable v : RegType;
   begin
      v := r;
      
      -- Reset any pulsed signals
         -- None to reset

      -- Logic to write incoming user data to fifo
      v.tdataFifoDin(34)           := userTxSOF;
      v.tdataFifoDin(33 downto 32) := userTxVc;
      v.tdataFifoDin(31 downto  0) := userTxData;
      v.tdataFifoWr                := userTxValid and (not (tdataFifoAFull or tcountFifoAFull));
      -- Count FIFO
      if userTxValid = '1' and tdataFifoAFull = '0' and tcountFifoAFull = '0' and (userTxEOF = '1' or r.tdataCount = TX_BREAK_SIZE_C) then
         v.tcountFifoWr := '1';
      else
         v.tcountFifoWr := '0';
      end if;
      v.tcountFifoDin(12)          := userTxEOF;
      v.tcountFifoDin(11 downto 0) := r.tdataCount;

      -- Counter
      if userTxValid = '1' and tdataFifoAFull = '0' and tcountFifoAFull = '0' then
         if userTxEOF = '1' or r.tdataCount = TX_BREAK_SIZE_C then
            v.tdataCount := x"002";
         else
            v.tdataCount := r.tdataCount + 1;
         end if;
      end if;
      
      -- State outputs & next state choices
      case (r.state) is
         -- Monitor for a complete packet (by monitoring tcountFifoEmpty)
         when IDLE_S =>
            v.tdataFifoRd  := '0';
            v.tcountFifoRd := '0';
            v.udpTxValid   := '0';
            v.udpTxData    := (others => '0');
            v.udpTxLength  := (others => '0');
            v.txCount      := (others => '0');
            v.byteCount    := (others => '0');
            -- FWFT is enabled so valid count data coincides with empty = '0'
            if (tcountFifoEmpty = '0') then
               v.tcountFifoRd := '1';
               v.txCount      := tcountFifoDout(11 downto 0);
               v.udpTxLength  := "00" & tcountFifoDout(11 downto 0) & "00"; --Convert # words to # bytes
               v.continueBit  := not(tcountFifoDout(12));
               v.state        := HEAD_S;
            end if;
         -- Wait for EthClientUdp to send the header before sending payload data
         when WAIT_S =>
            v.tcountFifoRd := '0';
            v.udpTxValid   := '1';
         -- Send our payload header
         when HEAD_S =>
            v.tcountFifoRd := '0';
            v.udpTxValid   := '1';
            if (udpTxReady = '1') then
               v.byteCount    := r.byteCount + 1;
            end if;
            -- Send first 32-bit word
            case (r.byteCount) is
               when "00" => --Bits 31:24 - lane[3:0] & vc[3:0]
                  v.udpTxData := "000000" & tdataFifoDout(33 downto 32);
               when "01" => --Bits 23:16 - continuation & zero[6:0]
                  v.udpTxData := r.continueBit & "0000000";
               when "10" => --Bits 15:8 - reserved
                  v.udpTxData := (others => '0');
               when "11" => --Bits 7:0 - reserved
                  v.udpTxData := (others => '0');
                  v.txCount   := r.txCount - 1;
                  v.state     := BYTE_S;
               when others =>
            end case;
         -- Send data words, rearrange order for SSI compatibility
         when BYTE_S =>
            v.byteCount   := r.byteCount + 1;
            v.tdataFifoRd := '0';
            v.udpTxValid   := '1';
            -- Shuffle data to match SSI byte and word order
            case (r.bytecount) is
               when "00" => 
                  v.udpTxData := tdataFifoDout(31 downto 24);
               when "01" =>
                  v.udpTxData := tdataFifoDout(23 downto 16);
               when "10" =>
                  v.udpTxData := tdataFifoDout(15 downto 8);
                  if (v.txCount /= 0) then
                     v.tdataFifoRd := '1';
                     v.txCount     := r.txCount - 1;
                  end if;
                  v.tdataFifoRd := '1';
               when "11" =>     
                  v.udpTxData   := tdataFifoDout(7 downto 0);
                  if (r.txCount = 0) then
                     v.state := IDLE_S;
                  end if;
               when others =>
            end case;
         -- Return to IDLE in unexpected state
         when others =>
            v.state := IDLE_S;
      end case;
            
      -- Synchronous reset
      if gtpClkRst = '1' then
         v := REG_INIT_C;
      end if;
      
      -- Set up variable for next clock cycle
      rin <= v;
      
      -- Outputs to ports
      userTxReady    <= userTxValid and (not (tdataFifoAFull or tcountFifoAFull));
      udpTxValid     <= r.udpTxValid;
      udpTxFast      <= '0'; --Unused for now
      udpTxData      <= r.udpTxData;
      udpTxLength    <= r.udpTxLength;      
   end process;
   
   seq : process (gtpClk) is
   begin
      if rising_edge(gtpClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end GigEthUdpFrameTx;
