-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing package wrapper for direct 12b14b encode/decode
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

library surf;
use surf.StdRtlPkg.all;
use surf.Code12b14bPkg.all;

entity Code12b14bPkgWrapper is
   port (
      encDispIn   : in  slv(1 downto 0);
      encDataIn   : in  slv(11 downto 0);
      encDataKIn  : in  sl;
      encDataOut  : out slv(13 downto 0);
      encDispOut  : out slv(1 downto 0);
      decDispIn   : in  slv(1 downto 0);
      decDataIn   : in  slv(13 downto 0);
      decDataOut  : out slv(11 downto 0);
      decDataKOut : out sl;
      decDispOut  : out slv(1 downto 0);
      invalidK    : out sl;
      codeError   : out sl;
      dispError   : out sl);
end entity Code12b14bPkgWrapper;

architecture rtl of Code12b14bPkgWrapper is

begin

   ---------------------------------------------------------------------------
   -- Package-level encode/decode shim
   ---------------------------------------------------------------------------

   comb : process (decDataIn, decDispIn, encDataIn, encDataKIn, encDispIn) is
      variable encodedDataVar : slv(13 downto 0);
      variable encodedDispVar : slv(1 downto 0);
      variable invalidKVar    : sl;
      variable decodedDataVar : slv(11 downto 0);
      variable decodedKVar    : sl;
      variable decodedDispVar : slv(1 downto 0);
      variable codeErrorVar   : sl;
      variable dispErrorVar   : sl;
   begin
      encodedDataVar := (others => '0');
      encodedDispVar := encDispIn;
      invalidKVar    := '0';
      encode12b14b(
         CODES_C  => ENCODE_TABLE_C,
         dataIn   => encDataIn,
         dataKIn  => encDataKIn,
         dispIn   => encDispIn,
         dataOut  => encodedDataVar,
         dispOut  => encodedDispVar,
         invalidK => invalidKVar);
      if (encDataKIn = '0') then
         invalidKVar := '0';
      end if;

      decodedDataVar := (others => '0');
      decodedKVar    := '0';
      decodedDispVar := decDispIn;
      dispErrorVar   := '0';
      decode12b14b(
         CODES_C   => ENCODE_TABLE_C,
         dataIn    => decDataIn,
         dispIn    => decDispIn,
         dataOut   => decodedDataVar,
         dataKOut  => decodedKVar,
         dispOut   => decodedDispVar,
         codeError => codeErrorVar,
         dispError => dispErrorVar);

      encDataOut  <= encodedDataVar;
      encDispOut  <= encodedDispVar;
      invalidK    <= invalidKVar;
      decDataOut  <= decodedDataVar;
      decDataKOut <= decodedKVar;
      decDispOut  <= decodedDispVar;
      codeError   <= codeErrorVar;
      dispError   <= dispErrorVar;
   end process comb;

end architecture rtl;
