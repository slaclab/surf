-------------------------------------------------------------------------------
-- File       : SaciPrepRdout.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 07/21/2016
-- Last update: 07/21/2016
-------------------------------------------------------------------------------
-- Description: The AXI lite master to issue SACI prepare for readout command
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

entity SaciPrepRdout is
   generic (
      TPD_G              : time             := 1 ns;
      MASK_REG_ADDR_G    : slv(31 downto 0) := x"00000034";
      SACI_BASE_ADDR_G   : slv(31 downto 0) := x"02000000";
      AXIL_ERR_RESP_G    : slv(1 downto 0)  := AXI_RESP_DECERR_C;
      SACI_NUM_CHIPS_G   : natural range 1 to 4 := 4
   );
   port (
      axilClk           : in  sl;
      axilRst           : in  sl;
      
      -- Prepare for readout req/ack
      prepRdoutReq      : in  sl;
      prepRdoutAck      : out sl;
      
      -- Optional AXI lite slave port for status readout
      sAxilWriteMaster  : in  AxiLiteWriteMasterType;
      sAxilWriteSlave   : out AxiLiteWriteSlaveType;
      sAxilReadMaster   : in  AxiLiteReadMasterType;
      sAxilReadSlave    : out AxiLiteReadSlaveType;
      
      -- AXI lite master port for command issue
      mAxilWriteMaster  : out AxiLiteWriteMasterType;
      mAxilWriteSlave   : in  AxiLiteWriteSlaveType;
      mAxilReadMaster   : out AxiLiteReadMasterType;
      mAxilReadSlave    : in  AxiLiteReadSlaveType
   );

end SaciPrepRdout;

architecture rtl of SaciPrepRdout is

   type StateType is (S_IDLE_C, S_IS_ASIC_C, S_WRITE_C, S_WRITE_AXI_C, S_READ_C, S_READ_AXI_C);
   
   type RegType is record
      asicMask         : slv(SACI_NUM_CHIPS_G-1 downto 0);
      state            : StateType;
      timer            : slv(23 downto 0);
      asicCnt          : natural;
      rdTimeout        : slv(31 downto 0);
      rdFail           : slv(31 downto 0);
      wrTimeout        : slv(31 downto 0);
      wrFail           : slv(31 downto 0);
      prepRdoutAck     : sl;
      mAxilWriteMaster : AxiLiteWriteMasterType;
      mAxilReadMaster  : AxiLiteReadMasterType;
      sAxilWriteSlave  : AxiLiteWriteSlaveType;
      sAxilReadSlave   : AxiLiteReadSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      asicMask          => (others=>'0'),
      state             => S_IDLE_C,
      timer             => (others => '1'),
      asicCnt           =>  0,
      rdTimeout         => (others=>'0'),
      rdFail            => (others=>'0'),
      wrTimeout         => (others=>'0'),
      wrFail            => (others=>'0'),
      prepRdoutAck      => '0',
      mAxilWriteMaster  => AXI_LITE_WRITE_MASTER_INIT_C,
      mAxilReadMaster   => AXI_LITE_READ_MASTER_INIT_C,
      sAxilWriteSlave   => AXI_LITE_WRITE_SLAVE_INIT_C,
      sAxilReadSlave    => AXI_LITE_READ_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
   function asicBaseAddr(asic : natural) return slv is
   begin
      return toSlv(asic*(2**22), 32);
   end function;

begin

   comb : process (axilRst, sAxilReadMaster, sAxilWriteMaster, mAxilReadSlave, mAxilWriteSlave, r, prepRdoutReq) is
      variable v        : RegType;
      variable regCon   : AxiLiteEndPointType;
   begin
      v := r;
      
      v.sAxilReadSlave.rdata := (others => '0');
      axiSlaveWaitTxn(regCon, sAxilWriteMaster, sAxilReadMaster, v.sAxilWriteSlave, v.sAxilReadSlave);
      
      -- error counters
      axiSlaveRegisterR(regCon, x"00", 0, r.rdFail);
      axiSlaveRegisterR(regCon, x"04", 0, r.rdTimeout);
      axiSlaveRegisterR(regCon, x"08", 0, r.wrFail);
      axiSlaveRegisterR(regCon, x"0C", 0, r.wrTimeout);
      axiSlaveRegisterR(regCon, x"10", 0, r.asicMask);
      
      axiSlaveDefault(regCon, v.sAxilWriteSlave, v.sAxilReadSlave, AXIL_ERR_RESP_G);
      
      -- State machine for SACI mediation
      -- SACI command is issued via the AXI lite master bus
      case(r.state) is
         when S_IDLE_C =>
            v.mAxilWriteMaster   := AXI_LITE_WRITE_MASTER_INIT_C;
            v.mAxilReadMaster    := AXI_LITE_READ_MASTER_INIT_C;
            v.asicCnt            :=  0;
            v.prepRdoutAck       := '0';

            -- If we see a multi-pixel write request, handle it
            if (prepRdoutReq = '1') then
                  v.state     := S_READ_C;
            end if;
            
         -- Read the ASIC mask
         when S_READ_C =>
            v.mAxilReadMaster.araddr := MASK_REG_ADDR_G;
            v.mAxilReadMaster.arprot := (others => '0');
            v.timer                  := (others => '1');

            -- Start AXI transaction
            v.mAxilReadMaster.arvalid := '1';
            v.mAxilReadMaster.rready  := '1';
            v.state                   := S_READ_AXI_C;

         -- Read AXI
         when S_READ_AXI_C =>
            v.timer := r.timer - 1;

            -- Clear control signals on ack
            if mAxilReadSlave.arready = '1' then
               v.mAxilReadMaster.arvalid := '0';
            end if;
            if mAxilReadSlave.rvalid = '1' then
               v.mAxilReadMaster.rready := '0';
               v.asicMask := mAxilReadSlave.rdata(SACI_NUM_CHIPS_G-1 downto 0);

               if mAxilReadSlave.rresp /= AXI_RESP_OK_C then
                  v.rdFail := r.rdFail + 1;
               end if;
            end if;

            -- End transaction on timeout
            if r.timer = 0 then
               v.mAxilReadMaster.arvalid := '0';
               v.mAxilReadMaster.rready  := '0';
               v.rdTimeout               := r.rdTimeout + 1;
            end if;

            -- Transaction is done
            if v.mAxilReadMaster.arvalid = '0' and v.mAxilReadMaster.rready = '0' then
               if mAxilReadSlave.rresp /= AXI_RESP_OK_C or r.timer = 0 then
                  v.state := S_IDLE_C;
               else
                  v.state := S_IS_ASIC_C;
               end if;
            end if;
            
         -- Check if ASIC is enabled
         when S_IS_ASIC_C =>
            if r.asicCnt >= SACI_NUM_CHIPS_G then
               v.prepRdoutAck := '1';
               v.state        := S_IDLE_C;
            elsif (r.asicMask(r.asicCnt) = '1') then
               v.state        := S_WRITE_C;
            else
               v.asicCnt      := r.asicCnt + 1;
            end if;
            
         -- Prepare Write Transactions
         when S_WRITE_C =>
            -- Prepare for readout: CMD = 0, ADDR = 0, DATA = 0
            v.mAxilWriteMaster.awaddr := SACI_BASE_ADDR_G + asicBaseAddr(r.asicCnt);
            v.mAxilWriteMaster.wdata  := x"00000000";
            v.mAxilWriteMaster.awprot  := (others => '0');
            v.mAxilWriteMaster.wstrb   := (others => '1');
            v.timer                    := (others => '1');
            
            v.mAxilWriteMaster.awvalid := '1';
            v.mAxilWriteMaster.wvalid  := '1';
            v.mAxilWriteMaster.bready  := '1';
            v.state                    := S_WRITE_AXI_C;

         -- Write Transaction, AXI
         when S_WRITE_AXI_C =>
            v.timer := r.timer - 1;

            -- Clear control signals on ack
            if mAxilWriteSlave.awready = '1' then
               v.mAxilWriteMaster.awvalid := '0';
            end if;
            if mAxilWriteSlave.wready = '1' then
               v.mAxilWriteMaster.wvalid := '0';
            end if;
            if mAxilWriteSlave.bvalid = '1' then
               v.mAxilWriteMaster.bready := '0';

               if mAxilWriteSlave.bresp /= AXI_RESP_OK_C then
                  v.wrFail := r.wrFail + 1;
               end if;
            end if;

            -- End transaction on timeout
            if r.timer = 0 then
               v.mAxilWriteMaster.awvalid := '0';
               v.mAxilWriteMaster.wvalid  := '0';
               v.mAxilWriteMaster.bready  := '0';
               v.wrTimeout                := r.wrTimeout + 1;
            end if;

            -- Transaction is done
            if v.mAxilWriteMaster.awvalid = '0' and
               v.mAxilWriteMaster.wvalid = '0' and
               v.mAxilWriteMaster.bready = '0' then
               
               if mAxilWriteSlave.bresp /= AXI_RESP_OK_C or r.timer = 0 then
                  v.state    := S_IDLE_C;
               else
                  v.asicCnt  := r.asicCnt + 1;
                  v.state    := S_IS_ASIC_C;
               end if;
               
            end if;
            
      end case;
      
      if (axilRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      sAxilWriteSlave   <= r.sAxilWriteSlave;
      sAxilReadSlave    <= r.sAxilReadSlave;
      mAxilWriteMaster  <= r.mAxilWriteMaster;
      mAxilReadMaster   <= r.mAxilReadMaster;
      
      prepRdoutAck      <= r.prepRdoutAck;

   end process comb;

   seq : process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;

