-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AxiLiteSaciMaster2.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-06-01
-- Last update: 2016-06-02
-- Platform   :
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2016 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.SaciMasterPkg.all;

entity AxiLiteSaciMaster2 is
   generic (
      TPD_G             : time                  := 1 ns;
      NUM_CHIPS_G       : positive range 1 to 4 := 1;
      AXIL_CLK_PERIOD_G : real                  := 8.0e-9;  -- units of Hz
      SACI_CLK_PERIOD_G : real                  := 1.0e-6;  -- units of Hz
      TIMEOUT_G         : real                  := 1.0E-3;  -- In units of seconds
      AXI_ERROR_RESP_G  : slv(1 downto 0)       := AXI_RESP_DECERR_C);
   port (
      -- SACI interface
      saciClk         : out sl;
      saciCmd         : out sl;
      saciSelL        : out slv(NUM_SLAVES_G-1 downto 0);
      saciRsp         : in  slv(NUM_SLAVES_G-1 downto 0);
      -- AXI-Lite Register Interface
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end AxiLiteSaciMaster2;

architecture rtl of AxiLiteSaciMaster2 is

   constant CHIP_BITS_C : log2(NUM_CHIPS_G);

   type StateType is (
      IDLE_S,
      SACI_REQ_S,
      SACI_ACK_S);

   type RegType is record
      state          : StateType;
      req            : sl;
      chip           : slv(log2(NUM_CHIPS_G)-1 downto 0);
      op             : sl;
      cmd            : slv(6 downto 0);
      addr           : slv(11 downto 0);
      wrData         : slv(31 downto 0);
      timer          : natural range 0 to TIMEOUT_C;
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;

   end record RegType;

   constant REG_INIT_C : RegType := (
      state          => IDLE_S,
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


begin

   U_SaciMaster2_1 : entity work.SaciMaster2
      generic map (
         TPD_G              => TPD_G,
         SYS_CLK_PERIOD_G   => SYS_CLK_PERIOD_G,
         SACI_CLK_PERIOD_G  => SACI_CLK_PERIOD_G,
         SACI_CLK_FREERUN_G => SACI_CLK_FREERUN_G,
         NUM_CHIPS_G        => NUM_CHIPS_G)
      port map (
         sysClk   => sysClk,            -- [in]
         sysRst   => sysRst,            -- [in]
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

   comb : process (axilReadMaster, axilRst, axilWriteMaster, r, rsp, saciMasterOut, selL) is
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
            v.timer := 0;
            -- Check for a write request
            if (axilStatus.writeEnable = '1') then
               -- SACI Commands
               v.req  := '1';
               v.op   := '1';
               v.chip := axilWriteMaster.awaddr(22+CHIP_BITS_C-1 downto 22);
               if (NUM_CHIPS_G = 1) then
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
               if (NUM_CHIPS_G = 1) then
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
               resp  := AXIL_ERROR_RESP_G;
               v.req := '0';
               if (ack = '1') then
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
