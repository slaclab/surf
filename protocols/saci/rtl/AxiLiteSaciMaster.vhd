-------------------------------------------------------------------------------
-- File       : AxiLiteSaciMaster2.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-06-01
-- Last update: 2016-11-15
-------------------------------------------------------------------------------
-- Description: New and improved version of the AxiLiteSaciMaster.
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
use work.SaciMasterPkg.all;

entity AxiLiteSaciMaster is
   generic (
      TPD_G              : time                  := 1 ns;
      AXIL_ERROR_RESP_G  : slv(1 downto 0)       := AXI_RESP_DECERR_C;
      AXIL_CLK_PERIOD_G  : real                  := 8.0e-9;  -- In units of seconds
      AXIL_TIMEOUT_G     : real                  := 1.0E-3;  -- In units of seconds
      SACI_CLK_PERIOD_G  : real                  := 1.0e-6;  -- In units of seconds
      SACI_CLK_FREERUN_G : boolean               := false;
      SACI_NUM_CHIPS_G   : positive range 1 to 4 := 1;
      SACI_RSP_BUSSED_G  : boolean               := false);
   port (
      -- SACI interface
      saciClk         : out sl;
      saciCmd         : out sl;
      saciSelL        : out slv(SACI_NUM_CHIPS_G-1 downto 0);
      saciRsp         : in  slv(ite(SACI_RSP_BUSSED_G, 0, SACI_NUM_CHIPS_G-1) downto 0);
      -- AXI-Lite Register Interface
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end AxiLiteSaciMaster;

architecture rtl of AxiLiteSaciMaster is

   constant CHIP_BITS_C : integer := log2(SACI_NUM_CHIPS_G);
   constant TIMEOUT_C   : integer := integer(AXIL_TIMEOUT_G/AXIL_CLK_PERIOD_G)-1;

   type StateType is (
      IDLE_S,
      SACI_REQ_S,
      SACI_ACK_S);

   type RegType is record
      state          : StateType;
      saciRst        : sl;
      req            : sl;
      chip           : slv(log2(SACI_NUM_CHIPS_G)-1 downto 0);
      op             : sl;
      cmd            : slv(6 downto 0);
      addr           : slv(11 downto 0);
      wrData         : slv(31 downto 0);
      timer          : integer range 0 to TIMEOUT_C;
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;

   end record RegType;

   constant REG_INIT_C : RegType := (
      state          => IDLE_S,
      saciRst        => '1',
      req            => '0',
      chip           => (others => '0'),
      op             => '0',
      cmd            => (others => '0'),
      addr           => (others => '0'),
      wrData         => (others => '0'),
      timer          => 0,
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal ack    : sl;
   signal fail   : sl;
   signal rdData : slv(31 downto 0);

   -- attribute dont_touch      : string;
   -- attribute dont_touch of r : signal is "true";   

begin

   assert (AXIL_CLK_PERIOD_G < 1.0)
      report "AXIL_CLK_PERIOD_G must be < 1.0 seconds" severity failure;
   assert (AXIL_TIMEOUT_G < 1.0)
      report "AXIL_TIMEOUT_G must be < 1.0 seconds" severity failure;
   assert (SACI_CLK_PERIOD_G < 1.0)
      report "SACI_CLK_PERIOD_G must be < 1.0 seconds" severity failure;
   assert (AXIL_CLK_PERIOD_G < AXIL_TIMEOUT_G)
      report "AXIL_CLK_PERIOD_G must be < AXIL_TIMEOUT_G" severity failure;
   assert (AXIL_CLK_PERIOD_G < SACI_CLK_PERIOD_G)
      report "AXIL_CLK_PERIOD_G must be < SACI_CLK_PERIOD_G" severity failure;
   assert (SACI_CLK_PERIOD_G < AXIL_TIMEOUT_G)
      report "SACI_CLK_PERIOD_G must be < AXIL_TIMEOUT_G" severity failure;
   
   U_SaciMaster2_1 : entity work.SaciMaster2
      generic map (
         TPD_G              => TPD_G,
         SYS_CLK_PERIOD_G   => AXIL_CLK_PERIOD_G,
         SACI_CLK_PERIOD_G  => SACI_CLK_PERIOD_G,
         SACI_CLK_FREERUN_G => SACI_CLK_FREERUN_G,
         SACI_NUM_CHIPS_G   => SACI_NUM_CHIPS_G,
         SACI_RSP_BUSSED_G  => SACI_RSP_BUSSED_G)
      port map (
         sysClk   => axilClk,           -- [in]
         sysRst   => r.saciRst,         -- [in]
         req      => r.req,             -- [in]
         ack      => ack,               -- [out]
         fail     => fail,              -- [out]
         chip     => r.chip,            -- [in]
         op       => r.op,              -- [in]
         cmd      => r.cmd,             -- [in]
         addr     => r.addr,            -- [in]
         wrData   => r.wrData,          -- [in]
         rdData   => rdData,            -- [out]
         saciClk  => saciClk,           -- [out]
         saciSelL => saciSelL,          -- [out]
         saciCmd  => saciCmd,           -- [out]
         saciRsp  => saciRsp);          -- [in]

   comb : process (ack, axilReadMaster, axilRst, axilWriteMaster, fail, r, rdData) is
      variable v          : RegType;
      variable axilStatus : AxiLiteStatusType;
      variable resp       : slv(1 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Reset the strobing signals
      resp := AXI_RESP_OK_C;

      -- Check the timer
      if r.timer /= TIMEOUT_C then
         -- Increment the counter
         v.timer := r.timer + 1;
      end if;

      -- Determine the transaction type
      axiSlaveWaitTxn(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus);

      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Reset the timer
            v.saciRst := '0';
            v.timer   := 0;
            -- Check for a write request
            if (axilStatus.writeEnable = '1') then
               -- SACI Commands
               v.req  := '1';
               v.op   := '1';
               v.chip := axilWriteMaster.awaddr(22+CHIP_BITS_C-1 downto 22);
               if (SACI_NUM_CHIPS_G = 1) then
                  v.chip := "0";
               end if;
               v.cmd    := axilWriteMaster.awaddr(20 downto 14);
               v.addr   := axilWriteMaster.awaddr(13 downto 2);
               v.wrData := axilWriteMaster.wdata;
               -- Next state
               v.state  := SACI_REQ_S;
            -- Check for a read request            
            elsif (axilStatus.readEnable = '1') then
               -- SACI Commands
               v.req  := '1';
               v.op   := '0';
               v.chip := axilReadMaster.araddr(22+CHIP_BITS_C-1 downto 22);
               if (SACI_NUM_CHIPS_G = 1) then
                  v.chip := "0";
               end if;
               v.cmd    := axilReadMaster.araddr(20 downto 14);
               v.addr   := axilReadMaster.araddr(13 downto 2);
               v.wrData := (others => '0');
               -- Next state
               v.state  := SACI_REQ_S;
            end if;
         ----------------------------------------------------------------------
         when SACI_REQ_S =>
            if (ack = '1' and fail = '1') or (r.timer = TIMEOUT_C) then
               -- Set the error flags
               resp      := AXIL_ERROR_RESP_G;
               v.req     := '0';
               v.saciRst := '1';
            elsif (ack = '1') then
               -- Reset the flag
               v.req := '0';
            end if;


            if (v.req = '0') then
               -- Check for Write operation
               if (r.op = '1') then
                  --- Send AXI-Lite response
                  axiSlaveWriteResponse(v.axilWriteSlave, resp);
               else
                  -- Return the read data bus
                  v.axilReadSlave.rdata := rdData;
                  -- Send AXI-Lite Response
                  axiSlaveReadResponse(v.axilReadSlave, resp);
               end if;
               -- Next state
               v.state := SACI_ACK_S;
            end if;
         ----------------------------------------------------------------------
         when SACI_ACK_S =>
            -- Check status of ACK flag
            if (ack = '0') then
               -- Next state
               v.state := IDLE_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Synchronous Reset
      if axilRst = '1' then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      axilReadSlave  <= r.axilReadSlave;
      axilWriteSlave <= r.axilWriteSlave;

   end process comb;

   seq : process (axilClk) is
   begin
      if rising_edge(axilClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
