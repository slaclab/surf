-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: http://pmbus.org/Assets/PDFS/Public/PMBus_Specification_Part_II_Rev_1-1_20070205.pdf
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

entity AxiLitePMbusMasterCore is
   generic (
      TPD_G           : time            := 1 ns;
      I2C_ADDR_G      : slv(6 downto 0) := "1010000";
      I2C_SCL_FREQ_G  : real            := 100.0E+3;    -- units of Hz
      I2C_MIN_PULSE_G : real            := 100.0E-9;    -- units of seconds
      AXI_CLK_FREQ_G  : real            := 156.25E+6);  -- units of Hz
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
end AxiLitePMbusMasterCore;

architecture rtl of AxiLitePMbusMasterCore is

   -- BIT2 = regAddrSkip, BIT[1:0] = regDataSize
   type AccessArray is array (0 to 255) of slv(2 downto 0);

   -- Refer to Table 26 in http://pmbus.org/Assets/PDFS/Public/PMBus_Specification_Part_II_Rev_1-1_20070205.pdf
   constant ACCESS_ROM_C : AccessArray := (
      16#00# to 16#02# => "000",
      16#03# to 16#03# => "100",
      16#04# to 16#10# => "000",
      16#11# to 16#12# => "100",
      16#13# to 16#14# => "000",
      16#15# to 16#16# => "100",
      16#17# to 16#20# => "000",
      16#21# to 16#39# => "001",
      16#3A# to 16#3A# => "000",
      16#3B# to 16#3C# => "001",
      16#3D# to 16#3D# => "000",
      16#3E# to 16#40# => "001",
      16#41# to 16#41# => "000",
      16#42# to 16#44# => "001",
      16#45# to 16#45# => "000",
      16#46# to 16#46# => "001",
      16#47# to 16#47# => "000",
      16#48# to 16#48# => "001",
      16#49# to 16#49# => "000",
      16#4A# to 16#4B# => "001",
      16#4C# to 16#4E# => "000",
      16#4F# to 16#4F# => "001",
      16#50# to 16#50# => "000",
      16#51# to 16#53# => "001",
      16#54# to 16#54# => "000",
      16#55# to 16#55# => "001",
      16#56# to 16#56# => "000",
      16#57# to 16#59# => "001",
      16#5A# to 16#5A# => "000",
      16#5B# to 16#5B# => "001",
      16#5C# to 16#5C# => "000",
      16#5D# to 16#62# => "001",
      16#63# to 16#63# => "000",
      16#64# to 16#68# => "001",
      16#69# to 16#69# => "000",
      16#6A# to 16#6B# => "001",
      16#6C# to 16#78# => "000",
      16#79# to 16#79# => "001",
      16#7A# to 16#87# => "000",
      16#88# to 16#97# => "001",
      16#98# to 16#98# => "000",
      16#99# to 16#9F# => "011",
      16#A0# to 16#A9# => "001",
      16#AA# to 16#FF# => "000");

   -- Note: PRESCALE_G = (clk_freq / (5 * i2c_freq)) - 1
   --       FILTER_G = (min_pulse_time / clk_period) + 1
   constant I2C_SCL_5xFREQ_C : real    := 5.0 * I2C_SCL_FREQ_G;
   constant PRESCALE_C       : natural := (getTimeRatio(AXI_CLK_FREQ_G, I2C_SCL_5xFREQ_C)) - 1;
   constant FILTER_C         : natural := natural(AXI_CLK_FREQ_G * I2C_MIN_PULSE_G) + 1;

   constant I2C_ADDR_C : slv(9 downto 0) := ("000" & I2C_ADDR_G);

   constant MY_I2C_REG_MASTER_IN_INIT_C : I2cRegMasterInType := (
      i2cAddr     => I2C_ADDR_C,
      tenbit      => '0',
      regAddr     => (others => '0'),
      regWrData   => (others => '0'),
      regOp       => '0',               -- 1 for write, 0 for read
      regAddrSkip => '0',
      regAddrSize => "00",              -- 0x0 = 1 byte address
      regDataSize => "00",              -- dynamic
      regReq      => '0',
      busReq      => '0',
      endianness  => '0',               -- Little endian
      repeatStart => '1',
      wrDataOnRd  => '0');

   type StateType is (
      IDLE_S,
      READ_ACK_S,
      WRITE_ACK_S);

   type RegType is record
      ignoreResp     : sl;
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
      regIn          : I2cRegMasterInType;
      state          : StateType;
   end record;

   constant REG_INIT_C : RegType := (
      ignoreResp     => '1',
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

   attribute rom_style                   : string;
   attribute rom_style of ACCESS_ROM_C   : constant is "distributed";
   attribute rom_extract                 : string;
   attribute rom_extract of ACCESS_ROM_C : constant is "TRUE";
   attribute syn_keep                    : string;
   attribute syn_keep of ACCESS_ROM_C    : constant is "TRUE";

begin

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

   comb : process (axilReadMaster, axilRst, axilWriteMaster, r, regOut) is
      variable v          : regType;
      variable axilStatus : AxiLiteStatusType;
      variable axilResp   : slv(1 downto 0);
      variable wrIdx      : natural;
      variable rdIdx      : natural;
   begin
      -- Latch the current value
      v := r;

      -- Update the variables
      wrIdx := conv_integer(axilWriteMaster.awaddr(9 downto 2));
      rdIdx := conv_integer(axilReadMaster.araddr(9 downto 2));

      -- Determine the transaction type
      axiSlaveWaitTxn(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus);

      -- Update the AXI-Lite response
      axilResp := ite((regOut.regFail = '1' and r.ignoreResp = '0'), AXI_RESP_SLVERR_C, AXI_RESP_OK_C);

      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when IDLE_S =>
            if regOut.regAck = '0' then
               -- Check for a write request
               if (axilStatus.writeEnable = '1') then

                  -- Check for I2C data Access
                  if (axilWriteMaster.awaddr(10) = '0') then

                     -- Send read transaction to I2cRegMaster
                     v.regIn.regReq      := '1';
                     v.regIn.regOp       := '1';  -- 1 for write operation
                     v.regIn.regAddrSkip := ACCESS_ROM_C(wrIdx)(2);
                     v.regIn.regDataSize := ACCESS_ROM_C(wrIdx)(1 downto 0);

                     -- Check if not skipping address
                     if (v.regIn.regAddrSkip = '0') then

                        -- Normal Access
                        v.regIn.regAddr(7 downto 0) := axilWriteMaster.awaddr(9 downto 2);
                        v.regIn.regWrData           := axilWriteMaster.wData;

                     -- Else skipping address
                     else

                        -- Send the address into the data
                        v.regIn.regWrData := x"0000_00" & axilWriteMaster.awaddr(9 downto 2);

                        -- Force 1 byte transaction
                        v.regIn.regDataSize := "00";

                     end if;

                     -- Next state
                     v.state := WRITE_ACK_S;

                  -- Else I2C config Access
                  else

                     -- Read back I2C configuration
                     if axilWriteMaster.awaddr(7 downto 0) = x"00" then
                        v.regIn.i2cAddr := axilWriteMaster.wData(9 downto 0);
                        v.regIn.tenbit  := axilWriteMaster.wData(10);
                        v.ignoreResp    := axilWriteMaster.wData(11);
                     end if;

                     -- Send AXI-Lite response
                     axiSlaveWriteResponse(v.axilWriteSlave, AXI_RESP_OK_C);

                  end if;

               -- Check for a read request
               elsif (axilStatus.readEnable = '1') then

                  -- Check for I2C data Access
                  if (axilReadMaster.araddr(10) = '0') then

                     -- Send read transaction to I2cRegMaster
                     v.regIn.regReq              := '1';
                     v.regIn.regOp               := '0';  -- 0 for read operation
                     v.regIn.regAddrSkip         := ACCESS_ROM_C(rdIdx)(2);
                     v.regIn.regDataSize         := ACCESS_ROM_C(rdIdx)(1 downto 0);
                     v.regIn.regAddr(7 downto 0) := axilReadMaster.araddr(9 downto 2);

                     -- Next state
                     v.state := READ_ACK_S;

                  -- Else I2C config Access
                  else

                     -- Read back I2C configuration
                     if axilReadMaster.araddr(7 downto 0) = x"00" then
                        v.axilReadSlave.rdata(9 downto 0) := r.regIn.i2cAddr;
                        v.axilReadSlave.rdata(10)         := r.regIn.tenbit;
                        v.axilReadSlave.rdata(11)         := r.ignoreResp;
                     end if;

                     -- Send AXI-Lite response
                     axiSlaveReadResponse(v.axilReadSlave, AXI_RESP_OK_C);

                  end if;

               end if;
            end if;
         ----------------------------------------------------------------------
         when READ_ACK_S =>
            -- Wait for completion
            if regOut.regAck = '1' then

               -- Reset the flag
               v.regIn.regReq := '0';

               -- Check for I2C failure
               if regOut.regFail = '1' and r.ignoreResp = '0' then
                  -- Forward error code on the data bus for debugging
                  v.axilReadSlave.rdata := X"000000" & regOut.regFailCode;

               elsif regOut.regFail = '1' and r.ignoreResp = '1' then
                  -- Return zeros if ignoring the response
                  v.axilReadSlave.rdata := (others => '0');

               else
                  -- Forward the readout data
                  v.axilReadSlave.rdata := regOut.regRdData;

               end if;

               -- Next state
               v.state := IDLE_S;

               -- Send AXI-Lite response
               axiSlaveReadResponse(v.axilReadSlave, axilResp);

            end if;
         ----------------------------------------------------------------------
         when WRITE_ACK_S =>
            -- Wait for completion
            if regOut.regAck = '1' then

               -- Reset the flag
               v.regIn.regReq := '0';

               -- Send AXI-Lite response
               axiSlaveWriteResponse(v.axilWriteSlave, axilResp);

               -- Next state
               v.state := IDLE_S;

            end if;
      ----------------------------------------------------------------------
      end case;

      -- Outputs
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

end rtl;
