-------------------------------------------------------------------------------
-- File       : SsiAxiLiteMaster.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-09
-- Last update: 2015-05-29
-------------------------------------------------------------------------------
-- Description:
-- Block for Register protocol.
-- Packet is a minimum of 4 x 32-bits
--
-- Incoming Request:
-- Word 0   Data[31:0]  = TID[31:0] (echoed)
--
-- Word 1   Data[29:0]  = Address[31:2] (only 26-bits if EN_32BIT_G = false)
-- Word 1   Data[31:30] = Opcode, 0x0=Read, 0x1=Write, 0x2=Set, 0x3=Clear 
--                        (bit set and bit clear not supported)
-- Word 2   Data[31:0]  = WriteData[31:0] or ReadCount[8:0]
--
-- Word N-1 Data[31:0]  = WriteData[31:0]
--
-- Word N   Data[31:2]  = Don't Care
--
-- Outgoing Response:
-- Word 0   Data[1:0]   = VC (legacy, echoed)
-- Word 0   Data[7:2]   = Dest_ID (legacy, echoed)
-- Word 0   Data[31:8]  = TID[31:0] (legacy, echoed)
--
-- Word 1   Data[29:0]  = Address[31:2]
-- Word 1   Data[31:30] = OpCode, 0x0=Read, 0x1=Write, 0x2=Set, 0x3=Clear
--
-- Word 2   Data[31:0]  = ReadData[31:0]/WriteData[31:0]
--
-- Word N-1 Data[31:0]  = ReadData[31:0]/WriteData[31:0]
--
-- Word N   Data[31:18] = Don't Care
-- Word N   Data[17]    = Timeout Flag (response data)
-- Word N   Data[16]    = Fail Flag (response data)
-- Word N   Data[15:00] = Don't Care
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
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.AxiLitePkg.all;

entity SsiAxiLiteMaster is
   generic (
      -- General Config
      TPD_G : time := 1 ns;

      -- FIFO Config
      RESP_THOLD_G        : integer range 0 to (2**24) := 1;  -- =1 = normal operation
      SLAVE_READY_EN_G    : boolean                    := false;
      EN_32BIT_ADDR_G     : boolean                    := false;
      BRAM_EN_G           : boolean                    := true;
      XIL_DEVICE_G        : string                     := "7SERIES";  --Xilinx only generic parameter    
      USE_BUILT_IN_G      : boolean                    := false;  --if set to true, this module is only Xilinx compatible only!!!
      ALTERA_SYN_G        : boolean                    := false;
      ALTERA_RAM_G        : string                     := "M9K";
      GEN_SYNC_FIFO_G     : boolean                    := false;
      FIFO_ADDR_WIDTH_G   : integer range 4 to 48      := 9;
      FIFO_PAUSE_THRESH_G : integer range 1 to (2**24) := 2**8;

      -- AXI Stream IO Config
      AXI_STREAM_CONFIG_G : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C);
   port (

      -- Streaming Slave (Rx) Interface (sAxisClk domain) 
      sAxisClk    : in  sl;
      sAxisRst    : in  sl := '0';
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;
      sAxisCtrl   : out AxiStreamCtrlType;

      -- Streaming Master (Tx) Data Interface (mAxisClk domain)
      mAxisClk    : in  sl;
      mAxisRst    : in  sl := '0';
      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType;

      -- AXI Lite Bus (axiLiteClk domain)
      axiLiteClk          : in  sl;
      axiLiteRst          : in  sl;
      mAxiLiteWriteMaster : out AxiLiteWriteMasterType;
      mAxiLiteWriteSlave  : in  AxiLiteWriteSlaveType;
      mAxiLiteReadMaster  : out AxiLiteReadMasterType;
      mAxiLiteReadSlave   : in  AxiLiteReadSlaveType
      );

end SsiAxiLiteMaster;

architecture rtl of SsiAxiLiteMaster is

   constant SLAVE_FIFO_SSI_CONFIG_C  : AxiStreamConfigType := ssiAxiStreamConfig(4, TKEEP_COMP_C);
   constant MASTER_FIFO_SSI_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(4, TKEEP_COMP_C);

   signal sFifoAxisMaster : AxiStreamMasterType;
   signal sFifoAxisSlave  : AxiStreamSlaveType;
   signal mFifoAxisMaster : AxiStreamMasterType;
   signal mFifoAxisSlave  : AxiStreamSlaveType;
   signal mFifoAxisCtrl   : AxiStreamCtrlType;

   type StateType is (S_IDLE_C, S_ADDR_C, S_WRITE_C, S_WRITE_AXI_C, S_READ_SIZE_C,
                      S_READ_C, S_READ_AXI_C, S_STATUS_C, S_DUMP_C);

   type RegType is record
      echo    : slv(31 downto 0);
      address : slv(31 downto 0);
      rdSize  : slv(8 downto 0);
      rdCount : slv(8 downto 0);
      timer   : slv(23 downto 0);
      state   : StateType;
      timeout : sl;
      fail    : sl;

      mAxiLiteWriteMaster : AxiLiteWriteMasterType;
      mAxiLiteReadMaster  : AxiLiteReadMasterType;
      sFifoAxisSlave      : AxiStreamSlaveType;
      mFifoAxisMaster     : AxiStreamMasterType;

   end record RegType;

   constant REG_INIT_C : RegType := (
      echo                => (others => '0'),
      address             => (others => '0'),
      rdSize              => (others => '0'),
      rdCount             => (others => '0'),
      timer               => (others => '1'),
      state               => S_IDLE_C,
      timeout             => '0',
      fail                => '0',
      mAxiLiteWriteMaster => AXI_LITE_WRITE_MASTER_INIT_C,
      mAxiLiteReadMaster  => AXI_LITE_READ_MASTER_INIT_C,
      sFifoAxisSlave      => AXI_STREAM_SLAVE_INIT_C,
      mFifoAxisMaster     => AXI_STREAM_MASTER_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- attribute dont_touch                    : string;
   -- attribute dont_touch of r               : signal is "TRUE";
   -- attribute dont_touch of sFifoAxisMaster : signal is "TRUE";
   -- attribute dont_touch of sFifoAxisSlave  : signal is "TRUE";   
   -- attribute dont_touch of mFifoAxisMaster : signal is "TRUE";
   -- attribute dont_touch of mFifoAxisSlave  : signal is "TRUE";
   -- attribute dont_touch of mFifoAxisCtrl   : signal is "TRUE";

begin

   ----------------------------------
   -- Input FIFO 
   ----------------------------------
   SlaveAxiStreamFifo : entity work.AxiStreamFifo
      generic map (
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => 0,
         SLAVE_READY_EN_G    => SLAVE_READY_EN_G,
         BRAM_EN_G           => BRAM_EN_G,
         XIL_DEVICE_G        => XIL_DEVICE_G,
         USE_BUILT_IN_G      => USE_BUILT_IN_G,
         GEN_SYNC_FIFO_G     => GEN_SYNC_FIFO_G,
         ALTERA_SYN_G        => ALTERA_SYN_G,
         ALTERA_RAM_G        => ALTERA_RAM_G,
         CASCADE_SIZE_G      => 1,
         FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_G,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => FIFO_PAUSE_THRESH_G,
         SLAVE_AXI_CONFIG_G  => AXI_STREAM_CONFIG_G,
         MASTER_AXI_CONFIG_G => SLAVE_FIFO_SSI_CONFIG_C)
      port map (
         sAxisClk    => sAxisClk,
         sAxisRst    => sAxisRst,
         sAxisMaster => sAxisMaster,
         sAxisSlave  => sAxisSlave,
         sAxisCtrl   => sAxisCtrl,
         mAxisClk    => axiLiteClk,
         mAxisRst    => axiLiteRst,
         mAxisMaster => sFifoAxisMaster,
         mAxisSlave  => sFifoAxisSlave);



   -------------------------------------
   -- Master State Machine
   -------------------------------------

   comb : process (axiLiteRst, mAxiLiteReadSlave, mAxiLiteWriteSlave, mFifoAxisCtrl, r, sFifoAxisMaster) is
      variable v : RegType;
   begin
      v := r;

      -- Init
      v.mFifoAxisMaster        := sFifoAxisMaster;
      v.mFifoAxisMaster.tUser  := (others => '0');
      v.mFifoAxisMaster.tKeep  := (others => '1');
      v.mFifoAxisMaster.tValid := '0';
      v.mFifoAxisMaster.tLast  := '0';

      v.sFifoAxisSlave.tReady := '0';


      -- State machine
      case r.state is

         -- Idle
         when S_IDLE_C =>
            v.mAxiLiteWriteMaster := AXI_LITE_WRITE_MASTER_INIT_C;
            v.mAxiLiteReadMaster  := AXI_LITE_READ_MASTER_INIT_C;
            v.address             := (others => '0');
            v.rdSize              := (others => '0');
            v.rdCount             := (others => '0');
            v.timeout             := '0';
            v.fail                := '0';

            -- Frame is starting
            if sFifoAxisMaster.tValid = '1' and mFifoAxisCtrl.pause = '0' then
               v.sFifoAxisSlave.tReady := '1';

               -- Bad frame 
               if sFifoAxisMaster.tLast = '0' then
                  v.mFifoAxisMaster.tValid := '1';  -- Echo word 0
                  v.mFifoAxisMaster.tUser  := sFifoAxisMaster.tUser;
                  v.mFifoAxisMaster.tData  := sFifoAxisMaster.tData;
                  v.state                  := S_ADDR_C;
               end if;
            end if;

         -- Address Field
         when S_ADDR_C =>
            v.sFifoAxisSlave.tReady := '1';

            if sFifoAxisMaster.tValid = '1' then

               if EN_32BIT_ADDR_G = true then
                  v.address(31 downto 26) := sFifoAxisMaster.tData(29 downto 24);
               end if;

               v.address(25 downto 2)   := sFifoAxisMaster.tData(23 downto 0);
               v.mFifoAxisMaster.tValid := '1';  -- Echo word 1

               -- Short frame, return error
               if sFifoAxisMaster.tLast = '1' then
                  v.fail  := '1';
                  v.state := S_STATUS_C;

               -- Read
               elsif sFifoAxisMaster.tData(31 downto 30) = "00" then
                  v.state := S_READ_SIZE_C;

               -- Write 
               elsif sFifoAxisMaster.tData(31 downto 30) = "01" then
                  v.state := S_WRITE_C;

               -- Not supported
               else
                  v.fail  := '1';
                  v.state := S_DUMP_C;
               end if;
            end if;

         -- Prepare Write Transaction
         when S_WRITE_C =>
            v.mAxiLiteWriteMaster.awaddr := r.address;
            v.mAxiLiteWriteMaster.awprot := (others => '0');
            v.mAxiLiteWriteMaster.wstrb  := (others => '1');
            v.mAxiLiteWriteMaster.wdata  := sFifoAxisMaster.tData(31 downto 0);
            v.sFifoAxisSlave.tReady      := '1';
            v.timer                      := (others => '1');

            if sFifoAxisMaster.tValid = '1' then
               if sFifoAxisMaster.tLast = '1' then
                  -- check tkeep here
                  if (not axiStreamPacked(SLAVE_FIFO_SSI_CONFIG_C, sFifoAxisMaster)) then
                     v.fail := '1';
                  end if;
                  v.state := S_STATUS_C;
               else
                  v.mFifoAxisMaster.tValid      := '1';  -- Echo write data
                  v.mAxiLiteWriteMaster.awvalid := '1';
                  v.mAxiLiteWriteMaster.wvalid  := '1';
                  v.mAxiLiteWriteMaster.bready  := '1';
                  v.state                       := S_WRITE_AXI_C;
               end if;
            end if;

         -- Write Transaction, AXI
         when S_WRITE_AXI_C =>
            v.timer := r.timer - 1;

            -- Clear control signals on ack
            if mAxiLiteWriteSlave.awready = '1' then
               v.mAxiLiteWriteMaster.awvalid := '0';
            end if;
            if mAxiLiteWriteSlave.wready = '1' then
               v.mAxiLiteWriteMaster.wvalid := '0';
            end if;
            if mAxiLiteWriteSlave.bvalid = '1' then
               v.mAxiLiteWriteMaster.bready := '0';

               if mAxiLiteWriteSlave.bresp /= AXI_RESP_OK_C then
                  v.fail := '1';
               end if;
            end if;

            -- End transaction on timeout
            if r.timer = 0 then
               v.mAxiLiteWriteMaster.awvalid := '0';
               v.mAxiLiteWriteMaster.wvalid  := '0';
               v.mAxiLiteWriteMaster.bready  := '0';
               v.timeout                     := '1';
            end if;

            -- Transaction is done
            if v.mAxiLiteWriteMaster.awvalid = '0' and
               v.mAxiLiteWriteMaster.wvalid = '0' and
               v.mAxiLiteWriteMaster.bready = '0' then

               v.address := r.address + 4;
               v.state   := S_WRITE_C;
            end if;

         -- Read size 
         when S_READ_SIZE_C =>
            v.rdCount := (others => '0');
            v.rdSize  := sFifoAxisMaster.tData(8 downto 0);

            -- Don't read if EOF (need for dump later)
            if sFifoAxisMaster.tValid = '1' then
               v.sFifoAxisSlave.tReady := not sFifoAxisMaster.tLast;
               v.state                 := S_READ_C;
            end if;

         -- Read transaction
         when S_READ_C =>
            v.mAxiLiteReadMaster.araddr := r.address;
            v.mAxiLiteReadMaster.arprot := (others => '0');
            v.timer                     := (others => '1');

            -- Start AXI transaction
            v.mAxiLiteReadMaster.arvalid := '1';
            v.mAxiLiteReadMaster.rready  := '1';
            v.state                      := S_READ_AXI_C;

         -- Read AXI
         when S_READ_AXI_C =>
            v.timer := r.timer - 1;

            -- Clear control signals on ack
            if mAxiLiteReadSlave.arready = '1' then
               v.mAxiLiteReadMaster.arvalid := '0';
            end if;
            if mAxiLiteReadSlave.rvalid = '1' then
               v.mAxiLiteReadMaster.rready          := '0';
               v.mFifoAxisMaster.tData(31 downto 0) := mAxiLiteReadSlave.rdata;

               if mAxiLiteReadSlave.rresp /= AXI_RESP_OK_C then
                  v.fail := '1';
               end if;
            end if;

            -- End transaction on timeout
            if r.timer = 0 then
               v.mAxiLiteReadMaster.arvalid := '0';
               v.mAxiLiteReadMaster.rready  := '0';
               v.timeout                    := '1';
            end if;

            -- Transaction is done
            if v.mAxiLiteReadMaster.arvalid = '0' and v.mAxiLiteReadMaster.rready = '0' then
               v.mFifoAxisMaster.tValid := '1';
               v.address                := r.address + 4;
               v.rdCount                := r.rdCount + 1;

               if r.rdCount = r.rdSize then
                  v.state := S_DUMP_C;
               else
                  v.state := S_READ_C;
               end if;
            end if;

         -- Dump until EOF
         when S_DUMP_C =>
            v.sFifoAxisSlave.tReady := '1';

            if sFifoAxisMaster.tValid = '1' and sFifoAxisMaster.tLast = '1' then
               -- Check tKeep here
               if (not axiStreamPacked(SLAVE_FIFO_SSI_CONFIG_C, sFifoAxisMaster)) then
                  v.fail := '1';
               end if;
               v.state := S_STATUS_C;
            end if;

         -- Send Status
         when S_STATUS_C =>
            v.mFifoAxisMaster.tValid             := '1';
            v.mFifoAxisMaster.tLast              := '1';
            v.mFifoAxisMaster.tData(63 downto 0) := (others => '0');
            v.mFifoAxisMaster.tData(17)          := r.timeout;
            v.mFifoAxisMaster.tData(16)          := r.fail;
            v.state                              := S_IDLE_C;

         when others =>
            v.state := S_IDLE_C;

      end case;

      if (axiLiteRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      mAxiLiteWriteMaster <= r.mAxiLiteWriteMaster;
      mAxiLiteReadMaster  <= r.mAxiLiteReadMaster;
      sFifoAxisSlave      <= v.sFifoAxisSlave;
      mFifoAxisMaster     <= r.mFifoAxisMaster;

   end process comb;

   seq : process (axiLiteClk) is
   begin
      if (rising_edge(axiLiteClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;


   ----------------------------------
   -- Output FIFO 
   ----------------------------------
   MasterAxiStreamFifo : entity work.AxiStreamFifo
      generic map (
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => 0,
         VALID_THOLD_G       => RESP_THOLD_G,
         BRAM_EN_G           => BRAM_EN_G,
         XIL_DEVICE_G        => XIL_DEVICE_G,
         USE_BUILT_IN_G      => USE_BUILT_IN_G,
         GEN_SYNC_FIFO_G     => GEN_SYNC_FIFO_G,
         ALTERA_SYN_G        => ALTERA_SYN_G,
         ALTERA_RAM_G        => ALTERA_RAM_G,
         CASCADE_SIZE_G      => 1,
         FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_G,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => FIFO_PAUSE_THRESH_G,
         SLAVE_AXI_CONFIG_G  => ssiAxiStreamConfig(4, TKEEP_COMP_C),
         MASTER_AXI_CONFIG_G => AXI_STREAM_CONFIG_G)
      port map (
         sAxisClk    => axiLiteClk,
         sAxisRst    => axiLiteRst,
         sAxisMaster => mFifoAxisMaster,
         sAxisSlave  => mFifoAxisSlave,
         sAxisCtrl   => mFifoAxisCtrl,
         mAxisClk    => mAxisClk,
         mAxisRst    => mAxisRst,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);

end rtl;

