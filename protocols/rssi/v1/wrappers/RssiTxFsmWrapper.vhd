-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for RSSI transmit FSM tests
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
use surf.RssiPkg.all;
use surf.SsiPkg.all;

entity RssiTxFsmWrapper is
   generic (
      TPD_G               : time     := 1 ns;
      WINDOW_ADDR_SIZE_G  : positive := 3;
      HEADER_CHKSUM_EN_G  : boolean  := true;
      SEGMENT_ADDR_SIZE_G : positive := 2
   );
   port (
      axisClk : in sl;
      axisRst : in sl;

      connActive_i  : in sl;
      closed_i      : in sl;
      injectFault_i : in sl;

      sndSyn_i    : in sl;
      sndAck_i    : in sl;
      sndRst_i    : in sl;
      sndResend_i : in sl;
      sndNull_i   : in sl;

      windowSize_i : in integer range 1 to 2 ** (WINDOW_ADDR_SIZE_G);
      bufferSize_i : in integer range 1 to 2 ** (SEGMENT_ADDR_SIZE_G);

      initSeqN_i  : in slv(7 downto 0);
      txAckFlag_i : in sl;
      rxAckN_i    : in slv(7 downto 0);
      localBusy_i : in sl;

      ack_i  : in sl;
      ackN_i : in slv(7 downto 0);

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

      chksumValid_i  : in  sl;
      chksum_i       : in  slv(15 downto 0);
      chksumEnable_o : out sl;
      chksumStrobe_o : out sl;

      txSeqN_o      : out slv(7 downto 0);
      lastAckN_o    : out slv(7 downto 0);
      synHeadSt_o   : out sl;
      ackHeadSt_o   : out sl;
      dataHeadSt_o  : out sl;
      dataSt_o      : out sl;
      rstHeadSt_o   : out sl;
      nullHeadSt_o  : out sl;
      txTspState_o  : out slv(7 downto 0);
      txAppState_o  : out slv(3 downto 0);
      txAckState_o  : out slv(3 downto 0);
      lenErr_o      : out sl;
      ackErr_o      : out sl;
      bufferEmpty_o : out sl
   );
end entity RssiTxFsmWrapper;

architecture mapping of RssiTxFsmWrapper is

   subtype MemoryAddrType is natural range 0 to 2 ** (WINDOW_ADDR_SIZE_G+SEGMENT_ADDR_SIZE_G)-1;
   type MemoryType is array (MemoryAddrType) of slv(63 downto 0);

   signal mem : MemoryType := (others => (others => '0'));

   signal appSsiMaster : SsiMasterType;
   signal appSsiSlave  : SsiSlaveType;
   signal tspSsiMaster : SsiMasterType;
   signal tspSsiSlave  : SsiSlaveType;
   signal wrBuffWe     : sl;
   signal wrBuffAddr   : slv((SEGMENT_ADDR_SIZE_G+WINDOW_ADDR_SIZE_G)-1 downto 0);
   signal wrBuffData   : slv(63 downto 0);
   signal rdBuffAddr   : slv((SEGMENT_ADDR_SIZE_G+WINDOW_ADDR_SIZE_G)-1 downto 0);
   signal rdBuffData   : slv(63 downto 0);
   signal rdHeaderAddr : slv(7 downto 0);
   signal rdHeaderData : slv(63 downto 0);
   signal headerRdy    : sl;
   signal headerLength : positive;
   signal txSeqN       : slv(7 downto 0);
   signal headerValues : RssiParamType := RSSI_PARAM_INIT_C;

begin

   -- Flattened application-side SSI input.
   appSsiMaster.valid             <= sAxisTValid;
   appSsiMaster.data(63 downto 0) <= sAxisTData;
   appSsiMaster.data(appSsiMaster.data'high downto 64) <= (others => '0');
   appSsiMaster.strb              <= (others => '1');
   appSsiMaster.keep              <= (others => '0');
   appSsiMaster.keep(7 downto 0)  <= sAxisTKeep;
   appSsiMaster.dest              <= (others => '0');
   appSsiMaster.packed            <= '0';
   appSsiMaster.sof               <= sAxisSof;
   appSsiMaster.eof               <= sAxisTLast;
   appSsiMaster.eofe              <= sAxisEofe;
   sAxisTReady                    <= appSsiSlave.ready;

   -- Flattened transport-side SSI output.
   mAxisTValid <= tspSsiMaster.valid;
   mAxisTData  <= tspSsiMaster.data(63 downto 0);
   mAxisTKeep  <= tspSsiMaster.keep(7 downto 0);
   mAxisTLast  <= tspSsiMaster.eof;
   mAxisSof    <= tspSsiMaster.sof;
   mAxisEofe   <= tspSsiMaster.eofe;

   tspSsiSlave.ready    <= mAxisTReady;
   tspSsiSlave.pause    <= not mAxisTReady;
   tspSsiSlave.overflow <= '0';

   -- Small behavioral RAM for DATA and resend path tests.
   seq : process (axisClk) is
   begin
      if rising_edge(axisClk) then
         if wrBuffWe = '1' then
            mem(to_integer(unsigned(wrBuffAddr))) <= wrBuffData after TPD_G;
         end if;
      end if;
   end process seq;

   rdBuffData <= mem(to_integer(unsigned(rdBuffAddr)));

   -- Header generator wired as it is in RssiCore, with flattened control
   -- values that make standalone ACK/DATA/NULL/RST requests deterministic.
   U_Header : entity surf.RssiHeaderReg
      generic map (
         TPD_G => TPD_G)
      port map (
         clk_i          => axisClk,       -- [in]
         rst_i          => axisRst,       -- [in]
         synHeadSt_i    => synHeadSt_o,   -- [in]
         rstHeadSt_i    => rstHeadSt_o,   -- [in]
         dataHeadSt_i   => dataHeadSt_o,  -- [in]
         nullHeadSt_i   => nullHeadSt_o,  -- [in]
         ackHeadSt_i    => ackHeadSt_o,   -- [in]
         busyHeadSt_i   => localBusy_i,   -- [in]
         ack_i          => txAckFlag_i,   -- [in]
         txSeqN_i       => txSeqN,        -- [in]
         rxAckN_i       => rxAckN_i,      -- [in]
         headerValues_i => headerValues,  -- [in]
         addr_i         => rdHeaderAddr,  -- [in]
         headerData_o   => rdHeaderData,  -- [out]
         ready_o        => headerRdy,     -- [out]
         headerLength_o => headerLength); -- [out]

   -- Real DUT hookup.
   U_DUT : entity surf.RssiTxFsm
      generic map (
         TPD_G               => TPD_G,
         WINDOW_ADDR_SIZE_G  => WINDOW_ADDR_SIZE_G,
         SEGMENT_ADDR_SIZE_G => SEGMENT_ADDR_SIZE_G,
         HEADER_CHKSUM_EN_G  => HEADER_CHKSUM_EN_G)
      port map (
         clk_i          => axisClk,       -- [in]
         rst_i          => axisRst,       -- [in]
         connActive_i   => connActive_i,  -- [in]
         closed_i       => closed_i,      -- [in]
         injectFault_i  => injectFault_i, -- [in]
         sndSyn_i       => sndSyn_i,      -- [in]
         sndAck_i       => sndAck_i,      -- [in]
         sndRst_i       => sndRst_i,      -- [in]
         sndResend_i    => sndResend_i,   -- [in]
         sndNull_i      => sndNull_i,     -- [in]
         windowSize_i   => windowSize_i,  -- [in]
         bufferSize_i   => bufferSize_i,  -- [in]
         wrBuffWe_o     => wrBuffWe,      -- [out]
         wrBuffAddr_o   => wrBuffAddr,    -- [out]
         wrBuffData_o   => wrBuffData,    -- [out]
         rdBuffAddr_o   => rdBuffAddr,    -- [out]
         rdBuffData_i   => rdBuffData,    -- [in]
         rdHeaderAddr_o => rdHeaderAddr,  -- [out]
         rdHeaderData_i => rdHeaderData,  -- [in]
         headerRdy_i    => headerRdy,     -- [in]
         headerLength_i => headerLength,  -- [in]
         chksumValid_i  => chksumValid_i, -- [in]
         chksumEnable_o => chksumEnable_o, -- [out]
         chksumStrobe_o => chksumStrobe_o, -- [out]
         chksum_i       => chksum_i,      -- [in]
         initSeqN_i     => initSeqN_i,    -- [in]
         txSeqN_o       => txSeqN,        -- [out]
         synHeadSt_o    => synHeadSt_o,   -- [out]
         ackHeadSt_o    => ackHeadSt_o,   -- [out]
         dataHeadSt_o   => dataHeadSt_o,  -- [out]
         dataSt_o       => dataSt_o,      -- [out]
         rstHeadSt_o    => rstHeadSt_o,   -- [out]
         nullHeadSt_o   => nullHeadSt_o,  -- [out]
         txTspState_o   => txTspState_o,  -- [out]
         txAppState_o   => txAppState_o,  -- [out]
         txAckState_o   => txAckState_o,  -- [out]
         lastAckN_o     => lastAckN_o,    -- [out]
         ack_i          => ack_i,         -- [in]
         ackN_i         => ackN_i,        -- [in]
         appSsiMaster_i => appSsiMaster,  -- [in]
         appSsiSlave_o  => appSsiSlave,   -- [out]
         tspSsiSlave_i  => tspSsiSlave,   -- [in]
         tspSsiMaster_o => tspSsiMaster,  -- [out]
         lenErr_o       => lenErr_o,      -- [out]
         ackErr_o       => ackErr_o,      -- [out]
         bufferEmpty_o  => bufferEmpty_o); -- [out]

   txSeqN_o <= txSeqN;

end architecture mapping;
