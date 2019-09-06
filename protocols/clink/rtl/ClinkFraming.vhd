-------------------------------------------------------------------------------
-- File       : ClinkFraming.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- CameraLink framing module
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
use work.ClinkPkg.all;

entity ClinkFraming is
   generic (
      TPD_G              : time                := 1 ns;
      COMMON_DATA_CLK_G  : boolean             := false;  -- true if dataClk=sysClk
      DATA_AXIS_CONFIG_G : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C);
   port (
      -- System clock and reset
      sysClk     : in  sl;
      sysRst     : in  sl;
      -- Config and status
      chanConfig : in  ClChanConfigType;
      chanStatus : out ClChanStatusType;
      linkStatus : in  ClLinkStatusArray(2 downto 0);
      -- Data interface
      parData    : in  Slv28Array(2 downto 0);
      parValid   : in  slv(2 downto 0);
      parReady   : out sl;
      -- Camera data
      dataClk    : in  sl;
      dataRst    : in  sl;
      dataMaster : out AxiStreamMasterType;
      dataSlave  : in  AxiStreamSlaveType);
end ClinkFraming;

architecture rtl of ClinkFraming is

   constant SLV_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(dataBytes => 10, tDestBits => 0);
   constant MST_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(dataBytes => 16, tDestBits => 0);

   type RegType is record
      ready    : sl;
      portData : ClDataType;
      byteData : ClDataType;
      bytes    : integer range 1 to 10;
      inFrame  : sl;
      dump     : sl;
      status   : ClChanStatusType;
      master   : AxiStreamMasterType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      ready    => '1',
      portData => CL_DATA_INIT_C,
      byteData => CL_DATA_INIT_C,
      bytes    => 1,
      inFrame  => '0',
      dump     => '0',
      status   => CL_CHAN_STATUS_INIT_C,
      master   => AXI_STREAM_MASTER_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal intCtrl    : AxiStreamCtrlType;
   signal packMaster : AxiStreamMasterType;

   -- attribute MARK_DEBUG : string;
   -- attribute MARK_DEBUG of r          : signal is "TRUE";
   -- attribute MARK_DEBUG of parData    : signal is "TRUE";
   -- attribute MARK_DEBUG of parValid   : signal is "TRUE";
   -- attribute MARK_DEBUG of parReady   : signal is "TRUE";
   -- attribute MARK_DEBUG of intCtrl    : signal is "TRUE";
   -- attribute MARK_DEBUG of packMaster : signal is "TRUE";

begin

   comb : process (chanConfig, intCtrl, linkStatus, parData, parValid, r,
                   sysRst) is
      variable v : RegType;
   begin
      v := r;

      ---------------------------------
      -- Map parrallel data to ports
      -- Taken from cameraLink spec V2.0
      ---------------------------------
      v.status.running := '0';
      v.portData       := CL_DATA_INIT_C;

      -- DECA Mode
      if chanConfig.linkMode = CLM_DECA_C then

         v.status.running := linkStatus(0).locked and linkStatus(1).locked and linkStatus(2).locked;
         v.portData.valid := uAnd(parValid) and v.status.running;
         v.portData.dv    := '1';
         v.portData.fv    := parData(0)(25);

         -- 8-bit, cameraLink spec V2.0, page 16
         if chanConfig.dataMode = CDM_8BIT_C then
            v.portData.lv                  := parData(0)(24) and parData(1)(27) and parData(2)(27);
            v.portData.data(0)             := parData(0)(7 downto 0);
            v.portData.data(1)             := parData(0)(15 downto 8);
            v.portData.data(2)             := parData(0)(23 downto 16);
            v.portData.data(3)(1 downto 0) := parData(0)(27 downto 26);
            v.portData.data(3)(7 downto 2) := parData(1)(5 downto 0);
            v.portData.data(4)             := parData(1)(13 downto 6);
            v.portData.data(5)             := parData(1)(21 downto 14);
            v.portData.data(6)(4 downto 0) := parData(1)(26 downto 22);
            v.portData.data(6)(7 downto 5) := parData(2)(2 downto 0);
            v.portData.data(7)             := parData(2)(10 downto 3);
            v.portData.data(8)             := parData(2)(18 downto 11);
            v.portData.data(9)             := parData(2)(26 downto 19);

         -- 10-bit, cameraLink spec V2.0, page 17
         elsif chanConfig.dataMode = CDM_10BIT_C then
            v.portData.lv                  := parData(0)(24) and parData(1)(24) and parData(2)(24);
            v.portData.data(0)(4 downto 0) := parData(0)(4 downto 0);
            v.portData.data(0)(5)          := parData(0)(6);
            v.portData.data(0)(6)          := parData(0)(27);
            v.portData.data(0)(7)          := parData(0)(5);
            v.portData.data(1)(2 downto 0) := parData(0)(9 downto 7);
            v.portData.data(1)(5 downto 3) := parData(0)(14 downto 12);
            v.portData.data(1)(7 downto 6) := parData(0)(11 downto 10);
            v.portData.data(2)(0)          := parData(0)(15);
            v.portData.data(2)(5 downto 1) := parData(0)(22 downto 18);
            v.portData.data(2)(7 downto 6) := parData(0)(17 downto 16);
            v.portData.data(3)(4 downto 0) := parData(1)(4 downto 0);
            v.portData.data(3)(5)          := parData(1)(6);
            v.portData.data(3)(6)          := parData(1)(27);
            v.portData.data(3)(7)          := parData(1)(5);
            v.portData.data(4)(2 downto 0) := parData(1)(9 downto 7);
            v.portData.data(4)(5 downto 3) := parData(1)(14 downto 12);
            v.portData.data(4)(7 downto 6) := parData(1)(11 downto 10);
            v.portData.data(5)(0)          := parData(1)(15);
            v.portData.data(5)(5 downto 1) := parData(1)(22 downto 18);
            v.portData.data(5)(7 downto 6) := parData(1)(17 downto 16);
            v.portData.data(6)(4 downto 0) := parData(2)(4 downto 0);
            v.portData.data(6)(5)          := parData(2)(6);
            v.portData.data(6)(6)          := parData(2)(27);
            v.portData.data(6)(7)          := parData(2)(5);
            v.portData.data(7)(2 downto 0) := parData(2)(9 downto 7);
            v.portData.data(7)(5 downto 3) := parData(2)(14 downto 12);
            v.portData.data(7)(7 downto 6) := parData(2)(11 downto 10);
            v.portData.data(8)(0)          := parData(0)(26);
            v.portData.data(8)(1)          := parData(0)(23);
            v.portData.data(8)(3 downto 2) := parData(1)(26 downto 25);
            v.portData.data(8)(4)          := parData(1)(23);
            v.portData.data(8)(5)          := parData(2)(15);
            v.portData.data(8)(7 downto 6) := parData(2)(19 downto 18);
            v.portData.data(9)(2 downto 0) := parData(2)(22 downto 20);
            v.portData.data(9)(4 downto 3) := parData(2)(17 downto 16);
            v.portData.data(9)(6 downto 5) := parData(2)(26 downto 25);
            v.portData.data(9)(7)          := parData(2)(23);
         end if;

      -- Base, Medium, Full Modes
      else

         -- Base, Medium, Full, cameraLink spec V2.0 page 15
         v.portData.data(0)(4 downto 0) := parData(0)(4 downto 0);
         v.portData.data(0)(5)          := parData(0)(6);
         v.portData.data(0)(6)          := parData(0)(27);
         v.portData.data(0)(7)          := parData(0)(5);
         v.portData.data(1)(2 downto 0) := parData(0)(9 downto 7);
         v.portData.data(1)(5 downto 3) := parData(0)(14 downto 12);
         v.portData.data(1)(7 downto 6) := parData(0)(11 downto 10);
         v.portData.data(2)(0)          := parData(0)(15);
         v.portData.data(2)(5 downto 1) := parData(0)(22 downto 18);
         v.portData.data(2)(7 downto 6) := parData(0)(17 downto 16);

         -- Medium, Full, cameraLink spec V2.0 pages 15
         v.portData.data(3)(4 downto 0) := parData(1)(4 downto 0);
         v.portData.data(3)(5)          := parData(1)(6);
         v.portData.data(3)(6)          := parData(1)(27);
         v.portData.data(3)(7)          := parData(1)(5);
         v.portData.data(4)(2 downto 0) := parData(1)(9 downto 7);
         v.portData.data(4)(5 downto 3) := parData(1)(14 downto 12);
         v.portData.data(4)(7 downto 6) := parData(1)(11 downto 10);
         v.portData.data(5)(0)          := parData(1)(15);
         v.portData.data(5)(5 downto 1) := parData(1)(22 downto 18);
         v.portData.data(5)(7 downto 6) := parData(1)(17 downto 16);

         -- Full, cameraLink spec V2.0 page 15
         v.portData.data(6)(4 downto 0) := parData(2)(4 downto 0);
         v.portData.data(6)(5)          := parData(2)(6);
         v.portData.data(6)(6)          := parData(2)(27);
         v.portData.data(6)(7)          := parData(2)(5);
         v.portData.data(7)(2 downto 0) := parData(2)(9 downto 7);
         v.portData.data(7)(5 downto 3) := parData(2)(14 downto 12);
         v.portData.data(7)(7 downto 6) := parData(2)(11 downto 10);
         v.portData.data(8)(0)          := parData(2)(15);
         v.portData.data(8)(5 downto 1) := parData(2)(22 downto 18);
         v.portData.data(8)(7 downto 6) := parData(2)(17 downto 16);

         -- Determine valids based upon modes
         case chanConfig.linkMode is

            -- Base mode, 24 bits, cameraLink spec V2.0 page 15
            when CLM_BASE_C =>
               v.status.running := linkStatus(0).locked;
               v.portData.valid := parValid(0) and v.status.running;
               v.portData.dv    := parData(0)(26);
               v.portData.fv    := parData(0)(25);
               v.portData.lv    := parData(0)(24);

            -- Medium mode, 48 bits, cameraLink spec V2.0 page 15
            when CLM_MEDM_C =>
               v.status.running := linkStatus(0).locked and linkStatus(1).locked;
               v.portData.valid := uAnd(parValid(1 downto 0)) and v.status.running;
               v.portData.dv    := parData(0)(26) and parData(1)(26);
               v.portData.fv    := parData(0)(25) and parData(1)(25);
               v.portData.lv    := parData(0)(24) and parData(1)(24);

            -- Full mode, 64 bits, cameraLink spec V2.0 page 15
            when CLM_FULL_C =>
               v.status.running := linkStatus(0).locked and linkStatus(1).locked and linkStatus(2).locked;
               v.portData.valid := uAnd(parValid) and v.status.running;
               v.portData.dv    := parData(0)(26) and parData(1)(26) and parData(2)(26);
               v.portData.fv    := parData(0)(25) and parData(1)(25) and parData(2)(25);
               v.portData.lv    := parData(0)(24) and parData(1)(24) and parData(2)(24);

            when others =>
         end case;
      end if;

      -- Drive ready, dump when not running
      v.ready := v.portData.valid or (not r.status.running);

      ---------------------------------
      -- Map data bytes
      ---------------------------------

      -- Move only when portData is valid
      if r.portData.valid = '1' then
         v.byteData      := r.portData;
         v.byteData.data := (others => (others => '0'));
         v.bytes         := 1;

         -- Data mode
         case chanConfig.dataMode is

            -- 8 bits, base, medium, full & deca
            when CDM_8BIT_C =>
               v.byteData := r.portData;
               v.bytes    := conv_integer(chanConfig.tapCount);

            -- 10 bits, base, medium, full & deca, cameraLink spec V2.0 pages 19-28
            when CDM_10BIT_C =>
               if chanConfig.linkMode = CLM_DECA_C then
                  v.byteData := r.portData;
                  v.bytes    := 10;
               else
                  v.byteData.data(0)             := r.portData.data(0);  -- T1, DA[07:00]
                  v.byteData.data(1)(1 downto 0) := r.portData.data(1)(1 downto 0);  -- T1, DA[09:08]
                  v.byteData.data(2)             := r.portData.data(2);  -- T2, DB[07:00]
                  v.byteData.data(3)(1 downto 0) := r.portData.data(1)(5 downto 4);  -- T2, DB[09:08]
                  v.byteData.data(4)             := r.portData.data(4);  -- T3, DC[07:00]
                  v.byteData.data(5)(1 downto 0) := r.portData.data(5)(1 downto 0);  -- T3, DC[09:08]
                  v.byteData.data(6)             := r.portData.data(3);  -- T4, DD[07:00]
                  v.byteData.data(7)(1 downto 0) := r.portData.data(5)(5 downto 4);  -- T4, DD[09:08]

                  v.bytes := conv_integer(chanConfig.tapCount & "0");  -- tapCount * 2
               end if;

            -- 12 bits, base and medium, cameraLink spec V2.0 pages 19-20
            when CDM_12BIT_C =>
               v.byteData.data(0)             := r.portData.data(0);  -- T1, DA[07:00]
               v.byteData.data(1)(3 downto 0) := r.portData.data(1)(3 downto 0);  -- T1, DA[11:08]
               v.byteData.data(2)             := r.portData.data(2);  -- T2, DB[07:00]
               v.byteData.data(3)(3 downto 0) := r.portData.data(1)(7 downto 4);  -- T2, DB[11:08]
               v.byteData.data(4)             := r.portData.data(4);  -- T3, DC[07:00]
               v.byteData.data(5)(3 downto 0) := r.portData.data(5)(3 downto 0);  -- T3, DC[11:08]
               v.byteData.data(6)             := r.portData.data(3);  -- T4, DD[07:00]
               v.byteData.data(7)(3 downto 0) := r.portData.data(5)(7 downto 4);  -- T4, DD[11:08]

               v.bytes := conv_integer(chanConfig.tapCount & "0");  -- tapCount * 2

            -- 14 bits, base, cameraLink spec V2.0 page 19
            when CDM_14BIT_C =>
               v.byteData.data(0)             := r.portData.data(0);  -- T1, DA[07:00]
               v.byteData.data(1)(5 downto 0) := r.portData.data(1)(5 downto 0);  -- T1, DA[13:08]
               v.bytes                        := 2;

            -- 16 bits, base, cameraLink spec V2.0 page 19
            when CDM_16BIT_C =>
               v.byteData.data(0) := r.portData.data(0);  -- T1, DA[07:00]
               v.byteData.data(1) := r.portData.data(1);  -- T1, DA[15:08]
               v.bytes            := 2;

            -- 24 bits, base, cameraLink spec V2.0 page 19
            when CDM_24BIT_C =>
               v.byteData.data(0) := r.portData.data(0);  -- T1, DR[07:00]
               v.byteData.data(1) := r.portData.data(1);  -- T2, DG[07:08]
               v.byteData.data(2) := r.portData.data(2);  -- T3, DB[07:08]
               v.bytes            := 3;

            -- 30 bits, medium, cameraLink spec V2.0 page 20
            when CDM_30BIT_C =>
               v.byteData.data(0)             := r.portData.data(0);  -- T1, DR[07:00]
               v.byteData.data(1)(1 downto 0) := r.portData.data(1)(1 downto 0);  -- T1, DR[09:08]
               v.byteData.data(2)             := r.portData.data(2);  -- T2, DB[07:00]
               v.byteData.data(3)(1 downto 0) := r.portData.data(1)(5 downto 4);  -- T2, DB[09:08]
               v.byteData.data(4)             := r.portData.data(4);  -- T3, DG[07:00]
               v.byteData.data(5)(1 downto 0) := r.portData.data(5)(1 downto 0);  -- T3, DG[09:08]
               v.bytes                        := 6;

            -- 36 bits, medium, cameraLink spec V2.0 pages 20
            when CDM_36BIT_C =>
               v.byteData.data(0)             := r.portData.data(0);  -- T1, DR[07:00]
               v.byteData.data(1)(3 downto 0) := r.portData.data(1)(3 downto 0);  -- T1, DR[11:08]
               v.byteData.data(2)             := r.portData.data(2);  -- T2, DB[07:00]
               v.byteData.data(3)(3 downto 0) := r.portData.data(1)(7 downto 4);  -- T2, DB[11:08]
               v.byteData.data(4)             := r.portData.data(4);  -- T3, DG[07:00]
               v.byteData.data(5)(3 downto 0) := r.portData.data(5)(3 downto 0);  -- T3, DG[11:08]
               v.bytes                        := 6;

            when others =>
         end case;
      end if;

      ---------------------------------
      -- Frame Generation
      ---------------------------------
      v.master       := AXI_STREAM_MASTER_INIT_C;
      v.master.tKeep := (others => '0');

      -- Setup output data
      for i in 0 to SLV_CONFIG_C.TDATA_BYTES_C-1 loop
         if i < r.bytes then
            v.master.tData((i*8)+7 downto i*8) := r.byteData.data(i);
            v.master.tKeep(i)                  := '1';
         end if;
      end loop;

      -- Set start of frame
      ssiSetUserSof (SLV_CONFIG_C, v.master, not r.inFrame);

      -- Move data
      if r.portData.valid = '1' and r.byteData.valid = '1' and (
         (chanConfig.frameMode = CFM_FRAME_C and r.byteData.fv = '1') or  -- Frame mode
         (chanConfig.frameMode = CFM_LINE_C and r.byteData.lv = '1')) then  -- Line  mode

         -- Valid data in byte record
         if r.dump = '0' and r.byteData.dv = '1' and r.byteData.lv = '1' then
            v.inFrame       := '1';
            v.master.tValid := '1';
         end if;

         -- Backpressure
         if intCtrl.pause = '1' then
            v.dump := '1';
         end if;

         -- End of frame or line depending on mode
         if (chanConfig.frameMode = CFM_FRAME_C and r.byteData.fv = '1' and r.portData.fv = '0') or  -- Frame mode
            (chanConfig.frameMode = CFM_LINE_C and r.byteData.lv = '1' and r.portData.lv = '0') then  -- Line mode

            -- Frame was dumped, or bad end markers
            if (r.dump = '1' or r.inFrame = '0' or r.byteData.dv = '0') then
               ssiSetUserEofe (SLV_CONFIG_C, v.master, '1');
               v.status.dropCount := r.status.dropCount + 1;
            else
               v.status.frameCount := r.status.frameCount + 1;
            end if;

            v.master.tValid := r.inFrame;
            v.master.tLast  := '1';

            v.inFrame := '0';
            v.dump    := '0';
         end if;
      end if;

      -- Check if we need to blow off the streaming data for debugging
      if (chanConfig.blowoff = '1') then
         v.master.tValid := '0';
      end if;

      -- Check for counter reset
      if (chanConfig.cntRst = '1') then
         v.status.frameCount := (others => '0');
         v.status.dropCount  := (others => '0');
      end if;

      -- Outputs 
      parReady   <= v.ready;
      chanStatus <= r.status;

      -- Reset
      if (sysRst = '1' or chanConfig.dataEn = '0') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;


   end process;

   seq : process (sysClk) is
   begin
      if (rising_edge(sysClk)) then
         r <= rin;
      end if;
   end process;

   ---------------------------------
   -- Frame Packing
   ---------------------------------
   U_Pack : entity work.AxiStreamBytePacker
      generic map (
         TPD_G           => TPD_G,
         SLAVE_CONFIG_G  => SLV_CONFIG_C,
         MASTER_CONFIG_G => MST_CONFIG_C)
      port map (
         axiClk      => sysClk,
         axiRst      => sysRst,
         sAxisMaster => r.master,
         mAxisMaster => packMaster);

   ---------------------------------
   -- Data FIFO
   ---------------------------------
   U_DataFifo : entity work.AxiStreamFifoV2
      generic map (
         TPD_G               => TPD_G,
         SLAVE_READY_EN_G    => false,
         GEN_SYNC_FIFO_G     => COMMON_DATA_CLK_G,
         FIFO_ADDR_WIDTH_G   => 9,
         FIFO_PAUSE_THRESH_G => 500,
         SLAVE_AXI_CONFIG_G  => MST_CONFIG_C,
         MASTER_AXI_CONFIG_G => DATA_AXIS_CONFIG_G)
      port map (
         sAxisClk    => sysClk,
         sAxisRst    => sysRst,
         sAxisMaster => packMaster,
         sAxisCtrl   => intCtrl,
         mAxisClk    => dataClk,
         mAxisRst    => dataRst,
         mAxisMaster => dataMaster,
         mAxisSlave  => dataSlave);

end architecture rtl;

