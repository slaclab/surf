-------------------------------------------------------------------------------
-- File       : PgpParallelSimModel.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 07/21/2016
-- Last update: 07/21/2016
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
use work.SaciMultiPixelPkg.all;

entity SaciMultiPixel is
   generic (
      TPD_G              : time             := 1 ns;
      MASK_REG_ADDR_G    : slv(31 downto 0) := x"00000034";
      SACI_BASE_ADDR_G   : slv(31 downto 0) := x"02000000";
      AXIL_ERR_RESP_G    : slv(1 downto 0)  := AXI_RESP_DECERR_C;
      SACI_NUM_CHIPS_G   : natural range 1 to 4 := 4
   );
   port (
      axilClk           : in sl;
      axilRst           : in sl;
      
      -- AXI lite slave port
      sAxilWriteMaster  : in  AxiLiteWriteMasterType;
      sAxilWriteSlave   : out AxiLiteWriteSlaveType;
      sAxilReadMaster   : in  AxiLiteReadMasterType;
      sAxilReadSlave    : out AxiLiteReadSlaveType;
      
      -- AXI lite master port
      mAxilWriteMaster  : out AxiLiteWriteMasterType;
      mAxilWriteSlave   : in  AxiLiteWriteSlaveType;
      mAxilReadMaster   : out AxiLiteReadMasterType;
      mAxilReadSlave    : in  AxiLiteReadSlaveType
   );

end SaciMultiPixel;

architecture rtl of SaciMultiPixel is

   type StateType is (S_IDLE_C, S_IS_ASIC_C, S_WRITE_C, S_WRITE_AXI_C,
      S_READ_C, S_READ_AXI_C, S_DONE_OK_C, S_DONE_FAIL_C);

   type RegType is record
      globalMultiPix : MultiPixelWriteType;
      localMultiPix  : MultiPixelWriteType;
      asicMask    : slv(3 downto 0);
      writeCnt    : slv(3 downto 0);
      state       : StateType;
      timer       : slv(23 downto 0);
      timeout     : sl;
      fail        : sl;
      mAxilWriteMaster : AxiLiteWriteMasterType;
      mAxilReadMaster  : AxiLiteReadMasterType;
      sAxilWriteSlave  : AxiLiteWriteSlaveType;
      sAxilReadSlave   : AxiLiteReadSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      globalMultiPix       => MULTI_PIXEL_WRITE_INIT_C,
      localMultiPix        => MULTI_PIXEL_WRITE_INIT_C,
      asicMask             => (others=>'0'),
      writeCnt             => (others=>'0'),
      state                => S_IDLE_C,
      timer                => (others => '1'),
      timeout              => '0',
      fail                 => '0',
      mAxilWriteMaster  => AXI_LITE_WRITE_MASTER_INIT_C,
      mAxilReadMaster   => AXI_LITE_READ_MASTER_INIT_C,
      sAxilWriteSlave   => AXI_LITE_WRITE_SLAVE_INIT_C,
      sAxilReadSlave    => AXI_LITE_READ_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   assert (SACI_NUM_CHIPS_G = 4) report "Multi-pixel write supports only 4 ASIC configuration!" severity failure;

   comb : process (axilRst, sAxilReadMaster, sAxilWriteMaster, mAxilReadSlave, mAxilWriteSlave, r) is
      variable v           : RegType;
      variable axiStatus   : AxiLiteStatusType;
   begin
      v := r;
      
      v.sAxilReadSlave.rdata := (others => '0');
      axiSlaveWaitTxn(sAxilWriteMaster, sAxilReadMaster, v.sAxilWriteSlave, v.sAxilReadSlave, axiStatus);
      
      if (axiStatus.writeEnable = '1' and r.globalMultiPix.req = '0') then
         -- Pseudo SACI Commands (multi-pixel write)
         if (sAxilWriteMaster.awaddr(7 downto 0) = x"00") then
            v.globalMultiPix.row          := sAxilWriteMaster.wdata(9 downto 0);
            v.globalMultiPix.calRowFlag   := sAxilWriteMaster.wdata(16);
            v.globalMultiPix.calBotFlag   := sAxilWriteMaster.wdata(17);
            axiSlaveWriteResponse(v.sAxilWriteSlave, AXI_RESP_OK_C);
         elsif (sAxilWriteMaster.awaddr(7 downto 0) = x"04") then
            v.globalMultiPix.col          := sAxilWriteMaster.wdata(9 downto 0);
            axiSlaveWriteResponse(v.sAxilWriteSlave, AXI_RESP_OK_C);
         elsif (sAxilWriteMaster.awaddr(7 downto 0) = x"08") then
            v.globalMultiPix.data(0)      := sAxilWriteMaster.wdata(15 downto 0);
            axiSlaveWriteResponse(v.sAxilWriteSlave, AXI_RESP_OK_C);
         elsif (sAxilWriteMaster.awaddr(7 downto 0) = x"0C") then
            v.globalMultiPix.data(1)      := sAxilWriteMaster.wdata(15 downto 0);
            axiSlaveWriteResponse(v.sAxilWriteSlave, AXI_RESP_OK_C);
         elsif (sAxilWriteMaster.awaddr(7 downto 0) = x"10") then
            v.globalMultiPix.data(2)      := sAxilWriteMaster.wdata(15 downto 0);
            axiSlaveWriteResponse(v.sAxilWriteSlave, AXI_RESP_OK_C);
         elsif (sAxilWriteMaster.awaddr(7 downto 0) = x"14") then
            v.globalMultiPix.data(3)      := sAxilWriteMaster.wdata(15 downto 0);
            v.globalMultiPix.req          := '1'; -- start the AxiL master
         else
            axiSlaveWriteResponse(v.sAxilWriteSlave, AXIL_ERR_RESP_G);
         end if;
      end if;
      
      if (axiStatus.readEnable = '1' and r.globalMultiPix.req = '0') then
         if (sAxilReadMaster.araddr(7 downto 0) = x"00") then
            v.sAxilReadSlave.rdata(9 downto 0)  := r.globalMultiPix.row;
            v.sAxilReadSlave.rdata(16)          := r.globalMultiPix.calRowFlag;
            v.sAxilReadSlave.rdata(17)          := r.globalMultiPix.calBotFlag;
            axiSlaveReadResponse(v.sAxilReadSlave, AXI_RESP_OK_C);
         elsif (sAxilReadMaster.araddr(7 downto 0) = x"04") then
            v.sAxilReadSlave.rdata(9 downto 0)  := r.globalMultiPix.col;
            axiSlaveReadResponse(v.sAxilReadSlave, AXI_RESP_OK_C);
         elsif (sAxilReadMaster.araddr(7 downto 0) = x"08") then
            v.sAxilReadSlave.rdata(15 downto 0) := r.globalMultiPix.data(0);
            axiSlaveReadResponse(v.sAxilReadSlave, AXI_RESP_OK_C);
         elsif (sAxilReadMaster.araddr(7 downto 0) = x"0C") then
            v.sAxilReadSlave.rdata(15 downto 0) := r.globalMultiPix.data(1);
            axiSlaveReadResponse(v.sAxilReadSlave, AXI_RESP_OK_C);
         elsif (sAxilReadMaster.araddr(7 downto 0) = x"10") then
            v.sAxilReadSlave.rdata(15 downto 0) := r.globalMultiPix.data(2);
            axiSlaveReadResponse(v.sAxilReadSlave, AXI_RESP_OK_C);
         elsif (sAxilReadMaster.araddr(7 downto 0) = x"14") then
            v.sAxilReadSlave.rdata(15 downto 0) := r.globalMultiPix.data(3);
            axiSlaveReadResponse(v.sAxilReadSlave, AXI_RESP_OK_C);
         elsif (sAxilReadMaster.araddr(7 downto 0) = x"18") then
            v.sAxilReadSlave.rdata(0)           := r.fail;
            v.sAxilReadSlave.rdata(1)           := r.timeout;
            axiSlaveReadResponse(v.sAxilReadSlave, AXI_RESP_OK_C);
         else
            axiSlaveReadResponse(v.sAxilReadSlave, AXIL_ERR_RESP_G);
         end if;
      end if;
      
      
      -- State machine for SACI mediation
      -- SACI is accessed via the AXI lite master bus
      case(r.state) is
         when S_IDLE_C =>
            v.mAxilWriteMaster   := AXI_LITE_WRITE_MASTER_INIT_C;
            v.mAxilReadMaster    := AXI_LITE_READ_MASTER_INIT_C;
            v.asicMask           := (others => '0');
            v.writeCnt           := (others => '0');

            -- If we see a multi-pixel write request, handle it
            if (r.globalMultiPix.req = '1') then
                  globalToLocalPixel(
                     r.globalMultiPix.row,
                     r.globalMultiPix.col,
                     r.globalMultiPix.calRowFlag,
                     r.globalMultiPix.calBotFlag,
                     r.globalMultiPix.data,
                     v.localMultiPix.asic,
                     v.localMultiPix.row,
                     v.localMultiPix.col,
                     v.localMultiPix.data);
                  v.timeout            := '0';
                  v.fail               := '0';
                  v.localMultiPix.bankFlag := "1110";
                  v.state := S_READ_C;
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
               v.asicMask := mAxilReadSlave.rdata(3 downto 0);

               if mAxilReadSlave.rresp /= AXI_RESP_OK_C then
                  v.fail := '1';
               end if;
            end if;

            -- End transaction on timeout
            if r.timer = 0 then
               v.mAxilReadMaster.arvalid := '0';
               v.mAxilReadMaster.rready  := '0';
               v.timeout                 := '1';
            end if;

            -- Transaction is done
            if v.mAxilReadMaster.arvalid = '0' and v.mAxilReadMaster.rready = '0' then
               if v.fail = '1' or v.timeout = '1' then
                  v.state := S_DONE_FAIL_C;
               else
                  v.state := S_IS_ASIC_C;
               end if;
            end if;
            
         -- Check if ASIC is enabled
         when S_IS_ASIC_C =>
            -- If the ASIC is not active, immediately drop the req and return
            if (r.asicMask(conv_integer(r.localMultiPix.asic)) = '0') then
               v.state := S_DONE_OK_C;
            else
               v.state := S_WRITE_C;
            end if;
         
         -- Prepare Write Transactions
         when S_WRITE_C =>
            if r.writeCnt = 0 then
               -- ASIC offset + CMD = 6, ADDR = 17
               v.mAxilWriteMaster.awaddr := SACI_BASE_ADDR_G + asicBaseAddr(conv_integer(r.localMultiPix.asic)) + x"00018044";
               -- DATA = ROW
               v.mAxilWriteMaster.wdata  := x"00000" & "000" & r.localMultiPix.row(8 downto 0);
            elsif r.writeCnt = 1 then
               -- ASIC offset + CMD = 6, ADDR = 19
               v.mAxilWriteMaster.awaddr := SACI_BASE_ADDR_G + asicBaseAddr(conv_integer(r.localMultiPix.asic)) + x"0001804C";
               -- DATA = Bank + Col
               v.mAxilWriteMaster.wdata  := x"00000" & "0" & r.localMultiPix.bankFlag & r.localMultiPix.col(6 downto 0);
            elsif r.writeCnt = 2 then
               -- ASIC offset + CMD = 5, ADDR = 0
               v.mAxilWriteMaster.awaddr := SACI_BASE_ADDR_G + asicBaseAddr(conv_integer(r.localMultiPix.asic)) + x"00014000";
               -- DATA = MT
               v.mAxilWriteMaster.wdata  := x"0000" & r.localMultiPix.data(0);
            end if;
            
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
                  v.fail := '1';
               end if;
            end if;

            -- End transaction on timeout
            if r.timer = 0 then
               v.mAxilWriteMaster.awvalid := '0';
               v.mAxilWriteMaster.wvalid  := '0';
               v.mAxilWriteMaster.bready  := '0';
               v.timeout                  := '1';
            end if;

            -- Transaction is done
            if v.mAxilWriteMaster.awvalid = '0' and
               v.mAxilWriteMaster.wvalid = '0' and
               v.mAxilWriteMaster.bready = '0' then
               
               if v.fail = '1' or v.timeout = '1' then
                  v.state    := S_DONE_FAIL_C;
               elsif r.writeCnt >= 2 then
                  -- Done if this was the last bank
                  if r.localMultiPix.bankFlag = "0111" then
                     v.state  := S_DONE_OK_C;
                  -- Otherwise, rotate the bank counter and pixel data
                  else
                     v.writeCnt                           := (others=>'0');
                     v.localMultiPix.bankFlag(3 downto 1) := r.localMultiPix.bankFlag(2 downto 0);
                     v.localMultiPix.bankFlag(0)          := r.localMultiPix.bankFlag(3);
                     v.localMultiPix.data(2 downto 0)     := r.localMultiPix.data(3 downto 1);
                     v.state                              := S_WRITE_C;
                  end if;
               else
                  v.writeCnt := r.writeCnt + 1;
                  v.state    := S_WRITE_C;
               end if;
               
            end if;
            
         when S_DONE_OK_C =>
            v.globalMultiPix.req := '0';
            axiSlaveWriteResponse(v.sAxilWriteSlave, AXI_RESP_OK_C);
            v.state  := S_IDLE_C;
         
         when S_DONE_FAIL_C =>
            v.globalMultiPix.req := '0';
            axiSlaveWriteResponse(v.sAxilWriteSlave, AXIL_ERR_RESP_G);
            v.state  := S_IDLE_C;
            
      end case;
      
      if (axilRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      sAxilWriteSlave   <= r.sAxilWriteSlave;
      sAxilReadSlave    <= r.sAxilReadSlave;
      mAxilWriteMaster  <= r.mAxilWriteMaster;
      mAxilReadMaster   <= r.mAxilReadMaster;


   end process comb;

   seq : process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;

