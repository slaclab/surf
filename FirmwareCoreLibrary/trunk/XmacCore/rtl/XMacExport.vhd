-------------------------------------------------------------------------------
-- Title         : 10G MAC / Export
-- Project       : RCE 10G-bit MAC
-------------------------------------------------------------------------------
-- File          : XMacExport.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 02/11/2008
-------------------------------------------------------------------------------
-- Description:
-- PIC Export block for 10G MAC core for the RCE.
-------------------------------------------------------------------------------
-- Copyright (c) 2008 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 02/11/2008: created.
-- 02/23/2008: Fixed error which incorrectly detected short frame if the 
--             data available signal was de-asserted with the last line signal.
-- 02/29/2008: Outgoing data is now dumped when phy is not ready. Byte order
--             is swapped at PIC interface. 
-- 03/31/2008: Fixed errror where status was not generated properly in error
--             situation. 
-- 05/09/2008: Removed header/payload re-alignment. Added automated pause frame
--             reception and transmission.
-- 08/05/2008: Added two clock delay following tx of pause frames.
-- 11/12/2008: Added padding for frames under 64 bytes.
-- 04/22/2014: Adapted for AXI Stream interface.
-------------------------------------------------------------------------------

LIBRARY ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.AxiStreamPkg.all;
use work.StdRtlPkg.all;

entity XMacExport is 
   generic (
      TPD_G         : time                := 1 ns;
      ADDR_WIDTH_G  : integer             := 9;
      VALID_THOLD_G : integer             := 0;
      SHIFT_EN_G    : boolean             := false;
      AXIS_CONFIG_G : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C
   );
   port ( 

      -- PPI Interface   
      dmaClk           : in  sl;
      dmaClkRst        : in  sl;
      dmaObMaster      : in  AxiStreamMasterType;
      dmaObSlave       : out AxiStreamSlaveType;

      -- XAUI Interface
      phyClk           : in  sl;
      phyRst           : in  sl;
      phyTxd           : out slv(63 downto 0);
      phyTxc           : out slv(7  downto 0);
      phyReady         : in  sl;

      -- Pause Interface
      rxPauseReq       : in  sl;
      rxPauseSet       : in  sl;
      rxPauseValue     : in  slv(15 downto 0);

      -- Configuration
      interFrameGap    : in  slv(3  downto 0);
      pauseTime        : in  slv(15 downto 0);
      macAddress       : in  slv(47 downto 0);
      byteSwap         : in  sl;
      txShift          : in  slv(3 downto 0);
      txShiftEn        : in  sl;

      -- Errors
      txCountEn        : out sl;
      txUnderRun       : out sl;
      txLinkNotReady   : out sl
   );
end XMacExport;


-- Define architecture
architecture XMacExport of XMacExport is

   -- Local Signals
   signal intAdvance       : sl;
   signal intDump          : sl;
   signal intRunt          : sl;
   signal intPad           : sl;
   signal intLastLine      : sl;
   signal intLastValidByte : slv(2  downto 0);
   signal frameShift0      : sl;
   signal frameShift1      : sl;
   signal txEnable0        : sl;
   signal txEnable1        : sl;
   signal txEnable2        : sl;
   signal txEnable3        : sl;
   signal nxtMaskIn        : slv(7  downto 0);
   signal nxtEOF           : sl;
   signal intData          : slv(63 downto 0);
   signal stateCount       : slv(3  downto 0);
   signal stateCountRst    : sl;
   signal pausePreCnt      : slv(2  downto 0);
   signal importPauseCnt   : slv(15 downto 0);
   signal exportPauseCnt   : slv(15 downto 0);
   signal exportWordCnt    : slv(3  downto 0);
   signal pauseTx          : sl;
   signal pausePrst        : sl;
   signal pauseLast        : sl;
   signal pauseData        : slv(63 downto 0);
   signal crcFifoIn        : slv(71 downto 0);
   signal crcFifoOut       : slv(71 downto 0);
   signal crcTx            : slv(31 downto 0);
   signal crcIn            : slv(63 downto 0);
   signal crcInit          : sl;
   signal crcMaskIn        : slv(7  downto 0);
   signal crcInAdj         : slv(63 downto 0);
   signal crcDataWidth     : slv(2  downto 0);
   signal crcDataValid     : sl;
   signal crcReset         : sl;
   signal crcOut           : slv(31 downto 0);
   signal sftObMaster      : AxiStreamMasterType;
   signal sftObSlave       : AxiStreamSlaveType;
   signal intObMaster      : AxiStreamMasterType;
   signal intObSlave       : AxiStreamSlaveType;
   signal intError         : sl;
   signal nxtError         : sl;
   signal txShiftEnSync    : sl;

   -- MAC States
   signal   curState    : slv(2 downto 0);
   signal   nxtState    : slv(2 downto 0);
   constant ST_IDLE_C   : slv(2 downto 0) := "000";
   constant ST_DUMP_C   : slv(2 downto 0) := "001";
   constant ST_READ_C   : slv(2 downto 0) := "010";
   constant ST_WAIT_C   : slv(2 downto 0) := "011";
   constant ST_PAUSE_C  : slv(2 downto 0) := "100";
   constant ST_PAD_C    : slv(2 downto 0) := "101";

   -- Debug Signals
   attribute dont_touch : string;

   attribute dont_touch of intAdvance       : signal is "true";
   attribute dont_touch of intDump          : signal is "true";
   attribute dont_touch of intRunt          : signal is "true";
   attribute dont_touch of intPad           : signal is "true";
   attribute dont_touch of intLastLine      : signal is "true";
   attribute dont_touch of intLastValidByte : signal is "true";
   attribute dont_touch of frameShift0      : signal is "true";
   attribute dont_touch of frameShift1      : signal is "true";
   attribute dont_touch of txEnable0        : signal is "true";
   attribute dont_touch of txEnable1        : signal is "true";
   attribute dont_touch of txEnable2        : signal is "true";
   attribute dont_touch of txEnable3        : signal is "true";
   attribute dont_touch of nxtMaskIn        : signal is "true";
   attribute dont_touch of nxtEOF           : signal is "true";
   attribute dont_touch of intData          : signal is "true";
   attribute dont_touch of stateCount       : signal is "true";
   attribute dont_touch of stateCountRst    : signal is "true";
   attribute dont_touch of pausePreCnt      : signal is "true";
   attribute dont_touch of importPauseCnt   : signal is "true";
   attribute dont_touch of exportPauseCnt   : signal is "true";
   attribute dont_touch of exportWordCnt    : signal is "true";
   attribute dont_touch of pauseTx          : signal is "true";
   attribute dont_touch of pausePrst        : signal is "true";
   attribute dont_touch of pauseLast        : signal is "true";
   attribute dont_touch of pauseData        : signal is "true";
   attribute dont_touch of crcFifoIn        : signal is "true";
   attribute dont_touch of crcFifoOut       : signal is "true";
   attribute dont_touch of crcTx            : signal is "true";
   attribute dont_touch of crcIn            : signal is "true";
   attribute dont_touch of crcInit          : signal is "true";
   attribute dont_touch of crcMaskIn        : signal is "true";
   attribute dont_touch of crcInAdj         : signal is "true";
   attribute dont_touch of crcDataWidth     : signal is "true";
   attribute dont_touch of crcDataValid     : signal is "true";
   attribute dont_touch of crcReset         : signal is "true";
   attribute dont_touch of crcOut           : signal is "true";
   attribute dont_touch of intObMaster      : signal is "true";
   attribute dont_touch of intObSlave       : signal is "true";
   attribute dont_touch of intError         : signal is "true";
   attribute dont_touch of nxtError         : signal is "true";

begin

   ------------------------------------------
   -- PPI FIFO
   ------------------------------------------

   -- Shift enable sync
   U_EnSync: entity work.Synchronizer
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => '1',
         OUT_POLARITY_G => '1',
         RST_ASYNC_G    => false,
         STAGES_G       => 4,
         BYPASS_SYNC_G  => false,
         INIT_G         => "0"
      ) port map (
         clk     => dmaClk,
         rst     => dmaClkRst,
         dataIn  => txShiftEn,
         dataOut => txShiftEnSync
      );

   U_ShiftEnGen: if SHIFT_EN_G = true generate

      -- Shift outbound data 2 bytes to the right.
      -- This removes two bytes of data at start 
      -- of the packet. These were added by software
      -- to create a software friendly alignment of 
      -- outbound data.
      U_FrameShift : entity work.AxiStreamShift
         generic map (
            TPD_G         => TPD_G,
            AXIS_CONFIG_G => AXIS_CONFIG_G
         ) port map (
            axisClk     => dmaClk,
            axisRst     => dmaClkRst,
            axiStart    => txShiftEnSync,
            axiShiftDir => '1', -- 1 = right (msb to lsb)
            axiShiftCnt => txShift,
            sAxisMaster => dmaObMaster,
            sAxisSlave  => dmaObSlave,
            mAxisMaster => sftObMaster,
            mAxisSlave  => sftObSlave
         );
   end generate;

   U_ShiftDisGen: if SHIFT_EN_G = false generate
      sftObMaster <= dmaObMaster;
      dmaObSlave  <= sftObSlave;
   end generate;

   -- PPI FIFO
   U_InFifo : entity work.AxiStreamFifo 
      generic map (
         TPD_G                => TPD_G,
         INT_PIPE_STAGES_G    => 0,
         PIPE_STAGES_G        => 0,
         SLAVE_READY_EN_G     => true,
         VALID_THOLD_G        => VALID_THOLD_G,
         BRAM_EN_G            => true,
         XIL_DEVICE_G         => "7SERIES",
         USE_BUILT_IN_G       => false,
         GEN_SYNC_FIFO_G      => false,
         CASCADE_SIZE_G       => 1,
         FIFO_ADDR_WIDTH_G    => ADDR_WIDTH_G,
         FIFO_FIXED_THRESH_G  => true,
         FIFO_PAUSE_THRESH_G  => 500,
         SLAVE_AXI_CONFIG_G   => AXIS_CONFIG_G,
         MASTER_AXI_CONFIG_G  => AXIS_CONFIG_G 
      ) port map (
         sAxisClk        => dmaClk,
         sAxisRst        => dmaClkRst,
         sAxisMaster     => sftObMaster,
         sAxisSlave      => sftObSlave,
         sAxisCtrl       => open,
         mAxisClk        => phyClk,
         mAxisRst        => phyRst,
         mAxisMaster     => intObMaster,
         mAxisSlave      => intObSlave
      );


   ------------------------------------------
   -- MAC Logic
   ------------------------------------------

   -- Generate read
   intObSlave.tReady <= (intAdvance and (not intPad)) or intDump;

   -- Re-Order Bytes
   process ( intObMaster, byteSwap ) begin
      if byteSwap = '1' then
         intData(63 downto 56) <= intObMaster.tData(39 downto 32);
         intData(55 downto 48) <= intObMaster.tData(47 downto 40);
         intData(47 downto 40) <= intObMaster.tData(55 downto 48);
         intData(39 downto 32) <= intObMaster.tData(63 downto 56);
         intData(31 downto 24) <= intObMaster.tData(7  downto  0);
         intData(23 downto 16) <= intObMaster.tData(15 downto  8);
         intData(15 downto  8) <= intObMaster.tData(23 downto 16);
         intData(7  downto  0) <= intObMaster.tData(31 downto 24);
      else
         intData <= intObmaster.tData(63 downto 0);
      end if;
   end process;

   -- State machine logic
   process ( phyClk ) begin
      if rising_edge(phyClk) then
         if phyRst = '1' then
            curState        <= ST_IDLE_C     after TPD_G;
            intError        <= '0'           after TPD_G;
            stateCount      <= (others=>'0') after TPD_G;
            exportWordCnt   <= (others=>'0') after TPD_G;
         else

            -- State transition
            curState <= nxtState after TPD_G;
            intError <= nxtError after TPD_G;

            -- Inter frame gap
            if stateCountRst = '1' then
              stateCount <= (others=>'0');
            else
              stateCount <= stateCount + 1;
            end if;

            if stateCountRst = '1' then
              exportWordCnt <= (others=>'0');
            elsif intAdvance = '1' and intRunt = '1' then
              exportWordCnt <= exportWordCnt + 1;
            end if;
            
         end if;
      end if;
   end process;

   -- Pad runt frames
   intRunt          <= not exportWordCnt(3);
   intLastValidByte <= "111" when curState=ST_PAD_C else onesCount(intObMaster.tKeep(7 downto 1));
   
   -- State machine
   process (curState, intObMaster, intError, phyReady, phyRst, stateCount, 
            rxPauseReq, importPauseCnt, exportPauseCnt, interFrameGap, intRunt ) begin

      -- Init
      txCountEn      <= '0';
      txUnderRun     <= '0';
      txLinkNotReady <= '0';
      nxtError       <= intError;
      crcInit        <= '0';

      case curState is 

         -- IDLE, wait for data to be available
         when ST_IDLE_C =>
            pauseTx       <= '0';
            pauseLast     <= '0';
            stateCountRst <= '1';
            intPad        <= '0';
            intAdvance    <= '0';
            intLastLine   <= '0';
            nxtError      <= '0';
            intDump       <= '0';
            crcInit       <= '1';
            
            -- Pause frame is required
            if rxPauseReq = '1' and importPauseCnt = 0 then
               pausePrst  <= '1';
               nxtState   <= ST_PAUSE_C;

            -- Wait for start flag, export pause count must be zero
            elsif intObMaster.tValid = '1' and phyRst = '0' and exportPauseCnt = 0 then
               pausePrst  <= '0';

               -- Phy is ready
               if phyReady = '1' then
                  nxtState <= ST_READ_C;

               -- Phy is not ready dump data
               else
                  nxtState       <= ST_DUMP_C;
                  txLinkNotReady <= '1';
               end if;
            else
               pausePrst  <= '0';
               nxtState   <= curState;
            end if;

         -- Transmit Pause Frame
         when ST_PAUSE_C =>
            pauseTx     <= '1';
            intAdvance  <= '0';   
            intDump     <= '0';   
            pausePrst   <= '0';
            intPad      <= '0';
            intLastLine <= '0';
            
            -- Pause Frame Is Finished
            if stateCount = 7 then
               stateCountRst <= '1';
               pauseLast     <= '1';
               nxtState      <= ST_WAIT_C;
            else
               stateCountRst <= '0';
               pauseLast     <= '0';
               nxtState      <= curState;
            end if;

         -- Reading from PIC
         when ST_READ_C =>
            intDump       <= '0';
            pauseTx       <= '0';
            pauseLast     <= '0';
            stateCountRst <= '0';
            pausePrst     <= '0';
            intLastLine   <= '0';
            intPad        <= '0';
            intAdvance    <= '1';
            nxtState      <= curState;

            -- Read until we get last
            if intObMaster.tLast = '1' and intRunt = '1' then
               nxtState   <= ST_PAD_C;
               txCountEn  <= '1';

            elsif intObMaster.tLast ='1' and intRunt = '0' then
               intLastLine   <= '1';
               nxtState      <= ST_WAIT_C;
               txCountEn     <= '1';
               stateCountRst <= '1';

            -- Detect underflow
            elsif intObMaster.tValid = '0' then
               txUnderRun <= '1';
               nxtError   <= '1';
               intAdvance <= '0';

            -- Keep reading
            else
               intAdvance <= '1';
            end if;

         -- Reading from PIC, Dumping data
         when ST_DUMP_C =>
            intAdvance    <= '0';
            pauseTx       <= '0';
            pauseLast     <= '0';
            stateCountRst <= '0';
            pausePrst     <= '0';
            intPad        <= '0';
            
            -- Read until we get last
            if intObMaster.tLast = '1' then
               intDump       <= '0';
               intLastLine   <= '1';
               nxtState      <= ST_WAIT_C;
               stateCountRst <= '1';

            -- Keep reading
            else
               intDump     <= intObMaster.tValid;
               intLastLine <= '0';
               nxtState    <= curState;
            end if;

         -- Wait for inter-frame gap
         when ST_WAIT_C =>
            intDump       <= '0';
            intAdvance    <= '0';
            pauseTx       <= '0';
            pauseLast     <= '0';
            stateCountRst <= '0';
            pausePrst     <= '0';
            intPad        <= '0';
            intLastLine   <= '0';
            
            -- Wait for gap, min 3 clocks
            if stateCount >= interFrameGap and stateCount >= 3 then
               nxtState <= ST_IDLE_C;
            else
               nxtState <= curState;
            end if;

         -- Padding frame
         when ST_PAD_C =>
            intDump       <= '0';
            pauseTx       <= '0';
            pauseLast     <= '0';
            stateCountRst <= '0';
            pausePrst     <= '0';
            intAdvance    <= '1';
            intPad        <= '1';

            if intRunt = '1' then
               intLastLine<= '0';
               nxtState   <= curState;
            else
               intLastLine   <= '1';
               nxtState      <= ST_WAIT_C;
               stateCountRst <= '1';
            end if;

        when others =>
            nxtState      <= ST_IDLE_C;
            intAdvance    <= '0';
            intDump       <= '0';
            pauseTx       <= '0';
            pauseLast     <= '0';
            stateCountRst <= '0';
            pausePrst     <= '0';
            intPad        <= '0';
            intLastLine   <= '0';
      end case;
   end process;


   -- Format data for input into CRC delay FIFO.
   process ( phyClk ) begin
      if rising_edge(phyClk) then
         if phyRst = '1' then
            frameShift0    <= '0'           after TPD_G;
            frameShift1    <= '0'           after TPD_G;
            txEnable0      <= '0'           after TPD_G;
            txEnable1      <= '0'           after TPD_G;
            txEnable2      <= '0'           after TPD_G;
            txEnable3      <= '0'           after TPD_G;
            crcDataWidth   <= (others=>'0') after TPD_G;
            crcMaskIn      <= (others=>'0') after TPD_G;
            nxtMaskIn      <= (others=>'0') after TPD_G;
            crcIn          <= (others=>'0') after TPD_G;
            crcDataValid   <= '0'           after TPD_G;
         else 

            -- Shift register to track frame state
            frameShift0 <= intAdvance  or pauseTx after TPD_G;
            frameShift1 <= frameShift0            after TPD_G;

            -- Input to transmit enable shift register. 
            -- Asserted with frameShift0
            if (intAdvance = '1' or pauseTx = '1') and frameShift0 = '0' then
               txEnable0 <= '1' after TPD_G;

            -- De-assert following frame shift0, 
            -- keep one extra clock if nxtMask contains a non-zero value.
            elsif frameShift0 = '0' and nxtMaskIn = x"00" then
               txEnable0 <= '0' after TPD_G;
            end if;

            -- Transmit enable shift register
            txEnable1 <= txEnable0 after TPD_G;
            txEnable2 <= txEnable1 after TPD_G;
            txEnable3 <= txEnable2 after TPD_G;

            -- CRC Valid
            crcDataValid <= intAdvance or pauseTx after TPD_G;

            -- CRC Input
            if pauseTx = '1' then
               crcIn <= pauseData after TPD_G;
            else
               crcIn <= intData after TPD_G;
            end if;

            -- Last line
            if intLastLine = '1' and pauseTx = '0' then
               crcDataWidth <= intLastValidByte after TPD_G;
            else
               crcDataWidth <= "111" after TPD_G;
            end if;

            -- Generate CRC Mask Value for CRC append after delay buffer.
            -- depends on number of bytes in last transfer
            if pauseLast = '1' then
               crcMaskIn <= x"00" after TPD_G;
               nxtMaskIn <= x"0F" after TPD_G;
            elsif intLastLine = '1' and frameShift0 = '1' and pauseTx = '0' then
               if intError = '1' then -- Corrupt CRC
                  crcMaskIn <= x"FF" after TPD_G;
                  nxtMaskIn <= x"00" after TPD_G;
               else
                  case intLastValidByte is
                     when "000"  => crcMaskIn <= x"1E" after TPD_G; nxtMaskIn <= x"00" after TPD_G;
                     when "001"  => crcMaskIn <= x"3C" after TPD_G; nxtMaskIn <= x"00" after TPD_G;
                     when "010"  => crcMaskIn <= x"78" after TPD_G; nxtMaskIn <= x"00" after TPD_G;
                     when "011"  => crcMaskIn <= x"F0" after TPD_G; nxtMaskIn <= x"00" after TPD_G;
                     when "100"  => crcMaskIn <= x"E0" after TPD_G; nxtMaskIn <= x"01" after TPD_G;
                     when "101"  => crcMaskIn <= x"C0" after TPD_G; nxtMaskIn <= x"03" after TPD_G;
                     when "110"  => crcMaskIn <= x"80" after TPD_G; nxtMaskIn <= x"07" after TPD_G;
                     when "111"  => crcMaskIn <= x"00" after TPD_G; nxtMaskIn <= x"0F" after TPD_G;
                     when others => crcMaskIn <= x"00" after TPD_G; nxtMaskIn <= x"00" after TPD_G;
                  end case;
               end if;
            else
               crcMaskIn <= nxtMaskIn     after TPD_G;
               nxtMaskIn <= (others=>'0') after TPD_G;
            end if;
         end if;
      end if;
   end process;

   -- Select CRC FIFO Data
   crcFifoIn(71 downto 64) <= crcMaskIn;
   crcFifoIn(63 downto  0) <= crcIn;

   -- CRC Delay FIFO
   U_CrcFifo: entity work.Fifo
      generic map (
         TPD_G              => TPD_G,
         RST_POLARITY_G     => '1',
         RST_ASYNC_G        => false,
         GEN_SYNC_FIFO_G    => true,
         BRAM_EN_G          => false,
         FWFT_EN_G          => false,
         USE_DSP48_G        => "no",
         USE_BUILT_IN_G     => false,
         XIL_DEVICE_G       => "7SERIES",
         SYNC_STAGES_G      => 3,
         DATA_WIDTH_G       => 72,
         ADDR_WIDTH_G       => 4,
         INIT_G             => "0",
         FULL_THRES_G       => 1,
         EMPTY_THRES_G      => 1
      ) port map (
         rst           => phyRst,
         wr_clk        => phyClk,
         wr_en         => txEnable0,
         din           => crcFifoIn,
         wr_data_count => open,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         full          => open,
         not_full      => open,
         rd_clk        => phyClk,
         rd_en         => txEnable2,
         dout          => crcFifoOut,
         rd_data_count => open,
         valid         => open,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open
      );


   -- Output Stage to PHY
   process ( phyClk ) begin
      if rising_edge(phyClk) then
         if phyRst = '1' then
            phyTxd  <= (others=>'0') after TPD_G;
            phyTxc  <= (others=>'0') after TPD_G;
            nxtEOF  <= '0'           after TPD_G;
         else

            -- EOF Charactor Required If CRC was in last word and there was
            -- not enough space for EOF
            if nxtEOF = '1' then
               phyTxd <= X"07070707070707FD" after TPD_G;
               phyTxc <= x"FF"               after TPD_G;
               nxtEOF <= '0'                 after TPD_G;

            -- Not transmitting
            elsif txEnable2 = '0' and txEnable3 = '0' then 
               phyTxd  <= X"0707070707070707" after TPD_G;
               phyTxc  <= x"FF"               after TPD_G;

            -- Pre-amble word
            elsif txEnable2 = '1' and txEnable3 = '0' then
               phyTxd  <= X"D5555555555555FB" after TPD_G;
               phyTxc  <= x"01"               after TPD_G;

            -- Normal data or CRC data. Select CRC / data combination
            else
               case crcFifoOut(71 downto 64) is -- CRC MASK
                  when x"00" => 
                     phyTxd <= crcFifoOut(63 downto 0)               after TPD_G;
                     phyTxc <= x"00"                                 after TPD_G;
                  when x"80" => 
                     phyTxd(63 downto 56) <= crcTx(7  downto 0)      after TPD_G;
                     phyTxd(55 downto  0) <= crcFifoOut(55 downto 0) after TPD_G;
                     phyTxc               <= x"00"                   after TPD_G;
                  when x"07" => 
                     phyTxd(63 downto 24) <= x"07070707FD"           after TPD_G;
                     phyTxd(23 downto  0) <= crcTx(31 downto 8)      after TPD_G;
                     phyTxc               <= x"F8"                   after TPD_G;
                  when x"0F" => 
                     phyTxd(63 downto 32) <= x"070707FD"             after TPD_G;
                     phyTxd(31 downto  0) <= crcTx                   after TPD_G;
                     phyTxc               <= x"F0"                   after TPD_G;
                  when x"1E" => 
                     phyTxd(63 downto 40) <= x"0707FD"               after TPD_G;
                     phyTxd(39 downto  8) <= crcTx                   after TPD_G;
                     phyTxd(7  downto  0) <= crcFifoOut(7 downto 0)  after TPD_G;
                     phyTxc               <= x"E0"                   after TPD_G;
                  when x"3C" => 
                     phyTxd(63 downto 48) <= x"07FD"                 after TPD_G;
                     phyTxd(47 downto 16) <= crcTx                   after TPD_G;
                     phyTxd(15 downto  0) <= crcFifoOut(15 downto 0) after TPD_G;
                     phyTxc               <= x"C0"                   after TPD_G;
                  when x"78" => 
                     phyTxd(63 downto 56) <= x"FD"                   after TPD_G;
                     phyTxd(55 downto 24) <= crcTx                   after TPD_G;
                     phyTxd(23 downto  0) <= crcFifoOut(23 downto 0) after TPD_G;
                     phyTxc               <= x"80"                   after TPD_G;
                  when x"F0" => 
                     phyTxd(63 downto 32) <= crcTx                   after TPD_G;
                     phyTxd(31 downto  0) <= crcFifoOut(31 downto 0) after TPD_G;
                     phyTxc               <= x"00"                   after TPD_G;
                     nxtEOF               <= '1'                     after TPD_G;
                  when x"E0" => 
                     phyTxd(63 downto 40) <= crcTx(23 downto 0)      after TPD_G;
                     phyTxd(39 downto  0) <= crcFifoOut(39 downto 0) after TPD_G;
                     phyTxc               <= x"00"                   after TPD_G;
                  when x"01" => 
                     phyTxd(63 downto  8) <= x"070707070707FD"       after TPD_G;
                     phyTxd(7  downto  0) <= crcTx(31 downto 24)     after TPD_G;
                     phyTxc               <= x"FE"                   after TPD_G;
                  when x"C0" => 
                     phyTxd(63 downto 48) <= crcTx(15 downto 0)      after TPD_G;
                     phyTxd(47 downto  0) <= crcFifoOut(47 downto 0) after TPD_G;
                     phyTxc               <= x"00"                   after TPD_G;
                  when x"03" => 
                     phyTxd(63 downto 16) <= x"0707070707FD"         after TPD_G;
                     phyTxd(15 downto  0) <= crcTx(31 downto 16)     after TPD_G;
                     phyTxc               <= x"FC"                   after TPD_G;
                  when x"FF" => 
                     phyTxd(63 downto 32) <= x"070707FD"             after TPD_G;
                     phyTxd(31 downto  0) <= not crcTx               after TPD_G;
                     phyTxc               <= x"F0"                   after TPD_G;
                  when others => 
                     phyTxd <= x"0707070707070707"                   after TPD_G;
                     phyTxc <= x"FF"                                 after TPD_G;
               end case;
            end if;
         end if;
      end if;
   end process;


   ------------------------------------------
   -- Pause frame generation
   ------------------------------------------

   -- Pause Counters & Frame Generation
   with stateCount select
     pauseData <=
       -- Preamble
       --(others => '0') when "0000", 
       -- Src Id, Upper 2 Bytes + Dest Id, All 6 bytes
       (macAddress(39 downto 32) & macAddress(47 downto 40) & x"010000C28001") when "0000",
       -- Pause Opcode + Length/Type Field + Src Id, Lower 4 bytes
       (x"0100" & x"0888" & macAddress( 7 downto 0) &
                            macAddress(15 downto  8) &
                            macAddress(23 downto 16) &
                            macAddress(31 downto 24)) when "0001",
       -- Pause length
       (x"000000000000" & pauseTime( 7 downto 0) & pauseTime(15 downto 8)) when "0010",
       (others=>'0') when others;


   -- Counters for pause tracking
   process ( phyClk ) begin
      if rising_edge(phyClk) then
         if phyRst = '1' then
            pausePreCnt    <= (others=>'0') after TPD_G;
            importPauseCnt <= (others=>'0') after TPD_G;
            exportPauseCnt <= (others=>'0') after TPD_G;
         else

            -- Pre-counter, 8 125Mhz clocks ~= 512 bit times of 10G
            pausePreCnt <= pausePreCnt + 1 after TPD_G;

            -- Import Pause Counter, preset with transmitted pause value
            -- Decrement at end of pause tx. This ensures local count will
            -- expire in time to send a new pause frame to remote end before it expires
            if pausePrst = '1' then
               importPauseCnt <= pauseTime after TPD_G;
            elsif (pausePreCnt = 0 or pauseLast = '1') and importPauseCnt /= 0 then
               importPauseCnt <= importPauseCnt - 1 after TPD_G;
            end if;

            -- Export Pause Counter, preset with received pause value
            if rxPauseSet = '1' then
               exportPauseCnt <= rxPauseValue after TPD_G;
            elsif pausePreCnt = 0 and exportPauseCnt /= 0 then
               exportPauseCnt <= exportPauseCnt - 1 after TPD_G;
            end if;
         end if;
      end if;
   end process;


   ------------------------------------------
   -- CRC Logic
   ------------------------------------------

   -- CRC Input
   crcReset               <= crcInit or phyRst or (not phyReady);
   crcInAdj(63 downto 56) <= crcIn(7  downto  0);
   crcInAdj(55 downto 48) <= crcIn(15 downto  8);
   crcInAdj(47 downto 40) <= crcIn(23 downto 16);
   crcInAdj(39 downto 32) <= crcIn(31 downto 24);
   crcInAdj(31 downto 24) <= crcIn(39 downto 32);
   crcInAdj(23 downto 16) <= crcIn(47 downto 40);
   crcInAdj(15 downto  8) <= crcIn(55 downto 48);
   crcInAdj(7  downto  0) <= crcIn(63 downto 56);

   -- CRC
   U_Crc32 : entity work.Crc32Parallel
      generic map (
         BYTE_WIDTH_G => 8
      ) port map (
         crcOut        => crcOut,
         crcClk        => phyClk,
         crcDataValid  => crcDataValid,
         crcDataWidth  => crcDataWidth,
         crcIn         => crcInAdj,
         crcReset      => crcReset
      ); 

   -- CRC for transmission
   crcTx(31 downto 24) <= crcOut(7  downto  0);
   crcTx(23 downto 16) <= crcOut(15 downto  8);
   crcTx(15 downto  8) <= crcOut(23 downto 16);
   crcTx(7  downto  0) <= crcOut(31 downto 24);

end XMacExport;

