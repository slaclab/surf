-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Private PTP word-bank requests and AXI bridge ownership.
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
use ieee.numeric_std.all;
library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

package PtpRegisterPkg is

   type PtpRegisterMasterType is record
      valid         : sl;
      write         : sl;
      bank          : slv(1 downto 0); -- 0 shadow, 1 active, 2 frozen candidate.
      index         : slv(7 downto 0);
      data          : slv(31 downto 0);
      mask          : slv(31 downto 0);
      responseReady : sl;
      cancel        : sl; -- Response cancellation only; accepted writes survive.
   end record;

   constant PTP_REGISTER_MASTER_INIT_C : PtpRegisterMasterType := (
      valid         => '0',
      write         => '0',
      bank          => "00",
      index         => (others => '0'),
      data          => (others => '0'),
      mask          => (others => '0'),
      responseReady => '0',
      cancel        => '0');

   type PtpRegisterSlaveType is record
      ready         : sl;
      responseValid : sl;
      data          : slv(31 downto 0);
   end record;

   constant PTP_REGISTER_SLAVE_INIT_C : PtpRegisterSlaveType := (
      ready         => '0',
      responseValid => '0',
      data          => (others => '0'));

   type PtpRegisterMasterArray is array(natural range <>) of PtpRegisterMasterType;
   type PtpRegisterSlaveArray is array(natural range <>) of PtpRegisterSlaveType;

   type PtpPublicationType is record
      write        : sl;
      first        : sl;
      recordIndex  : slv(3 downto 0);
      wordIndex    : slv(7 downto 0);
      data         : slv(31 downto 0);
      commit       : sl;
      commitRecord : slv(3 downto 0);
   end record;

   constant PTP_PUBLICATION_INIT_C : PtpPublicationType := (
      write        => '0',
      first        => '0',
      recordIndex  => (others => '0'),
      wordIndex    => (others => '0'),
      data         => (others => '0'),
      commit       => '0',
      commitRecord => (others => '0'));

   -- The AXI address/data remain at their producer until RAM completion. These
   -- scalars track the single outstanding local RAM operation; unrelated local
   -- register transactions can still complete on the other AXI channel.
   type PtpRegisterBusType is record
      master : PtpRegisterMasterType;
      busy   : sl;
      write  : sl;
   end record;

   constant PTP_REGISTER_BUS_INIT_C : PtpRegisterBusType := (
      master => PTP_REGISTER_MASTER_INIT_C,
      busy   => '0',
      write  => '0');

   procedure ptpRegisterBus(
      variable v          : inout PtpRegisterBusType;
      constant r     : PtpRegisterBusType;
      constant slave : PtpRegisterSlaveType;
      variable ep         : inout AxiLiteEndpointType;
      constant readIndex  : integer;
      constant writeIndex : integer;
      constant writeMask : slv(31 downto 0);
      constant readBank  : slv(1 downto 0) := "00";
      constant reset     : sl              := '0');

   -- Registered candidate scan in clk, without backpressure. valid qualifies a
   -- 32-bit data word and its word index. prepare freezes the candidate; this
   -- stream finishes before prepared. Reset cancels preparation.
   type PtpConfigScanType is record
      valid : sl;
      index : slv(7 downto 0);
      data  : slv(31 downto 0);
   end record;

   constant PTP_CONFIG_SCAN_INIT_C : PtpConfigScanType := (
      valid => '0',
      index => (others => '0'),
      data  => (others => '0'));

   -- PtpEndpoint aperture (ethernet/PtpCore/register-map.md): 32 KiB with the
   -- endpoint coordinator at 0x0000, ProtocolEngine at 0x2000, Servo at
   -- 0x3000 and the 8 KiB PtpPhcCore at 0x4000. Offsets 0x1000-0x1FFF and
   -- 0x6000-0x7FFF are unmapped. Slot order is part of the register ABI.
   constant PTP_ENDPOINT_AXIL_APERTURE_BITS_C : positive := 15;
   constant PTP_ENDPOINT_AXIL_MASTERS_C       : positive := 4;
   constant PTP_ENDPOINT_CONTROL_INDEX_C      : natural  := 0;
   constant PTP_ENDPOINT_PHC_INDEX_C          : natural  := 1;
   constant PTP_ENDPOINT_PORT_INDEX_C         : natural  := 2;
   constant PTP_ENDPOINT_SERVO_INDEX_C        : natural  := 3;

   function ptpEndpointAxilConfig (base : slv(31 downto 0)) return AxiLiteCrossbarMasterConfigArray;

end package PtpRegisterPkg;

package body PtpRegisterPkg is

   procedure ptpRegisterBus(
      variable v          : inout PtpRegisterBusType;
      constant r     : PtpRegisterBusType;
      constant slave : PtpRegisterSlaveType;
      variable ep         : inout AxiLiteEndpointType;
      constant readIndex  : integer;
      constant writeIndex : integer;
      constant writeMask : slv(31 downto 0);
      constant readBank  : slv(1 downto 0) := "00";
      constant reset     : sl              := '0') is
   begin
      v.master.responseReady := '1';
      v.master.cancel        := reset;

      if r.master.valid = '1' and slave.ready = '1' then
         v.master.valid := '0';
      end if;

      if r.busy = '0' and reset = '0' then
         if ep.axiStatus.readEnable = '1' and readIndex >= 0 then
            v.busy         := '1';
            v.write        := '0';
            v.master.valid := '1';
            v.master.write := '0';
            v.master.bank  := readBank;
            v.master.index := toSlv(readIndex, 8);
         elsif ep.axiStatus.writeEnable = '1' and writeIndex >= 0 and unsigned(writeMask) /= 0 then
            v.busy         := '1';
            v.write        := '1';
            v.master.valid := '1';
            v.master.write := '1';
            v.master.bank  := "00";
            v.master.index := toSlv(writeIndex, 8);
            v.master.data  := ep.axiWriteMaster.wdata;
            v.master.mask  := writeMask;
         end if;
      end if;

      if r.busy = '1' and slave.responseValid = '1' and reset = '0' then
         v.busy := '0';
         if r.write = '1' then
            axiSlaveWriteResponse(ep.axiWriteSlave);
         else
            ep.axiReadSlave.rdata := slave.data;
            axiSlaveReadResponse(ep.axiReadSlave);
         end if;
      end if;

      -- Defer only mapped RAM transactions. A malformed strobe still gets the
      -- owning local bank's normal DECERR response from axiSlaveDefault.
      if readIndex >= 0 then
         ep.axiStatus.readEnable := '0';
      end if;

      if writeIndex >= 0 and unsigned(writeMask) /= 0 then
         ep.axiStatus.writeEnable := '0';
      end if;

      if reset = '1' then
         v                      := PTP_REGISTER_BUS_INIT_C;
         v.master.cancel        := '1';
         v.master.responseReady := '1';
      end if;

   end procedure;

   function ptpEndpointAxilConfig (base : slv(31 downto 0)) return AxiLiteCrossbarMasterConfigArray is
      variable retVar : AxiLiteCrossbarMasterConfigArray(PTP_ENDPOINT_AXIL_MASTERS_C-1 downto 0);

      -- Keep the aperture-selection bits of base and place the local offset.
      function slot (offset : natural; addrBits : positive) return AxiLiteCrossbarMasterConfigType is
      begin
         return (
            baseAddr     => base(31 downto PTP_ENDPOINT_AXIL_APERTURE_BITS_C) &
                            slv(to_unsigned(offset, PTP_ENDPOINT_AXIL_APERTURE_BITS_C)),
            addrBits     => addrBits,
            connectivity => x"FFFF");
      end function;

   begin
      retVar(PTP_ENDPOINT_CONTROL_INDEX_C) := slot(16#0000#, 12);
      retVar(PTP_ENDPOINT_PORT_INDEX_C)    := slot(16#2000#, 12);
      retVar(PTP_ENDPOINT_SERVO_INDEX_C)   := slot(16#3000#, 12);
      retVar(PTP_ENDPOINT_PHC_INDEX_C)     := slot(16#4000#, 13);
      return retVar;
   end function;

end package body PtpRegisterPkg;
