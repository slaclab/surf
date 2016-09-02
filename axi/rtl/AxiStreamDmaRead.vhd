-------------------------------------------------------------------------------
-- Title      : AXI Stream DMA Read
-- Project    : General Purpose Core
-------------------------------------------------------------------------------
-- File       : AxiStreamDmaRead.vhd
-- Author     : Ryan Herbst, rherbst@slac.stanford.edu
-- Created    : 2014-04-25
-- Last update: 2016-05-04
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-- Block to transfer a single AXI Stream frame from memory using an AXI
-- interface.
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
-- Modification history:
-- 04/25/2014: created.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.AxiPkg.all;
use work.AxiDmaPkg.all;

entity AxiStreamDmaRead is
   generic (
      TPD_G           : time                       := 1 ns;
      AXIS_READY_EN_G : boolean                    := false;
      AXIS_CONFIG_G   : AxiStreamConfigType        := AXI_STREAM_CONFIG_INIT_C;
      AXI_CONFIG_G    : AxiConfigType              := AXI_CONFIG_INIT_C;
      AXI_BURST_G     : slv(1 downto 0)            := "01";
      AXI_CACHE_G     : slv(3 downto 0)            := "1111";
      MAX_PEND_G      : integer range 0 to (2**24) := 0
      );
   port (

      -- Clock/Reset
      axiClk : in sl;
      axiRst : in sl;

      -- DMA Control Interface 
      dmaReq : in  AxiReadDmaReqType;
      dmaAck : out AxiReadDmaAckType;

      -- Streaming Interface 
      axisMaster : out AxiStreamMasterType;
      axisSlave  : in  AxiStreamSlaveType;
      axisCtrl   : in  AxiStreamCtrlType;

      -- AXI Interface
      axiReadMaster : out AxiReadMasterType;
      axiReadSlave  : in  AxiReadSlaveType
      );
end AxiStreamDmaRead;

architecture structure of AxiStreamDmaRead is

   constant DATA_BYTES_C : integer         := AXIS_CONFIG_G.TDATA_BYTES_C;
   constant ADDR_LSB_C   : integer         := bitSize(DATA_BYTES_C-1);
   constant ARLEN_C      : slv(7 downto 0) := getAxiLen(AXI_CONFIG_G, 4096);

   type StateType is (S_IDLE_C, S_SHIFT_C, S_FIRST_C, S_NEXT_C, S_DATA_C, S_LAST_C, S_DONE_C);

   type RegType is record
      state   : StateType;
      dmaReq  : AxiReadDmaReqType;
      dmaAck  : AxiReadDmaAckType;
      shift   : slv(3 downto 0);
      shiftEn : sl;
      first   : sl;
      last    : sl;
      rMaster : AxiReadMasterType;
      sMaster : AxiStreamMasterType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state   => S_IDLE_C,
      dmaReq  => AXI_READ_DMA_REQ_INIT_C,
      dmaAck  => AXI_READ_DMA_ACK_INIT_C,
      shift   => (others => '0'),
      shiftEn => '0',
      first   => '0',
      last    => '0',
      rMaster => axiReadMasterInit(AXI_CONFIG_G, AXI_BURST_G, AXI_CACHE_G),
      sMaster => axiStreamMasterInit(AXIS_CONFIG_G));

   signal r             : RegType := REG_INIT_C;
   signal rin           : RegType;
   signal selReady      : sl;
   signal selPause      : sl;
   signal intAxisMaster : AxiStreamMasterType;
   signal intAxisSlave  : AxiStreamSlaveType;

   signal rDataDebug : slv(AXI_CONFIG_G.DATA_BYTES_C*8-1 downto 0);

begin

   rDataDebug <= axiReadSlave.rdata(AXI_CONFIG_G.DATA_BYTES_C*8-1 downto 0);

   assert AXIS_CONFIG_G.TDATA_BYTES_C = AXI_CONFIG_G.DATA_BYTES_C
      report "AXIS (" & integer'image(AXIS_CONFIG_G.TDATA_BYTES_C) & ") and AXI ("
      & integer'image(AXI_CONFIG_G.DATA_BYTES_C) & ") must have equal data widths" severity failure;

   -- Determine handshaking mode
   selReady <= intAxisSlave.tReady when AXIS_READY_EN_G else '1';
   selPause <= '0'                 when AXIS_READY_EN_G else axisCtrl.pause;

   comb : process (axiRst, r, intAxisSlave, axiReadSlave, dmaReq, selReady, selPause) is
      variable v        : RegType;
      variable readSize : integer;
   begin
      v := r;

      -- Init
      v.rMaster.arvalid := '0';
      v.rMaster.rready  := '0';
      v.shiftEn         := '0';

      -- Track read status
      if axiReadSlave.rvalid = '1' and axiReadSlave.rresp /= 0 and axiReadSlave.rlast = '1' then
         v.dmaAck.readError  := '1';
         v.dmaAck.errorValue := axiReadSlave.rresp;
      end if;

      -- State machine
      case r.state is

         -- IDLE
         when S_IDLE_C =>
            v.rMaster := axiReadMasterInit(AXI_CONFIG_G, AXI_BURST_G, AXI_CACHE_G);
            v.sMaster := axiStreamMasterInit(AXIS_CONFIG_G);
            v.last    := '0';
            v.dmaAck  := AXI_READ_DMA_ACK_INIT_C;
            v.dmaReq  := dmaReq;
            v.shift   := (others => '0');

            -- Align shift and address to transfer size
            if DATA_BYTES_C /= 1 then
               v.dmaReq.address(ADDR_LSB_C-1 downto 0) := (others => '0');
               v.shift(ADDR_LSB_C-1 downto 0)          := dmaReq.address(ADDR_LSB_C-1 downto 0);
            end if;

            -- Start 
            if dmaReq.request = '1' then
               v.shiftEn := '1';
               v.state   := S_FIRST_C;
            end if;

         -- First
         when S_FIRST_C =>
            v.first                                                := '1';
            v.rMaster.araddr(AXI_CONFIG_G.ADDR_WIDTH_C-1 downto 0) := r.dmaReq.address(AXI_CONFIG_G.ADDR_WIDTH_C-1 downto 0);

            -- Determine transfer size to align address to 16-transfer boundaries
            -- This initial alignment will ensure that we never cross a 4k boundary
            if (ARLEN_C > 0) then
               v.rMaster.arlen := ARLEN_C - r.dmaReq.address(ADDR_LSB_C+AXI_CONFIG_G.LEN_BITS_C-1 downto ADDR_LSB_C);

               -- Limit read burst size
               if r.dmaReq.size(31 downto ADDR_LSB_C) < v.rMaster.arlen then
                  v.rMaster.arlen := resize(r.dmaReq.size(ADDR_LSB_C+AXI_CONFIG_G.LEN_BITS_C-1 downto ADDR_LSB_C)-1, 8);
               end if;
            end if;

            -- There is enough room in the FIFO for a burst
            if selPause = '0' then
               v.rMaster.arvalid := '1';
               v.state           := S_DATA_C;
            end if;

         -- Next Write
         when S_NEXT_C =>
            v.rMaster.araddr(AXI_CONFIG_G.ADDR_WIDTH_C-1 downto 0) := r.dmaReq.address(AXI_CONFIG_G.ADDR_WIDTH_C-1 downto 0);

            -- Bursts after the FIRST are garunteed to be aligned.
            v.rMaster.arlen := ARLEN_C;
            if r.dmaReq.size(31 downto ADDR_LSB_C) < v.rMaster.arlen then
               v.rMaster.arlen := resize(r.dmaReq.size(ADDR_LSB_C+AXI_CONFIG_G.LEN_BITS_C-1 downto ADDR_LSB_C)-1, 8);
            end if;

            -- There is enough room in the FIFO for a burst and address is ready
            if selPause = '0' then
               v.rMaster.arvalid := '1';
               v.state           := S_DATA_C;
            end if;

         -- Move Data
         when S_DATA_C =>
            v.rMaster.arvalid := r.rMaster.arvalid;
            if axiReadSlave.arready = '1' then
               v.rMaster.arvalid := '0';
            end if;

            -- Ready and valid
            if selReady = '1' or r.sMaster.tValid = '0' then
               v.sMaster.tValid := axiReadSlave.rvalid and (not r.last);
               v.rMaster.rready := '1';
            else
               v.rMaster.rready := '0';
            end if;

            -- Advance pipeline
            if (selReady = '1' or r.last = '1' or r.sMaster.tValid = '0') and axiReadSlave.rvalid = '1' then
               v.sMaster.tUser := (others => '0');
               v.sMaster.tStrb := (others => '1');
               v.sMaster.tKeep := (others => '1');
               v.sMaster.tDest := r.dmaReq.dest;
               v.sMaster.tId   := r.dmareq.id;
               v.first         := '0';

               -- Setup data
               v.sMaster.tData((DATA_BYTES_C*8)-1 downto 0) := axiReadSlave.rdata((DATA_BYTES_C*8)-1 downto 0);

               -- Address
               v.dmaReq.address := r.dmaReq.address + DATA_BYTES_C;
               v.dmaReq.address(ADDR_LSB_C-1 downto 0) := (others => '0');

               -- First transfer, set user field
               if r.first = '1' then
                  axiStreamSetUserField (AXIS_CONFIG_G,
                                         v.sMaster,
                                         r.dmaReq.firstUser(AXIS_CONFIG_G.TUSER_BITS_C-1 downto 0),
                                         conv_integer(r.shift));
               end if;

               -- Subtract the read size
               -- Bottom out at 0
               readSize := DATA_BYTES_C - ite(r.first = '1', conv_integer(r.shift), 0);
               if (readSize > r.dmaReq.size) then
                  v.dmaReq.size := (others => '0');
               else
                  v.dmaReq.size := r.dmaReq.size - readSize;
               end if;

               -- Know it is last when size is about to bottom out
               if (v.dmaReq.size = 0) then
                  v.last          := '1';
                  v.sMaster.tLast := '1';
                  v.sMaster.tKeep := genTKeep(conv_integer(r.dmaReq.size(4 downto 0)));
                  v.sMaster.tStrb := genTKeep(conv_integer(r.dmaReq.size(4 downto 0)));

                  if (r.first = '1') then
                     v.sMaster.tKeep := shl(v.sMaster.tKeep, r.shift);
                     v.sMaster.tStrb := shl(v.sMaster.tStrb, r.shift);

                     -- This probably generates a crazy long logic chain
                     -- For 1 byte read, lastUser will overwrite firstUser.
                     axiStreamSetUserField (AXIS_CONFIG_G,
                                            v.sMaster,
                                            r.dmaReq.lastUser(AXIS_CONFIG_G.TUSER_BITS_C-1 downto 0),
                                            conv_integer(r.shift + r.dmaReq.size -1));

                  else
                     -- Set user field, last position
                     axiStreamSetUserField (AXIS_CONFIG_G,
                                            v.sMaster,
                                            r.dmaReq.lastUser(AXIS_CONFIG_G.TUSER_BITS_C-1 downto 0));
                  end if;
               end if;

               -- Last in transfer
               if axiReadSlave.rlast = '1' then
                  v.state := S_LAST_C;
               end if;
            end if;

         -- Last Trasfer Of A Burst Data
         when S_LAST_C =>
            if selReady = '1' or r.sMaster.tValid = '0' then
               if r.last = '1' then
                  v.state       := S_DONE_C;
                  v.dmaAck.done := '1';
               else
                  v.state := S_NEXT_C;
               end if;
               v.sMaster.tValid := '0';
               v.sMaster.tLast  := '0';
            end if;

         -- Done
         when S_DONE_C =>
            if dmaReq.request = '0' then
               v.dmaAck.done := '0';
               v.state       := S_IDLE_C;
            end if;

         when others =>
            v.state := S_IDLE_C;
      end case;

      if (axiRst = '1') then
         v := REG_INIT_C;
      end if;


      -- Always accept data when outbound ready is ignored
      if AXIS_READY_EN_G = false then
         v.rMaster.rready := '1';
      end if;

      rin <= v;

      dmaAck               <= r.dmaAck;
      intAxisMaster        <= r.sMaster;
      axiReadMaster        <= r.rMaster;
      axiReadMaster.rready <= v.rMaster.rready;

   end process comb;

   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;


   -- Stream Shifter
   U_AxiStreamShift : entity work.AxiStreamShift
      generic map (
         TPD_G         => TPD_G,
         AXIS_CONFIG_G => AXIS_CONFIG_G
         ) port map (
            axisClk     => axiClk,
            axisRst     => axiRst,
            axiStart    => r.shiftEn,
            axiShiftDir => '1',
            axiShiftCnt => r.shift,
            sAxisMaster => intAxisMaster,
            sAxisSlave  => intAxisSlave,
            mAxisMaster => axisMaster,
            mAxisSlave  => axisSlave
            );

end structure;

