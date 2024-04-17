-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: This controller is designed around the Micron PC28F FLASH IC.
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

entity AxiMicronP30Reg is
   generic (
      TPD_G              : time             := 1 ns;
      EN_PASSWORD_LOCK_G : boolean          := false;
      PASSWORD_LOCK_G    : slv(31 downto 0) := x"DEADBEEF";
      MEM_ADDR_MASK_G    : slv(31 downto 0) := x"00000000";
      AXI_CLK_FREQ_G     : real             := 200.0E+6);  -- units of Hz
   port (
      -- FLASH Interface
      flashAddr      : out slv(30 downto 0);
      flashAdv       : out sl;
      flashClk       : out sl;
      flashRstL      : out sl;
      flashCeL       : out sl;
      flashOeL       : out sl;
      flashWeL       : out sl;
      flashTri       : out sl;
      flashDin       : out slv(15 downto 0);
      flashDout      : in  slv(15 downto 0);
      -- AXI-Lite Register Interface
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;
      -- Clocks and Resets
      axiClk         : in  sl;
      axiRst         : in  sl);
end AxiMicronP30Reg;

architecture rtl of AxiMicronP30Reg is

   constant HALF_CYCLE_PERIOD_C : real := 128.0E-9;  -- units of seconds

   constant HALF_CYCLE_FREQ_C : real := (1.0 / HALF_CYCLE_PERIOD_C);  -- units of Hz

   constant MAX_CNT_C : natural := getTimeRatio(AXI_CLK_FREQ_G, HALF_CYCLE_FREQ_C);

   type stateType is (
      IDLE_S,
      RAM_READ_S,
      BLOCK_RD_S,
      BLOCK_WR_S,
      CMD_LOW_S,
      CMD_HIGH_S,
      WAIT_S,
      DATA_LOW_S,
      DATA_HIGH_S);

   type RegType is record
      -- PROM Control Signals
      tristate      : sl;
      ceL           : sl;
      oeL           : sl;
      RnW           : sl;
      weL           : sl;
      cnt           : natural range 0 to (MAX_CNT_C+1);
      din           : slv(15 downto 0);
      dataReg       : slv(15 downto 0);
      addr          : slv(30 downto 0);
      wrCmd         : slv(15 downto 0);
      wrData        : slv(15 downto 0);
      test          : slv(31 downto 0);
      -- Block Transfer signals
      lockCmd       : sl;
      blockRd       : sl;
      blockWr       : sl;
      blockCnt      : slv(7 downto 0);
      xferSize      : slv(7 downto 0);
      -- RAM Buffer Signals
      ramRd         : slv(1 downto 0);
      ramWe         : sl;
      ramDin        : slv(15 downto 0);
      waddr         : slv(7 downto 0);
      raddr         : slv(7 downto 0);
      -- AXI-Lite Signals
      axiReadSlave  : AxiLiteReadSlaveType;
      axiWriteSlave : AxiLiteWriteSlaveType;
      -- Status Machine
      state         : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      -- PROM Control Signals
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
      -- Block Transfer signals
      lockCmd       => '0',
      blockRd       => '0',
      blockWr       => '0',
      blockCnt      => (others => '0'),
      xferSize      => (others => '0'),
      -- RAM Buffer Signals
      ramRd         => (others => '0'),
      ramWe         => '0',
      ramDin        => (others => '0'),
      waddr         => (others => '0'),
      raddr         => (others => '0'),
      -- AXI-Lite Signals
      axiReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axiWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      -- Status Machine
      state         => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal ramDout : slv(15 downto 0);

   -- attribute dont_touch             : string;
   -- attribute dont_touch of r        : signal is "true";
   -- attribute dont_touch of ramDout  : signal is "true";

begin

   comb : process (axiReadMaster, axiRst, axiWriteMaster, flashDout, r,
                   ramDout) is
      variable v            : RegType;
      variable axiStatus    : AxiLiteStatusType;
      variable axiWriteResp : slv(1 downto 0);
      variable axiReadResp  : slv(1 downto 0);
      variable i            : natural;
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
      v.ramWe      := '0';

      -- Shift register
      v.ramRd(1) := r.ramRd(0);
      v.ramRd(0) := '0';

      -- Determine the transaction type
      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Reset variables
            v.lockCmd  := '0';
            v.blockRd  := '0';
            v.blockWr  := '0';
            v.blockCnt := x"00";
            v.raddr    := x"00";
            -------------------------------------------------------------------
            -- Check for a read request
            -------------------------------------------------------------------
            if (axiStatus.readEnable = '1') then
               -- Check for RAM access
               if (axiReadMaster.araddr(10) = '1') then
                  -- Read the ram
                  v.ramRd(0) := '1';
                  v.raddr    := axiReadMaster.araddr(9 downto 2);
                  -- Next state
                  v.state    := RAM_READ_S;
               else
                  case (axiReadMaster.araddr(7 downto 0)) is
                     -------------------------
                     -- Non-buffered Interface
                     -------------------------
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
                        v.axiReadSlave.rdata := MEM_ADDR_MASK_G;
                     -------------------------
                     -- Buffered Interface
                     -------------------------
                     when x"80" =>
                        -- Get the address bus
                        v.axiReadSlave.rdata(7 downto 0) := r.xferSize;
                     when x"84" =>
                        -- Get the RnW
                        v.axiReadSlave.rdata(31)          := r.RnW;
                        -- Get the address bus
                        v.axiReadSlave.rdata(30 downto 0) := r.addr;
                     when others =>
                        axiReadResp := AXI_RESP_DECERR_C;
                  end case;
                  -- Send AXI-Lite Response
                  axiSlaveReadResponse(v.axiReadSlave, axiReadResp);
               end if;
            -------------------------------------------------------------------
            -- Check for a write request
            -------------------------------------------------------------------
            elsif (axiStatus.writeEnable = '1') then
               -- Check for RAM access
               if (axiWriteMaster.awaddr(10) = '1') then
                  -- Write the data to RAM
                  v.waddr  := axiWriteMaster.awaddr(9 downto 2);
                  v.ramDin := axiWriteMaster.wdata(15 downto 0);
                  v.ramWe  := '1';
               else
                  case (axiWriteMaster.awaddr(7 downto 0)) is
                     -------------------------
                     -- Non-buffered Interface
                     -------------------------
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
                     -------------------------
                     -- Buffered Interface
                     -------------------------
                     when x"80" =>
                        -- Set the block transfer size
                        v.xferSize := axiWriteMaster.wdata(7 downto 0);
                     when x"84" =>
                        -- Set the RnW
                        v.RnW  := axiWriteMaster.wdata(31);
                        -- Set the address bus
                        v.addr := axiWriteMaster.wdata(30 downto 0);
                        -- Check the mode
                        if (axiWriteMaster.wdata(31) = '1') then
                           -- Set the flag
                           v.blockRd := '1';
                           -- Set the opCode bus
                           v.wrCmd   := x"00FF";
                           -- Set the input data bus
                           v.wrData  := x"00FF";
                           -- Next state
                           v.state   := CMD_LOW_S;
                        else
                           -- Set the flag
                           v.blockWr := '1';
                           -- Next state
                           v.state   := BLOCK_WR_S;
                        end if;
                     when others =>
                        axiWriteResp := AXI_RESP_DECERR_C;
                  end case;
               end if;
               -- Send AXI-Lite response
               axiSlaveWriteResponse(v.axiWriteSlave, axiWriteResp);
            end if;
         ----------------------------------------------------------------------
         when RAM_READ_S =>
            -- Check if the RAM data is updated
            if r.ramRd = "00" then
               -- Set the data bus
               v.axiReadSlave.rdata(15 downto 0) := ramDout;
               -- Send AXI-Lite Response
               axiSlaveReadResponse(v.axiReadSlave, axiReadResp);
               -- Next state
               v.state                           := IDLE_S;
            end if;
         ----------------------------------------------------------------------
         when BLOCK_RD_S =>
            -- Write the data to RAM
            v.waddr  := r.blockCnt;
            v.ramDin := r.dataReg;
            v.ramWe  := '1';
            -- Check the counter
            if (r.blockCnt = r.xferSize) then
               -- Next state
               v.state := IDLE_S;
            else
               -- Increment the counters
               v.blockCnt := r.blockCnt + 1;
               v.addr     := r.addr + 1;
               -- Next state
               v.state    := CMD_LOW_S;
            end if;
         ----------------------------------------------------------------------
         when BLOCK_WR_S =>
            -- Increment the counter
            v.blockCnt := r.blockCnt + 1;
            -- Check the counter
            case r.blockCnt is
               when x"00" =>
                  -- Send the "unlock the block" command
                  v.RnW    := '0';
                  v.wrCmd  := x"0060";
                  v.wrData := x"00D0";
               when x"01" =>
                  -- Send the "reset the status register" command
                  v.RnW    := '0';
                  v.wrCmd  := x"0050";
                  v.wrData := x"0050";
               when x"02" =>
                  -- Send the "program" command
                  v.RnW    := '0';
                  v.wrCmd  := x"0040";
                  v.wrData := ramDout;  -- Send the BRAM data
               -- Get the status register
               when x"03" =>
                  v.RnW    := '1';
                  v.wrCmd  := x"0070";
                  v.wrData := x"00FF";
               when others =>
                  -- Check if FLASH is still busy
                  if r.dataReg(7) = '0' then
                     -- Set the counter
                     v.blockCnt := x"04";
                     -- Get the status register
                     v.RnW      := '1';
                     v.wrCmd    := x"0070";
                     v.wrData   := x"00FF";
                  -- Check for programming failure
                  elsif r.dataReg(4) = '1' then
                     -- Set the counter
                     v.blockCnt := x"01";
                     -- Send the "unlock the block" command
                     v.RnW      := '0';
                     v.wrCmd    := x"0060";
                     v.wrData   := x"00D0";
                  else
                     -- Send the "lock the block" command
                     v.RnW      := '0';
                     v.wrCmd    := x"0060";
                     v.wrData   := x"0001";
                     v.lockCmd  := '1';
                     -- Reset the counter
                     v.blockCnt := x"00";
                     -- Check the Block RAM address
                     if (r.raddr = r.xferSize) then
                        -- Reset the flag
                        v.blockWr := '0';
                     else
                        -- Increment the counter
                        v.raddr := r.raddr + 1;
                     end if;
                  end if;
            end case;
            -- Next state
            v.state := CMD_LOW_S;
         ----------------------------------------------------------------------
         when CMD_LOW_S =>
            -- Check for password locking
            if(EN_PASSWORD_LOCK_G) then
               -- Check if password write to test register
               if(r.test = PASSWORD_LOCK_G) then
                  v.ceL := '0';
               end if;
            else
               v.ceL := '0';
            end if;
            v.oeL      := '1';
            v.weL      := '0';
            v.tristate := '0';
            v.din      := r.wrCmd;
            -- Increment the counter
            v.cnt      := r.cnt + 1;
            -- Check the counter
            if (r.cnt = MAX_CNT_C) then
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
            if (r.cnt = MAX_CNT_C) then
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
            if (r.cnt = MAX_CNT_C) then
               -- Reset the counter
               v.cnt   := 0;
               -- Next state
               v.state := DATA_LOW_S;
            end if;
         ----------------------------------------------------------------------
         when DATA_LOW_S =>
            -- Check for password locking
            if(EN_PASSWORD_LOCK_G) then
               -- Check if password write to test register
               if(r.test = PASSWORD_LOCK_G) then
                  v.ceL := '0';
               end if;
            else
               v.ceL := '0';
            end if;
            v.oeL      := not(r.RnW);
            v.weL      := r.RnW;
            v.tristate := r.RnW;
            v.din      := r.wrData;
            -- Increment the counter
            v.cnt      := r.cnt + 1;
            -- Check the counter
            if (r.cnt = MAX_CNT_C) then
               -- Reset the counter
               v.cnt     := 0;
               --latch the data bus value
               v.dataReg := flashDout;
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
            if (r.cnt = MAX_CNT_C) then
               -- Reset the counter
               v.cnt := 0;
               -- Check for block read
               if (r.blockRd = '1') then
                  -- Next state
                  v.state := BLOCK_RD_S;
               -- Check for block write
               elsif (r.blockWr = '1') then
                  -- Check for the lock CMD
                  if (r.lockCmd = '1') then
                     -- Reset the flag
                     v.lockCmd := '0';
                     -- Increment the counter
                     v.addr    := r.addr + 1;
                  end if;
                  -- Next state
                  v.state := BLOCK_WR_S;
               else
                  -- Next state
                  v.state := IDLE_S;
               end if;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Synchronous Reset
      if (axiRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      for i in 0 to 30 loop
         flashAddr(i) <= r.addr(i) or MEM_ADDR_MASK_G(i);
      end loop;
      flashAdv      <= '0';
      flashClk      <= '1';
      flashRstL     <= not(axiRst);
      flashCeL      <= r.ceL;
      flashOeL      <= r.oeL;
      flashWeL      <= r.weL;
      flashDin      <= r.din;
      flashTri      <= r.tristate;
      axiReadSlave  <= r.axiReadSlave;
      axiWriteSlave <= r.axiWriteSlave;

   end process comb;

   seq : process (axiClk) is
   begin
      if rising_edge(axiClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_Ram : entity surf.SimpleDualPortRam
      generic map(
         TPD_G         => TPD_G,
         MEMORY_TYPE_G => "block",
         DATA_WIDTH_G  => 16,
         ADDR_WIDTH_G  => 8)
      port map (
         -- Port A
         clka  => axiClk,
         wea   => r.ramWe,
         addra => r.waddr,
         dina  => r.ramDin,
         -- Port B
         clkb  => axiClk,
         rstb  => '0', -- Cadence Genus doesn't support not(RST_POLARITY_G) on port's initial value : Could not resolve complex expression. [CDFG-200] [elaborate]
         addrb => r.raddr,
         doutb => ramDout);

end rtl;
