-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol, V2, Register Slave Block
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : Pgp2RegSlave.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 11/20/2009
-------------------------------------------------------------------------------
-- Description:
-- Slave block for Register protocol over the PGP2.
-- Packet is 16 bytes. The 16 bit values passed over the PGP will be:
-- Word 0   Data[1:0]   = VC
-- Word 0   Data[7:2]   = Dest_ID
-- Word 0   Data[15:8]  = TID[7:0]
-- Word 1   Data[15:0]  = TID[23:8]
-- Word 2   Data[15:0]  = Address[15:0]
-- Word 3   Data[15:14] = OpCode, 0x0=Read, 0x1=Write, 0x2=Set, 0x3=Clear
-- Word 3   Data[13:8]  = Don't Care
-- Word 3   Data[7:0]   = Address[23:16]
-- Word 4   Data[15:0]  = WriteData0[15:0] or ReadCount[8:0]
-- Word 5   Data[15:0]  = WriteData0[31:16]
-- Word N-3 Data[15:0]  = WriteData[15:0]
-- Word N-2 Data[15:0]  = WriteData[31:16]
-- Word N-1             = Don't Care
-- Word N   Data[15:2]  = Don't Care
-- Word N   Data[1]     = Timeout Flag (response data)
-- Word N   Data[0]     = Fail Flag (response data)
-------------------------------------------------------------------------------
-- Copyright (c) 2007 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 11/20/2009: created.
-- 05/24/2010: Modified FIFO
-- 06/10/2013: updated for series 7 FPGAs (LLR)
-- 04/20/2015: added StdLib buffer support (should be used for all families) (by MK)
-------------------------------------------------------------------------------

library ieee;
--use work.all;
use work.StdRtlPkg.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity Pgp2RegSlave is
   generic (
      -- FifoType: (default = V5)
      -- V4 = Virtex 4,  V5 = Virtex 5, V6 = Virtex 6, V7 = Virtex 7, 
      -- S6 = Spartan 6, A7 = Artix 7,  K7 = kintex7, SL = StdLib
      FifoType : string := "V5"
      );
   port (

      -- PGP Rx Clock And Reset
      pgpRxClk   : in std_logic;        -- PGP Clock
      pgpRxReset : in std_logic;        -- Synchronous PGP Reset

      -- PGP Tx Clock And Reset
      pgpTxClk   : in std_logic;        -- PGP Clock
      pgpTxReset : in std_logic;        -- Synchronous PGP Reset

      -- Local clock and reset
      locClk   : in std_logic;          -- Local Clock
      locReset : in std_logic;          -- Synchronous Local Reset

      -- PGP Receive Signals
      vcFrameRxValid : in  std_logic;   -- Data is valid
      vcFrameRxSOF   : in  std_logic;   -- Data is SOF
      vcFrameRxEOF   : in  std_logic;   -- Data is EOF
      vcFrameRxEOFE  : in  std_logic;   -- Data is EOF with Error
      vcFrameRxData  : in  std_logic_vector(15 downto 0);  -- Data
      vcLocBuffAFull : out std_logic;   -- Local buffer almost full
      vcLocBuffFull  : out std_logic;   -- Local buffer full

      -- PGP Transmit Signals
      vcFrameTxValid : out std_logic;   -- User frame data is valid
      vcFrameTxReady : in  std_logic;   -- PGP is ready
      vcFrameTxSOF   : out std_logic;   -- User frame data start of frame
      vcFrameTxEOF   : out std_logic;   -- User frame data end of frame
      vcFrameTxEOFE  : out std_logic;   -- User frame data error
      vcFrameTxData  : out std_logic_vector(15 downto 0);  -- User frame data
      vcRemBuffAFull : in  std_logic;   -- Remote buffer almost full
      vcRemBuffFull  : in  std_logic;   -- Remote buffer full

      -- Local register control signals
      regInp     : out std_logic;       -- Register Access In Progress Flag
      regReq     : out std_logic;       -- Register Access Request
      regOp      : out std_logic;       -- Register OpCode, 0=Read, 1=Write
      regAck     : in  std_logic;       -- Register Access Acknowledge
      regFail    : in  std_logic;       -- Register Access Fail
      regAddr    : out std_logic_vector(23 downto 0);  -- Register Address
      regDataOut : out std_logic_vector(31 downto 0);  -- Register Data Out
      regDataIn  : in  std_logic_vector(31 downto 0)   -- Register Data In
      );

end Pgp2RegSlave;


-- Define architecture
architecture Pgp2RegSlave of Pgp2RegSlave is

   -- V4 Async FIFO
   component pgp2_v4_afifo_18x1023 port (
      din           : in  std_logic_vector(17 downto 0);
      rd_clk        : in  std_logic;
      rd_en         : in  std_logic;
      rst           : in  std_logic;
      wr_clk        : in  std_logic;
      wr_en         : in  std_logic;
      dout          : out std_logic_vector(17 downto 0);
      empty         : out std_logic;
      full          : out std_logic;
      wr_data_count : out std_logic_vector(9 downto 0));
   end component;

   -- V5 Async FIFO
   component pgp2_v5_afifo_18x1023 port (
      din           : in  std_logic_vector(17 downto 0);
      rd_clk        : in  std_logic;
      rd_en         : in  std_logic;
      rst           : in  std_logic;
      wr_clk        : in  std_logic;
      wr_en         : in  std_logic;
      dout          : out std_logic_vector(17 downto 0);
      empty         : out std_logic;
      full          : out std_logic;
      wr_data_count : out std_logic_vector(9 downto 0));
   end component;

   -- V6 Async FIFO
   component pgp2_v6_afifo_18x1023 port (
      din           : in  std_logic_vector(17 downto 0);
      rd_clk        : in  std_logic;
      rd_en         : in  std_logic;
      rst           : in  std_logic;
      wr_clk        : in  std_logic;
      wr_en         : in  std_logic;
      dout          : out std_logic_vector(17 downto 0);
      empty         : out std_logic;
      full          : out std_logic;
      wr_data_count : out std_logic_vector(9 downto 0));
   end component;

   -- V7 Async FIFO
   component pgp2_v7_afifo_18x1023 port (
      din           : in  std_logic_vector(17 downto 0);
      rd_clk        : in  std_logic;
      rd_en         : in  std_logic;
      rst           : in  std_logic;
      wr_clk        : in  std_logic;
      wr_en         : in  std_logic;
      dout          : out std_logic_vector(17 downto 0);
      empty         : out std_logic;
      full          : out std_logic;
      wr_data_count : out std_logic_vector(9 downto 0));
   end component;

   -- S6 Async FIFO
   component pgp2_s6_afifo_18x1023 port (
      din           : in  std_logic_vector(17 downto 0);
      rd_clk        : in  std_logic;
      rd_en         : in  std_logic;
      rst           : in  std_logic;
      wr_clk        : in  std_logic;
      wr_en         : in  std_logic;
      dout          : out std_logic_vector(17 downto 0);
      empty         : out std_logic;
      full          : out std_logic;
      wr_data_count : out std_logic_vector(9 downto 0));
   end component;

   -- A7 Async FIFO
   component pgp2_a7_afifo_18x1023 port (
      din           : in  std_logic_vector(17 downto 0);
      rd_clk        : in  std_logic;
      rd_en         : in  std_logic;
      rst           : in  std_logic;
      wr_clk        : in  std_logic;
      wr_en         : in  std_logic;
      dout          : out std_logic_vector(17 downto 0);
      empty         : out std_logic;
      full          : out std_logic;
      wr_data_count : out std_logic_vector(9 downto 0));
   end component;

   -- K7 Async FIFO
   component pgp2_k7_afifo_18x1023 port (
      din           : in  std_logic_vector(17 downto 0);
      rd_clk        : in  std_logic;
      rd_en         : in  std_logic;
      rst           : in  std_logic;
      wr_clk        : in  std_logic;
      wr_en         : in  std_logic;
      dout          : out std_logic_vector(17 downto 0);
      empty         : out std_logic;
      full          : out std_logic;
      wr_data_count : out std_logic_vector(9 downto 0));
   end component;
   
   component FifoAsync is
      generic (
         TPD_G          : time                       := 1 ns;
         RST_POLARITY_G : sl                         := '1';  -- '1' for active high rst, '0' for active low
         BRAM_EN_G      : boolean                    := true;
         FWFT_EN_G      : boolean                    := false;
         USE_DSP48_G    : string                     := "no";
         ALTERA_SYN_G   : boolean                    := false;
         ALTERA_RAM_G   : string                     := "M9K";
         SYNC_STAGES_G  : integer range 3 to (2**24) := 3;
         PIPE_STAGES_G  : natural range 0 to 16      := 0;
         DATA_WIDTH_G   : integer range 1 to (2**24) := 16;
         ADDR_WIDTH_G   : integer range 2 to 48      := 4;
         INIT_G         : slv                        := "0";
         FULL_THRES_G   : integer range 1 to (2**24) := 1;
         EMPTY_THRES_G  : integer range 1 to (2**24) := 1);
      port (
         -- Asynchronous Reset
         rst           : in  sl;
         -- Write Ports (wr_clk domain)
         wr_clk        : in  sl;
         wr_en         : in  sl;
         din           : in  slv(DATA_WIDTH_G-1 downto 0);
         wr_data_count : out slv(ADDR_WIDTH_G-1 downto 0);
         wr_ack        : out sl;
         overflow      : out sl;
         prog_full     : out sl;
         almost_full   : out sl;
         full          : out sl;
         not_full      : out sl;
         -- Read Ports (rd_clk domain)
         rd_clk        : in  sl;
         rd_en         : in  sl;
         dout          : out slv(DATA_WIDTH_G-1 downto 0);
         rd_data_count : out slv(ADDR_WIDTH_G-1 downto 0);
         valid         : out sl;
         underflow     : out sl;
         prog_empty    : out sl;
         almost_empty  : out sl;
         empty         : out sl);
   end component;

   -- Local Signals
   signal rxFifoDin   : std_logic_vector(17 downto 0);
   signal rxFifoDout  : std_logic_vector(17 downto 0);
   signal rxFifoRd    : std_logic;
   signal rxFifoCount : std_logic_vector(9 downto 0);
   signal rxFifoEmpty : std_logic;
   signal rxFifoErr   : std_logic;
   signal rxFifoFull  : std_logic;
   signal locRxSOF    : std_logic;
   signal locRxEOF    : std_logic;
   signal locRxEOFE   : std_logic;
   signal locRxData   : std_logic_vector(15 downto 0);
   signal intAddress  : std_logic_vector(23 downto 0);
   signal intData     : std_logic_vector(31 downto 0);
   signal nxtData     : std_logic_vector(31 downto 0);
   signal intInp      : std_logic;
   signal nxtInp      : std_logic;
   signal intReq      : std_logic;
   signal nxtReq      : std_logic;
   signal intOp       : std_logic;
   signal nxtOp       : std_logic;
   signal intFail     : std_logic;
   signal nxtFail     : std_logic;
   signal intTout     : std_logic;
   signal nxtTout     : std_logic;
   signal intEOFE     : std_logic;
   signal nxtEOFE     : std_logic;
   signal intReqCnt   : std_logic_vector(23 downto 0);
   signal regStart    : std_logic;
   signal regDone     : std_logic;
   signal intWrData   : std_logic_vector(31 downto 0);
   signal intOpCode   : std_logic_vector(1 downto 0);
   signal locTxWr     : std_logic;
   signal nxtTxWr     : std_logic;
   signal countEn     : std_logic;
   signal intCount    : std_logic_vector(9 downto 0);
   signal locTxSOF    : std_logic;
   signal nxtTxSOF    : std_logic;
   signal locTxEOF    : std_logic;
   signal nxtTxEOF    : std_logic;
   signal locTxEOFE   : std_logic;
   signal nxtTxEOFE   : std_logic;
   signal locTxData   : std_logic_vector(15 downto 0);
   signal nxtTxData   : std_logic_vector(15 downto 0);
   signal txFifoValid : std_logic;
   signal txFifoRd    : std_logic;
   signal txFifoWr    : std_logic;
   signal txFifoDout  : std_logic_vector(17 downto 0);
   signal txFifoDin   : std_logic_vector(17 downto 0);
   signal txFifoFull  : std_logic;
   signal txFifoEmpty : std_logic;
   signal txFifoAFull : std_logic;
   signal txFifoCount : std_logic_vector(9 downto 0);

   -- Master state machine states
   signal   curState   : std_logic_vector(3 downto 0);
   signal   nxtState   : std_logic_vector(3 downto 0);
   constant ST_IDLE    : std_logic_vector(3 downto 0) := "0001";
   constant ST_HEAD_A  : std_logic_vector(3 downto 0) := "0010";
   constant ST_HEAD_B  : std_logic_vector(3 downto 0) := "0011";
   constant ST_HEAD_C  : std_logic_vector(3 downto 0) := "0100";
   constant ST_HEAD_D  : std_logic_vector(3 downto 0) := "0101";
   constant ST_READ    : std_logic_vector(3 downto 0) := "0110";
   constant ST_WRITE_A : std_logic_vector(3 downto 0) := "0111";
   constant ST_WRITE_B : std_logic_vector(3 downto 0) := "1000";
   constant ST_REQ     : std_logic_vector(3 downto 0) := "1001";
   constant ST_NEXT    : std_logic_vector(3 downto 0) := "1010";
   constant ST_DUMP    : std_logic_vector(3 downto 0) := "1011";
   constant ST_DONE_A  : std_logic_vector(3 downto 0) := "1100";
   constant ST_DONE_B  : std_logic_vector(3 downto 0) := "1101";

   -- Register access states
   signal   curRegState  : std_logic_vector(2 downto 0);
   signal   nxtRegState  : std_logic_vector(2 downto 0);
   constant ST_REG_IDLE  : std_logic_vector(2 downto 0) := "001";
   constant ST_REG_WRITE : std_logic_vector(2 downto 0) := "010";
   constant ST_REG_READ  : std_logic_vector(2 downto 0) := "011";
   constant ST_REG_SET   : std_logic_vector(2 downto 0) := "100";
   constant ST_REG_CLEAR : std_logic_vector(2 downto 0) := "101";
   constant ST_REG_WAIT  : std_logic_vector(2 downto 0) := "110";
   constant ST_REG_DONE  : std_logic_vector(2 downto 0) := "111";

   -- Register delay for simulation
   constant tpd : time := 0.5 ns;

   -- Black Box Attributes
   attribute syn_black_box                          : boolean;
   attribute syn_noprune                            : boolean;
   attribute syn_black_box of pgp2_v4_afifo_18x1023 : component is true;
   attribute syn_noprune of pgp2_v4_afifo_18x1023   : component is true;
   attribute syn_black_box of pgp2_v5_afifo_18x1023 : component is true;
   attribute syn_noprune of pgp2_v5_afifo_18x1023   : component is true;
   attribute syn_black_box of pgp2_v6_afifo_18x1023 : component is true;
   attribute syn_noprune of pgp2_v6_afifo_18x1023   : component is true;
   attribute syn_black_box of pgp2_v7_afifo_18x1023 : component is true;
   attribute syn_noprune of pgp2_v7_afifo_18x1023   : component is true;
   attribute syn_black_box of pgp2_s6_afifo_18x1023 : component is true;
   attribute syn_noprune of pgp2_s6_afifo_18x1023   : component is true;
   attribute syn_black_box of pgp2_a7_afifo_18x1023 : component is true;
   attribute syn_noprune of pgp2_a7_afifo_18x1023   : component is true;
   attribute syn_black_box of pgp2_k7_afifo_18x1023 : component is true;
   attribute syn_noprune of pgp2_k7_afifo_18x1023   : component is true;
--   attribute syn_black_box of FifoAsync : component is true;
--   attribute syn_noprune of FifoAsync   : component is true;

begin

   -------------------------------------
   -- Inbound FIFO
   -------------------------------------

   -- Data going into Rx FIFO
   rxFifoDin(17 downto 16) <= "11" when vcFrameRxEOFE = '1' or rxFifoErr = '1' else
                              "10" when vcFrameRxEOF = '1' else
                              "01" when vcFrameRxSOF = '1' else
                              "00";
   rxFifoDin(15 downto 0) <= vcFrameRxData;

   -- V4 Receive FIFO
   U_GenRxV4Fifo : if FifoType = "V4" generate
      U_RegRxV4Fifo : pgp2_v4_afifo_18x1023 port map (
         din           => rxFifoDin,
         rd_clk        => locClk,
         rd_en         => rxFifoRd,
         rst           => pgpRxReset,
         wr_clk        => pgpRxClk,
         wr_en         => vcFrameRxValid,
         dout          => rxFifoDout,
         empty         => rxFifoEmpty,
         full          => rxFifoFull,
         wr_data_count => rxFifoCount
         );
   end generate;

   -- V5 Receive FIFO
   U_GenRxV5Fifo : if FifoType = "V5" generate
      U_RegRxV5Fifo : pgp2_v5_afifo_18x1023 port map (
         din           => rxFifoDin,
         rd_clk        => locClk,
         rd_en         => rxFifoRd,
         rst           => pgpRxReset,
         wr_clk        => pgpRxClk,
         wr_en         => vcFrameRxValid,
         dout          => rxFifoDout,
         empty         => rxFifoEmpty,
         full          => rxFifoFull,
         wr_data_count => rxFifoCount
         );
   end generate;

   -- V6 Receive FIFO
   U_GenRxV6Fifo0 : if FifoType = "V6" generate
      U_RegRxV6Fifo : pgp2_v6_afifo_18x1023 port map (
         din           => rxFifoDin,
         rd_clk        => locClk,
         rd_en         => rxFifoRd,
         rst           => pgpRxReset,
         wr_clk        => pgpRxClk,
         wr_en         => vcFrameRxValid,
         dout          => rxFifoDout,
         empty         => rxFifoEmpty,
         full          => rxFifoFull,
         wr_data_count => rxFifoCount
         );
   end generate;

   -- V7 Receive FIFO
   U_GenRxV7Fifo0 : if FifoType = "V7" generate
      U_RegRxV7Fifo : pgp2_v7_afifo_18x1023 port map (
         din           => rxFifoDin,
         rd_clk        => locClk,
         rd_en         => rxFifoRd,
         rst           => pgpRxReset,
         wr_clk        => pgpRxClk,
         wr_en         => vcFrameRxValid,
         dout          => rxFifoDout,
         empty         => rxFifoEmpty,
         full          => rxFifoFull,
         wr_data_count => rxFifoCount
         );
   end generate;

   -- S6 Receive FIFO
   U_GenRxS6Fifo0 : if FifoType = "S6" generate
      U_RegRxS6Fifo : pgp2_s6_afifo_18x1023 port map (
         din           => rxFifoDin,
         rd_clk        => locClk,
         rd_en         => rxFifoRd,
         rst           => pgpRxReset,
         wr_clk        => pgpRxClk,
         wr_en         => vcFrameRxValid,
         dout          => rxFifoDout,
         empty         => rxFifoEmpty,
         full          => rxFifoFull,
         wr_data_count => rxFifoCount
         );
   end generate;

   -- A7 Receive FIFO
   U_GenRxA7Fifo0 : if FifoType = "A7" generate
      U_RegRxA7Fifo : pgp2_a7_afifo_18x1023 port map (
         din           => rxFifoDin,
         rd_clk        => locClk,
         rd_en         => rxFifoRd,
         rst           => pgpRxReset,
         wr_clk        => pgpRxClk,
         wr_en         => vcFrameRxValid,
         dout          => rxFifoDout,
         empty         => rxFifoEmpty,
         full          => rxFifoFull,
         wr_data_count => rxFifoCount
         );
   end generate;

   -- K7 Receive FIFO
   U_GenRxK7Fifo0 : if FifoType = "K7" generate
      U_RegRxK7Fifo : pgp2_k7_afifo_18x1023 port map (
         din           => rxFifoDin,
         rd_clk        => locClk,
         rd_en         => rxFifoRd,
         rst           => pgpRxReset,
         wr_clk        => pgpRxClk,
         wr_en         => vcFrameRxValid,
         dout          => rxFifoDout,
         empty         => rxFifoEmpty,
         full          => rxFifoFull,
         wr_data_count => rxFifoCount
         );
   end generate;
   
   -- StdLib Receive FIFO
   U_GenRxSLFifo : if FifoType = "SL" generate
      U_RegRxSLFifo : FifoAsync 
      generic map (
         RST_POLARITY_G => '1',
         DATA_WIDTH_G   => 18,
         ADDR_WIDTH_G   => 10
      )
      port map ( 
         rst               => pgpRxReset,
         wr_clk            => pgpRxClk,
         wr_en             => vcFrameRxValid,
         din               => rxFifoDin,
         wr_data_count     => rxFifoCount,
         wr_ack            => open,
         overflow          => open,
         prog_full         => open,
         almost_full       => open,
         full              => rxFifoFull,
         not_full          => open,
         rd_clk            => locClk,
         rd_en             => rxFifoRd,
         dout              => rxFifoDout,
         rd_data_count     => open,
         valid             => open,
         underflow         => open,
         prog_empty        => open,
         almost_empty      => open,
         empty             => rxFifoEmpty
      );
   end generate;

   -- Data coming out of Rx FIFO
   locRxSOF  <= '1' when rxFifoDout(17 downto 16) = "01" else '0';
   locRxEOF  <= rxFifoDout(17);
   locRxEOFE <= '1' when rxFifoDout(17 downto 16) = "11" else '0';
   locRxData <= rxFifoDout(15 downto 0);

   -- Generate flow control
   process (pgpRxClk, pgpRxReset)
   begin
      if pgpRxReset = '1' then
         vcLocBuffAFull <= '0' after tpd;
         vcLocBuffFull  <= '0' after tpd;
         rxFifoErr      <= '0' after tpd;
      elsif rising_edge(pgpRxClk) then

         -- Generate full error
         if rxFifoCount >= 1020 or rxFifoFull = '1' then
            rxFifoErr <= '1' after tpd;
         else
            rxFifoErr <= '0' after tpd;
         end if;

         -- Almost full at 1/4 capacity
         vcLocBuffAFull <= rxFifoFull or rxFifoCount(9) or rxFifoCount(8);

         -- Full at 1/2 capacity
         vcLocBuffFull <= rxFifoFull or rxFifoCount(9);
      end if;
   end process;


   -------------------------------------
   -- Master State Machine
   -------------------------------------

   -- Master State Machine, Sync Logic
   process (locClk, locReset)
   begin
      if locReset = '1' then
         intCount   <= (others => '0') after tpd;
         intAddress <= (others => '0') after tpd;
         intOpCode  <= (others => '0') after tpd;
         intWrData  <= (others => '0') after tpd;
         locTxWr    <= '0'             after tpd;
         locTxSOF   <= '0'             after tpd;
         locTxEOF   <= '0'             after tpd;
         locTxEOFE  <= '0'             after tpd;
         locTxData  <= (others => '0') after tpd;
         intEOFE    <= '0'             after tpd;
         curState   <= ST_IDLE         after tpd;
      elsif rising_edge(locClk) then

         -- Length Counter
         if curState = ST_READ then
            intCount <= locRxData(9 downto 0) after tpd;
         elsif countEn = '1' then
            intCount <= intCount -1 after tpd;
         end if;

         -- Address counter
         if curState = ST_HEAD_C then
            intAddress(15 downto 0) <= locRxData after tpd;
         elsif curState = ST_HEAD_D then
            intAddress(23 downto 16) <= locRxData(7 downto 0) after tpd;
         elsif countEn = '1' then
            intAddress <= intAddress + 1 after tpd;
         end if;

         -- Store opcode
         if curState = ST_HEAD_D then
            intOpCode <= locRxData(15 downto 14) after tpd;
         end if;

         -- Write data
         if curState = ST_WRITE_A then
            intWrData(15 downto 0) <= locRxData after tpd;
         elsif curState = ST_WRITE_B then
            intWrData(31 downto 16) <= locRxData after tpd;
         end if;

         -- EOFE tracker
         intEOFE <= nxtEOFE after tpd;

         -- Outbound data
         locTxWr   <= nxtTxWr   after tpd;
         locTxSOF  <= nxtTxSOF  after tpd;
         locTxEOF  <= nxtTxEOF  after tpd;
         locTxEOFE <= nxtTxEOFE after tpd;
         locTxData <= nxtTxData after tpd;

         -- State transition
         curState <= nxtState after tpd;

      end if;
   end process;


   -- Master state engine
   process (curState, intCount, intData, intEOFE, intFail, intOpCode, intTout,
            locRxData, locRxEOF, locRxEOFE, locRxSOF, regDone, rxFifoEmpty,
            txFifoAFull) 
   begin

      -- States
      case curState is

         -- IDLE, Wait for data
         when ST_IDLE =>
            regStart  <= '0';
            nxtEOFE   <= '0';
            nxtTxWr   <= '0';
            nxtTxSOF  <= '0';
            nxtTxEOF  <= '0';
            nxtTxEOFE <= '0';
            nxtTxData <= (others => '0');
            countEn   <= '0';

            -- Data is ready
            if rxFifoEmpty = '0' and txFifoAFull = '0' then
               rxFifoRd <= '1';
               nxtState <= ST_HEAD_A;
            else
               rxFifoRd <= '0';
               nxtState <= curState;
            end if;

            -- Read Header A
         when ST_HEAD_A =>
            regStart  <= '0';
            nxtEOFE   <= '0';
            nxtTxSOF  <= '1';
            nxtTxEOF  <= '0';
            nxtTxEOFE <= '0';
            nxtTxData <= locRxData;
            countEn   <= '0';

            -- Bad alignment
            if locRxSOF = '0' or locRxEOF = '1' then
               nxtTxWr  <= '0';
               rxFifoRd <= '0';
               nxtState <= ST_IDLE;

               -- Data is ready
            elsif rxFifoEmpty = '0' then
               nxtTxWr  <= '1';
               rxFifoRd <= '1';
               nxtState <= ST_HEAD_B;
            else
               nxtTxWr  <= '0';
               rxFifoRd <= '0';
               nxtState <= curState;
            end if;

            -- Read Header B
         when ST_HEAD_B =>
            regStart  <= '0';
            nxtTxSOF  <= '0';
            nxtTxEOF  <= '0';
            nxtTxEOFE <= '0';
            nxtTxData <= locRxData;
            countEn   <= '0';

            -- Alignment Error
            if locRxSOF = '1' or locRxEOF = '1' then
               nxtEOFE  <= '1';
               nxtTxWr  <= '0';
               rxFifoRd <= '0';
               nxtState <= ST_DUMP;

               -- Data is ready
            elsif rxFifoEmpty = '0' then
               nxtEOFE  <= '0';
               nxtTxWr  <= '1';
               rxFifoRd <= '1';
               nxtState <= ST_HEAD_C;
            else
               nxtEOFE  <= '0';
               nxtTxWr  <= '0';
               rxFifoRd <= '0';
               nxtState <= curState;
            end if;

            -- Read Header C
         when ST_HEAD_C =>
            regStart  <= '0';
            nxtTxSOF  <= '0';
            nxtTxEOF  <= '0';
            nxtTxEOFE <= '0';
            nxtTxData <= locRxData;
            countEn   <= '0';

            -- Alignment Error
            if locRxSOF = '1' or locRxEOF = '1' then
               nxtEOFE  <= '1';
               nxtTxWr  <= '0';
               rxFifoRd <= '0';
               nxtState <= ST_DUMP;

               -- Data is ready
            elsif rxFifoEmpty = '0' then
               nxtEOFE  <= '0';
               nxtTxWr  <= '1';
               rxFifoRd <= '1';
               nxtState <= ST_HEAD_D;
            else
               nxtEOFE  <= '0';
               nxtTxWr  <= '0';
               rxFifoRd <= '0';
               nxtState <= curState;
            end if;

            -- Read Header D
         when ST_HEAD_D =>
            regStart  <= '0';
            nxtTxSOF  <= '0';
            nxtTxEOF  <= '0';
            nxtTxEOFE <= '0';
            nxtTxData <= locRxData;
            countEn   <= '0';

            -- Alignment Error
            if locRxSOF = '1' or locRxEOF = '1' then
               nxtEOFE  <= '1';
               nxtTxWr  <= '0';
               rxFifoRd <= '0';
               nxtState <= ST_DUMP;

               -- Data is ready
            elsif rxFifoEmpty = '0' then
               nxtEOFE  <= '0';
               nxtTxWr  <= '1';
               rxFifoRd <= '1';

               -- Read
               if locRxData(15 downto 14) = "00" then
                  nxtState <= ST_READ;
               else
                  nxtState <= ST_WRITE_A;
               end if;
            else
               nxtEOFE  <= '0';
               nxtTxWr  <= '0';
               rxFifoRd <= '0';
               nxtState <= curState;
            end if;

            -- Read command, frame word 0
         when ST_READ =>
            regStart  <= '0';
            nxtTxWr   <= '0';
            nxtTxSOF  <= '0';
            nxtTxEOF  <= '0';
            nxtTxEOFE <= '0';
            nxtTxData <= (others => '0');
            countEn   <= '0';
            rxFifoRd  <= '0';

            -- Alignment Error
            if locRxSOF = '1' or locRxEOF = '1' then
               nxtEOFE  <= '1';
               nxtState <= ST_DUMP;

               -- Data is ready
            elsif rxFifoEmpty = '0' then
               nxtEOFE  <= '0';
               nxtState <= ST_REQ;
            else
               nxtEOFE  <= '0';
               nxtState <= curState;
            end if;

            -- Low Write Data
         when ST_WRITE_A =>
            regStart  <= '0';
            nxtTxWr   <= '0';
            nxtTxSOF  <= '0';
            nxtTxEOF  <= '0';
            nxtTxEOFE <= '0';
            nxtTxData <= (others => '0');
            countEn   <= '0';

            -- Alignment Error
            if locRxSOF = '1' or locRxEOF = '1' then
               nxtEOFE  <= '1';
               rxFifoRd <= '0';
               nxtState <= ST_DUMP;

               -- Data is ready
            elsif rxFifoEmpty = '0' then
               nxtEOFE  <= '0';
               rxFifoRd <= '1';
               nxtState <= ST_WRITE_B;
            else
               nxtEOFE  <= '0';
               rxFifoRd <= '0';
               nxtState <= curState;
            end if;

            -- High Write Data
         when ST_WRITE_B =>
            regStart  <= '0';
            nxtTxWr   <= '0';
            nxtTxSOF  <= '0';
            nxtTxEOF  <= '0';
            nxtTxEOFE <= '0';
            nxtTxData <= (others => '0');
            countEn   <= '0';
            rxFifoRd  <= '0';

            -- Alignment Error
            if locRxSOF = '1' then
               nxtEOFE  <= '1';
               nxtState <= ST_DUMP;

               -- EOF
            elsif locRxEOF = '1' then
               nxtEOFE  <= locRxEOFE;
               nxtState <= ST_DONE_A;

               -- Request write cycle
            else
               nxtEOFE  <= '0';
               nxtState <= ST_REQ;
            end if;

            -- Transaction Request
         when ST_REQ =>
            regStart  <= '1';
            nxtEOFE   <= '0';
            nxtTxSOF  <= '0';
            nxtTxEOF  <= '0';
            nxtTxEOFE <= '0';
            nxtTxData <= intData(15 downto 0);
            rxFifoRd  <= '0';
            countEn   <= '0';

            -- Machine is done, write lower bits of return data
            if regDone = '1' then
               nxtTxWr  <= '1';
               nxtState <= ST_NEXT;
            else
               nxtTxWr  <= '0';
               nxtState <= curState;
            end if;

            -- Determine next command, write upper bits of return data
         when ST_NEXT =>
            regStart  <= '0';
            nxtEOFE   <= '0';
            nxtTxSOF  <= '0';
            nxtTxEOF  <= '0';
            nxtTxEOFE <= '0';
            nxtTxData <= intData(31 downto 16);

            -- An error occured
            if intTout = '1' or intFail = '1' then
               rxFifoRd <= '0';
               nxtTxWr  <= '1';
               countEn  <= '0';
               nxtState <= ST_DUMP;

               -- Read command
            elsif intOpCode = "00" then
               rxFifoRd <= '0';

               -- Read is done
               if intCount = 0 then
                  nxtTxWr  <= '1';
                  countEn  <= '0';
                  nxtState <= ST_DUMP;

                                        -- Room in transmit FIFO
               elsif txFifoAFull = '0' then
                  nxtTxWr  <= '1';
                  countEn  <= '1';
                  nxtState <= ST_REQ;
               else
                  nxtTxWr  <= '0';
                  countEn  <= '0';
                  nxtState <= curState;
               end if;

               -- Other command, data is ready
            elsif rxFifoEmpty = '0' and txFifoAFull = '0' then
               rxFifoRd <= '1';
               nxtTxWr  <= '1';
               countEn  <= '1';
               nxtState <= ST_WRITE_A;
            else
               rxFifoRd <= '0';
               nxtTxWr  <= '0';
               countEn  <= '0';
               nxtState <= curState;
            end if;

            -- Dump receive data
         when ST_DUMP =>
            regStart  <= '0';
            nxtTxSOF  <= '0';
            nxtTxEOF  <= '0';
            nxtTxEOFE <= '0';
            nxtTxData <= (others => '0');
            nxtTxWr   <= '0';
            countEn   <= '0';

            -- Data is done
            if locRxEOF = '1' then
               nxtEOFE  <= intEOFE or locRxEOFE;
               rxFifoRd <= '0';
               nxtState <= ST_DONE_A;
            else
               nxtEOFE  <= intEOFE;
               rxFifoRd <= not rxFifoEmpty;
               nxtState <= curState;
            end if;

            -- Done word 0
         when ST_DONE_A =>
            regStart  <= '0';
            nxtEOFE   <= intEOFE;
            nxtTxSOF  <= '0';
            nxtTxEOF  <= '0';
            nxtTxEOFE <= '0';
            nxtTxData <= (others => '0');
            nxtTxWr   <= '1';
            rxFifoRd  <= '0';
            countEn   <= '0';
            nxtState  <= ST_DONE_B;

            -- Done word 1
         when ST_DONE_B =>
            regStart               <= '0';
            nxtEOFE                <= intEOFE;
            nxtTxSOF               <= '0';
            nxtTxEOF               <= '1';
            nxtTxEOFE              <= intEOFE;
            nxtTxData(15 downto 2) <= (others => '0');
            nxtTxData(1)           <= intTout;
            nxtTxData(0)           <= intFail;
            nxtTxWr                <= '1';
            rxFifoRd               <= '0';
            countEn                <= '0';
            nxtState               <= ST_IDLE;

            -- default
         when others =>
            regStart  <= '0';
            nxtEOFE   <= '0';
            nxtTxSOF  <= '0';
            nxtTxEOF  <= '0';
            nxtTxEOFE <= '0';
            nxtTxData <= (others => '0');
            nxtTxWr   <= '0';
            rxFifoRd  <= '0';
            countEn   <= '0';
            nxtState  <= ST_IDLE;

      end case;
   end process;


   -------------------------------------
   -- Outbound FIFO
   -------------------------------------

   -- Data going into tx fifo
   process (locClk, locReset)
   begin
      if locReset = '1' then
         txFifoWr    <= '0'             after tpd;
         txFifoDin   <= (others => '0') after tpd;
         txFifoAFull <= '0'             after tpd;
      elsif rising_edge(locClk) then

         -- Write control
         txFifoWr <= locTxWr after tpd;

         -- Write Data
         if locTxEOFE = '1' then
            txFifoDin(17 downto 16) <= "11" after tpd;
         elsif locTxEOF = '1' then
            txFifoDin(17 downto 16) <= "10" after tpd;
         elsif locTxSOF = '1' then
            txFifoDin(17 downto 16) <= "01" after tpd;
         else
            txFifoDin(17 downto 16) <= "00" after tpd;
         end if;
         txFifoDin(15 downto 0) <= locTxData;

         -- Almost full
         if txFifoCount > 1000 or txFifoFull = '1' then
            txFifoAFull <= '1' after tpd;
         else
            txFifoAFull <= '0' after tpd;
         end if;
      end if;
   end process;

   -- V4 Transmit FIFO
   U_GenTxV4Fifo : if FifoType = "V4" generate
      U_RegTxV4Fifo : pgp2_v4_afifo_18x1023 port map (
         din           => txFifoDin,
         rd_clk        => pgpTxClk,
         rd_en         => txFifoRd,
         rst           => pgpTxReset,
         wr_clk        => locClk,
         wr_en         => txFifoWr,
         dout          => txFifoDout,
         empty         => txFifoEmpty,
         full          => txFifoFull,
         wr_data_count => txFifoCount
         );
   end generate;

   -- V5 Transmit FIFO
   U_GenTxV5Fifo : if FifoType = "V5" generate
      U_RegTxV5Fifo : pgp2_v5_afifo_18x1023 port map (
         din           => txFifoDin,
         rd_clk        => pgpTxClk,
         rd_en         => txFifoRd,
         rst           => pgpTxReset,
         wr_clk        => locClk,
         wr_en         => txFifoWr,
         dout          => txFifoDout,
         empty         => txFifoEmpty,
         full          => txFifoFull,
         wr_data_count => txFifoCount
         );
   end generate;

   -- V6 Receive FIFO
   U_GenRxV6Fifo1 : if FifoType = "V6" generate
      U_RegRxV6Fifo : pgp2_v6_afifo_18x1023 port map (
         din           => txFifoDin,
         rd_clk        => pgpTxClk,
         rd_en         => txFifoRd,
         rst           => pgpTxReset,
         wr_clk        => locClk,
         wr_en         => txFifoWr,
         dout          => txFifoDout,
         empty         => txFifoEmpty,
         full          => txFifoFull,
         wr_data_count => txFifoCount
         );
   end generate;

   -- V7 Receive FIFO
   U_GenRxV7Fifo1 : if FifoType = "V7" generate
      U_RegRxV7Fifo : pgp2_v7_afifo_18x1023 port map (
         din           => txFifoDin,
         rd_clk        => pgpTxClk,
         rd_en         => txFifoRd,
         rst           => pgpTxReset,
         wr_clk        => locClk,
         wr_en         => txFifoWr,
         dout          => txFifoDout,
         empty         => txFifoEmpty,
         full          => txFifoFull,
         wr_data_count => txFifoCount
         );
   end generate;

   -- S6 Receive FIFO
   U_GenRxS6Fifo1 : if FifoType = "S6" generate
      U_RegRxS6Fifo : pgp2_s6_afifo_18x1023 port map (
         din           => txFifoDin,
         rd_clk        => pgpTxClk,
         rd_en         => txFifoRd,
         rst           => pgpTxReset,
         wr_clk        => locClk,
         wr_en         => txFifoWr,
         dout          => txFifoDout,
         empty         => txFifoEmpty,
         full          => txFifoFull,
         wr_data_count => txFifoCount
         );
   end generate;

   -- A7 Receive FIFO
   U_GenRxA7Fifo1 : if FifoType = "A7" generate
      U_RegRxA7Fifo : pgp2_a7_afifo_18x1023 port map (
         din           => txFifoDin,
         rd_clk        => pgpTxClk,
         rd_en         => txFifoRd,
         rst           => pgpTxReset,
         wr_clk        => locClk,
         wr_en         => txFifoWr,
         dout          => txFifoDout,
         empty         => txFifoEmpty,
         full          => txFifoFull,
         wr_data_count => txFifoCount
         );
   end generate;

   -- K7 Receive FIFO
   U_GenRxK7Fifo1 : if FifoType = "K7" generate
      U_RegRxK7Fifo : pgp2_k7_afifo_18x1023 port map (
         din           => txFifoDin,
         rd_clk        => pgpTxClk,
         rd_en         => txFifoRd,
         rst           => pgpTxReset,
         wr_clk        => locClk,
         wr_en         => txFifoWr,
         dout          => txFifoDout,
         empty         => txFifoEmpty,
         full          => txFifoFull,
         wr_data_count => txFifoCount
         );
   end generate;
   
   -- StdLib Receive FIFO
   U_GenRxSLFifo1 : if FifoType = "SL" generate
      U_RegRxSLFifo : FifoAsync 
      generic map (
         RST_POLARITY_G => '1',
         DATA_WIDTH_G   => 18,
         ADDR_WIDTH_G   => 10
      )
      port map ( 
         rst               => pgpTxReset,
         wr_clk            => locClk,
         wr_en             => txFifoWr,
         din               => txFifoDin,
         wr_data_count     => txFifoCount,
         wr_ack            => open,
         overflow          => open,
         prog_full         => open,
         almost_full       => open,
         full              => txFifoFull,
         not_full          => open,
         rd_clk            => pgpTxClk,
         rd_en             => txFifoRd,
         dout              => txFifoDout,
         rd_data_count     => open,
         valid             => open,
         underflow         => open,
         prog_empty        => open,
         almost_empty      => open,
         empty             => txFifoEmpty
      );
   end generate;

   -- Data valid
   process (pgpTxClk, pgpTxReset)
   begin
      if pgpTxReset = '1' then
         txFifoValid <= '0' after tpd;
      elsif rising_edge(pgpTxClk) then
         if txFifoRd = '1' then
            txFifoValid <= '1' after tpd;
         elsif vcFrameTxReady = '1' then
            txFifoValid <= '0' after tpd;
         end if;
      end if;
   end process;

   -- Control reads
   txFifoRd <= (not txFifoEmpty) and (not vcRemBuffAFull) and (not vcRemBuffFull) and
               ((not txFifoValid) or vcframeTxReady);

   -- Outgoing signals
   vcFrameTxValid <= txFifoValid;
   vcFrameTxSOF   <= '1' when txFifoDout(17 downto 16) = "01" else '0';
   vcFrameTxEOF   <= txFifoDout(17);
   vcFrameTxEOFE  <= '1' when txFifoDout(17 downto 16) = "11" else '0';
   vcFrameTxData  <= txFifoDout(15 downto 0);


   -------------------------------------
   -- Register Access Control
   -------------------------------------

   -- Drive address bus
   regAddr    <= intAddress;
   regDataOut <= intData;
   regInp     <= intInp;
   regReq     <= intReq;
   regOp      <= intOp;


   -- Register State Machine, Sync Logic
   process (locClk, locReset)
   begin
      if locReset = '1' then
         intInp      <= '0'             after tpd;
         intReq      <= '0'             after tpd;
         intOp       <= '0'             after tpd;
         intData     <= (others => '0') after tpd;
         intReqCnt   <= (others => '0') after tpd;
         intFail     <= '0'             after tpd;
         intTout     <= '0'             after tpd;
         curRegState <= ST_REG_IDLE     after tpd;
      elsif rising_edge(locClk) then

         -- State transition
         curRegState <= nxtRegState after tpd;

         -- Opcode and write data
         intInp <= nxtInp after tpd;
         intReq <= nxtReq after tpd;
         intOp  <= nxtOp  after tpd;

         -- Data Storage
         intData <= nxtData after tpd;

         -- Timeout & fail flags
         intFail <= nxtFail after tpd;
         intTout <= nxtTout after tpd;

         -- Timeout counter
         if intReq <= '0' then
            intReqCnt <= (others => '0') after tpd;
         elsif intReqCnt /= x"FFFFFF" then
            intReqCnt <= intReqCnt + 1 after tpd;
         end if;
      end if;
   end process;


   -- Register state engine
   process (curRegState, intData, intFail, intOpCode, intReqCnt, intTout,
            intWrData, regAck, regDataIn, regFail, regStart) 
   begin

      -- States
      case curRegState is

         -- IDLE, Wait for enable from read logic
         when ST_REG_IDLE =>
            regDone <= '0';
            nxtInp  <= '0';
            nxtReq  <= '0';
            nxtOp   <= '0';

            -- Register data
            nxtdata <= intWrData;

            -- Start
            if regStart = '1' then
               nxtFail <= '0';
               nxtTout <= '0';

               -- Write Command
               if intOpCode = "01" then
                  nxtRegState <= ST_REG_WRITE;

                                        -- Read, Set Bit, Clear Bit
               else
                  nxtRegState <= ST_REG_READ;
               end if;
            else
               nxtFail     <= intFail;
               nxtTout     <= intTout;
               nxtRegState <= curRegState;
            end if;

            -- Write State
         when ST_REG_WRITE =>
            regDone <= '0';
            nxtInp  <= '1';
            nxtReq  <= '1';
            nxtOp   <= '1';
            nxtdata <= intData;

            -- Ack is passed
            if regAck = '1' then

               -- Done
               nxtRegState <= ST_REG_WAIT;

               -- Store fail flag, no timeout
               nxtFail <= regFail;
               nxtTout <= '0';

               -- Timeout
            elsif intReqCnt = x"FFFFFF" then

               -- Done
               nxtRegState <= ST_REG_WAIT;

               -- No Fail, set timeout
               nxtFail <= '0';
               nxtTout <= '1';

               -- Keep waiting
            else
               nxtRegState <= curRegState;
               nxtFail     <= '0';
               nxtTout     <= '0';
            end if;

            -- Read State
         when ST_REG_READ =>
            regDone <= '0';
            nxtInp  <= '1';
            nxtReq  <= '1';
            nxtOp   <= '0';

            -- Take read data
            nxtdata <= regDataIn;

            -- Ack is passed
            if regAck = '1' then

               -- Fail
               if regFail = '1' then

                                        -- Store fail flag, no timeout, done
                  nxtFail     <= regFail;
                  nxtTout     <= '0';
                  nxtRegState <= ST_REG_WAIT;

                                        -- Normal termination
               else

                                        -- No fail or timeout
                  nxtFail <= '0';
                  nxtTout <= '0';

                                        -- Set bit command
                  if intOpCode = "10" then
                     nxtRegState <= ST_REG_SET;

                                        -- Clear bit command
                  elsif intOpCode = "11" then
                     nxtRegState <= ST_REG_CLEAR;

                                        -- Read command
                  else
                     nxtRegState <= ST_REG_WAIT;
                  end if;
               end if;

               -- Timeout
            elsif intReqCnt = x"FFFFFF" then

               -- done
               nxtRegState <= ST_REG_WAIT;

               -- No Fail, set timeout
               nxtFail <= '0';
               nxtTout <= '1';

               -- Keep waiting
            else
               nxtRegState <= curRegState;
               nxtFail     <= '0';
               nxtTout     <= '0';
            end if;

            -- Set Bit Command
         when ST_REG_SET =>
            regDone <= '0';
            nxtInp  <= '1';
            nxtReq  <= '0';
            nxtOp   <= '0';

            -- Set bits
            nxtdata <= intData or intWrData;

            -- No errors
            nxtFail <= '0';
            nxtTout <= '0';

            -- Go to write state
            -- Wait for ack from previous command to clear
            if regAck = '0' then
               nxtRegState <= ST_REG_WRITE;
            else
               nxtRegState <= curRegState;
            end if;

            -- Clear Bit Command
         when ST_REG_CLEAR =>
            regDone <= '0';
            nxtInp  <= '1';
            nxtReq  <= '0';
            nxtOp   <= '0';

            -- Clear bits
            nxtdata <= intData and (not intWrData);

            -- No errors
            nxtFail <= '0';
            nxtTout <= '0';

            -- Go to write state
            -- Wait for ack from previous command to clear
            if regAck = '0' then
               nxtRegState <= ST_REG_WRITE;
            else
               nxtRegState <= curRegState;
            end if;

            -- Done
         when ST_REG_WAIT =>
            regDone <= '0';
            nxtInp  <= '0';
            nxtReq  <= '0';
            nxtOp   <= '0';
            nxtdata <= intData;
            nxtFail <= intFail;
            nxtTout <= intTout;

            -- Wait for ack to clear
            if regAck = '0' then
               nxtRegState <= ST_REG_DONE;
            else
               nxtRegState <= curRegState;
            end if;

            -- Done
         when ST_REG_DONE =>
            regDone     <= '1';
            nxtInp      <= '0';
            nxtReq      <= '0';
            nxtOp       <= '0';
            nxtdata     <= intData;
            nxtFail     <= intFail;
            nxtTout     <= intTout;
            nxtRegState <= ST_REG_IDLE;

         when others =>
            regDone     <= '0';
            nxtReq      <= '0';
            nxtInp      <= '0';
            nxtOp       <= '0';
            nxtdata     <= (others => '0');
            nxtFail     <= '0';
            nxtTout     <= '0';
            nxtRegState <= ST_REG_IDLE;
      end case;
   end process;

   --debug(63 downto 59) <= (others=>'0');
   --debug(58)           <= countEn;
   --debug(57)           <= intInp;
   --debug(56)           <= intReq;
   --debug(55)           <= intOp;
   --debug(54)           <= intFail;
   --debug(53)           <= intTout;
   --debug(52)           <= intEOFE;
   --debug(51)           <= regStart;
   --debug(50)           <= regDone;
   --debug(49 downto 48) <= intOpCode;
   --debug(47 downto 44) <= curState;
   --debug(43 downto 41) <= curRegState;
   --debug(40)           <= '0';
   --debug(39 downto 24) <= locTxData;
   --debug(23 downto  8) <= locRxData;
   --debug(7)            <= locTxSOF;
   --debug(6)            <= locTxEOF;
   --debug(5)            <= locTxEOFE;
   --debug(4)            <= locRxSOF;
   --debug(3)            <= locRxEOF;
   --debug(2)            <= locRxEOFE;
   --debug(1)            <= locTxWr;
   --debug(0)            <= rxFifoRd;


end Pgp2RegSlave;

