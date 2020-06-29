-------------------------------------------------------------------------------
-- Title      : RSSI Protocol: https://confluence.slac.stanford.edu/x/1IyfD
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: RSSI Package File
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiPkg.all;

package AxiRssiPkg is

   --! Default RSSI AXI configuration
   constant RSSI_AXI_CONFIG_C : AxiConfigType := (
      ADDR_WIDTH_C => 13,               -- 2^13 = 8kB buffer
      DATA_BYTES_C => 8,                -- 8 bytes = 64-bits
      ID_BITS_C    => 2,
      LEN_BITS_C   => 7);               -- Up to 1kB bursting

   procedure GetRssiCsum (              -- 2 clock cycle latency calculation
      -- Input
      init     : in    sl;
      header   : in    slv(63 downto 0);
      accumReg : in    slv(20 downto 0);
      -- Results
      accumVar : inout slv(20 downto 0);
      chksumOk : inout sl;
      checksum : inout slv(15 downto 0));

end AxiRssiPkg;


package body AxiRssiPkg is

   procedure GetRssiCsum (
      -- Input
      init     : in    sl;
      header   : in    slv(63 downto 0);
      accumReg : in    slv(20 downto 0);
      -- Results
      accumVar : inout slv(20 downto 0);
      chksumOk : inout sl;
      checksum : inout slv(15 downto 0)) is
      variable hdrSum : slv(20 downto 0);
      variable summ0  : slv(16 downto 0);
      variable summ1  : slv(15 downto 0);
   begin

      -- Summation of the header
      hdrSum := resize(header(63 downto 48), 21) +
                resize(header(47 downto 32), 21) +
                resize(header(31 downto 16), 21) +
                resize(header(15 downto 0), 21);

      -- Check for initializing
      if (init = '1') then
         accumVar := hdrSum;
      else
         -- Add new word sum
         accumVar := hdrSum + accumReg;
      end if;

      -- Add the sum carry bits
      summ0 := resize(accumReg(15 downto 0), 17) + resize(accumReg(20 downto 16), 17);
      summ1 := summ0(15 downto 0) + resize(summ0(16 downto 16), 16);

      -- Checksum's Ones complement output (only used in TX FSM)
      checksum := not(summ1);

      -- Output the checksum status (only used in RX FSM)
      if (checksum = 0) then
         chksumOk := '1';
      else
         chksumOk := '0';
      end if;

   end procedure;

end package body AxiRssiPkg;
