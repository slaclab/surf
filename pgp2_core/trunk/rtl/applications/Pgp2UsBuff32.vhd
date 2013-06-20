-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol Applications, Upstream Data Buffer
-- Project       : Reconfigurable Cluster Element
-------------------------------------------------------------------------------
-- File          : Pgp2UsBuff32.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 01/11/2010
-------------------------------------------------------------------------------
-- Description:
-- VHDL source file for buffer block for upstream data.
-------------------------------------------------------------------------------
-- Copyright (c) 2010 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 01/11/2010: created.
-- 06/10/2013: updated for series 7 FPGAs (LLR)
-------------------------------------------------------------------------------

library ieee;
use work.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity Pgp2UsBuff32 is
   generic (
      -- FifoType: (default = V5)
      -- V4 = Virtex 4,  V5 = Virtex 5, V6 = Virtex 6, V7 = Virtex 7, 
      -- S6 = Spartan 6, A7 = Artix 7,  K7 = kintex7
      FifoType : string := "V5"
      );
   port (

      -- Clock and reset     
      pgpClk   : in std_logic;
      pgpReset : in std_logic;
      locClk   : in std_logic;
      locReset : in std_logic;

      -- Local data transfer signals
      frameTxValid : in  std_logic;
      frameTxSOF   : in  std_logic;
      frameTxEOF   : in  std_logic;
      frameTxEOFE  : in  std_logic;
      frameTxData  : in  std_logic_vector(31 downto 0);
      frameTxAFull : out std_logic;

      -- PGP Transmit Signals
      vcFrameTxValid : out std_logic;
      vcFrameTxReady : in  std_logic;
      vcFrameTxSOF   : out std_logic;
      vcFrameTxEOF   : out std_logic;
      vcFrameTxEOFE  : out std_logic;
      vcFrameTxData  : out std_logic_vector(15 downto 0);
      vcRemBuffAFull : in  std_logic;
      vcRemBuffFull  : in  std_logic
      );
end Pgp2UsBuff32;


-- Define architecture
architecture Pgp2UsBuff32 of Pgp2UsBuff32 is

   -- V4 Async FIFO
   component pgp2_v4_afifo_36x512 port (
      din           : in  std_logic_vector(35 downto 0);
      rd_clk        : in  std_logic;
      rd_en         : in  std_logic;
      rst           : in  std_logic;
      wr_clk        : in  std_logic;
      wr_en         : in  std_logic;
      dout          : out std_logic_vector(35 downto 0);
      empty         : out std_logic;
      full          : out std_logic;
      wr_data_count : out std_logic_vector(8 downto 0));
   end component;

   -- V5 Async FIFO
   component pgp2_v5_afifo_36x512 port (
      din           : in  std_logic_vector(35 downto 0);
      rd_clk        : in  std_logic;
      rd_en         : in  std_logic;
      rst           : in  std_logic;
      wr_clk        : in  std_logic;
      wr_en         : in  std_logic;
      dout          : out std_logic_vector(35 downto 0);
      empty         : out std_logic;
      full          : out std_logic;
      wr_data_count : out std_logic_vector(8 downto 0));
   end component;

   -- V6 Async FIFO
   component pgp2_v6_afifo_36x512 port (
      din           : in  std_logic_vector(35 downto 0);
      rd_clk        : in  std_logic;
      rd_en         : in  std_logic;
      rst           : in  std_logic;
      wr_clk        : in  std_logic;
      wr_en         : in  std_logic;
      dout          : out std_logic_vector(35 downto 0);
      empty         : out std_logic;
      full          : out std_logic;
      wr_data_count : out std_logic_vector(8 downto 0));
   end component;

   -- V7 Async FIFO
   component pgp2_v7_afifo_36x512 port (
      din           : in  std_logic_vector(35 downto 0);
      rd_clk        : in  std_logic;
      rd_en         : in  std_logic;
      rst           : in  std_logic;
      wr_clk        : in  std_logic;
      wr_en         : in  std_logic;
      dout          : out std_logic_vector(35 downto 0);
      empty         : out std_logic;
      full          : out std_logic;
      wr_data_count : out std_logic_vector(8 downto 0));
   end component;

   -- S6 Async FIFO
   component pgp2_s6_afifo_36x512 port (
      din           : in  std_logic_vector(35 downto 0);
      rd_clk        : in  std_logic;
      rd_en         : in  std_logic;
      rst           : in  std_logic;
      wr_clk        : in  std_logic;
      wr_en         : in  std_logic;
      dout          : out std_logic_vector(35 downto 0);
      empty         : out std_logic;
      full          : out std_logic;
      wr_data_count : out std_logic_vector(8 downto 0));
   end component;

   -- A7 Async FIFO
   component pgp2_a7_afifo_36x512 port (
      din           : in  std_logic_vector(35 downto 0);
      rd_clk        : in  std_logic;
      rd_en         : in  std_logic;
      rst           : in  std_logic;
      wr_clk        : in  std_logic;
      wr_en         : in  std_logic;
      dout          : out std_logic_vector(35 downto 0);
      empty         : out std_logic;
      full          : out std_logic;
      wr_data_count : out std_logic_vector(8 downto 0));
   end component;

   -- K7 Async FIFO
   component pgp2_k7_afifo_36x512 port (
      din           : in  std_logic_vector(35 downto 0);
      rd_clk        : in  std_logic;
      rd_en         : in  std_logic;
      rst           : in  std_logic;
      wr_clk        : in  std_logic;
      wr_en         : in  std_logic;
      dout          : out std_logic_vector(35 downto 0);
      empty         : out std_logic;
      full          : out std_logic;
      wr_data_count : out std_logic_vector(8 downto 0));
   end component;

   -- Local Signals
   signal txFifoDin   : std_logic_vector(35 downto 0);
   signal txFifoDout  : std_logic_vector(35 downto 0);
   signal txFifoRd    : std_logic;
   signal txFifoCount : std_logic_vector(8 downto 0);
   signal txFifoEmpty : std_logic;
   signal txFifoFull  : std_logic;
   signal txFifoValid : std_logic;
   signal txFifoHalf  : std_logic;
   signal fifoErr     : std_logic;

   -- Register delay for simulation
   constant tpd : time := 0.5 ns;

   -- Black Box Attributes
   attribute syn_black_box                         : boolean;
   attribute syn_noprune                           : boolean;
   attribute syn_black_box of pgp2_v4_afifo_36x512 : component is true;
   attribute syn_noprune of pgp2_v4_afifo_36x512   : component is true;
   attribute syn_black_box of pgp2_v5_afifo_36x512 : component is true;
   attribute syn_noprune of pgp2_v5_afifo_36x512   : component is true;
   attribute syn_black_box of pgp2_v6_afifo_36x512 : component is true;
   attribute syn_noprune of pgp2_v6_afifo_36x512   : component is true;
   attribute syn_black_box of pgp2_v7_afifo_36x512 : component is true;
   attribute syn_noprune of pgp2_v7_afifo_36x512   : component is true;
   attribute syn_black_box of pgp2_s6_afifo_36x512 : component is true;
   attribute syn_noprune of pgp2_s6_afifo_36x512   : component is true;
   attribute syn_black_box of pgp2_a7_afifo_36x512 : component is true;
   attribute syn_noprune of pgp2_a7_afifo_36x512   : component is true;
   attribute syn_black_box of pgp2_k7_afifo_36x512 : component is true;
   attribute syn_noprune of pgp2_k7_afifo_36x512   : component is true;

begin

   -- Data going into Tx FIFO
   txFifoDin(35)          <= '0';
   txFifoDin(34)          <= frameTxEOFE;
   txFifoDin(33)          <= frameTxEOF;
   txFifoDin(32)          <= frameTxSOF;
   txFifoDin(31 downto 0) <= frameTxData;

   -- Generate fifo error signal
   process (locClk, locReset)
   begin
      if locReset = '1' then
         fifoErr      <= '0' after tpd;
         frameTxAFull <= '0' after tpd;
      elsif rising_edge(locClk) then

         -- Generate full error
         if txFifoCount >= 500 or txFifoFull = '1' then
            fifoErr <= '1' after tpd;
         else
            fifoErr <= '0' after tpd;
         end if;

         -- Almost full at 1/2 capacity
         frameTxAFull <= txFifoFull or txFifoCount(8);

      end if;
   end process;

   -- V4 Receive FIFO
   U_GenRxV4Fifo : if FifoType = "V4" generate
      U_RegRxV4Fifo : pgp2_v4_afifo_36x512 port map (
         din           => txFifoDin,
         rd_clk        => pgpClk,
         rd_en         => txFifoRd,
         rst           => pgpReset,
         wr_clk        => locClk,
         wr_en         => frameTxValid,
         dout          => txFifoDout,
         empty         => txFifoEmpty,
         full          => txFifoFull,
         wr_data_count => txFifoCount
         );
   end generate;

   -- V5 Receive FIFO
   U_GenRxV5Fifo : if FifoType = "V5" generate
      U_RegRxV5Fifo : pgp2_v5_afifo_36x512 port map (
         din           => txFifoDin,
         rd_clk        => pgpClk,
         rd_en         => txFifoRd,
         rst           => pgpReset,
         wr_clk        => locClk,
         wr_en         => frameTxValid,
         dout          => txFifoDout,
         empty         => txFifoEmpty,
         full          => txFifoFull,
         wr_data_count => txFifoCount
         );
   end generate;

   -- V6 Receive FIFO
   U_GenRxV6Fifo : if FifoType = "V6" generate
      U_RegRxV6Fifo : pgp2_v6_afifo_36x512 port map (
         din           => txFifoDin,
         rd_clk        => pgpClk,
         rd_en         => txFifoRd,
         rst           => pgpReset,
         wr_clk        => locClk,
         wr_en         => frameTxValid,
         dout          => txFifoDout,
         empty         => txFifoEmpty,
         full          => txFifoFull,
         wr_data_count => txFifoCount
         );
   end generate;

   -- V7 Receive FIFO
   U_GenRxV7Fifo : if FifoType = "V7" generate
      U_RegRxV7Fifo : pgp2_v7_afifo_36x512 port map (
         din           => txFifoDin,
         rd_clk        => pgpClk,
         rd_en         => txFifoRd,
         rst           => pgpReset,
         wr_clk        => locClk,
         wr_en         => frameTxValid,
         dout          => txFifoDout,
         empty         => txFifoEmpty,
         full          => txFifoFull,
         wr_data_count => txFifoCount
         );
   end generate;

   -- S6 Receive FIFO
   U_GenRxS6Fifo : if FifoType = "S6" generate
      U_RegRxS6Fifo : pgp2_s6_afifo_36x512 port map (
         din           => txFifoDin,
         rd_clk        => pgpClk,
         rd_en         => txFifoRd,
         rst           => pgpReset,
         wr_clk        => locClk,
         wr_en         => frameTxValid,
         dout          => txFifoDout,
         empty         => txFifoEmpty,
         full          => txFifoFull,
         wr_data_count => txFifoCount
         );
   end generate;

   -- A7 Receive FIFO
   U_GenRxA7Fifo : if FifoType = "A7" generate
      U_RegRxA7Fifo : pgp2_a7_afifo_36x512 port map (
         din           => txFifoDin,
         rd_clk        => pgpClk,
         rd_en         => txFifoRd,
         rst           => pgpReset,
         wr_clk        => locClk,
         wr_en         => frameTxValid,
         dout          => txFifoDout,
         empty         => txFifoEmpty,
         full          => txFifoFull,
         wr_data_count => txFifoCount
         );
   end generate;

   -- K7 Receive FIFO
   U_GenRxK7Fifo : if FifoType = "K7" generate
      U_RegRxK7Fifo : pgp2_k7_afifo_36x512 port map (
         din           => txFifoDin,
         rd_clk        => pgpClk,
         rd_en         => txFifoRd,
         rst           => pgpReset,
         wr_clk        => locClk,
         wr_en         => frameTxValid,
         dout          => txFifoDout,
         empty         => txFifoEmpty,
         full          => txFifoFull,
         wr_data_count => txFifoCount
         );
   end generate;

   -- Data valid
   process (pgpClk, pgpReset)
   begin
      if pgpReset = '1' then
         txFifoValid <= '0' after tpd;
         txFifoHalf  <= '0' after tpd;
      elsif rising_edge(pgpClk) then
         if txFifoRd = '1' then
            txFifoValid <= '1' after tpd;
            txFifoHalf  <= '0' after tpd;
         elsif vcFrameTxReady = '1' then
            if txFifoHalf = '1' then
               txFifoValid <= '0' after tpd;
            end if;
            txFifoHalf <= '0' after tpd;
         end if;
      end if;
   end process;

   -- Control reads
   txFifoRd <= (not txFifoEmpty) and (not vcRemBuffAFull) and (not vcRemBuffFull) and
               ((not txFifoValid) or (vcframeTxReady and txFifoHalf));

   -- Outgoing signals
   vcFrameTxValid <= txFifoValid;
   vcFrameTxEOFE  <= txFifoDout(34)          when txFifoHalf = '1' else '0';
   vcFrameTxEOF   <= txFifoDout(33)          when txFifoHalf = '1' else '0';
   vcFrameTxSOF   <= txFifoDout(32)          when txFifoHalf = '0' else '0';
   vcFrameTxData  <= txFifoDout(15 downto 0) when txFifoHalf = '0' else txFifoDout(31 downto 16);

end Pgp2UsBuff32;

