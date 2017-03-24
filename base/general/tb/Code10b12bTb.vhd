-------------------------------------------------------------------------------
-- File       : Encoder10b12bTb.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-10-11
-- Last update: 2016-10-26
-------------------------------------------------------------------------------
-- Description: Testbench for design "Encoder10b12b"
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

use work.StdRtlPkg.all;
use work.Code10b12bPkg.all;
use work.TextUtilPkg.all;


----------------------------------------------------------------------------------------------------

entity Code10b12bTb is

end entity Code10b12bTb;

----------------------------------------------------------------------------------------------------

architecture sim of Code10b12bTb is

   -- component generics
   constant TPD_G          : time    := 1 ns;
   constant RST_POLARITY_G : sl      := '1';
   constant RST_ASYNC_G    : boolean := false;

   -- component ports
--    signal clk        : sl;                                     -- [in]
--    signal clkEn      : sl              := '1';                 -- [in]
--    signal rst        : sl              := not RST_POLARITY_G;  -- [in]
--    signal encDispIn  : sl              := '0';
--    signal encDataIn  : slv(9 downto 0) := (others => '0');  -- [in]
--    signal encDataKIn : sl              := '0';              -- [in]
--    signal encDataOut : slv(11 downto 0);                    -- [out]
--    signal encDispOut : sl;

--    signal started         : boolean := false;
--    shared variable runVar : integer := 0;
--    signal run             : integer := 0;
--    signal lastEncDataOut  : slv(11 downto 0);

--    signal encDispInInt    : DisparityType;
--    signal encDispOutInt   : DisparityType;
   signal encDataInString : string(1 to 8);

--   signal startSet : sl := '0';

   -------------------------------------------------------------------------------------------------

--    signal decDataIn    : slv(11 downto 0);  -- [in]
--    signal decDispIn    : sl;                -- [in]
--    signal decDataOut   : slv(9 downto 0);   -- [out]
--    signal decDataKOut  : sl;                -- [out]
--    signal decDispOut   : sl;                -- [out]
--    signal decCodeError : sl;                -- [out]
--    signal decDispError : sl;                -- [out]



begin

--    encDispInInt  <= conv(encDispIn);
--    encDispOutInt <= conv(encDispOut);



   main : process is
      variable encDispIn    : sl              := '0';
      variable encDataIn    : slv(9 downto 0) := (others => '0');  -- [in]
      variable encDataKIn   : sl              := '0';              -- [in]
      variable encDataOut   : slv(11 downto 0);                    -- [out]
      variable encDispOut   : sl;
      variable decDataIn    : slv(11 downto 0);                    -- [in]
      variable decDispIn    : sl;                                  -- [in]
      variable decDataOut   : slv(9 downto 0);                     -- [out]
      variable decDataKOut  : sl;                                  -- [out]
      variable decDispOut   : sl;                                  -- [out]
      variable decCodeError : sl;                                  -- [out]
      variable decDispError : sl;                                  -- [out]
   begin
      wait for 1 us;

      for i in 0 to 2**10-1 loop
         encDataIn       := conv_std_logic_vector(i, 10);
         encDispIn       := '0';
         encode10b12b(encDataIn, encDataKIn, encDispIn, encDataout, encDispOut);
         decode10b12b(encDataOut, encDispIn, decDataOut, decDataKOut, decDispOut, decCodeError, decDispError);
         assert (encDataIn = decDataOut) report "encDataIn /= decDataOut" severity failure;
         assert (encDataKIn = decDataKOut) report "encDataKIn /= decDataKOut" severity failure;
         assert (decCodeError = '0') report "decCodeError" severity failure;
         assert (decDispError = '0') report "decDispError" severity failure;
         print("0 " & toString(encDataIn, encDataKIn) & " 0");
         wait for 1 ns;

         encDispIn := '1';
         encode10b12b(encDataIn, encDataKIn, encDispIn, encDataout, encDispOut);
         decode10b12b(encDataOut, encDispIn, decDataOut, decDataKOut, decDispOut, decCodeError, decDispError);
         assert (encDataIn = decDataOut) report "encDataIn /= decDataOut" severity failure;
         assert (encDataKIn = decDataKOut) report "encDataKIn /= decDataKOut" severity failure;
         assert (decCodeError = '0') report "decCodeError" severity failure;
         assert (decDispError = '0') report "decDispError" severity failure;
         print("1 " & toString(encDataIn, encDataKIn) & " 1");
         wait for 1 ns;

      end loop;

      wait for 1 ns;

      for i in 0 to 31 loop
         encDataIn       := conv_std_logic_vector(i, 5) & conv_std_logic_vector(28, 5);
         encDataKIn      := '1';
         encDispIn       := '0';
         encode10b12b(encDataIn, encDataKIn, encDispIn, encDataout, encDispOut);
         decode10b12b(encDataOut, encDispIn, decDataOut, decDataKOut, decDispOut, decCodeError, decDispError);
         assert (encDataIn = decDataOut) report "encDataIn /= decDataOut" severity failure;
         assert (encDataKIn = decDataKOut) report "encDataKIn /= decDataKOut" severity failure;
         assert (decCodeError = '0') report "decCodeError" severity failure;
         assert (decDispError = '0') report "decDispError" severity failure;
         print("0 " & toString(encDataIn, encDataKIn) & " 0");
         wait for 1 ns;

         encDispIn := '1';
         encode10b12b(encDataIn, encDataKIn, encDispIn, encDataout, encDispOut);
         decode10b12b(encDataOut, encDispIn, decDataOut, decDataKOut, decDispOut, decCodeError, decDispError);
         assert (encDataIn = decDataOut) report "encDataIn /= decDataOut" severity failure;
         assert (encDataKIn = decDataKOut) report "encDataKIn /= decDataKOut" severity failure;
         assert (decCodeError = '0') report "decCodeError" severity failure;
         assert (decDispError = '0') report "decDispError" severity failure;
         print("1 " & toString(encDataIn, encDataKIn) & " 1");
         wait for 1 ns;

      end loop;

      wait;

   end process;



end architecture sim;

----------------------------------------------------------------------------------------------------
