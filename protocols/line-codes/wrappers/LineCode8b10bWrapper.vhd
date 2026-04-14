-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for the 8b10b encoder/decoder round-trip
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

entity LineCode8b10bWrapper is
   generic (
      TPD_G       : time     := 1 ns;
      NUM_BYTES_G : positive := 1);
   port (
      clk      : in  sl;
      rst      : in  sl;
      validIn  : in  sl;
      dataIn   : in  slv(NUM_BYTES_G*8-1 downto 0);
      dataKIn  : in  slv(NUM_BYTES_G-1 downto 0);
      validOut : out sl;
      dataOut  : out slv(NUM_BYTES_G*8-1 downto 0);
      dataKOut : out slv(NUM_BYTES_G-1 downto 0);
      codeErr  : out slv(NUM_BYTES_G-1 downto 0);
      dispErr  : out slv(NUM_BYTES_G-1 downto 0));
end entity LineCode8b10bWrapper;

architecture rtl of LineCode8b10bWrapper is

   signal validEncode : sl;
   signal dataEncode  : slv(NUM_BYTES_G*10-1 downto 0);

begin

   ---------------------------------------------------------------------------
   -- Encoder stage
   ---------------------------------------------------------------------------
   U_Encoder : entity surf.Encoder8b10b
      generic map (
         TPD_G          => TPD_G,
         NUM_BYTES_G    => NUM_BYTES_G,
         RST_POLARITY_G => '1',
         RST_ASYNC_G    => false,
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
         dataOut  => dataEncode);

   ---------------------------------------------------------------------------
   -- Decoder stage
   ---------------------------------------------------------------------------
   U_Decoder : entity surf.Decoder8b10b
      generic map (
         TPD_G          => TPD_G,
         NUM_BYTES_G    => NUM_BYTES_G,
         RST_POLARITY_G => '1',
         RST_ASYNC_G    => false)
      port map (
         clk      => clk,
         clkEn    => '1',
         rst      => rst,
         validIn  => validEncode,
         dataIn   => dataEncode,
         validOut => validOut,
         dataOut  => dataOut,
         dataKOut => dataKOut,
         codeErr  => codeErr,
         dispErr  => dispErr);

end architecture rtl;

