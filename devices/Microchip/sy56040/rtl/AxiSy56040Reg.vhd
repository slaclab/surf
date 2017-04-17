-------------------------------------------------------------------------------
-- File       : AxiSy56040Reg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-12
-- Last update: 2016-09-20
-------------------------------------------------------------------------------
-- Description: This controller is designed around the Micrel SY56040AR.
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

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

entity AxiSy56040Reg is
   generic (
      TPD_G            : time                  := 1 ns;
      AXI_CLK_FREQ_G   : real                  := 200.0E+6;  -- units of Hz
      XBAR_DEFAULT_G   : Slv2Array(3 downto 0) := ("11", "10", "01", "00");
      AXI_ERROR_RESP_G : slv(1 downto 0)       := AXI_RESP_SLVERR_C);
   port (
      -- XBAR Ports 
      xBarSin        : out slv(1 downto 0);
      xBarSout       : out slv(1 downto 0);
      xBarConfig     : out sl;
      xBarLoad       : out sl;
      -- AXI-Lite Register Interface
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;
      -- Clocks and Resets
      axiClk         : in  sl;
      axiRst         : in  sl);
end AxiSy56040Reg;

architecture rtl of AxiSy56040Reg is

   constant PULSE_WIDTH_C : real    := 10.0E-9;              -- units of seconds
   constant PULSE_FREQ_C  : real    := 1.0 / PULSE_WIDTH_C;  -- units of Hz
   constant MAX_CNT_C     : natural := getTimeRatio(AXI_CLK_FREQ_G, PULSE_FREQ_C);

   type stateType is (
      IDLE_S,
      SETUP_S,
      LOAD_S,
      HOLD_S);

   type RegType is record
      sin           : slv(1 downto 0);
      sout          : slv(1 downto 0);
      load          : sl;
      config        : Slv2Array(3 downto 0);
      cnt           : natural range 0 to MAX_CNT_C;
      index         : natural range 0 to 3;
      -- AXI-Lite Signals
      axiReadSlave  : AxiLiteReadSlaveType;
      axiWriteSlave : AxiLiteWriteSlaveType;
      -- Status Machine
      state         : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      sin           => (others => '0'),
      sout          => (others => '0'),
      load          => '0',
      config        => XBAR_DEFAULT_G,
      cnt           => 0,
      index         => 0,
      -- AXI-Lite Signals
      axiReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axiWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      -- Status Machine
      state         => SETUP_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- attribute dont_touch             : string;
   -- attribute dont_touch of r        : signal is "true";

begin

   comb : process (axiReadMaster, axiRst, axiWriteMaster, r) is
      variable v            : RegType;
      variable axiStatus    : AxiLiteStatusType;
      variable axiWriteResp : slv(1 downto 0);
      variable axiReadResp  : slv(1 downto 0);
   begin
      -- Latch the current value
      v := r;

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
               axiReadResp          := AXI_RESP_OK_C;
               -- Decode address and assign read data
               case (axiReadMaster.araddr(3 downto 0)) is
                  when x"0" =>          -- OUT[0] Mapping
                     v.axiReadSlave.rdata(1 downto 0) := r.config(0);
                  when x"4" =>          -- OUT[1] Mapping
                     v.axiReadSlave.rdata(1 downto 0) := r.config(1);
                  when x"8" =>          -- OUT[2] Mapping
                     v.axiReadSlave.rdata(1 downto 0) := r.config(2);
                  when x"C" =>          -- OUT[3] Mapping
                     v.axiReadSlave.rdata(1 downto 0) := r.config(3);
                  when others =>
                     axiReadResp := AXI_ERROR_RESP_G;
               end case;
               -- Send AXI-Lite Response
               axiSlaveReadResponse(v.axiReadSlave, axiReadResp);
            -- Check for a write request
            elsif (axiStatus.writeEnable = '1') then
               axiWriteResp := AXI_RESP_OK_C;
               -- Decode address and perform write
               case (axiWriteMaster.awaddr(3 downto 0)) is
                  when x"0" =>          -- OUT[0] Mapping
                     v.config(0) := axiWriteMaster.wdata(1 downto 0);
                     v.state     := SETUP_S;
                  when x"4" =>          -- OUT[1] Mapping
                     v.config(1) := axiWriteMaster.wdata(1 downto 0);
                     v.state     := SETUP_S;
                  when x"8" =>          -- OUT[2] Mapping
                     v.config(2) := axiWriteMaster.wdata(1 downto 0);
                     v.state     := SETUP_S;
                  when x"C" =>          -- OUT[3] Mapping
                     v.config(3) := axiWriteMaster.wdata(1 downto 0);
                     v.state     := SETUP_S;
                  when others =>
                     axiWriteResp := AXI_ERROR_RESP_G;
               end case;
               -- Send AXI-Lite response
               axiSlaveWriteResponse(v.axiWriteSlave, axiWriteResp);
            end if;
         ----------------------------------------------------------------------
         when SETUP_S =>
            v.sin  := r.config(r.index);
            v.sout := toSLv(r.index, 2);
            v.load := '0';
            -- Increment the counter
            v.cnt  := r.cnt + 1;
            -- Check the counter 
            if r.cnt = MAX_CNT_C then
               -- Reset the counter
               v.cnt   := 0;
               -- Next state
               v.state := LOAD_S;
            end if;
         ----------------------------------------------------------------------
         when LOAD_S =>
            v.load := '1';
            -- Increment the counter
            v.cnt  := r.cnt + 1;
            -- Check the counter 
            if r.cnt = MAX_CNT_C then
               -- Reset the counter
               v.cnt   := 0;
               -- Next state
               v.state := HOLD_S;
            end if;
         ----------------------------------------------------------------------
         when HOLD_S =>
            v.load := '0';
            -- Increment the counter
            v.cnt  := r.cnt + 1;
            -- Check the counter 
            if r.cnt = MAX_CNT_C then
               -- Reset the counter
               v.cnt   := 0;
               -- Increment the counter
               v.index := r.index + 1;
               -- Check the counter 
               if r.index = 3 then
                  -- Reset the counter
                  v.index := 0;
                  -- Next state
                  v.state := IDLE_S;
               else
                  -- Next state
                  v.state := SETUP_S;
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
      axiReadSlave  <= r.axiReadSlave;
      axiWriteSlave <= r.axiWriteSlave;
      xBarSin       <= r.sin;
      xBarSout      <= r.sout;
      xBarConfig    <= r.load;
      xBarLoad      <= r.load;

   end process comb;

   seq : process (axiClk) is
   begin
      if rising_edge(axiClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
