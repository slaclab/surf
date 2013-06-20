-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol Applications, Downstream Data Buffer
-- Project       : Reconfigurable Cluster Element
-------------------------------------------------------------------------------
-- File          : Pgp2DsBuff.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 01/11/2010
-------------------------------------------------------------------------------
-- Description:
-- VHDL source file for buffer block for downstream data.
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

entity Pgp2DsBuff is
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

      -- PGP Receive Signals
      vcFrameRxValid : in  std_logic;
      vcFrameRxSOF   : in  std_logic;
      vcFrameRxEOF   : in  std_logic;
      vcFrameRxEOFE  : in  std_logic;
      vcFrameRxData  : in  std_logic_vector(15 downto 0);
      vcLocBuffAFull : out std_logic;
      vcLocBuffFull  : out std_logic;

      -- Local data transfer signals
      frameRxValid : out std_logic;
      frameRxReady : in  std_logic;
      frameRxSOF   : out std_logic;
      frameRxEOF   : out std_logic;
      frameRxEOFE  : out std_logic;
      frameRxData  : out std_logic_vector(15 downto 0)
      );
end Pgp2DsBuff;


-- Define architecture
architecture Pgp2DsBuff of Pgp2DsBuff is

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

   -- Local Signals
   signal rxFifoDin   : std_logic_vector(17 downto 0);
   signal rxFifoDout  : std_logic_vector(17 downto 0);
   signal rxFifoRd    : std_logic;
   signal rxFifoValid : std_logic;
   signal rxFifoCount : std_logic_vector(9 downto 0);
   signal rxFifoEmpty : std_logic;
   signal rxFifoFull  : std_logic;
   signal fifoErr     : std_logic;

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

begin

   -- Data going into Rx FIFO
   rxFifoDin(17 downto 16) <= "11" when vcFrameRxEOFE = '1' or fifoErr = '1' else
                              "10" when vcFrameRxEOF = '1' else
                              "01" when vcFrameRxSOF = '1' else
                              "00";
   rxFifoDin(15 downto 0) <= vcFrameRxData;

   -- Generate flow control
   process (pgpClk, pgpReset)
   begin
      if pgpReset = '1' then
         vcLocBuffAFull <= '0' after tpd;
         vcLocBuffFull  <= '0' after tpd;
         fifoErr        <= '0' after tpd;
      elsif rising_edge(pgpClk) then

         -- Generate full error
         if rxFifoCount >= 1020 or rxFifoFull = '1' then
            fifoErr <= '1' after tpd;
         else
            fifoErr <= '0' after tpd;
         end if;

         -- Almost full at 1/4 capacity
         vcLocBuffAFull <= rxFifoFull or rxFifoCount(9) or rxFifoCount(8);

         -- Full at 1/2 capacity
         vcLocBuffFull <= rxFifoFull or rxFifoCount(9);
      end if;
   end process;

   -- V4 Receive FIFO
   U_GenRxV4Fifo : if FifoType = "V4" generate
      U_RegRxV4Fifo : pgp2_v4_afifo_18x1023 port map (
         din           => rxFifoDin,
         rd_clk        => locClk,
         rd_en         => rxFifoRd,
         rst           => pgpReset,
         wr_clk        => pgpClk,
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
         rst           => pgpReset,
         wr_clk        => pgpClk,
         wr_en         => vcFrameRxValid,
         dout          => rxFifoDout,
         empty         => rxFifoEmpty,
         full          => rxFifoFull,
         wr_data_count => rxFifoCount
         );
   end generate;

   -- V6 Receive FIFO
   U_GenRxV6Fifo : if FifoType = "V6" generate
      U_RegRxV6Fifo : pgp2_v6_afifo_18x1023 port map (
         din           => rxFifoDin,
         rd_clk        => locClk,
         rd_en         => rxFifoRd,
         rst           => pgpReset,
         wr_clk        => pgpClk,
         wr_en         => vcFrameRxValid,
         dout          => rxFifoDout,
         empty         => rxFifoEmpty,
         full          => rxFifoFull,
         wr_data_count => rxFifoCount
         );
   end generate;

   -- V7 Receive FIFO
   U_GenRxV7Fifo : if FifoType = "V7" generate
      U_RegRxV7Fifo : pgp2_v7_afifo_18x1023 port map (
         din           => rxFifoDin,
         rd_clk        => locClk,
         rd_en         => rxFifoRd,
         rst           => pgpReset,
         wr_clk        => pgpClk,
         wr_en         => vcFrameRxValid,
         dout          => rxFifoDout,
         empty         => rxFifoEmpty,
         full          => rxFifoFull,
         wr_data_count => rxFifoCount
         );
   end generate;

   -- S6 Receive FIFO
   U_GenRxS6Fifo : if FifoType = "S6" generate
      U_RegRxS6Fifo : pgp2_s6_afifo_18x1023 port map (
         din           => rxFifoDin,
         rd_clk        => locClk,
         rd_en         => rxFifoRd,
         rst           => pgpReset,
         wr_clk        => pgpClk,
         wr_en         => vcFrameRxValid,
         dout          => rxFifoDout,
         empty         => rxFifoEmpty,
         full          => rxFifoFull,
         wr_data_count => rxFifoCount
         );
   end generate;

   -- A7 Receive FIFO
   U_GenRxA7Fifo : if FifoType = "A7" generate
      U_RegRxA7Fifo : pgp2_a7_afifo_18x1023 port map (
         din           => rxFifoDin,
         rd_clk        => locClk,
         rd_en         => rxFifoRd,
         rst           => pgpReset,
         wr_clk        => pgpClk,
         wr_en         => vcFrameRxValid,
         dout          => rxFifoDout,
         empty         => rxFifoEmpty,
         full          => rxFifoFull,
         wr_data_count => rxFifoCount
         );
   end generate;

   -- K7 Receive FIFO
   U_GenRxK7Fifo : if FifoType = "K7" generate
      U_RegRxK7Fifo : pgp2_k7_afifo_18x1023 port map (
         din           => rxFifoDin,
         rd_clk        => locClk,
         rd_en         => rxFifoRd,
         rst           => pgpReset,
         wr_clk        => pgpClk,
         wr_en         => vcFrameRxValid,
         dout          => rxFifoDout,
         empty         => rxFifoEmpty,
         full          => rxFifoFull,
         wr_data_count => rxFifoCount
         );
   end generate;

   -- Data valid
   process (locClk, locReset)
   begin
      if locReset = '1' then
         rxFifoValid <= '0' after tpd;
      elsif rising_edge(locClk) then
         if rxFifoRd = '1' then
            rxFifoValid <= '1' after tpd;
         elsif frameRxReady = '1' then
            rxFifoValid <= '0' after tpd;
         end if;
      end if;
   end process;

   -- Control reads
   rxFifoRd <= (not rxFifoEmpty) and ((not rxFifoValid) or frameRxReady);

   -- Outgoing signals
   frameRxValid <= rxFifoValid;
   frameRxSOF   <= '1' when rxFifoDout(17 downto 16) = "01" else '0';
   frameRxEOF   <= rxFifoDout(17);
   frameRxEOFE  <= '1' when rxFifoDout(17 downto 16) = "11" else '0';
   frameRxData  <= rxFifoDout(15 downto 0);

end Pgp2DsBuff;

