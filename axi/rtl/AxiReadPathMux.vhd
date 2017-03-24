-------------------------------------------------------------------------------
-- File       : AxiReadPathMux.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-25
-- Last update: 2014-04-29
-------------------------------------------------------------------------------
-- Description: Block to connect multiple incoming AXI write path interfaces.
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
use work.ArbiterPkg.all;
use work.AxiPkg.all;

entity AxiReadPathMux is
   generic (
      TPD_G        : time                  := 1 ns;
      NUM_SLAVES_G : integer range 1 to 32 := 4
      );
   port (

      -- Clock and reset
      axiClk : in sl;
      axiRst : in sl;

      -- Slaves
      sAxiReadMasters : in  AxiReadMasterArray(NUM_SLAVES_G-1 downto 0);
      sAxiReadSlaves  : out AxiReadSlaveArray(NUM_SLAVES_G-1 downto 0);

      -- Master
      mAxiReadMaster  : out AxiReadMasterType;
      mAxiReadSlave   : in  AxiReadSlaveType
      );
end AxiReadPathMux;

architecture structure of AxiReadPathMux is

   constant DEST_SIZE_C : integer := bitSize(NUM_SLAVES_G-1);
   constant ARB_BITS_C  : integer := 2**DEST_SIZE_C;

   --------------------------
   -- Address Path
   --------------------------

   type StateType is (S_IDLE_C, S_MOVE_C, S_LAST_C);

   type RegType is record
      addrState  : StateType;
      addrAcks   : slv(ARB_BITS_C-1 downto 0);
      addrAckNum : slv(DEST_SIZE_C-1 downto 0);
      addrValid  : sl;
      slaves     : AxiReadSlaveArray(NUM_SLAVES_G-1 downto 0);
      master     : AxiReadMasterType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      addrState  => S_IDLE_C,
      addrAcks   => (others => '0'),
      addrAckNum => (others => '0'),
      addrValid  => '0',
      slaves     => (others => AXI_READ_SLAVE_INIT_C),
      master     => AXI_READ_MASTER_INIT_C
      );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (axiRst, r, sAxiReadMasters, mAxiReadSlave) is
      variable v            : RegType;
      variable addrRequests : slv(ARB_BITS_C-1 downto 0);
      variable selAddr      : AxiReadMasterType;
   begin
      v := r;

      ----------------------------
      -- Address Path
      ----------------------------

      -- Init Slave Ready
      for i in 0 to (NUM_SLAVES_G-1) loop
         v.slaves(i).arready := '0';
      end loop;

      -- Select address source
      selAddr       := sAxiReadMasters(conv_integer(r.addrAckNum));
      selAddr.arid  := (others => '0');

      selAddr.arid(DEST_SIZE_C-1 downto 0) := r.addrAckNum;

      -- Format requests
      addrRequests := (others=>'0');
      for i in 0 to (NUM_SLAVES_G-1) loop
         addrRequests(i) := sAxiReadMasters(i).arvalid;
      end loop;

      -- Addr State machine
      case r.addrState is

         -- IDLE
         when S_IDLE_C =>
            v.master.arvalid := '0';

            -- Aribrate between requesters
            if r.addrValid = '0' then
               arbitrate(addrRequests, r.addrAckNum, v.addrAckNum, v.addrValid, v.addrAcks);
            end if;

            -- Valid request
            if r.addrValid = '1' then
               v.addrState := S_MOVE_C;
            end if;

         -- Move one entry
         when S_MOVE_C =>
            v.addrValid := '0';

            -- Assert ready
            v.slaves(conv_integer(r.addrAckNum)).arready := '1';

            -- Advance pipeline 
            v.master.arvalid := '1';
            v.master.araddr  := selAddr.araddr;
            v.master.arid    := selAddr.arid;
            v.master.arlen   := selAddr.arlen;
            v.master.arsize  := selAddr.arsize;
            v.master.arburst := selAddr.arburst;
            v.master.arlock  := selAddr.arlock;
            v.master.arprot  := selAddr.arprot;
            v.master.arcache := selAddr.arcache;
            v.addrState      := S_LAST_C;

         -- Laster transfer
         when S_LAST_C =>
            if mAxiReadSlave.arready = '1' then
               v.master.arvalid := '0';
               v.addrState      := S_IDLE_C;
            end if;
      end case;

      ----------------------------
      -- Data Path
      ----------------------------

      -- Clear existing valids
      for i in 0 to (NUM_SLAVES_G-1) loop
         if sAxiReadMasters(i).rready = '1' then
            v.slaves(i).rvalid := '0';
         end if;
      end loop;

      -- Pass response to destination
      if r.slaves(conv_integer(mAxiReadSlave.rid(DEST_SIZE_C-1 downto 0))).rvalid = '0' or
         sAxiReadMasters(conv_integer(mAxiReadSlave.rid(DEST_SIZE_C-1 downto 0))).rready = '1' then

         v.slaves(conv_integer(mAxiReadSlave.rid(DEST_SIZE_C-1 downto 0))).rvalid := mAxiReadSlave.rvalid;
         v.slaves(conv_integer(mAxiReadSlave.rid(DEST_SIZE_C-1 downto 0))).rdata  := mAxiReadSlave.rdata;
         v.slaves(conv_integer(mAxiReadSlave.rid(DEST_SIZE_C-1 downto 0))).rlast  := mAxiReadSlave.rlast;
         v.slaves(conv_integer(mAxiReadSlave.rid(DEST_SIZE_C-1 downto 0))).rresp  := mAxiReadSlave.rresp;
         v.slaves(conv_integer(mAxiReadSlave.rid(DEST_SIZE_C-1 downto 0))).rid    := mAxiReadSlave.rid;
         v.master.rready := '1';
      else
         v.master.rready := '0';
      end if;
   
      if (axiRst = '1' ) or (NUM_SLAVES_G = 1) then
         v := REG_INIT_C;
      end if;

      rin <= v;

      -- Bypass if single slave
      if NUM_SLAVES_G = 1 then
         sAxiReadSlaves(0) <= mAxiReadSlave;
         mAxiReadMaster    <= sAxiReadmasters(0);
      else

         -- Output data
         sAxiReadSlaves <= r.slaves;
         mAxiReadMaster <= r.master;

         -- Readies are direct
         for i in 0 to (NUM_SLAVES_G-1) loop
            sAxiReadSlaves(i).arready <= v.slaves(i).arready;
         end loop;
         mAxiReadMaster.rready <= v.master.rready;
      end if;
   end process comb;

   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end structure;
