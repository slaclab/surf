-------------------------------------------------------------------------------
-- Title      : CoaXPress Protocol: http://jiia.org/wp-content/themes/jiia/pdf/standard_dl/coaxpress/CXP-001-2021.pdf
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: CoaXPress RX FSM
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;
use surf.CoaXPressPkg.all;

entity CoaXPressRxHsFsm is
   generic (
      TPD_G              : time                   := 1 ns;
      RX_FSM_CNT_WIDTH_G : positive range 1 to 24 := 16;  -- Optimize this down w.r.t camera to help make timing in CoaXPressRxHsFsm.vhd
      NUM_LANES_G        : positive               := 1);
   port (
      -- Clock and Reset
      rxClk      : in  sl;
      rxRst      : in  sl;
      -- Config/Status Interface
      rxFsmRst   : in  sl;
      rxFsmError : out sl;
      -- Inbound Stream Interface
      rxMaster   : in  AxiStreamMasterType;
      rxSlave    : out AxiStreamSlaveType;
      -- Outbound Image header Interface
      hdrMaster  : out AxiStreamMasterType;
      -- Outbound Camera Data Interface
      dataMaster : out AxiStreamMasterType);
end entity CoaXPressRxHsFsm;

architecture rtl of CoaXPressRxHsFsm is

   type StateType is (
      IDLE_S,
      TYPE_S,
      HDR_S,
      STEP_S,
      LINE_S);

   type ImageHdrType is record
      steamId   : slv(7 downto 0);
      sourceTag : slv(15 downto 0);
      xSize     : slv(23 downto 0);
      xOffs     : slv(23 downto 0);
      ySize     : slv(23 downto 0);
      yOffs     : slv(23 downto 0);
      dsizeL    : slv(23 downto 0);
      pixelF    : slv(15 downto 0);
      tapG      : slv(15 downto 0);
      flags     : slv(7 downto 0);
   end record ImageHdrType;
   constant IMAGE_HDR_INIT_C : ImageHdrType := (
      steamId   => (others => '0'),
      sourceTag => (others => '0'),
      xSize     => (others => '0'),
      xOffs     => (others => '0'),
      ySize     => (others => '0'),
      yOffs     => (others => '0'),
      dsizeL    => (others => '0'),
      pixelF    => (others => '0'),
      tapG      => (others => '0'),
      flags     => (others => '0'));

   type DebugType is record
      errDet : sl;
      maker  : slv(NUM_LANES_G-1 downto 0);
      wrd    : natural range 0 to NUM_LANES_G;
      cnt    : slv(31 downto 0);
   end record DebugType;
   constant DEBUG_INIT_C : DebugType := (
      errDet => '0',
      maker  => (others => '0'),
      wrd    => 0,
      cnt    => (others => '0'));

   subtype LineRemType is natural range 0 to NUM_LANES_G+1;

   constant WIDE_AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(
      dataBytes => (4*NUM_LANES_G),
      tKeepMode => TKEEP_NORMAL_C,
      tUserMode => TUSER_NORMAL_C,
      tDestBits => 0,
      tUserBits => CXP_RX_STREAM_TUSER_BITS_C);

   type RegType is record
      endOfLine   : sl;
      frameEofe   : sl;
      hdrValid    : sl;
      pendingValid : sl;
      parseBeat   : sl;
      trailerMarker : sl;
      trailerEofe : sl;
      trailerSeen : sl;
      waitTrailer : sl;
      waitFrameTrailer : sl;
      yCnt        : slv(RX_FSM_CNT_WIDTH_G-1 downto 0);
      dRem        : slv(RX_FSM_CNT_WIDTH_G-1 downto 0);
      lineRem     : LineRemType;
      hdrCnt      : natural range 0 to 25;
      hdr         : ImageHdrType;
      dbg         : DebugType;
      wrd         : natural range 0 to NUM_LANES_G-1;
      hdrMaster   : AxiStreamMasterType;
      rxSlave     : AxiStreamSlaveType;
      packOut     : AxiStreamSlaveType;
      dataMasters : AxiStreamMasterArray(1 downto 0);
      dataMaster  : AxiStreamMasterType;
      pendingMaster : AxiStreamMasterType;
      state       : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      endOfLine   => '0',
      frameEofe   => '0',
      hdrValid    => '0',
      pendingValid => '0',
      parseBeat   => '0',
      trailerMarker => '0',
      trailerEofe => '0',
      trailerSeen => '0',
      waitTrailer => '0',
      waitFrameTrailer => '0',
      yCnt        => (others => '0'),
      dRem        => (others => '0'),
      lineRem     => 0,
      hdrCnt      => 0,
      hdr         => IMAGE_HDR_INIT_C,
      dbg         => DEBUG_INIT_C,
      wrd         => 0,
      hdrMaster   => AXI_STREAM_MASTER_INIT_C,
      rxSlave     => AXI_STREAM_SLAVE_FORCE_C,
      packOut     => AXI_STREAM_SLAVE_FORCE_C,
      dataMasters => (others => AXI_STREAM_MASTER_INIT_C),
      dataMaster  => AXI_STREAM_MASTER_INIT_C,
      pendingMaster => AXI_STREAM_MASTER_INIT_C,
      state       => IDLE_S);

   function satLineRem (
      remCnt : slv)
      return LineRemType is
   begin
      if (remCnt = 0) then
         return 0;
      elsif (remCnt > toSlv(NUM_LANES_G, remCnt'length)) then
         return NUM_LANES_G+1;
      else
         return conv_integer(remCnt);
      end if;
   end function satLineRem;

   signal r       : RegType := REG_INIT_C;
   signal rin     : RegType;
   signal packRst : sl;

   signal pipeMaster : AxiStreamMasterType;
   signal pipeSlave  : AxiStreamSlaveType;
   signal packMaster : AxiStreamMasterType;
   signal packInSlave  : AxiStreamSlaveType;
   signal packOutSlave : AxiStreamSlaveType;

   -- attribute dont_touch      : string;
   -- attribute dont_touch of r : signal is "TRUE";

begin

   packRst <= rxRst or rxFsmRst;

   packOutSlave <= r.packOut;

   comb : process (packInSlave, packMaster, pipeMaster, r, rxFsmRst, rxRst) is
      variable v        : RegType;
      variable tData    : slv(31 downto 0);
      variable eolBeat  : sl;
      variable eolWrd   : natural range 0 to NUM_LANES_G-1;
      variable wordCnt  : natural range 0 to NUM_LANES_G;
      variable lineDec  : natural range 0 to NUM_LANES_G;
      variable nextDRem : slv(RX_FSM_CNT_WIDTH_G-1 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Init Variable
      tData           := pipeMaster.tData(32*r.wrd+31 downto 32*r.wrd);
      v.trailerMarker := pipeMaster.tValid and pipeMaster.tLast and (
         pipeMaster.tUser(CXP_RX_STREAM_TRAILER_TUSER_C) or
         axiStreamGetUserBit(WIDE_AXIS_CONFIG_C, pipeMaster, CXP_RX_STREAM_TRAILER_TUSER_C));
      v.trailerEofe := ssiGetUserEofe(WIDE_AXIS_CONFIG_C, pipeMaster) or pipeMaster.tUser(SSI_EOFE_C);
      v.waitTrailer := r.pendingValid or (r.waitFrameTrailer and not v.trailerMarker and not r.trailerSeen) or
         (packMaster.tValid and packMaster.tLast and not v.trailerMarker and not r.trailerSeen);

      -- Reset strobes
      v.dbg.errDet := '0';
      v.dbg.maker  := (others => '0');

      -- Loop the number of 32-bit words
      for i in 0 to NUM_LANES_G-1 loop
         -- Check for maker pattern
         if (pipeMaster.tData(32*i+31 downto 32*i) = CXP_MARKER_C) then
            v.dbg.maker(i) := '1';
         end if;
      end loop;

      -- Init header stream
      v.hdrMaster.tValid           := '0';  -- Reset strobe
      v.hdrMaster.tLast            := '1';  -- single word write
      v.hdrMaster.tUser(SSI_SOF_C) := '1';  -- single word write

      -- Init data stream
      if (packInSlave.tReady = '1') then
         v.dataMasters(0).tValid := '0';                -- Reset strobe
         v.dataMasters(0).tData  := pipeMaster.tData;
         -- Check if state is not STEP_S
         if (r.state /= STEP_S) then
            v.dataMasters(0).tKeep := (others => '0');  -- Reset bus
         end if;
      else
         v.dataMasters(0) := r.dataMasters(0);
      end if;

      -- Flow Control
      v.rxSlave.tReady := '0';
      v.packOut        := AXI_STREAM_SLAVE_FORCE_C;
      if (v.waitTrailer = '1') then
         v.packOut.tReady := '0';
      end if;
      v.parseBeat      := pipeMaster.tValid and not v.trailerMarker and not v.waitTrailer and packInSlave.tReady;

      -- Check for valid data
      if (pipeMaster.tValid = '1') and (v.trailerMarker = '1') then
         -- Consume the lane's trailer verdict beat.  Payload has
         -- already streamed through; this only annotates the eventual SSI EOF.
         v.rxSlave.tReady := '1';
         if (v.trailerEofe = '1') then
            v.frameEofe := '1';
         end if;
         if (r.waitFrameTrailer = '1') or (r.pendingValid = '1') or (r.endOfLine = '1') or
            (r.dataMasters(0).tValid = '1') or (r.dataMasters(1).tValid = '1') or
            ((packMaster.tValid = '1') and (packMaster.tLast = '1')) then
            v.trailerSeen := '1';
         end if;

      elsif (v.parseBeat = '1') then

         -- State Machine
         case r.state is
            ----------------------------------------------------------------------
            when IDLE_S =>
               -- Reset counter
               v.dRem    := (others => '0');
               v.lineRem := 0;

               -- Check for the marker
               if (tData = CXP_MARKER_C) then
                  -- Next State
                  v.state := TYPE_S;

               else
                  -- Set the flag
                  v.dbg.errDet := '1';
               end if;
            ----------------------------------------------------------------------
            when TYPE_S =>
               if (r.waitFrameTrailer = '0') and (r.pendingValid = '0') then
                  v.trailerSeen := '0';
               end if;

               -- Check for "Rectangular image header indication"
               if (tData = x"01_01_01_01") then

                  -- Preset counter
                  v.hdrCnt := 3;

                  -- Reset counters
                  v.endOfLine := '0';
                  v.hdrValid  := '0';
                  v.dRem      := (others => '0');
                  v.lineRem   := 0;
                  v.yCnt      := (others => '0');

                  -- Check for out of sync header
                  if (r.hdrValid = '1') and (r.yCnt /= r.hdr.ySize(RX_FSM_CNT_WIDTH_G-1 downto 0)) then
                     -- Set the flag
                     v.dbg.errDet := '1';
                  end if;

                  -- Next State
                  v.state := HDR_S;

               -- Check for "Rectangular line marker"
               elsif (tData = x"02_02_02_02") then
                  if (r.hdrValid = '1') then
                     v.dRem    := r.hdr.dsizeL(RX_FSM_CNT_WIDTH_G-1 downto 0);
                     v.lineRem := satLineRem(r.hdr.dsizeL(RX_FSM_CNT_WIDTH_G-1 downto 0));

                     -- Next State
                     v.state := LINE_S;
                  else
                     -- Set the flag
                     v.dbg.errDet := '1';

                     -- Next State
                     v.state := IDLE_S;
                  end if;

               else
                  -- Set the flag
                  v.dbg.errDet := '1';

                  -- Next State
                  v.state := IDLE_S;
               end if;
            ----------------------------------------------------------------------
            when HDR_S =>
               if (tData(7 downto 0) /= tData(15 downto 8))
                  or (tData(7 downto 0) /= tData(23 downto 16))
                  or (tData(7 downto 0) /= tData(31 downto 24)) then

                  -- Reset counter
                  v.endOfLine := '0';
                  v.hdrCnt    := 0;
                  v.hdrValid  := '0';

                  -- Set the flag
                  v.dbg.errDet := '1';

                  -- Next State
                  v.state := IDLE_S;

               -- Check for roll over
               elsif (r.hdrCnt = 25) then

                  -- Reset counter
                  v.hdrCnt   := 0;
                  v.hdrValid := '1';

                  -- Forward the image header
                  v.hdrMaster.tValid := '1';

                  -- Next State
                  v.state := IDLE_S;

               else
                  -- Increment the counter
                  v.hdrCnt := r.hdrCnt + 1;
               end if;
            ----------------------------------------------------------------------
            when STEP_S =>
               -- Map the TKEEP word
               v.dataMasters(0).tKeep(4*r.wrd+3 downto 4*r.wrd) := x"F";

               -- Consume the held word from an unaligned line start.
               if (r.dRem > 1) then
                  nextDRem := r.dRem - 1;
               else
                  nextDRem := (others => '0');
               end if;
               v.dRem    := nextDRem;
               v.lineRem := satLineRem(nextDRem);

               -- Check for max count
               if (r.lineRem = 1) then

                  -- Move the data
                  v.dataMasters(0).tValid := '1';

                  -- Set the "end of line" flag
                  v.endOfLine := '1';

                  -- Next State
                  v.state := IDLE_S;

               end if;
            ----------------------------------------------------------------------
            when LINE_S =>
               -- Write the data
               v.dataMasters(0).tValid := '1';

               -- Accept the data unless the next word in this same beat must be
               -- reparsed as the next marker/type sequence.
               v.rxSlave.tReady := '1';
               eolBeat          := '0';
               eolWrd           := 0;
               wordCnt          := 0;
               lineDec          := 0;

               -- Loop the number of 32-bit words
               for i in 0 to NUM_LANES_G-1 loop

                  -- Check for valid data
                  if (pipeMaster.tKeep(4*i) = '1') then
                     wordCnt := wordCnt + 1;

                     -- Check for not "end of line"
                     if (wordCnt <= r.lineRem) then

                        -- Update the TKEEP mask
                        v.dataMasters(0).tKeep(4*i+3 downto 4*i) := x"F";

                        -- Count the accepted line words in this beat.
                        lineDec := lineDec + 1;

                     end if;

                     -- Check for max count
                     if (wordCnt = r.lineRem) then

                        -- Flag the end of line word in this beat
                        eolBeat := '1';
                        eolWrd  := i;

                        -- Set the "end of line" flag
                        v.endOfLine := '1';

                        -- Next State
                        v.state := IDLE_S;

                     end if;

                  end if;

               end loop;

               if (eolBeat = '1') and (eolWrd /= NUM_LANES_G-1) then
                  if (pipeMaster.tKeep(4*(eolWrd+1)) = '1') then
                     v.rxSlave.tReady := '0';
                     v.wrd            := eolWrd+1;
                  else
                     v.wrd := 0;
                  end if;
               elsif (eolBeat = '1') then
                  v.wrd := 0;
               end if;

               -- Track the remaining line words with an incremental
               -- countdown.  This avoids a wide dsizeL-dCnt subtraction on
               -- every parser cycle.
               if (lineDec /= 0) then
                  if (r.dRem > toSlv(lineDec, RX_FSM_CNT_WIDTH_G)) then
                     nextDRem := r.dRem - toSlv(lineDec, RX_FSM_CNT_WIDTH_G);
                  else
                     nextDRem := (others => '0');
                  end if;
                  v.dRem    := nextDRem;
                  v.lineRem := satLineRem(nextDRem);
               end if;
         ----------------------------------------------------------------------
         end case;

         -- Check if current state is not LINE_S
         if (r.state /= LINE_S) then

            -- Check for roll over
            if (r.wrd = NUM_LANES_G-1) then
               -- Reset the counter
               v.wrd := 0;

               -- Accept the data
               v.rxSlave.tReady := '1';

            else
               -- Increment the counter
               v.wrd := r.wrd + 1;

               -- Check if no more data available
               if (pipeMaster.tKeep(4*v.wrd) = '0') then
                  -- Reset the counter
                  v.wrd := 0;

                  -- Accept the data
                  v.rxSlave.tReady := '1';

               end if;

            end if;

            -- Check if next state is LINE_S but not aligned
            if (v.state = LINE_S) and (v.wrd /= 0) then
               -- Switch to stepping state
               v.state := STEP_S;

            end if;

            -- Check for STEP_S state
            if (r.state = STEP_S) and (v.state = STEP_S) and (v.rxSlave.tReady = '1') then
               -- Move the data
               v.dataMasters(0).tValid := '1';

               -- Switch to bursting state
               v.state := LINE_S;

            end if;

         end if;

      end if;

      -- Shift the parser output into the word packer only when the packer can
      -- accept it.  This keeps the final packed EOF beat stable while the FSM
      -- waits for the lane trailer verdict.
      if (packInSlave.tReady = '1') then
         v.dataMasters(1) := r.dataMasters(0);
      else
         v.dataMasters(1) := r.dataMasters(1);
      end if;

      -- Check for end of line in the previous cycle
      if (packInSlave.tReady = '1') and (r.endOfLine = '1') then

         -- Reset flag
         v.endOfLine := '0';

         -- Increment counter
         v.yCnt := v.yCnt + 1;

         -- Check for max count
         if (v.yCnt = r.hdr.ySize(RX_FSM_CNT_WIDTH_G-1 downto 0)) then
            -- Terminate the frame
            v.dataMasters(1).tLast := '1';
            v.waitFrameTrailer     := '1';
         end if;

      end if;

      -- Debugging: tracking the number of words
      v.dbg.wrd := 0;
      for i in 0 to NUM_LANES_G-1 loop
         if (r.dataMasters(1).tValid = '1') and (r.dataMasters(1).tKeep(4*i) = '1') then
            v.dbg.wrd := v.dbg.wrd + 1;
         end if;
      end loop;
      if (r.state = HDR_S) then
         -- Reset counter
         v.dbg.cnt := (others => '0');
      else
         -- Increment counter
         v.dbg.cnt := r.dbg.cnt + r.dbg.wrd;
      end if;

      -- Update header based on counter
      if (v.parseBeat = '1') then
         case r.hdrCnt is
            ----------------------------------------------------------------
            when 3  => v.hdr.steamId(7 downto 0)    := tData(7 downto 0);
            ----------------------------------------------------------------
            when 4  => v.hdr.sourceTag(15 downto 8) := tData(7 downto 0);
            when 5  => v.hdr.sourceTag(7 downto 0)  := tData(7 downto 0);
            ----------------------------------------------------------------
            when 6  => v.hdr.xSize(23 downto 16)    := tData(7 downto 0);
            when 7  => v.hdr.xSize(15 downto 8)     := tData(7 downto 0);
            when 8  => v.hdr.xSize(7 downto 0)      := tData(7 downto 0);
            ----------------------------------------------------------------
            when 9  => v.hdr.xOffs(23 downto 16)    := tData(7 downto 0);
            when 10 => v.hdr.xOffs(15 downto 8)     := tData(7 downto 0);
            when 11 => v.hdr.xOffs(7 downto 0)      := tData(7 downto 0);
            ----------------------------------------------------------------
            when 12 => v.hdr.ySize(23 downto 16)    := tData(7 downto 0);
            when 13 => v.hdr.ySize(15 downto 8)     := tData(7 downto 0);
            when 14 => v.hdr.ySize(7 downto 0)      := tData(7 downto 0);
            ----------------------------------------------------------------
            when 15 => v.hdr.yOffs(23 downto 16)    := tData(7 downto 0);
            when 16 => v.hdr.yOffs(15 downto 8)     := tData(7 downto 0);
            when 17 => v.hdr.yOffs(7 downto 0)      := tData(7 downto 0);
            ----------------------------------------------------------------
            when 18 => v.hdr.dsizeL(23 downto 16)   := tData(7 downto 0);
            when 19 => v.hdr.dsizeL(15 downto 8)    := tData(7 downto 0);
            when 20 => v.hdr.dsizeL(7 downto 0)     := tData(7 downto 0);
            ----------------------------------------------------------------
            when 21 => v.hdr.pixelF(15 downto 8)    := tData(7 downto 0);
            when 22 => v.hdr.pixelF(7 downto 0)     := tData(7 downto 0);
            ----------------------------------------------------------------
            when 23 => v.hdr.tapG(15 downto 8)      := tData(7 downto 0);
            when 24 => v.hdr.tapG(7 downto 0)       := tData(7 downto 0);
            ----------------------------------------------------------------
            when 25 => v.hdr.flags(7 downto 0)      := tData(7 downto 0);
            ----------------------------------------------------------------
            when others =>
               null;
         end case;
      end if;

      -----------------------------------------------------------------------------
      -- Perform an endianness swap in header message and remove redundant bytes --
      -----------------------------------------------------------------------------
      --                This is the image header format                          --
      -----------------------------------------------------------------------------
      -- WORD[0]BIT[31:0]
      v.hdrMaster.tData(7 downto 0)   := r.hdr.steamId(7 downto 0);
      v.hdrMaster.tData(15 downto 8)  := v.hdr.flags(7 downto 0);  -- variable (not reg) because same cycle as (r.hdrCnt = 25)
      v.hdrMaster.tData(31 downto 16) := r.hdr.sourceTag(15 downto 0);

      -- WORD[1]BIT[31:0]
      v.hdrMaster.tData(63 downto 32) := x"00" & r.hdr.xSize(23 downto 0);

      -- WORD[2]BIT[31:0]
      v.hdrMaster.tData(95 downto 64) := x"00" & r.hdr.xOffs(23 downto 0);

      -- WORD[3]BIT[31:0]
      v.hdrMaster.tData(127 downto 96) := x"00" & r.hdr.ySize(23 downto 0);

      -- WORD[4]BIT[31:0]
      v.hdrMaster.tData(159 downto 128) := x"00" & r.hdr.yOffs(23 downto 0);

      -- WORD[5]BIT[31:0]
      v.hdrMaster.tData(191 downto 160) := x"00" & r.hdr.dsizeL(23 downto 0);

      -- WORD[6]BIT[31:0]
      v.hdrMaster.tData(207 downto 192) := r.hdr.pixelF(15 downto 0);
      v.hdrMaster.tData(223 downto 208) := r.hdr.tapG(15 downto 0);

      -- Hold only the packed SSI EOF beat until the lane trailer verdict
      -- arrives. Payload still streams as soon as it is parsed.
      v.dataMaster.tValid := '0';

      if (r.pendingValid = '1') then
         v.packOut.tReady := '0';
         if (v.trailerMarker = '1') or (r.trailerSeen = '1') then
            v.dataMaster := r.pendingMaster;
            ssiSetUserEofe(WIDE_AXIS_CONFIG_C, v.dataMaster, v.frameEofe or v.trailerEofe);
            v.dataMaster.tUser(SSI_EOFE_C) := v.frameEofe or v.trailerEofe;
            v.pendingMaster := AXI_STREAM_MASTER_INIT_C;
            v.pendingValid  := '0';
            v.frameEofe     := '0';
            v.trailerSeen   := '0';
            v.waitFrameTrailer := '0';
         end if;
      elsif (packMaster.tValid = '1') and (packMaster.tLast = '1') and
         (v.trailerMarker = '0') and (r.trailerSeen = '0') then
         v.pendingMaster := packMaster;
         v.pendingValid  := '1';
      elsif (packMaster.tValid = '1') and (packMaster.tLast = '1') then
         v.dataMaster := packMaster;
         ssiSetUserEofe(WIDE_AXIS_CONFIG_C, v.dataMaster, v.frameEofe or v.trailerEofe);
         v.dataMaster.tUser(SSI_EOFE_C) := v.frameEofe or v.trailerEofe;
         v.frameEofe   := '0';
         v.trailerSeen := '0';
         v.waitFrameTrailer := '0';
      elsif (packMaster.tValid = '1') then
         v.dataMaster := packMaster;
      end if;

      -- Outputs
      pipeSlave    <= v.rxSlave;
      hdrMaster    <= r.hdrMaster;
      dataMaster   <= r.dataMaster;
      rxFsmError   <= r.dbg.errDet;

      -- Reset
      if (rxRst = '1') or (rxFsmRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (rxClk) is
   begin
      if (rising_edge(rxClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_RxPipe : entity surf.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
         PIPE_STAGES_G => 1)
      port map (
         axisClk     => rxClk,
         axisRst     => packRst,
         sAxisMaster => rxMaster,
         sAxisSlave  => rxSlave,
         mAxisMaster => pipeMaster,
         mAxisSlave  => pipeSlave);

   U_Pack : entity surf.CoaXPressRxWordPacker
      generic map (
         TPD_G       => TPD_G,
         NUM_LANES_G => NUM_LANES_G)
      port map (
         rxClk       => rxClk,
         rxRst       => packRst,
         sAxisMaster => r.dataMasters(1),
         sAxisSlave  => packInSlave,
         mAxisMaster => packMaster,
         mAxisSlave  => packOutSlave);

end rtl;
