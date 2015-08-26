-------------------------------------------------------------------------------
-- Title      : SLAC Asynchronous Logic Transceiver (SALT)
-------------------------------------------------------------------------------
-- File       : SaltCore.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-15
-- Last update: 2015-08-25
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: SALT Core
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;

entity SaltCore is
   generic (
      TPD_G           : time            := 1 ns;
      NUM_BYTES_G     : positive        := 2;
      COMMA_EN_G      : slv(3 downto 0) := "0011";
      COMMA_0_G       : slv             := "----------0101111100";
      COMMA_1_G       : slv             := "----------1010000011";
      COMMA_2_G       : slv             := "XXXXXXXXXXXXXXXXXXXX";
      COMMA_3_G       : slv             := "XXXXXXXXXXXXXXXXXXXX";
      IODELAY_GROUP_G : string          := "SALT_IODELAY_GRP";
      RXCLK2X_FREQ_G  : real            := 200.0;  -- In units of MHz
      XIL_DEVICE_G    : string          := "7SERIES");
   port (
      loopback   : in  sl := '0';
      -- TX Serial Stream
      txP        : out sl;
      txN        : out sl;
      txInv      : in  sl := '0';       -- '1' to invert the serial bit
      -- RX Serial Stream
      rxP        : in  sl;
      rxN        : in  sl;
      rxInv      : in  sl := '0';       -- '1' to invert the serial bit
      -- TX Parallel 8B/10B data bus
      txDataIn   : in  slv(NUM_BYTES_G*8-1 downto 0);
      txDataKIn  : in  slv(NUM_BYTES_G-1 downto 0);
      txPhyReady : out sl;
      -- RX Parallel 8B/10B data bus
      rxDataOut  : out slv(NUM_BYTES_G*8-1 downto 0);
      rxDataKOut : out slv(NUM_BYTES_G-1 downto 0);
      rxCodeErr  : out slv(NUM_BYTES_G-1 downto 0);
      rxDispErr  : out slv(NUM_BYTES_G-1 downto 0);
      rxPhyReady : out sl;
      -- Clock and Reset
      refClk     : in  sl;              -- IODELAY's Reference Clock
      refRst     : in  sl;
      txClkEn    : out sl;
      txClk      : in  sl;
      txRst      : in  sl;
      rxClkEn    : out sl;
      rxClk      : in  sl;              -- Equal frequency of txClk (independent of txClk phase)
      rxClk2x    : in  sl;              -- Twice the frequency of rxClk (independent of rxClk phase)
      rxClk2xInv : in  sl;              -- Twice the frequency of rxClk (180 phase of rxClk2x)
      rxRst      : in  sl);
end SaltCore;

architecture rtl of SaltCore is

   signal txClkEnable : sl;

   signal loopClkEn : sl;
   signal loopData  : slv(NUM_BYTES_G*8-1 downto 0);
   signal loopDataK : slv(NUM_BYTES_G-1 downto 0);

   signal rxReady     : sl;
   signal rxClkEnable : sl;
   signal rxData      : slv(NUM_BYTES_G*8-1 downto 0);
   signal rxDataK     : slv(NUM_BYTES_G-1 downto 0);
   signal rxCodeError : slv(NUM_BYTES_G-1 downto 0);
   signal rxDispError : slv(NUM_BYTES_G-1 downto 0);
   
begin

   txClkEn    <= txClkEnable;
   rxClkEn    <= rxClkEnable when(loopback = '0') else loopClkEn;
   rxDataOut  <= rxData      when(loopback = '0') else loopData;
   rxDataKOut <= rxDataK     when(loopback = '0') else loopDataK;
   rxCodeErr  <= rxCodeError when(loopback = '0') else (others => '0');
   rxDispErr  <= rxDispError when(loopback = '0') else (others => '0');
   rxPhyReady <= rxReady     when(loopback = '0') else not(rxRst);

   SaltTx_Inst : entity work.SaltTx
      generic map(
         TPD_G       => TPD_G,
         NUM_BYTES_G => NUM_BYTES_G)
      port map(
         -- TX Serial Stream
         txP        => txP,
         txN        => txN,
         txInv      => txInv,
         -- TX Parallel 8B/10B data bus
         txDataIn   => txDataIn,
         txDataKIn  => txDataKIn,
         txPhyReady => txPhyReady,
         -- Clock and Reset
         txClkEn    => txClkEnable,
         txClk      => txClk,
         txRst      => txRst);

   SynchronizerFifo_Inst : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => NUM_BYTES_G*9)
      port map (
         rst                                        => rxRst,
         -- Write Ports (wr_clk domain)
         wr_clk                                     => txClk,
         wr_en                                      => txClkEnable,
         din(NUM_BYTES_G*9-1 downto NUM_BYTES_G*8)  => txDataKIn,
         din(NUM_BYTES_G*8-1 downto 0)              => txDataIn,
         -- Read Ports (rd_clk domain)
         rd_clk                                     => rxClk,
         rd_en                                      => '1',
         valid                                      => loopClkEn,
         dout(NUM_BYTES_G*9-1 downto NUM_BYTES_G*8) => loopDataK,
         dout(NUM_BYTES_G*8-1 downto 0)             => loopData);  

   SaltRx_Inst : entity work.SaltRx
      generic map(
         TPD_G           => TPD_G,
         NUM_BYTES_G     => NUM_BYTES_G,
         COMMA_EN_G      => COMMA_EN_G,
         COMMA_0_G       => COMMA_0_G,
         COMMA_1_G       => COMMA_1_G,
         COMMA_2_G       => COMMA_2_G,
         COMMA_3_G       => COMMA_3_G,
         XIL_DEVICE_G    => XIL_DEVICE_G,
         RXCLK2X_FREQ_G  => RXCLK2X_FREQ_G,
         IODELAY_GROUP_G => IODELAY_GROUP_G)
      port map(
         -- TX Serial Stream
         rxP        => rxP,
         rxN        => rxN,
         rxInv      => rxInv,
         -- RX Parallel 8B/10B data bus
         rxDataOut  => rxData,
         rxDataKOut => rxDataK,
         rxCodeErr  => rxCodeError,
         rxDispErr  => rxDispError,
         rxPhyReady => rxReady,
         -- Clock and Reset
         refClk     => refClk,
         refRst     => refRst,
         rxClkEn    => rxClkEnable,
         rxClk      => rxClk,
         rxClk2x    => rxClk2x,
         rxClk2xInv => rxClk2xInv,
         rxRst      => rxRst);         

end rtl;
