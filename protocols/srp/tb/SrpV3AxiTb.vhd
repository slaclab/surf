-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation testbed for SrpV3Axi
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
use surf.AxiPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

entity SrpV3AxiTb is

end entity SrpV3AxiTb;

architecture tb of SrpV3AxiTb is

   constant FSM_AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(4);  -- 32-bit data width
   constant SRP_AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(8);  -- 64-bit data width

   constant AXI_CONFIG_C : AxiConfigType := (
      ADDR_WIDTH_C => 12,               -- 4kB RAM
      DATA_BYTES_C => 8,                -- 64-bit data width
      ID_BITS_C    => 1,
      LEN_BITS_C   => 8);

   constant REQ_BYTE_SIZE_C : positive := (2**AXI_CONFIG_C.ADDR_WIDTH_C);
   constant REQ_WORD_SIZE_C : positive := (REQ_BYTE_SIZE_C/4);

   constant CLK_PERIOD_C : time := 10 ns;
   constant TPD_G        : time := (CLK_PERIOD_C/4);

   type StateType is (
      REQ_MSG,
      TX_PAYLOAD,
      RX_HDR,
      RX_PAYLOAD,
      FAILED_S,
      PASSED_S);

   type RegType is record
      opCode   : slv(7 downto 0);
      cnt      : natural range 0 to REQ_BYTE_SIZE_C;
      tid      : slv(31 downto 0);
      addr     : slv(63 downto 0);
      txMaster : AxiStreamMasterType;
      rxSlave  : AxiStreamSlaveType;
      state    : StateType;
      passed   : sl;
      failed   : sl;
   end record RegType;
   constant REG_INIT_C : RegType := (
      opCode   => x"02",                -- posted write = 0x2
      cnt      => 0,
      tid      => x"1234_0000",
      addr     => (others => '0'),
      txMaster => AXI_STREAM_MASTER_INIT_C,
      rxSlave  => AXI_STREAM_SLAVE_INIT_C,
      state    => REQ_MSG,
      passed   => '0',
      failed   => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal clk : sl := '0';
   signal rst : sl := '1';

   signal axiWriteMaster : AxiWriteMasterType := AXI_WRITE_MASTER_INIT_C;
   signal axiWriteSlave  : AxiWriteSlaveType  := AXI_WRITE_SLAVE_INIT_C;
   signal axiReadMaster  : AxiReadMasterType  := AXI_READ_MASTER_INIT_C;
   signal axiReadSlave   : AxiReadSlaveType   := AXI_READ_SLAVE_INIT_C;

   signal srpIbMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal srpIbSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal srpObMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal srpObSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

   signal txMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal txSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal rxMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal rxSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

   signal passed : sl := '0';
   signal failed : sl := '0';

begin

   U_ClkRst : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1000 ns)  -- Hold reset for this long)
      port map (
         clkP => clk,
         rst  => rst);

   U_MEM : entity surf.AxiRam
      generic map (
         TPD_G        => TPD_G,
         AXI_CONFIG_G => AXI_CONFIG_C)
      port map (
         -- Clock and Reset
         axiClk          => clk,
         axiRst          => rst,
         -- Slave Write Interface
         sAxiWriteMaster => axiWriteMaster,
         sAxiWriteSlave  => axiWriteSlave,
         -- Slave Read Interface
         sAxiReadMaster  => axiReadMaster,
         sAxiReadSlave   => axiReadSlave);

   U_SRPv3 : entity surf.SrpV3Axi
      generic map (
         TPD_G               => TPD_G,
         AXI_CONFIG_G        => AXI_CONFIG_C,
         AXI_STREAM_CONFIG_G => SRP_AXIS_CONFIG_C)
      port map (
         -- AXIS Slave Interface (sAxisClk domain)
         sAxisClk       => clk,
         sAxisRst       => rst,
         sAxisMaster    => srpIbMaster,
         sAxisSlave     => srpIbSlave,
         -- AXIS Master Interface (mAxisClk domain)
         mAxisClk       => clk,
         mAxisRst       => rst,
         mAxisMaster    => srpObMaster,
         mAxisSlave     => srpObSlave,
         -- Master AXI Interface (axiClk domain)
         axiClk         => clk,
         axiRst         => rst,
         axiReadMaster  => axiReadMaster,
         axiReadSlave   => axiReadSlave,
         axiWriteMaster => axiWriteMaster,
         axiWriteSlave  => axiWriteSlave);

   U_Tx : entity surf.AxiStreamResize
      generic map (
         TPD_G               => TPD_G,
         SLAVE_AXI_CONFIG_G  => FSM_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => SRP_AXIS_CONFIG_C)
      port map (
         -- Clock and reset
         axisClk     => clk,
         axisRst     => rst,
         -- Slave Port
         sAxisMaster => txMaster,
         sAxisSlave  => txSlave,
         -- Master Port
         mAxisMaster => srpIbMaster,
         mAxisSlave  => srpIbSlave);

   U_Rx : entity surf.AxiStreamResize
      generic map (
         TPD_G               => TPD_G,
         SLAVE_AXI_CONFIG_G  => SRP_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => FSM_AXIS_CONFIG_C)
      port map (
         -- Clock and reset
         axisClk     => clk,
         axisRst     => rst,
         -- Slave Port
         sAxisMaster => srpObMaster,
         sAxisSlave  => srpObSlave,
         -- Master Port
         mAxisMaster => rxMaster,
         mAxisSlave  => rxSlave);

   comb : process (r, rst, rxMaster, txSlave) is
      variable v          : RegType;
      variable cntPattern : slv(63 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- AXI stream flow control
      v.rxSlave.tReady := '0';
      if (txSlave.tReady = '1') then
         v.txMaster.tValid := '0';
         v.txMaster.tLast  := '0';
         v.txMaster.tUser  := (others => '0');
         v.txMaster.tKeep  := (others => '1');
      end if;

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when REQ_MSG =>
            -- Check if ready to move data
            if (v.txMaster.tValid = '0') then

               -- Increment counter
               v.cnt := r.cnt + 1;

               -- Send the word
               v.txMaster.tValid := '1';

               -- Check for hdr[0]
               if (r.cnt = 0) then

                  -- Set SOF
                  ssiSetUserSof(FSM_AXIS_CONFIG_C, v.txMaster, '1');

                  -- timeout=0x0, opCode=r.opCode, Version=3
                  v.txMaster.tData(31 downto 0) := x"0000" & r.opCode & x"03";

               -- Check for hdr[1]
               elsif (r.cnt = 1) then
                  -- TID[31:0]
                  v.txMaster.tData(31 downto 0) := r.tid;

               -- Check for hdr[2]
               elsif (r.cnt = 2) then
                  -- Addr[31:0]
                  v.txMaster.tData(31 downto 0) := r.addr(31 downto 0);

               -- Check for hdr[3]
               elsif (r.cnt = 2) then
                  -- Addr[63:32]
                  v.txMaster.tData(31 downto 0) := r.addr(63 downto 32);

               -- Check for hdr[4]
               elsif (r.cnt = 4) then
                  -- ReqSize[31:0]
                  v.txMaster.tData(31 downto 0) := toSlv(REQ_BYTE_SIZE_C-1, 32);

                  -- Reset the counter
                  v.cnt := 0;

                  -- Check for posted write
                  if (r.opCode = x"02") then

                     -- Next state
                     v.state := TX_PAYLOAD;

                  else

                     -- Terminate the frame
                     v.txMaster.tLast := '1';

                     -- Next state
                     v.state := RX_HDR;

                  end if;

               end if;
            end if;
         ----------------------------------------------------------------------
         when TX_PAYLOAD =>
            -- Check if ready to move data
            if (v.txMaster.tValid = '0') then

               -- Increment counter
               v.cnt := r.cnt + 1;

               -- Send the counter data
               v.txMaster.tValid             := '1';
               v.txMaster.tData(31 downto 0) := toSlv(r.cnt, 32);

               -- Check for last TX word
               if (r.cnt = REQ_WORD_SIZE_C-1) then

                  -- Reset the counter
                  v.cnt := 0;

                  -- Terminate the frame
                  v.txMaster.tLast := '1';

                  -- Update next REQ_MSG opcode
                  v.opCode := x"00";     -- 0x0=Non-Posted Read

                  -- Increment the TID
                  v.tid := r.tid + 1;

                  -- Next state
                  v.state := REQ_MSG;

               end if;
            end if;
         ----------------------------------------------------------------------
         when RX_HDR =>
            -- Check if ready to move data
            if (rxMaster.tValid = '1') then

               -- Accept the data
               v.rxSlave.tReady := '1';

               -- Increment counter
               v.cnt := r.cnt + 1;

               -- Check for hdr[0]
               if (r.cnt = 0) then

                  if rxMaster.tData(31 downto 0) /= (x"0000" & r.opCode & x"03") then
                     v.state := FAILED_S;
                  end if;

               -- Check for hdr[1]
               elsif (r.cnt = 1) then

                  if rxMaster.tData(31 downto 0) /= r.tid then
                     v.state := FAILED_S;
                  end if;

               -- Check for hdr[2]
               elsif (r.cnt = 2) then

                  if rxMaster.tData(31 downto 0) /= r.addr(31 downto 0) then
                     v.state := FAILED_S;
                  end if;

               -- Check for hdr[3]
               elsif (r.cnt = 2) then

                  if rxMaster.tData(31 downto 0) /= r.addr(63 downto 32) then
                     v.state := FAILED_S;
                  end if;

               -- Check for hdr[4]
               elsif (r.cnt = 4) then

                  if rxMaster.tData(31 downto 0) /= (REQ_BYTE_SIZE_C-1) then
                     v.state := FAILED_S;
                  else

                     -- Reset the counter
                     v.cnt := 0;

                     -- Next state
                     v.state := RX_PAYLOAD;

                  end if;

               end if;

            end if;
         ----------------------------------------------------------------------
         when RX_PAYLOAD =>
            -- Check if ready to move data
            if (rxMaster.tValid = '1') then

               -- Accept the data
               v.rxSlave.tReady := '1';

               -- Check for last TX word
               if (r.cnt = REQ_WORD_SIZE_C) then


                  if rxMaster.tData(31 downto 0) /= 0 then
                     v.state := FAILED_S;

                  else

                     -- Reset the counter
                     v.cnt := 0;

                     -- Terminate the frame
                     v.txMaster.tLast := '1';

                     -- Increment the TID
                     v.tid := r.tid + 1;

                     -- Next state
                     v.state := PASSED_S;

                  end if;

               else

                  -- Increment counter
                  v.cnt := r.cnt + 1;

                  if rxMaster.tData(31 downto 0) /= r.cnt then
                     v.state := FAILED_S;
                  end if;

               end if;

            end if;
         ----------------------------------------------------------------------
         when FAILED_S =>
            v.failed := '1';
         ----------------------------------------------------------------------
         when PASSED_S =>
            v.passed := '1';
      ----------------------------------------------------------------------
      end case;

      -- Outputs
      rxSlave  <= v.rxSlave;            --- comb output
      txMaster <= r.txMaster;
      passed   <= r.passed;
      failed   <= r.failed;

      -- Synchronous Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   process(failed, passed)
   begin
      if passed = '1' then
         assert false
            report "Simulation Passed!" severity failure;
      elsif failed = '1' then
         assert false
            report "Simulation Failed!" severity failure;
      end if;
   end process;

end tb;
