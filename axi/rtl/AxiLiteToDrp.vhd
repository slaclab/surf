-------------------------------------------------------------------------------
-- File       : AxiLiteToDrp.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-02-10
-- Last update: 2016-02-17
-------------------------------------------------------------------------------
-- Description: AXI-Lite to Xilinx DRP Bridge 
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

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

entity AxiLiteToDrp is
   generic (
      TPD_G            : time                   := 1 ns;
      AXI_ERROR_RESP_G : slv(1 downto 0)        := AXI_RESP_DECERR_C;
      COMMON_CLK_G     : boolean                := false;
      EN_ARBITRATION_G : boolean                := false;
      TIMEOUT_G        : positive               := 4096;
      ADDR_WIDTH_G     : positive range 1 to 32 := 16;
      DATA_WIDTH_G     : positive range 1 to 32 := 16);
   port (
      -- AXI-Lite Port
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      -- DRP Interface
      drpClk          : in  sl;
      drpRst          : in  sl;
      drpGnt          : in  sl := '1';  -- Used if EN_ARBITRATION_G = true
      drpReq          : out sl;         -- Used if EN_ARBITRATION_G = true
      drpRdy          : in  sl;
      drpEn           : out sl;
      drpWe           : out sl;
      drpUsrRst       : out sl;
      drpAddr         : out slv(ADDR_WIDTH_G-1 downto 0);
      drpDi           : out slv(DATA_WIDTH_G-1 downto 0);
      drpDo           : in  slv(DATA_WIDTH_G-1 downto 0));      
end entity AxiLiteToDrp;

architecture rtl of AxiLiteToDrp is

   type StateType is (
      IDLE_S,
      REQ_S,
      ACK_S); 

   type RegType is record
      drpUsrRst  : sl;
      drpReq     : sl;
      drpEn      : sl;
      drpWe      : sl;
      drpAddr    : slv(ADDR_WIDTH_G-1 downto 0);
      drpDi      : slv(DATA_WIDTH_G-1 downto 0);
      timer      : natural range 0 to TIMEOUT_G;
      writeSlave : AxiLiteWriteSlaveType;
      readSlave  : AxiLiteReadSlaveType;
      state      : StateType;
   end record;

   constant REG_INIT_C : RegType := (
      drpUsrRst  => '1',
      drpReq     => '0',
      drpEn      => '0',
      drpWe      => '0',
      drpAddr    => (others => '0'),
      drpDi      => (others => '0'),
      timer      => 0,
      writeSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      readSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      state      => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal readMaster  : AxiLiteReadMasterType;
   signal readSlave   : AxiLiteReadSlaveType;
   signal writeMaster : AxiLiteWriteMasterType;
   signal writeSlave  : AxiLiteWriteSlaveType;

   -- attribute dont_touch      : string;
   -- attribute dont_touch of r : signal is "true";

begin

   GEN_ASYNC : if (COMMON_CLK_G = false) generate

      U_AxiLiteAsync : entity work.AxiLiteAsync
         generic map (
            TPD_G => TPD_G)
         port map (
            -- Slave Port
            sAxiClk         => axilClk,
            sAxiClkRst      => axilRst,
            sAxiReadMaster  => axilReadMaster,
            sAxiReadSlave   => axilReadSlave,
            sAxiWriteMaster => axilWriteMaster,
            sAxiWriteSlave  => axilWriteSlave,
            -- Master Port
            mAxiClk         => drpClk,
            mAxiClkRst      => drpRst,
            mAxiReadMaster  => readMaster,
            mAxiReadSlave   => readSlave,
            mAxiWriteMaster => writeMaster,
            mAxiWriteSlave  => writeSlave);  

   end generate;

   GEN_SYNC : if (COMMON_CLK_G = true) generate

      readMaster     <= axilReadMaster;
      axilReadSlave  <= readSlave;
      writeMaster    <= axilWriteMaster;
      axilWriteSlave <= writeSlave;
      
   end generate;

   comb : process (drpDo, drpGnt, drpRdy, drpRst, r, readMaster, writeMaster) is
      variable v         : RegType;
      variable axiStatus : AxiLiteStatusType;
      variable axiResp   : slv(1 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Reset the strobes
      v.drpEn     := '0';
      v.drpWe     := '0';
      v.drpUsrRst := '0';

      -- Determine the transaction type
      axiSlaveWaitTxn(writeMaster, readMaster, v.writeSlave, v.readSlave, axiStatus);

      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Reset the flags
            v.drpReq := '0';
            v.timer  := 0;
            -- Check for a write request
            if (axiStatus.writeEnable = '1') then
               -- Set the write address bus (32-bit access alignment)
               v.drpAddr := writeMaster.awaddr(ADDR_WIDTH_G+1 downto 2);
               -- Set the write data bus
               v.drpDi   := writeMaster.wdata(DATA_WIDTH_G-1 downto 0);
               -- Check for DRP request/grant
               if EN_ARBITRATION_G then
                  -- Next state
                  v.state := REQ_S;
               else
                  -- Send a write command
                  v.drpEn := '1';
                  v.drpWe := '1';
                  -- Next state
                  v.state := ACK_S;
               end if;
            -- Check for a read request            
            elsif (axiStatus.readEnable = '1') then
               -- Set the write address bus (32-bit access alignment)
               v.drpAddr := readMaster.araddr(ADDR_WIDTH_G+1 downto 2);
               -- Check for DRP request/grant
               if EN_ARBITRATION_G then
                  -- Next state
                  v.state := REQ_S;
               else
                  -- Send a read command
                  v.drpEn := '1';
                  v.drpWe := '0';
                  -- Next state
                  v.state := ACK_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when REQ_S =>
            -- Request the DRP bus
            v.drpReq := '1';
            -- Check for DRP bus access granted
            if (drpGnt = '1') or (r.timer = TIMEOUT_G) then
               -- Check for a write request
               if (axiStatus.writeEnable = '1') then
                  -- Check for non-timeout
                  if (drpGnt = '1') then
                     -- Reset the timer
                     v.timer := 0;
                     -- Send a write command
                     v.drpEn := '1';
                     v.drpWe := '1';
                  end if;
                  -- Next state
                  v.state := ACK_S;
               -- Check for a read request            
               elsif (axiStatus.readEnable = '1') then
                  -- Check for non-timeout
                  if (drpGnt = '1') then
                     -- Reset the timer
                     v.timer := 0;
                     -- Send a read command
                     v.drpEn := '1';
                     v.drpWe := '0';
                  end if;
                  -- Next state
                  v.state := ACK_S;
               else
                  -- Next state
                  v.state := IDLE_S;
               end if;
            else
               -- Increment the timer
               v.timer := r.timer + 1;
            end if;
         ----------------------------------------------------------------------
         when ACK_S =>
            -- Check for DRP acknowledgement of command
            if (drpRdy = '1') or (r.timer = TIMEOUT_G) then
               -- Check for non-timeout
               if (drpRdy = '1') then
                  -- Return good transaction
                  axiResp := AXI_RESP_OK_C;
               else
                  -- Return good transaction
                  axiResp     := AXI_ERROR_RESP_G;
                  -- Attempt to re-initialize the DRP interface
                  v.drpUsrRst := '1';
               end if;
               -- Check for a write request
               if (axiStatus.writeEnable = '1') then
                  -- Send AXI-Lite response
                  axiSlaveWriteResponse(v.writeSlave, axiResp);
               -- Check for a read request            
               elsif (axiStatus.readEnable = '1') then
                  -- Set the read bus
                  v.readSlave.rdata(DATA_WIDTH_G-1 downto 0) := drpDo;
                  -- Send AXI-Lite Response
                  axiSlaveReadResponse(v.readSlave, axiResp);
               end if;
               -- Next state
               v.state := IDLE_S;
            else
               -- Increment the timer
               v.timer := r.timer + 1;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Synchronous Reset
      if (drpRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      readSlave  <= r.readSlave;
      writeSlave <= r.writeSlave;
      drpReq     <= r.drpReq;
      drpEn      <= r.drpEn;
      drpWe      <= r.drpWe;
      drpAddr    <= r.drpAddr;
      drpDi      <= r.drpDi;
      drpUsrRst  <= r.drpUsrRst;
      
   end process comb;

   seq : process (drpClk) is
   begin
      if (rising_edge(drpClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
