-------------------------------------------------------------------------------
-- File       : Encoder12b14bTb.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-10-11
-- Last update: 2016-10-11
-------------------------------------------------------------------------------
-- Description: Testbench for design "Encoder12b14b"
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
use work.Code12b14bPkg.all;
use work.TextUtilPkg.all;


----------------------------------------------------------------------------------------------------

entity Encoder12b14bTb is

end entity Encoder12b14bTb;

----------------------------------------------------------------------------------------------------

architecture sim of Encoder12b14bTb is

   -- component generics
   constant TPD_G          : time     := 1 ns;
   constant RST_POLARITY_G : sl       := '1';
   constant RST_ASYNC_G    : boolean  := false;

   -- component ports
   signal clk      : sl;                        -- [in]
   signal clkEn    : sl := '1';                 -- [in]
   signal rst      : sl := not RST_POLARITY_G;  -- [in]
   signal dispIn   : slv(1 downto 0);
   signal dataIn   : slv(11 downto 0);          -- [in]
   signal dataKIn  : sl := '0';                 -- [in]
   signal dataOut  : slv(13 downto 0);          -- [out]
   signal dispOut  : slv(1 downto 0);
   signal invalidK : sl;                        -- [out]

   signal started         : boolean := false;
   shared variable runVar : integer := 0;
   signal run             : integer := 0;
   signal lastDataOut     : slv(13 downto 0);

   signal dispInInt : DisparityOutType;
   signal dispOutInt : DisparityOutType;

begin

   dispInInt <= toDisparityOutType(dispIn);
   dispOutInt <= toDisparityOutType(dispOut);

   -- component instantiation
   U_Encoder12b14b : entity work.Encoder12b14b
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         DEBUG_DISP_G => true)
      port map (
         clk      => clk,               -- [in]
         clkEn    => clkEn,             -- [in]
         rst      => rst,               -- [in]
         dataIn   => dataIn,            -- [in]
         dispIn   => dispIn,
         dataKIn  => dataKIn,           -- [in]
         dataOut  => dataOut,           -- [out]
         dispOut  => dispOut,
         invalidK => invalidK);         -- [out]


   U_ClkRst_1 : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => 10 ns,
         CLK_DELAY_G       => 1 ns,
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 5 us,
         SYNC_RESET_G      => true)
      port map (
         clkP => clk,
         rst  => rst);



   main : process is
      variable a : slv(11 downto 0);
      variable b : slv(11 downto 0);
      
      procedure doComb (
         a  : in slv(11 downto 0);
         ak : in sl;
         b  : in slv(11 downto 0);
         bk : in sl)
      is
         variable disparity : DisparityOutType;
      begin
         disparity        := -2;
         while (disparity <= 4) loop
            wait until clk = '0';
            dispIn  <= toSlv(disparity);
            dataIn  <= a;
            dataKIn <= ak;
            wait until clk = '1';
            started <= true;
            runVar  := 0;
            wait until clk = '0';
            dispIn  <= dispOut;
            dataIn  <= b;
            dataKIn <= bk;
            wait until clk = '1';

            disparity := disparity + 2;
         end loop;

      end procedure doComb;

      impure function isKCode (
         d : slv(11 downto 0))
         return boolean is
      begin
         for i in K_CODE_TABLE_C'range loop
            if (K_CODE_TABLE_C(i).k12 = d and
                d /= K_120_3_C and
                d /= K_120_11_C and
                d /= K_120_19_C) then
--               print("Sending K Code: " & str(K_CODE_TABLE_C(i).k12));
               return true;
            end if;
         end loop;
         return false;
      end function isKCode;
   begin

      wait until clk = '1';
      wait until clk = '1';
      wait until rst = '0';
      wait until clk = '1';

      for i in 3000 to 2**12-1 loop
         print("i: " & str(i));
         for j in 0 to 2**12-1 loop
            a := conv_std_logic_vector(i, 12);
            b := conv_std_logic_vector(j, 12);

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
   begin
      wait until clk = '0';
      if (started) then
         for i in 0 to 13 loop
            if (runVar = 0) then
               if (dataOut(i) = '1') then
                  runVar := runVar + 1;
               else
                  runVar := runVar - 1;
               end if;
            elsif (runVar > 0) then
               if (dataOut(i) = '1') then
                  runVar := runVar + 1;
               else
                  runVar := -1;
               end if;
            elsif (runVar < 0) then
               if (dataOut(i) = '0') then
                  runVar := runVar - 1;
               else
                  runVar := 1;
               end if;
            end if;

            assert (runVar < 7 and runVar > -7) report "Run length violation: "&
               "dataOut: " & str(dataOut) & " runVar: " & str(runVar) & " lastDataOut: " & str(lastDataOut)
               severity failure;

         end loop;
         lastDataOut <= dataOut;
      end if;

      run <= runVar;

   end process monitor;




end architecture sim;

----------------------------------------------------------------------------------------------------
