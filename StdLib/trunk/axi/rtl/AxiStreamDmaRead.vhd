-------------------------------------------------------------------------------
-- Title      : AXI Stream DMA Read
-- Project    : General Purpose Core
-------------------------------------------------------------------------------
-- File       : AxiStreamDmaRead.vhd
-- Author     : Ryan Herbst, rherbst@slac.stanford.edu
-- Created    : 2014-04-25
-- Last update: 2014-05-05
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-- Block to transfer a single AXI Stream frame from memory using an AXI
-- interface.
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
use work.AxiStreamPkg.all;
use work.AxiPkg.all;
use work.AxiDmaPkg.all;

entity AxiStreamDmaRead is
   generic (
      TPD_G            : time                := 1 ns;
      AXIS_READY_EN_G  : boolean             := false;
      AXIS_CONFIG_G    : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C;
      AXI_CONFIG_G     : AxiConfigType       := AXI_CONFIG_INIT_C;
      AXI_BURST_G      : slv(1 downto 0)     := "01";
      AXI_CACHE_G      : slv(3 downto 0)     := "1111";
      AXI_ALIGN_G      : boolean             := true
   );
   port (

      -- Clock/Reset
      axiClk          : in  sl;
      axiRst          : in  sl;

      -- DMA Control Interface 
      dmaReq          : in  AxiReadDmaReqType;
      dmaAck          : out AxiReadDmaAckType;

      -- Streaming Interface 
      axisMaster      : out AxiStreamMasterType;
      axisSlave       : in  AxiStreamSlaveType;
      axisCtrl        : in  AxiStreamCtrlType;

      -- AXI Interface
      axiReadMaster   : out AxiReadMasterType;
      axiReadSlave    : in  AxiReadSlaveType
   );
end AxiStreamDmaRead;

architecture structure of AxiStreamDmaRead is

   constant DATA_BYTES_C : integer := ite(AXIS_CONFIG_G.TDATA_BYTES_C < AXI_CONFIG_G.DATA_BYTES_C,
                                          AXIS_CONFIG_G.TDATA_BYTES_C,
                                          AXI_CONFIG_G.DATA_BYTES_C);

   type StateType is (S_IDLE_C, S_SHIFT_C, S_FIRST_C, S_NEXT_C, S_DATA_C, S_LAST_C, S_DONE_C);

   type RegType is record
      state    : StateType;
      dmaReq   : AxiReadDmaReqType;
      dmaAck   : AxiReadDmaAckType;
      shift    : slv(3 downto 0);
      shiftEn  : sl;
      first    : sl;
      last     : sl;
      rMaster  : AxiReadMasterType;
      sMaster  : AxiStreamMasterType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state    => S_IDLE_C,
      dmaReq   => AXI_READ_DMA_REQ_INIT_C,
      dmaAck   => AXI_READ_DMA_ACK_INIT_C,
      shift    => (others=>'0'),
      shiftEn  => '0',
      first    => '0',
      last     => '0',
      rMaster  => AXI_READ_MASTER_INIT_C,
      sMaster  => AXI_STREAM_MASTER_INIT_C
      );

   signal r             : RegType := REG_INIT_C;
   signal rin           : RegType;
   signal selReady      : sl;
   signal selPause      : sl;
   signal intAxisMaster : AxiStreamMasterType;
   signal intAxisSlave  : AxiStreamSlaveType;

begin

   -- Determine handshaking mode
   selReady <= axisSlave.tReady when AXIS_READY_EN_G else '1';
   selPause <= '0'              when AXIS_READY_EN_G else axisCtrl.pause;

   comb : process (axiRst, r, intAxisSlave, axiReadSlave, dmaReq, selReady, selPause ) is
      variable v     : RegType;
   begin
      v := r;

      -- Init
      v.rMaster.arvalid := '0';
      v.rMaster.rready  := '0';
      v.shiftEn         := '0';

      -- Track read status
      if axiReadSlave.rvalid = '1' and axiReadSlave.rresp /= 0 then
         v.dmaAck.readError := '1';
      end if;

      -- State machine
      case r.state is

         -- IDLE
         when S_IDLE_C =>
            v.rMaster  := AXI_READ_MASTER_INIT_C;
            v.sMaster  := AXI_STREAM_MASTER_INIT_C;
            v.shift    := (others=>'0');
            v.last     := '0';

            v.dmaAck                     := AXI_READ_DMA_ACK_INIT_C;
            v.dmaReq                     := dmaReq;
            v.dmaReq.address(2 downto 0) := "000";

            if AXI_ALIGN_G then
               v.shift := '0' & dmaReq.address(2 downto 0);
            end if;

            -- Start 
            if dmaReq.request = '1' then
               v.shiftEn := '1';
               v.state   := S_FIRST_C;
            end if;

         -- First
         when S_FIRST_C =>
            v.first := '1';

            -- Determine transfer size to align all transfers to 128 byte boundaries
            -- This initial alignment will ensure that we never cross a 4k boundary
            v.rMaster.araddr := r.dmaReq.address;
            v.rMaster.arlen  := x"F" - r.dmaReq.address(6 downto 3);

            -- There is enough room in the FIFO for a burst and address is ready
            if selPause = '0' and axiReadSlave.arready = '1' then
               v.rMaster.arvalid := '1';
               v.state           := S_DATA_C;
            end if;

         -- Next Write
         when S_NEXT_C =>
            v.rMaster.araddr := r.dmaReq.address;
            v.rMaster.arlen  := x"F";

            -- There is enough room in the FIFO for a burst and address is ready
            if selPause = '0' and axiReadSlave.arready = '1' then
               v.rMaster.arvalid := '1';
               v.state           := S_DATA_C;
            end if;
             
         -- Move Data
         when S_DATA_C =>

            -- Assert ready when incoming is ready or we are done
            v.rMaster.rready := intAxisSlave.tReady or r.last;

            -- Advance pipeline when incoming data is valid and outbound is ready
            -- or we have not yet asserted valid. Always shift after we have read full frame
            if r.last = '1' or (axiReadSlave.rvalid = '1' and (selReady = '1' or r.sMaster.tValid = '0')) then
               v.sMaster.tUser  := (others=>'0');
               v.sMaster.tStrb  := (others=>'1');
               v.sMaster.tKeep  := (others=>'1');
               v.sMaster.tLast  := '0';
               v.sMaster.tDest  := r.dmaReq.dest;
               v.sMaster.tId    := r.dmareq.id;

               -- If we have already sent out last value, clear valid when ready is asserted
               if r.last = '1' then
                  if selReady = '1' then
                     v.sMaster.tValid := '0';
                  end if;
               else
                  v.sMaster.tValid := axiReadSlave.rvalid;
               end if;

               -- Setup data
               v.sMaster.tData((DATA_BYTES_C*8)-1 downto 0) := axiReadSlave.rdata((DATA_BYTES_C*8)-1 downto 0);

               -- Address
               v.dmaReq.address := r.dmaReq.address + 8;

               -- First transfer, set user field
               if r.first = '1' then
                  axiStreamSetUserField (AXIS_CONFIG_G,v.sMaster,r.dmaReq.firstUser(AXIS_CONFIG_G.TUSER_BITS_C-1 downto 0),
                                         conv_integer(r.shift));
               end if;
               v.first := '0';

               -- Last transfer
               if r.dmaReq.size < 8  then
                  v.last          := '1';
                  v.sMaster.tLast := '1';

                  -- Clear unused keep bits
                  if r.shift /= 0 then
                     v.sMaster.tKeep(conv_integer(r.shift)-1 downto 0) := (others=>'0');
                  end if;

                  -- Set user field, last position
                  axiStreamSetUserField (AXIS_CONFIG_G,v.sMaster,r.dmaReq.lastUser(AXIS_CONFIG_G.TUSER_BITS_C-1 downto 0));

               else
                  v.dmaReq.size := r.dmaReq.size - ite(r.first='1',(x"8"-r.shift),x"8");
               end if;

               -- Last in transfer
               if r.rMaster.arlen = 0 then
                  v.state := S_LAST_C;
               else
                  v.rMaster.arlen := r.rMaster.arlen - 1;
               end if;
            end if;

         -- Last Trasfer Of A Burst Data
         when S_LAST_C =>
            if selReady = '1' or r.sMaster.tValid = '0' then
               if r.last = '1' then
                  v.state := S_DONE_C;
               else
                  v.state := S_NEXT_C;
               end if;
               v.sMaster.tValid := '0';
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

      -- Constants
      v.rMaster.arsize  := conv_std_logic_vector(AXI_CONFIG_G.DATA_BYTES_C-1,3);
      v.rMaster.arburst := AXI_BURST_G;
      v.rMaster.arcache := AXI_CACHE_G;
      v.rMaster.arlock  := "00";   -- Unused
      v.rMaster.arprot  := "000";  -- Unused
      v.rMaster.arid    := (others=>'0');

      rin <= v;

      dmaAck        <= r.dmaAck;
      intAxisMaster <= v.sMaster;
      axiReadMaster <= r.rMaster;

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

