-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Timing-port AXI-Lite bank: capability, status, faults,
-- controller levels, table occupancy and counters.
--
-- Read-only view of PtpMacPort for a port driven by an RTL controller, such
-- as PtpMacPortEndpoint: the control levels are reported, not written, and
-- SoftwareControl reads zero. Occupancy is the owned TX/RX table entries;
-- each high-water mark holds the largest occupancy since system reset or the
-- last OccupancyClear, which restarts both marks from the current value.
-- Counters are the port's saturating counters, cleared only by system reset.
-- All inputs and the bus are in clk; regRst cancels AXI responses only.
-- Offsets: ethernet/PtpCore/register-map.md, timing-port bank.
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
use surf.EthMacPkg.all;
use surf.PtpPkg.all;

entity PtpMacPortReg is
   generic (
      TPD_G            : time                    := 1 ns;
      RST_POLARITY_G   : sl                      := '1';  -- '1' for active HIGH reset, '0' for active LOW reset
      PHY_TYPE_G       : string                  := "GMII";  -- "GMII" or "XGMII"
      TX_TABLE_DEPTH_G : positive range 1 to 255 := 16;
      RX_TABLE_DEPTH_G : positive range 1 to 255 := 16);
   port (
      clk            : in  sl;
      rst            : in  sl;
      regRst         : in  sl := '0';
      -- Port state
      control        : in  PtpMacPortControlType;
      status         : in  PtpMacPortStatusType;
      counters       : in  PtpMacPortCountersType;
      -- AXI-Lite bank
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType);
end entity PtpMacPortReg;

architecture rtl of PtpMacPortReg is

   constant PHY_C : slv(3 downto 0) := ite(PHY_TYPE_G = "GMII", PTP_MAC_PORT_PHY_GMII_C, PTP_MAC_PORT_PHY_XGMII_C);

   type RegType is record
      txPeak     : slv(7 downto 0);
      rxPeak     : slv(7 downto 0);
      readSlave  : AxiLiteReadSlaveType;
      writeSlave : AxiLiteWriteSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      txPeak     => (others => '0'),
      rxPeak     => (others => '0'),
      readSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      writeSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (axiReadMaster, axiWriteMaster, control, counters, r, regRst, rst, status) is
      variable v          : RegType;
      variable ep         : AxiLiteEndpointType;
      variable peakClear  : sl;
      variable capability : slv(31 downto 0);
      variable depths     : slv(31 downto 0);
   begin
      -- Latch the current value
      v := r;

      peakClear := '0';

      capability               := (others => '0');
      capability(7 downto 0)   := PTP_MAC_PORT_ABI_VERSION_C;
      capability(11 downto 8)  := PHY_C;
      capability(15 downto 12) := PTP_MAC_PORT_PLANE_MAC_DMAC_C;
      capability(16)           := '1';  -- Timing-mode MAC
      capability(17)           := '0';  -- One-step TX
      capability(18)           := '0';  -- Software control
      capability(31 downto 24) := toSlv(EMAC_TOKEN_BITS_C, 8);

      depths(7 downto 0)   := toSlv(TX_TABLE_DEPTH_G, 8);
      depths(15 downto 8)  := toSlv(RX_TABLE_DEPTH_G, 8);
      depths(31 downto 16) := toSlv(EMAC_TIMING_MAX_FRAME_C, 16);

      ------------------------------------------------------------------------
      -- AXI-Lite
      ------------------------------------------------------------------------
      axiSlaveWaitTxn(ep, axiWriteMaster, axiReadMaster, v.writeSlave, v.readSlave);

      axiSlaveRegisterR(ep, x"000", 0, capability);
      axiSlaveRegisterR(ep, x"004", 0, depths);
      axiSlaveRegisterR(ep, x"008", 0, toSlv(PTP_MAC_PORT_COOKIE_BITS_C, 8));

      axiSlaveRegisterR(ep, x"010", 0, status.admissionOpen);
      axiSlaveRegisterR(ep, x"010", 1, status.drainIdle);
      axiSlaveRegisterR(ep, x"010", 2, status.cancelRequest);
      axiSlaveRegisterR(ep, x"010", 3, status.abortDone);
      axiSlaveRegisterR(ep, x"010", 16, status.transportGeneration);

      axiSlaveRegisterR(ep, x"014", 0, status.faultGeneration);
      axiSlaveRegisterR(ep, x"014", 1, status.faultClockEnable);
      axiSlaveRegisterR(ep, x"014", 2, status.faultTokenProtocol);

      axiSlaveRegisterR(ep, x"018", 0, control.openAdmission);
      axiSlaveRegisterR(ep, x"018", 1, control.drainRequest);
      axiSlaveRegisterR(ep, x"018", 2, control.abortRequest);
      axiSlaveRegisterR(ep, x"018", 3, control.cancelAck);

      axiSlaveRegisterR(ep, x"020", 0, status.txOccupancy);
      axiSlaveRegisterR(ep, x"020", 8, r.txPeak);
      axiSlaveRegisterR(ep, x"020", 16, status.rxOccupancy);
      axiSlaveRegisterR(ep, x"020", 24, r.rxPeak);
      axiSlaveRegister(ep, x"024", 0, peakClear);

      axiSlaveRegisterR(ep, x"040", 0, counters.rxDelivered);
      axiSlaveRegisterR(ep, x"044", 0, counters.rxDropped);
      axiSlaveRegisterR(ep, x"048", 0, counters.rxLost);
      axiSlaveRegisterR(ep, x"04C", 0, counters.txSent);
      axiSlaveRegisterR(ep, x"050", 0, counters.txWireError);
      axiSlaveRegisterR(ep, x"054", 0, counters.txDiscarded);
      axiSlaveRegisterR(ep, x"058", 0, counters.txFlushed);
      axiSlaveRegisterR(ep, x"05C", 0, counters.txRejected);

      axiSlaveDefault(ep, v.writeSlave, v.readSlave, AXI_RESP_DECERR_C);

      -- The bus reset cancels responses and the clear only.
      if regRst = '1' then
         peakClear    := '0';
         v.readSlave  := AXI_LITE_READ_SLAVE_INIT_C;
         v.writeSlave := AXI_LITE_WRITE_SLAVE_INIT_C;
      end if;

      ------------------------------------------------------------------------
      -- High-water marks
      ------------------------------------------------------------------------
      if peakClear = '1' then
         v.txPeak := status.txOccupancy;
         v.rxPeak := status.rxOccupancy;
      else
         if unsigned(status.txOccupancy) > unsigned(r.txPeak) then
            v.txPeak := status.txOccupancy;
         end if;
         if unsigned(status.rxOccupancy) > unsigned(r.rxPeak) then
            v.rxPeak := status.rxOccupancy;
         end if;
      end if;

      -- Outputs
      axiReadSlave  <= r.readSlave;
      axiWriteSlave <= r.writeSlave;

      -- Reset
      if (rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
