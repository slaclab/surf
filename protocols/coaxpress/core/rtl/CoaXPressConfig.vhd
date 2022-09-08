-------------------------------------------------------------------------------
-- Title      : CoaXPress Protocol: http://jiia.org/wp-content/themes/jiia/pdf/standard_dl/coaxpress/CXP-001-2021.pdf
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: CoaXPress Core
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
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;
use surf.CoaXPressPkg.all;
use surf.Code8b10bPkg.all;
use surf.CrcPkg.all;

entity CoaXPressConfig is
   generic (
      TPD_G         : time := 1 ns;
      AXIS_CONFIG_G : AxiStreamConfigType);
   port (
      -- Config Interface (cfgClk domain)
      cfgClk          : in  sl;
      cfgRst          : in  sl;
      configTimerSize : in  slv(23 downto 0);
      configErrResp   : in  slv(1 downto 0);
      cfgIbMaster     : in  AxiStreamMasterType;
      cfgIbSlave      : out AxiStreamSlaveType;
      cfgObMaster     : out AxiStreamMasterType;
      cfgObSlave      : in  AxiStreamSlaveType;
      -- Tx Interface (txClk domain)
      txClk           : in  sl;
      txRst           : in  sl;
      cfgTxMaster     : out AxiStreamMasterType;
      cfgTxSlave      : in  AxiStreamSlaveType;
      -- Tx Interface (txClk domain)
      rxClk           : in  sl;
      rxRst           : in  sl;
      cfgRxMaster     : in  AxiStreamMasterType);
end entity CoaXPressConfig;

architecture rtl of CoaXPressConfig is

   constant TX_WIDE_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => (224/8),         -- 224-bit data interface
      TDEST_BITS_C  => 0,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_NORMAL_C,
      TUSER_BITS_C  => 1,
      TUSER_MODE_C  => TUSER_NORMAL_C);

   constant TX_NARROW_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => TX_WIDE_CONFIG_C.TSTRB_EN_C,
      TDATA_BYTES_C => (8/8),           -- 8-bit data interface
      TDEST_BITS_C  => TX_WIDE_CONFIG_C.TDEST_BITS_C,
      TID_BITS_C    => TX_WIDE_CONFIG_C.TID_BITS_C,
      TKEEP_MODE_C  => TX_WIDE_CONFIG_C.TKEEP_MODE_C,
      TUSER_BITS_C  => TX_WIDE_CONFIG_C.TUSER_BITS_C,
      TUSER_MODE_C  => TX_WIDE_CONFIG_C.TUSER_MODE_C);

   type StateType is (
      IDLE_S,
      CRC_S,
      RESP_S);

   type RegType is record
      timer          : slv(23 downto 0);
      txMaster       : AxiStreamMasterType;
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
      state          : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      timer          => (others => '0'),
      txMaster       => AXI_STREAM_MASTER_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      state          => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal axilReadMaster  : AxiLiteReadMasterType;
   signal axilWriteMaster : AxiLiteWriteMasterType;

   signal txSlave   : AxiStreamSlaveType;
   signal rxMaster  : AxiStreamMasterType;
   signal rxRstSync : sl;

begin

   U_SRPv3 : entity surf.SrpV3AxiLite
      generic map (
         TPD_G               => TPD_G,
         SLAVE_READY_EN_G    => true,
         GEN_SYNC_FIFO_G     => true,
         AXI_STREAM_CONFIG_G => AXIS_CONFIG_G)
      port map (
         -- Streaming Slave (Rx) Interface (sAxisClk domain)
         sAxisClk         => cfgClk,
         sAxisRst         => cfgRst,
         sAxisMaster      => cfgIbMaster,
         sAxisSlave       => cfgIbSlave,
         -- Streaming Master (Tx) Data Interface (mAxisClk domain)
         mAxisClk         => cfgClk,
         mAxisRst         => cfgRst,
         mAxisMaster      => cfgObMaster,
         mAxisSlave       => cfgObSlave,
         -- Master AXI-Lite Interface (axilClk domain)
         axilClk          => cfgClk,
         axilRst          => cfgRst,
         mAxilReadMaster  => axilReadMaster,
         mAxilReadSlave   => r.axilReadSlave,
         mAxilWriteMaster => axilWriteMaster,
         mAxilWriteSlave  => r.axilWriteSlave);

   comb : process (axilReadMaster, axilWriteMaster, cfgRst, configErrResp,
                   configTimerSize, r, rxMaster, rxRstSync, txSlave) is
      variable v          : RegType;
      variable axilStatus : AxiLiteStatusType;
      variable axilResp   : slv(1 downto 0);
      variable crc        : slv(31 downto 0);
      variable retVar     : slv(31 downto 0);
      variable byteXor    : slv(7 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Init Local Variables
      axilResp := AXI_RESP_OK_C;
      crc      := x"FFFFFFFF";
      retVar   := x"FFFFFFFF";
      byteXor  := (others => '0');

      -- Flow Control
      if (txSlave.tReady = '1') then
         v.txMaster.tValid := '0';
      end if;

      -- Determine the transaction type
      axiSlaveWaitTxn(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus);

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Reset Counter
            v.timer := configTimerSize;

            -- Check if ready to move data
            if (r.txMaster.tValid = '0') then

               -- Reset the tUser/tKeep field
               v.txMaster.tUser := (others => '0');
               v.txMaster.tKeep := (others => '0');

               -- Check if write transaction
               if (axilStatus.writeEnable = '1') then

                  -- Start of packet indication
                  v.txMaster.tData(31 downto 0) := K_27_7_C & K_27_7_C & K_27_7_C & K_27_7_C;
                  v.txMaster.tUser(31 downto 0) := (others => '1');  -- txDataK marker

                  -- Control command indication – without tag
                  v.txMaster.tData(63 downto 32) := x"02_02_02_02";

                  -- Word[0].Char[P0] = Cmd (0x01 = Memory Write)
                  v.txMaster.tData(71 downto 64) := x"01";

                  -- Word[0].Char[P3:P1] = Size (always 4 byte access)
                  v.txMaster.tData(95 downto 72) := x"04_00_00";  -- big endian

                  -- Word[1] = Addr
                  v.txMaster.tData(127 downto 96) := endianSwap(axilWriteMaster.awaddr);

                  -- Word[2] = Write Data
                  v.txMaster.tData(159 downto 128) := endianSwap(axilWriteMaster.wdata);

                  -- Word[3] = CRC-32 (placeholder)
                  v.txMaster.tData(191 downto 160) := x"00_00_00_00";

                  -- Start of packet indication
                  v.txMaster.tData(223 downto 192) := K_29_7_C & K_29_7_C & K_29_7_C & K_29_7_C;
                  v.txMaster.tUser(223 downto 192) := (others => '1');  -- txDataK marker
                  v.txMaster.tKeep(27 downto 0)    := (others => '1');
                  v.txMaster.tLast                 := '1';

                  -- Next State
                  v.state := CRC_S;

               -- Check if read transaction
               elsif (axilStatus.readEnable = '1') then

                  -- Start of packet indication
                  v.txMaster.tData(31 downto 0) := K_27_7_C & K_27_7_C & K_27_7_C & K_27_7_C;
                  v.txMaster.tUser(31 downto 0) := (others => '1');  -- txDataK marker

                  -- Control command indication – without tag
                  v.txMaster.tData(63 downto 32) := x"02_02_02_02";

                  -- Word[0].Char[P0] = Cmd (0x00 = Memory Read)
                  v.txMaster.tData(71 downto 64) := x"00";

                  -- Word[0].Char[P3:P1] = Size (always 4 byte access)
                  v.txMaster.tData(95 downto 72) := x"04_00_00";  -- big endian

                  -- Word[1] = Addr
                  v.txMaster.tData(127 downto 96) := endianSwap(axilReadMaster.araddr);

                  -- Word[2] = CRC-32 (placeholder)
                  v.txMaster.tData(159 downto 128) := x"00_00_00_00";

                  -- Start of packet indication
                  v.txMaster.tData(191 downto 160) := K_29_7_C & K_29_7_C & K_29_7_C & K_29_7_C;
                  v.txMaster.tUser(191 downto 160) := (others => '1');  -- txDataK marker
                  v.txMaster.tKeep(23 downto 0)    := (others => '1');
                  v.txMaster.tLast                 := '1';

                  -- Next State
                  v.state := CRC_S;

               end if;

            end if;
         ----------------------------------------------------------------------
         when CRC_S =>
            -- Check if write transaction
            if (axilStatus.writeEnable = '1') then
               for i in 8 to 19 loop
                  byteXor := crc(31 downto 24) xor bitReverse(r.txMaster.tData(8*i+7 downto 8*i));
                  crc     := (crc(23 downto 0) & x"00") xor crcByteLookup(byteXor, CXP_CRC_POLY_C);
               end loop;
            -- Else read transaction
            else
               for i in 8 to 15 loop
                  byteXor := crc(31 downto 24) xor bitReverse(r.txMaster.tData(8*i+7 downto 8*i));
                  crc     := (crc(23 downto 0) & x"00") xor crcByteLookup(byteXor, CXP_CRC_POLY_C);
               end loop;
            end if;

            -- bit reverse the CRC bytes
            for i in 0 to 3 loop
               retVar(8*i+7 downto 8*i) := bitReverse(crc(8*i+7 downto 8*i));
            end loop;

            -- Check if write transaction
            if (axilStatus.writeEnable = '1') then
               -- Word[3] = CRC-32
               v.txMaster.tData(191 downto 160) := endianSwap(retVar);
            -- Else read transaction
            else
               -- Word[2] = CRC-32
               v.txMaster.tData(159 downto 128) := endianSwap(retVar);
            end if;

            -- Send the transaction
            v.txMaster.tValid := '1';

            -- Next State
            v.state := IDLE_S;
         ----------------------------------------------------------------------
         when RESP_S =>
            -- Check if RX link is down
            if (rxRstSync = '1') then
               v.timer := (others => '0');
            -- Check the timer
            elsif r.timer /= 0 then
               -- Decrement the timer
               v.timer := r.timer - 1;
            end if;

            -- Check for timeout or ACK packet
            if (r.timer = 0) or (rxMaster.tValid = '1') then

               -- Check for bus responds error
               if (rxMaster.tData(31 downto 0) /= 0) or (r.timer = 0) then
                  axilResp := configErrResp;
               end if;

               -- Copy the read data bus
               v.axilReadSlave.rdata := endianSwap(rxMaster.tData(95 downto 64));

               -- Check if write transaction
               if (axilStatus.writeEnable = '1') then
                  -- Send the write response
                  axiSlaveWriteResponse(v.axilWriteSlave, axilResp);
               -- Check if read transaction
               elsif (axilStatus.readEnable = '1') then
                  -- Send the response
                  axiSlaveReadResponse(v.axilReadSlave, axilResp);
               end if;

               -- Next State
               v.state := IDLE_S;

            end if;
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (cfgRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (cfgClk) is
   begin
      if (rising_edge(cfgClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_rxRst : entity surf.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => cfgClk,
         dataIn  => rxRst,
         dataOut => rxRstSync);

   TX_FIFO : entity surf.AxiStreamFifoV2
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         -- FIFO configurations
         INT_WIDTH_SELECT_G  => "NARROW",
         MEMORY_TYPE_G       => "block",
         GEN_SYNC_FIFO_G     => false,
         FIFO_ADDR_WIDTH_G   => 9,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => TX_WIDE_CONFIG_C,
         MASTER_AXI_CONFIG_G => TX_NARROW_CONFIG_C)
      port map (
         -- Slave Port
         sAxisClk    => cfgClk,
         sAxisRst    => cfgRst,
         sAxisMaster => r.txMaster,
         sAxisSlave  => txSlave,
         -- Master Port
         mAxisClk    => txClk,
         mAxisRst    => txRst,
         mAxisMaster => cfgTxMaster,
         mAxisSlave  => cfgTxSlave);

   RX_FIFO : entity surf.AxiStreamFifoV2
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         SLAVE_READY_EN_G    => false,
         -- FIFO configurations
         MEMORY_TYPE_G       => "distributed",
         GEN_SYNC_FIFO_G     => false,
         FIFO_ADDR_WIDTH_G   => 4,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => TX_WIDE_CONFIG_C,
         MASTER_AXI_CONFIG_G => TX_WIDE_CONFIG_C)
      port map (
         -- Slave Port
         sAxisClk    => rxClk,
         sAxisRst    => rxRst,
         sAxisMaster => cfgRxMaster,
         -- Master Port
         mAxisClk    => cfgClk,
         mAxisRst    => cfgRst,
         mAxisMaster => rxMaster,
         mAxisSlave  => AXI_STREAM_SLAVE_FORCE_C);

end rtl;
