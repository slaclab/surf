-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Flattened verification boundary for the two production shared
-- arithmetic services. Both owners, operand capture, response backpressure and
-- cancellation are driven directly by the cocotb scoreboard.
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
use surf.PtpMathPkg.all;

entity PtpArithmeticServiceWrapper is
   generic (
      VARIABLE_G : boolean := true);
   port (
      clk             : in  sl;
      rst             : in  sl;
      cancel          : in  slv(1 downto 0);
      inputValid      : in  slv(1 downto 0);
      inputReady      : out slv(1 downto 0);
      roundNearest    : in  slv(1 downto 0);
      operandA        : in  slv(255 downto 0);
      operandB        : in  slv(159 downto 0);
      resultValid     : out slv(1 downto 0);
      resultReady     : in  slv(1 downto 0);
      resultValue     : out slv(255 downto 0);
      resultRemainder : out slv(255 downto 0);
      resultError     : out slv(1 downto 0));
end entity PtpArithmeticServiceWrapper;

architecture mapping of PtpArithmeticServiceWrapper is

   signal operands : Slv128Array(1 downto 0);
   signal results  : Slv128Array(1 downto 0);

   signal divideRequests : PtpDivideRequestArray(2-1 downto 0)(operandB(80-1 downto 0));
   signal divideResults  : PtpDivideResultArray(2-1 downto 0);
   signal secondRequests : PtpConstDivideRequestArray(2-1 downto 0)(operand(128-1 downto 0));
   signal secondResults  : PtpConstDivideResultArray(2-1 downto 0)(value(128-1 downto 0), remainder(128-1 downto 0));

begin

   GEN_VARIABLE : if VARIABLE_G generate
      GEN_DIVIDE_RECORDS : for i in 0 to 2-1 generate
         divideRequests(i).valid        <= inputValid(i);
         divideRequests(i).roundNearest <= roundNearest(i);
         divideRequests(i).operandA     <= operands(i);
         divideRequests(i).operandB     <= operandB(80*i+80-1 downto 80*i);
         resultValid(i)                 <= divideResults(i).valid;
         results(i)                     <= divideResults(i).value;
         resultError(i)                 <= divideResults(i).error;
      end generate GEN_DIVIDE_RECORDS;
      GEN_OWNER : for i in 0 to 1 generate
         operands(i) <= operandA(128*i+127 downto 128*i);
         resultValue(128*i+127 downto 128*i) <= results(i);
      end generate GEN_OWNER;

      U_Divide : entity surf.PtpVariableDivide
         generic map (
            NUM_CLIENTS_G   => 2,
            DIVISOR_WIDTH_G => 80)
         port map (
            clk         => clk,             -- [in]
            rst         => rst,             -- [in]
            cancel      => cancel,          -- [in]
            requests    => divideRequests,  -- [in]
            inputReady  => inputReady,      -- [out]
            results     => divideResults,   -- [out]
            resultReady => resultReady);    -- [in]

      resultRemainder <= (others => '0');
   end generate GEN_VARIABLE;

   GEN_SECOND : if not VARIABLE_G generate
      GEN_SECOND_RECORDS : for i in 0 to 2-1 generate
         secondRequests(i).valid        <= inputValid(i);
         secondRequests(i).roundNearest <= roundNearest(i);
         secondRequests(i).operand      <= operandA(128*i+128-1 downto 128*i);
         resultValid(i)                 <= secondResults(i).valid;
         resultValue(128*i+128-1 downto 128*i) <= secondResults(i).value;
         resultRemainder(128*i+128-1 downto 128*i) <= secondResults(i).remainder;
      end generate GEN_SECOND_RECORDS;
      U_Second : entity surf.PtpSecondService
         generic map (
            NUM_CLIENTS_G => 2,
            WIDTH_G       => 128)
         port map (
            clk         => clk,             -- [in]
            rst         => rst,             -- [in]
            cancel      => cancel,          -- [in]
            requests    => secondRequests,  -- [in]
            inputReady  => inputReady,      -- [out]
            results     => secondResults,   -- [out]
            resultReady => resultReady);    -- [in]

      resultError <= (others => '0');
   end generate GEN_SECOND;

end architecture mapping;
