-------------------------------------------------------------------------------
-- File       : AxiI2cEepromCore.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-07-11
-- Last update: 2016-09-20
-------------------------------------------------------------------------------
-- Description: AXI-Lite Read/ModifyWrite for standard EEPROM Module
--
-- Supported Devices:   
--    24AA01F/24LC01F/24FC01F    (1kb:   ADDR_WIDTH_G = 7)
--    24AA02F/24LC02F/24FC02F    (2kb:   ADDR_WIDTH_G = 8)
--    24AA04F/24LC04F/24FC04F    (4kb:   ADDR_WIDTH_G = 9)
--    24AA08F/24LC08F/24FC08F    (8kb:   ADDR_WIDTH_G = 10)
--    24AA16F/24LC16F/24FC16F    (16kb:  ADDR_WIDTH_G = 11)
--    24AA32F/24LC32F/24FC32F    (32kb:  ADDR_WIDTH_G = 12)
--    24AA64F/24LC64F/24FC64F    (64kb:  ADDR_WIDTH_G = 13)
--    24AA128F/24LC128F/24FC128F (128kb: ADDR_WIDTH_G = 14)
--    24AA256F/24LC256F/24FC256F (256kb: ADDR_WIDTH_G = 15)
--    24AA512F/24LC512F/24FC512F (512kb: ADDR_WIDTH_G = 16)
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

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.I2cPkg.all;

library unisim;
use unisim.vcomponents.all;

entity AxiI2cEepromCore is
   generic (
      TPD_G            : time            := 1 ns;
      ADDR_WIDTH_G     : positive        := 16;
      POLL_TIMEOUT_G   : positive        := 16;
      I2C_ADDR_G       : slv(6 downto 0) := "1010000";
      I2C_SCL_FREQ_G   : real            := 100.0E+3;   -- units of Hz
      I2C_MIN_PULSE_G  : real            := 100.0E-9;   -- units of seconds
      AXI_CLK_FREQ_G   : real            := 156.25E+6;  -- units of Hz
      AXI_ERROR_RESP_G : slv(1 downto 0) := AXI_RESP_SLVERR_C);
   port (
      -- I2C Ports
      i2ci            : in  i2c_in_type;
      i2co            : out i2c_out_type;
      -- AXI-Lite Register Interface
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      -- Clocks and Resets
      axilClk         : in  sl;
      axilRst         : in  sl);     
end AxiI2cEepromCore;

architecture rtl of AxiI2cEepromCore is

   -- Note: PRESCALE_G = (clk_freq / (5 * i2c_freq)) - 1
   --       FILTER_G = (min_pulse_time / clk_period) + 1
   constant I2C_SCL_5xFREQ_C : real    := 5.0 * I2C_SCL_FREQ_G;
   constant PRESCALE_C       : natural := (getTimeRatio(AXI_CLK_FREQ_G, I2C_SCL_5xFREQ_C)) - 1;
   constant FILTER_C         : natural := natural(AXI_CLK_FREQ_G * I2C_MIN_PULSE_G) + 1;

   constant ADDR_SIZE_C : slv(1 downto 0) := toSlv(wordCount(ADDR_WIDTH_G, 8) - 1, 2);
   constant DATA_SIZE_C : slv(1 downto 0) := toSlv(wordCount(32, 8) - 1, 2);
   constant I2C_ADDR_C  : slv(9 downto 0) := ("000" & I2C_ADDR_G);
   constant TIMEOUT_C   : natural         := (getTimeRatio(AXI_CLK_FREQ_G, 200.0)) - 1;  -- 5 ms timeout   
   
   constant MY_I2C_REG_MASTER_IN_INIT_C : I2cRegMasterInType := (
      i2cAddr     => I2C_ADDR_C,
      tenbit      => '0',
      regAddr     => (others => '0'),
      regWrData   => (others => '0'),
      regOp       => '0',               -- 1 for write, 0 for read
      regAddrSkip => '0',
      regAddrSize => ADDR_SIZE_C,
      regDataSize => DATA_SIZE_C,
      regReq      => '0',
      busReq      => '0',
      endianness  => '1',               -- Big endian
      repeatStart => '0');

   type StateType is (
      IDLE_S,
      READ_ACK_S,
      READ_DONE_S,
      WRITE_REQ_S,
      WRITE_ACK_S,
      WRITE_DONE_S,
      WAIT_S);    

   type RegType is record
      timer          : natural range 0 to TIMEOUT_C;
      RnW            : sl;
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
      regIn          : I2cRegMasterInType;
      state          : StateType;
   end record;

   constant REG_INIT_C : RegType := (
      timer          => 0,
      RnW            => '0',
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      regIn          => MY_I2C_REG_MASTER_IN_INIT_C,
      state          => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal regOut : I2cRegMasterOutType;

   -- attribute dont_touch           : string;
   -- attribute dont_touch of r      : signal is "TRUE";
   -- attribute dont_touch of regOut : signal is "TRUE";
   
begin

   U_I2cRegMaster : entity work.I2cRegMaster
      generic map(
         TPD_G                => TPD_G,
         OUTPUT_EN_POLARITY_G => 0,
         FILTER_G             => FILTER_C,
         PRESCALE_G           => PRESCALE_C)
      port map (
         -- I2C Port Interface
         i2ci   => i2ci,
         i2co   => i2co,
         -- I2C Register Interface
         regIn  => r.regIn,
         regOut => regOut,
         -- Clock and Reset
         clk    => axilClk,
         srst   => axilRst);   

   comb : process (axilReadMaster, axilRst, axilWriteMaster, r, regOut) is
      variable v          : regType;
      variable axilStatus : AxiLiteStatusType;
      variable axilResp   : slv(1 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Determine the transaction type
      axiSlaveWaitTxn(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus);

      -- Update the AXI-Lite response
      axilResp := ite(regOut.regFail = '1', AXI_ERROR_RESP_G, AXI_RESP_OK_C);

      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when IDLE_S =>
            if regOut.regAck = '0' then
               -- Check for a write request
               if (axilStatus.writeEnable = '1') then
                  -- Set the flag
                  v.RnW                                    := '0';
                  -- Send read transaction to I2cRegMaster
                  v.regIn.regReq                           := '1';
                  v.regIn.regOp                            := '0';  -- Read (then modify write) operation
                  v.regIn.regAddr(ADDR_WIDTH_G-1 downto 0) := axilWriteMaster.awaddr(ADDR_WIDTH_G-1 downto 0);
                  -- Next state
                  v.state                                  := READ_ACK_S;
               -- Check for a read request            
               elsif (axilStatus.readEnable = '1') then
                  -- Set the flag
                  v.RnW                                    := '1';
                  -- Send read transaction to I2cRegMaster
                  v.regIn.regReq                           := '1';
                  v.regIn.regOp                            := '0';  -- Read operation
                  v.regIn.regAddr(ADDR_WIDTH_G-1 downto 0) := axilReadMaster.araddr(ADDR_WIDTH_G-1 downto 0);
                  -- Next state
                  v.state                                  := READ_ACK_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when READ_ACK_S =>
            -- Wait for completion
            if regOut.regAck = '1' then
               -- Reset the flag
               v.regIn.regReq := '0';
               -- Check for write operation
               if r.RnW = '0' then
                  -- Check for I2C failure
                  if regOut.regFail = '1' then
                     -- Send AXI-Lite response
                     axiSlaveWriteResponse(v.axilWriteSlave, axilResp);
                     -- Next state
                     v.state := WAIT_S;
                  -- Check if not modification required
                  elsif axilWriteMaster.wData = regOut.regRdData then
                     -- Send AXI-Lite response
                     axiSlaveWriteResponse(v.axilWriteSlave, axilResp);
                     -- Next state
                     v.state := IDLE_S;
                  else
                     -- Next state
                     v.state := READ_DONE_S;
                  end if;
               -- Else read operation
               else
                  -- Check for I2C failure
                  if regOut.regFail = '1' then
                     -- Next state
                     v.state               := WAIT_S;
                     -- Forward error code on the data bus for debugging
                     v.axilReadSlave.rdata := X"000000" & regOut.regFailCode;
                  else
                     -- Forward the readout data
                     v.axilReadSlave.rdata := regOut.regRdData;
                     -- Next state
                     v.state               := IDLE_S;
                  end if;
                  -- Send AXI-Lite response
                  axiSlaveReadResponse(v.axilReadSlave, axilResp);
               end if;
            end if;
         ----------------------------------------------------------------------
         when READ_DONE_S =>
            if regOut.regAck = '0' then
               -- Next state
               v.state := WRITE_REQ_S;
            end if;
         ----------------------------------------------------------------------
         when WRITE_REQ_S =>
            -- Send write transaction to I2cRegMaster
            v.regIn.regReq    := '1';
            v.regIn.regOp     := '1';   -- Write operation            
            v.regIn.regWrData := axilWriteMaster.wData;
            -- Next state
            v.state           := WRITE_ACK_S;
         ----------------------------------------------------------------------
         when WRITE_ACK_S =>
            -- Wait for completion
            if regOut.regAck = '1' then
               -- Reset the flag
               v.regIn.regReq := '0';
               -- Send AXI-Lite response
               axiSlaveWriteResponse(v.axilWriteSlave, axilResp);
               -- Check for I2C failure
               if regOut.regFail = '1' then
                  -- Next state
                  v.state := IDLE_S;
               else
                  -- Next state
                  v.state := WRITE_DONE_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when WRITE_DONE_S =>
            if regOut.regAck = '0' then
               -- Next state
               v.state := WAIT_S;
            end if;
         ----------------------------------------------------------------------
         when WAIT_S =>
            -- Increment the counter
            v.timer := r.timer + 1;
            -- Check counter
            if (r.timer = TIMEOUT_C) then
               -- Reset the counter
               v.timer := 0;
               -- Next state
               v.state := IDLE_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Synchronous Reset
      if (axilRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      axilReadSlave  <= r.axilReadSlave;
      axilWriteSlave <= r.axilWriteSlave;
      
   end process comb;

   seq : process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
end rtl;
