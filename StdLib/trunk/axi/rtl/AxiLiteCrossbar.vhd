-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : MainAxiCrossbarWrapper.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-09-24
-- Last update: 2014-03-05
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Wrapper around Xilinx generated Main AXI Crossbar for HPS Front End
-------------------------------------------------------------------------------
-- Copyright (c) 2013 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.ArbiterPkg.all;
--use work.TextUtilPkg.all;

entity AxiLiteCrossbar is

   generic (
      TPD_G              : time                             := 1 ns;
      NUM_SLAVE_SLOTS_G  : natural range 1 to 16            := 4;
      NUM_MASTER_SLOTS_G : natural range 1 to 16            := 4;
      DEC_ERROR_RESP_G   : slv(1 downto 0)                  := AXI_RESP_DECERR_C;
      MASTERS_CONFIG_G   : AxiLiteCrossbarMasterConfigArray);
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

   type SlaveStateType is (S_WAIT_AXI_TXN_S, S_WR_DEC_ERR_S, S_RD_DEC_ERR_S, S_DO_TXN_S);

   constant REQ_NUM_SIZE_C : integer := bitSize(NUM_MASTER_SLOTS_G-1);
   constant ACK_NUM_SIZE_C : integer := bitSize(NUM_SLAVE_SLOTS_G-1);

   type SlaveType is record
      state  : SlaveStateType;
      reqs   : slv(NUM_MASTER_SLOTS_G-1 downto 0);
      reqNum : slv(REQ_NUM_SIZE_C-1 downto 0);
   end record SlaveType;

   type SlaveArray is array (natural range <>) of SlaveType;

   type MasterStateType is (M_WAIT_REQ_S, M_WAIT_READYS_S, M_WAIT_REQ_FALL_S);

   type MasterType is record
      state  : MasterStateType;
      acks   : slv(NUM_SLAVE_SLOTS_G-1 downto 0);
      ackNum : slv(ACK_NUM_SIZE_C-1 downto 0);
      valid  : sl;
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
            state      => S_WAIT_AXI_TXN_S,
            reqs       => (others => '0'),
            reqNum     => (others => '0'))),
      master           => (
         others        => (
            state      => M_WAIT_REQ_S,
            acks       => (others => '0'),
            ackNum     => (others => '0'),
            valid      => '0')),
      sAxiWriteSlaves  => (others => AXI_WRITE_SLAVE_INIT_C),
      sAxiReadSlaves   => (others => AXI_READ_SLAVE_INIT_C),
      mAxiWriteMasters => (others => AXI_WRITE_MASTER_INIT_C),
      mAxiReadMasters  => (others => AXI_READ_MASTER_INIT_C));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   type AxiStatusArray is array (natural range <>) of AxiLiteStatusType;

begin

   comb : process (axiClkRst, mAxiReadSlaves, mAxiWriteSlaves, r, sAxiReadMasters, sAxiWriteMasters) is
      variable v            : RegType;
      variable sAxiStatuses : AxiStatusArray(NUM_SLAVE_SLOTS_G-1 downto 0);
      variable mReqs        : slv(NUM_SLAVE_SLOTS_G-1 downto 0);
   begin
      v := r;

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

         case (r.slave(s).state) is
            when S_WAIT_AXI_TXN_S =>

               -- Incomming write
               if (sAxiWriteMasters(s).awvalid = '1' and sAxiWriteMasters(s).wvalid = '1') then
                  for m in MASTERS_CONFIG_G'range loop
                     -- Check for address match
                     if (sAxiWriteMasters(s).awaddr(31 downto MASTERS_CONFIG_G(m).addrBits) =
                         MASTERS_CONFIG_G(m).baseAddr(31 downto MASTERS_CONFIG_G(m).addrBits) and
                         MASTERS_CONFIG_G(m).connectivity(s) = '1') then
                        v.slave(s).reqs(m) := '1';
                        v.slave(s).reqNum  := conv_std_logic_vector(m, REQ_NUM_SIZE_C);
--                        print("AxiLiteCrossbar: Slave  " & str(s) & " reqd Master " & str(m) & " Write addr " & hstr(sAxiWriteMasters(s).awaddr));
                     end if;
                  end loop;

                  -- Respond with error if decode fails
                  if (uOr(v.slave(s).reqs) = '0') then
                     v.sAxiWriteSlaves(s).awready := '1';
                     v.sAxiWriteSlaves(s).wready  := '1';
                     v.slave(s).state             := S_WR_DEC_ERR_S;
                  else
                     v.slave(s).state := S_DO_TXN_S;
                  end if;


               -- Incomming read
               elsif (sAxiReadMasters(s).arvalid = '1') then
                  for m in MASTERS_CONFIG_G'range loop
                     -- Check for address match
                     if (sAxiReadMasters(s).araddr(31 downto MASTERS_CONFIG_G(m).addrBits) =
                         MASTERS_CONFIG_G(m).baseAddr(31 downto MASTERS_CONFIG_G(m).addrBits) and
                         MASTERS_CONFIG_G(m).connectivity(s) = '1') then
                        v.slave(s).reqs(m) := '1';
                        v.slave(s).reqNum  := conv_std_logic_vector(m, REQ_NUM_SIZE_C);
                     end if;
                  end loop;

                  -- Respond with error if decode fails
                  if (uOr(v.slave(s).reqs) = '0') then
                     v.sAxiReadSlaves(s).arready := '1';
                     v.slave(s).state            := S_RD_DEC_ERR_S;
                  else
                     v.slave(s).state := S_DO_TXN_S;
                  end if;

               end if;

            when S_WR_DEC_ERR_S =>
               if (sAxiWriteMasters(s).bready = '1') then
                  v.sAxiWriteSlaves(s).bresp  := DEC_ERROR_RESP_G;
                  v.sAxiWriteSlaves(s).bvalid := '1';
                  v.slave(s).state            := S_WAIT_AXI_TXN_S;
               end if;

            when S_RD_DEC_ERR_S =>
               if (sAxiReadMasters(s).rready = '1') then
                  v.sAxiReadSlaves(s).rresp  := DEC_ERROR_RESP_G;
                  v.sAxiReadSlaves(s).rdata  := (others=>'0');
                  v.sAxiReadSlaves(s).rvalid := '1';
                  v.slave(s).state           := S_WAIT_AXI_TXN_S;
               end if;

            when S_DO_TXN_S =>
               for m in NUM_MASTER_SLOTS_G-1 downto 0 loop
                  if (r.slave(s).reqNum = m and r.slave(s).reqs(m) = '1' and r.master(m).acks(s) = '1') then
                     -- Connect Masters to Slaves upon ack
                     v.sAxiWriteSlaves(s) := mAxiWriteSlaves(m);
                     v.sAxiReadSlaves(s)  := mAxiReadSlaves(m);
                     if ((r.sAxiWriteSlaves(s).bvalid = '1' and sAxiWriteMasters(s).bready = '1') or
                         (r.sAxiReadSlaves(s).rvalid = '1' and sAxiReadMasters(s).rready = '1')) then
                        -- bvalid or rvalid indicates txn concluding
                        v.sAxiWriteSlaves(s) := AXI_WRITE_SLAVE_INIT_C;
                        v.sAxiReadSlaves(s)  := AXI_READ_SLAVE_INIT_C;
                        v.slave(s).reqs      := (others => '0');
                        v.slave(s).state     := S_WAIT_AXI_TXN_S;  --S_WAIT_DONE_S;
                     end if;
                  end if;
               end loop;

         end case;
      end loop;



      for m in NUM_MASTER_SLOTS_G-1 downto 0 loop
         -- Group reqs by master
         mReqs := (others => '0');
         for i in mReqs'range loop
            mReqs(i) := r.slave(i).reqs(m);
         end loop;

         case (r.master(m).state) is
            when M_WAIT_REQ_S =>

               -- Keep these in reset state while waiting for requests
               v.master(m).acks      := (others => '0');
               v.mAxiWriteMasters(m) := AXI_WRITE_MASTER_INIT_C;
               v.mAxiReadMasters(m)  := AXI_READ_MASTER_INIT_C;

               -- Wait for a request, arbitrate between simultaneous requests
               if (r.master(m).valid = '0') then
                  arbitrate(mReqs, r.master(m).ackNum, v.master(m).ackNum, v.master(m).valid, v.master(m).acks);
               end if;

               -- Upon valid request (set 1 cycle previous by arbitrate()), connect slave side
               -- busses to this master's outputs.
               if (r.master(m).valid = '1') then
                  v.master(m).acks      := r.master(m).acks;
                  v.mAxiWriteMasters(m) := sAxiWriteMasters(conv_integer(r.master(m).ackNum));
                  v.mAxiReadMasters(m)  := sAxiReadMasters(conv_integer(r.master(m).ackNum));
                  v.master(m).state     := M_WAIT_READYS_S;
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

               if (mAxiReadSlaves(m).arready = '1') then
                  v.mAxiReadMasters(m).arvalid := '0';
               end if;

               -- When all *valid signals cleared, wait for slave side to clear request
               if (v.mAxiWriteMasters(m).awvalid = '0' and
                   v.mAxiWriteMasters(m).wvalid = '0' and
                   v.mAxiReadMasters(m).arvalid = '0') then
                  v.master(m).state := M_WAIT_REQ_FALL_S;
               end if;
               
            when M_WAIT_REQ_FALL_S =>
               -- When slave side deasserts request, clear ack and valid and start waiting for next
               -- request
               if (mReqs(conv_integer(r.master(m).ackNum)) = '0') then
                  v.master(m).state := M_WAIT_REQ_S;
                  v.master(m).acks  := (others => '0');
                  v.master(m).valid := '0';
               end if;
               
            when others => null;
         end case;
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
