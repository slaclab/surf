-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: SPI Master Wrapper that includes a state machine for SPI paging
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
use surf.I2cPkg.all;

entity Si5394I2cCore is
   generic (
      TPD_G              : time            := 1 ns;
      MEMORY_INIT_FILE_G : string          := "none";      -- Used to initialization boot ROM
      I2C_BASE_ADDR_G    : slv(1 downto 0) := "00";        -- A[1:0] pin config
      I2C_SCL_FREQ_G     : real            := 100.0E+3;    -- units of Hz
      I2C_MIN_PULSE_G    : real            := 100.0E-9;    -- units of seconds
      AXIL_CLK_FREQ_G    : real            := 156.25E+6);  -- units of Hz
   port (
      -- I2C Ports
      i2ci            : in  i2c_in_type;
      i2co            : out i2c_out_type;
      -- Misc Interface
      irqL            : in  sl;
      lolL            : in  sl;
      losL            : in  sl;
      rstL            : out sl;
      booting         : out sl;
      -- AXI-Lite Register Interface
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      -- Clocks and Resets
      axilClk         : in  sl;
      axilRst         : in  sl);
end entity Si5394I2cCore;

architecture rtl of Si5394I2cCore is

   constant BOOT_ROM_C : boolean := (MEMORY_INIT_FILE_G /= "none");

   -- Note: PRESCALE_G = (clk_freq / (5 * i2c_freq)) - 1
   --       FILTER_G = (min_pulse_time / clk_period) + 1
   constant I2C_SCL_5xFREQ_C : real    := 5.0 * I2C_SCL_FREQ_G;
   constant PRESCALE_C       : natural := (getTimeRatio(AXIL_CLK_FREQ_G, I2C_SCL_5xFREQ_C)) - 1;
   constant FILTER_C         : natural := natural(AXIL_CLK_FREQ_G * I2C_MIN_PULSE_G) + 1;

   constant I2C_ADDR_C : slv(9 downto 0) := ("000" & "11010" & I2C_BASE_ADDR_G);

   --------------------------------------------------------------------
   -- Wait 300 ms for Grade A/B/C/D/J/K/L/M, Wait 625ms for Grade P/E
   --------------------------------------------------------------------
   constant TIMEOUT_CAL_C : natural := getTimeRatio(625.0E-3, (1.0/AXIL_CLK_FREQ_G))-1;

   -----------------------------------------------------------
   -- T_buf = Bus Free Time between a STOP and START Condition
   -----------------------------------------------------------
   constant TIMEOUT_I2C_C : natural := getTimeRatio(10.00E-6, (1.0/AXIL_CLK_FREQ_G))-1;

   constant MY_I2C_REG_MASTER_IN_INIT_C : I2cRegMasterInType := (
      i2cAddr     => I2C_ADDR_C,
      tenbit      => '0',
      regAddr     => (others => '0'),
      regWrData   => (others => '0'),
      regOp       => '0',               -- 1 for write, 0 for read
      regAddrSkip => '0',
      regAddrSize => "00",
      regDataSize => "00",
      regReq      => '0',
      busReq      => '0',
      endianness  => '0',
      repeatStart => '0',
      wrDataOnRd  => '0');

   type StateType is (
      POR_WAIT_S,
      BOOT_ROM_S,
      IDLE_S,
      PAGE_REQ_S,
      PAGE_ACK_S,
      DATA_REQ_S,
      DATA_ACK_S);

   type RegType is record
      timer          : natural range 0 to TIMEOUT_CAL_C;
      axiRd          : sl;
      ramAddr        : slv(9 downto 0);
      booting        : sl;
      data           : slv(7 downto 0);
      addr           : slv(7 downto 0);
      page           : slv(7 downto 0);
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
      regIn          : I2cRegMasterInType;
      state          : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      timer          => TIMEOUT_CAL_C,  -- POR wait is max 35 ms < TIMEOUT_CAL_C = 625 ms
      axiRd          => '0',
      ramAddr        => (others => '0'),
      booting        => ite(BOOT_ROM_C, '1', '0'),
      data           => (others => '0'),
      addr           => (others => '0'),
      page           => (others => '0'),
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      regIn          => MY_I2C_REG_MASTER_IN_INIT_C,
      state          => POR_WAIT_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal ramData : slv(19 downto 0) := (others => '0');

   signal regOut : I2cRegMasterOutType;

   -- attribute dont_touch            : string;
   -- attribute dont_touch of r       : signal is "TRUE";
   -- attribute dont_touch of regOut  : signal is "TRUE";
   -- attribute dont_touch of ramData : signal is "TRUE";

begin

   GEN_BOOT_ROM : if BOOT_ROM_C generate
      U_ROM : entity surf.SimpleDualPortRamXpm
         generic map (
            TPD_G               => TPD_G,
            COMMON_CLK_G        => true,
            MEMORY_TYPE_G       => "block",
            MEMORY_INIT_FILE_G  => MEMORY_INIT_FILE_G,
            MEMORY_INIT_PARAM_G => "",
            READ_LATENCY_G      => 1,
            DATA_WIDTH_G        => 20,
            ADDR_WIDTH_G        => 10)
         port map (
            -- Port A
            clka  => axilClk,
            -- Port B
            clkb  => axilClk,
            addrb => r.ramAddr,
            doutb => ramData);
   end generate;

   comb : process (axilReadMaster, axilRst, axilWriteMaster, r, ramData,
                   regOut) is
      variable v          : RegType;
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

      -- Get the AXI-Lite status
      axiSlaveWaitTxn(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus);

      -- Update the AXI-Lite response
      axilResp := ite(regOut.regFail = '1', AXI_RESP_SLVERR_C, AXI_RESP_OK_C);

      -- Check for timeout
      if (r.timer = 0) then

         -- State Machine
         case r.state is
            ----------------------------------------------------------------------
            when POR_WAIT_S =>
               -- Check if booting
               if (r.booting = '1') then
                  -- Next state
                  v.state := BOOT_ROM_S;
               else
                  -- Next state
                  v.state := IDLE_S;
               end if;
            ----------------------------------------------------------------------
            when BOOT_ROM_S =>
               -- Set the flag
               v.axiRd := '0';

               -- Save the data/address
               v.data := ramData(7 downto 0);
               v.addr := ramData(15 downto 8);
               v.page := x"0" & ramData(19 downto 16);

               -- Increment the counter
               v.ramAddr := r.ramAddr + 1;

               -- Check for forced timeout condition
               if (ramData = x"FF_FFFF_FFFF") then
                  -- Init the timer
                  v.timer := TIMEOUT_CAL_C;

               -- Check for empty transaction or roll over of counter
               elsif (ramData /= 0) and (v.ramAddr /= 0) then
                  -- Next State
                  v.state := PAGE_REQ_S;

               else

                  -- Reset the counter
                  v.ramAddr := (others => '0');

                  -- Reset the flag
                  v.booting := '0';

                  -- Next State
                  v.state := IDLE_S;

               end if;
            ----------------------------------------------------------------------
            when IDLE_S =>
               -- Check if write transaction
               if (axilStatus.writeEnable = '1') then

                  -- Set the flag
                  v.axiRd := '0';

                  -- Save the data/address
                  v.data := axilWriteMaster.wdata(7 downto 0);
                  v.addr := axilWriteMaster.awaddr(9 downto 2);
                  v.page := x"0" & axilWriteMaster.awaddr(13 downto 10);

                  -- Next State
                  v.state := PAGE_REQ_S;

               -- Check if read transaction
               elsif (axilStatus.readEnable = '1') then

                  -- Set the flag
                  v.axiRd := '1';

                  -- Save the address
                  v.addr := axilReadMaster.araddr(9 downto 2);
                  v.page := x"0" & axilReadMaster.araddr(13 downto 10);

                  -- Next State
                  v.state := PAGE_REQ_S;

               end if;
            ----------------------------------------------------------------------
            when PAGE_REQ_S =>
               -- Check if I2C FSM is ready
               if regOut.regAck = '0' then

                  -- Set the PAGE address
                  v.regIn.regAddr(7 downto 0) := x"01";

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

                  -- Init the timer
                  v.timer := TIMEOUT_I2C_C;

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

                  -- Init the timer
                  v.timer := TIMEOUT_I2C_C;

                  -- Check if booting
                  if (r.booting = '1') then

                     -- Next state
                     v.state := BOOT_ROM_S;

                  else

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

                     -- Next state
                     v.state := IDLE_S;

                  end if;

               end if;
         ----------------------------------------------------------------------
         end case;
      end if;

      -- Outputs
      axilWriteSlave <= r.axilWriteSlave;
      axilReadSlave  <= r.axilReadSlave;
      booting        <= r.booting;

      -- Reset
      if (axilRst = '1') then
         v := REG_INIT_C;
         if BOOT_ROM_C then
            v.state := BOOT_ROM_S;
         else
            v.state := IDLE_S;
         end if;
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

   U_rstL : entity surf.PwrUpRst
      generic map(
         TPD_G          => TPD_G,
         DURATION_G     => getTimeRatio(100.0E-9, (1.0/AXIL_CLK_FREQ_G)),  -- min 100 ns pulse
         IN_POLARITY_G  => '1',                                            -- active HIGH input
         OUT_POLARITY_G => '0')                                            -- active LOW output
      port map (
         clk    => axilClk,
         arst   => axilRst,
         rstOut => rstL);

end rtl;
