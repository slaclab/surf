-------------------------------------------------------------------------------
-- Title      : Line Code 12B14B: https://confluence.slac.stanford.edu/x/6AJODQ
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: 12B14B Line Code Test bed for cocoTB
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

entity LineCode12b14bTb is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Clock and Reset
      clk      : in  sl;
      rst      : in  sl;
      -- Encoder Interface
      validIn  : in  sl;
      dataIn   : in  slv(11 downto 0);
      dataKIn  : in  sl;
      -- Decoder Interface
      validOut : out sl;
      dataOut  : out slv(11 downto 0);
      dataKOut : out sl;
      codeErr  : out sl;
      dispErr  : out sl);
end entity LineCode12b14bTb;

architecture mapping of LineCode12b14bTb is

   signal validEncode : sl;
   signal dataEncode  : slv(13 downto 0);

begin

   U_Encoder : entity surf.Encoder12b14b
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => '1',
         RST_ASYNC_G    => false,
         DEBUG_DISP_G   => false,
         FLOW_CTRL_EN_G => true)
      port map (
         clk      => clk,
         clkEn    => '1',
         rst      => rst,
         validIn  => validIn,
         readyIn  => open,
         dataIn   => dataIn,
         dispIn   => "00",              -- Used if DEBUG_DISP_G=true
         dataKIn  => dataKIn,
         validOut => validEncode,
         readyOut => validEncode,
         dataOut  => dataEncode,
         dispOut  => open);

   U_Decoder : entity surf.Decoder12b14b
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => '1',
         RST_ASYNC_G    => false,
         DEBUG_DISP_G   => false)
      port map (
         clk       => clk,
         clkEn     => '1',
         rst       => rst,
         validIn   => validEncode,
         dataIn    => dataEncode,
         dispIn    => "00",             -- Used if DEBUG_DISP_G=true
         validOut  => validOut,
         dataOut   => dataOut,
         dataKOut  => dataKOut,
         codeError => codeErr,
         dispError => dispErr,
         dispOut   => open);

end mapping;
