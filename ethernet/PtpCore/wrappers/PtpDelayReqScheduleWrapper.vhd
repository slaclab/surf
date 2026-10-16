-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Thin scheduler fixture with controlled raw time and ledger grant.
--
-- The production transmitter owns interval selection and frame serialization.
-- Cocotb supplies configuration and accepted-response intervals, holds raw time
-- during serialization, and measures request offers on the public AXI stream.
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'. It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SLAC Firmware Standard Library', including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.PtpPkg.all;
use surf.PtpProtocolPkg.all;

entity PtpDelayReqScheduleWrapper is
   port (
      clk           : in  sl;
      rst           : in  sl;
      enable        : in  sl;
      cancel        : in  sl;
      ticks         : in  slv(63 downto 0);
      localInterval : in  slv(63 downto 0);
      seed          : in  slv(15 downto 0);
      intervalValid : in  sl;
      intervalTicks : in  slv(63 downto 0);
      grant         : in  sl;
      txReady       : in  sl;
      allocate      : out sl;
      txValid       : out sl;
      txLast        : out sl);
end entity PtpDelayReqScheduleWrapper;

architecture rtl of PtpDelayReqScheduleWrapper is

   signal config     : PtpPortConfigType;
   signal interval   : PtpIntervalType;
   signal allocation : PtpLedgerAllocationType;
   signal txMaster   : AxiStreamMasterType;
   signal txSlave    : AxiStreamSlaveType;

begin

   comb : process (all) is
      variable cfg    : PtpPortConfigType;
      variable ledger : PtpLedgerAllocationType;
      variable slave  : AxiStreamSlaveType;
   begin
      cfg               := PTP_PORT_CONFIG_INIT_C;
      cfg.delayInterval := localInterval;
      cfg.lfsrSeed      := seed;
      ledger.ready      := grant;
      ledger.sequenceId := (others => '0');
      slave             := AXI_STREAM_SLAVE_INIT_C;
      slave.tReady      := txReady;
      config            <= cfg;
      allocation        <= ledger;
      txSlave           <= slave;
   end process comb;
   interval <= (valid => intervalValid, ticks => intervalTicks);
   txValid <= txMaster.tValid;
   txLast <= txMaster.tLast;

   U_DUT : entity surf.PtpDelayReqTx
      port map (
         clk          => clk,                   -- [in]
         rst          => rst,                   -- [in]
         enable       => enable,                -- [in]
         cancel       => cancel,                -- [in]
         ticks        => ticks,                 -- [in]
         config       => config,                -- [in]
         localMac     => x"010000000002",        -- [in]
         interval     => interval,              -- [in]
         ledgerCancel => cancel,                -- [in]
         allocate     => allocate,              -- [out]
         allocation   => allocation,            -- [in]
         txMaster     => txMaster,              -- [out]
         txSlave      => txSlave);              -- [in]

end architecture rtl;
