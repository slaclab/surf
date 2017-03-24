-------------------------------------------------------------------------------
-- File       : AxiLiteMaster.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-09
-- Last update: 2016-03-09
-------------------------------------------------------------------------------
-- Description: AXI-Lite Master module controlled via REQ/ACK interface
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
use work.AxiLiteMasterPkg.all;

entity AxiLiteMaster is
   generic (
      -- General Config
      TPD_G : time := 1 ns);
   port (
      axilClk          : in  sl;
      axilRst          : in  sl;
      req              : in  AxiLiteMasterReqType;
      ack              : out AxiLiteMasterAckType;
      axilWriteMaster : out AxiLiteWriteMasterType;
      axilWriteSlave  : in  AxiLiteWriteSlaveType;
      axilReadMaster  : out AxiLiteReadMasterType;
      axilReadSlave   : in  AxiLiteReadSlaveType
      );

end AxiLiteMaster;

architecture rtl of AxiLiteMaster is

   type StateType is (S_IDLE_C, S_WRITE_C, S_WRITE_AXI_C, S_READ_C, S_READ_AXI_C);

   type RegType is record
      ack              : AxiLiteMasterAckType;
      state            : StateType;
      axilWriteMaster : AxiLiteWriteMasterType;
      axilReadMaster  : AxiLiteReadMasterType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      ack              =>  AXI_LITE_MASTER_ACK_INIT_C,
      state            => S_IDLE_C,
      axilWriteMaster => AXI_LITE_WRITE_MASTER_INIT_C,
      axilReadMaster  => AXI_LITE_READ_MASTER_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;


begin

   -------------------------------------
   -- Master State Machine
   -------------------------------------

   comb : process (axilRst, axilReadSlave, axilWriteSlave, r, req) is
      variable v : RegType;
   begin
      v := r;

      -- State machine
      case r.state is

         -- Idle
         when S_IDLE_C =>
            v.axilWriteMaster := AXI_LITE_WRITE_MASTER_INIT_C;
            v.axilReadMaster  := AXI_LITE_READ_MASTER_INIT_C;

            if (req.request = '0') then
               v.ack := AXI_LITE_MASTER_ACK_INIT_C;
            end if;

            -- Frame is starting
            if (req.request = '1' and r.ack.done = '0') then
               if (req.rnw = '1') then
                  v.state := S_READ_C;
               else
                  v.state := S_WRITE_C;
               end if;
            end if;

         -- Prepare Write Transaction
         when S_WRITE_C =>
            v.axilWriteMaster.awaddr  := req.address;
            v.axilWriteMaster.awprot  := (others => '0');
            v.axilWriteMaster.wstrb   := (others => '1');
            v.axilWriteMaster.wdata   := req.wrData;
            v.axilWriteMaster.awvalid := '1';
            v.axilWriteMaster.wvalid  := '1';
            v.axilWriteMaster.bready  := '1';

            v.state := S_WRITE_AXI_C;

         -- Write Transaction, AXI
         when S_WRITE_AXI_C =>
            -- Clear control signals on ack
            if axilWriteSlave.awready = '1' then
               v.axilWriteMaster.awvalid := '0';
            end if;
            if axilWriteSlave.wready = '1' then
               v.axilWriteMaster.wvalid := '0';
            end if;
            if axilWriteSlave.bvalid = '1' then
               v.axilWriteMaster.bready := '0';
               v.ack.done               := '1';
               v.ack.resp                := axilWriteSlave.bresp;
               v.state                   := S_IDLE_C;
            end if;

         -- Read transaction
         when S_READ_C =>
            v.axilReadMaster.araddr := req.address;
            v.axilReadMaster.arprot := (others => '0');

            -- Start AXI transaction
            v.axilReadMaster.arvalid := '1';
            v.axilReadMaster.rready  := '1';
            v.state                   := S_READ_AXI_C;

         -- Read AXI
         when S_READ_AXI_C =>
            -- Clear control signals on ack
            if axilReadSlave.arready = '1' then
               v.axilReadMaster.arvalid := '0';
            end if;
            if axilReadSlave.rvalid = '1' then
               v.axilReadMaster.rready := '0';
               v.ack.rdData             := axilReadSlave.rdata;
               v.ack.resp               := axilReadSlave.rresp;
            end if;

            -- Transaction is done
            if v.axilReadMaster.arvalid = '0' and v.axilReadMaster.rready = '0' then
               v.ack.done := '1';
               v.state     := S_IDLE_C;
            end if;

      end case;

      if (axilRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      ack              <= r.ack;
      axilWriteMaster <= r.axilWriteMaster;
      axilReadMaster  <= r.axilReadMaster;


   end process comb;

   seq : process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;


end rtl;

