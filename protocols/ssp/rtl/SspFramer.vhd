-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : SspFramer.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-07-14
-- Last update: 2014-08-27
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: SimpleStreamingProtocol - A simple protocol layer for inserting
-- idle and framing control characters into a raw data stream. The output of
-- module should be attached to an 8b10b encoder.
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
use IEEE.STD_LOGIC_ARITH.all;

use work.StdRtlPkg.all;
use work.Code8b10bPkg.all;
use work.SspPkg.all;

entity SspFramer is
   
   generic (
      TPD_G          : time    := 1 ns;
      RST_POLARITY_G : sl      := '0';
      RST_ASYNC_G    : boolean := true);

   port (
      clk      : in  sl;
      rst      : in  sl := RST_POLARITY_G;
      valid    : in  sl;
      dataIn   : in  slv(15 downto 0);
      dataOut  : out slv(15 downto 0);
      dataKOut : out slv(1 downto 0));

end entity SspFramer;

architecture rtl of SspFramer is

   constant IDLE_MODE_C : sl := '0';
   constant DATA_MODE_C : sl := '1';

   type RegType is record
      mode       : sl;
      dataInLast : slv(15 downto 0);
      validLast  : sl;
      dataOut    : slv(15 downto 0);
      dataKOut   : slv(1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      mode       => '0',
      dataInLast => (others => '0'),
      validLast  => '0',
      dataKOut   => "01",
      dataOut    => SSP_IDLE_CHAR_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (dataIn, r, rst, valid) is
      variable v : RegType;
   begin
      v := r;

      v.dataInLast := dataIn;
      v.validLast  := valid;

      -- Send commas while waiting for valid, then send SOF
      if (r.mode = IDLE_MODE_C) then
         v.dataOut  := SSP_IDLE_CHAR_C;
         v.dataKOut := "01";
         if (valid = '1') then
            v.dataOut  := SSP_SOF_CHAR_C;
            v.dataKOut := "01";
            v.mode     := DATA_MODE_C;
         end if;

      -- Send pipline delayed data, send eof when delayed valid falls
      elsif (r.mode = DATA_MODE_C) then
         v.dataOut  := r.dataInLast;
         v.dataKOut := "00";
         if (r.validLast = '0') then
            v.dataOut  := SSP_EOF_CHAR_C;
            v.dataKOut := "01";
            v.mode     := IDLE_MODE_C;
         end if;

      end if;

      if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      rin      <= v;
      dataOut  <= r.dataOut;
      dataKOut <= r.dataKOut;

   end process comb;

   -- Sequential process
   seq : process (clk, rst) is
   begin
      if (RST_ASYNC_G = true and rst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      elsif (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
