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

entity CoaXPressRxLaneMux is
   generic (
      TPD_G              : time     := 1 ns;
      NUM_LANES_G        : positive := 1;
      DATA_AXIS_CONFIG_C : AxiStreamConfigType);
   port (
      -- Clock and Reset
      rxClk      : in  sl;
      rxRst      : in  sl;
      -- Config Interface (rxClk domain)
      rxFsmRst   : in  sl;
      numOfLane  : in  slv(2 downto 0);
      -- Image header Interface (rxClk domain)
      hdrMaster  : out AxiStreamMasterType;
      -- Data Interface (rxClk domain)
      rxMasters  : in  AxiStreamMasterArray(NUM_LANES_G-1 downto 0);
      rxSlaves   : out AxiStreamSlaveArray(NUM_LANES_G-1 downto 0);
      rxCtrl     : out AxiStreamCtrlType;
      -- Camera data (dataClk domain)
      dataClk    : in  sl;
      dataRst    : in  sl;
      dataMaster : out AxiStreamMasterType;
      dataSlave  : in  AxiStreamSlaveType);
end entity CoaXPressRxLaneMux;

architecture rtl of CoaXPressRxLaneMux is

   constant RX_AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(dataBytes => 4*NUM_LANES_G, tDestBits => 0);

   type StateType is (
      IDLE_S,
      TYPE_S,
      HDR_S,
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

   type RegType is record
      sof       : sl;
      yCnt      : slv(23 downto 0);
      dCnt      : slv(23 downto 0);
      hdrCnt    : natural range 0 to 25;
      hdr       : ImageHdrType;
      idx       : natural range 0 to NUM_LANES_G-1;
      hdrMaster : AxiStreamMasterType;
      rxSlaves  : AxiStreamSlaveArray(NUM_LANES_G-1 downto 0);
      rxMaster  : AxiStreamMasterType;
      state     : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      sof       => '1',
      yCnt      => (others => '0'),
      dCnt      => (others => '0'),
      hdrCnt    => 3,
      hdr       => IMAGE_HDR_INIT_C,
      idx       => 0,
      hdrMaster => AXI_STREAM_MASTER_INIT_C,
      rxSlaves  => (others => AXI_STREAM_SLAVE_FORCE_C),
      rxMaster  => AXI_STREAM_MASTER_INIT_C,
      state     => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   attribute dont_touch      : string;
   attribute dont_touch of r : signal is "TRUE";

   signal packMaster : AxiStreamMasterType;

begin

   comb : process (numOfLane, r, rxFsmRst, rxMasters, rxRst) is
      variable v      : RegType;
      variable tData  : slv(31 downto 0);
      variable wrdIdx : natural;
   begin
      -- Latch the current value
      v := r;

      -- Init Variable
      wrdIdx := 0;

      -- Flow Control
      for i in 0 to NUM_LANES_G-1 loop
         v.rxSlaves(i).tReady := '0';
      end loop;
      v.hdrMaster.tValid := '0';
      v.hdrMaster.tLast  := '0';
      v.hdrMaster.tUser  := (others => '0');
      v.rxMaster.tValid  := '0';
      v.rxMaster.tLast   := '0';
      v.rxMaster.tUser   := (others => '0');
      v.rxMaster.tKeep   := (others => '0');

      -- Loop the number of 32-bit words
      for i in 0 to NUM_LANES_G-1 loop

         -- Update variable
         tData := rxMasters(r.idx).tData(32*i+31 downto 32*i);

         -- Check for valid data
         if (rxMasters(r.idx).tValid = '1') then

            -- Accept the data
            v.rxSlaves(r.idx).tReady := '1';

            -- Check for tLast
            if (rxMasters(r.idx).tLast = '1') then
               -- Check for roll over
               if (r.idx = numOfLane) then
                  -- Reset counter
                  v.idx := 0;
               else
                  -- Increment counter
                  v.idx := r.idx + 1;
               end if;
            end if;

            -- Check the tKeep
            if (rxMasters(r.idx).tKeep(4*i) = '1') then

               -- State Machine
               case v.state is
                  ----------------------------------------------------------------------
                  when IDLE_S =>
                     -- Preset counter
                     v.hdrCnt := 3;
                     -- Check for the marker
                     if (tData = CXP_MARKER_C) then
                        -- Next State
                        v.state := TYPE_S;
                     end if;
                  ----------------------------------------------------------------------
                  when TYPE_S =>
                     -- Check for "Rectangular image header indication"
                     if (tData = x"01_01_01_01") then
                        -- Reset counters
                        v.yCnt   := (others => '0');
                        v.dCnt   := (others => '0');
                        -- Set the flag
                        v.sof    := '1';
                        -- Next State
                        v.state  := HDR_S;
                     -- Check for "Rectangular line marker"
                     elsif (tData = x"02_02_02_02") then
                        -- Next State
                        v.state := LINE_S;
                     else
                        -- Next State
                        v.state := IDLE_S;
                     end if;
                  ----------------------------------------------------------------------
                  when HDR_S =>
                     case v.hdrCnt is
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
                     -- Check for roll over
                     if (v.hdrCnt = 25) then
                        -- Next State
                        v.state := IDLE_S;
                     else
                        -- Increment the counter
                        v.hdrCnt := v.hdrCnt + 1;
                     end if;
                  ----------------------------------------------------------------------
                  when LINE_S =>
                     -- Move the data
                     v.rxMaster.tValid                               := '1';
                     v.rxMaster.tData(32*wrdIdx+31 downto 32*wrdIdx) := tData;
                     v.rxMaster.tKeep(4*wrdIdx+3 downto 4*wrdIdx)    := x"F";
                     v.rxMaster.tUser(SSI_SOF_C)                     := v.sof;

                     -- Reset the flag
                     v.sof := '0';

                     -- Increment the word index counters
                     wrdIdx := wrdIdx + 1;
                     v.dCnt := v.dCnt + 1;

                     -- Check for max count
                     if (v.dCnt = v.hdr.dsizeL) then

                        -- Reset counter
                        v.dCnt := (others => '0');

                        -- Increment counter
                        v.yCnt := v.yCnt + 1;

                        -- Check for max count
                        if (v.yCnt = v.hdr.ySize) then

                           -- Reset counter
                           v.yCnt := (others => '0');

                           -- Terminate the frame
                           v.rxMaster.tLast := '1';

                           -- Next State
                           v.state := IDLE_S;

                        end if;
                     end if;
               ----------------------------------------------------------------------
               end case;
            end if;
         end if;
      end loop;

      -- Outputs
      rxSlaves  <= v.rxSlaves;
      hdrMaster <= r.hdrMaster;

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

   U_Pack : entity surf.AxiStreamBytePacker
      generic map (
         TPD_G           => TPD_G,
         SLAVE_CONFIG_G  => RX_AXIS_CONFIG_C,
         MASTER_CONFIG_G => RX_AXIS_CONFIG_C)
      port map (
         axiClk      => rxClk,
         axiRst      => rxRst,
         sAxisMaster => r.rxMaster,
         mAxisMaster => packMaster);

   U_DataFifo : entity surf.AxiStreamFifoV2
      generic map (
         TPD_G               => TPD_G,
         SLAVE_READY_EN_G    => false,
         GEN_SYNC_FIFO_G     => false,
         FIFO_ADDR_WIDTH_G   => 9,
         SLAVE_AXI_CONFIG_G  => RX_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => DATA_AXIS_CONFIG_C)
      port map (
         -- INbound Interface
         sAxisClk    => rxClk,
         sAxisRst    => rxRst,
         sAxisMaster => packMaster,
         sAxisCtrl   => rxCtrl,
         -- Outbound Interface
         mAxisClk    => dataClk,
         mAxisRst    => dataRst,
         mAxisMaster => dataMaster,
         mAxisSlave  => dataSlave);

end rtl;
