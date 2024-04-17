-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: SimpleStreamingProtocol - A simple protocol layer for inserting
-- idle and framing control characters into a raw data stream. The input of
-- module should be attached to an 8b10b decoder.
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

library surf;
use surf.StdRtlPkg.all;

entity SspDeframer is

   generic (
      TPD_G                : time    := 1 ns;
      RST_POLARITY_G       : sl      := '0';
      RST_ASYNC_G          : boolean := true;
      WORD_SIZE_G          : integer := 16;
      K_SIZE_G             : integer := 2;
      BRK_FRAME_ON_ERROR_G : boolean := true;
      SSP_IDLE_CODE_G      : slv;
      SSP_IDLE_K_G         : slv;
      SSP_SOF_CODE_G       : slv;
      SSP_SOF_K_G          : slv;
      SSP_EOF_CODE_G       : slv;
      SSP_EOF_K_G          : slv);
   port (
      -- Clock and Reset
      clk            : in  sl;
      rst            : in  sl := RST_POLARITY_G;
      -- Input Interface
      dataKIn        : in  slv(K_SIZE_G-1 downto 0);
      dataIn         : in  slv(WORD_SIZE_G-1 downto 0);
      validIn        : in  sl;
      decErrIn       : in  sl := '0';
      dispErrIn      : in  sl := '0';   -- Unused
      gearboxAligned : in  sl := '1';
      -- Output Interface
      dataOut        : out slv(WORD_SIZE_G-1 downto 0);
      validOut       : out sl;
      errorOut       : out sl;
      idle           : out sl;
      sof            : out sl;
      eof            : out sl;
      eofe           : out sl);
end entity SspDeframer;

architecture rtl of SspDeframer is

   constant WAIT_SOF_S : sl := '0';
   constant WAIT_EOF_S : sl := '1';

   type RegType is record
      state : sl;

      -- Internal
      iDataOut  : slv(WORD_SIZE_G-1 downto 0);
      iValidOut : sl;
      iSof      : sl;
      iEof      : sl;
      iEofe     : sl;

      -- Output registers
      dataOut  : slv(WORD_SIZE_G-1 downto 0);
      validOut : sl;
      errorOut : sl;
      idle     : sl;
      sof      : sl;
      eof      : sl;
      eofe     : sl;

   end record RegType;

   constant REG_INIT_C : RegType := (
      state     => WAIT_SOF_S,
      iDataOut  => (others => '0'),
      iValidOut => '0',
      iSof      => '0',
      iEof      => '0',
      iEofe     => '0',
      dataOut   => (others => '0'),
      validOut  => '0',
      errorOut  => '0',
      idle      => '0',
      sof       => '0',
      eof       => '0',
      eofe      => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (dataIn, dataKIn, decErrIn, gearboxAligned, r, rst, validIn) is
      variable v : RegType;
   begin
      v := r;

      v.errorOut := '0';

      if (validIn = '1') then

         if (dataKIn = SSP_IDLE_K_G) and (dataIn = SSP_IDLE_CODE_G) then
            v.idle := '1';
         else
            v.idle := '0';
         end if;

         if (r.state = WAIT_SOF_S) then

            v.iSof  := '0';
            v.iEof  := '0';
            v.iEofe := '0';

            if (dataKin /= slvZero(K_SIZE_G) and decErrIn = '0') then

               if (dataKIn = SSP_IDLE_K_G) and (dataIn = SSP_IDLE_CODE_G) then
                  -- Ignore idle codes
                  v.iSof      := '0';
                  v.iEof      := '0';
                  v.iEofe     := '0';
                  v.iValidOut := '0';

               elsif (dataKIn = SSP_SOF_K_G) and (dataIn = SSP_SOF_CODE_G) then
                  -- Correct SOF
                  v.iSof      := '1';
                  v.iValidOut := '0';
                  v.state     := WAIT_EOF_S;

               else
                  -- Invalid K Code
                  v.iEof      := '1';
                  v.iEofe     := '1';
                  v.iValidOut := '1';
                  v.errorOut  := '1';
               end if;
            else
               v.errorOut := '1';
            end if;

         elsif (r.state = WAIT_EOF_S) then

            -- Expect data to come
            -- Will be overridden if IDLE char seen
            v.iValidOut := '1';
            v.iDataOut  := dataIn;

            -- sof is asserted without valid in previous state
            -- Hold it until the first data arrives
            if (r.iValidOut = '1') then
               v.iSof := '0';
            end if;


            if (dataKin /= slvZero(K_SIZE_G)) then

               if (dataKin = SSP_EOF_K_G and dataIn = SSP_EOF_CODE_G) then
                  v.iEof      := '1';
                  v.iValidOut := '0';
                  v.state     := WAIT_SOF_S;

               elsif (dataKIn = SSP_IDLE_K_G and dataIn = SSP_IDLE_CODE_G) then
                  -- Ignore idle codes that arrive mid frame
                  v.iValidOut := '0';

               else

                  -- Unknown and/or incorrect K CODE
                  if BRK_FRAME_ON_ERROR_G then
                     v.iValidOut := '0';
                     v.iEof      := '1';
                     v.iEofe     := '1';
                     v.state     := WAIT_SOF_S;
                  else
                     v.iValidOut := '0';
                     v.iEofe     := '1';
                  end if;

               end if;

            end if;

            if (decErrIn = '1') then
               v.iEofe    := '1';
               v.errorOut := '1';
            end if;

         end if;

      end if;

      ----------------------------------------------------------------------------------------------
      -- Delay buffer to output SOF on first valid and EOF/EOFE on last valid
      ----------------------------------------------------------------------------------------------
      v.validOut := '0';
      if ((v.iValidOut = '1' or v.iEof = '1') and r.iValidOut = '1') then
         -- If new data arrived an existing data is waiting,
         -- Advance the pipeline and output the waiting data
         v.validOut := validIn;
         v.sof      := r.iSof;
         v.eof      := v.iEof;
         v.eofe     := v.iEofe;
         v.dataOut  := r.iDataOut;
      end if;

      -- Check if the gearbox is not aligned
      if (gearboxAligned = '0') then
         v.validOut := '0';
         v.state    := WAIT_SOF_S;
      end if;

      if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      rin      <= v;
      dataOut  <= r.dataOut;
      validOut <= r.validOut;
      errorOut <= r.errorOut;
      idle     <= r.idle;
      sof      <= r.sof;
      eof      <= r.eof;
      eofe     <= r.eofe;

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
