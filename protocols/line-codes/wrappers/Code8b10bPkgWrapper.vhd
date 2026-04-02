-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing package wrapper for direct 8b10b encode/decode
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
use surf.Code8b10bPkg.all;

entity Code8b10bPkgWrapper is
   port (
      encDispIn   : in  sl;
      encDataIn   : in  slv(7 downto 0);
      encDataKIn  : in  sl;
      encDataOut  : out slv(9 downto 0);
      encDispOut  : out sl;
      decDispIn   : in  sl;
      decDataIn   : in  slv(9 downto 0);
      decDataOut  : out slv(7 downto 0);
      decDataKOut : out sl;
      decDispOut  : out sl;
      invalidK    : out sl;
      codeError   : out sl;
      dispError   : out sl);
end entity Code8b10bPkgWrapper;

architecture rtl of Code8b10bPkgWrapper is

begin

   ---------------------------------------------------------------------------
   -- Package-level encode/decode shim
   ---------------------------------------------------------------------------
   comb : process (encDispIn, encDataIn, encDataKIn, decDispIn, decDataIn) is
      variable encodedDataVar : slv(9 downto 0);
      variable encodedDispVar : sl;
      variable decodedDataVar : slv(7 downto 0);
      variable decodedKVar    : sl;
      variable decodedDispVar : sl;
      variable codeErrorVar   : sl;
      variable dispErrorVar   : sl;
   begin
      encodedDataVar := (others => '0');
      encodedDispVar := encDispIn;
      encode8b10b(
         dataIn  => encDataIn,
         dataKIn => encDataKIn,
         dispIn  => encDispIn,
         dataOut => encodedDataVar,
         dispOut => encodedDispVar);

      decodedDataVar := (others => '0');
      decodedKVar    := '0';
      decodedDispVar := decDispIn;
      codeErrorVar   := '0';
      dispErrorVar   := '0';
      decode8b10b(
         dataIn   => decDataIn,
         dispIn   => decDispIn,
         dataOut  => decodedDataVar,
         dataKOut => decodedKVar,
         dispOut  => decodedDispVar,
         codeErr  => codeErrorVar,
         dispErr  => dispErrorVar);

      encDataOut  <= encodedDataVar;
      encDispOut  <= encodedDispVar;
      decDataOut  <= decodedDataVar;
      decDataKOut <= decodedKVar;
      decDispOut  <= decodedDispVar;
      invalidK    <= '0';
      codeError   <= codeErrorVar;
      dispError   <= dispErrorVar;
   end process comb;

end architecture rtl;
