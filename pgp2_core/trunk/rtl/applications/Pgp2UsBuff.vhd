-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol Applications, Upstream Data Buffer
-- Project       : Reconfigurable Cluster Element
-------------------------------------------------------------------------------
-- File          : Pgp2UsBuff.vhd
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
-- 04/20/2015: added StdLib buffer support (should be used for all families) (by MK)
-------------------------------------------------------------------------------

library ieee;
--use work.all;
use work.StdRtlPkg.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity Pgp2UsBuff is
   generic (
      -- FifoType: (default = V5)
      -- V4 = Virtex 4,  V5 = Virtex 5, V6 = Virtex 6, V7 = Virtex 7, 
      -- S6 = Spartan 6, A7 = Artix 7,  K7 = kintex7, SL = StdLib
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
      frameTxData  : in  std_logic_vector(15 downto 0);
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
end Pgp2UsBuff;


-- Define architecture
architecture Pgp2UsBuff of Pgp2UsBuff is

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
   signal txFifoDin   : std_logic_vector(17 downto 0);
   signal txFifoDout  : std_logic_vector(17 downto 0);
   signal txFifoRd    : std_logic;
   signal txFifoCount : std_logic_vector(9 downto 0);
   signal txFifoEmpty : std_logic;
   signal txFifoFull  : std_logic;
   signal txFifoValid : std_logic;
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
--   attribute syn_black_box of FifoAsync : component is true;
--   attribute syn_noprune of FifoAsync   : component is true;

begin

   -- Data going into Tx FIFO
   txFifoDin(17 downto 16) <= "11" when frameTxEOFE = '1' or fifoErr = '1' else
                              "10" when frameTxEOF = '1' else
                              "01" when frameTxSOF = '1' else
                              "00";
   txFifoDin(15 downto 0) <= frameTxData;

   -- Generate fifo error signal
   process (locClk, locReset)
   begin
      if locReset = '1' then
         fifoErr      <= '0' after tpd;
         frameTxAFull <= '0' after tpd;
      elsif rising_edge(locClk) then

         -- Generate full error
         if txFifoCount >= 1020 or txFifoFull = '1' then
            fifoErr <= '1' after tpd;
         else
            fifoErr <= '0' after tpd;
         end if;

         -- Almost full at 1/2 capacity
         frameTxAFull <= txFifoFull or txFifoCount(9);

      end if;
   end process;

   -- V4 Receive FIFO
   U_GenRxV4Fifo : if FifoType = "V4" generate
      U_RegRxV4Fifo : pgp2_v4_afifo_18x1023 port map (
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
      U_RegRxV5Fifo : pgp2_v5_afifo_18x1023 port map (
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
      U_RegRxV6Fifo : pgp2_v6_afifo_18x1023 port map (
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
      U_RegRxV7Fifo : pgp2_v7_afifo_18x1023 port map (
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
      U_RegRxS6Fifo : pgp2_s6_afifo_18x1023 port map (
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
      U_RegRxA7Fifo : pgp2_a7_afifo_18x1023 port map (
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
      U_RegRxK7Fifo : pgp2_k7_afifo_18x1023 port map (
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
   
   -- StdLib Receive FIFO
   U_GenRxSLFifo : if FifoType = "SL" generate
      U_RegRxSLFifo : FifoAsync 
      generic map (
         RST_POLARITY_G => '1',
         DATA_WIDTH_G   => 18,
         ADDR_WIDTH_G   => 10
      )
      port map ( 
         rst               => pgpReset,
         wr_clk            => locClk,
         wr_en             => frameTxValid,
         din               => txFifoDin,
         wr_data_count     => txFifoCount,
         wr_ack            => open,
         overflow          => open,
         prog_full         => open,
         almost_full       => open,
         full              => txFifoFull,
         not_full          => open,
         rd_clk            => pgpClk,
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
   process (pgpClk, pgpReset)
   begin
      if pgpReset = '1' then
         txFifoValid <= '0' after tpd;
      elsif rising_edge(pgpClk) then
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

end Pgp2UsBuff;

