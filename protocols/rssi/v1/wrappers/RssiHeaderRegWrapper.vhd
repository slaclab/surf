-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for RSSI header register tests
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
use surf.RssiPkg.all;

entity RssiHeaderRegWrapper is
   generic (
      TPD_G : time := 1 ns
   );
   port (
      clk_i : in sl;
      rst_i : in sl;

      synHeadSt_i  : in sl;
      rstHeadSt_i  : in sl;
      dataHeadSt_i : in sl;
      nullHeadSt_i : in sl;
      ackHeadSt_i  : in sl;
      busyHeadSt_i : in sl;

      ack_i    : in sl;
      txSeqN_i : in slv(7 downto 0);
      rxAckN_i : in slv(7 downto 0);

      paramVersion_i      : in slv(3 downto 0);
      paramChksumEn_i     : in slv(0 downto 0);
      paramTimeoutUnit_i  : in slv(7 downto 0);
      paramMaxOutsSeg_i   : in slv(7 downto 0);
      paramMaxSegSize_i   : in slv(15 downto 0);
      paramRetransTout_i  : in slv(15 downto 0);
      paramCumulAckTout_i : in slv(15 downto 0);
      paramNullSegTout_i  : in slv(15 downto 0);
      paramMaxRetrans_i   : in slv(7 downto 0);
      paramMaxCumAck_i    : in slv(7 downto 0);
      paramMaxOutofseq_i  : in slv(7 downto 0);
      paramConnectionId_i : in slv(31 downto 0);

      addr_i         : in  slv(7 downto 0);
      headerData_o   : out slv((RSSI_WORD_WIDTH_C * 8)-1 downto 0);
      ready_o        : out sl;
      headerLength_o : out positive
   );
end entity RssiHeaderRegWrapper;

architecture mapping of RssiHeaderRegWrapper is

   signal headerValues : RssiParamType;

begin

   -- Flatten the RSSI parameter record so cocotb can drive deterministic
   -- SYN-header values through simulator-visible scalar/vector ports.
   headerValues.version      <= paramVersion_i;
   headerValues.chksumEn     <= paramChksumEn_i;
   headerValues.timeoutUnit  <= paramTimeoutUnit_i;
   headerValues.maxOutsSeg   <= paramMaxOutsSeg_i;
   headerValues.maxSegSize   <= paramMaxSegSize_i;
   headerValues.retransTout  <= paramRetransTout_i;
   headerValues.cumulAckTout <= paramCumulAckTout_i;
   headerValues.nullSegTout  <= paramNullSegTout_i;
   headerValues.maxRetrans   <= paramMaxRetrans_i;
   headerValues.maxCumAck    <= paramMaxCumAck_i;
   headerValues.maxOutofseq  <= paramMaxOutofseq_i;
   headerValues.connectionId <= paramConnectionId_i;

   -- Real DUT hookup.
   U_DUT : entity surf.RssiHeaderReg
      generic map (
         TPD_G => TPD_G)
      port map (
         clk_i          => clk_i,        -- [in]
         rst_i          => rst_i,        -- [in]
         synHeadSt_i    => synHeadSt_i,  -- [in]
         rstHeadSt_i    => rstHeadSt_i,  -- [in]
         dataHeadSt_i   => dataHeadSt_i, -- [in]
         nullHeadSt_i   => nullHeadSt_i, -- [in]
         ackHeadSt_i    => ackHeadSt_i,  -- [in]
         busyHeadSt_i   => busyHeadSt_i, -- [in]
         ack_i          => ack_i,        -- [in]
         txSeqN_i       => txSeqN_i,     -- [in]
         rxAckN_i       => rxAckN_i,     -- [in]
         headerValues_i => headerValues, -- [in]
         addr_i         => addr_i,       -- [in]
         headerData_o   => headerData_o, -- [out]
         ready_o        => ready_o,      -- [out]
         headerLength_o => headerLength_o); -- [out]

end architecture mapping;
