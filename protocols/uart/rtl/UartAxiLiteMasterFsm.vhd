-------------------------------------------------------------------------------
-- Title      : UART Memory Protocol: https://confluence.slac.stanford.edu/x/uSDoDQ
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Finite State Machine (FSM) for UartAxiLiteMaster.vhd
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

library surf;
use surf.StdRtlPkg.all;
use surf.TextUtilPkg.all;
use surf.AxiLitePkg.all;

entity UartAxiLiteMasterFsm is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Clock and Reset
      axilClk          : in  sl;
      axilRst          : in  sl;
      -- UART TX Streaming Byte Interface
      uartTxValid      : out sl;
      uartTxData       : out slv(7 downto 0);
      uartTxReady      : in  sl;
      -- UART RX Streaming Byte Interface
      uartRxValid      : in  sl;
      uartRxData       : in  slv(7 downto 0);
      uartRxReady      : out sl;
      -- AXI-Lite interface
      mAxilWriteMaster : out AxiLiteWriteMasterType;
      mAxilWriteSlave  : in  AxiLiteWriteSlaveType;
      mAxilReadMaster  : out AxiLiteReadMasterType;
      mAxilReadSlave   : in  AxiLiteReadSlaveType);
end entity UartAxiLiteMasterFsm;

architecture rtl of UartAxiLiteMasterFsm is

   type StateType is (
      WAIT_START_S,
      SPACE_ADDR_S,
      ADDR_SPACE_S,
      WR_DATA_S,
      WAIT_EOL_S,
      AXIL_TXN_S,
      RD_DATA_SPACE_S,
      RD_DATA_S,
      DONE_S);

   type RegType is record
      state       : StateType;
      count       : slv(2 downto 0);
      axilReq     : AxiLiteReqType;
      rdData      : slv(31 downto 0);
      uartTxData  : slv(7 downto 0);
      uartTxValid : sl;
      uartRxReady : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state       => WAIT_START_S,
      count       => (others => '0'),
      axilReq     => AXI_LITE_REQ_INIT_C,
      rdData      => (others => '0'),
      uartTxData  => (others => '0'),
      uartTxValid => '0',
      uartRxReady => '1');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal axilAck : AxiLiteAckType;

   -- translate a hex character 0-9 A-F into an slv
   function hexToSlv (hex : slv(7 downto 0)) return slv is
      variable char : character;
   begin
      char := character'val(conv_integer(hex));

      return toSlv(int(char), 4);

   end function;

   function slvToHex (nibble : slv(3 downto 0)) return slv is
   begin
      return toSlv(character'pos(chr(conv_integer(nibble))), 8);
   end function;

begin

   U_AxiLiteMaster_1 : entity surf.AxiLiteMaster
      generic map (
         TPD_G => TPD_G)
      port map (
         axilClk         => axilClk,           -- [in]
         axilRst         => axilRst,           -- [in]
         req             => r.axilReq,         -- [in]
         ack             => axilAck,           -- [out]
         axilWriteMaster => mAxilWriteMaster,  -- [out]
         axilWriteSlave  => mAxilWriteSlave,   -- [in]
         axilReadMaster  => mAxilReadMaster,   -- [out]
         axilReadSlave   => mAxilReadSlave);   -- [in]

   comb : process (axilAck, axilRst, r, uartRxData, uartRxValid, uartTxReady) is
      variable v : RegType;

      procedure uartTx (byte : in slv(7 downto 0)) is
      begin
         v.uartTxValid := '1';
         v.uartTxData  := byte;
      end procedure uartTx;

      procedure uartTx (char : in character) is
      begin
         uartTx(toSlv(character'pos(char), 8));
      end procedure uartTx;

      function isSpace (byte : slv(7 downto 0)) return boolean is
      begin
         return (byte = character'pos(' '));
      end function isSpace;

      function isEOL (byte : slv(7 downto 0)) return boolean is
      begin
         return (byte = character'pos(CR) or
                 byte = character'pos(LF));
      end function isEOL;

   begin
      -- Latch the current value
      v := r;

      -- Format:
      -- "w|W ADDRHEX DATAHEX0 [DATAHEX1] [DATAHEX2]...\r|\n"
      -- Writes echo'd back with resp code
      -- "r|R ADDRHEX [NUMREADSHEX] \r|\n"
      -- Resp: "r|R ADDRHEX DATAHEX0 [DATAHEX1] [DATAHEX2]...\r|\n"
      -- Blank lines ignored
      -- Extra words ignored.

      -- Auto clear uartTxValid upton uartTxReady
      if (uartTxReady = '1') then
         v.uartTxValid := '0';
      end if;

      case r.state is
         when WAIT_START_S =>
            -- Any characters before 'r' or 'w' are thrown out
            if (uartRxValid = '1') then
               v.axilReq.address := (others => '0');
               if (uartRxData = toSlv(character'pos('w'), 8) or
                   uartRxData = toSlv(character'pos('W'), 8)) then
                  -- Write op
                  v.axilReq.rnw := '0';
                  uartTx(uartRxData);
                  v.state       := SPACE_ADDR_S;
               elsif (uartRxData = toSlv(character'pos('r'), 8) or
                      uartRxData = toSlv(character'pos('R'), 8)) then
                  -- Read
                  v.axilReq.rnw := '1';
                  uartTx(uartRxData);
                  v.state       := SPACE_ADDR_S;
               end if;
            end if;

         when SPACE_ADDR_S =>
            -- Need to check for the space after opcode
            if (uartRxValid = '1') then
               uartTx(uartRxData);
               v.state           := ADDR_SPACE_S;
               v.axilReq.address := r.axilReq.address(27 downto 0) & hexToSlv(uartRxData);

               -- Ignore character if its a space
               if (isSpace(uartRxData)) then
                  v.axilReq.address := r.axilReq.address;
               end if;

               -- Go back to start if EOL
               if (isEOL(uartRxData)) then
                  v.state := WAIT_START_S;
               end if;
            end if;


         when ADDR_SPACE_S =>
            if (uartRxValid = '1') then
               uartTx(uartRxData);
               v.axilReq.address := r.axilReq.address(27 downto 0) & hexToSlv(uartRxData);

               -- Space indicates end of addr word
               if (isSpace(uartRxData)) then
                  v.axilReq.address := r.axilReq.address;
                  if (r.axilReq.rnw = '0') then
                     v.axilReq.wrData := (others => '0');
                     v.state          := WR_DATA_S;
                  else
                     v.state := WAIT_EOL_S;
                  end if;
               end if;

               -- Go back to start if EOL and write op
               -- Else do the read op
               if (isEOL(uartRxData)) then
                  if (r.axilReq.rnw = '0') then
                     v.state := WAIT_START_S;
                  else
                     v.axilReq.address := r.axilReq.address;
                     uartTx(' ');
                     v.state           := AXIL_TXN_S;
                  end if;
               end if;

            end if;

         when WR_DATA_S =>
            if (uartRxValid = '1') then
               uartTx(uartRxData);
               v.axilReq.wrData := r.axilReq.wrData(27 downto 0) & hexToSlv(uartRxData);

               -- Space or EOL indicates end of wrData word
               -- If space need to wait for EOL
               if (isSpace(uartRxData)) then
                  v.axilReq.wrData := r.axilReq.wrData;
                  v.state          := WAIT_EOL_S;
               end if;

               -- If EOL can issue AXIL txn
               if (isEOL(uartRxData)) then
                  v.axilReq.wrData := r.axilReq.wrData;
                  uartTx(' ');
                  v.state          := AXIL_TXN_S;
               end if;
            end if;

         when WAIT_EOL_S =>
            -- Issue AXIL TXN once EOL seen
            -- Any other charachters are echo'd but otherwise ignored
            if (uartRxValid = '1') then
               uartTx(uartRxData);
               if (isEOL(uartRxData)) then
                  uartTx(' ');
                  v.state := AXIL_TXN_S;
               end if;
            end if;

         when AXIL_TXN_S =>
            -- Transmit a space on first cycle of this state
            if (r.axilReq.request = '0' and r.axilReq.rnw = '0') then
               uartTx(' ');
            end if;

            -- Assert request and wait for response
            v.axilReq.request := '1';
            if (axilAck.done = '1') then

               -- Done if write op, else transmit the read data
               if (r.axilReq.rnw = '0') then
                  v.state := DONE_S;
               else
                  --uartTx(' ');
                  v.rdData := axilAck.rdData;
                  v.state  := RD_DATA_S;
               end if;
            end if;


         when RD_DATA_S =>
            v.count  := r.count + 1;
            uartTx(slvToHex(r.rdData(31 downto 28)));
            v.rdData := r.rdData(27 downto 0) & "0000";
            if (r.count = 7) then
               v.state := RD_DATA_SPACE_S;
            end if;


         when RD_DATA_SPACE_S =>
            uartTx(' ');
            v.state := DONE_S;

         when DONE_S =>
            -- Send resp code first cycle of this state
            if (r.axilReq.request = '1') then
               -- Send the response code
               uartTx(slvToHex(resize(axilAck.resp, 4)));
            end if;

            -- Release request and wait for done to fall
            -- Send closing CR when it does
            v.axilReq.request := '0';
            if (axilAck.done = '0') then
               uartTx(CR);
               v.state := WAIT_START_S;
            end if;

      end case;

      -- Outputs
      uartTxData  <= r.uartTxData;
      uartTxValid <= r.uartTxValid;
      uartRxReady <= r.uartRxReady;

      -- Reset
      if (axilRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
