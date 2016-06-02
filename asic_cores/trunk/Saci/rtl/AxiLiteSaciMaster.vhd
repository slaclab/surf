-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AxiLiteSaciMaster.vhd
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

entity AxiLiteSaciMaster is
   generic (
      TPD_G            : time                  := 1 ns;
      NUM_SLAVES_G     : positive range 1 to 4 := 1;
      AXI_CLK_FREQ_G   : real                  := 200.0E+6;  -- units of Hz
      SACI_CLK_FREQ_G  : real                  := 50.0E+6;   -- units of Hz
      TIMEOUT_G        : real                  := 1.0E-3;    -- In units of seconds
      AXI_ERROR_RESP_G : slv(1 downto 0)       := AXI_RESP_DECERR_C);       
   port (
      -- SACI interface
      saciClk         : out sl;
      saciCmd         : out sl;
      saciRstL        : out sl;
      saciSelL        : out slv(NUM_SLAVES_G-1 downto 0);
      saciRsp         : in  slv(NUM_SLAVES_G-1 downto 0);
      -- AXI-Lite Register Interface
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end AxiLiteSaciMaster;

architecture rtl of AxiLiteSaciMaster is

   constant DOUBLE_SCK_FREQ_C : real    := getRealMult(SACI_CLK_FREQ_G, 2.0);
   constant SCK_HALF_PERIOD_C : natural := (getTimeRatio(AXI_CLK_FREQ_G, DOUBLE_SCK_FREQ_C))-1;
   constant TIMEOUT_C         : natural := (getTimeRatio(AXI_CLK_FREQ_G, (1.0/TIMEOUT_G)))-1;
   
   type StateType is (
      IDLE_S,
      SACI_REQ_S,
      SACI_ACK_S); 

   type RegType is record
      saciRst        : sl;
      saciRsp        : sl;
      saciMasterIn   : SaciMasterInType;
      timer          : natural range 0 to TIMEOUT_C;
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
      state          : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      saciRst        => '1',
      saciRsp        => '0',
      saciMasterIn   => SACI_MASTER_IN_INIT_C,
      timer          => 0,
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      state          => IDLE_S);      

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal selL          : slv(3 downto 0) := x"0";
   signal rsp           : slv(3 downto 0) := x"0";
   signal saciMasterOut : SaciMasterOutType;

   -- attribute dont_touch      : string;
   -- attribute dont_touch of r : signal is "true";

begin

   saciSelL                     <= selL(NUM_SLAVES_G-1 downto 0);
   saciRstL                     <= not(r.saciRst);
   rsp(NUM_SLAVES_G-1 downto 0) <= saciRsp;

   U_SaciMaster : entity work.SaciMasterSync
      generic map (
         TPD_G                 => TPD_G,
         SACI_HALF_CLK_TICKS   => SCK_HALF_PERIOD_C,
         SYNCHRONIZE_CONTROL_G => true)
      port map (
         clk           => axilClk,
         rst           => r.saciRst,
         saciClk       => saciClk,
         saciSelL      => selL,
         saciCmd       => saciCmd,
         saciRsp       => r.saciRsp,
         saciMasterIn  => r.saciMasterIn,
         saciMasterOut => saciMasterOut);

   comb : process (axilReadMaster, axilRst, axilWriteMaster, r, rsp, saciMasterOut, selL) is
      variable v             : RegType;
      variable axilStatus    : AxiLiteStatusType;
      variable axilWriteResp : slv(1 downto 0);
      variable axilReadResp  : slv(1 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Reset the strobing signals
      v.saciRst     := '0';
      axilWriteResp := AXI_RESP_OK_C;
      axilReadResp  := AXI_RESP_OK_C;

      -- Mux the bus responds w.r.t. select bus
      if (selL(0) = '0') then
         v.saciRsp := rsp(0);
      elsif selL(1) = '0' then
         v.saciRsp := rsp(1);
      elsif selL(2) = '0' then
         v.saciRsp := rsp(2);
      elsif selL(3) = '0' then
         v.saciRsp := rsp(3);
      else
         v.saciRsp := '0';
      end if;

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
               v.saciMasterIn.req    := '1';
               v.saciMasterIn.op     := '1';
               v.saciMasterIn.chip   := axilWriteMaster.awaddr(23 downto 22);
               v.saciMasterIn.cmd    := axilWriteMaster.awaddr(20 downto 14);
               v.saciMasterIn.addr   := axilWriteMaster.awaddr(13 downto 2);
               v.saciMasterIn.wrData := axilWriteMaster.wdata;
               -- Next state
               v.state               := SACI_REQ_S;
            -- Check for a read request            
            elsif (axilStatus.readEnable = '1') then
               -- SACI Commands
               v.saciMasterIn.req    := '1';
               v.saciMasterIn.op     := '0';
               v.saciMasterIn.chip   := axilReadMaster.araddr(23 downto 22);
               v.saciMasterIn.cmd    := axilReadMaster.araddr(20 downto 14);
               v.saciMasterIn.addr   := axilReadMaster.araddr(13 downto 2);
               v.saciMasterIn.wrData := (others => '0');
               -- Next state
               v.state               := SACI_REQ_S;
            end if;
         ----------------------------------------------------------------------
         when SACI_REQ_S =>
            if (saciMasterOut.fail = '1') or (r.timer = TIMEOUT_C) then
               -- Reset the interface
               v.saciRst          := '1';
               -- Reset the flag
               v.saciMasterIn.req := '0';
               -- Set the error flags
               axilWriteResp      := AXI_RESP_SLVERR_C;
               axilReadResp       := AXI_RESP_SLVERR_C;
            elsif (saciMasterOut.ack = '1') then
               -- Reset the flag
               v.saciMasterIn.req := '0';
            end if;
            -- Check status of REQ flag
            if (v.saciMasterIn.req = '0') then
               -- Check for Write operation
               if (r.saciMasterIn.op = '1') then
                  --- Send AXI-Lite response
                  axiSlaveWriteResponse(v.axilWriteSlave, axilWriteResp);
               else
                  -- Return the read data bus
                  v.axilReadSlave.rdata := saciMasterOut.rdData;
                  -- Send AXI-Lite Response
                  axiSlaveReadResponse(v.axilReadSlave, axilReadResp);
               end if;
               -- Next state
               v.state := SACI_ACK_S;
            end if;
         ----------------------------------------------------------------------
         when SACI_ACK_S =>
            -- Check status of ACK flag
            if (saciMasterOut.ack = '0') then
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
