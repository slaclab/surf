-------------------------------------------------------------------------------
-- File       : SemPkg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-02-08
-- Last update: 2017-02-08
-------------------------------------------------------------------------------
-- Description: 7-series SEM module Package File
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

use work.StdRtlPkg.all;

package SemPkg is

   type SemObType is record
      heartbeat      : sl;
      initialization : sl;
      observation    : sl;
      correction     : sl;
      classification : sl;
      injection      : sl;
      essential      : sl;
      uncorrectable  : sl;
      txData         : slv(7 downto 0);
      txWrite        : sl;
      rxRead         : sl;
      iprogIcapReq   : sl;
   end record;

   type SemIbType is record
      injectStrobe   : sl;
      injectAddress  : slv(39 downto 0);
      txFull         : sl;
      rxData         : slv(7 downto 0);
      rxEmpty        : sl;
      iprogIcapGrant : sl;
   end record;

   constant SEM_IB_INIT_C : SemIbType := (
      injectStrobe   => '0',
      injectAddress  => (others => '0'),
      txFull         => '1',            -- Init with backpreassure
      rxData         => (others => '0'),
      rxEmpty        => '0',            -- Init with backpreassure
      iprogIcapGrant => '0');  -- '0' = SEM access ICAP, '1' = IPROG access ICAP

end package;
