-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : SspDecoder.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-07-14
-- Last update: 2014-08-22
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: SimpleStreamingProtocol - A simple protocol layer for inserting
-- idle and framing control characters into a raw data stream. This module
-- ties the framing core to an RTL 8b10b encoder.
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
use IEEE.STD_LOGIC_ARITH.all;

use work.StdRtlPkg.all;
use work.Code8b10bPkg.all;

entity SspDecoder is
   
   generic (
      TPD_G          : time    := 1 ns;
      RST_POLARITY_G : sl      := '0';
      RST_ASYNC_G    : boolean := true);

   port (
      clk     : in  sl;
      rst     : in  sl := RST_POLARITY_G;
      dataIn  : in  slv(19 downto 0);
      dataOut : out slv(15 downto 0);
      valid   : out sl;
      sof     : out sl;
      eof     : out sl;
      eofe    : out sl);

end entity SspDecoder;

architecture rtl of SspDecoder is

   signal framedData  : slv(15 downto 0);
   signal framedDataK : slv(1 downto 0);

begin
   
   Decoder8b10b_1 : entity work.Decoder8b10b
      generic map (
         TPD_G          => TPD_G,
         NUM_BYTES_G    => 2,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G)
      port map (
         clk      => clk,
         clkEn    => '1',
         rst      => rst,
         dataIn   => dataIn,
         dataOut  => framedData,
         dataKOut => framedDataK,
         codeErr  => open,
         dispErr  => open);

   SspDeframer_1 : entity work.SspDeframer
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G)
      port map (
         clk     => clk,
         rst     => rst,
         dataIn  => framedData,
         dataKIn => framedDataK,
         dataOut => dataOut,
         valid   => valid,
         sof     => sof,
         eof     => eof,
         eofe    => eofe);



end architecture rtl;
