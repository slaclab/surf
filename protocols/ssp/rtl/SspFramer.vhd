-------------------------------------------------------------------------------
-- File       : SspFramer.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: SimpleStreamingProtocol - A simple protocol layer for inserting
-- idle and framing control characters into a raw data stream. The output of
-- module should be attached to an 8b10b encoder.
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
use IEEE.STD_LOGIC_ARITH.all;

use work.StdRtlPkg.all;

entity SspFramer is

   generic (
      TPD_G           : time    := 1 ns;
      RST_POLARITY_G  : sl      := '0';
      RST_ASYNC_G     : boolean := true;
      AUTO_FRAME_G    : boolean := true;
      FLOW_CTRL_EN_G  : boolean := false;
      WORD_SIZE_G     : integer := 16;
      K_SIZE_G        : integer := 2;
      SSP_IDLE_CODE_G : slv;
      SSP_IDLE_K_G    : slv;
      SSP_SOF_CODE_G  : slv;
      SSP_SOF_K_G     : slv;
      SSP_EOF_CODE_G  : slv;
      SSP_EOF_K_G     : slv);

   port (
      clk      : in  sl;
      rst      : in  sl := RST_POLARITY_G;
      validIn  : in  sl;
      readyIn  : out sl;
      dataIn   : in  slv(WORD_SIZE_G-1 downto 0);
      sof      : in  sl := '0';
      eof      : in  sl := '0';
      validOut : out sl;
      readyOut : in  sl := '1';
      dataOut  : out slv(WORD_SIZE_G-1 downto 0);
      dataKOut : out slv(K_SIZE_G-1 downto 0));

end entity SspFramer;

architecture rtl of SspFramer is

   constant IDLE_MODE_C : sl := '0';
   constant DATA_MODE_C : sl := '1';

   type RegType is record
      readyIn     : sl;
      validOut    : sl;
      mode        : sl;
      eofLast     : sl;
      eof         : sl;
      dataInLast  : slv(WORD_SIZE_G-1 downto 0);
      validInLast : sl;
      dataOut     : slv(WORD_SIZE_G-1 downto 0);
      dataKOut    : slv(K_SIZE_G-1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      readyIn     => '0',
      validOut    => toSl(not FLOW_CTRL_EN_G),
      mode        => '0',
      eofLast     => '0',
      eof         => '0',
      dataInLast  => (others => '0'),
      validInLast => '0',
      dataKOut    => (others => '0'),
      dataOut     => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (dataIn, eof, r, readyOut, rst, sof, validIn) is
      variable v : RegType;
   begin
      v := r;

      v.readyIn := readyOut;

      if (readyOut = '1' and FLOW_CTRL_EN_G) then
         v.validOut := '0';
      end if;

      if (v.validOut = '0' or FLOW_CTRL_EN_G = false) then
         v.validOut    := '1';
         v.dataInLast  := dataIn;
         v.validInLast := validIn;
         v.eofLast     := eof;

         -- Send commas while waiting for valid, then send SOF
         if (r.mode = IDLE_MODE_C) then
            v.dataOut  := SSP_IDLE_CODE_G;
            v.dataKOut := SSP_IDLE_K_G;
            if (validIn = '1' and (sof = '1' or AUTO_FRAME_G)) then
               v.dataOut  := SSP_SOF_CODE_G;
               v.dataKOut := SSP_SOF_K_G;
               v.mode     := DATA_MODE_C;
            end if;

         -- Send pipline delayed data, send eof when delayed valid falls
         elsif (r.mode = DATA_MODE_C) then
            v.dataOut  := r.dataInLast;
            v.dataKOut := slvZero(K_SIZE_G);
            v.eof      := r.validInLast and r.eofLast;
            if (r.validInLast = '0') then
               if (AUTO_FRAME_G or r.eof = '1') then
                  v.dataOut  := SSP_EOF_CODE_G;
                  v.dataKOut := SSP_EOF_K_G;
                  v.mode     := IDLE_MODE_C;
               else
                  -- if not auto framing and valid drops, insert idle char
                  v.dataOut  := SSP_IDLE_CODE_G;
                  v.dataKOut := SSP_EOF_K_G;
               end if;
            end if;
         end if;
      end if;

      readyIn <= v.readyIn;

      if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      rin      <= v;
      dataOut  <= r.dataOut;
      dataKOut <= r.dataKOut;
      validOut <= r.validOut;


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
