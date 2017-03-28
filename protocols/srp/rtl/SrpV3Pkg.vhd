-------------------------------------------------------------------------------
-- File       : SrpV3Pkg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-04-19
-- Last update: 2016-05-04
-------------------------------------------------------------------------------
-- Description: SRPv3 Package File
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
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

package SrpV3Pkg is

--    constant SRP_AXIS_CONFIG_C : AxiStreamConfigType := (
--       TSTRB_EN_C    => false,
--       TDATA_BYTES_C => 4,
--       TDEST_BITS_C  => 0,
--       TID_BITS_C    => 0,
--       TKEEP_MODE_C  => TKEEP_NORMAL_C,
--       TUSER_BITS_C  => 2,              
--       TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   constant SRP_VERSION_C : slv(7 downto 0) := x"03";

   -- opcodes
   constant SRP_READ_C         : slv(1 downto 0) := "00";
   constant SRP_WRITE_C        : slv(1 downto 0) := "01";
   constant SRP_POSTED_WRITE_C : slv(1 downto 0) := "10";
   constant SRP_NULL_C         : slv(1 downto 0) := "11";

   type SrpV3ReqType is record
      request : sl;
      remVer  : slv(7 downto 0);
      opCode  : slv(1 downto 0);
      spare   : slv(13 downto 0);
      tid     : slv(31 downto 0);
      addr    : slv(63 downto 0);
      reqSize : slv(31 downto 0);
   end record;

   constant SRPV3_REQ_INIT_C : SrpV3ReqType := (
      request => '0',
      remVer  => (others => '0'),
      opCode  => (others => '0'),
      spare   => (others => '0'),
      tid     => (others => '0'),
      addr    => (others => '0'),
      reqSize => (others => '0'));

   type SrpV3AckType is record
      done     : sl;
      respCode : slv(7 downto 0);
   end record;

   constant SRPV3_ACK_INIT_C : SrpV3AckType := (
      done     => '0',
      respCode => (others => '0'));


end package SrpV3Pkg;

package body SrpV3Pkg is

--    function srpHeader (
--       opcode  : in slv(1 downto 0);
--       addr    : in slv;
--       reqSize : in natural          := 0;
--       txnId   : in slv(31 downto 0) := (others => '0');
--       timeout : in slv(7 downto 0)  := (others => '0'))
--       return Slv32Array
--    is
--       variable header : slv32Array(0 to 4);
--    begin
--       header(0)(7 downto 0)   := X"03";            -- Version
--       header(0)(9 downto 8)   := opcode;           -- Opcode
--       header(0)(23 downto 10) := (others => '0');  -- Reserved
--       header(0)(31 downto 24) := timeout;          -- TimeoutCnt
--       header(1)(31 downto 0)  := txnId;            --TID
--       header(2)               := resize(addr, 32);
--       header(3)               := resize(addr(addr'high downto 32), 32);
--       header(4)               := toSlv(reqSize, 32);
--       return header;
--    end function;

--    procedure srpSimWrite (
--       signal clk    : in  sl;
--       signal master : out AxiStreamMasterType;
--       signal slave  : in  AxiStreamSlaveType;
--       addr          : in  slv;
--       data          : in  Slv32Array;
--       txnId         : in  slv(31 downto 0) := (others => '0');
--       timeout       : in  slv(7 downto 0)  := (others => '0');
--       posted        : in  boolean          := false)
--    is
--       variable txData : slv32array(0 to 4+data'length-1);
--    begin
--       -- Build frame
--       txData(0 to 4)               := srpHeader(ite(posted, SRP_POSTED_WRITE_C, SRP_WRITE_C), addr, data'length*4-1, txnId, timeout);
--       txData(5 to txData'length-1) := data;

--       axiStreamSimSendFrame(SRP_AXIS_CONFIG_C, clk, master, slave, txData, "02", "00");

--       -- Need to check response if non posted

--    end procedure;

--    procedure srpSimRead (
--       signal clk    : in  sl;
--       signal master : out AxiStreamMasterType;
--       signal slave  : in  AxiStreamSlaveType;
--       addr          : in  slv;
--       data          : inout  Slv32Array;
--       txnId         : in  slv(31 downto 0) := (others => '0');
--       timeout       : in  slv(7 downto 0)  := (others => '0'))
--    is
--       variable txData : slv32array(0 to 4);
--    begin
--       -- Build frame
--       txData(0 to 4)               := srpHeader(SRP_READ_C, addr, data'length*4-1, txnId, timeout);
--       axiStreamSimSendFrame(SRP_AXIS_CONFIG_C, clk, master, slave, txData, "02", "00");

--       --axiStreamSimReceiveFrame(SRP_AXIS_CONFIG_C, clk, 

--    end procedure;

end package body SrpV3Pkg;
