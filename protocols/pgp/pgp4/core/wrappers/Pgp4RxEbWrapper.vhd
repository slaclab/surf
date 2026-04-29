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
   generic (
      SKIP_EN_G       : boolean := true;
      CHECK_K_CODE_G  : boolean := false);
   port (
      phyClk         : in  sl;
      pgpClk         : in  sl;
      rst            : in  sl;
      phyRxValid     : in  sl;
      phyRxData      : in  slv(63 downto 0);
      phyRxHeader    : in  slv(1 downto 0);
      phyRxLinkError : in  sl := '0';
      pgpRxValid     : out sl;
      pgpRxData      : out slv(63 downto 0);
      pgpRxHeader    : out slv(1 downto 0);
      remLinkData    : out slv(47 downto 0);
      overflow       : out sl;
      linkError      : out sl;
      status         : out slv(8 downto 0));
end entity Pgp4RxEbWrapper;

architecture rtl of Pgp4RxEbWrapper is

   signal checkedValid  : sl;
   signal checkedData   : slv(63 downto 0);
   signal checkedHeader : slv(1 downto 0);
   signal checkedError  : sl;

begin

   GEN_CHECK_K_CODE : if (CHECK_K_CODE_G = true) generate
      U_Checker : entity surf.Pgp4RxKCodeChecker
         port map (
            phyRxClk      => phyClk,
            phyRxRst      => rst,
            phyRxValid    => phyRxValid,
            phyRxData     => phyRxData,
            phyRxHeader   => phyRxHeader,
            checkedValid  => checkedValid,
            checkedData   => checkedData,
            checkedHeader => checkedHeader,
            linkError     => checkedError);
   end generate GEN_CHECK_K_CODE;

   GEN_NO_CHECK_K_CODE : if (CHECK_K_CODE_G = false) generate
      checkedValid  <= phyRxValid;
      checkedData   <= phyRxData;
      checkedHeader <= phyRxHeader;
      checkedError  <= phyRxLinkError;
   end generate GEN_NO_CHECK_K_CODE;

   U_DUT : entity surf.Pgp4RxEb
      generic map (
         SKIP_EN_G => SKIP_EN_G)
      port map (
         phyRxClk       => phyClk,
         phyRxRst       => rst,
         phyRxValid     => checkedValid,
         phyRxData      => checkedData,
         phyRxHeader    => checkedHeader,
         phyRxLinkError => checkedError,
         pgpRxClk       => pgpClk,
         pgpRxRst       => rst,
         pgpRxValid     => pgpRxValid,
         pgpRxData      => pgpRxData,
         pgpRxHeader    => pgpRxHeader,
         remLinkData    => remLinkData,
         overflow       => overflow,
         linkError      => linkError,
         status         => status);

end architecture rtl;
