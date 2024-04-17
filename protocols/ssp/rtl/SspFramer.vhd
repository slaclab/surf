-------------------------------------------------------------------------------
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;

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
      -- Clock and Reset
      clk      : in  sl;
      rst      : in  sl := RST_POLARITY_G;
      -- Inbound Ports
      validIn  : in  sl;
      readyIn  : out sl;
      dataIn   : in  slv(WORD_SIZE_G-1 downto 0);
      sof      : in  sl := '0';
      eof      : in  sl := '0';
      -- Outbound Ports
      validOut : out sl;
      readyOut : in  sl := '1';
      dataOut  : out slv(WORD_SIZE_G-1 downto 0);
      dataKOut : out slv(K_SIZE_G-1 downto 0));
end entity SspFramer;

architecture rtl of SspFramer is

   type StateType is (
      IDLE_S,
      DATA_S,
      EOF_S);

   type RegType is record
      readyIn  : sl;
      validOut : sl;
      dataOut  : slv(WORD_SIZE_G-1 downto 0);
      dataKOut : slv(K_SIZE_G-1 downto 0);
      state    : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      readyIn  => '0',
      validOut => toSl(not FLOW_CTRL_EN_G),
      dataKOut => (others => '0'),
      dataOut  => (others => '0'),
      state    => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (dataIn, eof, r, readyOut, rst, sof, validIn) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Flow control
      v.readyIn := '0';
      if (readyOut = '1') or (FLOW_CTRL_EN_G = false) then
         v.validOut := '0';
      end if;

      -- State machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check if we are ready to move data
            if (v.validOut = '0') then

               -- Send commas
               v.validOut := '1';
               v.dataOut  := SSP_IDLE_CODE_G;
               v.dataKOut := SSP_IDLE_K_G;

               -- Check for data
               if (validIn = '1' and (sof = '1' or AUTO_FRAME_G)) then

                  -- Send the SOF
                  v.dataOut  := SSP_SOF_CODE_G;
                  v.dataKOut := SSP_SOF_K_G;

                  -- Next state
                  v.state := DATA_S;

               end if;
            end if;
         ----------------------------------------------------------------------
         when DATA_S =>
            -- Check if we are ready to move data
            if (v.validOut = '0') then

               -- Send commas
               v.validOut := '1';
               v.dataOut  := SSP_IDLE_CODE_G;
               v.dataKOut := SSP_IDLE_K_G;

               -- Check for data
               if (validIn = '1') then

                  -- Accept the data
                  v.readyIn := '1';

                  -- Move the data
                  v.dataOut  := dataIn;
                  v.dataKOut := slvZero(K_SIZE_G);

                  -- Check for EOF
                  if (eof = '1') then
                     -- Next state
                     v.state := EOF_S;
                  end if;

               end if;
            end if;

            -- Allow exit to EOF_S for auto frame mode
            if (AUTO_FRAME_G and validIn = '0') then
               v.state := EOF_S;
            end if;
         ----------------------------------------------------------------------
         when EOF_S =>
            -- Check if we are ready to move data
            if (v.validOut = '0') then

               -- Send EOF
               v.validOut := '1';
               v.dataOut  := SSP_EOF_CODE_G;
               v.dataKOut := SSP_EOF_K_G;

               -- Next state
               v.state := IDLE_S;

            end if;
      ----------------------------------------------------------------------
      end case;

      -- Outputs
      readyIn  <= v.readyIn;
      dataOut  <= r.dataOut;
      dataKOut <= r.dataKOut;
      validOut <= r.validOut;

      -- Reset
      if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

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

end rtl;
