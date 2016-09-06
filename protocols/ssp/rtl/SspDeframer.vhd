-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : SspDeframer.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-07-14
-- Last update: 2014-08-22
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: SimpleStreamingProtocol - A simple protocol layer for inserting
-- idle and framing control characters into a raw data stream. The input of
-- module should be attached to an 8b10b deencoder.
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

entity SspDeframer is
   
   generic (
      TPD_G          : time    := 1 ns;
      RST_POLARITY_G : sl      := '0';
      RST_ASYNC_G    : boolean := true);

   port (
      clk     : in  sl;
      rst     : in  sl := RST_POLARITY_G;
      dataIn  : in  slv(15 downto 0);
      dataKIn : in  slv(1 downto 0);
      dataOut : out slv(15 downto 0);
      valid   : out sl;
      sof     : out sl;
      eof     : out sl;
      eofe    : out sl);


end entity SspDeframer;

architecture rtl of SspDeframer is

   constant WAIT_SOF_S : sl := '0';
   constant WAIT_EOF_S : sl := '1';

   type RegType is record
      state       : sl;
      dataInLast  : slv(15 downto 0);
      dataKInLast : slv(1 downto 0);
      dataOut     : slv(15 downto 0);
      valid       : sl;
      sof         : sl;
      eof         : sl;
      eofe        : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state       => WAIT_SOF_S,
      dataInLast  => (others => '0'),
      dataKInLast => (others => '0'),
      dataOut     => (others => '0'),
      valid       => '0',
      sof         => '0',
      eof         => '0',
      eofe        => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (dataIn, dataKIn, r, rst) is
      variable v : RegType;
   begin
      v := r;

      v.dataOut := dataIn;
      v.valid   := '0';
      v.sof     := '0';
      v.eof     := '0';
      v.eofe    := '0';

      if (r.state = WAIT_SOF_S) then
         
         if (dataKIn = "01") then
            if (dataIn = SSP_SOF_CHAR_C) then
               -- Correct SOF
               v.sof   := '1';
               v.valid := '1';
               v.state := WAIT_EOF_S;
            elsif (dataIn /= SSP_IDLE_CHAR_C) then
               -- Incorrect SOF or IDLE
               v.eof   := '1';
               v.eofe  := '1';
               v.valid := '1';
            end if;
         else
            -- Incorrect IDLE
            v.eof   := '1';
            v.eofe  := '1';
            v.valid := '1';
         end if;

      elsif (r.state = WAIT_EOF_S) then
         
         v.valid := '1';
         if (dataKIn = "01") then
            v.state := WAIT_SOF_S;
            if (dataIn = SSP_EOF_CHAR_C) then
               -- Correct EOF
               v.eof := '1';
            else
               -- Incorrect EOF
               v.eof  := '1';
               v.eofe := '1';
            end if;
         elsif (dataKin /= "00") then
            -- Incorrect dataK
            v.state := WAIT_SOF_S;
            v.eof   := '1';
            v.eofe  := '1';
         end if;

      end if;

      if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      rin     <= v;
      dataOut <= r.dataOut;
      valid   <= r.valid;
      sof     <= r.sof;
      eof     <= r.eof;
      eofe    <= r.eofe;

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
