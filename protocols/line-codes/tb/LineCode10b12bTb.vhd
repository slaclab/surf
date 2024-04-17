-------------------------------------------------------------------------------
-- Title      : Line Code 10B12B: https://confluence.slac.stanford.edu/x/QndODQ
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: 10B12B Line Code Test bed for cocoTB
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

entity LineCode10b12bTb is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Clock and Reset
      clk      : in  sl;
      rst      : in  sl;
      -- Encoder Interface
      validIn  : in  sl;
      dataIn   : in  slv(9 downto 0);
      dataKIn  : in  sl;
      -- Decoder Interface
      validOut : out sl;
      dataOut  : out slv(9 downto 0);
      dataKOut : out sl;
      codeErr  : out sl;
      dispErr  : out sl);
end entity LineCode10b12bTb;

architecture mapping of LineCode10b12bTb is

   signal validEncode : sl;
   signal dataEncode  : slv(11 downto 0);

begin

   U_Encoder : entity surf.Encoder10b12b
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => '1',
         RST_ASYNC_G    => false,
         USE_CLK_EN_G   => false,
         FLOW_CTRL_EN_G => true)
      port map (
         clk      => clk,
         clkEn    => '1',
         rst      => rst,
         validIn  => validIn,
         readyIn  => open,
         dataIn   => dataIn,
         dataKIn  => dataKIn,
         validOut => validEncode,
         readyOut => validEncode,
         dataOut  => dataEncode,
         dispOut  => open);

   U_Decoder : entity surf.Decoder10b12b
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => '1',
         RST_ASYNC_G    => false,
         USE_CLK_EN_G   => false)
      port map (
         clk       => clk,
         clkEn     => '1',
         rst       => rst,
         validIn   => validEncode,
         dataIn    => dataEncode,
         validOut  => validOut,
         dataOut   => dataOut,
         dataKOut  => dataKOut,
         codeError => codeErr,
         dispError => dispErr);

end mapping;
