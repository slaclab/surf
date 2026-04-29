-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for surf.Pgp4RxEb
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

entity Pgp4RxEbWrapper is
   port (
      phyClk      : in  sl;
      pgpClk      : in  sl;
      rst         : in  sl;
      phyRxValid  : in  sl;
      phyRxData   : in  slv(63 downto 0);
      phyRxHeader : in  slv(1 downto 0);
      pgpRxValid  : out sl;
      pgpRxData   : out slv(63 downto 0);
      pgpRxHeader : out slv(1 downto 0);
      remLinkData : out slv(47 downto 0);
      overflow    : out sl;
      status      : out slv(8 downto 0));
end entity Pgp4RxEbWrapper;

architecture rtl of Pgp4RxEbWrapper is

begin

   U_DUT : entity surf.Pgp4RxEb
      port map (
         phyRxClk    => phyClk,
         phyRxRst    => rst,
         phyRxValid  => phyRxValid,
         phyRxData   => phyRxData,
         phyRxHeader => phyRxHeader,
         pgpRxClk    => pgpClk,
         pgpRxRst    => rst,
         pgpRxValid  => pgpRxValid,
         pgpRxData   => pgpRxData,
         pgpRxHeader => pgpRxHeader,
         remLinkData => remLinkData,
         overflow    => overflow,
         status      => status);

end architecture rtl;
