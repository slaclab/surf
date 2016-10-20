-------------------------------------------------------------------------------
-- Title      : Testbench for design "Encoder10b12b"
-------------------------------------------------------------------------------
-- File       : Encoder10b12bTb.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-10-11
-- Last update: 2016-10-20
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of <PROJECT_NAME>. It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of <PROJECT_NAME>, including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
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
   signal clk        : sl;                                     -- [in]
   signal clkEn      : sl              := '1';                 -- [in]
   signal rst        : sl              := not RST_POLARITY_G;  -- [in]
   signal encDispIn  : sl              := '0';
   signal encDataIn  : slv(9 downto 0) := (others => '0');     -- [in]
   signal encDataKIn : sl              := '0';                 -- [in]
   signal encDataOut : slv(11 downto 0);                       -- [out]
   signal encDispOut : sl;

   signal started         : boolean := false;
   shared variable runVar : integer := 0;
   signal run             : integer := 0;
   signal lastEncDataOut  : slv(11 downto 0);

   signal encDispInInt    : DisparityType;
   signal encDispOutInt   : DisparityType;
   signal encDataInString : string(1 to 8);

--   signal startSet : sl := '0';

   -------------------------------------------------------------------------------------------------

   signal decDataIn    : slv(11 downto 0);  -- [in]
   signal decDispIn    : sl;                -- [in]
   signal decDataOut   : slv(9 downto 0);   -- [out]
   signal decDataKOut  : sl;                -- [out]
   signal decDispOut   : sl;                -- [out]
   signal decCodeError : sl;                -- [out]
   signal decDispError : sl;                -- [out]



begin

   encDispInInt  <= conv(encDispIn);
   encDispOutInt <= conv(encDispOut);

   encDataInString <= toString(encDataIn, encDataKIn);

   -- component instantiation
   U_Encoder10b12b : entity work.Encoder10b12b
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         DEBUG_DISP_G   => false)
      port map (
         clk     => clk,                -- [in]
         clkEn   => clkEn,              -- [in]
         rst     => rst,                -- [in]
         dataIn  => encDataIn,          -- [in]
         dispIn  => encDispIn,
         dataKIn => encDataKIn,         -- [in]
         dataOut => encDataOut,         -- [out]
         dispOut => encDispOut);


   U_ClkRst_1 : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => 4 ns,
         CLK_DELAY_G       => 1 ns,
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 5 us,
         SYNC_RESET_G      => true)
      port map (
         clkP => clk,
         rst  => rst);


   main : process is
      variable a : slv(9 downto 0);
      variable b : slv(9 downto 0);

      procedure doComb (
         a  : in slv(9 downto 0);
         ak : in sl;
         b  : in slv(9 downto 0);
         bk : in sl)
      is
      begin

         wait until clk = '0';
         encDispIn  <= '0';
         encDataIn  <= a;
         encDataKIn <= ak;
         decDispIn  <= decDispOut;
         wait until clk = '1';
         started    <= true;
         wait until clk = '0';
         encDispIn  <= encDispOut;
         encDataIn  <= b;
         encDataKIn <= bk;
         decDispIn  <= '0';
         wait until clk = '1';

         wait until clk = '0';
         encDispIn  <= '1';
         encDataIn  <= a;
         encDataKIn <= ak;
         decDispIn  <= decDispOut;
         wait until clk = '1';
         started    <= true;
         wait until clk = '0';
         encDispIn  <= encDispOut;
         encDataIn  <= b;
         encDataKIn <= bk;
         decDispIn  <= '1';
         wait until clk = '1';

      end procedure doComb;

      impure function isKCode (
         d : slv(9 downto 0))
         return boolean is
      begin
         if ((d(4 downto 0) = "11100") and
             (d(9 downto 5) /= "11100")) then
--             ((CODE_TABLE_C(conv_integer(d(9 downto 5))).outDisp = 0))) then
            return true;
         else
            return false;
         end if;
      end function isKCode;

   begin

      wait until clk = '1';
      wait until clk = '1';
      wait until rst = '0';
      wait until clk = '1';

      encDataIn  <= "0001111100";
      encDataKIn <= '1';

      wait for 1 us;
      wait until clk = '1';

      for i in 0 to 2**10-1 loop
         print("i: " & toString(conv_std_logic_vector(i, 10), '0'));
         for j in 0 to 2**10-1 loop
            a := conv_std_logic_vector(i, 10);
            b := conv_std_logic_vector(j, 10);

            doComb(a, '0', b, '0');

            if (isKCode(a)) then
               doComb(a, '1', b, '0');
            end if;

            if (isKCode(b)) then
               doComb(a, '0', b, '1');
            end if;

            if (isKCode(a) and isKCode(b)) then
               doComb(a, '1', b, '1');
            end if;

         end loop;

      end loop;

   end process;



   monitor : process is
      variable word : slv(23 downto 0);
   begin
      wait until clk = '0';
      if (started) then

         lastEncDataOut <= encDataOut;

         wait until clk = '0';

         word := encDataOut & lastEncDataOut;
--         print(str(word(23 downto 12)) & " " & str(word(11 downto 0)));
         for i in 1 to 11 loop
            if ((word(i+11 downto i) = "100011111100") or
                (word(i+11 downto i) = not("100011111100")) or
                (word(i+11 downto i) = "001011111100") or
                (word(i+11 downto i) = not("001011111100")) or
                (word(i+11 downto i) = "010011111100") or
                (word(i+11 downto i) = not("010011111100"))) then
               report "Run length violation: "&
                  str(encDataOut) &
                  " " & str(lastEncDataOut)
                  severity failure;
            end if;
         end loop;
         lastEncDataOut <= encDataOut;


     
      end if;

   end process monitor;
   
   assert (decDispError = '0' or not started) report "Disparity Error" severity failure;
   assert (decCodeError = '0' or not started) report "Code Error" severity failure;

   -------------------------------------------------------------------------------------------------
   -- Decoder
   -------------------------------------------------------------------------------------------------
   decDataIn <= encDataOut;
   U_Decoder10b12b_1 : entity work.Decoder10b12b
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         DEBUG_DISP_G   => false)
      port map (
         clk       => clk,              -- [in]
         clkEn     => clkEn,            -- [in]
         rst       => rst,              -- [in]
         dataIn    => decDataIn,        -- [in]
         dispIn    => decDispIn,        -- [in]
         dataOut   => decDataOut,       -- [out]
         dataKOut  => decDataKOut,      -- [out]
         dispOut   => decDispOut,       -- [out]
         codeError => decCodeError,     -- [out]
         dispError => decDispError);    -- [out]

end architecture sim;

----------------------------------------------------------------------------------------------------
