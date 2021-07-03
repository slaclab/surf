-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: AXI-Lite I2C Register Master with I2C Multiplexer
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.I2cPkg.all;
use surf.I2cMuxPkg.all;

library unisim;
use unisim.vcomponents.all;

entity AxiLiteCrossbarI2cMux is
   generic (
      TPD_G            : time               := 1 ns;
      AXIL_PROXY_G     : boolean            := false;
      MUX_DECODE_MAP_G : Slv8Array          := I2C_MUX_DECODE_MAP_TCA9548_C;
      I2C_MUX_ADDR_G   : slv(6 downto 0)    := b"1110_000";
      DEVICE_MAP_G     : I2cAxiLiteDevArray := I2C_AXIL_DEV_ARRAY_DEFAULT_C;
      I2C_SCL_FREQ_G   : real               := 100.0E+3;    -- units of Hz
      I2C_MIN_PULSE_G  : real               := 100.0E-9;    -- units of seconds
      AXIL_CLK_FREQ_G  : real               := 156.25E+6);  -- units of Hz
   port (
      -- Clocks and Resets
      axilClk         : in    sl;
      axilRst         : in    sl;
      -- AXI-Lite Register Interface
      axilReadMaster  : in    AxiLiteReadMasterType;
      axilReadSlave   : out   AxiLiteReadSlaveType;
      axilWriteMaster : in    AxiLiteWriteMasterType;
      axilWriteSlave  : out   AxiLiteWriteSlaveType;
      -- I2C Ports
      scl             : inout sl;
      sda             : inout sl);
end AxiLiteCrossbarI2cMux;

architecture mapping of AxiLiteCrossbarI2cMux is

   -- Note: PRESCALE_G = (clk_freq / (5 * i2c_freq)) - 1
   --       FILTER_G = (min_pulse_time / clk_period) + 1
   constant I2C_SCL_5xFREQ_C : real    := 5.0 * I2C_SCL_FREQ_G;
   constant PRESCALE_C       : natural := (getTimeRatio(AXIL_CLK_FREQ_G, I2C_SCL_5xFREQ_C)) - 1;
   constant FILTER_C         : natural := natural(AXIL_CLK_FREQ_G * I2C_MIN_PULSE_G) + 1;

   constant DEVICE_MAP_LENGTH_C : natural := DEVICE_MAP_G'length+1;  -- Append the I2C to the top of the device map

   constant DEVICE_MAP_C : I2cAxiLiteDevArray(0 to DEVICE_MAP_LENGTH_C-1) := (
      0 to DEVICE_MAP_G'length-1 => DEVICE_MAP_G(0 to DEVICE_MAP_G'length-1),
      DEVICE_MAP_LENGTH_C-1      => MakeI2cAxiLiteDevType(  -- Enhanced interface
         i2cAddress              => I2C_MUX_ADDR_G,
         dataSize                => 8,  -- in units of bits
         addrSize                => 0,  -- in units of bits
         endianness              => '0',                    -- Little endian
         repeatStart             => '0'));                  -- Repeat Start

   -- Number of device register space address bits mapped into axi bus is determined by
   -- the maximum address size of all the devices.
   constant I2C_REG_ADDR_SIZE_C : natural := maxAddrSize(DEVICE_MAP_C);

   constant I2C_REG_AXI_ADDR_LOW_C  : natural := 2;
   constant I2C_REG_AXI_ADDR_HIGH_C : natural :=
      ite(I2C_REG_ADDR_SIZE_C = 0,
          2,
          I2C_REG_AXI_ADDR_LOW_C + I2C_REG_ADDR_SIZE_C-1);

   subtype I2C_REG_AXI_ADDR_RANGE_C is natural range
      I2C_REG_AXI_ADDR_HIGH_C downto I2C_REG_AXI_ADDR_LOW_C;

   -- Number of device address bits mapped into axi bus space is determined by number of devices
   constant I2C_DEV_AXI_ADDR_LOW_C : natural := I2C_REG_AXI_ADDR_HIGH_C + 1;
   constant I2C_DEV_AXI_ADDR_HIGH_C : natural := ite(
      (DEVICE_MAP_LENGTH_C = 1),
      I2C_DEV_AXI_ADDR_LOW_C,
      (I2C_DEV_AXI_ADDR_LOW_C + log2(DEVICE_MAP_LENGTH_C) - 1));

   subtype I2C_DEV_AXI_ADDR_RANGE_C is natural range
      I2C_DEV_AXI_ADDR_HIGH_C downto I2C_DEV_AXI_ADDR_LOW_C;

   constant I2C_DEV_AXI_ADDR_WIDTH_C : positive := (I2C_DEV_AXI_ADDR_HIGH_C-I2C_DEV_AXI_ADDR_LOW_C)+1;

   type StateType is (
      IDLE_S,
      MUX_S,
      REQ_TXN_S,
      ACK_TXN_S);

   type RegType is record
      rnw             : sl;
      proxyReadSlave  : AxiLiteReadSlaveType;
      proxyWriteSlave : AxiLiteWriteSlaveType;
      req             : AxiLiteReqType;
      state           : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      rnw             => '0',
      proxyReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      proxyWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      req             => AXI_LITE_REQ_INIT_C,
      state           => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal ack : AxiLiteAckType;

   signal proxyReadMaster  : AxiLiteReadMasterType;
   signal proxyReadSlave   : AxiLiteReadSlaveType;
   signal proxyWriteMaster : AxiLiteWriteMasterType;
   signal proxyWriteSlave  : AxiLiteWriteSlaveType;

   signal readMaster  : AxiLiteReadMasterType;
   signal readSlave   : AxiLiteReadSlaveType;
   signal writeMaster : AxiLiteWriteMasterType;
   signal writeSlave  : AxiLiteWriteSlaveType;

   signal i2cRegMasterIn  : I2cRegMasterInType;
   signal i2cRegMasterOut : I2cRegMasterOutType;

   signal i2ci : i2c_in_type;
   signal i2co : i2c_out_type;

begin

   BYP_PROXY : if (AXIL_PROXY_G = false) generate
      proxyReadMaster  <= axilReadMaster;
      axilReadSlave    <= proxyReadSlave;
      proxyWriteMaster <= axilWriteMaster;
      axilWriteSlave   <= proxyWriteSlave;
   end generate BYP_PROXY;

   GEN_PROXY : if (AXIL_PROXY_G = true) generate
      U_AxiLiteMasterProxy : entity surf.AxiLiteMasterProxy
         generic map (
            TPD_G => TPD_G)
         port map (
            -- Clocks and Resets
            axiClk          => axilClk,
            axiRst          => axilRst,
            -- AXI-Lite Register Interface
            sAxiReadMaster  => axilReadMaster,
            sAxiReadSlave   => axilReadSlave,
            sAxiWriteMaster => axilWriteMaster,
            sAxiWriteSlave  => axilWriteSlave,
            -- AXI-Lite Register Interface
            mAxiReadMaster  => proxyReadMaster,
            mAxiReadSlave   => proxyReadSlave,
            mAxiWriteMaster => proxyWriteMaster,
            mAxiWriteSlave  => proxyWriteSlave);
   end generate GEN_PROXY;

   comb : process (ack, axilRst, proxyReadMaster, proxyWriteMaster, r) is
      variable v           : regType;
      variable wrIdx       : integer;
      variable rdIdx       : integer;
      variable proxyStatus : AxiLiteStatusType;
   begin
      -- Latch the current value
      v := r;

      -- Update the variables
      wrIdx := conv_integer(proxyWriteMaster.awaddr(I2C_DEV_AXI_ADDR_RANGE_C));
      rdIdx := conv_integer(proxyReadMaster.araddr(I2C_DEV_AXI_ADDR_RANGE_C));

      -- Determine the transaction type
      axiSlaveWaitTxn(proxyWriteMaster, proxyReadMaster, v.proxyWriteSlave, v.proxyReadSlave, proxyStatus);

      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Reset the buses
            v.req.wrData                            := (others => '0');
            v.req.address                           := (others => '0');
            v.req.address(I2C_DEV_AXI_ADDR_RANGE_C) := toSlv(DEVICE_MAP_LENGTH_C-1, I2C_DEV_AXI_ADDR_WIDTH_C);

            -- Check if ready for next transaction
            if (ack.done = '0') then

               -- Check for a write TXN
               if (proxyStatus.writeEnable = '1') then

                  -- Set the flag
                  v.rnw := '0';

                  -- Setup the AXI-Lite Master request
                  v.req.request            := '1';
                  v.req.rnw                := '0';  -- Only write TXN for setting up MUX
                  v.req.wrData(7 downto 0) := MUX_DECODE_MAP_G(wrIdx);

                  -- Next state
                  v.state := MUX_S;

               -- Check for a read TXN
               elsif (proxyStatus.readEnable = '1') then

                  -- Set the flag
                  v.rnw := '1';

                  -- Setup the AXI-Lite Master request
                  v.req.request            := '1';
                  v.req.rnw                := '0';  -- Only write TXN for setting up MUX
                  v.req.wrData(7 downto 0) := MUX_DECODE_MAP_G(rdIdx);

                  -- Next state
                  v.state := MUX_S;

               end if;

            end if;
         ----------------------------------------------------------------------
         when MUX_S =>
            -- Wait for DONE to set
            if (ack.done = '1') then

               -- Reset the flag
               v.req.request := '0';

               -- Check for bus error
               if (ack.resp /= AXI_RESP_OK_C) then

                  -- Check for a write TXN
                  if (r.rnw = '0') then

                     -- Send the response
                     axiSlaveWriteResponse(v.proxyWriteSlave, ack.resp);

                  -- Else read TXN
                  else

                     -- Return the error code value
                     v.proxyReadSlave.rData := ack.rdData;

                     -- Send the response
                     axiSlaveReadResponse(v.proxyReadSlave, ack.resp);

                  end if;

                  -- Next state
                  v.state := IDLE_S;

               else

                  -- Next state
                  v.state := REQ_TXN_S;

               end if;

            end if;
         ----------------------------------------------------------------------
         when REQ_TXN_S =>
            -- Check if ready for next transaction
            if (ack.done = '0') then

               -- Setup the AXI-Lite Master request
               v.req.request := '1';
               v.req.rnw     := r.rnw;

               -- Check for a write TXN
               if (r.rnw = '0') then

                  v.req.address := proxyWriteMaster.awaddr;
                  v.req.wrData  := proxyWriteMaster.wData;

               -- Else read TXN
               else

                  v.req.address := proxyReadMaster.araddr;
                  v.req.wrData  := proxyReadMaster.rData;

               end if;

               -- Next state
               v.state := ACK_TXN_S;

            end if;
         ----------------------------------------------------------------------
         when ACK_TXN_S =>
            -- Wait for DONE to set
            if (ack.done = '1') then

               -- Reset the flag
               v.req.request := '0';

               -- Check for a write TXN
               if (r.rnw = '0') then

                  -- Send the response
                  axiSlaveWriteResponse(v.proxyWriteSlave, ack.resp);

               -- Else read TXN
               else

                  -- Return the read value
                  v.proxyReadSlave.rData := ack.rdData;

                  -- Send the response
                  axiSlaveReadResponse(v.proxyReadSlave, ack.resp);

               end if;

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
      proxyReadSlave  <= r.proxyReadSlave;
      proxyWriteSlave <= r.proxyWriteSlave;

   end process comb;

   seq : process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_AxiLiteMaster : entity surf.AxiLiteMaster
      generic map (
         TPD_G => TPD_G)
      port map (
         req             => r.req,
         ack             => ack,
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilWriteMaster => writeMaster,
         axilWriteSlave  => writeSlave,
         axilReadMaster  => readMaster,
         axilReadSlave   => readSlave);

   U_I2cRegMasterAxiBridge : entity surf.I2cRegMasterAxiBridge
      generic map (
         TPD_G        => TPD_G,
         DEVICE_MAP_G => DEVICE_MAP_C)
      port map (
         -- I2C Register Interface
         i2cRegMasterIn  => i2cRegMasterIn,
         i2cRegMasterOut => i2cRegMasterOut,
         -- AXI-Lite Register Interface
         axiReadMaster   => readMaster,
         axiReadSlave    => readSlave,
         axiWriteMaster  => writeMaster,
         axiWriteSlave   => writeSlave,
         -- Clocks and Resets
         axiClk          => axilClk,
         axiRst          => axilRst);

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
         regIn  => i2cRegMasterIn,
         regOut => i2cRegMasterOut,
         -- Clock and Reset
         clk    => axilClk,
         srst   => axilRst);

   IOBUF_SCL : IOBUF
      port map (
         O  => i2ci.scl,                -- Buffer output
         IO => scl,  -- Buffer inout port (connect directly to top-level port)
         I  => i2co.scl,                -- Buffer input
         T  => i2co.scloen);  -- 3-state enable input, high=input, low=output

   IOBUF_SDA : IOBUF
      port map (
         O  => i2ci.sda,                -- Buffer output
         IO => sda,  -- Buffer inout port (connect directly to top-level port)
         I  => i2co.sda,                -- Buffer input
         T  => i2co.sdaoen);  -- 3-state enable input, high=input, low=output

end mapping;
