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

begin

   GEN_VARIABLE : if VARIABLE_G generate
      GEN_OWNER : for i in 0 to 1 generate
         operands(i) <= operandA(128*i+127 downto 128*i);
         resultValue(128*i+127 downto 128*i) <= results(i);
      end generate GEN_OWNER;

      U_Divide : entity surf.PtpVariableDivide
         generic map (
            NUM_CLIENTS_G   => 2,
            DIVISOR_WIDTH_G => 80)
         port map (
            clk          => clk,
            rst          => rst,
            cancel       => cancel,
            inputValid   => inputValid,
            inputReady   => inputReady,
            roundNearest => roundNearest,
            operandA     => operands,
            operandB     => operandB,
            resultValid  => resultValid,
            resultReady  => resultReady,
            resultValue  => results,
            resultError  => resultError);

      resultRemainder <= (others => '0');
   end generate GEN_VARIABLE;

   GEN_SECOND : if not VARIABLE_G generate
      U_Second : entity surf.PtpSecondService
         generic map (
            NUM_CLIENTS_G => 2,
            WIDTH_G       => 128)
         port map (
            clk             => clk,
            rst             => rst,
            cancel          => cancel,
            inputValid      => inputValid,
            inputReady      => inputReady,
            roundNearest    => roundNearest,
            operand         => operandA,
            resultValid     => resultValid,
            resultReady     => resultReady,
            resultValue     => resultValue,
            resultRemainder => resultRemainder);

      resultError <= (others => '0');
   end generate GEN_SECOND;

end architecture mapping;
