-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Private word workspace and descriptor interface for PTP compute.
--
-- Rate/E2E/servo own 64 little-endian words each; PHC owns 16. Full cancellation
-- or system reset invalidates them. Retained cancellation preserves completed
-- slots, invalidating only admitted destinations and pending responses.
-- Four-word aligned signed128 values occupy slots 0..15. A result acknowledgement
-- releases the descriptor, not its stored values. Sources may name earlier
-- destinations; destination may alias a source. Remainder must be distinct.
-- Requests and responses use the endpoint clock. Producers register and hold
-- valid/payload through ready; cancellation excludes all transfers for its owner.
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

package PtpComputePkg is

   constant PTP_COMPUTE_OWNERS_C      : positive := 4;
   constant PTP_COMPUTE_WORDS_C       : positive := 64;
   constant PTP_COMPUTE_OWNER_WORDS_C : IntegerArray(0 to 3) := (64, 64, 64, 16);

   constant PTP_COMPUTE_PERSISTENT_WORDS_C : positive := 208;
   constant PTP_COMPUTE_RATE_C             : natural := 0;
   constant PTP_COMPUTE_E2E_C              : natural := 1;
   constant PTP_COMPUTE_SERVO_C            : natural := 2;
   constant PTP_COMPUTE_PHC_C              : natural := 3;
   constant PTP_COMPUTE_ADD_C              : slv(2 downto 0) := "000";
   constant PTP_COMPUTE_SUB_C              : slv(2 downto 0) := "001";
   constant PTP_COMPUTE_MUL_C              : slv(2 downto 0) := "010";
   constant PTP_COMPUTE_DIV_C              : slv(2 downto 0) := "011";
   constant PTP_COMPUTE_COPY_C             : slv(2 downto 0) := "100";
   constant PTP_COMPUTE_SHL_C              : slv(2 downto 0) := "101";
   constant PTP_COMPUTE_SHR_C              : slv(2 downto 0) := "110";
   constant PTP_COMPUTE_CMP_C              : slv(2 downto 0) := "111";

   type PtpComputeJobType is record
      operation : slv(2 downto 0);
      sourceA   : slv(3 downto 0);
      sourceB   : slv(3 downto 0);
      target    : slv(3 downto 0);
      remainder : slv(3 downto 0);
      shift     : slv(6 downto 0);
      rounding  : sl;
      tag       : slv(31 downto 0);
   end record;

   constant PTP_COMPUTE_JOB_INIT_C : PtpComputeJobType := (
      operation => PTP_COMPUTE_ADD_C,
      sourceA   => x"0",
      sourceB   => x"1",
      target    => x"2",
      remainder => x"3",
      shift     => (others => '0'),
      rounding  => '0',
      tag       => (others => '0'));

   type PtpComputeMasterType is record
      cancel      : sl;
      retain      : sl;
      memValid    : sl;
      memWrite    : sl;
      memWord     : slv(5 downto 0);
      memData     : slv(31 downto 0);
      readReady   : sl;
      jobValid    : sl;
      job         : PtpComputeJobType;
      resultReady : sl;
   end record;

   constant PTP_COMPUTE_MASTER_INIT_C : PtpComputeMasterType := (
      cancel      => '0',
      retain      => '0',
      memValid    => '0',
      memWrite    => '0',
      memWord     => (others => '0'),
      memData     => (others => '0'),
      readReady   => '0',
      jobValid    => '0',
      job         => PTP_COMPUTE_JOB_INIT_C,
      resultReady => '0');

   type PtpComputeSlaveType is record
      memReady    : sl;
      readValid   : sl;
      readWord    : slv(5 downto 0);
      readData    : slv(31 downto 0);
      jobReady    : sl;
      resultValid : sl;
      resultError : sl;
      resultLess  : sl;
      resultEqual : sl;
      resultTag   : slv(31 downto 0);
   end record;

   constant PTP_COMPUTE_SLAVE_INIT_C : PtpComputeSlaveType := (
      memReady    => '0',
      readValid   => '0',
      readWord    => (others => '0'),
      readData    => (others => '0'),
      jobReady    => '0',
      resultValid => '0',
      resultError => '0',
      resultLess  => '0',
      resultEqual => '0',
      resultTag   => (others => '0'));

   type PtpComputeMasterArray is array (natural range <>) of PtpComputeMasterType;
   type PtpComputeSlaveArray is array (natural range <>) of PtpComputeSlaveType;
   type PtpComputeJobArray is array (natural range <>) of PtpComputeJobType;

   function ptpComputeJob (
      operation : slv(2 downto 0);
      sourceA   : natural;
      sourceB   : natural;
      target    : natural;
      remainder : natural;
      shift     : natural := 0;
      rounding  : sl := '0') return PtpComputeJobType;

end package PtpComputePkg;

package body PtpComputePkg is

   function ptpComputeJob (
      operation    : slv(2 downto 0);
      sourceA      : natural;
      sourceB      : natural;
      target       : natural;
      remainder    : natural;
      shift        : natural := 0;
      rounding     : sl := '0') return PtpComputeJobType is
      variable ret : PtpComputeJobType := PTP_COMPUTE_JOB_INIT_C;
   begin
      ret.operation := operation;
      ret.sourceA   := toSlv(sourceA, 4);
      ret.sourceB   := toSlv(sourceB, 4);
      ret.target    := toSlv(target, 4);
      ret.remainder := toSlv(remainder, 4);
      ret.shift     := toSlv(shift, 7);
      ret.rounding  := rounding;
      return ret;
   end function ptpComputeJob;

end package body PtpComputePkg;
