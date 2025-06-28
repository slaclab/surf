-------------------------------------------------------------------------------
-- Title      : PGPv4: https://confluence.slac.stanford.edu/x/1dzgEQ
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Used to overwrite the txData with FEC code markers
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library surf;
use surf.StdRtlPkg.all;

entity Pgp4TxFecMarkers is
   generic (
      TPD_G       : time    := 1 ns;
      RST_ASYNC_G : boolean := false);
   port (
      pgpTxClk   : in  sl;
      pgpTxRst   : in  sl;
      -- Inbound Interface
      ibTxReady  : out sl;
      ibTxValid  : in  sl;
      ibTxStart  : in  sl;
      ibTxFecCw  : in  sl;
      ibTxData   : in  slv(63 downto 0);
      ibTxHeader : in  slv(1 downto 0);
      -- Output Interface
      obTxReady  : in  sl;
      obTxValid  : out sl;
      obTxStart  : out sl;
      obTxFecCw  : out sl;
      obTxData   : out slv(63 downto 0);
      obTxHeader : out slv(1 downto 0));
end entity Pgp4TxFecMarkers;

architecture rtl of Pgp4TxFecMarkers is

   -- IEEE 802.3 25G RS-FEC: Code words
   constant PGP4_FEC_CW_C : Slv64Array(3 downto 0) := (
      0 => endianSwap(x"C16821333E97DECC"),
      1 => endianSwap(x"F0C4E6330F3B19CC"),
      2 => endianSwap(x"C5659B333A9A64CC"),
      3 => endianSwap(x"A2793D335D86C2CC"));

   type RegType is record
      ibTxReady  : sl;
      obTxValid  : sl;
      obTxStart  : sl;
      obTxFecCw  : sl;
      obTxData   : slv(63 downto 0);
      obTxHeader : slv(1 downto 0);
      fecCwIndex : natural range 0 to 3;
   end record RegType;

   constant REG_INIT_C : RegType := (
      ibTxReady  => '0',
      obTxValid  => '0',
      obTxStart  => '0',
      obTxFecCw  => '0',
      obTxData   => (others => '0'),
      obTxHeader => (others => '0'),
      fecCwIndex => 0);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (ibTxData, ibTxFecCw, ibTxHeader, ibTxStart, ibTxValid,
                   obTxReady, pgpTxRst, r) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Flow control
      v.ibTxReady := '0';
      if (obTxReady = '1') then
         v.obTxValid := '0';
      end if;

      -- Check if need and able to move data
      if (ibTxValid = '1') and (v.obTxValid = '0') then

         -- Accept and move data
         v.ibTxReady := '1';
         v.obTxValid := '1';

         -- Set the metadata
         v.obTxStart  := ibTxStart;
         v.obTxFecCw  := ibTxFecCw;
         v.obTxHeader := ibTxHeader;

         -- Check if no marker
         if (ibTxFecCw = '0') then

            -- Pass through the data
            v.obTxData := ibTxData;

            -- Reset the index
            v.fecCwIndex := 0;

         else

            -- Overwrite and send the code word
            v.obTxData := PGP4_FEC_CW_C(r.fecCwIndex);

            -- Increment the counter
            if (r.fecCwIndex /= 3) then
               v.fecCwIndex := r.fecCwIndex + 1;
            end if;

         end if;

      end if;

      -- Outputs
      ibTxReady  <= v.ibTxReady;
      obTxValid  <= r.obTxValid;
      obTxStart  <= r.obTxStart;
      obTxFecCw  <= r.obTxFecCw;
      obTxData   <= r.obTxData;
      obTxHeader <= r.obTxHeader;

      -- Reset
      if (RST_ASYNC_G = false and pgpTxRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (pgpTxClk, pgpTxRst) is
   begin
      if (RST_ASYNC_G) and (pgpTxRst = '1') then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(pgpTxClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
