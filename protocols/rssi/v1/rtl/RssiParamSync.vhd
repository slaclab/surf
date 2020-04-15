-------------------------------------------------------------------------------
-- Title      : RSSI Protocol: https://confluence.slac.stanford.edu/x/1IyfD
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:  Sync the RSSI parameter across clock doamins
------------------------------------------------------------------------------
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
use surf.RssiPkg.all;

entity RssiParamSync is
   generic (
      TPD_G        : time    := 1 ns;
      COMMON_CLK_G : boolean := false);
   port (
      clk         : in  sl;
      rssiParam_i : in  RssiParamType;
      rssiParam_o : out RssiParamType);
end RssiParamSync;

architecture rtl of RssiParamSync is

   signal rssiParam : RssiParamType;

begin

   rssiParam_o <= rssiParam;

   U_version : entity surf.SynchronizerVector
      generic map (
         TPD_G         => TPD_G,
         BYPASS_SYNC_G => COMMON_CLK_G,
         WIDTH_G       => 4)
      port map (
         clk     => clk,
         dataIn  => rssiParam_i.version,
         dataOut => rssiParam.version);

   U_chksumEn : entity surf.SynchronizerVector
      generic map (
         TPD_G         => TPD_G,
         BYPASS_SYNC_G => COMMON_CLK_G,
         WIDTH_G       => 1)
      port map (
         clk     => clk,
         dataIn  => rssiParam_i.chksumEn,
         dataOut => rssiParam.chksumEn);

   U_timeoutUnit : entity surf.SynchronizerVector
      generic map (
         TPD_G         => TPD_G,
         BYPASS_SYNC_G => COMMON_CLK_G,
         WIDTH_G       => 8)
      port map (
         clk     => clk,
         dataIn  => rssiParam_i.timeoutUnit,
         dataOut => rssiParam.timeoutUnit);

   U_maxOutsSeg : entity surf.SynchronizerVector
      generic map (
         TPD_G         => TPD_G,
         BYPASS_SYNC_G => COMMON_CLK_G,
         WIDTH_G       => 8)
      port map (
         clk     => clk,
         dataIn  => rssiParam_i.maxOutsSeg,
         dataOut => rssiParam.maxOutsSeg);

   U_maxSegSize : entity surf.SynchronizerVector
      generic map (
         TPD_G         => TPD_G,
         BYPASS_SYNC_G => COMMON_CLK_G,
         WIDTH_G       => 16)
      port map (
         clk     => clk,
         dataIn  => rssiParam_i.maxSegSize,
         dataOut => rssiParam.maxSegSize);

   U_retransTout : entity surf.SynchronizerVector
      generic map (
         TPD_G         => TPD_G,
         BYPASS_SYNC_G => COMMON_CLK_G,
         WIDTH_G       => 16)
      port map (
         clk     => clk,
         dataIn  => rssiParam_i.retransTout,
         dataOut => rssiParam.retransTout);

   U_cumulAckTout : entity surf.SynchronizerVector
      generic map (
         TPD_G         => TPD_G,
         BYPASS_SYNC_G => COMMON_CLK_G,
         WIDTH_G       => 16)
      port map (
         clk     => clk,
         dataIn  => rssiParam_i.cumulAckTout,
         dataOut => rssiParam.cumulAckTout);

   U_nullSegTout : entity surf.SynchronizerVector
      generic map (
         TPD_G         => TPD_G,
         BYPASS_SYNC_G => COMMON_CLK_G,
         WIDTH_G       => 16)
      port map (
         clk     => clk,
         dataIn  => rssiParam_i.nullSegTout,
         dataOut => rssiParam.nullSegTout);

   U_maxRetrans : entity surf.SynchronizerVector
      generic map (
         TPD_G         => TPD_G,
         BYPASS_SYNC_G => COMMON_CLK_G,
         WIDTH_G       => 8)
      port map (
         clk     => clk,
         dataIn  => rssiParam_i.maxRetrans,
         dataOut => rssiParam.maxRetrans);

   U_maxCumAck : entity surf.SynchronizerVector
      generic map (
         TPD_G         => TPD_G,
         BYPASS_SYNC_G => COMMON_CLK_G,
         WIDTH_G       => 8)
      port map (
         clk     => clk,
         dataIn  => rssiParam_i.maxCumAck,
         dataOut => rssiParam.maxCumAck);

   U_maxOutofseq : entity surf.SynchronizerVector
      generic map (
         TPD_G         => TPD_G,
         BYPASS_SYNC_G => COMMON_CLK_G,
         WIDTH_G       => 8)
      port map (
         clk     => clk,
         dataIn  => rssiParam_i.maxOutofseq,
         dataOut => rssiParam.maxOutofseq);

   U_connectionId : entity surf.SynchronizerVector
      generic map (
         TPD_G         => TPD_G,
         BYPASS_SYNC_G => COMMON_CLK_G,
         WIDTH_G       => 32)
      port map (
         clk     => clk,
         dataIn  => rssiParam_i.connectionId,
         dataOut => rssiParam.connectionId);

end rtl;
