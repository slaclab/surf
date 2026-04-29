-------------------------------------------------------------------------------
-- Title      : PGPv4: https://confluence.slac.stanford.edu/x/1dzgEQ
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PGPv4 Rx K-code Checksum Checker
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
use surf.Pgp4Pkg.all;

entity Pgp4RxKCodeChecker is
   generic (
      TPD_G          : time    := 1 ns;
      RST_POLARITY_G : sl      := '1';  -- '1' for active HIGH reset, '0' for active LOW reset
      RST_ASYNC_G    : boolean := false);
   port (
      phyRxClk     : in  sl;
      phyRxRst     : in  sl;
      phyRxValid   : in  sl;
      phyRxData    : in  slv(63 downto 0);
      phyRxHeader  : in  slv(1 downto 0);
      checkedValid  : out sl;
      checkedData   : out slv(63 downto 0);
      checkedHeader : out slv(1 downto 0);
      linkError     : out sl);
end entity Pgp4RxKCodeChecker;

architecture rtl of Pgp4RxKCodeChecker is

   type RegType is record
      checkedValid  : sl;
      checkedData   : slv(63 downto 0);
      checkedHeader : slv(1 downto 0);
      linkError     : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      checkedValid  => '0',
      checkedData   => (others => '0'),
      checkedHeader => (others => '0'),
      linkError     => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (phyRxData, phyRxHeader, phyRxRst, phyRxValid, r) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Map to output register
      v.checkedValid  := phyRxValid;
      v.checkedData   := phyRxData;
      v.checkedHeader := phyRxHeader;
      v.linkError     := '0';

      -- Drop K-codes with invalid checksum
      if (phyRxValid = '1') and (phyRxHeader = PGP4_K_HEADER_C) and
         (phyRxData(PGP4_K_CODE_CRC_FIELD_C) /= pgp4KCodeCrc(phyRxData)) then
         v.checkedValid := '0';
         v.linkError    := '1';
      end if;

      -- Reset
      if (RST_ASYNC_G = false and phyRxRst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (phyRxClk, phyRxRst) is
   begin
      if (RST_ASYNC_G) and (phyRxRst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(phyRxClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   checkedValid  <= r.checkedValid;
   checkedData   <= r.checkedData;
   checkedHeader <= r.checkedHeader;
   linkError     <= r.linkError;

end architecture rtl;
