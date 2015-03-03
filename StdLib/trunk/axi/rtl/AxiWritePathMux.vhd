-------------------------------------------------------------------------------
-- Title      : AXI Write Path Multiplexer
-- Project    : General Purpose Core
-------------------------------------------------------------------------------
-- File       : AxiWritePathMux.vhd
-- Author     : Ryan Herbst, rherbst@slac.stanford.edu
-- Created    : 2014-04-25
-- Last update: 2014-04-29
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-- Block to connect multiple incoming AXI write path interfaces.
-------------------------------------------------------------------------------
-- Copyright (c) 2014 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 04/25/2014: created.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.ArbiterPkg.all;
use work.AxiPkg.all;

entity AxiWritePathMux is
   generic (
      TPD_G        : time                  := 1 ns;
      NUM_SLAVES_G : integer range 1 to 32 := 4
      );
   port (

      -- Clock and reset
      axiClk : in sl;
      axiRst : in sl;

      -- Slaves
      sAxiWriteMasters : in  AxiWriteMasterArray(NUM_SLAVES_G-1 downto 0);
      sAxiWriteSlaves  : out AxiWriteSlaveArray(NUM_SLAVES_G-1 downto 0);

      -- Master
      mAxiWriteMaster  : out AxiWriteMasterType;
      mAxiWriteSlave   : in  AxiWriteSlaveType
      );
end AxiWritePathMux;

architecture structure of AxiWritePathMux is

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
      dataState  : StateType;
      dataAcks   : slv(ARB_BITS_C-1 downto 0);
      dataAckNum : slv(DEST_SIZE_C-1 downto 0);
      dataValid  : sl;
      slaves     : AxiWriteSlaveArray(NUM_SLAVES_G-1 downto 0);
      master     : AxiWriteMasterType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      addrState  => S_IDLE_C,
      addrAcks   => (others => '0'),
      addrAckNum => (others => '0'),
      addrValid  => '0',
      dataState  => S_IDLE_C,
      dataAcks   => (others => '0'),
      dataAckNum => (others => '0'),
      dataValid  => '0',
      slaves     => (others => AXI_WRITE_SLAVE_INIT_C),
      master     => AXI_WRITE_MASTER_INIT_C
      );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (axiRst, r, sAxiWriteMasters, mAxiWriteSlave) is
      variable v            : RegType;
      variable addrRequests : slv(ARB_BITS_C-1 downto 0);
      variable dataRequests : slv(ARB_BITS_C-1 downto 0);
      variable selAddr      : AxiWriteMasterType;
      variable selData      : AxiWriteMasterType;
   begin
      v := r;

      ----------------------------
      -- Address Path
      ----------------------------

      -- Init Slave Ready
      for i in 0 to (NUM_SLAVES_G-1) loop
         v.slaves(i).awready := '0';
      end loop;

      -- Select address source
      selAddr       := sAxiWriteMasters(conv_integer(r.addrAckNum));
      selAddr.awid  := (others => '0');

      selAddr.awid(DEST_SIZE_C-1 downto 0) := r.addrAckNum;

      -- Format requests
      addrRequests := (others=>'0');
      for i in 0 to (NUM_SLAVES_G-1) loop
         addrRequests(i) := sAxiWriteMasters(i).awvalid;
      end loop;

      -- Addr State machine
      case r.addrState is

         -- IDLE
         when S_IDLE_C =>
            v.master.awvalid := '0';

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
            v.slaves(conv_integer(r.addrAckNum)).awready := '1';

            -- Advance pipeline 
            v.master.awvalid := '1';
            v.master.awaddr  := selAddr.awaddr;
            v.master.awid    := selAddr.awid;
            v.master.awlen   := selAddr.awlen;
            v.master.awsize  := selAddr.awsize;
            v.master.awburst := selAddr.awburst;
            v.master.awlock  := selAddr.awlock;
            v.master.awprot  := selAddr.awprot;
            v.master.awcache := selAddr.awcache;
            v.addrState      := S_LAST_C;

         -- Laster transfer
         when S_LAST_C =>
            if mAxiWriteSlave.awready = '1' then
               v.master.awvalid := '0';
               v.addrState      := S_IDLE_C;
            end if;
      end case;

      ----------------------------
      -- Data Path
      ----------------------------

      -- Init Slave Ready
      for i in 0 to (NUM_SLAVES_G-1) loop
         v.slaves(i).wready  := '0';
      end loop;

      -- Select data source
      selData      := sAxiWriteMasters(conv_integer(r.dataAckNum));
      selData.wid  := (others => '0');

      selData.wid(DEST_SIZE_C-1 downto 0) := r.dataAckNum;

      -- Format requests
      dataRequests := (others=>'0');
      for i in 0 to (NUM_SLAVES_G-1) loop
         dataRequests(i) := sAxiWriteMasters(i).wvalid;
      end loop;

      -- Data State machine
      case r.dataState is

         -- IDLE
         when S_IDLE_C =>
            v.master.wvalid := '0';

            -- Aribrate between requesters
            if r.dataValid = '0' then
               arbitrate(dataRequests, r.dataAckNum, v.dataAckNum, v.dataValid, v.dataAcks);
            end if;

            -- Valid request
            if r.dataValid = '1' then
               v.dataState := S_MOVE_C;
            end if;

         -- Move a frame until tLast
         when S_MOVE_C =>
            v.dataValid := '0';

            -- Pass ready
            v.slaves(conv_integer(r.dataAckNum)).wready := mAxiWriteSlave.wready;

            -- Advance pipeline 
            if r.master.wvalid = '0' or mAxiWriteSlave.wready = '1' then
               v.master.wdata  := selData.wdata;
               v.master.wlast  := selData.wlast;
               v.master.wvalid := selData.wvalid;
               v.master.wstrb  := selData.wstrb;
               v.master.wid    := selData.wid;

               -- wlast to be presented
               if selData.wlast = '1' and selData.wvalid = '1' then
                  v.dataState := S_LAST_C;
               end if;
            end if;

         -- Laster transfer
         when S_LAST_C =>
            if mAxiWriteSlave.wready = '1' then
               v.master.wvalid := '0';
               v.dataState     := S_IDLE_C;
            end if;
      end case;

      ----------------------------
      -- Response Path
      ----------------------------

      -- Clear existing valids
      for i in 0 to (NUM_SLAVES_G-1) loop
         if sAxiWriteMasters(i).bready = '1' then
            v.slaves(i).bvalid := '0';
         end if;
      end loop;

      -- Pass response to destination
      if r.slaves(conv_integer(mAxiWriteSlave.bid(DEST_SIZE_C-1 downto 0))).bvalid = '0' or
         sAxiWriteMasters(conv_integer(mAxiWriteSlave.bid(DEST_SIZE_C-1 downto 0))).bready = '1' then

         v.slaves(conv_integer(mAxiWriteSlave.bid(DEST_SIZE_C-1 downto 0))).bresp  := mAxiWriteSlave.bresp;
         v.slaves(conv_integer(mAxiWriteSlave.bid(DEST_SIZE_C-1 downto 0))).bvalid := mAxiWriteSlave.bvalid;
         v.slaves(conv_integer(mAxiWriteSlave.bid(DEST_SIZE_C-1 downto 0))).bid    := mAxiWriteSlave.bid;
         v.master.bready := '1';
      else
         v.master.bready := '0';
      end if;
   
      if (axiRst = '1') or (NUM_SLAVES_G = 1) then
         v := REG_INIT_C;
      end if;

      rin <= v;

      -- Bypass if single slave
      if NUM_SLAVES_G = 1 then
         sAxiWriteSlaves(0) <= mAxiWriteSlave;
         mAxiWriteMaster    <= sAxiWritemasters(0);
      else

         -- Output data
         sAxiWriteSlaves <= r.slaves;
         mAxiWriteMaster <= r.master;

         -- Readies are direct
         for i in 0 to (NUM_SLAVES_G-1) loop
            sAxiWriteSlaves(i).awready <= v.slaves(i).awready;
            sAxiWriteSlaves(i).wready  <= v.slaves(i).wready;
         end loop;
         mAxiWriteMaster.bready <= v.master.bready;
      end if;

   end process comb;

   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end structure;
