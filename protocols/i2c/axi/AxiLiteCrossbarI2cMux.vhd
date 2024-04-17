-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Sets the I2C MUX path before sending the TXN to the AXI-Lite XBAR
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

entity AxiLiteCrossbarI2cMux is
   generic (
      TPD_G              : time                             := 1 ns;
      AXIL_PROXY_G       : boolean                          := false;
      -- I2C MUX Generics
      MUX_DECODE_MAP_G   : Slv8Array                        := I2C_MUX_DECODE_MAP_TCA9548_C;
      I2C_MUX_ADDR_G     : slv(6 downto 0)                  := b"1110_000";
      I2C_SCL_FREQ_G     : real                             := 400.0E+3;  -- units of Hz
      I2C_MIN_PULSE_G    : real                             := 100.0E-9;  -- units of seconds
      AXIL_CLK_FREQ_G    : real                             := 156.25E+6;  -- units of Hz
      -- AXI-Lite Crossbar Generics
      NUM_MASTER_SLOTS_G : natural range 1 to 64            := 4;
      DEC_ERROR_RESP_G   : slv(1 downto 0)                  := AXI_RESP_DECERR_C;
      MASTERS_CONFIG_G   : AxiLiteCrossbarMasterConfigArray := AXIL_XBAR_CFG_DEFAULT_C;
      DEBUG_G            : boolean                          := false);
   port (
      -- Clocks and Resets
      axilClk           : in  sl;
      axilRst           : in  sl;
      -- Slave AXI-Lite Interface
      sAxilReadMaster   : in  AxiLiteReadMasterType;
      sAxilReadSlave    : out AxiLiteReadSlaveType;
      sAxilWriteMaster  : in  AxiLiteWriteMasterType;
      sAxilWriteSlave   : out AxiLiteWriteSlaveType;
      -- Master AXI-Lite Interfaces
      mAxilWriteMasters : out AxiLiteWriteMasterArray(NUM_MASTER_SLOTS_G-1 downto 0);
      mAxilWriteSlaves  : in  AxiLiteWriteSlaveArray(NUM_MASTER_SLOTS_G-1 downto 0);
      mAxilReadMasters  : out AxiLiteReadMasterArray(NUM_MASTER_SLOTS_G-1 downto 0);
      mAxilReadSlaves   : in  AxiLiteReadSlaveArray(NUM_MASTER_SLOTS_G-1 downto 0);
      -- I2C MUX Ports
      i2cRst            : out sl;
      i2cRstL           : out sl;
      i2ci              : in  i2c_in_type;
      i2co              : out i2c_out_type);
end AxiLiteCrossbarI2cMux;

architecture mapping of AxiLiteCrossbarI2cMux is

   -- Note: PRESCALE_G = (clk_freq / (5 * i2c_freq)) - 1
   --       FILTER_G = (min_pulse_time / clk_period) + 1
   constant I2C_SCL_5xFREQ_C : real    := 5.0 * I2C_SCL_FREQ_G;
   constant PRESCALE_C       : natural := (getTimeRatio(AXIL_CLK_FREQ_G, I2C_SCL_5xFREQ_C)) - 1;
   constant FILTER_C         : natural := natural(AXIL_CLK_FREQ_G * I2C_MIN_PULSE_G) + 1;

   constant DEVICE_MAP_C : I2cAxiLiteDevType := (
      MakeI2cAxiLiteDevType(
         i2cAddress  => I2C_MUX_ADDR_G,
         dataSize    => 8,              -- in units of bits
         addrSize    => 0,              -- in units of bits
         endianness  => '0',            -- Little endian
         repeatStart => '0'));          -- Repeat Start

   constant I2C_MUX_INIT_C : I2cRegMasterInType := (
      i2cAddr     => DEVICE_MAP_C.i2cAddress,
      tenbit      => DEVICE_MAP_C.i2cTenbit,
      regAddr     => (others => '0'),
      regWrData   => (others => '0'),
      regOp       => '1',               -- 1 for write, 0 for read
      regAddrSkip => '1',               -- No memory address in the MUX
      regAddrSize => (others => '0'),
      regDataSize => (others => '0'),
      regReq      => '0',
      busReq      => '0',
      endianness  => DEVICE_MAP_C.endianness,
      repeatStart => DEVICE_MAP_C.repeatStart,
      wrDataOnRd => '0');

   type StateType is (
      IDLE_S,
      RST_S,
      MUX_S,
      XBAR_S);

   type RegType is record
      cnt            : natural range 0 to FILTER_C;
      i2cRstL        : sl;
      rnw            : sl;
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
      i2cRegMasterIn : I2cRegMasterInType;
      req            : AxiLiteReqType;
      state          : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      cnt            => 0,
      i2cRstL        => '1',
      rnw            => '0',
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      i2cRegMasterIn => I2C_MUX_INIT_C,
      req            => AXI_LITE_REQ_INIT_C,
      state          => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal axilReadMaster  : AxiLiteReadMasterType;
   signal axilReadSlave   : AxiLiteReadSlaveType;
   signal axilWriteMaster : AxiLiteWriteMasterType;
   signal axilWriteSlave  : AxiLiteWriteSlaveType;

   signal i2cRegMasterOut : I2cRegMasterOutType;

   signal ack             : AxiLiteAckType;
   signal xbarReadMaster  : AxiLiteReadMasterType;
   signal xbarReadSlave   : AxiLiteReadSlaveType;
   signal xbarWriteMaster : AxiLiteWriteMasterType;
   signal xbarWriteSlave  : AxiLiteWriteSlaveType;

begin

   BYP_PROXY : if (AXIL_PROXY_G = false) generate
      axilReadMaster  <= sAxilReadMaster;
      sAxilReadSlave  <= axilReadSlave;
      axilWriteMaster <= sAxilWriteMaster;
      sAxilWriteSlave <= axilWriteSlave;
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
            sAxiReadMaster  => sAxilReadMaster,
            sAxiReadSlave   => sAxilReadSlave,
            sAxiWriteMaster => sAxilWriteMaster,
            sAxiWriteSlave  => sAxilWriteSlave,
            -- AXI-Lite Register Interface
            mAxiReadMaster  => axilReadMaster,
            mAxiReadSlave   => axilReadSlave,
            mAxiWriteMaster => axilWriteMaster,
            mAxiWriteSlave  => axilWriteSlave);
   end generate GEN_PROXY;

   comb : process (ack, axilReadMaster, axilRst, axilWriteMaster,
                   i2cRegMasterOut, r) is
      variable v          : regType;
      variable wrIdx      : integer;
      variable rdIdx      : integer;
      variable axilStatus : AxiLiteStatusType;
   begin
      -- Latch the current value
      v := r;

      -- Update the variables
      wrIdx := 0;                       -- init
      rdIdx := 0;                       -- init
      for m in MASTERS_CONFIG_G'range loop

         -- Check for write address match
         if ((MASTERS_CONFIG_G(m).addrBits = 32)
             or (
                StdMatch(  -- Use std_match to allow dontcares ('-')
                   axilWriteMaster.awaddr(31 downto MASTERS_CONFIG_G(m).addrBits),
                   MASTERS_CONFIG_G(m).baseAddr(31 downto MASTERS_CONFIG_G(m).addrBits))
                and (MASTERS_CONFIG_G(m).connectivity(0) = '1')))
         then
            wrIdx := m;
         end if;

         -- Check for read address match
         if ((MASTERS_CONFIG_G(m).addrBits = 32)
             or (
                StdMatch(  -- Use std_match to allow dontcares ('-')
                   axilReadMaster.araddr(31 downto MASTERS_CONFIG_G(m).addrBits),
                   MASTERS_CONFIG_G(m).baseAddr(31 downto MASTERS_CONFIG_G(m).addrBits))
                and (MASTERS_CONFIG_G(m).connectivity(0) = '1')))
         then
            rdIdx := m;
         end if;

      end loop;

      -- Determine the transaction type
      axiSlaveWaitTxn(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus);

      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check if ready for next transaction
            if (ack.done = '0') then

               -- Check for a write TXN
               if (axilStatus.writeEnable = '1') then

                  -- Set the flags
                  v.i2cRstL := '0';
                  v.rnw     := '0';

                  -- Setup the I2C MUX
                  v.i2cRegMasterIn.regWrData(7 downto 0) := MUX_DECODE_MAP_G(wrIdx);

                  -- Next state
                  v.state := RST_S;

               -- Check for a read TXN
               elsif (axilStatus.readEnable = '1') then

                  -- Set the flag
                  v.i2cRstL := '0';
                  v.rnw     := '1';

                  -- Setup the I2C MUX
                  v.i2cRegMasterIn.regWrData(7 downto 0) := MUX_DECODE_MAP_G(rdIdx);

                  -- Next state
                  v.state := RST_S;

               end if;

            end if;
         ----------------------------------------------------------------------
         when RST_S =>
            -- Check the counter
            if (r.cnt = FILTER_C) then

               -- Reset the counter
               v.cnt := 0;

               -- Reset the flag
               v.i2cRstL := '1';

               -- Start the I2C transaction
               v.i2cRegMasterIn.regReq := '1';

               -- Next state
               v.state := MUX_S;

            else
               -- Increment the counter
               v.cnt := r.cnt + 1;
            end if;
         ----------------------------------------------------------------------
         when MUX_S =>
            -- Wait for DONE to set
            if (i2cRegMasterOut.regAck = '1' and r.i2cRegMasterIn.regReq = '1') then

               -- Reset the flag
               v.i2cRegMasterIn.regReq := '0';

               -- Check for bus error
               if (i2cRegMasterOut.regFail = '1') then

                  -- Check for a write TXN
                  if (r.rnw = '0') then

                     -- Send the response
                     axiSlaveWriteResponse(v.axilWriteSlave, AXI_RESP_SLVERR_C);

                  -- Else read TXN
                  else

                     -- Return the error code value
                     v.axilReadSlave.rData := x"000000" & i2cRegMasterOut.regFailCode;

                     -- Send the response
                     axiSlaveReadResponse(v.axilReadSlave, AXI_RESP_SLVERR_C);

                  end if;

                  -- Next state
                  v.state := IDLE_S;

               else

                  -- Setup the AXI-Lite Master request
                  v.req.request := '1';
                  v.req.rnw     := r.rnw;
                  v.req.wrData  := axilWriteMaster.wData;

                  -- Check for a write TXN
                  if (r.rnw = '0') then
                     v.req.address := axilWriteMaster.awaddr;

                  -- Else read TXN
                  else
                     v.req.address := axilReadMaster.araddr;

                  end if;

                  -- Next state
                  v.state := XBAR_S;

               end if;

            end if;
         ----------------------------------------------------------------------
         when XBAR_S =>
            -- Wait for DONE to set
            if (ack.done = '1') then

               -- Reset the flag
               v.req.request := '0';

               -- Check for a write TXN
               if (r.rnw = '0') then

                  -- Send the response
                  axiSlaveWriteResponse(v.axilWriteSlave, ack.resp);

               -- Else read TXN
               else

                  -- Return the read value
                  v.axilReadSlave.rData := ack.rdData;

                  -- Send the response
                  axiSlaveReadResponse(v.axilReadSlave, ack.resp);

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
      axilReadSlave  <= r.axilReadSlave;
      axilWriteSlave <= r.axilWriteSlave;
      i2cRstL        <= r.i2cRstL;
      i2cRst         <= not(r.i2cRstL);

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
         regIn  => r.i2cRegMasterIn,
         regOut => i2cRegMasterOut,
         -- Clock and Reset
         clk    => axilClk,
         srst   => axilRst);

   U_XbarAxilMaster : entity surf.AxiLiteMaster
      generic map (
         TPD_G => TPD_G)
      port map (
         req             => r.req,
         ack             => ack,
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilWriteMaster => xbarWriteMaster,
         axilWriteSlave  => xbarWriteSlave,
         axilReadMaster  => xbarReadMaster,
         axilReadSlave   => xbarReadSlave);

   U_XBAR : entity surf.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_MASTER_SLOTS_G,
         DEC_ERROR_RESP_G   => DEC_ERROR_RESP_G,
         MASTERS_CONFIG_G   => MASTERS_CONFIG_G,
         DEBUG_G            => DEBUG_G)
      port map (
         -- Clock and Resets
         axiClk              => axilClk,
         axiClkRst           => axilRst,
         -- Slave AXI-Lite Interface
         sAxiWriteMasters(0) => xbarWriteMaster,
         sAxiWriteSlaves(0)  => xbarWriteSlave,
         sAxiReadMasters(0)  => xbarReadMaster,
         sAxiReadSlaves(0)   => xbarReadSlave,
         -- Master AXI-Lite Interfaces
         mAxiWriteMasters    => mAxilWriteMasters,
         mAxiWriteSlaves     => mAxilWriteSlaves,
         mAxiReadMasters     => mAxilReadMasters,
         mAxiReadSlaves      => mAxilReadSlaves);

end mapping;
