-------------------------------------------------------------------------------
-- File       : EthMacTxExportXgmii.vhd
-- Author     : Ryan Herbst <rherbst@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2008-02-11
-- Last update: 2016-10-06
-------------------------------------------------------------------------------
-- Description: 10GbE Export MAC core with GMII interface
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.AxiStreamPkg.all;
use work.StdRtlPkg.all;
use work.EthMacPkg.all;

entity EthMacTxExportXgmii is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Clock and Reset
      ethClk         : in  sl;
      ethRst         : in  sl;
      -- AXIS Interface   
      macObMaster    : in  AxiStreamMasterType;
      macObSlave     : out AxiStreamSlaveType;
      -- XAUI Interface
      phyTxd         : out slv(63 downto 0);
      phyTxc         : out slv(7 downto 0);
      phyReady       : in  sl;
      -- Configuration
      macAddress     : in  slv(47 downto 0);
      -- Errors
      txCountEn      : out sl;
      txUnderRun     : out sl;
      txLinkNotReady : out sl);
end EthMacTxExportXgmii;

architecture rtl of EthMacTxExportXgmii is

   constant INTERGAP_C : slv(3 downto 0) := x"3";

   constant AXI_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => EMAC_AXIS_CONFIG_C.TSTRB_EN_C,
      TDATA_BYTES_C => 8,               -- 64-bit AXI stream interface
      TDEST_BITS_C  => EMAC_AXIS_CONFIG_C.TDEST_BITS_C,
      TID_BITS_C    => EMAC_AXIS_CONFIG_C.TID_BITS_C,
      TKEEP_MODE_C  => EMAC_AXIS_CONFIG_C.TKEEP_MODE_C,
      TUSER_BITS_C  => EMAC_AXIS_CONFIG_C.TUSER_BITS_C,
      TUSER_MODE_C  => EMAC_AXIS_CONFIG_C.TUSER_MODE_C);   

   -- Local Signals
   signal macMaster        : AxiStreamMasterType;
   signal macSlave         : AxiStreamSlaveType;
   signal intAdvance       : sl;
   signal intDump          : sl;
   signal intRunt          : sl;
   signal intPad           : sl;
   signal intLastLine      : sl;
   signal intLastValidByte : slv(2 downto 0);
   signal frameShift0      : sl;
   signal frameShift1      : sl;
   signal txEnable0        : sl;
   signal txEnable1        : sl;
   signal txEnable2        : sl;
   signal txEnable3        : sl;
   signal nxtMaskIn        : slv(7 downto 0);
   signal nxtEOF           : sl;
   signal intData          : slv(63 downto 0);
   signal stateCount       : slv(3 downto 0);
   signal stateCountRst    : sl;
   signal exportWordCnt    : slv(3 downto 0);
   signal crcFifoIn        : slv(71 downto 0);
   signal crcFifoOut       : slv(71 downto 0);
   signal crcTx            : slv(31 downto 0);
   signal crcIn            : slv(63 downto 0);
   signal crcInit          : sl;
   signal crcMaskIn        : slv(7 downto 0);
   signal crcInAdj         : slv(63 downto 0);
   signal crcDataWidth     : slv(2 downto 0);
   signal crcDataValid     : sl;
   signal crcReset         : sl;
   signal crcOut           : slv(31 downto 0);
   signal intError         : sl;
   signal nxtError         : sl;

   -- MAC States
   signal curState    : slv(2 downto 0);
   signal nxtState    : slv(2 downto 0);
   constant ST_IDLE_C : slv(2 downto 0) := "000";
   constant ST_DUMP_C : slv(2 downto 0) := "001";
   constant ST_READ_C : slv(2 downto 0) := "010";
   constant ST_WAIT_C : slv(2 downto 0) := "011";
   constant ST_PAD_C  : slv(2 downto 0) := "100";

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
   attribute dont_touch of exportWordCnt    : signal is "true";
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
   attribute dont_touch of intError         : signal is "true";
   attribute dont_touch of nxtError         : signal is "true";

begin

   DATA_MUX : entity work.AxiStreamFifo
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         INT_PIPE_STAGES_G   => 0,
         PIPE_STAGES_G       => 1,
         SLAVE_READY_EN_G    => true,
         VALID_THOLD_G       => 1,
         -- FIFO configurations
         BRAM_EN_G           => false,
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => true,
         CASCADE_SIZE_G      => 1,
         FIFO_ADDR_WIDTH_G   => 4,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => EMAC_AXIS_CONFIG_C,  -- 128-bit AXI stream interface  
         MASTER_AXI_CONFIG_G => AXI_CONFIG_C)        -- 64-bit AXI stream interface          
      port map (
         -- Slave Port
         sAxisClk    => ethClk,
         sAxisRst    => ethRst,
         sAxisMaster => macObMaster,                 -- 128-bit AXI stream interface 
         sAxisSlave  => macObSlave,
         -- Master Port
         mAxisClk    => ethClk,
         mAxisRst    => ethRst,
         mAxisMaster => macMaster,                   -- 64-bit AXI stream interface 
         mAxisSlave  => macSlave);  

   -- Generate read
   macSlave.tReady <= (intAdvance and (not intPad)) or intDump;

   -- Data processing
   process (intPad, macMaster)
   begin
      for i in 0 to 7 loop
         if intPad = '1' or macMaster.tKeep(i) = '0' then
            intData(i*8+7 downto i*8) <= (others => '0');
         else
            intData(i*8+7 downto i*8) <= macMaster.tData(i*8+7 downto i*8);
         end if;
      end loop;
   end process;

   -- State machine logic
   process (ethClk)
   begin
      if rising_edge(ethClk) then
         if ethRst = '1' then
            curState      <= ST_IDLE_C       after TPD_G;
            intError      <= '0'             after TPD_G;
            stateCount    <= (others => '0') after TPD_G;
            exportWordCnt <= (others => '0') after TPD_G;
         else

            -- State transition
            curState <= nxtState after TPD_G;
            intError <= nxtError after TPD_G;

            -- Inter frame gap
            if stateCountRst = '1' then
               stateCount <= (others => '0');
            else
               stateCount <= stateCount + 1;
            end if;

            if stateCountRst = '1' then
               exportWordCnt <= (others => '0');
            elsif intAdvance = '1' and intRunt = '1' then
               exportWordCnt <= exportWordCnt + 1;
            end if;
            
         end if;
      end if;
   end process;

   -- Pad runt frames
   intRunt          <= not exportWordCnt(3);
   intLastValidByte <= "111" when curState = ST_PAD_C else onesCount(macMaster.tKeep(7 downto 1));

   -- State machine
   process (curState, ethRst, intError, intRunt, macMaster, phyReady, stateCount)
   begin

      -- Init
      txCountEn      <= '0';
      txUnderRun     <= '0';
      txLinkNotReady <= '0';
      nxtError       <= intError;
      crcInit        <= '0';

      case curState is

         -- IDLE, wait for data to be available
         when ST_IDLE_C =>
            stateCountRst <= '1';
            intPad        <= '0';
            intAdvance    <= '0';
            intLastLine   <= '0';
            nxtError      <= '0';
            intDump       <= '0';
            crcInit       <= '1';

            -- Wait for start flag
            if macMaster.tValid = '1' and ethRst = '0' then

               -- Phy is ready
               if phyReady = '1' then
                  nxtState <= ST_READ_C;

               -- Phy is not ready dump data
               else
                  nxtState       <= ST_DUMP_C;
                  txLinkNotReady <= '1';
               end if;
            else
               nxtState <= curState;
            end if;

         -- Reading from PIC
         when ST_READ_C =>
            intDump       <= '0';
            stateCountRst <= '0';
            intLastLine   <= '0';
            intPad        <= '0';
            intAdvance    <= '1';
            nxtState      <= curState;

            -- Read until we get last
            if macMaster.tLast = '1' and intRunt = '1' then
               nxtState  <= ST_PAD_C;
               txCountEn <= '1';
               nxtError  <= intError or axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, macMaster, EMAC_EOFE_BIT_C);

            elsif macMaster.tLast = '1' and intRunt = '0' then
               intLastLine   <= '1';
               nxtState      <= ST_WAIT_C;
               txCountEn     <= '1';
               stateCountRst <= '1';
               nxtError      <= intError or axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, macMaster, EMAC_EOFE_BIT_C);

            -- Detect underflow
            elsif macMaster.tValid = '0' then
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
            stateCountRst <= '0';
            intPad        <= '0';

            -- Read until we get last
            if macMaster.tLast = '1' then
               intDump       <= '0';
               intLastLine   <= '1';
               nxtState      <= ST_WAIT_C;
               stateCountRst <= '1';

            -- Keep reading
            else
               intDump     <= macMaster.tValid;
               intLastLine <= '0';
               nxtState    <= curState;
            end if;

         -- Wait for inter-frame gap
         when ST_WAIT_C =>
            intDump       <= '0';
            intAdvance    <= '0';
            stateCountRst <= '0';
            intPad        <= '0';
            intLastLine   <= '0';

            -- Wait for gap, min 3 clocks
            if stateCount >= INTERGAP_C and stateCount >= 3 then
               nxtState <= ST_IDLE_C;
            else
               nxtState <= curState;
            end if;

         -- Padding frame
         when ST_PAD_C =>
            intDump       <= '0';
            stateCountRst <= '0';
            intAdvance    <= '1';
            intPad        <= '1';

            if intRunt = '1' then
               intLastLine <= '0';
               nxtState    <= curState;
            else
               intLastLine   <= '1';
               nxtState      <= ST_WAIT_C;
               stateCountRst <= '1';
            end if;

         when others =>
            nxtState      <= ST_IDLE_C;
            intAdvance    <= '0';
            intDump       <= '0';
            stateCountRst <= '0';
            intPad        <= '0';
            intLastLine   <= '0';
      end case;
   end process;


   -- Format data for input into CRC delay FIFO.
   process (ethClk)
   begin
      if rising_edge(ethClk) then
         if ethRst = '1' then
            frameShift0  <= '0'             after TPD_G;
            frameShift1  <= '0'             after TPD_G;
            txEnable0    <= '0'             after TPD_G;
            txEnable1    <= '0'             after TPD_G;
            txEnable2    <= '0'             after TPD_G;
            txEnable3    <= '0'             after TPD_G;
            crcDataWidth <= (others => '0') after TPD_G;
            crcMaskIn    <= (others => '0') after TPD_G;
            nxtMaskIn    <= (others => '0') after TPD_G;
            crcIn        <= (others => '0') after TPD_G;
            crcDataValid <= '0'             after TPD_G;
         else

            -- Shift register to track frame state
            frameShift0 <= intAdvance  after TPD_G;
            frameShift1 <= frameShift0 after TPD_G;

            -- Input to transmit enable shift register. 
            -- Asserted with frameShift0
            if intAdvance = '1'and frameShift0 = '0' then
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
            crcDataValid <= intAdvance after TPD_G;

            -- Word 0, set source mac address
            if exportWordCnt = 0 then
               crcIn(63 downto 48) <= macAddress(15 downto 0) after TPD_G;
               crcIn(47 downto 0)  <= intData(47 downto 0)    after TPD_G;

            -- Word 1, set source mac address
            elsif exportWordCnt = 1 then
               crcIn(63 downto 32) <= intData(63 downto 32)    after TPD_G;
               crcIn(31 downto 0)  <= macAddress(47 downto 16) after TPD_G;

            -- Normal data
            else
               crcIn <= intData after TPD_G;
            end if;

            -- Last line
            if intLastLine = '1' then
               crcDataWidth <= intLastValidByte after TPD_G;
            else
               crcDataWidth <= "111" after TPD_G;
            end if;

            -- Generate CRC Mask Value for CRC append after delay buffer.
            -- depends on number of bytes in last transfer
            if intLastLine = '1' and frameShift0 = '1' then
               if intError = '1' then   -- Corrupt CRC
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
               crcMaskIn <= nxtMaskIn       after TPD_G;
               nxtMaskIn <= (others => '0') after TPD_G;
            end if;
         end if;
      end if;
   end process;

   -- Select CRC FIFO Data
   crcFifoIn(71 downto 64) <= crcMaskIn;
   crcFifoIn(63 downto 0)  <= crcIn;

   -- CRC Delay FIFO
   U_CrcFifo : entity work.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         BRAM_EN_G       => false,
         FWFT_EN_G       => false,
         USE_DSP48_G     => "no",
         USE_BUILT_IN_G  => false,
         XIL_DEVICE_G    => "7SERIES",
         SYNC_STAGES_G   => 3,
         DATA_WIDTH_G    => 72,
         INIT_G          => "0",
         FULL_THRES_G    => 1,
         EMPTY_THRES_G   => 1
         ) port map (
            rst           => ethRst,
            wr_clk        => ethClk,
            wr_en         => txEnable0,
            din           => crcFifoIn,
            wr_data_count => open,
            wr_ack        => open,
            overflow      => open,
            prog_full     => open,
            almost_full   => open,
            full          => open,
            not_full      => open,
            rd_clk        => ethClk,
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
   process (ethClk)
   begin
      if rising_edge(ethClk) then
         if ethRst = '1' then
            phyTxd <= (others => '0') after TPD_G;
            phyTxc <= (others => '0') after TPD_G;
            nxtEOF <= '0'             after TPD_G;
         else

            -- EOF Charactor Required If CRC was in last word and there was
            -- not enough space for EOF
            if nxtEOF = '1' then
               phyTxd <= X"07070707070707FD" after TPD_G;
               phyTxc <= x"FF"               after TPD_G;
               nxtEOF <= '0'                 after TPD_G;

            -- Not transmitting
            elsif (txEnable2 = '0') and (txEnable3 = '0' or crcFifoOut(71 downto 64) = 0) then
               phyTxd <= X"0707070707070707" after TPD_G;
               phyTxc <= x"FF"               after TPD_G;

            -- Pre-amble word
            elsif txEnable2 = '1' and txEnable3 = '0' then
               phyTxd <= X"D5555555555555FB" after TPD_G;
               phyTxc <= x"01"               after TPD_G;

            -- Normal data or CRC data. Select CRC / data combination
            else
               case crcFifoOut(71 downto 64) is  -- CRC MASK
                  when x"00" =>
                     phyTxd <= crcFifoOut(63 downto 0) after TPD_G;
                     phyTxc <= x"00"                   after TPD_G;
                  when x"80" =>
                     phyTxd(63 downto 56) <= crcTx(7 downto 0)       after TPD_G;
                     phyTxd(55 downto 0)  <= crcFifoOut(55 downto 0) after TPD_G;
                     phyTxc               <= x"00"                   after TPD_G;
                  when x"07" =>
                     phyTxd(63 downto 24) <= x"07070707FD"      after TPD_G;
                     phyTxd(23 downto 0)  <= crcTx(31 downto 8) after TPD_G;
                     phyTxc               <= x"F8"              after TPD_G;
                  when x"0F" =>
                     phyTxd(63 downto 32) <= x"070707FD" after TPD_G;
                     phyTxd(31 downto 0)  <= crcTx       after TPD_G;
                     phyTxc               <= x"F0"       after TPD_G;
                  when x"1E" =>
                     phyTxd(63 downto 40) <= x"0707FD"              after TPD_G;
                     phyTxd(39 downto 8)  <= crcTx                  after TPD_G;
                     phyTxd(7 downto 0)   <= crcFifoOut(7 downto 0) after TPD_G;
                     phyTxc               <= x"E0"                  after TPD_G;
                  when x"3C" =>
                     phyTxd(63 downto 48) <= x"07FD"                 after TPD_G;
                     phyTxd(47 downto 16) <= crcTx                   after TPD_G;
                     phyTxd(15 downto 0)  <= crcFifoOut(15 downto 0) after TPD_G;
                     phyTxc               <= x"C0"                   after TPD_G;
                  when x"78" =>
                     phyTxd(63 downto 56) <= x"FD"                   after TPD_G;
                     phyTxd(55 downto 24) <= crcTx                   after TPD_G;
                     phyTxd(23 downto 0)  <= crcFifoOut(23 downto 0) after TPD_G;
                     phyTxc               <= x"80"                   after TPD_G;
                  when x"F0" =>
                     phyTxd(63 downto 32) <= crcTx                   after TPD_G;
                     phyTxd(31 downto 0)  <= crcFifoOut(31 downto 0) after TPD_G;
                     phyTxc               <= x"00"                   after TPD_G;
                     nxtEOF               <= '1'                     after TPD_G;
                  when x"E0" =>
                     phyTxd(63 downto 40) <= crcTx(23 downto 0)      after TPD_G;
                     phyTxd(39 downto 0)  <= crcFifoOut(39 downto 0) after TPD_G;
                     phyTxc               <= x"00"                   after TPD_G;
                  when x"01" =>
                     phyTxd(63 downto 8) <= x"070707070707FD"   after TPD_G;
                     phyTxd(7 downto 0)  <= crcTx(31 downto 24) after TPD_G;
                     phyTxc              <= x"FE"               after TPD_G;
                  when x"C0" =>
                     phyTxd(63 downto 48) <= crcTx(15 downto 0)      after TPD_G;
                     phyTxd(47 downto 0)  <= crcFifoOut(47 downto 0) after TPD_G;
                     phyTxc               <= x"00"                   after TPD_G;
                  when x"03" =>
                     phyTxd(63 downto 16) <= x"0707070707FD"     after TPD_G;
                     phyTxd(15 downto 0)  <= crcTx(31 downto 16) after TPD_G;
                     phyTxc               <= x"FC"               after TPD_G;
                  when x"FF" =>
                     phyTxd(63 downto 32) <= x"070707FD" after TPD_G;
                     phyTxd(31 downto 0)  <= not crcTx   after TPD_G;
                     phyTxc               <= x"F0"       after TPD_G;
                  when others =>
                     phyTxd <= x"0707070707070707" after TPD_G;
                     phyTxc <= x"FF"               after TPD_G;
               end case;
            end if;
         end if;
      end if;
   end process;


   ------------------------------------------
   -- CRC Logic
   ------------------------------------------

   -- CRC Input
   crcReset               <= crcInit or ethRst or (not phyReady);
   crcInAdj(63 downto 56) <= crcIn(7 downto 0);
   crcInAdj(55 downto 48) <= crcIn(15 downto 8);
   crcInAdj(47 downto 40) <= crcIn(23 downto 16);
   crcInAdj(39 downto 32) <= crcIn(31 downto 24);
   crcInAdj(31 downto 24) <= crcIn(39 downto 32);
   crcInAdj(23 downto 16) <= crcIn(47 downto 40);
   crcInAdj(15 downto 8)  <= crcIn(55 downto 48);
   crcInAdj(7 downto 0)   <= crcIn(63 downto 56);

   -- CRC
   U_Crc32 : entity work.Crc32Parallel
      generic map (
         BYTE_WIDTH_G => 8
         ) port map (
            crcOut       => crcOut,
            crcClk       => ethClk,
            crcDataValid => crcDataValid,
            crcDataWidth => crcDataWidth,
            crcIn        => crcInAdj,
            crcReset     => crcReset
            );

   -- CRC for transmission
   crcTx(31 downto 24) <= crcOut(7 downto 0);
   crcTx(23 downto 16) <= crcOut(15 downto 8);
   crcTx(15 downto 8)  <= crcOut(23 downto 16);
   crcTx(7 downto 0)   <= crcOut(31 downto 24);

end rtl;

