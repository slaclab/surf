-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing package wrapper for direct 10b12b encode/decode
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
use surf.Code10b12bPkg.all;

entity Code10b12bPkgWrapper is
   port (
      encDispIn   : in  sl;
      encDataIn   : in  slv(9 downto 0);
      encDataKIn  : in  sl;
      encDataOut  : out slv(11 downto 0);
      encDispOut  : out sl;
      decDispIn   : in  sl;
      decDataIn   : in  slv(11 downto 0);
      decDataOut  : out slv(9 downto 0);
      decDataKOut : out sl;
      decDispOut  : out sl;
      codeError   : out sl;
      dispError   : out sl);
end entity Code10b12bPkgWrapper;

architecture rtl of Code10b12bPkgWrapper is

begin

   ---------------------------------------------------------------------------
   -- Package-level encode/decode shim
   ---------------------------------------------------------------------------

   comb : process (decDataIn, decDispIn, encDataIn, encDataKIn, encDispIn) is
      variable encodedDataVar : slv(11 downto 0);
      variable encodedDispVar : sl;
      variable decodedDataVar : slv(9 downto 0);
      variable decodedKVar    : sl;
      variable decodedDispVar : sl;
      variable codeErrorVar   : sl;
      variable dispErrorVar   : sl;
   begin
      encode10b12b(
         dataIn  => encDataIn,
         dataKIn => encDataKIn,
         dispIn  => encDispIn,
         dataOut => encodedDataVar,
         dispOut => encodedDispVar);

      decodedKVar    := '0';
      decodedDispVar := decDispIn;
      dispErrorVar   := '0';
      decode10b12b(
         dataIn    => decDataIn,
         dispIn    => decDispIn,
         dataOut   => decodedDataVar,
         dataKOut  => decodedKVar,
         dispOut   => decodedDispVar,
         codeError => codeErrorVar,
         dispError => dispErrorVar);

      encDataOut  <= encodedDataVar;
      encDispOut  <= encodedDispVar;
      decDataOut  <= decodedDataVar;
      decDataKOut <= decodedKVar;
      decDispOut  <= decodedDispVar;
      codeError   <= codeErrorVar;
      dispError   <= dispErrorVar;
   end process comb;

end architecture rtl;
