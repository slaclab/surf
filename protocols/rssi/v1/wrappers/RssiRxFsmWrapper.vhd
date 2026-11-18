-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Flattened SSI and status boundary for RSSI receive FSM tests.
-- Uses the same synchronous payload RAM as RssiCore. Tests may supply checksum
-- status externally to isolate filtering, or select the real RssiChksum to
-- exercise header capture and validation under contiguous traffic.
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
use surf.SsiPkg.all;

entity RssiRxFsmWrapper is
   generic (
      TPD_G               : time     := 1 ns;
      WINDOW_ADDR_SIZE_G  : positive := 3;
      HEADER_CHKSUM_EN_G  : boolean  := true;
      EXTERNAL_CHKSUM_G   : boolean  := true;
      SEGMENT_ADDR_SIZE_G : positive := 2
   );
   port (
      axisClk : in sl;
      axisRst : in sl;

      connActive_i   : in sl;
      rxWindowSize_i : in integer range 1 to 2 ** (WINDOW_ADDR_SIZE_G);
      rxBufferSize_i : in integer range 1 to 2 ** (SEGMENT_ADDR_SIZE_G);
      txWindowSize_i : in integer range 1 to 2 ** (WINDOW_ADDR_SIZE_G);
      lastAckN_i     : in slv(7 downto 0);

      sAxisTValid : in  sl;
      sAxisTReady : out sl;
      sAxisTData  : in  slv(63 downto 0);
      sAxisTKeep  : in  slv(7 downto 0);
      sAxisTLast  : in  sl;
      sAxisSof    : in  sl;
      sAxisEofe   : in  sl;

      mAxisTValid : out sl;
      mAxisTReady : in  sl;
      mAxisTData  : out slv(63 downto 0);
      mAxisTKeep  : out slv(7 downto 0);
      mAxisTLast  : out sl;
      mAxisSof    : out sl;
      mAxisEofe   : out sl;

      chksumValid_i : in sl;
      chksumOk_i    : in sl;

      rxSeqN_o           : out slv(7 downto 0);
      rxAckN_o           : out slv(7 downto 0);
      rxLastSeqN_o       : out slv(7 downto 0);
      rxValidSeg_o       : out sl;
      rxDropSeg_o        : out sl;
      rxFlagSyn_o        : out sl;
      rxFlagAck_o        : out sl;
      rxFlagRst_o        : out sl;
      rxFlagNull_o       : out sl;
      rxFlagData_o       : out sl;
      rxFlagBusy_o       : out sl;
      chksumEnable_o     : out sl;
      chksumStrobe_o     : out sl;
      chksumLength_o     : out positive;
      rxTspState_o       : out slv(3 downto 0);
      rxAppState_o       : out slv(3 downto 0);
      paramVersion_o     : out slv(3 downto 0);
      paramChksumEn_o    : out slv(0 downto 0);
      paramConnId_o      : out slv(31 downto 0);
      paramTimeoutUnit_o : out slv(7 downto 0);
      paramMaxOutofseq_o : out slv(7 downto 0);
      payloadWrite_o     : out sl
   );
end entity RssiRxFsmWrapper;

architecture mapping of RssiRxFsmWrapper is

   signal tspSsiMaster  : SsiMasterType;
   signal tspSsiSlave   : SsiSlaveType;
   signal appSsiMaster  : SsiMasterType;
   signal appSsiSlave   : SsiSlaveType;
   signal rxFlags       : flagsType;
   signal rxParam       : RssiParamType;
   signal wrBuffWe      : sl;
   signal wrBuffAddr    : slv((SEGMENT_ADDR_SIZE_G+WINDOW_ADDR_SIZE_G)-1 downto 0);
   signal wrBuffData    : slv(63 downto 0);
   signal rdBuffAddr    : slv((SEGMENT_ADDR_SIZE_G+WINDOW_ADDR_SIZE_G)-1 downto 0);
   signal rdBuffData    : slv(63 downto 0) := (others => '0');
   signal checksumValid : sl;
   signal checksumOk    : sl;

begin

   -- Flattened transport-side SSI input.
   tspSsiMaster.valid <= sAxisTValid;
   tspSsiMaster.data(63 downto 0) <= sAxisTData;
   tspSsiMaster.data(tspSsiMaster.data'high downto 64) <= (others => '0');
   tspSsiMaster.strb <= (others => '1');
   tspSsiMaster.keep(tspSsiMaster.keep'high downto RSSI_WORD_WIDTH_C) <= (others => '0');
   tspSsiMaster.keep(RSSI_WORD_WIDTH_C-1 downto 0) <= sAxisTKeep;
   tspSsiMaster.dest   <= (others => '0');
   tspSsiMaster.packed <= '0';
   tspSsiMaster.sof    <= sAxisSof;
   tspSsiMaster.eof    <= sAxisTLast;
   tspSsiMaster.eofe   <= sAxisEofe;
   sAxisTReady         <= tspSsiSlave.ready;

   -- Flattened application-side SSI output.
   mAxisTValid <= appSsiMaster.valid;
   mAxisTData  <= appSsiMaster.data(63 downto 0);
   mAxisTKeep  <= appSsiMaster.keep(7 downto 0);
   mAxisTLast  <= appSsiMaster.eof;
   mAxisSof    <= appSsiMaster.sof;
   mAxisEofe   <= appSsiMaster.eofe;

   appSsiSlave.ready    <= mAxisTReady;
   appSsiSlave.pause    <= not mAxisTReady;
   appSsiSlave.overflow <= '0';

   -- Production payload RAM, with the same read latency as RssiCore.
   U_RAM : entity surf.SimpleDualPortRam
      generic map (
         TPD_G        => TPD_G,
         COMMON_CLK_G => true,
         DATA_WIDTH_G => 64,
         ADDR_WIDTH_G => WINDOW_ADDR_SIZE_G+SEGMENT_ADDR_SIZE_G)
      port map (
         clka  => axisClk,      -- [in]
         wea   => wrBuffWe,     -- [in]
         addra => wrBuffAddr,   -- [in]
         dina  => wrBuffData,   -- [in]
         clkb  => axisClk,      -- [in]
         rstb  => axisRst,      -- [in]
         addrb => rdBuffAddr,   -- [in]
         doutb => rdBuffData);  -- [out]

   GEN_EXTERNAL : if EXTERNAL_CHKSUM_G generate
      checksumValid <= chksumValid_i;
      checksumOk    <= chksumOk_i;
   end generate GEN_EXTERNAL;

   GEN_CHECKSUM : if not EXTERNAL_CHKSUM_G generate
      U_CHECKSUM : entity surf.RssiChksum
         generic map (
            TPD_G => TPD_G)
         port map (
            clk_i    => axisClk,         -- [in]
            rst_i    => axisRst,         -- [in]
            enable_i => chksumEnable_o,  -- [in]
            strobe_i => chksumStrobe_o,  -- [in]
            length_i => chksumLength_o,  -- [in]
            init_i   => x"0000",         -- [in]
            data_i   => wrBuffData,      -- [in]
            chksum_o => open,            -- [out]
            valid_o  => checksumValid,   -- [out]
            check_o  => checksumOk);     -- [out]
   end generate GEN_CHECKSUM;

   -- Real DUT hookup.
   U_DUT : entity surf.RssiRxFsm
      generic map (
         TPD_G               => TPD_G,
         WINDOW_ADDR_SIZE_G  => WINDOW_ADDR_SIZE_G,
         HEADER_CHKSUM_EN_G  => HEADER_CHKSUM_EN_G,
         SEGMENT_ADDR_SIZE_G => SEGMENT_ADDR_SIZE_G)
      port map (
         clk_i          => axisClk,         -- [in]
         rst_i          => axisRst,         -- [in]
         connActive_i   => connActive_i,    -- [in]
         rxWindowSize_i => rxWindowSize_i,  -- [in]
         rxBufferSize_i => rxBufferSize_i,  -- [in]
         txWindowSize_i => txWindowSize_i,  -- [in]
         lastAckN_i     => lastAckN_i,      -- [in]
         rxSeqN_o       => rxSeqN_o,        -- [out]
         rxAckN_o       => rxAckN_o,        -- [out]
         rxLastSeqN_o   => rxLastSeqN_o,    -- [out]
         rxValidSeg_o   => rxValidSeg_o,    -- [out]
         rxDropSeg_o    => rxDropSeg_o,     -- [out]
         rxFlags_o      => rxFlags,         -- [out]
         rxParam_o      => rxParam,         -- [out]
         rxTspState_o   => rxTspState_o,    -- [out]
         rxAppState_o   => rxAppState_o,    -- [out]
         chksumValid_i  => checksumValid,   -- [in]
         chksumOk_i     => checksumOk,      -- [in]
         chksumEnable_o => chksumEnable_o,  -- [out]
         chksumStrobe_o => chksumStrobe_o,  -- [out]
         chksumLength_o => chksumLength_o,  -- [out]
         wrBuffWe_o     => wrBuffWe,        -- [out]
         wrBuffAddr_o   => wrBuffAddr,      -- [out]
         wrBuffData_o   => wrBuffData,      -- [out]
         rdBuffAddr_o   => rdBuffAddr,      -- [out]
         rdBuffData_i   => rdBuffData,      -- [in]
         tspSsiMaster_i => tspSsiMaster,    -- [in]
         tspSsiSlave_o  => tspSsiSlave,     -- [out]
         appSsiMaster_o => appSsiMaster,    -- [out]
         appSsiSlave_i  => appSsiSlave);    -- [in]

   rxFlagSyn_o        <= rxFlags.syn;
   rxFlagAck_o        <= rxFlags.ack;
   rxFlagRst_o        <= rxFlags.rst;
   rxFlagNull_o       <= rxFlags.nul;
   rxFlagData_o       <= rxFlags.data;
   rxFlagBusy_o       <= rxFlags.busy;
   paramVersion_o     <= rxParam.version;
   paramChksumEn_o    <= rxParam.chksumEn;
   paramConnId_o      <= rxParam.connectionId;
   paramTimeoutUnit_o <= rxParam.timeoutUnit;
   paramMaxOutofseq_o <= rxParam.maxOutofseq;
   payloadWrite_o     <= wrBuffWe;

end architecture mapping;
