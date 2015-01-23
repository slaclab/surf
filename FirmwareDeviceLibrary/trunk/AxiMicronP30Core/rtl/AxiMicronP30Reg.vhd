-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AxiMicronP30Reg.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-10-21
-- Last update: 2015-01-23
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: This controller is designed around the Micron PC28F FLASH IC.
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
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
      flashDq        : inout slv(15 downto 0);
      flashCeL       : out   sl;
      flashOeL       : out   sl;
      flashWeL       : out   sl;
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
      FAST_MODE_S,
      CMD_LOW_S,
      CMD_HIGH_S,
      WAIT_S,
      DATA_LOW_S,
      DATA_HIGH_S);

   type RegType is record
      tristate      : sl;
      ceL           : sl;
      oeL           : sl;
      RnW           : sl;
      weL           : sl;
      cnt           : natural range 0 to MAX_CNT_C;
      din           : slv(15 downto 0);
      dataReg       : slv(15 downto 0);
      addr          : slv(30 downto 0);
      wrCmd         : slv(15 downto 0);
      wrData        : slv(15 downto 0);
      test          : slv(31 downto 0);
      fastProgEn    : sl;
      fastData      : slv(15 downto 0);
      fastCnt       : slv(3 downto 0);
      axiReadSlave  : AxiLiteReadSlaveType;
      axiWriteSlave : AxiLiteWriteSlaveType;
      state         : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      tristate      => '1',
      ceL           => '1',
      oeL           => '1',
      RnW           => '1',
      weL           => '1',
      cnt           => 0,
      din           => x"0000",
      dataReg       => x"0000",
      addr          => (others => '0'),
      wrCmd         => (others => '0'),
      wrData        => (others => '0'),
      test          => (others => '0'),
      fastProgEn    => '0',
      fastData      => (others => '0'),
      fastCnt       => (others => '0'),
      axiReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axiWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      state         => IDLE_S);

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

      -- Reset the strobing signals
      v.ceL        := '1';
      v.oeL        := '1';
      v.weL        := '1';
      v.tristate   := '1';
      axiWriteResp := AXI_RESP_OK_C;
      axiReadResp  := AXI_RESP_OK_C;

      -- Determine the transaction type
      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check for a read request            
            if (axiStatus.readEnable = '1') then
               -- Reset the register
               v.axiReadSlave.rdata := (others => '0');
               -- Decode address and assign read data
               case (axiReadMaster.araddr(7 downto 0)) is
                  when x"00" =>
                     -- Get the opCode bus
                     v.axiReadSlave.rdata(31 downto 16) := r.wrCmd;
                     -- Get the input data bus
                     v.axiReadSlave.rdata(15 downto 0)  := r.wrData;
                  when x"04" =>
                     -- Get the RnW
                     v.axiReadSlave.rdata(31)          := r.RnW;
                     -- Get the address bus
                     v.axiReadSlave.rdata(30 downto 0) := r.addr;
                  when x"08" =>
                     -- Get the output data bus
                     v.axiReadSlave.rdata(15 downto 0) := r.dataReg;
                  when x"0C" =>
                     v.axiReadSlave.rdata := r.test;
                  when x"10" =>
                     -- Get the address bus
                     v.axiReadSlave.rdata(30 downto 0) := r.addr;
                  when others =>
                     axiReadResp := AXI_ERROR_RESP_G;
               end case;
               -- Send AXI-Lite Response
               axiSlaveReadResponse(v.axiReadSlave, axiReadResp);
            end if;
            -- Check for a write request
            if (axiStatus.writeEnable = '1') then
               -- Decode address and perform write
               case (axiWriteMaster.awaddr(7 downto 0)) is
                  when x"00" =>
                     -- Set the opCode bus
                     v.wrCmd  := axiWriteMaster.wdata(31 downto 16);
                     -- Set the input data bus
                     v.wrData := axiWriteMaster.wdata(15 downto 0);
                  when x"04" =>
                     -- Set the RnW
                     v.RnW   := axiWriteMaster.wdata(31);
                     -- Set the address bus
                     v.addr  := axiWriteMaster.wdata(30 downto 0);
                     -- Next state
                     v.state := CMD_LOW_S;
                  when x"0C" =>
                     v.test := axiWriteMaster.wdata;
                  when x"10" =>
                     -- Set the address bus
                     v.addr := axiWriteMaster.wdata(30 downto 0);
                  when x"14" =>
                     -- Set the flag
                     v.fastProgEn := '1';
                     -- Set the data bus
                     v.fastData   := axiWriteMaster.wdata(15 downto 0);
                     -- Next state
                     v.state      := FAST_MODE_S;
                  when others =>
                     axiWriteResp := AXI_ERROR_RESP_G;
               end case;
               -- Send AXI-Lite response
               axiSlaveWriteResponse(v.axiWriteSlave, axiWriteResp);
            end if;
         ----------------------------------------------------------------------
         when FAST_MODE_S =>
            -- Increment the counter
            v.fastCnt := r.fastCnt + 1;
            -- Check the counter
            case r.fastCnt is
               when x"0" =>
                  -- Send the "unlock the block" command
                  v.RnW    := '0';
                  v.wrCmd  := x"0060";
                  v.wrData := x"00D0";
               when x"1" =>
                  -- Send the "reset the status register" command
                  v.RnW    := '0';
                  v.wrCmd  := x"0050";
                  v.wrData := x"0050";
               when x"2" =>
                  -- Send the "program" command
                  v.RnW    := '0';
                  v.wrCmd  := x"0040";
                  v.wrData := r.fastData;
               -- Get the status register
               when x"3" =>
                  v.RnW   := '1';
                  v.wrCmd := x"0070";
               when others =>
                  -- Check if FLASH is still busy
                  if r.dataReg(7) = '0' then
                     -- Set the counter
                     v.fastCnt := x"4";
                     -- Get the status register
                     v.RnW     := '1';
                     v.wrCmd   := x"0070";
                  -- Check for programming failure
                  elsif r.dataReg(4) = '1' then
                     -- Set the counter
                     v.fastCnt := x"1";
                     -- Send the "unlock the block" command
                     v.RnW     := '0';
                     v.wrCmd   := x"0060";
                     v.wrData  := x"00D0";
                  else
                     -- Send the "lock the block" command
                     v.RnW        := '0';
                     v.wrCmd      := x"0060";
                     v.wrData     := x"0001";
                     -- Reset the flag
                     v.fastProgEn := '0';
                     -- Reset the counter
                     v.fastCnt    := x"0";
                  end if;
            end case;
            -- Next state
            v.state := CMD_LOW_S;
         ----------------------------------------------------------------------
         when CMD_LOW_S =>
            v.ceL      := '0';
            v.oeL      := '1';
            v.weL      := '0';
            v.tristate := '0';
            v.din      := r.wrCmd;
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
            v.ceL      := '1';
            v.oeL      := '1';
            v.weL      := '1';
            v.tristate := '0';
            v.din      := r.wrCmd;
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
            v.ceL      := '1';
            v.oeL      := '1';
            v.weL      := '1';
            v.tristate := '1';
            v.din      := r.wrData;
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
            v.ceL      := '0';
            v.oeL      := not(r.RnW);
            v.weL      := r.RnW;
            v.tristate := r.RnW;
            v.din      := r.wrData;
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
            v.ceL      := '1';
            v.oeL      := '1';
            v.weL      := '1';
            v.tristate := r.RnW;
            v.din      := r.wrData;
            -- Increment the counter
            v.cnt      := r.cnt + 1;
            -- Check the counter 
            if r.cnt = MAX_CNT_C then
               -- Reset the counter
               v.cnt := 0;
               -- Check for fast program command mode
               if r.fastProgEn = '1' then
                  -- Next state
                  v.state := FAST_MODE_S;
               else
                  -- Next state
                  v.state := IDLE_S;
               end if;
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
      flashAddr     <= r.addr;
      flashCeL      <= r.ceL;
      flashOeL      <= r.oeL;
      flashWeL      <= r.weL;
      axiReadSlave  <= r.axiReadSlave;
      axiWriteSlave <= r.axiWriteSlave;
      
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
            IO => flashDq(i),           -- Buffer inout port (connect directly to top-level port)
            I  => r.din(i),             -- Buffer input
            T  => r.tristate);          -- 3-state enable input, high=input, low=output     
   end generate GEN_IOBUF;

end rtl;
