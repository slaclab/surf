-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : SspDecoder10b12b.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-07-14
-- Last update: 2016-10-24
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: SimpleStreamingProtocol - A simple protocol layer for inserting
-- idle and framing control characters into a raw data stream. This module
-- ties the framing core to an RTL 10b12b encoder.
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
use IEEE.STD_LOGIC_ARITH.all;

use work.StdRtlPkg.all;
use work.Code10b12bPkg.all;

entity SspDecoder10b12b is

   generic (
      TPD_G          : time    := 1 ns;
      RST_POLARITY_G : sl      := '0';
      RST_ASYNC_G    : boolean := true);

   port (
      clk       : in  sl;
      rst       : in  sl := RST_POLARITY_G;
      dataIn    : in  slv(11 downto 0);
      dataOut   : out slv(9 downto 0);
      valid     : out sl;
      sof       : out sl;
      eof       : out sl;
      eofe      : out sl;
      codeError : out sl;
      dispError : out sl);

end entity SspDecoder10b12b;

architecture rtl of SspDecoder10b12b is

   signal framedData  : slv(9 downto 0);
   signal framedDataK : slv(0 downto 0);

begin

   Decoder10b12b_1 : entity work.Decoder10b12b
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G)
      port map (
         clk       => clk,
         clkEn     => '1',
         rst       => rst,
         dataIn    => dataIn,
         dataOut   => framedData,
         dataKOut  => framedDataK(0),
         codeError => codeError,
         dispError => dispError);

   SspDeframer_1 : entity work.SspDeframer
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => RST_POLARITY_G,
         RST_ASYNC_G     => RST_ASYNC_G,
         WORD_SIZE_G     => 10,
         K_SIZE_G        => 1,
         SSP_IDLE_CODE_G => K_28_3_C,
         SSP_IDLE_K_G    => "1",
         SSP_SOF_CODE_G  => K_28_10_C,
         SSP_SOF_K_G     => "1",
         SSP_EOF_CODE_G  => K_28_21_C,
         SSP_EOF_K_G     => "1")
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
