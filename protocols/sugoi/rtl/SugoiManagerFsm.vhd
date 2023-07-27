-------------------------------------------------------------------------------
-- Title      : SUGOI Protocol: https://confluence.slac.stanford.edu/x/3of_E
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Manager Finite State Machine (FSM)
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
use surf.AxiLitePkg.all;
use surf.SugoiPkg.all;

entity SugoiManagerFsm is
   generic (
      TPD_G           : time    := 1 ns;
      SIMULATION_G    : boolean := false;
      RST_ASYNC_G     : boolean := false;
      NUM_ADDR_BITS_G : positive;  -- Number of AXI-Lite address bits in the Subordinate
      TX_POLARITY_G   : sl      := '0';
      RX_POLARITY_G   : sl      := '0');
   port (
      -- Clock and Reset
      clk             : in  sl;
      rst             : in  sl;
      -- Timing and Trigger Interface
      globalRst       : in  sl;
      opCode          : in  slv(7 downto 0);
      -- RX Interface
      rxValid         : in  sl;
      rxData          : in  slv(7 downto 0);
      rxDataK         : in  sl;
      -- RX Interface
      txStrobe        : out sl;
      txData          : out slv(7 downto 0);
      txDataK         : out sl;
      -- Control/Monitoring
      disableClk      : out sl;
      disableTx       : out sl;
      polarityTx      : out sl;
      polarityRx      : out sl;
      enUsrDlyCfg     : out sl;
      usrDlyCfg       : out slv(8 downto 0);
      bypFirstBerDet  : out sl;
      minEyeWidth     : out slv(7 downto 0);
      lockingCntCfg   : out slv(23 downto 0);
      errorDet        : in  sl;
      eyeWidth        : in  slv(8 downto 0);
      gearboxAligned  : in  sl;
      -- AXI-Lite Master Interface
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end entity SugoiManagerFsm;

architecture rtl of SugoiManagerFsm is

   constant CNT_WIDTH_C : positive := 16;

   constant MAX_CNT_C : slv(CNT_WIDTH_C-1 downto 0) := (others => '1');

   type CntArray is array (natural range <>) of slv(CNT_WIDTH_C-1 downto 0);

   type StateType is (
      IDLE_S,
      TXN_S,
      RESP_S);

   type RegType is record
      disableClk     : sl;
      disableTx      : sl;
      polarityTx     : sl;
      polarityRx     : sl;
      enUsrDlyCfg    : sl;
      usrDlyCfg      : slv(8 downto 0);
      bypFirstBerDet : sl;
      minEyeWidth    : slv(7 downto 0);
      lockingCntCfg  : slv(23 downto 0);
      heartbeatCnt   : natural range 0 to 9;
      globalRst      : sl;
      globalRstForce : sl;
      opCode         : slv(7 downto 0);
      opCodeForce    : slv(7 downto 0);
      txStrobe       : sl;
      heartbeat      : sl;
      txData         : slv(7 downto 0);
      txDataK        : sl;
      txByteCnt      : natural range 0 to 13;
      txXsum         : slv(7 downto 0);
      txMsg          : Slv8Array(12 downto 0);
      rxByteCnt      : natural range 0 to 13;
      rxXsum         : slv(7 downto 0);
      rxMsg          : Slv8Array(12 downto 0);
      rstCnt         : sl;
      errorDet       : sl;
      gearboxAligned : sl;
      dropTrigCnt    : CntArray(7 downto 0);
      errorDetCnt    : slv(CNT_WIDTH_C-1 downto 0);
      linkUpCnt      : slv(CNT_WIDTH_C-1 downto 0);
      timerConfig    : slv(23 downto 0);
      timer          : slv(23 downto 0);
      enLatencyCnt   : sl;
      latencyCnt     : slv(CNT_WIDTH_C-1 downto 0);
      latency        : slv(CNT_WIDTH_C-1 downto 0);
      axilWriteSlave : AxiLiteWriteSlaveType;
      axilReadSlave  : AxiLiteReadSlaveType;
      state          : StateType;
   end record;
   constant REG_INIT_C : RegType := (
      disableClk     => '0',
      disableTx      => '0',
      polarityTx     => TX_POLARITY_G,
      polarityRx     => RX_POLARITY_G,
      enUsrDlyCfg    => '0',            -- Enable User delay config
      usrDlyCfg      => (others => '0'),  -- User delay config
      bypFirstBerDet => '1',  -- Set to '1' if IDELAY full scale range > 2 Unit Intervals (UI) of serial rate (example: IDELAY range 2.5ns  > 1 ns "1Gb/s" )
      minEyeWidth    => toSlv(80, 8),  -- Sets the minimum eye width required for locking (units of IDELAY step)
      lockingCntCfg  => ite(SIMULATION_G, x"00_0064", x"00_0FFF"),  -- Number of error-free event before state=LOCKED_S
      heartbeatCnt   => 9,
      globalRst      => '0',
      globalRstForce => '0',
      opCode         => (others => '0'),
      opCodeForce    => (others => '0'),
      heartbeat      => '0',
      txStrobe       => '0',
      txData         => CODE_IDLE_C,
      txDataK        => '1',
      txByteCnt      => 13,
      txXsum         => (others => '0'),
      txMsg          => (others => (others => '0')),
      rxByteCnt      => 13,
      rxXsum         => (others => '0'),
      rxMsg          => (others => (others => '0')),
      rstCnt         => '0',
      errorDet       => '0',
      gearboxAligned => '0',
      dropTrigCnt    => (others => (others => '0')),
      errorDetCnt    => (others => '0'),
      linkUpCnt      => (others => '0'),
      timerConfig    => toSlv(1024, 24),
      timer          => (others => '0'),
      enLatencyCnt   => '0',
      latencyCnt     => (others => '0'),
      latency        => (others => '0'),
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      state          => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (axilReadMaster, axilWriteMaster, errorDet, eyeWidth,
                   gearboxAligned, globalRst, opCode, r, rst, rxData, rxDataK,
                   rxValid) is
      variable v        : RegType;
      variable i        : natural;
      variable RnW      : sl;
      variable devIdx   : natural;
      variable addr     : slv(31 downto 0);
      variable axilResp : slv(1 downto 0);
      variable axilEp   : AxiLiteEndpointType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobes
      v.heartbeat   := '0';
      v.txStrobe    := '0';
      v.rstCnt      := '0';
      v.opCodeForce := (others => '0');

      -- Round trip latency using the SOF control code
      if (r.enLatencyCnt = '1') and (r.latencyCnt /= MAX_CNT_C) then
         -- Increment the counter
         v.latencyCnt := r.latencyCnt + 1;
      end if;

      -- Check for heartbeat event
      if (r.heartbeatCnt = 0) then
         -- Pre-set the counter
         v.heartbeatCnt := 9;
         -- Set the flag
         v.heartbeat    := '1';
      else
         -- Decrement the counter
         v.heartbeatCnt := r.heartbeatCnt - 1;
      end if;

      -- Check for no link lock
      if (r.gearboxAligned = '0') then
         v.timer := (others => '0');

      -- Else check if not communication timed out
      elsif (r.timer /= 0) then
         -- Decrement the counter
         v.timer := r.timer - 1;
      end if;

      -- Latch the globalRst value
      if (globalRst = '1') then
         v.globalRst := '1';
      end if;

      -- Loop through trigger codes
      for i in 0 to 7 loop

         -- Latch the opCode values
         if (opCode(i) = '1') or (r.opCodeForce(i) = '1') then
            v.opCode(i) := '1';
         end if;

      end loop;

      -- Check for heartbeat
      if (r.heartbeat = '1') then

         -- Send IDLE code
         v.txStrobe := '1';
         v.txData   := CODE_IDLE_C;
         v.txDatak  := '1';

         -- Check for global reset or forced from software
         if (v.globalRst = '1') or (r.globalRstForce = '1') then
            -- Send reset to Subordinate
            v.txData := CODE_RST_C;
         end if;

         -- Loop through trigger codes
         for i in 0 to 7 loop

            -- Latch the opCode values
            if (v.opCode(i) = '1') then

               -- Check for IDLE code
               if (v.txData = CODE_IDLE_C) then
                  -- Send trigger to Subordinate
                  v.txData := CODE_TRIG_C(i);

               elsif (r.dropTrigCnt(i) /= MAX_CNT_C) then
                  -- Increment the counter
                  v.dropTrigCnt(i) := r.dropTrigCnt(i) + 1;
               end if;

            end if;

         end loop;

         -- Reset the flags
         v.globalRst := '0';
         v.opCode    := (others => '0');

         -- Check for IDLE code
         if (v.txData = CODE_IDLE_C) and (r.txByteCnt /= 13) then

            -- Send request message
            v.txData := r.txMsg(r.txByteCnt);

            -- Update checksum
            v.txXsum := r.txXsum + v.txData;

            -- Increment the counter
            v.txByteCnt := r.txByteCnt + 1;

            -- Check for payload
            if (r.txByteCnt /= 0) and (r.txByteCnt /= 12) then
               -- Reset the flag
               v.txDatak := '0';
            end if;

            -- Check for SOF
            if (r.txByteCnt = 0) then

               -- Set the flag
               v.enLatencyCnt := '1';

               -- Reset the counter
               v.latencyCnt := (others => '0');

            end if;

            -- Check for header
            if (r.txByteCnt = 1) then
               -- Init the checksum value
               v.txXsum := r.txMsg(1);
            end if;

            -- Check for checksum
            if (r.txByteCnt = 11) then
               -- Send the checksum value (-- one's complement)
               v.txData    := not(r.txXsum);
               v.txMsg(11) := not(r.txXsum);  -- Save the value for debugging
               -- Don't update txXsum (sim debug only)
               v.txXsum    := r.txXsum;
            end if;

            -- Check if EOF
            if (r.txByteCnt = 12) then
               -- Don't update txXsum (sim debug only)
               v.txXsum := r.txXsum;
            end if;

         end if;

      end if;

      -- Check for RX valid and receiving the ACK message
      if (rxValid = '1') and (r.rxByteCnt /= 13) then

         -- Check for SOF
         if (rxDataK = '1') and (rxData = CODE_SOF_C) then

            -- Pre-set counter
            v.rxByteCnt := 1;

            -- Receive acknowledge message
            v.rxMsg(r.rxByteCnt) := rxData;

            -- Reset the flag
            v.enLatencyCnt := '0';

            -- Save the measurement value
            v.latency := r.latencyCnt;

         end if;

         -- Check of data payload and SOF was received
         if (rxDataK = '0') and (r.rxByteCnt /= 0) then

            -- Increment the counter
            v.rxByteCnt := r.rxByteCnt + 1;

            -- Receive acknowledge message
            v.rxMsg(r.rxByteCnt) := rxData;

            -- Update checksum
            v.rxXsum := r.rxXsum + rxData;

            -- Check for header
            if (r.rxByteCnt = 1) then
               -- Init the checksum value
               v.rxXsum := rxData;
            end if;

            -- Check for checksum
            if (r.rxByteCnt = 11) and (rxData /= not(r.rxXsum)) then
               -- Sent the footer's checksum error bit
               v.rxMsg(10)(SUGOI_FOOTER_XSUM_ERROR_C) := '1';
               -- Don't update rxXsum (sim debug only)
               v.rxXsum                               := r.rxXsum;
            end if;

         end if;

         -- Check of EOF and SOF was received
         if (rxDataK = '1') and (rxData = CODE_EOF_C) and (r.rxByteCnt /= 0) then

            -- Increment the counter
            v.rxByteCnt := r.rxByteCnt + 1;

            -- Receive acknowledge message
            v.rxMsg(r.rxByteCnt) := rxData;

         end if;

      end if;

      -- Determine the transaction type
      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      -- Update the variables
      axilResp := (others => '0');
      RnW      := '0';
      addr     := (others => '0');
      devIdx   := 0;

      -- Check for Read TXN
      if (axilEp.axiStatus.readEnable = '1') then
         RnW                              := '1';
         addr(NUM_ADDR_BITS_G-1 downto 0) := axilReadMaster.araddr(NUM_ADDR_BITS_G-1 downto 0);
         devIdx                           := conv_integer(axilReadMaster.araddr(3+NUM_ADDR_BITS_G downto NUM_ADDR_BITS_G));
      end if;

      -- Check for Write TXN
      if (axilEp.axiStatus.writeEnable = '1') then
         RnW                              := '0';
         addr(NUM_ADDR_BITS_G-1 downto 0) := axilWriteMaster.awaddr(NUM_ADDR_BITS_G-1 downto 0);
         devIdx                           := conv_integer(axilWriteMaster.awaddr(3+NUM_ADDR_BITS_G downto NUM_ADDR_BITS_G));
      end if;

      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check if device address = 0
            if (devIdx = 0) then

               axiSlaveRegister(axilEp, x"00", 0, v.disableClk);
               axiSlaveRegister(axilEp, x"04", 0, v.disableTx);
               axiSlaveRegister(axilEp, x"08", 0, v.polarityTx);
               axiSlaveRegister(axilEp, x"0C", 0, v.polarityRx);

               axiSlaveRegister(axilEp, x"10", 0, v.bypFirstBerDet);
               axiSlaveRegister(axilEp, x"14", 0, v.enUsrDlyCfg);
               axiSlaveRegister(axilEp, x"18", 0, v.usrDlyCfg);
               axiSlaveRegister(axilEp, x"1C", 0, v.lockingCntCfg);

               axiSlaveRegister(axilEp, x"20", 0, v.minEyeWidth);
               axiSlaveRegister(axilEp, x"24", 0, v.timerConfig);
               axiSlaveRegister(axilEp, x"28", 0, v.globalRstForce);  -- SW force
               axiSlaveRegister(axilEp, x"2C", 0, v.opCodeForce);  -- SW force

               axiSlaveRegisterR(axilEp, x"80", 0, r.dropTrigCnt(0));
               axiSlaveRegisterR(axilEp, x"84", 0, r.dropTrigCnt(1));
               axiSlaveRegisterR(axilEp, x"88", 0, r.dropTrigCnt(2));
               axiSlaveRegisterR(axilEp, x"8C", 0, r.dropTrigCnt(3));

               axiSlaveRegisterR(axilEp, x"90", 0, r.dropTrigCnt(4));
               axiSlaveRegisterR(axilEp, x"94", 0, r.dropTrigCnt(5));
               axiSlaveRegisterR(axilEp, x"98", 0, r.dropTrigCnt(6));
               axiSlaveRegisterR(axilEp, x"9C", 0, r.dropTrigCnt(7));

               axiSlaveRegisterR(axilEp, x"A0", 0, r.errorDetCnt);
               axiSlaveRegisterR(axilEp, x"A4", 0, r.linkUpCnt);
               axiSlaveRegisterR(axilEp, x"A8", 0, r.latency);  -- Round trip SOF latency
               axiSlaveRegisterR(axilEp, x"AC", 0, eyeWidth);

               axiSlaveRegisterR(axilEp, x"B0", 0, r.gearboxAligned);

               axiSlaveRegister(axilEp, x"FC", 0, v.rstCnt);

               -- Close the transaction
               axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);

            -- Check for read or write transactions
            elsif (axilEp.axiStatus.writeEnable = '1') or (axilEp.axiStatus.readEnable = '1') then

               -- Setup the request message
               v.txMsg(0)  := CODE_SOF_C;
               v.txMsg(1)  := toSlv(devIdx, 4) & RnW & SUGOI_VERSION_C;  --  Header
               v.txMsg(2)  := addr(31 downto 24);
               v.txMsg(3)  := addr(23 downto 16);
               v.txMsg(4)  := addr(15 downto 8);
               v.txMsg(5)  := addr(7 downto 0);
               v.txMsg(6)  := axilWriteMaster.wData(31 downto 24);
               v.txMsg(7)  := axilWriteMaster.wData(23 downto 16);
               v.txMsg(8)  := axilWriteMaster.wData(15 downto 8);
               v.txMsg(9)  := axilWriteMaster.wData(7 downto 0);
               v.txMsg(10) := x"00";    -- Footer
               v.txMsg(11) := x"00";    -- checksum
               v.txMsg(12) := CODE_EOF_C;

               -- Reset the counter
               v.rxByteCnt := 0;
               v.txByteCnt := 0;

               -- Start the timer
               v.timer := r.timerConfig;

               -- Next state
               v.state := TXN_S;

            end if;
         ----------------------------------------------------------------------
         when TXN_S =>
            -- Check for timeout or acknowledgment received
            if (r.timer = 0) or (r.rxByteCnt = 13) then

               -- Pre-set counters
               v.rxByteCnt := 13;
               v.txByteCnt := 13;

               -- Check for timeout
               if (r.timer = 0) then
                  axilResp(1) := '1';
               end if;

               -- Check for mismatch in SOF/EOF
               if (r.rxMsg(0) /= CODE_SOF_C) or (r.rxMsg(12) /= CODE_EOF_C) then
                  axilResp(1) := '1';
               end if;

               -- Check for mismatch if frame size
               if (r.rxByteCnt /= 13) then
                  axilResp(1) := '1';
               end if;

               -- Check for mismatch in Version
               if (r.rxMsg(1)(SUGOI_HDR_VERSION_FIELD_C) /= SUGOI_VERSION_C) then
                  axilResp(1) := '1';
               end if;

               -- Check for mismatch in operation type
               if (r.rxMsg(1)(SUGOI_HDR_OP_TYPE_C) /= r.txMsg(1)(SUGOI_HDR_OP_TYPE_C)) then
                  axilResp(1) := '1';
               end if;

               -- Check for dev address not processed
               if (r.rxMsg(1)(SUGOI_HDR_DDEV_ID_FIELD_C) /= 0) then
                  axilResp(1) := '1';
               end if;

               -- Check for wrong address echo'd back
               if (r.rxMsg(2) /= r.txMsg(2)) or (r.rxMsg(3) /= r.txMsg(3)) or (r.rxMsg(4) /= r.txMsg(4)) or (r.rxMsg(5) /= r.txMsg(5)) then
                  axilResp(0) := '1';
               end if;

               -- If write operation, check if wrong data echo'd back
               if (r.txMsg(1)(4) = '0') then
                  if (r.rxMsg(6) /= r.txMsg(6)) or (r.rxMsg(7) /= r.txMsg(7)) or (r.rxMsg(8) /= r.txMsg(8)) or (r.rxMsg(9) /= r.txMsg(9)) then
                     axilResp(0) := '1';
                  end if;
               end if;

               -- Check for non-zero footer
               if (r.rxMsg(10) /= 0) then
                  axilResp(0) := '1';
               end if;

               -- Check for read operation
               if (r.txMsg(1)(SUGOI_HDR_OP_TYPE_C) = '1') then
                  -- Forward the readout data
                  v.axilReadSlave.rdata := r.rxMsg(6) & r.rxMsg(7) & r.rxMsg(8) & r.rxMsg(9);
                  -- Send AXI-Lite response
                  axiSlaveReadResponse(v.axilReadSlave, axilResp);
               -- Else write operation
               else
                  -- Send AXI-Lite response
                  axiSlaveWriteResponse(v.axilWriteSlave, axilResp);
               end if;

               -- Next state
               v.state := RESP_S;

            end if;
         ----------------------------------------------------------------------
         when RESP_S =>
            -- Check for read operation
            if (r.txMsg(1)(SUGOI_HDR_OP_TYPE_C) = '1') then

               -- Closeout TXN
               axiSlaveWaitReadTxn(axilReadMaster, v.axilReadSlave, axilEp.axiStatus.readEnable);

               -- Check if TXN completed
               if (r.axilReadSlave.rvalid = '1') then
                  -- Next state
                  v.state := IDLE_S;
               end if;

            -- Else write operation
            else

               -- Closeout TXN
               axiSlaveWaitWriteTxn(axilWriteMaster, v.axilWriteSlave, axilEp.axiStatus.writeEnable);

               -- Check if TXN completed
               if (r.axilWriteSlave.bvalid = '1') then
                  -- Next state
                  v.state := IDLE_S;
               end if;

            end if;
      ----------------------------------------------------------------------
      end case;

      -- Check for error event
      v.errorDet := errorDet;
      if (r.errorDet = '0') and (v.errorDet = '1') and (r.errorDetCnt /= MAX_CNT_C) then
         v.errorDetCnt := r.errorDetCnt + 1;
      end if;

      -- Check for error event
      v.gearboxAligned := gearboxAligned;
      if (r.gearboxAligned = '0') and (v.gearboxAligned = '1') and (r.linkUpCnt /= MAX_CNT_C) then
         v.linkUpCnt := r.linkUpCnt + 1;
      end if;

      -- Check for counter reset
      if (r.rstCnt = '1') then
         v.dropTrigCnt := (others => (others => '0'));
         v.errorDetCnt := (others => '0');
         v.linkUpCnt   := (others => '0');
      end if;

      -- Outputs
      axilReadSlave  <= r.axilReadSlave;
      axilWriteSlave <= r.axilWriteSlave;
      txStrobe       <= r.txStrobe;
      txData         <= r.txData;
      txDataK        <= r.txDataK;
      disableClk     <= r.disableClk;
      disableTx      <= r.disableTx;
      polarityTx     <= r.polarityTx;
      polarityRx     <= r.polarityRx;
      enUsrDlyCfg    <= r.enUsrDlyCfg;
      usrDlyCfg      <= r.usrDlyCfg;
      bypFirstBerDet <= r.bypFirstBerDet;
      minEyeWidth    <= r.minEyeWidth;
      lockingCntCfg  <= r.lockingCntCfg;

      -- Synchronous Reset
      if (RST_ASYNC_G = false and rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (clk, rst) is
   begin
      -- Asynchronous Reset
      if (RST_ASYNC_G and rst = '1') then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
