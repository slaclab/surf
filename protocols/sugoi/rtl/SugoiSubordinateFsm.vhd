-------------------------------------------------------------------------------
-- Title      : SUGOI Protocol: https://confluence.slac.stanford.edu/x/3of_E
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Subordinate Finite State Machine (FSM)
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

entity SugoiSubordinateFsm is
   generic (
      TPD_G          : time    := 1 ns;
      RST_POLARITY_G : sl      := '1';  -- '1' for active high rst, '0' for active low
      RST_ASYNC_G    : boolean := false);
   port (
      pwrOnRst        : in  sl := not(RST_POLARITY_G);
      -- Clock and Reset
      clk             : in  sl;
      rst             : out sl;
      rstL            : out sl;
      -- Link Status
      linkup          : out sl;
      -- Trigger/Timing Command Bus
      opCode          : out slv(7 downto 0);
      -- RX Interface
      rxValid         : in  sl;
      rxData          : in  slv(7 downto 0);
      rxDataK         : in  sl;
      rxError         : in  sl;
      rxSlip          : out sl;
      -- RX Interface
      txValid         : out sl;
      txData          : out slv(7 downto 0);
      txDataK         : out sl;
      -- AXI-Lite Master Interface
      axilReadMaster  : out AxiLiteReadMasterType;
      axilReadSlave   : in  AxiLiteReadSlaveType;
      axilWriteMaster : out AxiLiteWriteMasterType;
      axilWriteSlave  : in  AxiLiteWriteSlaveType);
end entity SugoiSubordinateFsm;

architecture rtl of SugoiSubordinateFsm is

   type StateType is (
      INIT_S,
      RX_SOF_S,
      RX_HEADER_S,
      RX_ADDR_S,
      RX_DATA_S,
      RX_FOOTER_S,
      RX_XSUM_S,
      RX_EOF_S,
      RD_TXN_S,
      WR_TXN_S,
      TX_DATA_S,
      TX_FOOTER_S,
      TX_XSUM_S,
      TX_EOF_S);

   type RegType is record
      linkup          : sl;
      rst             : sl;
      rstL            : sl;
      opCode          : slv(7 downto 0);
      rxSlip          : sl;
      txValid         : sl;
      txData          : slv(7 downto 0);
      memData         : slv(31 downto 0);
      footer          : slv(7 downto 0);
      rxXsum          : slv(7 downto 0);
      txXsum          : slv(7 downto 0);
      RnW             : sl;
      devSelected     : sl;
      txDataK         : sl;
      stableCnt       : slv(7 downto 0);
      byteCnt         : slv(1 downto 0);
      axilWriteMaster : AxiLiteWriteMasterType;
      axilReadMaster  : AxiLiteReadMasterType;
      state           : StateType;
   end record;
   constant REG_INIT_C : RegType := (
      linkup          => '0',
      rst             => '0',  -- Don't publish reset during FSM reset process
      rstL            => '1',  -- Don't publish reset during FSM reset process
      opCode          => (others => '0'),
      rxSlip          => '1',           -- Assert RX slip on reset condition
      txValid         => '0',
      txData          => CODE_IDLE_C,
      memData         => (others => '0'),
      footer          => (others => '0'),
      rxXsum          => (others => '0'),
      txXsum          => (others => '0'),
      RnW             => '0',
      devSelected     => '0',
      txDataK         => '1',
      stableCnt       => (others => '1'),  -- Pre-set counter value on reset condition
      byteCnt         => (others => '0'),
      axilWriteMaster => AXI_LITE_WRITE_MASTER_INIT_C,
      axilReadMaster  => AXI_LITE_READ_MASTER_INIT_C,
      state           => INIT_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (axilReadSlave, axilWriteSlave, pwrOnRst, r, rxData, rxDataK,
                   rxError, rxValid) is
      variable v : RegType;
      variable i : natural;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobes
      v.rxSlip  := '0';
      v.txValid := '0';
      v.opCode  := (others => '0');

      -- Echo the message back by default
      v.txValid := rxValid;
      v.txData  := rxData;
      v.txDataK := rxDataK;

      -- Check for not(INIT_S) and active control code
      if (r.state /= INIT_S) and (rxValid = '1') and (rxDataK = '1') then

         -- Check for unexpected SOF
         if (r.state /= RX_SOF_S) and (rxData = CODE_SOF_C) then
            -- Echo back with IDLE instead
            v.txData := CODE_IDLE_C;
         end if;

         -- Check for unexpected EOF
         if (r.state /= RX_EOF_S) and (rxData = CODE_EOF_C) then
            -- Echo back with IDLE instead
            v.txData := CODE_IDLE_C;
         end if;

         -- Loop through trigger codes
         for i in 7 downto 0 loop

            -- Check for trigger code
            if (rxData = CODE_TRIG_C(i)) then
               -- Set the OP-code bit
               v.opCode(i) := '1';      -- single cycle strobe
            end if;

         end loop;

         ---------------------------------------------------------------------------
         -- Reset strobes within this "if" statement such that the pulse width of the reset
         -- output can be controlled by the number of CODE_RST_C sent by the manager
         ---------------------------------------------------------------------------
         v.rst  := '0';
         v.rstL := '1';

         -- Check for global reset
         if (rxData = CODE_RST_C) then
            v.rst  := '1';
            v.rstL := '0';
         end if;

      end if;

      -- Check slave.arready flag
      if axilReadSlave.arready = '1' then
         -- Reset the flag
         v.axilReadMaster.arvalid := '0';
      end if;

      -- Check slave.rvalid flag
      if axilReadSlave.rvalid = '1' then

         -- Reset the flag
         v.axilReadMaster.rready := '0';

         -- Latch the memory bus responds
         v.footer(SUGOI_FOOTER_BUS_RESP_FIELD_C) := axilReadSlave.rresp;

         -- Save the data
         v.memData := axilReadSlave.rdata;

      end if;

      -- Check the slave.awready flag
      if axilWriteSlave.awready = '1' then
         -- Reset the flag
         v.axilWriteMaster.awvalid := '0';
      end if;

      -- Check the slave.wready flag
      if axilWriteSlave.wready = '1' then
         -- Reset the flag
         v.axilWriteMaster.wvalid := '0';
      end if;

      -- Check the slave.bvalid flag
      if axilWriteSlave.bvalid = '1' then

         -- Reset the flag
         v.axilWriteMaster.bready := '0';

         -- Latch the memory bus responds
         v.footer(SUGOI_FOOTER_BUS_RESP_FIELD_C) := axilWriteSlave.bresp;

      end if;

      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when INIT_S =>
            -- Check for valid
            if (rxValid = '1') then

               -- Check stable counter
               if r.stableCnt = 0 then

                  -- Set the flag
                  v.linkup := '1';

                  -- Next state
                  v.state := RX_SOF_S;

               else
                  -- Decrement the counter
                  v.stableCnt := r.stableCnt - 1;
               end if;

            end if;
         ----------------------------------------------------------------------
         when RX_SOF_S =>
            -- Wait for SOF
            if (rxValid = '1')and (rxDataK = '1') and (rxData = CODE_SOF_C)then
               -- Next state
               v.state := RX_HEADER_S;
            end if;
         ----------------------------------------------------------------------
         when RX_HEADER_S =>
            -- Wait for non-control word
            if (rxValid = '1') and (rxDataK = '0') then

               -- Check for version number mismatch
               if (rxData(SUGOI_HDR_VERSION_FIELD_C) /= SUGOI_VERSION_C) then
                  -- Set the error flag
                  v.footer(SUGOI_FOOTER_VER_MISMATCH_C) := '1';
               end if;

               -- Check if read or write operation
               v.RnW := rxData(SUGOI_HDR_OP_TYPE_C);

               -- Check for non-zero device ID
               if (rxData(SUGOI_HDR_DDEV_ID_FIELD_C) /= 0) then
                  -- Decrement the device ID
                  v.txData(SUGOI_HDR_DDEV_ID_FIELD_C) := rxData(SUGOI_HDR_DDEV_ID_FIELD_C) - 1;
               end if;

               -- Init the RX/TX checksums
               v.rxXsum := rxData;
               v.txXsum := v.txData;

               -- Check for device ID is index to local device
               if (rxData(SUGOI_HDR_DDEV_ID_FIELD_C) = 1) then
                  -- Set the flag
                  v.devSelected := '1';
               else
                  -- Set the flag
                  v.devSelected := '0';
               end if;

               -- Next state
               v.state := RX_ADDR_S;

            end if;
         ----------------------------------------------------------------------
         when RX_ADDR_S =>
            -- Wait for non-control word
            if (rxValid = '1')and (rxDataK = '0') then

               -- Update the RX/TX checksums
               v.rxXsum := r.rxXsum + rxData;
               v.txXsum := r.txXsum + v.txData;

               -- Set the address
               v.axilReadMaster.araddr  := r.axilReadMaster.araddr(23 downto 0) & rxData;
               v.axilWriteMaster.awaddr := r.axilWriteMaster.awaddr(23 downto 0) & rxData;

               -- Increment the counter
               v.byteCnt := r.byteCnt + 1;

               -- Check the counter
               if (r.byteCnt = 3) then

                  -- Check if not 32-bit word alignment in the address
                  if (rxData(1 downto 0) /= "00") then
                     -- Set the flag
                     v.footer(SUGOI_FOOTER_NOT_ADDR_ALIGN_C) := '1';
                  end if;

                  -- Next state
                  v.state := RX_DATA_S;
               end if;

            end if;
         ----------------------------------------------------------------------
         when RX_DATA_S =>
            -- Wait for non-control word
            if (rxValid = '1')and (rxDataK = '0') then

               -- Send IDLE char
               v.txValid := '1';
               v.txData  := CODE_IDLE_C;
               v.txDataK := '1';

               -- Update the RX checksum only
               v.rxXsum := r.rxXsum + rxData;

               -- Set the write and memory data buses
               v.axilWriteMaster.wdata := r.axilWriteMaster.wdata(23 downto 0) & rxData;
               v.memData               := r.memData(23 downto 0) & rxData;

               -- Increment the counter
               v.byteCnt := r.byteCnt + 1;

               -- Check the counter
               if (r.byteCnt = 3) then
                  -- Next state
                  v.state := RX_FOOTER_S;
               end if;

            end if;
         ----------------------------------------------------------------------
         when RX_FOOTER_S =>
            -- Wait for non-control word
            if (rxValid = '1')and (rxDataK = '0') then

               -- Send IDLE char
               v.txValid := '1';
               v.txData  := CODE_IDLE_C;
               v.txDataK := '1';

               -- Update the RX checksum only
               v.rxXsum := r.rxXsum + rxData;

               -- OR the remote footer value with local
               v.footer := r.footer or rxData;

               -- Check for non-zero footer
               if (v.footer /= 0) then
                  -- Set the flag
                  v.devSelected := '0';
               end if;

               -- Next state
               v.state := RX_XSUM_S;

            end if;
         ----------------------------------------------------------------------
         when RX_XSUM_S =>
            -- Wait for non-control word
            if (rxValid = '1')and (rxDataK = '0') then

               -- Send IDLE char
               v.txValid := '1';
               v.txData  := CODE_IDLE_C;
               v.txDataK := '1';

               -- Check if wrong checksum
               if (rxData /= not(r.rxXsum)) then

                  -- Set the flag
                  v.devSelected := '0';

                  -- Set the footer error bit
                  v.footer(SUGOI_FOOTER_XSUM_ERROR_C) := '1';

               end if;

               -- Next state
               v.state := RX_EOF_S;

            end if;
         ----------------------------------------------------------------------
         when RX_EOF_S =>
            -- Wait for EOF
            if (rxValid = '1')and (rxDataK = '1') and (rxData = CODE_EOF_C)then

               -- Send IDLE char
               v.txValid := '1';
               v.txData  := CODE_IDLE_C;
               v.txDataK := '1';

               -- Check for read operation
               if (r.RnW = '1') then
                  -- Start AXI-Lite read transaction
                  v.axilReadMaster.arvalid := r.devSelected;
                  v.axilReadMaster.rready  := r.devSelected;
                  -- Next state
                  v.state                  := RD_TXN_S;
               -- Else write operation
               else
                  -- Start AXI-Lite write transaction
                  v.axilWriteMaster.awvalid := r.devSelected;
                  v.axilWriteMaster.wvalid  := r.devSelected;
                  v.axilWriteMaster.bready  := r.devSelected;
                  -- Next state
                  v.state                   := WR_TXN_S;
               end if;

            end if;
         ----------------------------------------------------------------------
         when RD_TXN_S =>
            -- Check if read transaction is done
            if (r.axilReadMaster.arvalid = '0') and (r.axilReadMaster.rready = '0') then
               -- Next state
               v.state := TX_DATA_S;
            end if;
         ----------------------------------------------------------------------
         when WR_TXN_S =>
            -- Check if write transaction is done
            if (r.axilWriteMaster.awvalid = '0') and(r.axilWriteMaster.wvalid = '0') and (r.axilWriteMaster.bready = '0') then
               -- Next state
               v.state := TX_DATA_S;
            end if;
         ----------------------------------------------------------------------
         when TX_DATA_S =>
            -- Wait for IDLE word
            if (rxValid = '1') and (rxDataK = '1') and (rxData = CODE_IDLE_C) then

               -- Send the memory data
               v.txValid := '1';
               v.txData  := r.memData(31 downto 24);
               v.txDataK := '0';

               -- Update the TX checksum only
               v.txXsum := r.txXsum + v.txData;

               -- Update the byte shift register
               v.memData := r.memData(23 downto 0) & x"00";

               -- Increment the counter
               v.byteCnt := r.byteCnt + 1;

               -- Check the counter
               if (r.byteCnt = 3) then
                  -- Next state
                  v.state := TX_FOOTER_S;
               end if;

            end if;
         ----------------------------------------------------------------------
         when TX_FOOTER_S =>
            -- Wait for IDLE word
            if (rxValid = '1') and (rxDataK = '1') and (rxData = CODE_IDLE_C) then

               -- Send the footer data
               v.txValid := '1';
               v.txData  := r.footer;
               v.txDataK := '0';

               -- Update the TX checksum only
               v.txXsum := r.txXsum + v.txData;

               -- Reset flags
               v.footer := (others => '0');

               -- Next state
               v.state := TX_XSUM_S;

            end if;
         ----------------------------------------------------------------------
         when TX_XSUM_S =>
            -- Wait for IDLE word
            if (rxValid = '1') and (rxDataK = '1') and (rxData = CODE_IDLE_C) then

               -- Send the checksum value
               v.txValid := '1';
               v.txData  := not(r.txXsum);  --  one's complement
               v.txDataK := '0';

               -- Next state
               v.state := TX_EOF_S;

            end if;
         ----------------------------------------------------------------------
         when TX_EOF_S =>
            -- Wait for IDLE word
            if (rxValid = '1') and (rxDataK = '1') and (rxData = CODE_IDLE_C) then

               -- Send the footer data
               v.txValid := '1';
               v.txData  := CODE_EOF_C;
               v.txDataK := '1';

               -- Next state
               v.state := RX_SOF_S;

            end if;
      ----------------------------------------------------------------------
      end case;

      -- De-select the device if error was detected during framing
      if (r.footer /= 0) then
         v.devSelected := '0';
      end if;

      -- Check for global reset
      if (r.rst = '1') then

         -- Reset counters
         v.byteCnt := (others => '0');

         -- Reset the state machine
         v.state := RX_SOF_S;

         -- Reset the AXI-Lite interface
         v.axilReadMaster  := AXI_LITE_READ_MASTER_INIT_C;
         v.axilWriteMaster := AXI_LITE_WRITE_MASTER_INIT_C;

      end if;

      -- Outputs
      linkup          <= r.linkup;
      rst             <= r.rst;
      rstL            <= r.rstL;
      opCode          <= r.opCode;
      rxSlip          <= r.rxSlip;
      txValid         <= r.txValid;
      txData          <= r.txData;
      txDataK         <= r.txDataK;
      axilReadMaster  <= r.axilReadMaster;
      axilWriteMaster <= r.axilWriteMaster;

      -- Check for active error condition + enough time for data pipeline to be stable
      if (rxValid = '1') and (rxError = '1') and (r.stableCnt(r.stableCnt'high) = '0') then
         v := REG_INIT_C;

      elsif (RST_ASYNC_G = false and pwrOnRst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (clk, pwrOnRst) is
   begin
      if (RST_ASYNC_G and pwrOnRst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
