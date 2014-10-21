-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AxiMicronP30Reg.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-10-21
-- Last update: 2014-10-21
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: This controller is designed around the Micron PC28F FLASH IC.
--
-- Write Only Registers:
-- Addr (0x00 << 2): Bits[31:16] = wr_data(1) // opCode
--                   Bits[15:00] = wr_data(0) // data
--
-- Addr (0x01 << 2): Bits[31]    = RnW bit
--                   Bits[30:00] = address bus
--
-- Read Only Registers:
-- Addr (0x00 << 2): Bits[31:16] = wr_data(1) // opCode
--                   Bits[15:00] = wr_data(0) // data
--
-- Addr (0x01 << 2): Bits[31]    = RnW bit
--                   Bits[30:00] = address bus
--
-- Addr (0x02 << 2): Bits[31:16] = zeros
--                   Bits[15:00] = rd_data
--
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

library unisim;
use unisim.vcomponents.all;

entity AxiMicronP30Reg is
   generic (
      TPD_G            : time            := 1 ns;
      AXI_CLK_FREQ_G   : real            := 200.0E+6;  -- units of Hz
      AXI_ERROR_RESP_G : slv(1 downto 0) := AXI_RESP_SLVERR_C);
   port (
      -- FLASH Interface 
      flashAddr      : out   slv(30 downto 0);
      flashData      : inout slv(15 downto 0);
      flashCe        : out   sl;
      flashOe        : out   sl;
      flashWe        : out   sl;
      -- AXI-Lite Register Interface
      axiReadMaster  : in    AxiLiteReadMasterType;
      axiReadSlave   : out   AxiLiteReadSlaveType;
      axiWriteMaster : in    AxiLiteWriteMasterType;
      axiWriteSlave  : out   AxiLiteWriteSlaveType;
      -- Clocks and Resets
      axiClk         : in    sl;
      axiRst         : in    sl);
end AxiMicronP30Reg;

architecture rtl of AxiMicronP30Reg is

   constant HALF_CYCLE_PERIOD_C : real := 128.0E-9;  -- units of seconds

   constant HALF_CYCLE_FREQ_C : real := getRealDiv(1, HALF_CYCLE_PERIOD_C);  -- units of Hz

   constant MAX_CNT_C : natural := getTimeRatio(AXI_CLK_FREQ_G, HALF_CYCLE_FREQ_C);
   
   type stateType is (
      IDLE_S,
      CMD_LOW_S,
      CMD_HIGH_S,
      WAIT_S,
      DATA_LOW_S,
      DATA_HIGH_S);

   type RegType is record
      tristate      : sl;
      ce            : sl;
      oe            : sl;
      RnW           : sl;
      we            : sl;
      cnt           : natural range 0 to MAX_CNT_C;
      din           : slv(15 downto 0);
      dataReg       : slv(15 downto 0);
      addr          : slv(30 downto 0);
      wrData        : Slv16Array(0 to 1);
      state         : StateType;
      axiReadSlave  : AxiLiteReadSlaveType;
      axiWriteSlave : AxiLiteWriteSlaveType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      tristate      => '1',
      ce            => '1',
      oe            => '1',
      RnW           => '1',
      we            => '1',
      cnt           => 0,
      din           => x"0000",
      dataReg       => x"0000",
      addr          => (others => '0'),
      wrData        => (others => x"0000"),
      state         => IDLE_S,
      axiReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axiWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal dout : slv(15 downto 0);
   
begin

   comb : process (axiReadMaster, axiRst, axiWriteMaster, dout, r) is
      variable v            : RegType;
      variable axiStatus    : AxiLiteStatusType;
      variable axiWriteResp : slv(1 downto 0);
      variable axiReadResp  : slv(1 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Determine the transaction type
      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);

      if (axiStatus.writeEnable = '1') and (r.state = IDLE_S) then
         -- Check for an out of 32 bit aligned address
         axiWriteResp := ite(axiWriteMaster.awaddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_ERROR_RESP_G);
         -- Decode address and perform write
         case (axiWriteMaster.awaddr(9 downto 2)) is
            when x"00" =>
               -- Set the opCode bus
               v.wrData(1) := axiWriteMaster.wdata(31 downto 16);
               -- Set the input data bus
               v.wrData(0) := axiWriteMaster.wdata(15 downto 0);
            when x"01" =>
               -- Set the RnW
               v.RnW   := axiWriteMaster.wdata(31);
               -- Set the address bus
               v.addr  := axiWriteMaster.wdata(30 downto 0);
               -- Next state
               v.state := CMD_LOW_S;
            when others =>
               axiWriteResp := AXI_ERROR_RESP_G;
         end case;
         -- Send AXI response
         axiSlaveWriteResponse(v.axiWriteSlave, axiWriteResp);
      elsif (axiStatus.readEnable = '1') and (r.state = IDLE_S) then
         -- Check for an out of 32 bit aligned address
         axiReadResp          := ite(axiReadMaster.araddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_ERROR_RESP_G);
         -- Reset the register
         v.axiReadSlave.rdata := (others => '0');
         -- Decode address and assign read data
         case (axiReadMaster.araddr(9 downto 2)) is
            when x"00" =>
               -- Get the opCode bus
               v.axiReadSlave.rdata(31 downto 16) := r.wrData(1);
               -- Get the input data bus
               v.axiReadSlave.rdata(15 downto 0)  := r.wrData(0);
            when x"01" =>
               -- Get the RnW
               v.axiReadSlave.rdata(31)          := r.RnW;
               -- Get the address bus
               v.axiReadSlave.rdata(30 downto 0) := r.addr;
            when x"02" =>
               -- Get the output data bus
               v.axiReadSlave.rdata(15 downto 0) := r.dataReg;
            when others =>
               axiReadResp := AXI_ERROR_RESP_G;
         end case;
         -- Send Axi Response
         axiSlaveReadResponse(v.axiReadSlave, axiReadResp);
      end if;

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            v.ce       := '1';
            v.oe       := '1';
            v.we       := '1';
            v.tristate := '1';
         ----------------------------------------------------------------------
         when CMD_LOW_S =>
            v.ce       := '0';
            v.oe       := '1';
            v.we       := '0';
            v.tristate := '0';
            v.din      := r.wrData(1);
            -- Increment the counter
            v.cnt      := r.cnt + 1;
            -- Check the counter 
            if r.cnt = MAX_CNT_C then
               -- Reset the counter
               v.cnt   := 0;
               -- Next state
               v.state := CMD_HIGH_S;
            end if;
         ----------------------------------------------------------------------
         when CMD_HIGH_S =>
            v.ce       := '1';
            v.oe       := '1';
            v.we       := '1';
            v.tristate := '0';
            v.din      := r.wrData(1);
            -- Increment the counter
            v.cnt      := r.cnt + 1;
            -- Check the counter 
            if r.cnt = MAX_CNT_C then
               -- Reset the counter
               v.cnt   := 0;
               -- Next state
               v.state := WAIT_S;
            end if;
         ----------------------------------------------------------------------
         when WAIT_S =>
            v.ce       := '1';
            v.oe       := '1';
            v.we       := '1';
            v.tristate := '1';
            v.din      := r.wrData(0);
            -- Increment the counter
            v.cnt      := r.cnt + 1;
            -- Check the counter 
            if r.cnt = MAX_CNT_C then
               -- Reset the counter
               v.cnt   := 0;
               -- Next state
               v.state := DATA_LOW_S;
            end if;
         ----------------------------------------------------------------------
         when DATA_LOW_S =>
            v.ce       := '0';
            v.oe       := not(r.RnW);
            v.we       := r.RnW;
            v.tristate := r.RnW;
            v.din      := r.wrData(0);
            -- Increment the counter
            v.cnt      := r.cnt + 1;
            -- Check the counter 
            if r.cnt = MAX_CNT_C then
               -- Reset the counter
               v.cnt     := 0;
               --latch the data bus value
               v.dataReg := dout;
               -- Next state
               v.state   := DATA_HIGH_S;
            end if;
         ----------------------------------------------------------------------
         when DATA_HIGH_S =>
            v.ce       := '1';
            v.oe       := '1';
            v.we       := '1';
            v.tristate := r.RnW;
            v.din      := r.wrData(0);
            -- Increment the counter
            v.cnt      := r.cnt + 1;
            -- Check the counter 
            if r.cnt = MAX_CNT_C then
               -- Reset the counter
               v.cnt   := 0;
               -- Next state
               v.state := IDLE_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Synchronous Reset
      if axiRst = '1' then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      flashAddr <= r.addr;
      flashCe   <= r.ce;
      flashOe   <= r.oe;
      flashWe   <= r.we;
      
   end process comb;

   seq : process (axiClk) is
   begin
      if rising_edge(axiClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   GEN_IOBUF :
   for i in 15 downto 0 generate
      IOBUF_inst : IOBUF
         port map (
            O  => dout(i),              -- Buffer output
            IO => flashData(i),         -- Buffer inout port (connect directly to top-level port)
            I  => r.din(i),             -- Buffer input
            T  => r.tristate);          -- 3-state enable input, high=input, low=output     
   end generate GEN_IOBUF;
   
end rtl;
