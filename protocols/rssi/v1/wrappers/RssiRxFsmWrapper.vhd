-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for RSSI receive FSM tests
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

entity RssiRxFsmWrapper is
   generic (
      TPD_G               : time     := 1 ns;
      WINDOW_ADDR_SIZE_G  : positive := 3;
      HEADER_CHKSUM_EN_G  : boolean  := true;
      SEGMENT_ADDR_SIZE_G : positive := 2
   );
   port (
      clk_i : in sl;
      rst_i : in sl;

      connActive_i   : in sl;
      rxWindowSize_i : in integer range 1 to 2 ** (WINDOW_ADDR_SIZE_G);
      rxBufferSize_i : in integer range 1 to 2 ** (SEGMENT_ADDR_SIZE_G);
      txWindowSize_i : in integer range 1 to 2 ** (WINDOW_ADDR_SIZE_G);
      lastAckN_i     : in slv(7 downto 0);

      tspTValid_i : in  sl;
      tspTReady_o : out sl;
      tspTData_i  : in  slv(63 downto 0);
      tspTKeep_i  : in  slv(7 downto 0);
      tspTLast_i  : in  sl;
      tspSof_i    : in  sl;
      tspEofe_i   : in  sl;

      appTValid_o : out sl;
      appTReady_i : in  sl;
      appTData_o  : out slv(63 downto 0);
      appTKeep_o  : out slv(7 downto 0);
      appTLast_o  : out sl;
      appSof_o    : out sl;
      appEofe_o   : out sl;

      chksumValid_i : in sl;
      chksumOk_i    : in sl;

      rxSeqN_o        : out slv(7 downto 0);
      rxAckN_o        : out slv(7 downto 0);
      rxLastSeqN_o    : out slv(7 downto 0);
      rxValidSeg_o    : out sl;
      rxDropSeg_o     : out sl;
      rxFlagSyn_o     : out sl;
      rxFlagAck_o     : out sl;
      rxFlagRst_o     : out sl;
      rxFlagNull_o    : out sl;
      rxFlagData_o    : out sl;
      rxFlagBusy_o    : out sl;
      chksumEnable_o  : out sl;
      chksumStrobe_o  : out sl;
      chksumLength_o  : out positive;
      rxTspState_o    : out slv(3 downto 0);
      rxAppState_o    : out slv(3 downto 0);
      paramVersion_o  : out slv(3 downto 0);
      paramChksumEn_o : out slv(0 downto 0);
      paramConnId_o   : out slv(31 downto 0)
   );
end entity RssiRxFsmWrapper;

architecture mapping of RssiRxFsmWrapper is

   subtype MemoryAddrType is natural range 0 to 2 ** (WINDOW_ADDR_SIZE_G+SEGMENT_ADDR_SIZE_G)-1;
   type MemoryType is array (MemoryAddrType) of slv(63 downto 0);

   signal mem : MemoryType := (others => (others => '0'));

   signal tspSsiMaster : SsiMasterType;
   signal tspSsiSlave  : SsiSlaveType;
   signal appSsiMaster : SsiMasterType;
   signal appSsiSlave  : SsiSlaveType;
   signal rxFlags      : flagsType;
   signal rxParam      : RssiParamType;
   signal wrBuffWe     : sl;
   signal wrBuffAddr   : slv((SEGMENT_ADDR_SIZE_G+WINDOW_ADDR_SIZE_G)-1 downto 0);
   signal wrBuffData   : slv(63 downto 0);
   signal rdBuffAddr   : slv((SEGMENT_ADDR_SIZE_G+WINDOW_ADDR_SIZE_G)-1 downto 0);
   signal rdBuffData   : slv(63 downto 0);

begin

   -- Flattened transport-side SSI input.
   tspSsiMaster.valid             <= tspTValid_i;
   tspSsiMaster.data(63 downto 0) <= tspTData_i;
   tspSsiMaster.data(tspSsiMaster.data'high downto 64) <= (others => '0');
   tspSsiMaster.strb              <= (others => '1');
   tspSsiMaster.keep              <= (others => '0');
   tspSsiMaster.keep(7 downto 0)  <= tspTKeep_i;
   tspSsiMaster.dest              <= (others => '0');
   tspSsiMaster.packed            <= '0';
   tspSsiMaster.sof               <= tspSof_i;
   tspSsiMaster.eof               <= tspTLast_i;
   tspSsiMaster.eofe              <= tspEofe_i;
   tspTReady_o                    <= tspSsiSlave.ready;

   -- Flattened application-side SSI output.
   appTValid_o <= appSsiMaster.valid;
   appTData_o  <= appSsiMaster.data(63 downto 0);
   appTKeep_o  <= appSsiMaster.keep(7 downto 0);
   appTLast_o  <= appSsiMaster.eof;
   appSof_o    <= appSsiMaster.sof;
   appEofe_o   <= appSsiMaster.eofe;

   appSsiSlave.ready    <= appTReady_i;
   appSsiSlave.pause    <= not appTReady_i;
   appSsiSlave.overflow <= '0';

   -- Small behavioral RAM that represents the segment buffer attached to
   -- `RssiRxFsm` in `RssiCore`.  Writes remain clocked, while the read side is
   -- asynchronous so the wrapper tests RX FSM behavior without adding another
   -- registered RAM latency to the application stream.
   seq : process (clk_i) is
   begin
      if rising_edge(clk_i) then
         if wrBuffWe = '1' then
            mem(to_integer(unsigned(wrBuffAddr))) <= wrBuffData after TPD_G;
         end if;
      end if;
   end process seq;

   rdBuffData <= mem(to_integer(unsigned(rdBuffAddr)));

   -- Real DUT hookup.
   U_DUT : entity surf.RssiRxFsm
      generic map (
         TPD_G               => TPD_G,
         WINDOW_ADDR_SIZE_G  => WINDOW_ADDR_SIZE_G,
         HEADER_CHKSUM_EN_G  => HEADER_CHKSUM_EN_G,
         SEGMENT_ADDR_SIZE_G => SEGMENT_ADDR_SIZE_G)
      port map (
         clk_i          => clk_i,        -- [in]
         rst_i          => rst_i,        -- [in]
         connActive_i   => connActive_i, -- [in]
         rxWindowSize_i => rxWindowSize_i, -- [in]
         rxBufferSize_i => rxBufferSize_i, -- [in]
         txWindowSize_i => txWindowSize_i, -- [in]
         lastAckN_i     => lastAckN_i,   -- [in]
         rxSeqN_o       => rxSeqN_o,     -- [out]
         rxAckN_o       => rxAckN_o,     -- [out]
         rxLastSeqN_o   => rxLastSeqN_o, -- [out]
         rxValidSeg_o   => rxValidSeg_o, -- [out]
         rxDropSeg_o    => rxDropSeg_o,  -- [out]
         rxFlags_o      => rxFlags,      -- [out]
         rxParam_o      => rxParam,      -- [out]
         rxTspState_o   => rxTspState_o, -- [out]
         rxAppState_o   => rxAppState_o, -- [out]
         chksumValid_i  => chksumValid_i, -- [in]
         chksumOk_i     => chksumOk_i,   -- [in]
         chksumEnable_o => chksumEnable_o, -- [out]
         chksumStrobe_o => chksumStrobe_o, -- [out]
         chksumLength_o => chksumLength_o, -- [out]
         wrBuffWe_o     => wrBuffWe,     -- [out]
         wrBuffAddr_o   => wrBuffAddr,   -- [out]
         wrBuffData_o   => wrBuffData,   -- [out]
         rdBuffAddr_o   => rdBuffAddr,   -- [out]
         rdBuffData_i   => rdBuffData,   -- [in]
         tspSsiMaster_i => tspSsiMaster, -- [in]
         tspSsiSlave_o  => tspSsiSlave,  -- [out]
         appSsiMaster_o => appSsiMaster, -- [out]
         appSsiSlave_i  => appSsiSlave); -- [in]

   rxFlagSyn_o     <= rxFlags.syn;
   rxFlagAck_o     <= rxFlags.ack;
   rxFlagRst_o     <= rxFlags.rst;
   rxFlagNull_o    <= rxFlags.nul;
   rxFlagData_o    <= rxFlags.data;
   rxFlagBusy_o    <= rxFlags.busy;
   paramVersion_o  <= rxParam.version;
   paramChksumEn_o <= rxParam.chksumEn;
   paramConnId_o   <= rxParam.connectionId;

end architecture mapping;
