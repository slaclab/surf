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

entity Sc18Is602Core is
   generic (
      TPD_G             : time                     := 1 ns;
      I2C_BASE_ADDR_G   : slv(2 downto 0)          := "000";          -- A[2:0] pin config
      I2C_SCL_FREQ_G    : real                     := 100.0E+3;       -- units of Hz
      I2C_MIN_PULSE_G   : real                     := 100.0E-9;       -- units of seconds
      SDO_MUX_SEL_MAP_G : Slv2Array(3 downto 0)    := (0      => "00", 1 => "01", 2 => "10", 3 => "11");
      ADDRESS_SIZE_G    : IntegerArray(3 downto 0) := (others => 7);  -- SPI Address bits per channel
      DATA_SIZE_G       : IntegerArray(3 downto 0) := (others => 16);  -- SPI Data bits per channel
      AXIL_CLK_FREQ_G   : real                     := 156.25E+6);     -- units of Hz
   port (
      -- I2C Ports
      i2ci            : in  i2c_in_type;
      i2co            : out i2c_out_type;
      -- Optional MUX select for SDO
      sdoMuxSel       : out slv(1 downto 0);
      -- AXI-Lite Register Interface
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      -- Clocks and Resets
      axilClk         : in  sl;
      axilRst         : in  sl);
end Sc18Is602Core;

architecture rtl of Sc18Is602Core is

   constant ADDRESS_MAX_SIZE_C : integer := maximum(ADDRESS_SIZE_G);

   constant ADDR_SIZE_C : Slv2Array(3 downto 0) := (
      0 => toSlv(wordCount(ADDRESS_SIZE_G(0)+1, 8) - 1, 2),
      1 => toSlv(wordCount(ADDRESS_SIZE_G(1)+1, 8) - 1, 2),
      2 => toSlv(wordCount(ADDRESS_SIZE_G(2)+1, 8) - 1, 2),
      3 => toSlv(wordCount(ADDRESS_SIZE_G(3)+1, 8) - 1, 2));

   constant DATA_SIZE_C : Slv2Array(3 downto 0) := (
      0 => toSlv(wordCount(DATA_SIZE_G(0), 8) - 1, 2),
      1 => toSlv(wordCount(DATA_SIZE_G(1), 8) - 1, 2),
      2 => toSlv(wordCount(DATA_SIZE_G(2), 8) - 1, 2),
      3 => toSlv(wordCount(DATA_SIZE_G(3), 8) - 1, 2));

   constant READ_SIZE_C : Slv2Array(3 downto 0) := (
      0 => toSlv(wordCount(ADDRESS_SIZE_G(0)+1+DATA_SIZE_G(0), 8) - 1, 2),
      1 => toSlv(wordCount(ADDRESS_SIZE_G(1)+1+DATA_SIZE_G(1), 8) - 1, 2),
      2 => toSlv(wordCount(ADDRESS_SIZE_G(2)+1+DATA_SIZE_G(2), 8) - 1, 2),
      3 => toSlv(wordCount(ADDRESS_SIZE_G(3)+1+DATA_SIZE_G(3), 8) - 1, 2));

   -- Note: PRESCALE_G = (clk_freq / (5 * i2c_freq)) - 1
   --       FILTER_G = (min_pulse_time / clk_period) + 1
   constant I2C_SCL_5xFREQ_C : real    := 5.0 * I2C_SCL_FREQ_G;
   constant PRESCALE_C       : natural := (getTimeRatio(AXIL_CLK_FREQ_G, I2C_SCL_5xFREQ_C)) - 1;
   constant FILTER_C         : natural := natural(AXIL_CLK_FREQ_G * I2C_MIN_PULSE_G) + 1;

   constant I2C_ADDR_C : slv(9 downto 0) := ("000" & "0101" & I2C_BASE_ADDR_G);

   constant MY_I2C_REG_MASTER_IN_INIT_C : I2cRegMasterInType := (
      i2cAddr     => I2C_ADDR_C,
      tenbit      => '0',
      regAddr     => (others => '0'),
      regWrData   => (others => '0'),
      regOp       => '0',               -- 1 for write, 0 for read
      regAddrSkip => '0',
      regAddrSize => "00",              -- dynamic
      regDataSize => "00",              -- dynamic
      regReq      => '0',
      busReq      => '0',
      endianness  => '1',               -- Big endian
      repeatStart => '0',
      wrDataOnRd  => '0');

   type StateType is (
      IDLE_S,
      WRITE_ACK_S,
      READ_TXN_S,
      READ_REQ_S,
      READ_ACK_S);

   type RegType is record
      sdoMuxSel      : slv(1 downto 0);
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
      regIn          : I2cRegMasterInType;
      state          : StateType;
   end record;

   constant REG_INIT_C : RegType := (
      sdoMuxSel      => "00",
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

   assert (wordCount(ADDRESS_SIZE_G(0)+1+DATA_SIZE_G(0), 8) <= 4)
      report "ADDRESS_SIZE_G(0)+1+DATA_SIZE_G(0) > 4 bytes is not supported" severity failure;

   assert (wordCount(ADDRESS_SIZE_G(1)+1+DATA_SIZE_G(1), 8) <= 4)
      report "ADDRESS_SIZE_G(1)+1+DATA_SIZE_G(1) > 4 bytes is not supported" severity failure;

   assert (wordCount(ADDRESS_SIZE_G(2)+1+DATA_SIZE_G(2), 8) <= 4)
      report "ADDRESS_SIZE_G(2)+1+DATA_SIZE_G(2) > 4 bytes is not supported" severity failure;

   assert (wordCount(ADDRESS_SIZE_G(3)+1+DATA_SIZE_G(3), 8) <= 4)
      report "ADDRESS_SIZE_G(3)+1+DATA_SIZE_G(3) > 4 bytes is not supported" severity failure;

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
      wrIdx := conv_integer(axilWriteMaster.awaddr(3+ADDRESS_MAX_SIZE_C downto 2+ADDRESS_MAX_SIZE_C));
      rdIdx := conv_integer(axilReadMaster.araddr(3+ADDRESS_MAX_SIZE_C downto 2+ADDRESS_MAX_SIZE_C));

      -- Determine the transaction type
      axiSlaveWaitTxn(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus);

      -- Update the AXI-Lite response
      axilResp := ite(regOut.regFail = '1', AXI_RESP_SLVERR_C, AXI_RESP_OK_C);

      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check if I2C FSM is ready
            if regOut.regAck = '0' then

               -- Check for a write request
               if (axilStatus.writeEnable = '1') then

                  -- Set the SPI SDO Mux
                  v.sdoMuxSel := SDO_MUX_SEL_MAP_G(wrIdx);

                  -- Send write transaction to I2cRegMaster
                  v.regIn.regReq := '1';
                  v.regIn.regOp  := '1';  -- 1 for I2C write operation

                  -- Setup the reg data
                  v.regIn.regWrData := axilWriteMaster.wData;

                  -- Check for configuration path
                  if (axilWriteMaster.awaddr(4+ADDRESS_MAX_SIZE_C) = '1') then

                     -- Skip writing the address because reading out buffer
                     v.regIn.regAddrSkip := '1';

                     -- Insert the function ID
                     v.regIn.regWrData(15 downto 8) := axilWriteMaster.awaddr(9 downto 2);

                     -- Setup the reg sizes
                     v.regIn.regDataSize := "01";  -- two bytes (fucntion ID + CMD bytes)

                  else

                     -- Setup the reg address
                     v.regIn.regAddr                                   := (others => '0');
                     v.regIn.regAddr(ADDRESS_SIZE_G(wrIdx)-1 downto 0) := axilWriteMaster.awaddr(ADDRESS_SIZE_G(wrIdx)+1 downto 2);

                     -- Set the SPI R/W flag
                     v.regIn.regAddr(ADDRESS_SIZE_G(wrIdx)) := '0';  -- 0 for SPI write operation

                     -- Set the function ID
                     v.regIn.regAddr(ADDRESS_SIZE_G(wrIdx)+1+wrIdx) := '1';

                     -- Setup the reg sizes
                     v.regIn.regAddrSize := ADDR_SIZE_C(wrIdx)+1;  -- plus one for function ID byte
                     v.regIn.regDataSize := DATA_SIZE_C(wrIdx);

                  end if;

                  -- Next state
                  v.state := WRITE_ACK_S;

               -- Check for a read request
               elsif (axilStatus.readEnable = '1') then

                  -- Set the SPI SDO Mux
                  v.sdoMuxSel := SDO_MUX_SEL_MAP_G(rdIdx);

                  -- Send write transaction to I2cRegMaster
                  v.regIn.regReq := '1';
                  v.regIn.regOp  := '1';  -- 1 for I2C write operation

                  -- Setup the reg data
                  v.regIn.regWrData := (others => '1');

                  -- Setup the reg address
                  v.regIn.regAddr                                   := (others => '0');
                  v.regIn.regAddr(ADDRESS_SIZE_G(rdIdx)-1 downto 0) := axilReadMaster.araddr(ADDRESS_SIZE_G(rdIdx)+1 downto 2);

                  -- Set the SPI R/W flag
                  v.regIn.regAddr(ADDRESS_SIZE_G(rdIdx)) := '1';  -- 1 for SPI read operation

                  -- Set the function ID
                  v.regIn.regAddr(ADDRESS_SIZE_G(rdIdx)+1+rdIdx) := '1';

                  -- Setup the reg sizes
                  v.regIn.regAddrSize := ADDR_SIZE_C(rdIdx)+1;  -- plus one for function ID byte
                  v.regIn.regDataSize := DATA_SIZE_C(rdIdx);

                  -- Next state
                  v.state := READ_TXN_S;

               end if;

            end if;
         ----------------------------------------------------------------------
         when WRITE_ACK_S =>
            -- Wait for completion
            if regOut.regAck = '1' then

               -- Reset the flag
               v.regIn.regReq      := '0';
               v.regIn.regAddrSkip := '0';

               -- Send AXI-Lite response
               axiSlaveWriteResponse(v.axilWriteSlave, axilResp);

               -- Next state
               v.state := IDLE_S;

            end if;
         ----------------------------------------------------------------------
         when READ_TXN_S =>
            -- Wait for completion
            if regOut.regAck = '1' then

               -- Reset the flag
               v.regIn.regReq := '0';

               -- Check for I2C failure
               if (regOut.regFail = '1') then

                  -- Send AXI-Lite response
                  axiSlaveReadResponse(v.axilReadSlave, axilResp);

                  -- Next state
                  v.state := IDLE_S;

               else

                  -- Next state
                  v.state := READ_REQ_S;

               end if;

            end if;
         ----------------------------------------------------------------------
         when READ_REQ_S =>
            -- Check if I2C FSM is ready
            if regOut.regAck = '0' then

               -- Send read transaction to I2cRegMaster
               v.regIn.regReq      := '1';
               v.regIn.regOp       := '0';  -- 0 for I2C read operation
               v.regIn.regAddrSkip := '1';  -- Skip writing the address because reading out buffer

               -- Setup the reg sizes
               v.regIn.regDataSize := READ_SIZE_C(rdIdx);  --  function ID byte is not included in cache read

               -- Next state
               v.state := READ_ACK_S;

            end if;
         ----------------------------------------------------------------------
         when READ_ACK_S =>
            -- Wait for completion
            if regOut.regAck = '1' then

               -- Reset the flag
               v.regIn.regReq      := '0';
               v.regIn.regAddrSkip := '0';

               -- Forward the readout data
               v.axilReadSlave.rdata := regOut.regRdData;

               -- Send AXI-Lite response
               axiSlaveReadResponse(v.axilReadSlave, axilResp);

               -- Next state
               v.state := IDLE_S;

            end if;
      ----------------------------------------------------------------------
      end case;

      -- Outputs
      sdoMuxSel      <= r.sdoMuxSel;
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
