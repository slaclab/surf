-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: https://www.nxp.com/docs/en/data-sheet/SC18IS602B.pdf
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
use surf.AxiLitePkg.all;
use surf.I2cPkg.all;

entity LeapXcvrCore is
   generic (
      TPD_G           : time            := 1 ns;
      I2C_BASE_ADDR_G : slv(3 downto 0) := "0000";      -- A[3:0] pin config
      I2C_SCL_FREQ_G  : real            := 100.0E+3;    -- units of Hz
      I2C_MIN_PULSE_G : real            := 100.0E-9;    -- units of seconds
      AXIL_CLK_FREQ_G : real            := 156.25E+6);  -- units of Hz
   port (
      -- I2C Ports
      i2ci            : in  i2c_in_type;
      i2co            : out i2c_out_type;
      -- Optional I/O Ports
      intL            : in  sl := '1';
      rstL            : out sl;
      -- AXI-Lite Register Interface
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      -- Clocks and Resets
      axilClk         : in  sl;
      axilRst         : in  sl);
end LeapXcvrCore;

architecture rtl of LeapXcvrCore is

   -- Note: PRESCALE_G = (clk_freq / (5 * i2c_freq)) - 1
   --       FILTER_G = (min_pulse_time / clk_period) + 1
   constant I2C_SCL_5xFREQ_C : real    := 5.0 * I2C_SCL_FREQ_G;
   constant PRESCALE_C       : natural := (getTimeRatio(AXIL_CLK_FREQ_G, I2C_SCL_5xFREQ_C)) - 1;
   constant FILTER_C         : natural := natural(AXIL_CLK_FREQ_G * I2C_MIN_PULSE_G) + 1;

   constant TIMEOUT_C : natural := getTimeRatio(40.0E-3, (1.0/AXIL_CLK_FREQ_G))-1;

   type StateType is (
      BOOT_CONFIG_S,
      IDLE_S,
      PAGE_REQ_S,
      PAGE_ACK_S,
      DATA_REQ_S,
      DATA_ACK_S,
      WAIT_S);

   type RegType is record
      timer          : natural range 0 to TIMEOUT_C;
      reset          : sl;
      booting        : sl;
      axiRd          : sl;
      txSel          : sl;
      data           : slv(7 downto 0);
      addr           : slv(7 downto 0);
      page           : slv(7 downto 0);
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
      regIn          : I2cRegMasterInType;
      state          : StateType;
   end record;

   constant REG_INIT_C : RegType := (
      timer          => 0,
      reset          => '0',
      booting        => '1',
      axiRd          => '0',
      txSel          => '0',
      data           => (others => '0'),
      addr           => (others => '0'),
      page           => (others => '0'),
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      regIn          => I2C_REG_MASTER_IN_INIT_C,
      state          => BOOT_CONFIG_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal regOut : I2cRegMasterOutType;

   -- attribute dont_touch           : string;
   -- attribute dont_touch of r      : signal is "TRUE";
   -- attribute dont_touch of regOut : signal is "TRUE";

begin

   comb : process (axilReadMaster, axilRst, axilWriteMaster, r, regOut) is
      variable v          : regType;
      variable axilStatus : AxiLiteStatusType;
      variable axilResp   : slv(1 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Check the timer
      if (r.timer /= 0) then
         -- Decrement the timer
         v.timer := r.timer - 1;
      end if;

      -- Determine the transaction type
      axiSlaveWaitTxn(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus);

      -- Update the AXI-Lite response
      axilResp := ite(regOut.regFail = '1', AXI_RESP_SLVERR_C, AXI_RESP_OK_C);

      -- State Machine
      case (r.state) is

         ----------------------------------------------------------------------
         when BOOT_CONFIG_S =>
            -------------------------------------------------------
            -- "place holder" for adding this feature in the future
            -------------------------------------------------------

            -- Set the flag
            v.axiRd := '0';

            -- Reset the flag
            v.booting := '0';

            -- Next State
            v.state := IDLE_S;
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check if write transaction
            if (axilStatus.writeEnable = '1') then

               -- Set the flag
               v.axiRd := '0';

               -- Save the data/address
               v.data  := axilWriteMaster.wdata(7 downto 0);
               v.addr  := axilWriteMaster.awaddr(9 downto 2);
               v.page  := b"000_0000" & axilWriteMaster.awaddr(10);
               v.txSel := axilWriteMaster.awaddr(11);

               -- Check for Reset register access
               if (axilWriteMaster.awaddr(11 downto 2) = 0) then

                  -- Set reset output
                  v.reset := axilWriteMaster.wdata(0);

                  -- Send AXI-Lite response
                  axiSlaveWriteResponse(v.axilWriteSlave, AXI_RESP_OK_C);

               else
                  -- Next State
                  v.state := PAGE_REQ_S;
               end if;

            -- Check if read transaction
            elsif (axilStatus.readEnable = '1') then

               -- Set the flag
               v.axiRd := '1';

               -- Save the address
               v.addr  := axilReadMaster.araddr(9 downto 2);
               v.page  := b"000_0000" & axilReadMaster.araddr(10);
               v.txSel := axilReadMaster.araddr(11);

               -- Check for Reset register access
               if (axilReadMaster.araddr(11 downto 2) = 0) then

                  -- Forward the readout data
                  v.axilReadSlave.rdata(0) := r.reset;

                  -- Send AXI-Lite response
                  axiSlaveReadResponse(v.axilReadSlave, AXI_RESP_OK_C);

               else
                  -- Next State
                  v.state := PAGE_REQ_S;
               end if;

            end if;
         ----------------------------------------------------------------------
         when PAGE_REQ_S =>
            -- Check if I2C FSM is ready
            if regOut.regAck = '0' then

               -- Set the I2C hardware address
               v.regIn.i2cAddr := ("000" & "10" & r.TxSel & I2C_BASE_ADDR_G);

               -- Set the PAGE address
               v.regIn.regAddr(7 downto 0) := x"7F";

               -- Set the new page location
               v.regIn.regWrData(7 downto 0) := r.page;

               -- 1 for I2C write operation
               v.regIn.regOp := '1';

               -- Start the transaction
               v.regIn.regReq := '1';

               -- Next State
               v.state := PAGE_ACK_S;

            end if;
         ----------------------------------------------------------------------
         when PAGE_ACK_S =>
            -- Wait for completion
            if regOut.regAck = '1' then

               -- Reset the flag
               v.regIn.regReq := '0';

               -- Default next state
               v.state := DATA_REQ_S;

               -- Check if not booting and I2C failure
               if (r.booting = '0') and (regOut.regFail = '1') then

                  -- Check if read transaction type
                  if (r.axiRd = '1') then
                     -- Send the read response
                     axiSlaveReadResponse(v.axilReadSlave, axilResp);
                  else
                     -- Send the write response
                     axiSlaveWriteResponse(v.axilWriteSlave, axilResp);
                  end if;

                  -- Next state
                  v.state := IDLE_S;

               end if;

            end if;
         ----------------------------------------------------------------------
         when DATA_REQ_S =>
            -- Check if I2C FSM is ready
            if regOut.regAck = '0' then

               -- Set the PAGE address
               v.regIn.regAddr(7 downto 0) := r.addr;

               -- Set the new page location
               v.regIn.regWrData(7 downto 0) := r.data;

               -- 1 for I2C write operation, 0 for I2C read operation
               v.regIn.regOp := not(r.axiRd);

               -- Start the transaction
               v.regIn.regReq := '1';

               -- Next State
               v.state := DATA_ACK_S;

            end if;
         ----------------------------------------------------------------------
         when DATA_ACK_S =>
            -- Wait for completion
            if regOut.regAck = '1' then

               -- Reset the flag
               v.regIn.regReq := '0';

               -- Check for write operation
               if (r.regIn.regOp = '1') then
                  v.timer := TIMEOUT_C;
               end if;

               -- Check if not booting
               if (r.booting = '0') then

                  -- Check if read transaction type
                  if (r.axiRd = '1') then

                     -- Forward the readout data
                     v.axilReadSlave.rdata := regOut.regRdData;

                     -- Send the read response
                     axiSlaveReadResponse(v.axilReadSlave, axilResp);

                  else
                     -- Send the write response
                     axiSlaveWriteResponse(v.axilWriteSlave, axilResp);
                  end if;

               end if;

               -- Next state
               v.state := WAIT_S;

            end if;
         ----------------------------------------------------------------------
         when WAIT_S =>
            -- Check for timeout
            if (r.timer = 0) then

               -- Check if booting
               if (r.booting = '1') then
                  -- Next state
                  v.state := BOOT_CONFIG_S;
               else
                  -- Next state
                  v.state := IDLE_S;
               end if;

            end if;
      ----------------------------------------------------------------------
      end case;

      -- Outputs
      rstL           <= not(r.reset) or not(axilRst);
      axilReadSlave  <= r.axilReadSlave;
      axilWriteSlave <= r.axilWriteSlave;

      -- Synchronous Reset
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

   U_I2cRegMaster : entity surf.I2cRegMaster
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

end rtl;
