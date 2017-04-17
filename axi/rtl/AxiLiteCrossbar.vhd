-------------------------------------------------------------------------------
-- File       : AxiLiteCrossbar.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-09-24
-- Last update: 2016-01-13
-------------------------------------------------------------------------------
-- Description: Wrapper around Xilinx generated Main AXI Crossbar for HPS Front End
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
use work.ArbiterPkg.all;
use work.TextUtilPkg.all;

entity AxiLiteCrossbar is

   generic (
      TPD_G              : time                  := 1 ns;
      NUM_SLAVE_SLOTS_G  : natural range 1 to 16 := 4;
      NUM_MASTER_SLOTS_G : natural range 1 to 64 := 4;
      DEC_ERROR_RESP_G   : slv(1 downto 0)       := AXI_RESP_DECERR_C;
      MASTERS_CONFIG_G   : AxiLiteCrossbarMasterConfigArray;
      DEBUG_G : boolean := false);
   port (
      axiClk    : in sl;
      axiClkRst : in sl;

      -- Slave Slots (Connect to AxiLite Masters
      sAxiWriteMasters : in  AxiLiteWriteMasterArray(NUM_SLAVE_SLOTS_G-1 downto 0);
      sAxiWriteSlaves  : out AxiLiteWriteSlaveArray(NUM_SLAVE_SLOTS_G-1 downto 0);
      sAxiReadMasters  : in  AxiLiteReadMasterArray(NUM_SLAVE_SLOTS_G-1 downto 0);
      sAxiReadSlaves   : out AxiLiteReadSlaveArray(NUM_SLAVE_SLOTS_G-1 downto 0);

      -- Master Slots (Connect to AXI Slaves)
      mAxiWriteMasters : out AxiLiteWriteMasterArray(NUM_MASTER_SLOTS_G-1 downto 0);
      mAxiWriteSlaves  : in  AxiLiteWriteSlaveArray(NUM_MASTER_SLOTS_G-1 downto 0);
      mAxiReadMasters  : out AxiLiteReadMasterArray(NUM_MASTER_SLOTS_G-1 downto 0);
      mAxiReadSlaves   : in  AxiLiteReadSlaveArray(NUM_MASTER_SLOTS_G-1 downto 0)

      );

end entity AxiLiteCrossbar;

architecture rtl of AxiLiteCrossbar is

   type SlaveStateType is (S_WAIT_AXI_TXN_S, S_DEC_ERR_S, S_ACK_S, S_TXN_S);

   constant REQ_NUM_SIZE_C : integer := bitSize(NUM_MASTER_SLOTS_G-1);
   constant ACK_NUM_SIZE_C : integer := bitSize(NUM_SLAVE_SLOTS_G-1);

   type SlaveType is record
      wrState  : SlaveStateType;
      wrReqs   : slv(NUM_MASTER_SLOTS_G-1 downto 0);
      wrReqNum : slv(REQ_NUM_SIZE_C-1 downto 0);
      rdState  : SlaveStateType;
      rdReqs   : slv(NUM_MASTER_SLOTS_G-1 downto 0);
      rdReqNum : slv(REQ_NUM_SIZE_C-1 downto 0);
   end record SlaveType;

   type SlaveArray is array (natural range <>) of SlaveType;

   type MasterStateType is (M_WAIT_REQ_S, M_WAIT_READYS_S, M_WAIT_REQ_FALL_S);

   type MasterType is record
      wrState  : MasterStateType;
      wrAcks   : slv(NUM_SLAVE_SLOTS_G-1 downto 0);
      wrAckNum : slv(ACK_NUM_SIZE_C-1 downto 0);
      wrValid  : sl;
      rdState  : MasterStateType;
      rdAcks   : slv(NUM_SLAVE_SLOTS_G-1 downto 0);
      rdAckNum : slv(ACK_NUM_SIZE_C-1 downto 0);
      rdValid  : sl;
   end record MasterType;

   type MasterArray is array (natural range <>) of MasterType;

   type RegType is record
      slave            : SlaveArray(NUM_SLAVE_SLOTS_G-1 downto 0);
      master           : MasterArray(NUM_MASTER_SLOTS_G-1 downto 0);
      sAxiWriteSlaves  : AxiLiteWriteSlaveArray(NUM_SLAVE_SLOTS_G-1 downto 0);
      sAxiReadSlaves   : AxiLiteReadSlaveArray(NUM_SLAVE_SLOTS_G-1 downto 0);
      mAxiWriteMasters : AxiLiteWriteMasterArray(NUM_MASTER_SLOTS_G-1 downto 0);
      mAxiReadMasters  : AxiLiteReadMasterArray(NUM_MASTER_SLOTS_G-1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      slave            => (
         others        => (
            wrState    => S_WAIT_AXI_TXN_S,
            wrReqs     => (others => '0'),
            wrReqNum   => (others => '0'),
            rdState    => S_WAIT_AXI_TXN_S,
            rdReqs     => (others => '0'),
            rdReqNum   => (others => '0'))),
      master           => (
         others        => (
            wrState    => M_WAIT_REQ_S,
            wrAcks     => (others => '0'),
            wrAckNum   => (others => '0'),
            wrValid    => '0',
            rdState    => M_WAIT_REQ_S,
            rdAcks     => (others => '0'),
            rdAckNum   => (others => '0'),
            rdValid    => '0')),
      sAxiWriteSlaves  => (others => AXI_LITE_WRITE_SLAVE_INIT_C),
      sAxiReadSlaves   => (others => AXI_LITE_READ_SLAVE_INIT_C),
      mAxiWriteMasters => axiWriteMasterInit(MASTERS_CONFIG_G),
      mAxiReadMasters  => axiReadMasterInit(MASTERS_CONFIG_G));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   type AxiStatusArray is array (natural range <>) of AxiLiteStatusType;

begin

   print(DEBUG_G, "AXI_LITE_CROSSBAR: " & LF &
         "NUM_SLAVE_SLOTS_G: " & integer'image(NUM_SLAVE_SLOTS_G) & LF &
         "NUM_MASTER_SLOTS_G: " & integer'image(NUM_MASTER_SLOTS_G) & LF &
         "DEC_ERROR_RESP_G: " & str(DEC_ERROR_RESP_G) & LF &
         "MASTERS_CONFIG_G:");

   printCfg : for i in MASTERS_CONFIG_G'range generate
      print(DEBUG_G, 
         "  baseAddr: " & hstr(MASTERS_CONFIG_G(i).baseAddr) & LF &
         "  addrBits: " & str(MASTERS_CONFIG_G(i).addrBits) & LF &
         "  connectivity: " & hstr(MASTERS_CONFIG_G(i).connectivity));
   end generate printCfg;

   comb : process (axiClkRst, mAxiReadSlaves, mAxiWriteSlaves, r, sAxiReadMasters, sAxiWriteMasters) is
      variable v            : RegType;
      variable sAxiStatuses : AxiStatusArray(NUM_SLAVE_SLOTS_G-1 downto 0);
      variable mRdReqs      : slv(NUM_SLAVE_SLOTS_G-1 downto 0);
      variable mWrReqs      : slv(NUM_SLAVE_SLOTS_G-1 downto 0);
   begin
      v := r;

      -- Control slave side outputs
      for s in NUM_SLAVE_SLOTS_G-1 downto 0 loop

         v.sAxiWriteSlaves(s).awready := '0';
         v.sAxiWriteSlaves(s).wready  := '0';
         v.sAxiReadSlaves(s).arready  := '0';

         -- Reset resp valid
         if (sAxiWriteMasters(s).bready = '1') then
            v.sAxiWriteSlaves(s).bvalid := '0';
         end if;

         -- Reset rvalid upon rready
         if (sAxiReadMasters(s).rready = '1') then
            v.sAxiReadSlaves(s).rvalid := '0';
         end if;

         -- Write state machine
         case (r.slave(s).wrState) is
            when S_WAIT_AXI_TXN_S =>

               -- Incomming write
               if (sAxiWriteMasters(s).awvalid = '1' and sAxiWriteMasters(s).wvalid = '1') then

                  for m in MASTERS_CONFIG_G'range loop
                     -- Check for address match
                     if (sAxiWriteMasters(s).awaddr(31 downto MASTERS_CONFIG_G(m).addrBits) =
                         MASTERS_CONFIG_G(m).baseAddr(31 downto MASTERS_CONFIG_G(m).addrBits) and
                         MASTERS_CONFIG_G(m).connectivity(s) = '1') then
                        v.slave(s).wrReqs(m) := '1';
                        v.slave(s).wrReqNum  := conv_std_logic_vector(m, REQ_NUM_SIZE_C);
--                        print("AxiLiteCrossbar: Slave  " & str(s) & " reqd Master " & str(m) & " Write addr " & hstr(sAxiWriteMasters(s).awaddr));
                     end if;
                  end loop;

                  -- Respond with error if decode fails
                  if (uOr(v.slave(s).wrReqs) = '0') then
                     v.sAxiWriteSlaves(s).awready := '1';
                     v.sAxiWriteSlaves(s).wready  := '1';
                     v.slave(s).wrState           := S_DEC_ERR_S;
                  else
                     v.slave(s).wrState := S_ACK_S;
                  end if;
               end if;

            -- Send error
            when S_DEC_ERR_S =>
               if (sAxiWriteMasters(s).bready = '1') then
                  v.sAxiWriteSlaves(s).bresp  := DEC_ERROR_RESP_G;
                  v.sAxiWriteSlaves(s).bvalid := '1';
                  v.slave(s).wrState          := S_WAIT_AXI_TXN_S;
               end if;

            -- Transaction is acked
            when S_ACK_S =>
               for m in NUM_MASTER_SLOTS_G-1 downto 0 loop
                  if (r.slave(s).wrReqNum = m and r.slave(s).wrReqs(m) = '1' and r.master(m).wrAcks(s) = '1') then
                     v.sAxiWriteSlaves(s).awready := '1';
                     v.sAxiWriteSlaves(s).wready  := '1';
                     v.slave(s).wrState           := S_TXN_S;
                  end if;
               end loop;

            -- Transaction in progress
            when S_TXN_S =>
               for m in NUM_MASTER_SLOTS_G-1 downto 0 loop
                  if (r.slave(s).wrReqNum = m and r.slave(s).wrReqs(m) = '1' and r.master(m).wrAcks(s) = '1') then

                     -- Forward write response
                     v.sAxiWriteSlaves(s).bresp  := mAxiWriteSlaves(m).bresp;
                     v.sAxiWriteSlaves(s).bvalid := mAxiWriteSlaves(m).bvalid;

                     -- bvalid or rvalid indicates txn concluding
                     if (r.sAxiWriteSlaves(s).bvalid = '1' and sAxiWriteMasters(s).bready = '1') then
                        v.sAxiWriteSlaves(s) := AXI_LITE_WRITE_SLAVE_INIT_C;
                        v.slave(s).wrReqs    := (others => '0');
                        v.slave(s).wrState   := S_WAIT_AXI_TXN_S;
                     end if;
                  end if;
               end loop;
         end case;

         -- Read state machine
         case (r.slave(s).rdState) is
            when S_WAIT_AXI_TXN_S =>

               -- Incomming read
               if (sAxiReadMasters(s).arvalid = '1') then
                  for m in MASTERS_CONFIG_G'range loop
                     -- Check for address match
                     if (sAxiReadMasters(s).araddr(31 downto MASTERS_CONFIG_G(m).addrBits) =
                         MASTERS_CONFIG_G(m).baseAddr(31 downto MASTERS_CONFIG_G(m).addrBits) and
                         MASTERS_CONFIG_G(m).connectivity(s) = '1') then
                        v.slave(s).rdReqs(m) := '1';
                        v.slave(s).rdReqNum  := conv_std_logic_vector(m, REQ_NUM_SIZE_C);
                     end if;
                  end loop;

                  -- Respond with error if decode fails
                  if (uOr(v.slave(s).rdReqs) = '0') then
                     v.sAxiReadSlaves(s).arready := '1';
                     v.slave(s).rdState          := S_DEC_ERR_S;
                  else
                     v.slave(s).rdState := S_ACK_S;
                  end if;
               end if;

            -- Error
            when S_DEC_ERR_S =>
               if (sAxiReadMasters(s).rready = '1') then
                  v.sAxiReadSlaves(s).rresp  := DEC_ERROR_RESP_G;
                  v.sAxiReadSlaves(s).rdata  := (others => '0');
                  v.sAxiReadSlaves(s).rvalid := '1';
                  v.slave(s).rdState         := S_WAIT_AXI_TXN_S;
               end if;

            -- Transaction is acked
            when S_ACK_S =>
               for m in NUM_MASTER_SLOTS_G-1 downto 0 loop
                  if (r.slave(s).rdReqNum = m and r.slave(s).rdReqs(m) = '1' and r.master(m).rdAcks(s) = '1') then
                     v.sAxiReadSlaves(s).arready := '1';
                     v.slave(s).rdState          := S_TXN_S;
                  end if;
               end loop;

            -- Transaction in progress
            when S_TXN_S =>
               for m in NUM_MASTER_SLOTS_G-1 downto 0 loop
                  if (r.slave(s).rdReqNum = m and r.slave(s).rdReqs(m) = '1' and r.master(m).rdAcks(s) = '1') then

                     -- Forward read response
                     v.sAxiReadSlaves(s).rresp  := mAxiReadSlaves(m).rresp;
                     v.sAxiReadSlaves(s).rdata  := mAxiReadSlaves(m).rdata;
                     v.sAxiReadSlaves(s).rvalid := mAxiReadSlaves(m).rvalid;

                     -- rvalid indicates txn concluding
                     if (r.sAxiReadSlaves(s).rvalid = '1' and sAxiReadMasters(s).rready = '1') then
                        v.sAxiReadSlaves(s) := AXI_LITE_READ_SLAVE_INIT_C;
                        v.slave(s).rdReqs   := (others => '0');
                        v.slave(s).rdState  := S_WAIT_AXI_TXN_S;  --S_WAIT_DONE_S;
                     end if;
                  end if;
               end loop;
         end case;
      end loop;


      -- Control master side outputs
      for m in NUM_MASTER_SLOTS_G-1 downto 0 loop

         -- Group reqs by master
         mWrReqs := (others => '0');
         mRdReqs := (others => '0');
         for i in mWrReqs'range loop
            mWrReqs(i) := r.slave(i).wrReqs(m);
            mRdReqs(i) := r.slave(i).rdReqs(m);
         end loop;

         -- Write path processing
         case (r.master(m).wrState) is
            when M_WAIT_REQ_S =>

               -- Keep these in reset state while waiting for requests
               v.master(m).wrAcks    := (others => '0');
               v.mAxiWriteMasters(m) := axiWriteMasterInit(MASTERS_CONFIG_G(m));

               -- Wait for a request, arbitrate between simultaneous requests
               if (r.master(m).wrValid = '0') then
                  arbitrate(mWrReqs, r.master(m).wrAckNum, v.master(m).wrAckNum, v.master(m).wrValid, v.master(m).wrAcks);
               end if;

               -- Upon valid request (set 1 cycle previous by arbitrate()), connect slave side
               -- busses to this master's outputs.
               if (r.master(m).wrValid = '1') then
                  v.master(m).wrAcks    := r.master(m).wrAcks;
                  v.mAxiWriteMasters(m) := sAxiWriteMasters(conv_integer(r.master(m).wrAckNum));
                  v.master(m).wrState   := M_WAIT_READYS_S;
               end if;

            when M_WAIT_READYS_S =>

               -- Wait for attached slave to respond
               -- Clear *valid signals upon *ready responses
               if (mAxiWriteSlaves(m).awready = '1') then
                  v.mAxiWriteMasters(m).awvalid := '0';
               end if;
               if (mAxiWriteSlaves(m).wready = '1') then
                  v.mAxiWriteMasters(m).wvalid := '0';
               end if;

               -- When all *valid signals cleared, wait for slave side to clear request
               if (v.mAxiWriteMasters(m).awvalid = '0' and v.mAxiWriteMasters(m).wvalid = '0') then
                  v.master(m).wrState := M_WAIT_REQ_FALL_S;
               end if;

            when M_WAIT_REQ_FALL_S =>
               -- When slave side deasserts request, clear ack and valid and start waiting for next
               -- request
               if (mWrReqs(conv_integer(r.master(m).wrAckNum)) = '0') then
                  v.master(m).wrState := M_WAIT_REQ_S;
                  v.master(m).wrAcks  := (others => '0');
                  v.master(m).wrValid := '0';
               end if;

         end case;

         -- Don't allow baseAddr bits to be overwritten
         -- They can't be anyway based on the logic above, but Vivado can't figure that out.
         -- This helps optimization happen properly
         v.mAxiWriteMasters(m).awaddr(31 downto MASTERS_CONFIG_G(m).addrBits) :=
            MASTERS_CONFIG_G(m).baseAddr(31 downto MASTERS_CONFIG_G(m).addrBits);



         -- Read path processing
         case (r.master(m).rdState) is
            when M_WAIT_REQ_S =>

               -- Keep these in reset state while waiting for requests
               v.master(m).rdAcks   := (others => '0');
               v.mAxiReadMasters(m) := axiReadMasterInit(MASTERS_CONFIG_G(m));

               -- Wait for a request, arbitrate between simultaneous requests
               if (r.master(m).rdValid = '0') then
                  arbitrate(mRdReqs, r.master(m).rdAckNum, v.master(m).rdAckNum, v.master(m).rdValid, v.master(m).rdAcks);
               end if;

               -- Upon valid request (set 1 cycle previous by arbitrate()), connect slave side
               -- busses to this master's outputs.
               if (r.master(m).rdValid = '1') then
                  v.master(m).rdAcks   := r.master(m).rdAcks;
                  v.mAxiReadMasters(m) := sAxiReadMasters(conv_integer(r.master(m).rdAckNum));
                  v.master(m).rdState  := M_WAIT_READYS_S;
               end if;

            when M_WAIT_READYS_S =>

               -- Wait for attached slave to respond
               -- Clear *valid signals upon *ready responses
               if (mAxiReadSlaves(m).arready = '1') then
                  v.mAxiReadMasters(m).arvalid := '0';
               end if;

               -- When all *valid signals cleared, wait for slave side to clear request
               if (v.mAxiReadMasters(m).arvalid = '0') then
                  v.master(m).rdState := M_WAIT_REQ_FALL_S;
               end if;

            when M_WAIT_REQ_FALL_S =>
               -- When slave side deasserts request, clear ack and valid and start waiting for next
               -- request
               if (mRdReqs(conv_integer(r.master(m).rdAckNum)) = '0') then
                  v.master(m).rdState := M_WAIT_REQ_S;
                  v.master(m).rdAcks  := (others => '0');
                  v.master(m).rdValid := '0';
               end if;

         end case;

         -- Don't allow baseAddr bits to be overwritten
         -- They can't be anyway based on the logic above, but Vivado can't figure that out.
         -- This helps optimization happen properly
         v.mAxiReadMasters(m).araddr(31 downto MASTERS_CONFIG_G(m).addrBits) :=
            MASTERS_CONFIG_G(m).baseAddr(31 downto MASTERS_CONFIG_G(m).addrBits);

      end loop;

      if (axiClkRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      sAxiReadSlaves   <= r.sAxiReadSlaves;
      sAxiWriteSlaves  <= r.sAxiWriteSlaves;
      mAxiReadMasters  <= r.mAxiReadMasters;
      mAxiWriteMasters <= r.mAxiWriteMasters;

   end process comb;

   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;

