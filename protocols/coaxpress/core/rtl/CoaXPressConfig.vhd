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
      -- Clock and Reset
      cfgClk          : in  sl;
      cfgRst          : in  sl;
      -- Config Interface
      configTimerSize : in  slv(23 downto 0);
      configErrResp   : in  slv(1 downto 0);
      cfgIbMaster     : in  AxiStreamMasterType;
      cfgIbSlave      : out AxiStreamSlaveType;
      cfgObMaster     : out AxiStreamMasterType;
      cfgObSlave      : in  AxiStreamSlaveType;
      -- Tx Interface
      cfgTxMaster     : out AxiStreamMasterType;
      cfgTxSlave      : in  AxiStreamSlaveType;
      -- Tx Interface
      cfgRxMaster     : in  AxiStreamMasterType);
end entity CoaXPressConfig;

architecture rtl of CoaXPressConfig is

   type StateType is (
      IDLE_S,
      CRC_S,
      XFER_S,
      RESP_S);

   type RegType is record
      tValid         : slv(7 downto 0);
      tLast          : slv(7 downto 0);
      tData          : Slv32Array(7 downto 0);
      tDataK         : slv(7 downto 0);
      idx            : natural range 0 to 7;
      timer          : slv(23 downto 0);
      cfgTxMaster    : AxiStreamMasterType;
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
      state          : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      tValid         => (others => '0'),
      tLast          => (others => '0'),
      tData          => (others => (others => '0')),
      tDataK         => (others => '0'),
      idx            => 0,
      timer          => (others => '0'),
      cfgTxMaster    => AXI_STREAM_MASTER_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      state          => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal axilReadMaster  : AxiLiteReadMasterType;
   signal axilWriteMaster : AxiLiteWriteMasterType;

   attribute dont_touch                    : string;
   attribute dont_touch of r               : signal is "TRUE";
   attribute dont_touch of axilReadMaster  : signal is "TRUE";
   attribute dont_touch of axilWriteMaster : signal is "TRUE";

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

   comb : process (axilReadMaster, axilWriteMaster, cfgRst, cfgRxMaster,
                   cfgTxSlave, configErrResp, configTimerSize, r) is
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
      if (cfgTxSlave.tReady = '1') then
         v.cfgTxMaster.tValid := '0';
      end if;

      -- Determine the transaction type
      axiSlaveWaitTxn(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus);

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Reset Counters
            v.timer := configTimerSize;

            -- Check if ready to move data
            if (v.cfgTxMaster.tValid = '0') then

               -- Reset bus
               v.tValid := (others => '0');
               v.tLast  := (others => '0');
               v.tDataK := (others => '0');

               -- Check if write transaction
               if (axilStatus.writeEnable = '1') then

                  -- Start of packet indication
                  v.tValid(0) := '1';
                  v.tDataK(0) := '1';
                  v.tData(0)  := CXP_SOP_C;

                  -- Control command indication - without tag
                  v.tValid(1) := '1';
                  v.tData(1)  := x"02_02_02_02";

                  -- Word[0].Char[P3:P1] = Size (always 4 byte access)
                  -- Word[0].Char[P0] = Cmd (0x01 = Memory Write)
                  v.tValid(2) := '1';
                  v.tData(2)  := x"04_00_00_01";

                  -- Word[1] = Addr
                  v.tValid(3) := '1';
                  v.tData(3)  := endianSwap(axilWriteMaster.awaddr);

                  -- Word[2] = Write Data
                  v.tValid(4) := '1';
                  v.tData(4)  := endianSwap(axilWriteMaster.wdata);

                  -- Word[3] = CRC-32 (placeholder)
                  v.tValid(5) := '1';
                  v.tData(5)  := x"00_00_00_00";

                  -- End of packet indication
                  v.tValid(6) := '1';
                  v.tLast(6)  := '1';
                  v.tDataK(6) := '1';
                  v.tData(6)  := CXP_EOP_C;

                  -- Next State
                  v.state := CRC_S;

               -- Check if read transaction
               elsif (axilStatus.readEnable = '1') then

                  -- Start of packet indication
                  v.tValid(0) := '1';
                  v.tDataK(0) := '1';
                  v.tData(0)  := CXP_SOP_C;

                  -- Control command indication - without tag
                  v.tValid(1) := '1';
                  v.tData(1)  := x"02_02_02_02";

                  -- Word[0].Char[P3:P1] = Size (always 4 byte access)
                  -- Word[0].Char[P0] = Cmd (0x00 = Memory Read)
                  v.tValid(2) := '1';
                  v.tData(2)  := x"04_00_00_00";

                  -- Word[1] = Addr
                  v.tValid(3) := '1';
                  v.tData(3)  := endianSwap(axilReadMaster.araddr);

                  -- Word[2] = CRC-32 (placeholder)
                  v.tValid(4) := '1';
                  v.tData(4)  := x"00_00_00_00";

                  -- End of packet indication
                  v.tValid(5) := '1';
                  v.tLast(5)  := '1';
                  v.tDataK(5) := '1';
                  v.tData(5)  := CXP_EOP_C;

                  -- Next State
                  v.state := CRC_S;

               end if;

            end if;
         ----------------------------------------------------------------------
         when CRC_S =>
            -- Check if write transaction
            if (axilStatus.writeEnable = '1') then
               for i in 2 to 4 loop
                  for j in 0 to 3 loop
                     byteXor := crc(31 downto 24) xor bitReverse(r.tData(i)(8*j+7 downto 8*j));
                     crc     := (crc(23 downto 0) & x"00") xor crcByteLookup(byteXor, CXP_CRC_POLY_C);
                  end loop;
               end loop;
            -- Else read transaction
            else
               for i in 2 to 3 loop
                  for j in 0 to 3 loop
                     byteXor := crc(31 downto 24) xor bitReverse(r.tData(i)(8*j+7 downto 8*j));
                     crc     := (crc(23 downto 0) & x"00") xor crcByteLookup(byteXor, CXP_CRC_POLY_C);
                  end loop;
               end loop;
            end if;

            -- bit reverse the CRC bytes
            for i in 0 to 3 loop
               retVar(8*i+7 downto 8*i) := bitReverse(crc(8*i+7 downto 8*i));
            end loop;

            -- Check if write transaction
            if (axilStatus.writeEnable = '1') then
               -- Word[3] = CRC-32
               v.tData(5) := endianSwap(retVar);
            -- Else read transaction
            else
               -- Word[2] = CRC-32
               v.tData(4) := endianSwap(retVar);
            end if;

            -- Next State
            v.state := XFER_S;
         ----------------------------------------------------------------------
         when XFER_S =>
            -- Check if ready to move data
            if (v.cfgTxMaster.tValid = '0') then

               -- Send the transaction
               v.cfgTxMaster.tValid             := r.tValid(r.idx);
               v.cfgTxMaster.tLast              := r.tLast(r.idx);
               v.cfgTxMaster.tData(31 downto 0) := r.tData(r.idx);
               v.cfgTxMaster.tUser(0)           := r.tDataK(r.idx);

               -- Check counter
               if (r.idx = 7) then
                  -- Reset counter
                  v.idx   := 0;
                  -- Next State
                  v.state := RESP_S;
               else
                  -- Increment counter
                  v.idx := r.idx + 1;
               end if;

            end if;
         ----------------------------------------------------------------------
         when RESP_S =>
            -- Check the timer
            if r.timer /= 0 then
               -- Decrement the timer
               v.timer := r.timer - 1;
            end if;

            -- Check for timeout or ACK packet
            if (r.timer = 0) or (cfgRxMaster.tValid = '1') then

               -- Check for bus responds error
               if (cfgRxMaster.tData(31 downto 0) /= 0) or (r.timer = 0) then
                  axilResp := configErrResp;
               end if;

               -- Copy the read data bus
               v.axilReadSlave.rdata := endianSwap(cfgRxMaster.tData(63 downto 32));

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

      -- Outputs
      cfgTxMaster <= r.cfgTxMaster;

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

end rtl;
