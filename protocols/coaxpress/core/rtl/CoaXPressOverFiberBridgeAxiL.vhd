-------------------------------------------------------------------------------
-- Title      : CXP Over Fiber Bridge AXI-Lite Status
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: AXI-Lite status and counters for CoaXPress-over-Fiber bridge RX
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
use surf.AxiLitePkg.all;
use surf.CoaXPressPkg.all;

entity CoaXPressOverFiberBridgeAxiL is
   generic (
      TPD_G       : time                   := 1 ns;
      CNT_WIDTH_G : positive range 1 to 32 := 16);
   port (
      -- Bridge RX status clock domain
      rxClk           : in  sl;
      rxRst           : in  sl;
      rxStatus        : in  CxpofRxStatusType;
      -- AXI-Lite Register Interface
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end entity CoaXPressOverFiberBridgeAxiL;

architecture rtl of CoaXPressOverFiberBridgeAxiL is

   constant STATUS_WIDTH_C : positive := 6;

   constant RX_ERROR_INDEX_C : natural := 0;
   constant RX_ABORT_INDEX_C : natural := 1;
   constant SEQ_VALID_INDEX_C : natural := 2;
   constant SEQ_ERROR_INDEX_C : natural := 3;
   constant HKP_VALID_INDEX_C : natural := 4;
   constant HKP_ERROR_INDEX_C : natural := 5;

   type RegType is record
      cntRst         : sl;
      stickyStatus   : slv(STATUS_WIDTH_C-1 downto 0);
      statusCnt      : Slv32Array(STATUS_WIDTH_C-1 downto 0);
      rxErrorCode    : slv(3 downto 0);
      seqData        : slv(23 downto 0);
      seqExpected    : slv(23 downto 0);
      seqErrorExpected : slv(23 downto 0);
      hkpData        : slv(31 downto 0);
      hkpWordCount   : slv(7 downto 0);
      hkpKCodeMask   : slv(3 downto 0);
      hkpKCodeValid  : sl;
      hkpType        : slv(3 downto 0);
      axilWriteSlave : AxiLiteWriteSlaveType;
      axilReadSlave  : AxiLiteReadSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      cntRst         => '1',
      stickyStatus   => (others => '0'),
      statusCnt      => (others => (others => '0')),
      rxErrorCode    => CXPOF_RX_ERR_NONE_C,
      seqData        => (others => '0'),
      seqExpected    => (others => '0'),
      seqErrorExpected => (others => '0'),
      hkpData        => (others => '0'),
      hkpWordCount   => (others => '0'),
      hkpKCodeMask   => (others => '0'),
      hkpKCodeValid  => '0',
      hkpType        => CXPOF_HKP_TYPE_NONE_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal statusIn : slv(STATUS_WIDTH_C-1 downto 0);

   signal rxAxilReadMaster  : AxiLiteReadMasterType;
   signal rxAxilReadSlave   : AxiLiteReadSlaveType;
   signal rxAxilWriteMaster : AxiLiteWriteMasterType;
   signal rxAxilWriteSlave  : AxiLiteWriteSlaveType;

begin

   statusIn(RX_ERROR_INDEX_C) <= rxStatus.rxError;
   statusIn(RX_ABORT_INDEX_C) <= rxStatus.rxAbort;
   statusIn(SEQ_VALID_INDEX_C) <= rxStatus.seqValid;
   statusIn(SEQ_ERROR_INDEX_C) <= rxStatus.seqError;
   statusIn(HKP_VALID_INDEX_C) <= rxStatus.hkpValid;
   statusIn(HKP_ERROR_INDEX_C) <= rxStatus.hkpError;

   U_AxiLiteAsync : entity surf.AxiLiteAsync
      generic map (
         TPD_G => TPD_G)
      port map (
         -- Slave Interface
         sAxiClk         => axilClk,
         sAxiClkRst      => axilRst,
         sAxiReadMaster  => axilReadMaster,
         sAxiReadSlave   => axilReadSlave,
         sAxiWriteMaster => axilWriteMaster,
         sAxiWriteSlave  => axilWriteSlave,
         -- Master Interface
         mAxiClk         => rxClk,
         mAxiClkRst      => rxRst,
         mAxiReadMaster  => rxAxilReadMaster,
         mAxiReadSlave   => rxAxilReadSlave,
         mAxiWriteMaster => rxAxilWriteMaster,
         mAxiWriteSlave  => rxAxilWriteSlave);

   comb : process (r, rxAxilReadMaster, rxAxilWriteMaster, rxRst, rxStatus,
                   statusIn) is
      variable v         : RegType;
      variable axilEp    : AxiLiteEndpointType;
      variable hkpStatus : slv(31 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Reset strobes
      v.cntRst := '0';

      -- Accumulate sticky status bits and event counters in the RX domain.
      v.stickyStatus := r.stickyStatus or statusIn;
      for i in 0 to STATUS_WIDTH_C-1 loop
         if (statusIn(i) = '1') then
            v.statusCnt(i)(CNT_WIDTH_G-1 downto 0) := r.statusCnt(i)(CNT_WIDTH_G-1 downto 0) + 1;
         end if;
      end loop;

      if (r.cntRst = '1') then
         v.stickyStatus := (others => '0');
         v.statusCnt    := (others => (others => '0'));
      end if;

      if (rxStatus.rxError = '1') then
         v.rxErrorCode := rxStatus.rxErrorCode;
      end if;

      if (rxStatus.seqValid = '1') then
         v.seqData     := rxStatus.seqData;
         v.seqExpected := rxStatus.seqExpected;
      end if;

      if (rxStatus.seqError = '1') then
         v.seqErrorExpected := rxStatus.seqErrorExpected;
      end if;

      if (rxStatus.hkpValid = '1') or (rxStatus.hkpError = '1') then
         v.hkpData       := rxStatus.hkpData;
         v.hkpWordCount  := rxStatus.hkpWordCount;
         v.hkpKCodeMask  := rxStatus.hkpKCodeMask;
         v.hkpKCodeValid := rxStatus.hkpKCodeValid;
         v.hkpType       := rxStatus.hkpType;
      end if;

      hkpStatus := (others => '0');
      hkpStatus(7 downto 0)   := r.hkpWordCount;
      hkpStatus(11 downto 8)  := r.hkpKCodeMask;
      hkpStatus(12)           := r.hkpKCodeValid;
      hkpStatus(19 downto 16) := r.hkpType;

      ------------------------
      -- AXI-Lite Transactions
      ------------------------
      axiSlaveWaitTxn(axilEp, rxAxilWriteMaster, rxAxilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      axiSlaveRegisterR(axilEp, x"000", 0, r.stickyStatus);
      axiSlaveRegisterR(axilEp, x"004", 0, r.rxErrorCode);
      axiSlaveRegisterR(axilEp, x"008", 0, r.seqData);
      axiSlaveRegisterR(axilEp, x"00C", 0, r.seqExpected);
      axiSlaveRegisterR(axilEp, x"010", 0, r.seqErrorExpected);
      axiSlaveRegisterR(axilEp, x"014", 0, r.hkpData);
      axiSlaveRegisterR(axilEp, x"018", 0, hkpStatus);

      for i in 0 to STATUS_WIDTH_C-1 loop
         axiSlaveRegisterR(axilEp, x"020"+toSlv(i*4, 12), 0, r.statusCnt(i));
      end loop;

      axiSlaveRegister(axilEp, x"03C", 0, v.cntRst);

      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);

      -- Outputs
      rxAxilReadSlave  <= r.axilReadSlave;
      rxAxilWriteSlave <= r.axilWriteSlave;

      -- Reset
      if (rxRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

   end process comb;

   seq : process (rxClk) is
   begin
      if (rising_edge(rxClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
