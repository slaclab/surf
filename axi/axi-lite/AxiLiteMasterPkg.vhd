-------------------------------------------------------------------------------
-- File       : AxiLiteMasterPkg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-03-08
-- Last update: 2016-03-09
-------------------------------------------------------------------------------
-- Description: AxiLiteMaster Support Package
-------------------------------------------------------------------------------
-- This file is part of SLAC Firmware Standard Library. It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of SLAC Firmware Standard Library, including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;

package AxiLiteMasterPkg is

   type AxiLiteMasterReqType is record
      request   : sl;
      rnw     : sl;
      address : slv(31 downto 0);
      wrData  : slv(31 downto 0);
   end record AxiLiteMasterReqType;

   constant AXI_LITE_MASTER_REQ_INIT_C : AxiLiteMasterReqType := (
      request   => '0',
      rnw     => '1',
      address => (others => '0'),
      wrData  => (others => '0'));

   type AxiLiteMasterAckType is record
      done  : sl;
      resp   : slv(1 downto 0);
      rdData : slv(31 downto 0);
   end record AxiLiteMasterAckType;

   constant AXI_LITE_MASTER_ACK_INIT_C : AxiLiteMasterAckType := (
      done  => '0',
      resp   => (others => '0'),
      rdData => (others => '0'));


end package AxiLiteMasterPkg;

